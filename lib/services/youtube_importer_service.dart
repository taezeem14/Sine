import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import '../models/song.dart';
import '../models/playlist.dart';
import 'piped_service.dart';
import 'log_service.dart';

enum YouTubeImportType { video, playlist, unknown }

class YouTubeImportResult {
  final YouTubeImportType type;
  final Song? song;
  final Playlist? playlist;
  final String? error;

  const YouTubeImportResult({
    required this.type,
    this.song,
    this.playlist,
    this.error,
  });
}

class MixContinuationResult {
  final List<Song> songs;
  final String? continuationToken;
  final String? nextVideoId;
  final String? nextParams;

  const MixContinuationResult({
    required this.songs,
    this.continuationToken,
    this.nextVideoId,
    this.nextParams,
  });
}

class YouTubeImporterService {
  static YouTubeImportType detectUrlType(String url) {
    final clean = url.trim();
    if (clean.contains('list=') || clean.contains('/playlist')) {
      return YouTubeImportType.playlist;
    }
    if (clean.contains('watch?v=') || clean.contains('youtu.be/') || clean.contains('/shorts/')) {
      return YouTubeImportType.video;
    }
    return YouTubeImportType.unknown;
  }

  static String? extractVideoId(String url) {
    try {
      return VideoId.parseVideoId(url.trim());
    } catch (_) {
      final regExp = RegExp(r'(?:v=|\/)([0-9A-Za-z_-]{11})');
      final match = regExp.firstMatch(url);
      return match?.group(1);
    }
  }

  static String? extractPlaylistId(String url) {
    try {
      return PlaylistId.parsePlaylistId(url.trim());
    } catch (_) {
      final regExp = RegExp(r'list=([0-9A-Za-z_-]+)');
      final match = regExp.firstMatch(url);
      return match?.group(1);
    }
  }

  static Duration parseDurationText(String? text) {
    if (text == null || text.trim().isEmpty) {
      return const Duration(minutes: 3, seconds: 30);
    }
    final parts = text.trim().split(':');
    try {
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      } else if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return const Duration(minutes: 3, seconds: 30);
  }

  static final YoutubeExplode _yt = YoutubeExplode();
  static const int _maxCacheEntries = 100;
  static final Map<String, ({List<String> urls, DateTime cachedAt})> _streamCache = {};

  static void _cacheStreams(String cleanId, List<String> urls) {
    if (_streamCache.length >= _maxCacheEntries) {
      _streamCache.remove(_streamCache.keys.first);
    }
    _streamCache[cleanId] = (urls: List.from(urls), cachedAt: DateTime.now());
  }

  /// Invalidate cached stream URLs for a video ID if playback fails
  static void invalidateCache(String videoId) {
    final cleanId = videoId.replaceFirst('yt_', '').trim();
    _streamCache.remove(cleanId);
    _streamCache.remove('${cleanId}_high');
    _streamCache.remove('${cleanId}_medium');
    _streamCache.remove('${cleanId}_dataSaver');
    _streamCache.remove('${cleanId}_mp4');
  }

  /// Clears all stream caches across the application
  static void clearAllCaches() {
    _streamCache.clear();
  }

  /// Safely extracts text from InnerTube runs or simpleText maps
  static String? _extractText(dynamic obj) {
    if (obj is! Map) return null;
    final runs = obj['runs'];
    if (runs is List && runs.isNotEmpty && runs.first is Map) {
      return runs.first['text'] as String?;
    }
    return obj['simpleText'] as String?;
  }

  /// Smart YouTube metadata cleaner: accurately extracts song title & artist,
  /// correcting for inverted "Title - Artist" vs "Artist - Title", stripping YouTube topic/VEVO suffixes,
  /// and handling quotes or "by" patterns.
  static ({String cleanTitle, String cleanArtist, String searchQuery}) parseYouTubeMetadata(String rawTitle, String rawAuthor) {
    // 1. Clean author / channel name
    String cleanAuthor = rawAuthor.trim();
    // Strip " - Topic", " (Topic)", " Topic"
    cleanAuthor = cleanAuthor.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '').trim();
    cleanAuthor = cleanAuthor.replaceAll(RegExp(r'\s*\(Topic\)$', caseSensitive: false), '').trim();
    cleanAuthor = cleanAuthor.replaceAll(RegExp(r'\s+Topic$', caseSensitive: false), '').trim();

