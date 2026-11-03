import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';
import 'storage_service.dart';
import 'youtube_importer_service.dart';
import 'stream_resolver_service.dart';
import 'piped_service.dart';

class DownloadProgress {
  final String songId;
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final bool isFailed;
  final String? error;
  final String? localFilePath;
  final bool isVideo;

  const DownloadProgress({
    required this.songId,
    required this.progress,
    this.isCompleted = false,
    this.isFailed = false,
    this.error,
    this.localFilePath,
    this.isVideo = false,
  });
}

class DownloadService {
  DownloadService._();

  static final Map<String, DownloadProgress> _activeDownloads = {};
  static final StreamController<DownloadProgress> _progressController =
      StreamController<DownloadProgress>.broadcast();

  static Stream<DownloadProgress> get progressStream => _progressController.stream;
  static Map<String, DownloadProgress> get activeDownloads => _activeDownloads;

  static String _sanitizeFilename(String input) {
    // Strip illegal filesystem and control characters
    var clean = input
        .replaceAll(RegExp(r'[\x00-\x1F\x7F\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Strip trailing periods and spaces (prohibited on Windows)
    clean = clean.replaceAll(RegExp(r'[.\s]+$'), '');

    // Guard against Windows reserved device names
    const reserved = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
    };
    if (reserved.contains(clean.toUpperCase())) {
      clean = 'track_$clean';
    }

    return clean.isNotEmpty ? clean : 'track_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Request runtime storage permissions for Android.
  /// Android <= 10 (API 28/29 - e.g. user device PKQ1.180904.001): Permission.storage (WRITE_EXTERNAL_STORAGE)
  /// Android 11+ (API 30+): Permission.manageExternalStorage (MANAGE_EXTERNAL_STORAGE)
  /// Android 13+ (API 33+): Permission.audio / Permission.videos
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      // 1. Android 11+ (API 30+): MANAGE_EXTERNAL_STORAGE is required to write directly to /storage/emulated/0/Sine-Music
      final manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        final req = await Permission.manageExternalStorage.request();
        if (req.isGranted) return true;
      } else {
        return true;
      }

      // 2. Android <= 10 (API <= 29): WRITE_EXTERNAL_STORAGE legacy permission
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }
      if (storageStatus.isGranted) return true;

