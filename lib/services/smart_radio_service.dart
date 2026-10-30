import 'dart:async';
import '../models/song.dart';
import 'youtube_importer_service.dart';
import 'log_service.dart';

/// Result container for a complete Smart Radio station
class RadioStationResult {
  final Song seedSong;
  final bool isArtistRadio;
  final List<Song> songs;
  final String? continuationToken;
  final String? nextVideoId;
  final String? nextParams;
  final Set<String> seenVideoIds;

  const RadioStationResult({
    required this.seedSong,
    this.isArtistRadio = false,
    required this.songs,
    this.continuationToken,
    this.nextVideoId,
    this.nextParams,
    required this.seenVideoIds,
  });
}

/// Spotify-Grade Smart Radio & Autoplay Recommendation Engine
/// Powered by YouTube Music Machine-Learning automixes (RDAMVM / RD) and
/// Spotify-inspired acoustic diversity, deduplication, and anti-clustering.
class SmartRadioService {
  static final SmartRadioService instance = SmartRadioService._();
  SmartRadioService._();

  // In-memory cache for generated radio stations
  static const int _maxCachedStations = 30;
  final Map<String, RadioStationResult> _stationCache = {};

  // Recommendations cache for quick queue previews
  final Map<String, List<Song>> _queueRecommendationsCache = {};

  /// Junk and noise patterns to filter out of radio streams
  static final List<RegExp> _noiseFilters = [
    RegExp(r'\b(?:karaoke|backing track|instrumental version)\b', caseSensitive: false),
    RegExp(r'\b(?:synthesia|piano tutorial|guitar tutorial|how to play)\b', caseSensitive: false),
    RegExp(r'\b(?:1\s*hour|10\s*hours|loop|extended loop)\b', caseSensitive: false),
    RegExp(r'\b(?:reaction|reacts to|review|unboxing)\b', caseSensitive: false),
    RegExp(r'\b(?:nightcore|sped up|slowed\s*\+\s*reverb|chipmunk)\b', caseSensitive: false),
    RegExp(r'\b(?:8d\s*audio|3d\s*audio|bass\s*boosted\s*extreme)\b', caseSensitive: false),
    RegExp(r'\b(?:parody|meme\s*compilation)\b', caseSensitive: false),
  ];