    // Strip "VEVO" / "vevo" suffix
    if (cleanAuthor.toLowerCase().endsWith('vevo') && cleanAuthor.length > 4) {
      cleanAuthor = cleanAuthor.substring(0, cleanAuthor.length - 4).trim();
    }
    // Strip " Official Channel", " Official"
    cleanAuthor = cleanAuthor.replaceAll(RegExp(r'\s*Official(\s+Channel)?$', caseSensitive: false), '').trim();

    // Strip generic YouTube channel names
    final lowerAuthor = cleanAuthor.toLowerCase();
    final isPublisherOrCurator = lowerAuthor.contains('records') ||
        lowerAuthor.contains('record') ||
        lowerAuthor.contains('series') ||
        lowerAuthor.contains('studio') ||
        lowerAuthor.contains('studios') ||
        lowerAuthor.contains('company') ||
        lowerAuthor.contains('label') ||
        lowerAuthor.contains('nation') ||
        lowerAuthor.contains('clouds') ||
        lowerAuthor.contains('chill') ||
        lowerAuthor.contains('entertainment') ||
        lowerAuthor.contains('media') ||
        lowerAuthor.contains('lofi') ||
        lowerAuthor.contains('slowed') ||
        lowerAuthor.contains('reverb') ||
        lowerAuthor.contains('vibes') ||
        lowerAuthor.contains('edits') ||
        cleanAuthor == 'YouTube' ||
        cleanAuthor == 'Unknown Artist';

    // 2. Initial title cleaning (strip common YouTube junk: official video, audio, 4K, visualizer, etc.)
    var t = rawTitle
        .replaceAll(RegExp(r'\((?:official\s*(?:music\s*)?video|official\s*audio|lyrics?|hd|4k|visualizer|remastered|prod\.|video|audio).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(?:official\s*(?:music\s*)?video|official\s*audio|lyrics?|hd|4k|visualizer|remastered|prod\.|video|audio).*?\]', caseSensitive: false), '')
        .trim();

    String? pipeArtist;
    if (t.contains('|')) {
      final segments = t.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (int i = 1; i < segments.length; i++) {
        final seg = segments[i];
        final singerMatch = RegExp(r'^(?:singers?|artist|vocals?|performed\s+by|sung\s+by|music|feat\.?|ft\.?)\s*[:\-]?\s*(.+)$', caseSensitive: false).firstMatch(seg);
        if (singerMatch != null) {
          pipeArtist = singerMatch.group(1)?.trim();
          break;
        } else if (cleanAuthor.isNotEmpty && !isPublisherOrCurator && seg.toLowerCase().contains(cleanAuthor.toLowerCase())) {
          pipeArtist = cleanAuthor;
          break;
        }
      }
      if (pipeArtist == null && isPublisherOrCurator && segments.length >= 2) {
        final lastSeg = segments.last;
        if (!lastSeg.toLowerCase().contains('official') && !lastSeg.toLowerCase().contains('video')) {
          pipeArtist = lastSeg;
        }
      }
      t = segments.isNotEmpty ? segments.first : t;
    }

    String candidateArtist = pipeArtist ?? '';
    String candidateTitle = t;

