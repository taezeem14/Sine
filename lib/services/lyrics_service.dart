import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricWord {
  final Duration timestamp;
  final Duration duration;
  final String text;

  const LyricWord({
    required this.timestamp,
    required this.duration,
    required this.text,
  });
}

class LyricLine {
  final Duration timestamp;
  final Duration duration;
  final String text;
  final List<LyricWord> words;
  final bool isWordSynced;
  final String? translation;
  final String? romanization;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.duration = Duration.zero,
    this.words = const [],
    this.isWordSynced = false,
    this.translation,
    this.romanization,
  });

  LyricLine copyWith({
    Duration? timestamp,
    Duration? duration,
    String? text,
    List<LyricWord>? words,
    bool? isWordSynced,
    String? translation,
    String? romanization,
  }) {
    return LyricLine(
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      text: text ?? this.text,
      words: words ?? this.words,
      isWordSynced: isWordSynced ?? this.isWordSynced,
      translation: translation ?? this.translation,
      romanization: romanization ?? this.romanization,
    );
  }

  @override
  String toString() => '[${timestamp.inSeconds}s]: $text (words: ${words.length})';
}

class LyricsResult {
  final List<LyricLine> syncedLyrics;
  final String plainLyrics;
  final bool hasSynced;
  final bool hasWordSync;

  const LyricsResult({
    required this.syncedLyrics,
    required this.plainLyrics,
    required this.hasSynced,
    this.hasWordSync = false,
  });

  static const empty = LyricsResult(
    syncedLyrics: [],
    plainLyrics: '',
    hasSynced: false,
    hasWordSync: false,
  );

  bool get isEmpty => syncedLyrics.isEmpty && plainLyrics.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  LyricsResult copyWith({
    List<LyricLine>? syncedLyrics,
    String? plainLyrics,
    bool? hasSynced,
    bool? hasWordSync,
  }) {
    return LyricsResult(
      syncedLyrics: syncedLyrics ?? this.syncedLyrics,
      plainLyrics: plainLyrics ?? this.plainLyrics,
      hasSynced: hasSynced ?? this.hasSynced,
      hasWordSync: hasWordSync ?? this.hasWordSync,
    );
  }
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

/// Advanced multi-provider synchronized lyrics service with syllable/word-by-word timing,
/// translation, and romanization inspired by BetterLyrics and Metrolist (GPL-3.0).
class LyricsService {
  LyricsService._();

  static final Map<String, LyricsResult> _cache = {};
  static final Map<String, List<LyricLine>> _translatedCache = {};
  static const int _maxCacheSize = 100;

  static void invalidateCache(String title, String artist) {
    final cacheKey = '${title.toLowerCase().trim()}___${artist.toLowerCase().trim()}';
    _cache.remove(cacheKey);
  }

  static void clearCache() {
    _cache.clear();
    _translatedCache.clear();
  }

  /// Checks whether a track has been tempo-modified (slowed, reverb, sped up, nightcore, daycore, etc.)
  /// Synchronized lyrics are disabled for modified-tempo tracks to prevent timing desync.
  static bool isTempoModified(String title, [String? artist]) {
    final combined = '$title ${artist ?? ''}'.toLowerCase();
    final regex = RegExp(
      r'\b(slowed(\s*(down|and|\+|&)?\s*reverb)?|reverb|sped\s*up|speed\s*up|speedup|nightcore|daycore|pitched(\s*(up|down))?|fast\s*(version|song|audio)?|slow\s*(version|song|audio)?|chopped(\s*(&|and)?\s*screwed)?|8d(\s*audio)?|16d|bass\s*boost(ed)?)\b',
      caseSensitive: false,
    );
    return regex.hasMatch(combined);
  }

  /// Deep-cleans title string by stripping noise tags, resolution/fps, brackets, quotes, etc.
  static String cleanTitle(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'^\s*[【\[\(\]](?:mv|pv|official\s*(?:music\s*)?video|video\s*oficial|clip\s*officiel)[】\]\)]\s*', caseSensitive: false), '')
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

    final delimiterMatch = RegExp(r'[\s\u3000]*[-–—―:|\/／－〜～~][\s\u3000]*').firstMatch(cleanedT);
    if (delimiterMatch != null) {
      final partA = cleanedT.substring(0, delimiterMatch.start).trim();
      final partB = cleanedT.substring(delimiterMatch.end).trim();

      if (partA.isNotEmpty && partB.isNotEmpty) {
        addCandidate(partB, partA);
        addCandidate(partA, partB);
      }
    }

