import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '[${timestamp.inSeconds}s]: $text';
}

class LyricsResult {
  final List<LyricLine> syncedLyrics;
  final String plainLyrics;
  final bool hasSynced;

  const LyricsResult({
    required this.syncedLyrics,
    required this.plainLyrics,
    required this.hasSynced,
  });

  static const empty = LyricsResult(
    syncedLyrics: [],
    plainLyrics: '',
    hasSynced: false,
  );
}

class QueryCandidate {
  final String title;
  final String artist;
  final String searchString;

  const QueryCandidate({
    required this.title,
    required this.artist,
    required this.searchString,
  });
}

class LyricsService {
  LyricsService._();

  static final Map<String, LyricsResult> _cache = {};
  static const int _maxCacheSize = 80;

  static void invalidateCache(String title, String artist) {
    final cacheKey = '${title.toLowerCase().trim()}___${artist.toLowerCase().trim()}';
    _cache.remove(cacheKey);
  }

  static void clearCache() {
    _cache.clear();
  }

  /// Deep-cleans title string by stripping noise tags, resolution/fps, brackets, quotes, etc.
  static String cleanTitle(String input) {
    final cleaned = input
        // Strip leading CJK / bracket tags like 【MV】, [MV], 【PV】, [Official Video]
        .replaceAll(RegExp(r'^\s*[【\[\(\]](?:mv|pv|official\s*(?:music\s*)?video|video\s*oficial|clip\s*officiel)[】\]\)]\s*', caseSensitive: false), '')
        // Strip bracketed noise with standard & full-width / CJK brackets
        .replaceAll(
          RegExp(
            r'\s*[\(\[【（［「『](?:official\s*(?:music\s*)?video|official\s*audio|official|music\s*video|audio|lyric\s*video|lyrics?|visualizer|remastered|remaster|hd|4k|1080p|720p|60fps|mv|pv|live(?:\s*at[^)\]】）］」』]*)?|acoustic|slowed\s*\+?\s*reverb|slowed|reverb|nightcore|sped\s*up|bass\s*boosted|tiktok\s*(?:version)?|version|deluxe|prod\.[^)\]】）］」』]*|clean|explicit|letra|paroles|traduzione|sub\s*espa[ñn]ol|subtitulado|8d\s*audio|video\s*oficial|audio\s*oficial|clip\s*officiel)[^)\]】）］」』]*[\)\]】）］」』]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*[\(\[【（［](?:feat\.|ft\.)[^)\]】）］]*[\)\]】）］]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*-\s*(?:official\s*(?:music\s*)?video|official\s*audio|official|music\s*video|audio|lyric\s*video|lyrics?|visualizer|remastered|remaster|live).*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'^\s*\d{1,3}[\.\s-]+\s*'), '')
        // Strip surrounding quotation marks, preserving inner apostrophes (e.g. Don't, Can't)
        .replaceAll(RegExp(r'^["“”«»\x27]+|["“”«»\x27]+$'), '')
        .replaceAll(RegExp(r'["“”«»]'), '')
        .trim();

    return cleaned.isNotEmpty ? cleaned : input.trim();
  }

  /// Sanitizes YouTube channel names (strips "- Topic", "VEVO", "Official", etc.)
  static String cleanArtist(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'VEVO$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(?:official\s*(?:artist\s*)?channel|official|records|music|entertainment)$', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : input.trim();
  }

  /// Detects if an uploader channel is an aggregator/curator rather than the musical artist
  static bool isCuratorChannel(String channel) {
    final lower = channel.toLowerCase();
    const curatorWords = [
      'lyrics', 'lyric', 'vibes', 'vibe', 'hub', 'daily', 'chill', 'trap',
      'beats', 'edits', 'aesthetic', 'status', 'repost', 'nightcore',
      'slowed', 'nation', 'tv', 'fm', 'radio', 'records', 'sound',
      'sounds', 'promotions', 'clips', 'central', 'zone', 'city', 'gang'
    ];
    return curatorWords.any((w) => lower.contains(w));
  }

  /// Backward-compatible alias for existing callers
  static String cleanString(String input) => cleanTitle(input);

  /// Generates ordered prioritized candidate pairs for a track and uploader
  static List<QueryCandidate> generateCandidates(String rawTitle, String rawArtist) {
    final cleanedT = cleanTitle(rawTitle);
    final cleanedA = cleanArtist(rawArtist);
    final candidates = <QueryCandidate>[];
    final seen = <String>{};

    void addCandidate(String title, String artist) {
      final t = title.trim();
      final a = artist.trim();
      if (t.isEmpty) return;
      final key = '${t.toLowerCase()}___${a.toLowerCase()}';
      if (!seen.add(key)) return;

      final searchStr = a.isNotEmpty ? '$a $t' : t;
      candidates.add(QueryCandidate(title: t, artist: a, searchString: searchStr));
    }

    // 1. Check if title contains delimiter "Artist - Title" (standard third-party reupload pattern)
    // Support both ASCII and full-width CJK dashes/delimiters with optional ideographic spaces
    final delimiterMatch = RegExp(r'[\s\u3000]*[-–—―:|\/／－〜～~][\s\u3000]*').firstMatch(cleanedT);
    if (delimiterMatch != null) {
      final partA = cleanedT.substring(0, delimiterMatch.start).trim();
      final partB = cleanedT.substring(delimiterMatch.end).trim();

      // Case A: standard "Artist - Track" (90% of YouTube reuploads)
      if (partA.isNotEmpty && partB.isNotEmpty) {
        addCandidate(partB, partA);
      }

      // Case B: reversed "Track - Artist"
      if (partB.isNotEmpty && partA.isNotEmpty) {
        addCandidate(partA, partB);
      }
    }

    // 2. Pair cleaned title with cleaned artist (if artist is not a curator channel)
    if (!isCuratorChannel(cleanedA) && cleanedA.isNotEmpty) {
      addCandidate(cleanedT, cleanedA);
    }

    // 3. Extracted track name alone (fuzzy search engines excel at track-only query)
    if (delimiterMatch != null) {
      final partB = cleanedT.substring(delimiterMatch.end).trim();
      if (partB.isNotEmpty) {
        addCandidate(partB, '');
      }
    }

    // 4. Cleaned title with channel as fallback
    addCandidate(cleanedT, cleanedA);
    addCandidate(cleanedT, '');

    return candidates;
  }

  /// Parses LRC text supporting multi-tag lines, global offsets, fractional seconds, and hours
  static List<LyricLine> parseLrc(String lrcText) {
    final lines = <LyricLine>[];
    Duration globalOffset = Duration.zero;

    // 1. Pre-scan for global offset tag across the entire document
    final offsetRegex = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);
    final offsetMatch = offsetRegex.firstMatch(lrcText);
    if (offsetMatch != null) {
      final offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
      globalOffset = Duration(milliseconds: offsetMs);
    }

    // Matches timestamp prefix: [mm:ss], [mm:ss.xx], [mm:ss.xxx], [hh:mm:ss.xx]
    final prefixTimeTagRegex = RegExp(r'^(?:\[\s*(?:\d{1,3}:)?\d{1,3}:\d{2}(?:[:\.]\d{1,4})?\s*\])+');
    final individualTagRegex = RegExp(r'\[\s*(?:(\d{1,3}):)?(\d{1,3}):(\d{2})(?:[:\.](\d{1,4}))?\s*\]');

    for (final rawLine in lrcText.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      // Check if line starts with timestamp tags
      final prefixMatch = prefixTimeTagRegex.firstMatch(trimmed);
      if (prefixMatch == null) continue; // Skip metadata tags like [ar:...], [ti:...]

      final prefixString = prefixMatch.group(0)!;
      final lineText = trimmed.substring(prefixMatch.end).trim();

      final timeMatches = individualTagRegex.allMatches(prefixString);
      for (final match in timeMatches) {
        final hours = match.group(1) != null ? (int.tryParse(match.group(1)!) ?? 0) : 0;
        final mins = int.tryParse(match.group(2) ?? '0') ?? 0;
        final secs = int.tryParse(match.group(3) ?? '0') ?? 0;
        final frac = match.group(4) ?? '0';

        int millis = 0;
        if (frac.length == 1) {
          millis = (int.tryParse(frac) ?? 0) * 100;
        } else if (frac.length == 2) {
          millis = (int.tryParse(frac) ?? 0) * 10;
        } else if (frac.length >= 3) {
          millis = int.tryParse(frac.substring(0, 3)) ?? 0;
        }

        final ts = Duration(hours: hours, minutes: mins, seconds: secs, milliseconds: millis) + globalOffset;
        lines.add(LyricLine(
          timestamp: ts.isNegative ? Duration.zero : ts,
          text: lineText,
        ));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static LyricsResult? _extractLyricsResult(Map<String, dynamic> data) {
    final syncedStr = data['syncedLyrics'] as String?;
    final plainStr = data['plainLyrics'] as String? ?? '';
    final syncedLines = syncedStr != null ? parseLrc(syncedStr) : <LyricLine>[];

    if (syncedLines.isNotEmpty || plainStr.trim().isNotEmpty) {
      return LyricsResult(
        syncedLyrics: syncedLines,
        plainLyrics: plainStr.isNotEmpty ? plainStr : syncedLines.map((l) => l.text).join('\n'),
        hasSynced: syncedLines.isNotEmpty,
      );
    }
    return null;
  }

  static void _cacheLyrics(String key, LyricsResult result) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  static Future<LyricsResult> fetchLyrics(
    String title,
    String artist, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${title.toLowerCase().trim()}___${artist.toLowerCase().trim()}';

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    const headers = {
      'User-Agent': 'Sine/1.0.7 (https://github.com/taezeem14/Sine)',
      'Accept': 'application/json',
    };

    final candidates = generateCandidates(title, artist);

    // -----------------------------------------------------------------
    // Tier 1: Exact / High-Precision LRCLib match (/api/get)
    // -----------------------------------------------------------------
    for (final cand in candidates.where((c) => c.artist.isNotEmpty && c.title.isNotEmpty)) {
      try {
        final getUrl = Uri.https('lrclib.net', '/api/get', {
          'track_name': cand.title,
          'artist_name': cand.artist,
        });
        final resp = await http.get(getUrl, headers: headers).timeout(const Duration(seconds: 3));

        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            final res = _extractLyricsResult(data);
            if (res != null) {
              _cacheLyrics(cacheKey, res);
              return res;
            }
          }
        }
      } catch (_) {}
    }

    // -----------------------------------------------------------------
    // Tier 2: Resilient Fuzzy Search on LRCLib (/api/search?q=...)
    // -----------------------------------------------------------------
    for (final cand in candidates) {
      try {
        final searchUrl = Uri.https('lrclib.net', '/api/search', {
          'q': cand.searchString,
        });
        final searchResp = await http.get(searchUrl, headers: headers).timeout(const Duration(seconds: 4));

        if (searchResp.statusCode == 200) {
          final decodedList = jsonDecode(searchResp.body);
          if (decodedList is List && decodedList.isNotEmpty) {
            // First pass: try to find a candidate with synced lyrics
            for (final rawItem in decodedList) {
              if (rawItem is! Map) continue;
              final item = Map<String, dynamic>.from(rawItem);
              final syncedStr = item['syncedLyrics'] as String?;
              if (syncedStr != null && syncedStr.trim().isNotEmpty) {
                final syncedLines = parseLrc(syncedStr);
                if (syncedLines.isNotEmpty) {
                  final plainStr = item['plainLyrics'] as String? ?? '';
                  final res = LyricsResult(
                    syncedLyrics: syncedLines,
                    plainLyrics: plainStr.isNotEmpty ? plainStr : syncedLines.map((l) => l.text).join('\n'),
                    hasSynced: true,
                  );
                  _cacheLyrics(cacheKey, res);
                  return res;
                }
              }
            }

            // Second pass: any result with plain lyrics
            for (final rawItem in decodedList) {
              if (rawItem is! Map) continue;
              final item = Map<String, dynamic>.from(rawItem);
              final plainStr = item['plainLyrics'] as String?;
              if (plainStr != null && plainStr.trim().isNotEmpty) {
                final res = LyricsResult(
                  syncedLyrics: const [],
                  plainLyrics: plainStr.trim(),
                  hasSynced: false,
                );
                _cacheLyrics(cacheKey, res);
                return res;
              }
            }
          }
        }
      } catch (_) {}
    }

    // -----------------------------------------------------------------
    // Tier 3: Secondary Lyrics Fallback (Lyrics.ovh)
    // -----------------------------------------------------------------
    for (final cand in candidates.where((c) => c.artist.isNotEmpty && c.title.isNotEmpty).take(2)) {
      try {
        final ovhUrl = Uri.https('api.lyrics.ovh', '/v1/${Uri.encodeComponent(cand.artist)}/${Uri.encodeComponent(cand.title)}');
        final ovhResp = await http.get(ovhUrl, headers: headers).timeout(const Duration(seconds: 4));

        if (ovhResp.statusCode == 200) {
          final decoded = jsonDecode(ovhResp.body);
          if (decoded is Map && decoded['lyrics'] is String) {
            final plainLyrics = (decoded['lyrics'] as String).trim();
            if (plainLyrics.isNotEmpty) {
              final res = LyricsResult(
                syncedLyrics: const [],
                plainLyrics: plainLyrics,
                hasSynced: false,
              );
              _cacheLyrics(cacheKey, res);
              return res;
            }
          }
        }
      } catch (_) {}
    }

    return LyricsResult.empty;
  }
}