      // 3. Android 13+ (API 33+) granular media permissions
      final audioStatus = await Permission.audio.request();
      final videoStatus = await Permission.videos.request();
      if (audioStatus.isGranted || videoStatus.isGranted) return true;
    } catch (e) {
      debugPrint('[DownloadService] Storage permission request error: $e');
    }
    return false;
  }

  /// Locate or create appropriate public/accessible media directory cross-platform.
  /// Strictly prioritizes "/storage/emulated/0/Sine-Music" (the root directory where Android & DCIM lie).
  static Future<Directory> _getMediaDirectory({bool isVideo = false}) async {
    final subFolder = isVideo ? 'Sine-Videos' : 'Sine-Music';
    if (Platform.isAndroid) {
      // Request permission before attempting filesystem operations
      await requestStoragePermission();

      // Find external storage root (e.g. /storage/emulated/0)
      String? rootPath;
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final idx = ext.path.indexOf('/Android');
          if (idx != -1) {
            rootPath = ext.path.substring(0, idx);
          }
        }
      } catch (_) {}

      // Target candidates in strict priority order:
      // 1. Direct /storage/emulated/0/$subFolder (in parent directory where Android & DCIM lie)
      // 2. Dynamic root directory ($rootPath/$subFolder)
      // 3. /sdcard/$subFolder
      // 4. /storage/self/primary/$subFolder
      // 5. Standard public media folders (Music/Movies, Download)
      final candidates = <String>[
        '/storage/emulated/0/$subFolder',
        if (rootPath != null && rootPath != '/storage/emulated/0') '$rootPath/$subFolder',
        '/sdcard/$subFolder',
        '/storage/self/primary/$subFolder',
        if (isVideo) '/storage/emulated/0/Movies/$subFolder' else '/storage/emulated/0/Music/$subFolder',
        '/storage/emulated/0/Download/$subFolder',
      ];

      for (final p in candidates) {
        try {
          final dir = Directory(p);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          // Verify writeability with a dummy probe file
          final probe = File('${dir.path}/.probe_${DateTime.now().millisecondsSinceEpoch}');
          await probe.writeAsString('probe');
          await probe.delete();
          return dir;
        } catch (e) {
          debugPrint('[DownloadService] Probe failed for $p: $e');
        }
      }

      // App-specific external storage as absolute last resort
      try {
        final storageType = isVideo ? StorageDirectory.movies : StorageDirectory.music;
        final extDirs = await getExternalStorageDirectories(type: storageType);
        if (extDirs != null && extDirs.isNotEmpty) {
          final dir = Directory('${extDirs.first.path}/$subFolder');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (_) {}

      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final dir = Directory('${ext.path}/$subFolder');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (_) {}
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final dir = Directory('${downloads.path}/$subFolder');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (_) {}
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$subFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Robust file move with atomic rename & cross-filesystem copy fallback
  static Future<void> _safeMoveFile(File source, File target) async {
    if (await target.exists()) {
      try { await target.delete(); } catch (_) {}
    }
    try {
      await source.rename(target.path);
    } catch (_) {
      await source.copy(target.path);
      try { await source.delete(); } catch (_) {}
    }
  }

  /// Resolve any song to a valid YouTube Video ID
  static Future<String?> _resolveVideoId(YoutubeExplode yt, Song song) async {
    if (song.id.startsWith('yt_')) {
      return song.id.substring(3);
    }

    final fromUrl = YouTubeImporterService.extractVideoId(song.streamUrl);
    if (fromUrl != null && fromUrl.isNotEmpty) {
      return fromUrl;
    }

    try {
      final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
      final query = '${cleanTitle.isNotEmpty ? cleanTitle : song.title} ${song.artist}'.trim();
      final searchResults = await yt.search.search(query).timeout(const Duration(seconds: 8));
      if (searchResults.isNotEmpty) {
        return searchResults.first.id.value;
      }
    } catch (e) {
      debugPrint('[DownloadService] Error searching video ID for download: $e');
    }
    return null;
  }

  /// Download audio directly to device storage for offline playback
  /// Helper to stream download from an HTTP / Piped proxy URL directly to a file
  static Future<bool> _downloadFileFromUrl({
    required String url,
    required File targetFile,
    required String downloadKey,
    required bool isVideo,
    Map<String, String>? headers,
  }) async {
    final partFile = File('${targetFile.path}.part');
    IOSink? output;
    http.Client? client;
    try {
      client = http.Client();
      final uri = Uri.parse(url);
      final req = http.Request('GET', uri);

      final isYouTubeCdn = uri.host.contains('googlevideo.com') || uri.host.contains('youtube.com');
      if (headers != null) {
        req.headers.addAll(headers);
      } else if (isYouTubeCdn) {
        // Android InnerTube ExoPlayer headers to prevent HTTP 403 Forbidden
        req.headers['User-Agent'] = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11)';
        req.headers['Accept'] = '*/*';
      } else {
        req.headers['User-Agent'] = 'Sine/1.0 (Android; Linux)';
        req.headers['Accept'] = '*/*';
      }

      final response = await client.send(req).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      output = partFile.openWrite();
      var received = 0;
      final total = response.contentLength ?? 0;
      double lastProgress = 0.0;

      await for (final chunk in response.stream.timeout(const Duration(seconds: 35))) {
        output.add(chunk);
        received += chunk.length;
        final prog = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.5;
        if ((prog - lastProgress).abs() >= 0.01 || prog == 1.0) {
          lastProgress = prog;
          _activeDownloads[downloadKey] = DownloadProgress(
            songId: downloadKey,
            progress: prog,
            isVideo: isVideo,
          );
          _progressController.add(_activeDownloads[downloadKey]!);
        }
      }

      await output.flush();
      await output.close();
      output = null;

      if (total > 0 && received < total) {
        throw Exception('Truncated download: received $received of $total bytes');
      }
      if (received == 0) {
        throw Exception('Download failed: 0 bytes received');
      }

      await _safeMoveFile(partFile, targetFile);
      return true;
    } catch (e) {
      try { await output?.close(); } catch (_) {}
      output = null;
      if (await partFile.exists()) {
        try { await partFile.delete(); } catch (_) {}
      }
      rethrow;
    } finally {
      client?.close();
    }
  }

  /// Download audio directly to device storage for offline playback
  static Future<String?> downloadAudio(Song song, StorageService storageService) async {
    final songId = song.id;

    // Check active in-progress downloads
    final active = _activeDownloads[songId];
    if (active != null && !active.isCompleted && !active.isFailed) {
      return null; // Already in progress
    }

    // Return immediately if already completed and file exists on disk
    if (active != null && active.isCompleted && active.localFilePath != null) {
      final f = File(active.localFilePath!);
      if (await f.exists() && await f.length() > 0) {
        return active.localFilePath;
      }
    }

    // Proactively request runtime storage permissions (Android 9/10/11+)
    await requestStoragePermission();

    final dir = await _getMediaDirectory(isVideo: false);
    final rawBase = _sanitizeFilename('${song.title} - ${song.artist}');
    var safeBase = rawBase.length > 90 ? rawBase.substring(0, 90).trimRight() : rawBase;
    safeBase = safeBase.replaceAll(RegExp(r'[.\s_-]+$'), '');
    final cleanId = song.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final safeId = cleanId.isNotEmpty ? cleanId : '${song.hashCode.abs()}';
    final targetM4a = File('${dir.path}/${safeBase}_$safeId.m4a');
    final targetWebm = File('${dir.path}/${safeBase}_$safeId.webm');

    for (final f in [targetM4a, targetWebm]) {
      if (await f.exists() && await f.length() > 0) {
        _activeDownloads[songId] = DownloadProgress(
          songId: songId,
          progress: 1.0,
          isCompleted: true,
          localFilePath: f.path,
        );
        _progressController.add(_activeDownloads[songId]!);
        return f.path;
      }
    }

    _activeDownloads[songId] = DownloadProgress(songId: songId, progress: 0.0);
    _progressController.add(_activeDownloads[songId]!);

    File? completedFile;

    try {
      // Tier 1: Resolve high-res candidates via StreamResolverService (InnerTube multi-client cascade)
      debugPrint('[DownloadService] Resolving stream candidates for "${song.title}"...');
      final candidates = await StreamResolverService.resolvePlayableStreamCandidates(song);
      
      for (int i = 0; i < candidates.length; i++) {
        final candUrl = candidates[i];
        if (candUrl.isEmpty || candUrl.contains('youtube.com/watch') || candUrl.contains('youtu.be/')) continue;

        final isWebm = candUrl.contains('webm') || candUrl.contains('itag=251');
        final ext = isWebm ? 'webm' : 'm4a';
        final file = File('${dir.path}/${safeBase}_$safeId.$ext');

        try {
          debugPrint('[DownloadService] Downloading audio candidate #${i + 1} for "${song.title}"...');
          final ok = await _downloadFileFromUrl(
            url: candUrl,
            targetFile: file,
            downloadKey: songId,
            isVideo: false,
          );
          if (ok && await file.exists() && await file.length() > 0) {
            completedFile = file;
            debugPrint('[DownloadService] Successfully downloaded audio via candidate #${i + 1}');
            break;
          }
        } catch (candErr) {
          debugPrint('[DownloadService] Candidate #${i + 1} download failed: $candErr');
        }
      }

      // Tier 2: If candidate downloads failed, resolve videoId and try direct manifest & Piped proxy
      if (completedFile == null) {
        final yt = YoutubeExplode();
        try {
          final videoId = await _resolveVideoId(yt, song);
          if (videoId != null && videoId.isNotEmpty) {
            // Tier 2A: Query YoutubeExplode manifest
            try {
              final manifest = await yt.videos.streamsClient.getManifest(
                videoId,
                ytClients: [
                  YoutubeApiClient.ios,
                  YoutubeApiClient.android,
                  YoutubeApiClient.androidSdkless,
                ],
                requireWatchPage: false,
              ).timeout(const Duration(seconds: 8));

              StreamInfo? audioStreamInfo;
              final mp4Audio = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
              if (mp4Audio.isNotEmpty) {
                audioStreamInfo = mp4Audio.withHighestBitrate();
              } else if (manifest.audioOnly.isNotEmpty) {
                audioStreamInfo = manifest.audioOnly.withHighestBitrate();
              } else if (manifest.audio.isNotEmpty) {
                audioStreamInfo = manifest.audio.withHighestBitrate();
              }

              if (audioStreamInfo != null) {
                final ext = audioStreamInfo.container.name.toLowerCase() == 'mp4' ? 'm4a' : audioStreamInfo.container.name.toLowerCase();
                final file = File('${dir.path}/${safeBase}_$safeId.$ext');
                final ok = await _downloadFileFromUrl(
                  url: audioStreamInfo.url.toString(),
                  targetFile: file,
                  downloadKey: songId,
                  isVideo: false,
                );
                if (ok && await file.exists() && await file.length() > 0) {
                  completedFile = file;
                }
              }
            } catch (manifestErr) {
              debugPrint('[DownloadService] Manifest audio fetch failed: $manifestErr');
            }

            // Tier 2B: Piped proxy fallback
            if (completedFile == null) {
              debugPrint('[DownloadService] Attempting Piped audio proxy fallback for "${song.title}"...');
              final pipedAudioUrl = await PipedService.getAudioStream(videoId);
              if (pipedAudioUrl != null && pipedAudioUrl.isNotEmpty) {
                final file = File('${dir.path}/${safeBase}_$safeId.m4a');
                final ok = await _downloadFileFromUrl(
                  url: pipedAudioUrl,
                  targetFile: file,
                  downloadKey: songId,
                  isVideo: false,
                );
                if (ok && await file.exists() && await file.length() > 0) {
                  completedFile = file;
                }
              }
            }
          }
        } finally {
          yt.close();
        }
      }

      if (completedFile == null) {
        throw Exception('Unable to acquire audio stream from YouTube or fallback proxy for "${song.title}"');
      }

      // Record in storage as downloaded
      final downloadedSong = song.copyWith(
        streamUrl: completedFile.path, // Use local path for offline playback
        source: 'download',
      );
      final currentDownloads = storageService.loadDownloads();
      currentDownloads.removeWhere((s) => s.id == song.id);
      currentDownloads.add(downloadedSong);
      await storageService.saveDownloads(currentDownloads);

      _activeDownloads[songId] = DownloadProgress(
        songId: songId,
        progress: 1.0,
        isCompleted: true,
        localFilePath: completedFile.path,
      );
      _progressController.add(_activeDownloads[songId]!);
      return completedFile.path;
    } catch (e) {
      debugPrint('[DownloadService] Audio download error: $e');
      _activeDownloads[songId] = DownloadProgress(
        songId: songId,
        progress: 0.0,
        isFailed: true,
        error: e.toString(),
      );
      _progressController.add(_activeDownloads[songId]!);
      return null;
    }
  }

  /// Download MP4 Video (complete with audio) directly to device Movies folder
  static Future<String?> downloadVideo(Song song) async {
    final videoIdKey = 'video_${song.id}';
    final active = _activeDownloads[videoIdKey];
    if (active != null && !active.isCompleted && !active.isFailed) {
      return null; // Already downloading
    }

    // Proactively request runtime storage permissions
    await requestStoragePermission();

    final dir = await _getMediaDirectory(isVideo: true);
    final rawBase = _sanitizeFilename('${song.title} - ${song.artist}');
    var safeBase = rawBase.length > 90 ? rawBase.substring(0, 90).trimRight() : rawBase;
    safeBase = safeBase.replaceAll(RegExp(r'[.\s_-]+$'), '');
    final cleanId = song.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final safeId = cleanId.isNotEmpty ? cleanId : '${song.hashCode.abs()}';
    final targetMp4 = File('${dir.path}/${safeBase}_$safeId.mp4');
    final targetWebm = File('${dir.path}/${safeBase}_$safeId.webm');

    // Return immediately if already downloaded and exists on disk
    for (final f in [targetMp4, targetWebm]) {
      if (await f.exists() && await f.length() > 0) {
        _activeDownloads[videoIdKey] = DownloadProgress(
          songId: videoIdKey,
          progress: 1.0,
          isCompleted: true,
          localFilePath: f.path,
          isVideo: true,
        );
        _progressController.add(_activeDownloads[videoIdKey]!);
        return f.path;
      }
    }

    _activeDownloads[videoIdKey] = DownloadProgress(songId: videoIdKey, progress: 0.0, isVideo: true);
    _progressController.add(_activeDownloads[videoIdKey]!);

    final yt = YoutubeExplode();
    try {
      final videoId = await _resolveVideoId(yt, song);
      if (videoId == null || videoId.isEmpty) {
        throw Exception('No video found for "${song.title}"');
      }

      StreamManifest? manifest;

      // Tier 1: Query iOS & Android clients without watch page
      // iOS Innertube client returns progressive muxed formats (itag 22 @ 720p, itag 18 @ 360p)
      try {
        manifest = await yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [
            YoutubeApiClient.ios,
            YoutubeApiClient.android,
            YoutubeApiClient.androidSdkless,
          ],
          requireWatchPage: false,
        ).timeout(const Duration(seconds: 10));
      } catch (tier1Err) {
        debugPrint('[DownloadService] Tier 1 manifest fetch failed ($tier1Err), attempting Tier 2...');
      }

      // Tier 2: Watch page fallback if Tier 1 failed or returned no muxed streams
      if (manifest == null || manifest.muxed.isEmpty) {
        try {
          manifest = await yt.videos.streamsClient.getManifest(
            videoId,
            ytClients: [
              YoutubeApiClient.ios,
              YoutubeApiClient.tv,
              YoutubeApiClient.androidVr,
            ],
            requireWatchPage: true,
          ).timeout(const Duration(seconds: 12));
        } catch (tier2Err) {
          debugPrint('[DownloadService] Tier 2 watch page manifest fetch failed: $tier2Err');
        }
      }

      File? completedFile;

      if (manifest != null && manifest.muxed.isNotEmpty) {
        MuxedStreamInfo? selectedStream;

        // 1. Prefer itag 22 (720p HD MP4 muxed: H.264 + AAC audio)
        for (final s in manifest.muxed) {
          if (s.tag == 22) {
            selectedStream = s;
            break;
          }
        }

        // 2. Fallback: Any MP4 muxed stream sorted by highest video resolution
        if (selectedStream == null) {
          final mp4Muxed = manifest.muxed
              .where((s) => s.container.name.toLowerCase() == 'mp4')
              .sortByVideoQuality();
          if (mp4Muxed.isNotEmpty) {
            selectedStream = mp4Muxed.first;
          }
        }

        // 3. Fallback: itag 18 (360p SD MP4 muxed: H.264 + AAC audio)
        if (selectedStream == null) {
          for (final s in manifest.muxed) {
            if (s.tag == 18) {
              selectedStream = s;
              break;
            }
          }
        }

        // 4. Fallback: Any available muxed stream
        if (selectedStream == null && manifest.muxed.isNotEmpty) {
          selectedStream = manifest.muxed.sortByVideoQuality().first;
        }

        if (selectedStream != null) {
          final ext = selectedStream.container.name.toLowerCase() == 'webm' ? 'webm' : 'mp4';
          final file = File('${dir.path}/${safeBase}_$safeId.$ext');

          try {
            final ok = await _downloadFileFromUrl(
              url: selectedStream.url.toString(),
              targetFile: file,
              downloadKey: videoIdKey,
              isVideo: true,
            );
            if (ok && await file.exists() && await file.length() > 0) {
              completedFile = file;
            }
          } catch (e) {
            debugPrint('[DownloadService] Direct video download stream failed: $e');
          }
        }
      }

      // Tier 3 Fallback: If YouTubeExplode returned no muxed streams or download severed, use Piped muxed video stream
      if (completedFile == null) {
        debugPrint('[DownloadService] Attempting Piped proxy video fallback for "${song.title}"...');
        final pipedVideoUrl = await PipedService.getVideoStream(videoId);
        if (pipedVideoUrl == null || pipedVideoUrl.isEmpty) {
          throw Exception('No playable audio/video muxed stream available for "${song.title}" via YouTube or Piped proxy.');
        }

        final file = File('${dir.path}/${safeBase}_$safeId.mp4');
        await _downloadFileFromUrl(
          url: pipedVideoUrl,
          targetFile: file,
          downloadKey: videoIdKey,
          isVideo: true,
        );
        completedFile = file;
      }

      _activeDownloads[videoIdKey] = DownloadProgress(
        songId: videoIdKey,
        progress: 1.0,
        isCompleted: true,
        localFilePath: completedFile.path,
        isVideo: true,
      );
      _progressController.add(_activeDownloads[videoIdKey]!);
      return completedFile.path;
    } catch (e) {
      debugPrint('[DownloadService] Video download error: $e');
      _activeDownloads[videoIdKey] = DownloadProgress(
        songId: videoIdKey,
        progress: 0.0,
        isFailed: true,
        error: e.toString(),
        isVideo: true,
      );
      _progressController.add(_activeDownloads[videoIdKey]!);
      return null;
    } finally {
      yt.close();
    }
  }
}
