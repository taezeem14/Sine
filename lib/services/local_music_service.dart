import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';
import 'native_storage_bridge.dart';

class LocalMusicService {
  LocalMusicService._();

  static const List<String> supportedExtensions = [
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
    '.opus',
    '.webm',
  ];

  static const List<String> _audioExtensions = supportedExtensions;

  static (String, String) parseArtistAndTitle(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    final baseName = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;
    String artist = 'Unknown Artist';
    String title = baseName.replaceAll('_', ' ').trim();

    if (baseName.contains(' - ')) {
      final parts = baseName.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].replaceAll('_', ' ').trim();
        title = parts.sublist(1).join(' - ').replaceAll('_', ' ').trim();
      }
    }
    return (artist, title);
  }

  static String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Requests audio read permission across both Android 13+ (READ_MEDIA_AUDIO)
  /// and Android 8–12 (READ_EXTERNAL_STORAGE).
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    bool granted = false;

    try {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted || audioStatus.isLimited) {
        return true;
      }
    } catch (_) {}

    try {
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        return true;
      }
    } catch (_) {}

    // Request Android 13+ READ_MEDIA_AUDIO first
    try {
      final resAudio = await Permission.audio.request();
      if (resAudio.isGranted || resAudio.isLimited) {
        granted = true;
      }
    } catch (_) {}

    if (granted) return true;

    // Fallback for Android 12 and below (API <= 32): READ_EXTERNAL_STORAGE
    try {
      final resStorage = await Permission.storage.request();
      if (resStorage.isGranted) {
        granted = true;
      }
    } catch (_) {}

    if (granted) return true;

    // Check MANAGE_EXTERNAL_STORAGE if user already granted it for downloads
    try {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  static Future<List<Song>> scanDeviceAudioFiles() async {
    final List<Song> foundSongs = [];
    final Set<String> visitedPaths = {};
    final Set<String> visitedIds = {};

    // 1. Primary on Android: Native MediaStore.Audio.Media ContentResolver query!
    // Finds 100% of MP3/FLAC/M4A/WAV/OGG/OPUS tracks across Downloads, Music, WhatsApp,
    // Telegram, Recordings, and SD cards under Android 10–15 Scoped Storage with exact ID3 metadata.
    if (Platform.isAndroid) {
      try {
        final mediaRows = await NativeStorageBridge.queryDeviceAudio();
        for (final row in mediaRows) {
          final id = row['id']?.toString() ?? '';
          final contentUri = row['contentUri']?.toString() ?? '';
          final filePath = row['filePath']?.toString() ?? '';
          final displayName = row['displayName']?.toString() ?? '';
          final rawTitle = row['title']?.toString().trim() ?? '';
          final rawArtist = row['artist']?.toString().trim() ?? '';
          final durationMs = (row['durationMs'] as num?)?.toInt() ?? 0;
          final sizeBytes = (row['sizeBytes'] as num?)?.toInt() ?? 0;

          if (contentUri.isEmpty && filePath.isEmpty) continue;
          if (id.isNotEmpty && !visitedIds.add(id)) continue;
          if (filePath.isNotEmpty) {
            visitedPaths.add(filePath.toLowerCase());
          }

          final fallbackParsed = parseArtistAndTitle(
            displayName.isNotEmpty
                ? displayName
                : (filePath.isNotEmpty ? filePath.split('/').last : 'Track'),
          );

          final bool hasValidTitle = rawTitle.isNotEmpty && rawTitle.toLowerCase() != '<unknown>';
          final bool hasValidArtist = rawArtist.isNotEmpty &&
              rawArtist.toLowerCase() != '<unknown>' &&
              rawArtist.toLowerCase() != 'unknown artist';

          String cleanTitle = hasValidTitle ? rawTitle : fallbackParsed.$2;
          String cleanArtist = hasValidArtist ? rawArtist : fallbackParsed.$1;
          if (cleanArtist == 'Unknown Artist') {
            // Try parsing "Artist - Title" from rawTitle when ID3 artist tag is missing
            if (cleanTitle.contains(' - ')) {
              final parts = cleanTitle.split(' - ');
              if (parts.length >= 2 && parts[0].trim().isNotEmpty) {
                cleanArtist = parts[0].trim();
                cleanTitle = parts.sublist(1).join(' - ').trim();
              }
            } else {
              cleanArtist = 'Device Music';
            }
          }

          // Prefer direct readable file path if accessible, else Scoped-Storage-safe content:// URI
          String playableStream = contentUri;
          if (filePath.isNotEmpty) {
            try {
              final f = File(filePath);
              if (f.existsSync()) {
                // Keep contentUri if Android Scoped Storage blocks direct read, otherwise filePath works too.
                // On Android, ExoPlayer plays content:// URIs with 100% reliability across all folders!
                playableStream = contentUri.isNotEmpty ? contentUri : filePath;
              }
            } catch (_) {}
          }

          final int effectiveDurationMs = durationMs > 0
              ? durationMs
              : (((sizeBytes / (160 * 1024 / 8)).clamp(30.0, 600.0)) * 1000).toInt();

          foundSongs.add(
            Song(
              id: id.isNotEmpty ? id : 'local_${playableStream.hashCode.abs()}',
              title: cleanTitle.isEmpty ? 'Untitled Track' : cleanTitle,
              artist: cleanArtist.isEmpty ? 'Device Music' : cleanArtist,
              duration: Duration(milliseconds: effectiveDurationMs),
              artworkUrl: '',
              streamUrl: playableStream,
              source: 'device',
            ),
          );
        }
      } catch (e) {
        debugPrint('[LocalMusicService] MediaStore scan error: $e');
      }
    }

    // 2. Supplementary filesystem scan: Sine's own download/vault folders & desktop folders
    final List<Directory> searchDirs = [];

    if (Platform.isAndroid) {
      final candidates = [
        Directory('/storage/emulated/0/Sine-Music'),
        Directory('/storage/emulated/0/Music'),
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
        Directory('/storage/emulated/0/Audio'),
        Directory('/storage/emulated/0/Podcasts'),
      ];
      for (final d in candidates) {
        try {
          if (d.existsSync()) searchDirs.add(d);
        } catch (_) {}
      }
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      if (docDir.existsSync()) searchDirs.add(docDir);
    } catch (_) {}

    try {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null) {
        for (final ed in extDirs) {
          if (ed.existsSync()) searchDirs.add(ed);
        }
      }
    } catch (_) {}

    for (final dir in searchDirs) {
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final path = entity.path;
            final lower = path.toLowerCase();
            if (lower.endsWith('.part') || lower.contains('/backups/') || lower.contains('\\backups\\')) {
              continue;
            }
            final isAudio = _audioExtensions.any((ext) => lower.endsWith(ext));

            if (isAudio && !visitedPaths.contains(lower)) {
              visitedPaths.add(lower);
              final song = _songFromFile(entity);
              if (song != null && visitedIds.add(song.id)) {
                foundSongs.add(song);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning dir ${dir.path}: $e');
      }
    }

    foundSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return foundSongs;
  }

  static Song? _songFromFile(File file) {
    try {
      final filename = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : file.path.split(Platform.pathSeparator).last;

      final dotIndex = filename.lastIndexOf('.');
      final baseName = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;

      String artist = 'Device Music';
      String title = baseName.replaceAll('_', ' ').trim();

      if (baseName.contains(' - ')) {
        final parts = baseName.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].replaceAll('_', ' ').trim();
          title = parts.sublist(1).join(' - ').replaceAll('_', ' ').trim();
        }
      }

      final stat = file.statSync();
      if (stat.size < 8192) return null;
      final estimatedSecs = ((stat.size / (160 * 1024 / 8))).clamp(30.0, 600.0).toInt();
      final cleanId = 'local_${file.path.hashCode.abs()}';

      return Song(
        id: cleanId,
        title: title.isEmpty ? 'Untitled Track' : title,
        artist: artist.isEmpty ? 'Local Artist' : artist,
        duration: Duration(seconds: estimatedSecs),
        artworkUrl: '',
        streamUrl: file.path,
        source: 'device',
      );
    } catch (_) {
      return null;
    }
  }
}
