import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'youtube_importer_service.dart';
import 'log_service.dart';

class StreamResolverService {
  static const int _maxCacheEntries = 100;
  static final Map<String, ({List<String> streams, DateTime cachedAt})> _resolvedCache = {};
  static final Map<String, Future<List<String>>> _inFlightResolutions = {};

  static void _cacheStreams(String key, List<String> streams) {
    if (!_resolvedCache.containsKey(key) && _resolvedCache.length >= _maxCacheEntries) {
      _resolvedCache.remove(_resolvedCache.keys.first);
    }
    _resolvedCache[key] = (streams: List<String>.from(streams), cachedAt: DateTime.now());
  }

  /// Invalidate cached stream candidates for a song if playback fails
  static void invalidateCache(String key) {
    _resolvedCache.remove(key);
  }

  /// Manually cache a verified working stream (e.g. from fallback proxy)
  static void cacheStream(String key, String streamUrl) {
    _cacheStreams(key, [streamUrl]);
  }

  /// Clears all stream caches across the application
  static void clearAllCaches() {
    _resolvedCache.clear();
    _inFlightResolutions.clear();
  }

  static final Set<String> _currentlyPreloading = {};

  /// Checks if a song has already been pre-resolved into memory cache (valid for 30 minutes)
  static bool isPreloaded(Song song) {
    final cacheKey = song.id.isNotEmpty ? song.id : song.streamUrl;
    final cached = _resolvedCache[cacheKey];
    return cached != null && cached.streams.isNotEmpty && DateTime.now().difference(cached.cachedAt).inMinutes < 30;
  }

  /// Prefetch playable audio stream for a track in the background (WINDOW_SIZE = 1)
  static void prefetchPlayableStreams(Song song) {
    final cacheKey = song.id.isNotEmpty ? song.id : song.streamUrl;
    if (isPreloaded(song) || _currentlyPreloading.contains(cacheKey)) return;
    _currentlyPreloading.add(cacheKey);
    resolvePlayableStreamCandidates(song).catchError((e) {
      debugPrint('[StreamResolverService] Prefetch background error for "${song.title}": $e');
      return <String>[];
    }).whenComplete(() {
      _currentlyPreloading.remove(cacheKey);
    });
  }

  /// NewPipe WINDOW_SIZE = 1 preloader:
  /// Preloads ONLY the immediate next track in the queue sequentially,
  /// avoiding YouTube connection choking, socket saturation, and rate-limiting.
  static void preloadNextSong(Song? nextSong) {
    if (nextSong == null) return;
    prefetchPlayableStreams(nextSong);
  }

  /// Safe preload: only prefetches at most 1 single next un-cached song
  static void preloadSongs(List<Song> songs, {int maxCount = 1}) {
    if (songs.isEmpty) return;
    for (final song in songs) {
      final key = song.id.isNotEmpty ? song.id : song.streamUrl;
      if (!isPreloaded(song) && !_currentlyPreloading.contains(key)) {
        preloadNextSong(song);
        break;
      }
    }
  }

