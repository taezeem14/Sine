import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'catalog_service.dart';

enum ExternalPlaylistSource { spotify, appleMusic, youtube, unsupported, unknown }

typedef PlaylistSource = ExternalPlaylistSource;

class ImportedTrackMeta {
  final String title;
  final String artist;

  const ImportedTrackMeta({required this.title, required this.artist});
}

class PlaylistImportResult {
  final ExternalPlaylistSource source;
  final String title;
  final String? coverUrl;
  final List<Song> resolvedSongs;
  final int totalSourceTracks;
  final String? error;

  const PlaylistImportResult({
    required this.source,
    required this.title,
    this.coverUrl,
    required this.resolvedSongs,
    required this.totalSourceTracks,
    this.error,
  });
}

class PlaylistImportService {
  PlaylistImportService._();

  static ExternalPlaylistSource detectSource(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('spotify.com/playlist') || lower.contains('spotify.link')) {
      return ExternalPlaylistSource.spotify;
    }
    if (lower.contains('music.apple.com') && lower.contains('/playlist/')) {
      return ExternalPlaylistSource.appleMusic;
    }
    if (lower.contains('youtube.com/playlist') || lower.contains('list=')) {
      return ExternalPlaylistSource.youtube;
    }
    return ExternalPlaylistSource.unsupported;
  }

  static String? extractSpotifyPlaylistId(String url) {
    final regExp = RegExp(r'playlist\/([a-zA-Z0-9]+)');
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  static String? extractAppleMusicPlaylistId(String url) {
    final match = RegExp(r'playlist\/[^\/]+\/([a-zA-Z0-9\.]+)').firstMatch(url);
    return match?.group(1);
  }

  static String cleanTrackTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*\([^)]*(?:official|video|audio|lyrics|hd|4k)[^)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*(?:official|video|audio|lyrics|hd|4k)[^\]]*\]', caseSensitive: false), '')
        .trim();
  }

  static Future<PlaylistImportResult> importExternalPlaylist(
    String url, {
    void Function(int current, int total)? onProgress,
  }) async {
    final source = detectSource(url);
    switch (source) {
      case ExternalPlaylistSource.spotify:
        return _importSpotifyPlaylist(url, onProgress);
      case ExternalPlaylistSource.appleMusic:
        return _importAppleMusicPlaylist(url, onProgress);
      case ExternalPlaylistSource.youtube:
      case ExternalPlaylistSource.unknown:
      case ExternalPlaylistSource.unsupported:
        return const PlaylistImportResult(
          source: ExternalPlaylistSource.unsupported,
          title: '',
          resolvedSongs: [],
          totalSourceTracks: 0,
          error: 'Please use YouTube Importer or provide a valid Spotify/Apple Music playlist URL',
        );
    }
  }

  static Future<PlaylistImportResult> _importSpotifyPlaylist(
    String url,
    void Function(int current, int total)? onProgress,
  ) async {
    try {
      final regExp = RegExp(r'playlist\/([a-zA-Z0-9]+)');
      final match = regExp.firstMatch(url);
      final playlistId = match?.group(1);
      if (playlistId == null) {
        return const PlaylistImportResult(
          source: ExternalPlaylistSource.spotify,
          title: '',
          resolvedSongs: [],
          totalSourceTracks: 0,
          error: 'Could not parse Spotify playlist ID',
        );
      }

      // Spotify Public Embed Endpoint (No OAuth / API Keys required)
      final embedUrl = Uri.parse('https://open.spotify.com/embed/playlist/$playlistId');
      final res = await http.get(embedUrl, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        return PlaylistImportResult(
          source: ExternalPlaylistSource.spotify,
          title: '',
          resolvedSongs: [],
          totalSourceTracks: 0,
          error: 'Spotify returned status ${res.statusCode}',
        );
      }

      final html = res.body;

      // Extract Playlist Title
      String playlistTitle = 'Spotify Playlist';
      final titleMatch = RegExp(r'<title>([^<]+)<\/title>', caseSensitive: false).firstMatch(html);
      if (titleMatch != null) {
        playlistTitle = titleMatch.group(1)?.replaceAll('| Spotify', '').trim() ?? playlistTitle;
      }

      // Extract tracks from __NEXT_DATA__ JSON script or regex fallback
      final List<ImportedTrackMeta> trackMetas = [];
      final scriptMatch = RegExp(r'<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>')
          .firstMatch(html);

      if (scriptMatch != null) {
        try {
          final jsonData = jsonDecode(scriptMatch.group(1)!);
          final entity = jsonData['props']?['pageProps']?['state']?['data']?['entity'];
          if (entity != null) {
            playlistTitle = entity['name']?.toString() ?? playlistTitle;
            final trackList = entity['trackList'] as List? ?? [];
            for (final t in trackList) {
              final name = t['title']?.toString() ?? t['name']?.toString() ?? '';
              final subtitle = t['subtitle']?.toString() ?? '';
              if (name.isNotEmpty) {
                trackMetas.add(ImportedTrackMeta(title: name, artist: subtitle));
              }
            }
          }
        } catch (_) {}
      }

      // Regex fallback if Next.js hydration structure varies
      if (trackMetas.isEmpty) {
        final rowRegex = RegExp(r'"name":"([^"]+)","artists":\[\{"name":"([^"]+)"');
        for (final m in rowRegex.allMatches(html)) {
          final tName = m.group(1);
          final aName = m.group(2);
          if (tName != null && aName != null) {
            trackMetas.add(ImportedTrackMeta(title: tName, artist: aName));
          }
        }
      }

      if (trackMetas.isEmpty) {
        return PlaylistImportResult(
          source: ExternalPlaylistSource.spotify,
          title: playlistTitle,
          resolvedSongs: [],
          totalSourceTracks: 0,
          error: 'No tracks found in public Spotify playlist embed',
        );
      }

      // Resolve tracks to YouTube audio streams (limit first 40 for responsiveness)
      final resolvedSongs = await _resolveTracksToYouTube(trackMetas.take(40).toList(), onProgress);

      return PlaylistImportResult(
        source: ExternalPlaylistSource.spotify,
        title: playlistTitle,
        resolvedSongs: resolvedSongs,
        totalSourceTracks: trackMetas.length,
      );
    } catch (e) {
      return PlaylistImportResult(
        source: ExternalPlaylistSource.spotify,
        title: '',
        resolvedSongs: [],
        totalSourceTracks: 0,
        error: 'Spotify import failed: $e',
      );
    }
  }

  static Future<PlaylistImportResult> _importAppleMusicPlaylist(
    String url,
    void Function(int current, int total)? onProgress,
  ) async {
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        return PlaylistImportResult(
          source: ExternalPlaylistSource.appleMusic,
          title: '',
          resolvedSongs: [],
          totalSourceTracks: 0,
          error: 'Apple Music returned status ${res.statusCode}',
        );
      }

      final html = res.body;
      String playlistTitle = 'Apple Music Playlist';
      final ogTitle = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html);
      if (ogTitle != null) {
        playlistTitle = ogTitle.group(1)?.replaceAll('on Apple Music', '').trim() ?? playlistTitle;
      }

      final List<ImportedTrackMeta> trackMetas = [];
      // Look for schema.org music recording JSON-LD or meta tags
      final songRegex = RegExp(r'"name":"([^"]+)","@type":"MusicRecording"[^}]*"byArtist":\{"@type":"MusicGroup","name":"([^"]+)"');
      for (final m in songRegex.allMatches(html)) {
        final t = m.group(1);
        final a = m.group(2);
        if (t != null && a != null) {
          trackMetas.add(ImportedTrackMeta(title: t, artist: a));
        }
      }

      if (trackMetas.isEmpty) {
        // Fallback meta match
        final metaRegex = RegExp(r'<meta property="music:song" content="([^"]+)"');
        for (final m in metaRegex.allMatches(html)) {
          final title = m.group(1) ?? '';
          if (title.isNotEmpty) {
            trackMetas.add(ImportedTrackMeta(title: title, artist: 'Apple Music'));
          }
        }
      }

      if (trackMetas.isEmpty) {
        return PlaylistImportResult(
          source: ExternalPlaylistSource.appleMusic,
          title: playlistTitle,
          resolvedSongs: [],
          totalSourceTracks: 0,
          error: 'No tracks found in Apple Music playlist page',
        );
      }

      final resolvedSongs = await _resolveTracksToYouTube(trackMetas.take(40).toList(), onProgress);

      return PlaylistImportResult(
        source: ExternalPlaylistSource.appleMusic,
        title: playlistTitle,
        resolvedSongs: resolvedSongs,
        totalSourceTracks: trackMetas.length,
      );
    } catch (e) {
      return PlaylistImportResult(
        source: ExternalPlaylistSource.appleMusic,
        title: '',
        resolvedSongs: [],
        totalSourceTracks: 0,
        error: 'Apple Music import failed: $e',
      );
    }
  }

  static Future<List<Song>> _resolveTracksToYouTube(
    List<ImportedTrackMeta> metas,
    void Function(int current, int total)? onProgress,
  ) async {
    final List<Song> results = [];
    int count = 0;

    for (final meta in metas) {
      count++;
      onProgress?.call(count, metas.length);
      try {
        final query = '${cleanTrackTitle(meta.title)} ${meta.artist} audio'.trim();
        final searchResults = await CatalogService.searchOnline(query, limit: 5);
        if (searchResults.isNotEmpty) {
          results.add(searchResults.first);
        } else {
          // Create placeholder song that will resolve on tap
          results.add(Song(
            id: 'imp_${meta.title.hashCode.abs()}',
            title: meta.title,
            artist: meta.artist,
            duration: const Duration(minutes: 3, seconds: 30),
            artworkUrl: '',
            streamUrl: '',
          ));
        }
      } catch (_) {
        // Graceful skip
      }
    }
    return results;
  }
}