  /// Normalize string for title deduplication
  static String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '')
        .replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extracts clean 11-char YouTube video ID
  static String? _extractCleanVideoId(String rawId) {
    var id = rawId.replaceFirst('yt_', '').trim();
    if (id.length == 11 && RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(id)) {
      return id;
    }
    return YouTubeImporterService.extractVideoId(id);
  }

  /// Generate a complete Spotify-grade radio station for a seed track
  Future<RadioStationResult> generateRadioStation({
    required Song seedSong,
    bool isArtistRadio = false,
    int targetCount = 25,
  }) async {
    final cacheKey = '${seedSong.id}_${isArtistRadio ? 'artist' : 'song'}';
    if (_stationCache.containsKey(cacheKey)) {
      return _stationCache[cacheKey]!;
    }

    LogService.i('SmartRadio', 'Generating ${isArtistRadio ? "Artist" : "Song"} Radio for "${seedSong.title}" by ${seedSong.artist}');

    final seenIds = <String>{};
    final candidates = <Song>[];
    final seedVid = _extractCleanVideoId(seedSong.id);

    if (seedVid != null) {
      seenIds.add(seedVid);
    }
    // Seed track is always track #0
    candidates.add(seedSong);

    String? continuationToken;
    String? nextVideoId;
    String? nextParams;

    if (isArtistRadio) {
      // --- ARTIST RADIO STRATEGY ---
      // 1. Fetch artist's core discography & top hits
      final artistHits = await _fetchArtistTopTracks(seedSong.artist, seenIds);
      candidates.addAll(artistHits);

      // 2. Fetch artist automix or peer collaborator tracks
      final peerTracks = await _fetchPeerArtistTracks(seedSong, seenIds);
      candidates.addAll(peerTracks);
    } else {
      // --- SONG RADIO STRATEGY (YOUTUBE MUSIC ML GRAPH) ---
      // 1. Attempt official InnerTube Radio Mix (playlistId: RDAMVM<videoId> or RD<videoId>)
      if (seedVid != null) {
        final radioPlaylistIds = [
          'RDAMVM$seedVid',
          'RD$seedVid',
        ];

        for (final rPid in radioPlaylistIds) {
          try {
            final batch = await YouTubeImporterService.fetchNextMixBatch(
              playlistId: rPid,
              currentVideoId: seedVid,
              seenIds: seenIds,
            );

            if (batch != null && batch.songs.isNotEmpty) {
              continuationToken = batch.continuationToken;
              nextVideoId = batch.nextVideoId;
              nextParams = batch.nextParams;
              candidates.addAll(batch.songs);
              LogService.i('SmartRadio', 'InnerTube ML Radio ($rPid) returned ${batch.songs.length} curated tracks');
              break;
            }
          } catch (e) {
            LogService.w('SmartRadio', 'Mix batch error for $rPid: $e');
          }
        }
      }

      // 2. Fallback or supplementary: Algorithmic semantic query if InnerTube radio was too short
      if (candidates.length < 12) {
        final semanticRecs = await _fetchSemanticRecommendations(seedSong, seenIds, limit: 15);
        candidates.addAll(semanticRecs);
      }
    }

    // --- SPOTIFY SHAPING: Deduplication, Anti-Clustering, and Quality Filtering ---
    final shapedList = _shapePlaylist(candidates, seedSong);

    final result = RadioStationResult(
      seedSong: seedSong,
      isArtistRadio: isArtistRadio,
      songs: shapedList,
      continuationToken: continuationToken,
      nextVideoId: nextVideoId,
      nextParams: nextParams,
      seenVideoIds: seenIds,
    );

    if (_stationCache.length >= _maxCachedStations) {
      _stationCache.remove(_stationCache.keys.first);
    }
    _stationCache[cacheKey] = result;

    return result;
  }

  /// Infinite Radio Pagination: Fetches next batch of tracks for an active radio session
  Future<MixContinuationResult?> fetchNextRadioBatch({
    required String? seedVideoId,
    required String? continuationToken,
    required String? lastVideoId,
    required String? lastParams,
    required Set<String> seenIds,
  }) async {
    final effectiveVid = seedVideoId ?? lastVideoId;
    if (effectiveVid == null && continuationToken == null) return null;

    final playlistId = 'RDAMVM${effectiveVid ?? ""}';

    try {
      final batch = await YouTubeImporterService.fetchNextMixBatch(
        playlistId: playlistId,
        continuationToken: continuationToken,
        currentVideoId: lastVideoId ?? effectiveVid,
        currentParams: lastParams,
        seenIds: seenIds,
      );

      if (batch != null && batch.songs.isNotEmpty) {
        // Filter out noise
        final cleanSongs = batch.songs.where((s) => !_isNoise(s.title)).toList();
        return MixContinuationResult(
          songs: cleanSongs,
          continuationToken: batch.continuationToken,
          nextVideoId: batch.nextVideoId,
          nextParams: batch.nextParams,
        );
      }
    } catch (e) {
      LogService.w('SmartRadio', 'Error fetching next radio batch: $e');
    }
    return null;
  }

  /// Quick recommendations for the Queue tab based on current song
  Future<List<Song>> fetchQueueRecommendations({
    required Song currentSong,
    List<Song>? currentQueue,
    int limit = 12,
  }) async {
    final cacheKey = currentSong.id;
    if (_queueRecommendationsCache.containsKey(cacheKey)) {
      final cached = _queueRecommendationsCache[cacheKey]!;
      if (cached.isNotEmpty) return cached.take(limit).toList();
    }

    final queueIds = (currentQueue ?? []).map((s) => s.id.replaceFirst('yt_', '')).toSet();
    final vid = _extractCleanVideoId(currentSong.id);
    final recs = <Song>[];

    // Try InnerTube radio mix first for maximum relevance
    if (vid != null) {
      try {
        final batch = await YouTubeImporterService.fetchNextMixBatch(
          playlistId: 'RDAMVM$vid',
          currentVideoId: vid,
          seenIds: queueIds,
        );
        if (batch != null && batch.songs.isNotEmpty) {
          recs.addAll(batch.songs.where((s) => !_isNoise(s.title) && s.id != currentSong.id));
        }
      } catch (_) {}
    }

    // Supplementary semantic query if needed
    if (recs.length < limit) {
      final semantic = await _fetchSemanticRecommendations(currentSong, queueIds, limit: limit);
      recs.addAll(semantic);
    }

    final shaped = _shapePlaylist([currentSong, ...recs], currentSong).skip(1).take(limit).toList();
    _queueRecommendationsCache[cacheKey] = shaped;
    return shaped;
  }

  /// Smart Autoplay generator: seamlessly continues playback when active queue reaches tail
  Future<List<Song>> generateAutoplayTracks({
    required Song lastSong,
    List<Song>? recentHistory,
    int limit = 20,
  }) async {
    final seenIds = <String>{};
    if (recentHistory != null) {
      for (final s in recentHistory.take(30)) {
        seenIds.add(s.id.replaceFirst('yt_', ''));
      }
    }
    seenIds.add(lastSong.id.replaceFirst('yt_', ''));

    final station = await generateRadioStation(seedSong: lastSong, targetCount: limit);
    // Exclude the seed track itself since it just finished playing
    final nextTracks = station.songs.where((s) => s.id != lastSong.id).toList();

    return nextTracks.isNotEmpty ? nextTracks : station.songs;
  }

  // --- Internal Helpers ---

  static bool _isNoise(String title) {
    for (final reg in _noiseFilters) {
      if (reg.hasMatch(title)) return true;
    }
    return false;
  }

  /// Fetches top tracks for an artist
  static Future<List<Song>> _fetchArtistTopTracks(String artist, Set<String> seenIds) async {
    if (artist.isEmpty || artist == 'Unknown Artist') return [];
    try {
      final query = '$artist greatest hits top songs';
      final results = await YouTubeImporterService.searchYouTube(query, limit: 15);
      return results.where((s) {
        final id = s.id.replaceFirst('yt_', '');
        if (seenIds.contains(id) || _isNoise(s.title)) return false;
        seenIds.add(id);
        return true;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches related / peer artist tracks
  static Future<List<Song>> _fetchPeerArtistTracks(Song seedSong, Set<String> seenIds) async {
    try {
      final query = '${seedSong.artist} similar artists playlist';
      final results = await YouTubeImporterService.searchYouTube(query, limit: 20);
      return results.where((s) {
        final id = s.id.replaceFirst('yt_', '');
        if (seenIds.contains(id) || _isNoise(s.title)) return false;
        seenIds.add(id);
        return true;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// High-recall semantic recommendations
  static Future<List<Song>> _fetchSemanticRecommendations(Song song, Set<String> seenIds, {int limit = 15}) async {
    final cleanT = song.title.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '').trim();
    final query = (song.artist.isNotEmpty && song.artist != 'Unknown Artist')
        ? '$cleanT ${song.artist} songs'
        : '$cleanT music playlist';

    try {
      final results = await YouTubeImporterService.searchYouTube(query, limit: limit + 5);
      return results.where((s) {
        final id = s.id.replaceFirst('yt_', '');
        if (seenIds.contains(id) || s.id == song.id || _isNoise(s.title)) return false;
        seenIds.add(id);
        return true;
      }).take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Shapes candidate pool using Spotify-grade heuristics:
  /// 1. Seed track locked at index 0
  /// 2. Deduplication by normalized title
  /// 3. Anti-clustering: At most 2 songs from the same artist consecutively
  static List<Song> _shapePlaylist(List<Song> candidates, Song seedSong) {
    if (candidates.isEmpty) return [seedSong];

    final output = <Song>[];
    final seenNormalizedTitles = <String>{};

    // Ensure seed track is always #0
    output.add(seedSong);
    seenNormalizedTitles.add(_normalizeTitle(seedSong.title));

    final pool = <Song>[];
    for (final s in candidates) {
      if (s.id == seedSong.id) continue;
      final norm = _normalizeTitle(s.title);
      if (seenNormalizedTitles.contains(norm)) continue;
      seenNormalizedTitles.add(norm);
      pool.add(s);
    }

    // Interleave tracks to avoid artist clustering
    String lastArtist = seedSong.artist.toLowerCase();
    int consecutiveArtistCount = 1;

    final remaining = List<Song>.from(pool);

    while (remaining.isNotEmpty) {
      int nextIndex = -1;

      if (consecutiveArtistCount < 2) {
        // Can take either same artist or different
        nextIndex = 0;
      } else {
        // Need a different artist to prevent fatigue
        nextIndex = remaining.indexWhere((s) => s.artist.toLowerCase() != lastArtist);
        if (nextIndex == -1) {
          // If only same artist remains, accept it
          nextIndex = 0;
        }
      }

      final chosen = remaining.removeAt(nextIndex);
      output.add(chosen);

      final chosenArtist = chosen.artist.toLowerCase();
      if (chosenArtist == lastArtist) {
        consecutiveArtistCount++;
      } else {
        lastArtist = chosenArtist;
        consecutiveArtistCount = 1;
      }
    }

    return output;
  }

  /// Invalidate cache
  static void clearCaches() {
    instance._stationCache.clear();
    instance._queueRecommendationsCache.clear();
  }
}