  /// Normalizes title string by stripping noise words
  static String cleanTitle(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'\((?:official|music|video|audio|lyrics|hd|4k|visualizer|remastered|lyric|prod\.|feat\.|ft\.).*?\)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\[(?:official|music|video|audio|lyrics|hd|4k|visualizer|remastered|lyric|prod\.|feat\.|ft\.).*?\]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[\-_|]', caseSensitive: false), ' ')
        .trim();
  }

  /// Pure NewPipe YouTube Stream Resolver:
  /// 1. Offline local audio files
  /// 2. Direct YouTube video audio extraction via YoutubeExplode (requireWatchPage: false)
  /// 3. Piped REST audio proxy failover
  /// 4. Dynamic YouTube search & stream extraction if only title/artist is known
  static Future<List<String>> resolvePlayableStreamCandidates(Song song) {
    final cacheKey = song.id.isNotEmpty ? song.id : song.streamUrl;
    final cached = _resolvedCache[cacheKey];
    if (cached != null && cached.streams.isNotEmpty && DateTime.now().difference(cached.cachedAt).inMinutes < 30) {
      LogService.stream('StreamResolver', 'Cache HIT for "${song.title}": ${cached.streams.length} candidate(s)');
      return Future.value(List<String>.from(cached.streams));
    }

    if (_inFlightResolutions.containsKey(cacheKey)) {
      return _inFlightResolutions[cacheKey]!;
    }

    final future = _resolveCandidatesInternal(song, cacheKey)
        .timeout(const Duration(seconds: 15), onTimeout: () => <String>[]);
    _inFlightResolutions[cacheKey] = future;
    return future.whenComplete(() {
      _inFlightResolutions.remove(cacheKey);
    });
  }

  static Future<List<String>> _resolveCandidatesInternal(Song song, String cacheKey) async {
    final s = song.streamUrl;

    // 1. Local offline files (POSIX, file://, and Windows drive letters)
    final isLocal = s.startsWith('/') ||
        s.startsWith('file://') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(s);
    if (s.isNotEmpty && isLocal) {
      String checkPath;
      if (s.startsWith('file://')) {
        try {
          checkPath = Uri.parse(s).toFilePath(windows: Platform.isWindows);
        } catch (_) {
          checkPath = Uri.decodeFull(s.replaceFirst('file://', ''));
        }
      } else {
        checkPath = Uri.decodeFull(s);
      }
      if (Platform.isWindows && checkPath.startsWith('/') && checkPath.length > 2 && checkPath[2] == ':') {
        checkPath = checkPath.substring(1);
      }
      if (File(checkPath).existsSync()) {
        LogService.stream('StreamResolver', 'Local offline file verified for "${song.title}": $s');
        return [s];
      } else {
        LogService.w('StreamResolver', 'Local file not found on disk ($checkPath). Falling back to YouTube streaming.');
      }
    }

    // 2. Direct HTTP/HTTPS audio streams (non-YouTube web pages)
    if (s.startsWith('http://') || s.startsWith('https://')) {
      final uri = Uri.tryParse(s);
      final host = uri?.host.toLowerCase() ?? '';
      final isYouTubeUrl = host.contains('youtube.com') || host.contains('youtu.be');
      if (!isYouTubeUrl && (s.contains('.mp3') || s.contains('.m4a') || s.contains('.aac') || s.contains('.opus') || s.contains('.ogg') || s.contains('.webm') || s.contains('.flac') || s.contains('googlevideo.com'))) {
        LogService.stream('StreamResolver', 'Direct external audio stream URL detected: $s');
        _cacheStreams(cacheKey, [s]);
        return [s];
      }
    }

    // 3. Extract YouTube video ID
    String? videoId;
    if (song.id.startsWith('yt_')) {
      videoId = song.id.replaceFirst('yt_', '').trim();
    } else if (s.contains('youtube.com') || s.contains('youtu.be')) {
      videoId = YouTubeImporterService.extractVideoId(s);
    }

    // 4. If videoId found, extract direct YouTube audio streams
    if (videoId != null && videoId.isNotEmpty) {
      try {
        LogService.stream('StreamResolver', 'Resolving direct YouTube streams for $videoId ("${song.title}")...');
        debugPrint('[NewPipe Engine] Resolving YouTube audio streams for $videoId ("${song.title}")...');
        final streams = await YouTubeImporterService.getAudioStreamUrls(videoId);
        if (streams.isNotEmpty) {
          LogService.stream('StreamResolver', 'Resolved ${streams.length} direct YouTube audio streams for "${song.title}"');
          debugPrint('[NewPipe Engine] Resolved ${streams.length} direct YouTube audio streams for "${song.title}"');
          _cacheStreams(cacheKey, streams);
          return List<String>.from(streams);
        }
      } catch (e) {
        LogService.w('StreamResolver', 'Direct extraction error for $videoId: $e');
        debugPrint('[NewPipe Engine] Direct extraction error for $videoId: $e');
      }
    }

    // 5. If no direct videoId, search YouTube dynamically by title + artist
    try {
      final cleanT = cleanTitle(song.title);
      final cleanA = song.artist != 'Unknown Artist' && song.artist.isNotEmpty ? song.artist.trim() : '';
      var query = cleanA.isNotEmpty ? '$cleanT $cleanA' : cleanT;
      if (query.trim().isEmpty) {
        query = song.title.trim().isNotEmpty ? song.title.trim() : 'music';
      }
      LogService.stream('StreamResolver', 'Searching YouTube dynamically for "$query"...');
      debugPrint('[NewPipe Engine] Searching YouTube for "$query"...');

      final searchMatches = await YouTubeImporterService.searchYouTube(query, limit: 3);
      if (searchMatches.isNotEmpty) {
        final match = searchMatches.first;
        final matchVideoId = match.id.replaceFirst('yt_', '').trim();
        if (matchVideoId.isNotEmpty) {
          final streams = await YouTubeImporterService.getAudioStreamUrls(matchVideoId);
          if (streams.isNotEmpty) {
            LogService.stream('StreamResolver', 'Dynamic search resolved ${streams.length} streams for "$query"');
            debugPrint('[NewPipe Engine] Dynamic search resolved ${streams.length} streams for "$query"');
            _cacheStreams(cacheKey, streams);
            return List<String>.from(streams);
          }
        }
      }
    } catch (e) {
      LogService.w('StreamResolver', 'Dynamic search error for "${song.title}": $e');
      debugPrint('[NewPipe Engine] Dynamic search error for "${song.title}": $e');
    }

    LogService.w('StreamResolver', 'Could not resolve any audio stream candidates for "${song.title}"');
    return [];
  }
}
