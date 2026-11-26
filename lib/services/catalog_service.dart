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
      icon: FontAwesomeIcons.bolt,
      title: 'Trending Electric Hits',
      subtitle: 'Curated electronic dance & festival anthems • High-Fidelity Audio',
      searchQuery: 'electronic dance hits official audio song',
    ),
    MusicCategory(
      key: 'top_hits',
      icon: FontAwesomeIcons.headphones,
      title: 'Global Top 50',
      subtitle: 'The hottest tracks worldwide',
      searchQuery: 'billboard hot 100 global top 50 official audio',
    ),
    MusicCategory(
      key: 'pop',
      icon: FontAwesomeIcons.compactDisc,
      title: 'Pop Anthems',
      subtitle: 'Upbeat melodies & anthems',
      searchQuery: 'pop hits songs official audio',
    ),
    MusicCategory(
      key: 'hiphop',
      icon: FontAwesomeIcons.microphoneLines,
      title: 'Hip-Hop & Rap',
      subtitle: 'Beats, bars & urban hits',
      searchQuery: 'hip hop rap songs official audio',
    ),
    MusicCategory(
      key: 'lofi',
      icon: FontAwesomeIcons.headphones,
      title: 'Lo-Fi Chill',
      subtitle: 'Atmospheric study & relax beats',
      searchQuery: 'chill lofi hip hop beat track',
    ),
    MusicCategory(
      key: 'electronic',
      icon: FontAwesomeIcons.bolt,
      title: 'Electronic & Dance',
      subtitle: 'EDM, Synthwave & Club',
      searchQuery: 'electronic dance edm song official audio',
    ),
    MusicCategory(
      key: 'rock',
      icon: FontAwesomeIcons.guitar,
      title: 'Rock & Alternative',
      subtitle: 'Anthems, guitars & indie rock',
      searchQuery: 'rock alternative anthems official audio',
    ),
    MusicCategory(
      key: 'acoustic',
      icon: FontAwesomeIcons.music,
      title: 'Acoustic & Calm',
      subtitle: 'Soothing vocals and melodies',
      searchQuery: 'acoustic indie folk song official audio',
    ),
  ];

  static const int _maxCategoryCache = 30;
  static final Map<String, YouTubePageResult> _categoryPageCache = {};

  static final Map<String, String> _genreSearchTerms = {
    'electric & dance': 'electronic dance edm song official audio',
    'today\'s top hits': 'billboard hot 100 official audio song',
    'pop global': 'pop hits songs official audio',
    'hip-hop & rap': 'hip hop rap songs official audio',
    'rock & alt': 'rock classics alternative songs official audio',
    'indie vibes': 'indie rock alternative song official audio',
    'chill & lo-fi': 'chill lofi hip hop beat track',
    'bollywood hits': 'bollywood hindi hit song official audio',
    'pakistani hits': 'pakistani coke studio urdu song official audio',
    'workout & hype': 'workout gym hype song official audio',
    'classical & piano': 'classical piano solo piece',
    'acoustic & folk': 'acoustic guitar folk song official audio',
  };

  /// Normalizes pill labels or slugs ('All', 'Top Hits', 'Hip-Hop', 'Lo-Fi', etc.) to canonical category keys.
  static String normalizeCategoryKey(String raw) {
    final cleaned = raw.toLowerCase().trim().replaceAll('-', '').replaceAll(' ', '_');
    switch (cleaned) {
      case 'all':
      case 'trending':
        return 'trending';
      case 'top_hits':
      case 'tophits':
        return 'top_hits';
      case 'pop':
        return 'pop';
      case 'hiphop':
      case 'hip_hop':
        return 'hiphop';
      case 'electronic':
      case 'edm':
        return 'electronic';
      case 'lofi':
      case 'lo_fi':
        return 'lofi';
      case 'rock':
        return 'rock';
      case 'acoustic':
        return 'acoustic';
      default:
        return raw.toLowerCase().trim();
    }
  }

  static MusicCategory getCategoryMeta(String rawKey) {
    final norm = normalizeCategoryKey(rawKey);
    return categories.firstWhere(
      (c) => c.key == norm,
      orElse: () => categories.first,
    );
  }

  static void _cacheCategoryPage(String key, YouTubePageResult page) {
    if (!_categoryPageCache.containsKey(key) && _categoryPageCache.length >= _maxCategoryCache) {
      _categoryPageCache.remove(_categoryPageCache.keys.first);
    }
    _categoryPageCache[key] = page;
  }

  static List<Song>? getCachedCategory(String key) {
    final norm = normalizeCategoryKey(key);
    return _categoryPageCache[norm]?.songs ?? _categoryPageCache[key]?.songs;
  }

  static YouTubePageResult? getCachedCategoryPage(String key) {
    final norm = normalizeCategoryKey(key);
    return _categoryPageCache[norm] ?? _categoryPageCache[key];
  }

  static bool _isValidMusicTrack(Song song) {
    final secs = song.duration.inSeconds;
    // Allow tracks from 25s up to 720s (12 minutes) while filtering out hour-long DJ compilations
    if (secs > 0 && (secs < 25 || secs > 720)) {
      return false;
    }
    final lowerTitle = song.title.toLowerCase();
    const spamTerms = [
      '10 hour',
      '10-hour',
      '1 hour',
      '2 hour',
      '3 hour',
      '10 hours',
      'in-video playlist',
      'full album',
      'full playlist',
      'nonstop mix',
      'breaking news',
      'live news',
    ];
    for (final term in spamTerms) {
      if (lowerTitle.contains(term)) return false;
    }
    return true;
  }

  /// NewPipe-style paged online search supporting infinite continuation tokens.
  static Future<YouTubePageResult> searchOnlinePaged(
    String query, {
    String? continuationToken,
    Set<String>? seenIds,
    bool filterCompilations = false,
  }) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty && (continuationToken == null || continuationToken.isEmpty)) {
      return const YouTubePageResult(songs: []);
    }

    final seen = seenIds ?? <String>{};
    final collected = <Song>[];
    String? nextToken = continuationToken;

    // Fetch page (and if compilation filtering pruned heavily, eagerly pull one more page)
    final maxAttempts = filterCompilations ? 2 : 1;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0 && (nextToken == null || nextToken.isEmpty)) break;

      final page = await YouTubeImporterService.searchYouTubePaged(
        cleanQ,
        continuationToken: attempt == 0 ? continuationToken : nextToken,
        seenIds: seen,
      );

      nextToken = page.continuationToken;
      if (page.songs.isEmpty) break;

      if (filterCompilations) {
        final valid = page.songs.where(_isValidMusicTrack).toList();
        collected.addAll(valid.isNotEmpty ? valid : page.songs);
      } else {
        collected.addAll(page.songs);
      }

      if (collected.length >= 16) break;
    }

    return YouTubePageResult(
      songs: collected,
      continuationToken: nextToken,
    );
  }

  /// Search online catalog via YouTube NewPipe extractor
  static Future<List<Song>> searchOnline(String query, {int limit = 50}) async {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return [];

    try {
      final page = await YouTubeImporterService.searchYouTubePaged(cleanQ, maxItems: limit);
      final filtered = page.songs.where(_isValidMusicTrack).toList();
      if (filtered.isNotEmpty) return filtered.take(limit).toList();
      if (page.songs.isNotEmpty) return page.songs.take(limit).toList();
    } catch (e) {
      debugPrint('[CatalogService] Search error: $e');
    }

    return [];
  }

  /// NewPipe-style infinite category fetcher:
  /// Page 1 returns a rich initial list + `continuationToken`; subsequent pages use `continuationToken`
  /// to stream unlimited tracks as the user scrolls!
  static Future<YouTubePageResult> fetchCategoryPage(
    String categoryKeyOrTitle, {
    String? customQuery,
    String? continuationToken,
    Set<String>? seenIds,
    bool forceRefresh = false,
  }) async {
    final normKey = normalizeCategoryKey(categoryKeyOrTitle);
    final isInitialPage = continuationToken == null || continuationToken.isEmpty;

    if (isInitialPage && !forceRefresh && _categoryPageCache.containsKey(normKey)) {
      final cached = _categoryPageCache[normKey]!;
      if (cached.songs.isNotEmpty) {
        if (seenIds != null) {
          for (final s in cached.songs) {
            seenIds.add(s.id.replaceFirst('yt_', ''));
          }
        }
        return cached;
      }
    }

    final lowerTitle = categoryKeyOrTitle.toLowerCase().trim();
    String effectiveQuery;
    if (_genreSearchTerms.containsKey(lowerTitle)) {
      effectiveQuery = _genreSearchTerms[lowerTitle]!;
    } else if (categories.any((c) => c.key == normKey)) {
      effectiveQuery = categories.firstWhere((c) => c.key == normKey).searchQuery;
    } else if (customQuery != null && customQuery.trim().isNotEmpty) {
      effectiveQuery = '${customQuery.trim()} song official audio';
    } else {
      effectiveQuery = '${categoryKeyOrTitle.trim()} song official audio';
    }

    final seen = seenIds ?? <String>{};

    // Fetch via NewPipe InnerTube paged search (with continuation token for infinite scrolling!)
    final ytPage = await searchOnlinePaged(
      effectiveQuery,
      continuationToken: continuationToken,
      seenIds: seen,
      filterCompilations: true,
    );

    if (ytPage.songs.isNotEmpty) {
      if (isInitialPage) {
        _cacheCategoryPage(normKey, ytPage);
      }
      return ytPage;
    }

    // Fallback on initial page if YouTube search was blocked: iTunes Music API
    if (isInitialPage) {
      try {
        final uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(effectiveQuery)}&media=music&entity=song&limit=60',
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
                streamUrl: '',
                source: 'itunes',
              ),
            );
          }
          if (songs.isNotEmpty) {
            final fallbackPage = YouTubePageResult(songs: songs);
            _cacheCategoryPage(normKey, fallbackPage);
            return fallbackPage;
          }
        }
      } catch (e) {
        debugPrint('[CatalogService] iTunes fallback error: $e');
      }
    }

    return _categoryPageCache[normKey] ?? const YouTubePageResult(songs: []);
  }

  /// Curated Genre Provider (backward compatible, backed by NewPipe paged engine)
  static Future<List<Song>> fetchCuratedGenre(
    String categoryTitle,
    String query, {
    bool forceRefresh = false,
  }) async {
    final page = await fetchCategoryPage(
      categoryTitle,
      customQuery: query,
      forceRefresh: forceRefresh,
    );
    return page.songs;
  }

  /// Fetch songs for a curated category via YouTube
  static Future<List<Song>> fetchCategory(String categoryKey, {bool forceRefresh = false}) async {
    final page = await fetchCategoryPage(categoryKey, forceRefresh: forceRefresh);
    return page.songs;
  }

  /// Fetch trending tracks
  static Future<List<Song>> fetchTrending({bool forceRefresh = false}) async {
    final page = await fetchCategoryPage('trending', forceRefresh: forceRefresh);
    return page.songs;
  }

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
    return _categoryPageCache.values.expand((p) => p.songs).toList();
  }
}