    // Check for "Title" by Artist pattern
    final byMatch = RegExp(r'^(.*?)\s+by\s+(.*?)$', caseSensitive: false).firstMatch(t);
    final delimiterMatch = RegExp(r'\s+[-–—:]\s*|\s*[-–—:]\s+').firstMatch(t);
    if (byMatch != null) {
      candidateTitle = byMatch.group(1)?.trim() ?? t;
      candidateArtist = byMatch.group(2)?.trim() ?? '';
    } else if (delimiterMatch != null) {
      final partA = t.substring(0, delimiterMatch.start).trim();
      final partB = t.substring(delimiterMatch.end).trim();

      if (partA.isNotEmpty && partB.isNotEmpty) {

        // Check if one of the parts is enclosed in quotes -> Quotes ALWAYS indicate Title
        final aQuoted = (partA.startsWith('"') && partA.endsWith('"')) ||
            (partA.startsWith('“') && partA.endsWith('”')) ||
            (partA.startsWith("'") && partA.endsWith("'"));
        final bQuoted = (partB.startsWith('"') && partB.endsWith('"')) ||
            (partB.startsWith('“') && partB.endsWith('”')) ||
            (partB.startsWith("'") && partB.endsWith("'"));

        if (aQuoted && !bQuoted) {
          // "Song Title" - Artist
          candidateTitle = partA;
          candidateArtist = partB;
        } else if (bQuoted && !aQuoted) {
          // Artist - "Song Title"
          candidateArtist = partA;
          candidateTitle = partB;
        } else {
          // Compare both parts against cleanAuthor (if cleanAuthor is an artist)
          final normAuthor = cleanAuthor.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final normA = partA.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          final normB = partB.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

          final matchA = normAuthor.length >= 3 && (normA == normAuthor || normA.contains(normAuthor) || normAuthor.contains(normA));
          final matchB = normAuthor.length >= 3 && (normB == normAuthor || normB.contains(normAuthor) || normAuthor.contains(normB));

          if (matchB && !matchA) {
            // "Song Title - Artist" format! e.g. "Blinding Lights - The Weeknd"
            candidateTitle = partA;
            candidateArtist = partB;
          } else if (matchA && !matchB) {
            // Standard "Artist - Song Title" format! e.g. "The Weeknd - Blinding Lights"
            candidateArtist = partA;
            candidateTitle = partB;
          } else {
            // Check if one part has movie/soundtrack indicators
            final bHasMovieIndicators = RegExp(r'\b(from\s+["“\x27]?|movie|film|soundtrack|ost|brahm[aā]stra|aashiqui|jawan|animal|pathaan|kabir\s+singh|pushpa)\b', caseSensitive: false).hasMatch(partB);
            final aHasMovieIndicators = RegExp(r'\b(from\s+["“\x27]?|movie|film|soundtrack|ost|brahm[aā]stra|aashiqui|jawan|animal|pathaan|kabir\s+singh|pushpa)\b', caseSensitive: false).hasMatch(partA);

            if (bHasMovieIndicators && !aHasMovieIndicators) {
              candidateTitle = partA;
              candidateArtist = pipeArtist ?? (cleanAuthor.isNotEmpty && !isPublisherOrCurator ? cleanAuthor : '');
            } else if (aHasMovieIndicators && !bHasMovieIndicators) {
              candidateTitle = partB;
              candidateArtist = pipeArtist ?? (cleanAuthor.isNotEmpty && !isPublisherOrCurator ? cleanAuthor : '');
            } else {
              // Community / Curator Upload check:
              // Curator channels (lofi, slowed, reverb, studio, edits, records) or titles with audio modifiers
              // almost universally use "Song Title - Artist" (e.g. "Wishes - Hasan Raheem", "Heat Waves - Glass Animals")
              final isCuratorOrRemix = isPublisherOrCurator ||
                  RegExp(r'\b(slowed|reverb|lofi|remix|speed\s*up|sped\s*up|nightcore|flip|edit)\b', caseSensitive: false).hasMatch(rawTitle) ||
                  RegExp(r'\b(slowed|reverb|lofi|remix|speed\s*up|sped\s*up|nightcore|flip|edit)\b', caseSensitive: false).hasMatch(cleanAuthor);

              if (isCuratorOrRemix) {
                // Song Title - Artist format
                candidateTitle = partA;
                candidateArtist = partB;
              } else {
                // Check if one part has explicit title keywords like "Song", "Audio", "Official"
                final aHasTitleKeywords = RegExp(r'\b(song|track|audio|theme|remix|acoustic|live|cover|version)\b', caseSensitive: false).hasMatch(partA);
                final bHasTitleKeywords = RegExp(r'\b(song|track|audio|theme|remix|acoustic|live|cover|version)\b', caseSensitive: false).hasMatch(partB);

                if (aHasTitleKeywords && !bHasTitleKeywords) {
                  candidateTitle = partA;
                  candidateArtist = partB;
                } else {
                  // Default to standard "Artist - Title"
                  candidateArtist = partA;
                  candidateTitle = partB;
                }
              }
            }
          }
        }
      }
    }

    // 3. Fallback artist assignment if title had no delimiter
    String finalArtist = candidateArtist
        .replaceAll(RegExp(r'\(.*\)|\[.*\]', caseSensitive: false), '')
        .trim();
    if (finalArtist.isEmpty && cleanAuthor.isNotEmpty && !isPublisherOrCurator) {
      finalArtist = cleanAuthor.trim();
    }

