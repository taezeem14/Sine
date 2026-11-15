import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'youtube_importer_service.dart';

class MusicCategory {
  final String key;
  final FaIconData icon;
  final String title;
  final String subtitle;
  final String searchQuery;

  const MusicCategory({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.searchQuery,
  });
}

class CatalogService {
  static const List<MusicCategory> categories = [
    MusicCategory(
      key: 'trending',
      icon: FontAwesomeIcons.chartLine,
      title: 'Today\'s Top Hits',
      subtitle: 'Global chart toppers & viral hits',
      searchQuery: 'Today Top Hits Official Music Audio',
    ),
    MusicCategory(
      key: 'top_hits',
      icon: FontAwesomeIcons.headphones,
      title: 'Global Top 50',
      subtitle: 'The hottest tracks worldwide',
      searchQuery: 'Top 50 Global Music Hits',
    ),
    MusicCategory(
      key: 'pop',
      icon: FontAwesomeIcons.compactDisc,
      title: 'Pop Anthems',
      subtitle: 'Upbeat melodies & anthems',
      searchQuery: 'Popular Pop Music Hits',
    ),
    MusicCategory(
      key: 'hiphop',
      icon: FontAwesomeIcons.microphoneLines,
      title: 'Hip-Hop & Rap',
      subtitle: 'Beats, bars & urban hits',
      searchQuery: 'Hip Hop Rap Top Songs',
    ),
    MusicCategory(
      key: 'lofi',
      icon: FontAwesomeIcons.headphones,
      title: 'Lo-Fi Chill',
      subtitle: 'Atmospheric study & relax beats',
      searchQuery: 'Lofi Hip Hop Chill Beats',
    ),
    MusicCategory(
      key: 'electronic',
      icon: FontAwesomeIcons.bolt,
      title: 'Electronic & Dance',
      subtitle: 'EDM, Synthwave & Club',
      searchQuery: 'EDM Electronic Music Top Hits',
    ),
    MusicCategory(
      key: 'rock',
      icon: FontAwesomeIcons.guitar,
      title: 'Rock & Alternative',
      subtitle: 'Anthems, guitars & indie rock',
      searchQuery: 'Rock Classics Modern Alternative Hits',
    ),
    MusicCategory(
      key: 'acoustic',
      icon: FontAwesomeIcons.music,
      title: 'Acoustic & Calm',
      subtitle: 'Soothing vocals and melodies',
      searchQuery: 'Acoustic Guitar Calm Chill Songs',
    ),
  ];

  static const int _maxCategoryCache = 25;
  static final Map<String, List<Song>> _categoryCache = {};

  static final Map<String, String> _genreSearchTerms = {
    'electric & dance': 'electronic dance edm hits',
    'today\'s top hits': 'top hits billboard chart',
    'pop global': 'pop hits top tracks',
    'hip-hop & rap': 'hip hop rap top hits',
    'rock & alt': 'rock classics alternative hits',
    'indie vibes': 'indie rock alternative',
    'chill & lo-fi': 'lofi chill beats study relax',
    'bollywood hits': 'bollywood top hits hindi songs',
    'pakistani hits': 'pakistani top hits coke studio urdu',
    'workout & hype': 'workout cardio hype gym hits',
    'classical & piano': 'classical masterpieces piano orchestra',
    'acoustic & folk': 'acoustic guitar folk calm',
  };

  static void _cacheCategory(String key, List<Song> songs) {
    if (_categoryCache.length >= _maxCategoryCache) {
      _categoryCache.remove(_categoryCache.keys.first);
    }
    _categoryCache[key] = songs;
  }

  static List<Song>? getCachedCategory(String key) => _categoryCache[key];

  static bool _isValidMusicTrack(Song song) {
    final secs = song.duration.inSeconds;
    if (secs > 0 && (secs < 45 || secs > 720)) {
      return false;
    }
    final lowerTitle = song.title.toLowerCase();
    const spamTerms = [
      '10 hour',
      '10-hour',
      '1 hour loop',
      '10 hours',
      'compilation',
      'meme song',
      'tiktok meme',
      'breaking news',
      'live news',
    ];
    for (final term in spamTerms) {
      if (lowerTitle.contains(term)) return false;
    }
    return true;
  }

  /// Curated Genre Provider: Fetches genuine top tracks via iTunes Search API with fallback to YouTube
  static Future<List<Song>> fetchCuratedGenre(
    String categoryTitle,
    String query, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'curated_${categoryTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    if (!forceRefresh && _categoryCache.containsKey(cacheKey)) {
      final cached = _categoryCache[cacheKey]!;
      if (cached.isNotEmpty) return cached;
    }

