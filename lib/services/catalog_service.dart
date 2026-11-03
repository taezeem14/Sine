import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
      icon: FontAwesomeIcons.fire,
      title: 'YouTube Trending',
      subtitle: 'Top charts & viral hits',
      searchQuery: 'Top Trending Music Videos Hits',
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

  static const int _maxCategoryCache = 20;
  static final Map<String, List<Song>> _categoryCache = {};

  static void _cacheCategory(String key, List<Song> songs) {
    if (_categoryCache.length >= _maxCategoryCache) {
      _categoryCache.remove(_categoryCache.keys.first);
    }
    _categoryCache[key] = songs;
  }

  /// Search online catalog via YouTube NewPipe extractor
  static Future<List<Song>> searchOnline(String query, {int limit = 50}) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    try {
      debugPrint('[CatalogService] Searching YouTube for "$cleanQ"...');
      final results = await YouTubeImporterService.searchYouTube(cleanQ, limit: limit);
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