    if (!isCuratorChannel(cleanedA) && cleanedA.isNotEmpty) {
      addCandidate(cleanedT, cleanedA);
      // Inverted candidate to resolve "Author - Title" mistaking author as title
      addCandidate(cleanedA, cleanedT);
    }

    final strippedT = cleanedT.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '').trim();
    if (strippedT.isNotEmpty && strippedT != cleanedT) {
      addCandidate(strippedT, cleanedA);
      if (cleanedA.isNotEmpty) addCandidate(cleanedA, strippedT);
    }

    if (delimiterMatch != null) {
      final partB = cleanedT.substring(delimiterMatch.end).trim();
      if (partB.isNotEmpty) {
        addCandidate(partB, '');
      }
    }

    addCandidate(cleanedT, cleanedA);
    addCandidate(cleanedA, cleanedT);
    addCandidate(cleanedT, '');

    return candidates;
  }

  /// Parses standard LRC as well as enhanced word-timed LRC tags (<mm:ss.xx>word)
  static List<LyricLine> parseLrc(String lrcText) {
    final lines = <LyricLine>[];
    Duration globalOffset = Duration.zero;

    final offsetRegex = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);
    final offsetMatch = offsetRegex.firstMatch(lrcText);
    if (offsetMatch != null) {
      final offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
      globalOffset = Duration(milliseconds: offsetMs);
    }

    final prefixTimeTagRegex = RegExp(r'^(?:\[\s*(?:\d{1,3}:)?\d{1,3}:\d{2}(?:[:\.]\d{1,4})?\s*\])+');
    final individualTagRegex = RegExp(r'\[\s*(?:(\d{1,3}):)?(\d{1,3}):(\d{2})(?:[:\.](\d{1,4}))?\s*\]');
    final syllableTagRegex = RegExp(r'<(\d{1,3}):(\d{2})(?:[:\.](\d{1,4}))?>([^<]*)');

    for (final rawLine in lrcText.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final prefixMatch = prefixTimeTagRegex.firstMatch(trimmed);
      if (prefixMatch == null) continue;

      final prefixString = prefixMatch.group(0)!;
      final bodyText = trimmed.substring(prefixMatch.end).trim();

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

        final lineTs = Duration(hours: hours, minutes: mins, seconds: secs, milliseconds: millis) + globalOffset;
        final validLineTs = lineTs.isNegative ? Duration.zero : lineTs;

        // Check for syllable/word timing tokens: <mm:ss.xx>word
        final syllableMatches = syllableTagRegex.allMatches(bodyText).toList();
        if (syllableMatches.isNotEmpty) {
          final words = <LyricWord>[];
          final cleanBuffer = StringBuffer();

          for (int i = 0; i < syllableMatches.length; i++) {
            final sm = syllableMatches[i];
            final sMins = int.tryParse(sm.group(1) ?? '0') ?? 0;
            final sSecs = int.tryParse(sm.group(2) ?? '0') ?? 0;
            final sFrac = sm.group(3) ?? '0';

            int sMillis = 0;
            if (sFrac.length == 1) {
              sMillis = (int.tryParse(sFrac) ?? 0) * 100;
            } else if (sFrac.length == 2) {
              sMillis = (int.tryParse(sFrac) ?? 0) * 10;
            } else if (sFrac.length >= 3) {
              sMillis = int.tryParse(sFrac.substring(0, 3)) ?? 0;
            }

            final wordTs = Duration(minutes: sMins, seconds: sSecs, milliseconds: sMillis) + globalOffset;
            final wordText = sm.group(4) ?? '';
            cleanBuffer.write(wordText);

            Duration wordDur = const Duration(milliseconds: 350);
            if (i < syllableMatches.length - 1) {
              final nextSm = syllableMatches[i + 1];
              final nMin = int.tryParse(nextSm.group(1) ?? '0') ?? 0;
              final nSec = int.tryParse(nextSm.group(2) ?? '0') ?? 0;
              final nFrac = nextSm.group(3) ?? '0';
              int nMil = 0;
              if (nFrac.length == 1) {
                nMil = (int.tryParse(nFrac) ?? 0) * 100;
              } else if (nFrac.length == 2) {
                nMil = (int.tryParse(nFrac) ?? 0) * 10;
              } else if (nFrac.length >= 3) {
                nMil = int.tryParse(nFrac.substring(0, 3)) ?? 0;
              }

              final nextTs = Duration(minutes: nMin, seconds: nSec, milliseconds: nMil) + globalOffset;
              final diff = nextTs - wordTs;
              if (diff > Duration.zero) wordDur = diff;
            }

            words.add(LyricWord(
              timestamp: wordTs.isNegative ? Duration.zero : wordTs,
              duration: wordDur,
              text: wordText,
            ));
          }

          lines.add(LyricLine(
            timestamp: validLineTs,
            text: cleanBuffer.toString().trim(),
            words: words,
            isWordSynced: true,
          ));
        } else {
          // Standard line-synced LRC
          lines.add(LyricLine(
            timestamp: validLineTs,
            text: bodyText,
            words: const [],
            isWordSynced: false,
          ));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate line durations from consecutive timestamps
    for (int i = 0; i < lines.length - 1; i++) {
      final diff = lines[i + 1].timestamp - lines[i].timestamp;
      if (diff > Duration.zero) {
        lines[i] = lines[i].copyWith(duration: diff);
      }
    }

    return lines;
  }

  static LyricsResult? _extractLyricsResult(Map<String, dynamic> data) {
    final syncedStr = data['syncedLyrics'] as String?;
    final plainStr = data['plainLyrics'] as String? ?? '';
    final syncedLines = syncedStr != null ? parseLrc(syncedStr) : <LyricLine>[];
    final hasWords = syncedLines.any((l) => l.isWordSynced);

    if (syncedLines.isNotEmpty || plainStr.trim().isNotEmpty) {
      return LyricsResult(
        syncedLyrics: syncedLines,
        plainLyrics: plainStr.isNotEmpty ? plainStr : syncedLines.map((l) => l.text).join('\n'),
        hasSynced: syncedLines.isNotEmpty,
        hasWordSync: hasWords,
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

  /// When only plain unsynchronized lyrics are available for a foreign or indie track,
  /// this method calculates intelligent line-by-line estimated timestamps distributed
  /// across the track duration, allowing synchronized auto-scrolling and tap-to-seek.
  static List<LyricLine> synthesizeTimedLyrics(String plainText, Duration totalDuration) {
    if (plainText.trim().isEmpty || totalDuration.inSeconds < 15) return const [];

    final rawLines = plainText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('[') && !l.endsWith(':'))
        .toList();

    if (rawLines.isEmpty) return const [];

    final totalSec = totalDuration.inSeconds.toDouble();
    final introSec = (totalSec * 0.08).clamp(5.0, 20.0);
    final outroSec = (totalSec * 0.05).clamp(4.0, 15.0);
    final vocalSec = (totalSec - introSec - outroSec).clamp(10.0, totalSec);

    final stepSec = vocalSec / rawLines.length;
    final lines = <LyricLine>[];

    for (int i = 0; i < rawLines.length; i++) {
      final ts = Duration(milliseconds: ((introSec + i * stepSec) * 1000).toInt());
      final dur = Duration(milliseconds: (stepSec * 1000).toInt());
      lines.add(LyricLine(
        timestamp: ts,
        duration: dur,
        text: rawLines[i],
        isWordSynced: false,
      ));
    }

    return lines;
  }

  /// Master fetch lyrics method with multi-provider cascade:
  /// Tier 1: LRCLib exact API
  /// Tier 2: LRCLib search API
  /// Tier 3: Netease Cloud Music (with official synced translations)
  /// Tier 4: Lyrics.ovh
  static Future<LyricsResult> fetchLyrics(
    String title,
    String artist, {
    Duration? trackDuration,
    bool forceRefresh = false,
  }) async {
    if (isTempoModified(title, artist)) {
      return LyricsResult.empty;
    }

    final cacheKey = '${title.toLowerCase().trim()}___${artist.toLowerCase().trim()}';

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    const headers = {
      'User-Agent': 'Sine/1.2.6 (https://github.com/taezeem14/Sine)',
      'Accept': 'application/json',
    };

    final candidates = generateCandidates(title, artist);
    LyricsResult? fallbackPlainResult;

    // -----------------------------------------------------------------
    // Tier 1: Exact / High-Precision LRCLib match (/api/get)
    // -----------------------------------------------------------------
    for (final cand in candidates.where((c) => c.artist.isNotEmpty && c.title.isNotEmpty)) {
      try {
        final queryParams = <String, String>{
          'track_name': cand.title,
          'artist_name': cand.artist,
        };
        if (trackDuration != null && trackDuration.inSeconds > 0) {
          queryParams['duration'] = trackDuration.inSeconds.toString();
        }
        final getUrl = Uri.https('lrclib.net', '/api/get', queryParams);
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
                    hasWordSync: syncedLines.any((l) => l.isWordSynced),
                  );
                  _cacheLyrics(cacheKey, res);
                  return res;
                }
              }
            }

            // Save first plain lyric candidate as fallback without prematurely halting search for synced lyrics
            if (fallbackPlainResult == null) {
              for (final rawItem in decodedList) {
                if (rawItem is! Map) continue;
                final item = Map<String, dynamic>.from(rawItem);
                final plainStr = item['plainLyrics'] as String?;
                if (plainStr != null && plainStr.trim().isNotEmpty) {
                  fallbackPlainResult = LyricsResult(
                    syncedLyrics: const [],
                    plainLyrics: plainStr.trim(),
                    hasSynced: false,
                    hasWordSync: false,
                  );
                  break;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // -----------------------------------------------------------------
    // Tier 3: Netease Cloud Music (High coverage & built-in translations)
    // -----------------------------------------------------------------
    for (final cand in candidates.take(2)) {
      try {
        final neteaseRes = await _fetchNeteaseLyrics(cand.title, cand.artist);
        if (neteaseRes != null && neteaseRes.isNotEmpty) {
          _cacheLyrics(cacheKey, neteaseRes);
          return neteaseRes;
        }
      } catch (_) {}
    }

    // -----------------------------------------------------------------
    // Tier 4: Secondary Lyrics Fallback (Lyrics.ovh)
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
                hasWordSync: false,
              );
              _cacheLyrics(cacheKey, res);
              return res;
            }
          }
        }
      } catch (_) {}
    }

    if (fallbackPlainResult != null && fallbackPlainResult.plainLyrics.isNotEmpty) {
      if (trackDuration != null && trackDuration.inSeconds >= 20) {
        final synthesizedLines = synthesizeTimedLyrics(fallbackPlainResult.plainLyrics, trackDuration);
        if (synthesizedLines.isNotEmpty) {
          final enriched = LyricsResult(
            syncedLyrics: synthesizedLines,
            plainLyrics: fallbackPlainResult.plainLyrics,
            hasSynced: true,
            hasWordSync: false,
          );
          _cacheLyrics(cacheKey, enriched);
          return enriched;
        }
      }
      _cacheLyrics(cacheKey, fallbackPlainResult);
      return fallbackPlainResult;
    }

    _cacheLyrics(cacheKey, LyricsResult.empty);
    return LyricsResult.empty;
  }

  /// Netease Cloud Music API fetcher for synchronized lyrics & translations
  static Future<LyricsResult?> _fetchNeteaseLyrics(String title, String artist) async {
    try {
      final query = artist.isNotEmpty ? '$title $artist' : title;
      final searchUrl = Uri.parse('https://music.163.com/api/search/get/web?s=${Uri.encodeComponent(query)}&type=1&offset=0&total=true&limit=1');
      final searchResp = await http.get(searchUrl, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': 'https://music.163.com/',
      }).timeout(const Duration(seconds: 4));

      if (searchResp.statusCode != 200) return null;
      final searchJson = jsonDecode(searchResp.body) as Map<String, dynamic>;
      final songs = searchJson['result']?['songs'] as List?;
      if (songs == null || songs.isEmpty) return null;

      final songId = songs.first['id'];
      if (songId == null) return null;

      final lyricUrl = Uri.parse('https://music.163.com/api/song/lyric?os=pc&id=$songId&lv=-1&kv=-1&tv=-1');
      final lyricResp = await http.get(lyricUrl, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': 'https://music.163.com/',
      }).timeout(const Duration(seconds: 4));

      if (lyricResp.statusCode != 200) return null;
      final lyricJson = jsonDecode(lyricResp.body) as Map<String, dynamic>;

      final lrcStr = lyricJson['lrc']?['lyric'] as String?;
      final tLrcStr = lyricJson['tlyric']?['lyric'] as String?;

      if (lrcStr == null || lrcStr.trim().isEmpty) return null;

      final synced = parseLrc(lrcStr);
      final translatedMap = <Duration, String>{};

      if (tLrcStr != null && tLrcStr.isNotEmpty) {
        final tLines = parseLrc(tLrcStr);
        for (final tl in tLines) {
          translatedMap[tl.timestamp] = tl.text;
        }
      }

      // Merge translations into synced lyrics
      final merged = synced.map((line) {
        final trans = translatedMap[line.timestamp];
        return line.copyWith(translation: trans);
      }).toList();

      return LyricsResult(
        syncedLyrics: merged,
        plainLyrics: merged.map((l) => l.text).join('\n'),
        hasSynced: merged.isNotEmpty,
        hasWordSync: merged.any((l) => l.isWordSynced),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // TRANSLATION & ROMANIZATION BATCH ENGINE (Google GTX)
  // ---------------------------------------------------------------------------

  /// Batched machine translation of synchronized lyrics into the target language
  static Future<List<LyricLine>> translateLyrics(
    List<LyricLine> lines, {
    String targetLang = 'en',
  }) async {
    if (lines.isEmpty) return lines;

    final cacheKey = 'trans_${targetLang}_${lines.first.text.hashCode}_${lines.length}';
    if (_translatedCache.containsKey(cacheKey)) {
      return _translatedCache[cacheKey]!;
    }

    try {
      // Batch up to 40 lines at once using delimiter
      const delimiter = '\n;;\n';
      final chunks = <List<LyricLine>>[];
      for (int i = 0; i < lines.length; i += 35) {
        chunks.add(lines.sublist(i, (i + 35 > lines.length) ? lines.length : i + 35));
      }

      final translatedLines = <LyricLine>[];

      for (final chunk in chunks) {
        final joinedText = chunk.map((l) => l.text.replaceAll(';;', '')).join(delimiter);
        final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(joinedText)}',
        );

        final resp = await http.get(url).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as List;
          final parts = json[0] as List?;
          final fullTranslated = parts?.map((p) => p[0]?.toString() ?? '').join() ?? '';
          final split = fullTranslated.split(RegExp(r'\s*;;\s*'));

          for (int i = 0; i < chunk.length; i++) {
            final transText = i < split.length ? split[i].trim() : null;
            translatedLines.add(chunk[i].copyWith(translation: transText));
          }
        } else {
          translatedLines.addAll(chunk);
        }
      }

      _translatedCache[cacheKey] = translatedLines;
      return translatedLines;
    } catch (_) {
      return lines;
    }
  }

  /// Batched romanization for CJK/non-Latin lyrics
  static Future<List<LyricLine>> romanizeLyrics(List<LyricLine> lines) async {
    if (lines.isEmpty) return lines;

    final cacheKey = 'rom_${lines.first.text.hashCode}_${lines.length}';
    if (_translatedCache.containsKey(cacheKey)) {
      return _translatedCache[cacheKey]!;
    }

    try {
      const delimiter = ' 0000 ';
      final chunks = <List<LyricLine>>[];
      for (int i = 0; i < lines.length; i += 30) {
        chunks.add(lines.sublist(i, (i + 30 > lines.length) ? lines.length : i + 30));
      }

      final romanizedLines = <LyricLine>[];

      for (final chunk in chunks) {
        final joinedText = chunk.map((l) => l.text).join(delimiter);
        final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=rm&q=${Uri.encodeComponent(joinedText)}',
        );

        final resp = await http.get(url).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as List;
          final parts = json[0] as List?;
          String? romText;
          if (parts != null && parts.isNotEmpty && parts.last is List && (parts.last as List).length > 2) {
            romText = parts.last[3]?.toString() ?? parts.last[2]?.toString();
          }

          if (romText != null && romText.isNotEmpty) {
            final split = romText.split(RegExp(r'\s*0000\s*'));
            for (int i = 0; i < chunk.length; i++) {
              final r = i < split.length ? split[i].trim() : null;
              romanizedLines.add(chunk[i].copyWith(romanization: r));
            }
          } else {
            romanizedLines.addAll(chunk);
          }
        } else {
          romanizedLines.addAll(chunk);
        }
      }

      _translatedCache[cacheKey] = romanizedLines;
      return romanizedLines;
    } catch (_) {
      return lines;
    }
  }
}