    final lowerTitle = categoryTitle.toLowerCase().trim();
    final searchTerm = _genreSearchTerms[lowerTitle] ??
        (query.trim().isNotEmpty ? query.trim() : categoryTitle.trim());

    // 1. Primary: High-fidelity iTunes Music API (returns genuine top tracks, clean metadata, and HD 600x600 covers)
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(searchTerm)}&media=music&entity=song&limit=50',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List? ?? [];
        final songs = <Song>[];

        for (final item in results) {
          final trackName = item['trackName'] as String?;
          final artistName = item['artistName'] as String?;
          final trackId = item['trackId'];
          if (trackName == null || trackName.isEmpty || artistName == null || artistName.isEmpty) {
            continue;
          }

          final rawArtwork = item['artworkUrl100'] as String? ?? '';
          final hdArtwork = rawArtwork.replaceAll('100x100bb', '600x600bb');
          final durationMs = item['trackTimeMillis'] as int? ?? 0;

          songs.add(
            Song(
              id: 'itunes_${trackId ?? songs.length}',
              title: trackName,
              artist: artistName,
              duration: Duration(milliseconds: durationMs),
              artworkUrl: hdArtwork,
              streamUrl: '', // Resolved on-demand by StreamResolverService via YouTube
              source: 'itunes',
            ),
          );
        }

        if (songs.isNotEmpty) {
          debugPrint('[CatalogService] Curated genre "$categoryTitle" fetched ${songs.length} real tracks via iTunes API');
          _cacheCategory(cacheKey, songs);
          return songs;
        }
      }
    } catch (e) {
      debugPrint('[CatalogService] iTunes genre fetch error for "$categoryTitle": $e');
    }

    // 2. Resilient Fallback: YouTube Search
    try {
      final fallbackQuery = '$searchTerm best songs';
      final results = await searchOnline(fallbackQuery, limit: 40);
      if (results.isNotEmpty) {
        _cacheCategory(cacheKey, results);
        return results;
      }
    } catch (e) {
      debugPrint('[CatalogService] Fallback YouTube search error: $e');
    }

    return _categoryCache[cacheKey] ?? [];
  }

  /// Search online catalog via YouTube NewPipe extractor
  static Future<List<Song>> searchOnline(String query, {int limit = 50}) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    try {
      debugPrint('[CatalogService] Searching YouTube for "$cleanQ"...');
      final results = await YouTubeImporterService.searchYouTube(cleanQ, limit: limit);
      final filtered = results.where(_isValidMusicTrack).toList();
      if (filtered.isNotEmpty) return filtered;
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[CatalogService] Search error: $e');
    }

    return [];
  }

  /// Fetch songs for a curated category via YouTube
  static Future<List<Song>> fetchCategory(String categoryKey, {bool forceRefresh = false}) async {
    if (!forceRefresh && _categoryCache.containsKey(categoryKey)) {
      final cached = _categoryCache[categoryKey]!;
      if (cached.isNotEmpty) return cached;
    }

    final cat = categories.firstWhere(
      (c) => c.key == categoryKey,
      orElse: () => categories.first,
    );

    try {
      final results = await searchOnline(cat.searchQuery, limit: 50);
      if (results.isNotEmpty) {
        _cacheCategory(categoryKey, results);
        return results;
      }
    } catch (e) {
      debugPrint('[CatalogService] Category fetch error for $categoryKey: $e');
    }

    return _categoryCache[categoryKey] ?? [];
  }

  /// Fetch trending YouTube tracks
  static Future<List<Song>> fetchTrending({bool forceRefresh = false}) =>
      fetchCategory('trending', forceRefresh: forceRefresh);

  /// Backward-compatible aliases for player provider
  static Future<List<Song>> fetchTrendingTracks({bool forceRefresh = false}) =>
      fetchTrending(forceRefresh: forceRefresh);

  static Future<List<Song>> fetchCategoryTracks(String categoryKey, {bool forceRefresh = false}) =>
      fetchCategory(categoryKey, forceRefresh: forceRefresh);

  static Future<List<Song>> fetchRecommendations(Song song, {int limit = 12}) async {
    final cleanTitle = song.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
    final effectiveTitle = cleanTitle.isNotEmpty ? cleanTitle : song.title;
    final hasArtist = song.artist.isNotEmpty && song.artist != 'Unknown Artist';
    final query = hasArtist ? '$effectiveTitle ${song.artist} songs'.trim() : '$effectiveTitle songs'.trim();
    return searchOnline(query, limit: limit);
  }

  static List<Song> getAllTracks() {
    return _categoryCache.values.expand((list) => list).toList();
  }
}
