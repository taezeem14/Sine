import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MetadataCorrectionResult {
  final String cleanTitle;
  final String cleanArtist;
  final bool wasSwapped;
  final bool isVerified;
  final String? album;
  final String? artworkUrl;

  const MetadataCorrectionResult({
    required this.cleanTitle,
    required this.cleanArtist,
    this.wasSwapped = false,
    this.isVerified = false,
    this.album,
    this.artworkUrl,
  });

  @override
  String toString() =>
      'MetadataCorrectionResult(title: "$cleanTitle", artist: "$cleanArtist", wasSwapped: $wasSwapped, isVerified: $isVerified)';
}

/// Production metadata correction service that resolves inverted "Title - Artist" vs "Artist - Title",
/// fixes author mistaken as song name (e.g. "Wrong - Chris Grey" vs "Chris Grey - Wrong"),
/// and canonicalizes song metadata using public iTunes Search & Deezer APIs.
class MetadataCorrectionService {
  MetadataCorrectionService._();

  static http.Client? customClient;
  static final Map<String, MetadataCorrectionResult> _cache = {};
  static const int _maxCacheSize = 250;

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{【（［「『].*?[\)\]\}】）］」』]'), '')
        .replaceAll(RegExp(r'\b(feat\.?|ft\.?|prod\.?|official|video|audio|lyrics?)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  /// Checks if two strings are fuzzy equivalent (containment or equality)
  static bool _fuzzyMatch(String a, String b) {
    final normA = _normalize(a);
    final normB = _normalize(b);
    if (normA.isEmpty || normB.isEmpty) return false;
    if (normA == normB) return true;
    if (normA.length >= 3 && normB.length >= 3) {
      return normA.contains(normB) || normB.contains(normA);
    }
    return false;
  }

  /// Primary metadata correction function. Queries iTunes Search API with Deezer API fallback.
  static Future<MetadataCorrectionResult> correctMetadata(
    String rawTitle,
    String rawArtist, {
    http.Client? client,
  }) async {
    final trimmedTitle = rawTitle.trim();
    final trimmedArtist = rawArtist.trim();
    if (trimmedTitle.isEmpty) {
      return MetadataCorrectionResult(cleanTitle: rawTitle, cleanArtist: rawArtist);
    }

    final cacheKey = '${trimmedTitle.toLowerCase()}___${trimmedArtist.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Attempt iTunes Search first (instant, free, authoritative)
    try {
      final itunesResult = await _queryItunes(trimmedTitle, trimmedArtist, client: client);
      if (itunesResult != null) {
        _cacheResult(cacheKey, itunesResult);
        return itunesResult;
      }
    } catch (e) {
      debugPrint('[MetadataCorrection] iTunes query error: $e');
    }

    // Fallback to Deezer API
    try {
      final deezerResult = await _queryDeezer(trimmedTitle, trimmedArtist, client: client);
      if (deezerResult != null) {
        _cacheResult(cacheKey, deezerResult);
        return deezerResult;
      }
    } catch (e) {
      debugPrint('[MetadataCorrection] Deezer query error: $e');
    }

    // Default fallback: preserve input
    final fallback = MetadataCorrectionResult(
      cleanTitle: trimmedTitle,
      cleanArtist: trimmedArtist,
      wasSwapped: false,
      isVerified: false,
    );
    _cacheResult(cacheKey, fallback);
    return fallback;
  }

  /// Evaluates iTunes Search API JSON response against input title and artist.
  static MetadataCorrectionResult? evaluateItunesResponse(
    Map<String, dynamic> data,
    String inTitle,
    String inArtist,
  ) {
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) return null;

    for (final raw in results) {
      if (raw is! Map) continue;
      final apiTrack = raw['trackName'] as String? ?? '';
      final apiArtist = raw['artistName'] as String? ?? '';
      final album = raw['collectionName'] as String?;
      final art = raw['artworkUrl100'] as String?;

      if (apiTrack.isEmpty || apiArtist.isEmpty) continue;

      // 1. Swapped check: inTitle was actually the Artist, and inArtist was the Track!
      // (e.g. inTitle: "Chris Grey", inArtist: "Wrong" -> apiTrack: "WRONG", apiArtist: "Chris Grey")
      final isTitleArtist = _fuzzyMatch(inTitle, apiArtist);
      final isArtistTrack = _fuzzyMatch(inArtist, apiTrack);

      if (isTitleArtist && isArtistTrack) {
        debugPrint('[MetadataCorrection] iTunes detected swapped metadata! Input: [$inTitle by $inArtist] -> Correct: [$apiTrack by $apiArtist]');
        return MetadataCorrectionResult(
          cleanTitle: apiTrack,
          cleanArtist: apiArtist,
          wasSwapped: true,
          isVerified: true,
          album: album,
          artworkUrl: art,
        );
      }

      // 2. Direct match check: inTitle matches apiTrack and inArtist matches apiArtist
      final isTitleTrack = _fuzzyMatch(inTitle, apiTrack);
      final isArtistArtist = _fuzzyMatch(inArtist, apiArtist);

      if (isTitleTrack && (inArtist.isEmpty || isArtistArtist)) {
        return MetadataCorrectionResult(
          cleanTitle: apiTrack,
          cleanArtist: apiArtist,
          wasSwapped: false,
          isVerified: true,
          album: album,
          artworkUrl: art,
        );
      }
    }

    // Check delimiter split if title contains a dash: e.g. "Wrong - Chris Grey"
    final dashMatch = RegExp(r'\s+[-–—:]\s*|\s*[-–—:]\s+').firstMatch(inTitle);
    if (dashMatch != null) {
      final partA = inTitle.substring(0, dashMatch.start).trim();
      final partB = inTitle.substring(dashMatch.end).trim();

      for (final raw in results) {
        if (raw is! Map) continue;
        final apiTrack = raw['trackName'] as String? ?? '';
        final apiArtist = raw['artistName'] as String? ?? '';

        // If partA is Track and partB is Artist (e.g. "Wrong - Chris Grey")
        if (_fuzzyMatch(partA, apiTrack) && _fuzzyMatch(partB, apiArtist)) {
          return MetadataCorrectionResult(
            cleanTitle: apiTrack,
            cleanArtist: apiArtist,
            wasSwapped: false,
            isVerified: true,
          );
        }

        // If partA is Artist and partB is Track (e.g. "Chris Grey - Wrong")
        if (_fuzzyMatch(partA, apiArtist) && _fuzzyMatch(partB, apiTrack)) {
          return MetadataCorrectionResult(
            cleanTitle: apiTrack,
            cleanArtist: apiArtist,
            wasSwapped: true,
            isVerified: true,
          );
        }
      }
    }

    return null;
  }

  static Future<MetadataCorrectionResult?> _queryItunes(
    String inTitle,
    String inArtist, {
    http.Client? client,
  }) async {
    final query = inArtist.isNotEmpty ? '$inTitle $inArtist' : inTitle;
    final url = Uri.https('itunes.apple.com', '/search', {
      'term': query,
      'entity': 'song',
      'limit': '5',
    });

    final c = client ?? customClient ?? http.Client();
    final shouldClose = client == null && customClient == null;
    try {
      final resp = await c.get(url, headers: {
        'User-Agent': 'Sine/1.2.6 (https://github.com/taezeem14/Sine)',
      }).timeout(const Duration(seconds: 4));

      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return evaluateItunesResponse(data, inTitle, inArtist);
    } finally {
      if (shouldClose) c.close();
    }
  }

  /// Evaluates Deezer API JSON response against input title and artist.
  static MetadataCorrectionResult? evaluateDeezerResponse(
    Map<String, dynamic> data,
    String inTitle,
    String inArtist,
  ) {
    final items = data['data'] as List?;
    if (items == null || items.isEmpty) return null;

    for (final raw in items) {
      if (raw is! Map) continue;
      final apiTrack = raw['title'] as String? ?? '';
      final artistObj = raw['artist'] as Map?;
      final apiArtist = artistObj?['name'] as String? ?? '';
      final albumObj = raw['album'] as Map?;
      final album = albumObj?['title'] as String?;
      final art = albumObj?['cover_medium'] as String?;

      if (apiTrack.isEmpty || apiArtist.isEmpty) continue;

      if (_fuzzyMatch(inTitle, apiArtist) && _fuzzyMatch(inArtist, apiTrack)) {
        return MetadataCorrectionResult(
          cleanTitle: apiTrack,
          cleanArtist: apiArtist,
          wasSwapped: true,
          isVerified: true,
          album: album,
          artworkUrl: art,
        );
      }

      if (_fuzzyMatch(inTitle, apiTrack) && (inArtist.isEmpty || _fuzzyMatch(inArtist, apiArtist))) {
        return MetadataCorrectionResult(
          cleanTitle: apiTrack,
          cleanArtist: apiArtist,
          wasSwapped: false,
          isVerified: true,
          album: album,
          artworkUrl: art,
        );
      }
    }

    return null;
  }

  static Future<MetadataCorrectionResult?> _queryDeezer(
    String inTitle,
    String inArtist, {
    http.Client? client,
  }) async {
    final query = inArtist.isNotEmpty ? '$inTitle $inArtist' : inTitle;
    final url = Uri.parse('https://api.deezer.com/search?q=${Uri.encodeComponent(query)}&limit=5');

    final c = client ?? customClient ?? http.Client();
    final shouldClose = client == null && customClient == null;
    try {
      final resp = await c.get(url, headers: {
        'User-Agent': 'Sine/1.2.6 (https://github.com/taezeem14/Sine)',
      }).timeout(const Duration(seconds: 4));

      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return evaluateDeezerResponse(data, inTitle, inArtist);
    } finally {
      if (shouldClose) c.close();
    }
  }

  static void _cacheResult(String key, MetadataCorrectionResult result) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  static void clearCache() {
    _cache.clear();
  }
}