    // 4. Polish title: strip outer quotes and remaining bracketed video tags
    String finalTitle = candidateTitle
        .replaceAll(RegExp(r'^["“\x27]|["”\x27]$'), '')
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(?:official|video|audio|lyrics|hd|4k|full song|lyric video)\b', caseSensitive: false), '')
        .trim();

    if (finalTitle.isEmpty) {
      finalTitle = t.isNotEmpty ? t : (rawTitle.trim().isNotEmpty ? rawTitle.trim() : 'YouTube Song');
    }

    // Strip outer quotes and prefixes on artist as well
    finalArtist = finalArtist
        .replaceFirst(RegExp(r'^(?:singers?|artists?)\s*:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^["“\x27]|["”\x27]$'), '')
        .trim();

    final searchQuery = finalArtist.isNotEmpty ? '$finalTitle $finalArtist' : finalTitle;
    return (
      cleanTitle: finalTitle,
      cleanArtist: finalArtist,
      searchQuery: searchQuery,
    );
  }

  /// Returns all playable audio streams for a YouTube video ID in order of preference:
  /// 1. MP4 / AAC streams (optimal hardware decoding on Android)
  /// 2. WebM / Opus streams (audiophile audio quality)
  /// 3. Muxed MP4 stream fallback
  static const Duration _streamCacheTtl = Duration(minutes: 30);
  static String preferredQuality = 'high'; // 'high', 'medium', 'dataSaver'

  /// Multi-client InnerTube stream extractor: cascades through client profiles to bypass 403 Forbidden
  static Future<List<String>> getAudioStreamUrls(
    String videoId, {
    bool preferProgressiveMp4 = false,
  }) async {
    final cleanId = videoId.replaceFirst('yt_', '').trim();
    if (cleanId.isEmpty) return [];

    final cacheKey = '${cleanId}_${preferProgressiveMp4 ? 'mp4' : preferredQuality}';
    final cached = _streamCache[cacheKey];
    if (cached != null && cached.urls.isNotEmpty && DateTime.now().difference(cached.cachedAt) < _streamCacheTtl) {
      return List.from(cached.urls);
    }

    // Client cascade priority based on yt-dlp / NewPipe resilience:
    // 1. androidSdkless: Standard high-bitrate AAC/Opus, no androidSdkVersion check (avoids PO token)
    // 2. ios: Uses clean iOS InnerTube endpoint, immune to JS signature cipher
    // 3. androidVr: Meta Quest 3 endpoint, often bypasses regular mobile rate-limits
    // 4. androidMusic: YouTube Music endpoint, dedicated audio streams
    final clientProfiles = [
      [YoutubeApiClient.androidSdkless],
      [YoutubeApiClient.ios],
      [YoutubeApiClient.androidVr],
      [YoutubeApiClient.androidMusic],
    ];

    for (final clients in clientProfiles) {
      try {
        final clientName = clients.first.payload['context']['client']['clientName'] ?? 'InnerTube';
        LogService.stream('YouTubeEngine', 'Querying InnerTube manifest for $cleanId using $clientName...');

        final manifest = await _yt.videos.streamsClient.getManifest(
          cleanId,
          ytClients: clients,
          requireWatchPage: false,
        ).timeout(const Duration(seconds: 6));

        final candidates = <String>[];

        final muxedMp4 = manifest.muxed.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
        final mp4Audio = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4').toList();
        final webmAudio = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'webm').toList();

        // Rock-solid stream candidate ordering (from proven v1.0.8 architecture):
        // 1. Primary (Fastest & 100% Reliable): Progressive Muxed MP4 (itag 18, 360p container with AAC audio)
        // Instant hardware decoding on all Android devices, completely immune to DASH cipher throttling & PO-token 403 blocks
        if (muxedMp4.isNotEmpty) {
          candidates.add(muxedMp4.withHighestBitrate().url.toString());
        }

        // 2. Secondary Fallback: Standalone MP4 AAC (itag 140, ~128 kbps)
        if (mp4Audio.isNotEmpty) {
          candidates.add(mp4Audio.withHighestBitrate().url.toString());
        }

        // 3. Tertiary Fallback: Standalone WebM Opus (itag 251, ~160 kbps)
        if (webmAudio.isNotEmpty) {
          candidates.add(webmAudio.withHighestBitrate().url.toString());
        }
        if (candidates.isNotEmpty) {
          LogService.stream('YouTubeEngine', 'InnerTube resolved ${candidates.length} candidate(s) via $clientName for $cleanId');
          _cacheStreams(cacheKey, candidates);
          return candidates;
        }
      } catch (e) {
        LogService.w('YouTubeEngine', 'InnerTube attempt failed for $cleanId: $e');
        continue;
      }
    }

    // Tier 3: High-speed Piped API proxy fallback
    try {
      LogService.stream('YouTubeEngine', 'Attempting Piped proxy fallback for $cleanId...');
      final pipedUrl = await PipedService.getAudioStream(cleanId);
      if (pipedUrl != null && pipedUrl.isNotEmpty) {
        LogService.stream('YouTubeEngine', 'Piped proxy succeeded for $cleanId');
        _cacheStreams(cacheKey, [pipedUrl]);
        return [pipedUrl];
      }
    } catch (e) {
      LogService.w('YouTubeEngine', 'Piped proxy fallback error for $cleanId: $e');
      debugPrint('[YouTube] Piped proxy fallback error for $cleanId: $e');
    }

    LogService.w('YouTubeEngine', 'No audio stream could be extracted for $cleanId');
    return [];
  }

  /// Resolve direct playable audio stream URL from a YouTube video ID.
  static Future<String?> getAudioStreamUrl(String videoId) async {
    final urls = await getAudioStreamUrls(videoId);
    return urls.isNotEmpty ? urls.first : null;
  }

  /// Non-blocking prefetch of streams for the first few tracks of a playlist
  static void prefetchPlaylistStreams(List<Song> songs) {
    int delay = 0;
    for (final song in songs.take(3)) {
      final vid = extractVideoId(song.streamUrl) ?? (song.id.startsWith('yt_') ? song.id.replaceFirst('yt_', '') : null);
      if (vid != null && vid.isNotEmpty) {
        Future.delayed(Duration(milliseconds: delay), () {
          getAudioStreamUrl(vid).catchError((_) => null);
        });
        delay += 250;
      }
    }
  }

  /// Resolve any song's stream URL into a directly playable media stream
  static Future<String?> resolvePlayableUrl(Song song) async {
    final s = song.streamUrl;
    if (s.contains('youtube.com/watch') || s.contains('youtu.be/') || song.id.startsWith('yt_')) {
      final vid = extractVideoId(s) ?? (song.id.startsWith('yt_') ? song.id.replaceFirst('yt_', '') : null);
      if (vid != null && vid.isNotEmpty) {
        final stream = await getAudioStreamUrl(vid);
        if (stream != null && stream.isNotEmpty) {
          return stream;
        }
      }
      return null; // Return null so audio player never tries to play an HTML webpage
    }
    return s;
  }


  /// Result of fetching a mix continuation batch
  static Future<MixContinuationResult?> fetchNextMixBatch({
    required String playlistId,
    String? continuationToken,
    String? currentVideoId,
    String? currentParams,
    Set<String>? seenIds,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        "context": {
          "client": {
            "clientName": "WEB",
            "clientVersion": "2.20240101.00.00",
            "hl": "en",
            "gl": "US"
          }
        },
      };

      if (continuationToken != null && continuationToken.isNotEmpty) {
        requestBody["continuation"] = continuationToken;
      } else {
        if (currentVideoId != null && currentVideoId.isNotEmpty) {
          requestBody["videoId"] = currentVideoId;
        }
        requestBody["playlistId"] = playlistId;
        if (currentParams != null && currentParams.isNotEmpty) {
          requestBody["params"] = currentParams;
        }
      }

      final resp = await http.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/next?prettyPrint=false'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final plData = json['continuationContents']?['playlistPanelContinuation'] ??
          json['contents']?['twoColumnWatchNextResults']?['playlist']?['playlist'];
      if (plData == null) return null;

      final contents = plData['contents'] as List? ?? [];
      final songs = <Song>[];
      final seen = seenIds ?? <String>{};
      String? nextContinuation;
      String? nextVid;
      String? nextPrm;

      for (final item in contents) {
        final contRenderer = item['continuationItemRenderer'];
        if (contRenderer != null) {
          nextContinuation = contRenderer['continuationEndpoint']?['continuationCommand']?['token'] as String?;
          continue;
        }

        final renderer = item['playlistPanelVideoRenderer'];
        if (renderer != null) {
          final vId = renderer['videoId'] as String?;
          if (vId == null || vId.isEmpty) continue;

          if (!seen.contains(vId)) {
            seen.add(vId);
            final trackTitle = _extractText(renderer['title']) ?? 'YouTube Track';
            final trackAuthor = _extractText(renderer['shortBylineText']) ?? 'YouTube Artist';
            final meta = parseYouTubeMetadata(trackTitle, trackAuthor);
            final durText = _extractText(renderer['lengthText']);
            final thumbs = renderer['thumbnail']?['thumbnails'] as List?;
            var art = (thumbs != null && thumbs.isNotEmpty)
                ? (thumbs.last['url'] as String? ?? 'https://i.ytimg.com/vi/$vId/hqdefault.jpg')
                : 'https://i.ytimg.com/vi/$vId/hqdefault.jpg';
            if (art.startsWith('//')) {
              art = 'https:$art';
            }

            songs.add(
              Song(
                id: 'yt_$vId',
                title: meta.cleanTitle,
                artist: meta.cleanArtist.isNotEmpty ? meta.cleanArtist : trackAuthor,
                duration: parseDurationText(durText),
                artworkUrl: art,
                streamUrl: 'https://www.youtube.com/watch?v=$vId',
                source: 'youtube_mix',
              ),
            );
          }

          final endpoint = renderer['navigationEndpoint']?['watchEndpoint'];
          if (endpoint != null) {
            nextVid = endpoint['videoId'] as String?;
            nextPrm = endpoint['params'] as String?;
          }
        }
      }

      if (nextContinuation == null) {
        final contList = plData['continuations'] as List?;
        if (contList != null && contList.isNotEmpty) {
          nextContinuation = contList[0]?['nextContinuationData']?['continuation'] as String?;
        }
      }

      return MixContinuationResult(
        songs: songs,
        continuationToken: nextContinuation,
        nextVideoId: nextVid,
        nextParams: nextPrm,
      );
    } catch (e) {
      debugPrint('[YouTubeImporterService] Error fetching next mix batch: $e');
      return null;
    }
  }

  /// NewPipe-style extraction for YouTube Mixes (list=RD..., list=RDMM, radio mixes)
  /// Fetches initial batches dynamically and retains continuation token for infinite playback
  static Future<Playlist?> _importYouTubeMix(String? videoId, String playlistId) async {
    try {
      final songs = <Song>[];
      final seenIds = <String>{};
      String title = 'YouTube Mix';
      String author = 'YouTube Mix';
      String? currentVideoId = videoId;
      if (currentVideoId == null && playlistId.startsWith('RD') && playlistId.length >= 13) {
        currentVideoId = playlistId.substring(2, 13);
      }
      String? currentParams;
      String? continuationToken;

      // Fetch initial batches (up to 4 pages yielding 50-100 tracks to start immediately)
      for (int page = 0; page < 4; page++) {
        final result = await fetchNextMixBatch(
          playlistId: playlistId,
          continuationToken: continuationToken,
          currentVideoId: currentVideoId,
          currentParams: currentParams,
          seenIds: seenIds,
        );

        if (result == null) break;

        if (result.continuationToken != null) continuationToken = result.continuationToken;
        if (result.nextVideoId != null) currentVideoId = result.nextVideoId;
        if (result.nextParams != null) currentParams = result.nextParams;

        if (result.songs.isEmpty) {
          if (continuationToken == null && currentVideoId == null) break;
          continue;
        }

        if (page == 0 && songs.isEmpty) {
          final first = result.songs.first;
          title = 'Mix - ${first.title}';
          author = first.artist;
        }

        songs.addAll(result.songs);

        if (continuationToken == null && currentVideoId == null) break;
      }

      if (songs.isNotEmpty) {
        prefetchPlaylistStreams(songs);
        return Playlist(
          id: 'yt_mix_$playlistId',
          title: title,
          description: 'YouTube Mix • $author • Infinite Queue',
          songs: songs,
          createdAt: DateTime.now(),
          coverUrl: songs.first.artworkUrl,
          continuationToken: continuationToken,
        );
      }
    } catch (e) {
      debugPrint('Error importing YouTube Mix via next endpoint: $e');
    }
    return null;
  }

  /// Import either a video, standard playlist, or Mix from any YouTube / YouTube Music URL
  static Future<YouTubeImportResult> importFromUrl(String url) async {
    final clean = url.trim();
    final type = detectUrlType(clean);

    if (type == YouTubeImportType.playlist) {
      final playlistId = extractPlaylistId(clean);
      final videoId = extractVideoId(clean);

      if (playlistId == null) {
        return const YouTubeImportResult(type: YouTubeImportType.unknown, error: 'Invalid YouTube Playlist URL');
      }

      // 1. If this is a YouTube Mix (RD..., RDMM, RDEM, RDCLAK...) or contains a video context, try Mix parser first
      if (playlistId.startsWith('RD') || playlistId.startsWith('UL') || clean.contains('list=RD')) {
        final mixPlaylist = await _importYouTubeMix(videoId, playlistId);
        if (mixPlaylist != null && mixPlaylist.songs.isNotEmpty) {
          return YouTubeImportResult(type: YouTubeImportType.playlist, playlist: mixPlaylist);
        }
      }

      // 2. Standard user or channel playlist via youtube_explode_dart
      try {
        String title = 'YouTube Playlist';
        String description = 'Imported YouTube Playlist';
        String? coverUrl;

        try {
          final ytPlaylist = await _yt.playlists.get(playlistId);
          if (ytPlaylist.title.isNotEmpty) title = ytPlaylist.title;
          description = ytPlaylist.description;
        } catch (_) {}

        final songs = <Song>[];
        try {
          await for (final video in _yt.playlists.getVideos(playlistId).take(500)) {
            final trackId = 'yt_${video.id.value}';
            final artwork = video.thumbnails.highResUrl.isNotEmpty
                ? video.thumbnails.highResUrl
                : video.thumbnails.standardResUrl;

            final meta = parseYouTubeMetadata(video.title, video.author);
            songs.add(
              Song(
                id: trackId,
                title: meta.cleanTitle,
                artist: meta.cleanArtist.isNotEmpty ? meta.cleanArtist : video.author,
                duration: video.duration ?? const Duration(minutes: 3, seconds: 30),
                artworkUrl: artwork,
                streamUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
                source: 'youtube',
              ),
            );
          }
        } catch (e) {
          debugPrint('getVideos fallback triggered: $e');
        }

        // 3. If youtube_explode yielded no videos, fallback to YouTube next API
        if (songs.isEmpty) {
          final fallbackMix = await _importYouTubeMix(videoId, playlistId);
          if (fallbackMix != null && fallbackMix.songs.isNotEmpty) {
            return YouTubeImportResult(type: YouTubeImportType.playlist, playlist: fallbackMix);
          }
          return const YouTubeImportResult(type: YouTubeImportType.playlist, error: 'No playable tracks found in playlist');
        }

        prefetchPlaylistStreams(songs);
        coverUrl = songs.isNotEmpty ? songs.first.artworkUrl : null;
        final playlist = Playlist(
          id: 'yt_pl_$playlistId',
          title: title,
          description: description,
          songs: songs,
          createdAt: DateTime.now(),
          coverUrl: coverUrl,
        );

        return YouTubeImportResult(type: YouTubeImportType.playlist, playlist: playlist);
      } catch (e) {
        return YouTubeImportResult(type: YouTubeImportType.playlist, error: e.toString());
      }
    } else if (type == YouTubeImportType.video) {
      final videoId = extractVideoId(clean);
      if (videoId == null) {
        return const YouTubeImportResult(type: YouTubeImportType.unknown, error: 'Invalid YouTube Video URL');
      }

      try {
        final video = await _yt.videos.get(videoId);
        final streamUrl = 'https://www.youtube.com/watch?v=$videoId';
        final artwork = video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.standardResUrl;

        final meta = parseYouTubeMetadata(video.title, video.author);
        final song = Song(
          id: 'yt_${video.id.value}',
          title: meta.cleanTitle,
          artist: meta.cleanArtist.isNotEmpty ? meta.cleanArtist : video.author,
          duration: video.duration ?? const Duration(minutes: 3, seconds: 30),
          artworkUrl: artwork,
          streamUrl: streamUrl,
          source: 'youtube',
        );

        return YouTubeImportResult(type: YouTubeImportType.video, song: song);
      } catch (e) {
        return YouTubeImportResult(type: YouTubeImportType.video, error: e.toString());
      }
    }

    return const YouTubeImportResult(type: YouTubeImportType.unknown, error: 'Unrecognized YouTube URL');
  }

  /// Alias for searchYouTube
  static Future<List<Song>> searchInnerTube(String query, {int limit = 50}) =>
      searchYouTube(query, limit: limit);

  /// NewPipe-style InnerTube music search returning full-length tracks with high-resolution thumbnails
  static Future<List<Song>> searchYouTube(String query, {int limit = 50}) async {
    try {
      final body = jsonEncode({
        "context": {
          "client": {
            "clientName": "WEB",
            "clientVersion": "2.20240101.00.00",
            "hl": "en",
            "gl": "US",
          }
        },
        "query": query,
      });

      final resp = await http.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        body: body,
      ).timeout(const Duration(seconds: 7));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final sections = json['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List? ?? [];
        final songs = <Song>[];

        for (final sec in sections) {
          final items = sec['itemSectionRenderer']?['contents'] as List? ?? [];
          for (final item in items) {
            final v = item['videoRenderer'];
            if (v != null) {
              final vId = v['videoId'] as String?;
              if (vId == null || vId.isEmpty) continue;

              final title = _extractText(v['title']) ?? 'YouTube Song';
              final author = _extractText(v['ownerText']) ?? _extractText(v['shortBylineText']) ?? 'YouTube';
              final durText = v['lengthText']?['simpleText'] as String?;
              final meta = parseYouTubeMetadata(title, author);

              songs.add(
                Song(
                  id: 'yt_$vId',
                  title: meta.cleanTitle,
                  artist: meta.cleanArtist.isNotEmpty ? meta.cleanArtist : author,
                  duration: parseDurationText(durText),
                  artworkUrl: 'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
                  streamUrl: 'https://www.youtube.com/watch?v=$vId',
                  source: 'youtube',
                ),
              );

              if (songs.length >= limit) break;
            }
          }
          if (songs.length >= limit) break;
        }

        if (songs.isNotEmpty) return songs;
      }
    } catch (e) {
      debugPrint('InnerTube search error: $e');
    }

    // Fallback 1: YoutubeExplode search
    try {
      final searchList = await _yt.search.search(query).timeout(const Duration(seconds: 6));
      final fallbackSongs = <Song>[];
      for (final video in searchList.take(limit)) {
        final meta = parseYouTubeMetadata(video.title, video.author);
        fallbackSongs.add(
          Song(
            id: 'yt_${video.id.value}',
            title: meta.cleanTitle,
            artist: meta.cleanArtist.isNotEmpty ? meta.cleanArtist : video.author,
            duration: video.duration ?? const Duration(minutes: 3, seconds: 30),
            artworkUrl: video.thumbnails.highResUrl.isNotEmpty
                ? video.thumbnails.highResUrl
                : 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg',
            streamUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
            source: 'youtube',
          ),
        );
      }
      if (fallbackSongs.isNotEmpty) {
        debugPrint('[YouTube Search] Fallback via YoutubeExplode found ${fallbackSongs.length} tracks');
        return fallbackSongs;
      }
    } catch (e) {
      debugPrint('[YouTube Search] YoutubeExplode fallback error: $e');
    }

    // Fallback 2: Piped API search
    try {
      final pipedItems = await PipedService.search(query);
      if (pipedItems.isNotEmpty) {
        final pipedSongs = pipedItems.take(limit).map((item) {
          final rawUrl = item['url'] as String? ?? '';
          final vid = extractVideoId(rawUrl) ?? rawUrl.replaceFirst('/watch?v=', '').split('&').first.trim();
          final durSecs = (item['duration'] as num?)?.toInt() ?? 210;
          final rawTitle = item['title'] as String? ?? 'YouTube Track';
          final rawAuthor = item['uploaderName'] as String? ?? 'Artist';
          final meta = parseYouTubeMetadata(rawTitle, rawAuthor);
          return Song(
            id: 'yt_$vid',
            title: meta.cleanTitle,
            artist: meta.cleanArtist.isNotEmpty ? meta.cleanArtist : rawAuthor,
            duration: Duration(seconds: durSecs),
            artworkUrl: item['thumbnail'] as String? ?? (vid.isNotEmpty ? 'https://i.ytimg.com/vi/$vid/hqdefault.jpg' : ''),
            streamUrl: 'https://www.youtube.com/watch?v=$vid',
            source: 'youtube',
          );
        }).toList();
        if (pipedSongs.isNotEmpty) {
          debugPrint('[YouTube Search] Fallback via Piped found ${pipedSongs.length} tracks');
          return pipedSongs;
        }
      }
    } catch (e) {
      debugPrint('[YouTube Search] Piped search fallback error: $e');
    }

    return [];
  }
}
