import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'youtube_importer_service.dart';
import 'log_service.dart';

enum StemType {
  instrumental, // Karaoke / Instruments Only
  vocals,       // Acapella / Vocals Only
}

enum StemSource {
  youtubeSmartMatch,
  aiSeparation,
  dspFallback,
}

class StemResult {
  final StemType type;
  final StemSource source;
  final String? streamUrl;
  final String? candidateVideoId;
  final String? candidateTitle;
  final Duration? candidateDuration;
  final Duration durationDelta;
  final int confidenceScore;
  final bool isSuccess;
  final bool isLocal;
  final String? errorMessage;

  bool get isStudioStem => isSuccess && (source == StemSource.youtubeSmartMatch || source == StemSource.aiSeparation);
  bool get fallbackToDsp => source == StemSource.dspFallback || !isSuccess;

  const StemResult({
    required this.type,
    required this.source,
    this.streamUrl,
    this.candidateVideoId,
    this.candidateTitle,
    this.candidateDuration,
    this.durationDelta = Duration.zero,
    this.confidenceScore = 0,
    required this.isSuccess,
    this.isLocal = false,
    this.errorMessage,
  });

  factory StemResult.youtubeMatch({
    required StemType type,
    required String streamUrl,
    required String videoId,
    required String title,
    required Duration duration,
    required Duration delta,
    required int score,
  }) {
    return StemResult(
      type: type,
      source: StemSource.youtubeSmartMatch,
      streamUrl: streamUrl,
      candidateVideoId: videoId,
      candidateTitle: title,
      candidateDuration: duration,
      durationDelta: delta,
      confidenceScore: score,
      isSuccess: true,
      isLocal: false,
    );
  }

  factory StemResult.aiSeparated({
    required StemType type,
    required String localFilePath,
  }) {
    return StemResult(
      type: type,
      source: StemSource.aiSeparation,
      streamUrl: localFilePath,
      isSuccess: true,
      isLocal: true,
    );
  }

  factory StemResult.dspFallback({
    required StemType type,
    String? reason,
  }) {
    return StemResult(
      type: type,
      source: StemSource.dspFallback,
      isSuccess: false,
      errorMessage: reason,
    );
  }
}

class StemService {
  static final StemService instance = StemService._();
  StemService._();

  // In-memory LRU resolution cache
  static const int _maxCacheEntries = 60;
  final Map<String, StemResult> _stemCache = {};
  final Map<String, Future<StemResult>> _inFlightResolutions = {};

  /// Known high-fidelity backing track & karaoke channels
  static const Set<String> _proKaraokeChannels = {
    'sing king',
    'sing king karaoke',
    'karafun',
    'karafun karaoke',
    'karaoke version',
    'cc karaoke',
    'instrumental king',
    'the karaoke channel',
    'stingray karaoke',
    'vocal-star',
    'acousticinstrumentals',
  };

  /// Clean title of track to maximize YouTube search recall
  static String _sanitizeSongTitle(String raw) {
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

  /// Resolve stem (Instrumental or Vocals) for a song
  Future<StemResult> resolveStem({
    required Song song,
    required StemType type,
    Duration? targetDuration,
  }) async {
    final cacheKey = '${song.id}_${type.name}';

    // 1. Check in-memory cache
    if (_stemCache.containsKey(cacheKey)) {
      LogService.stream('StemService', 'Cache HIT for "${song.title}" (${type.name})');
      return _stemCache[cacheKey]!;
    }

    // 2. Prevent duplicate in-flight requests
    if (_inFlightResolutions.containsKey(cacheKey)) {
      return _inFlightResolutions[cacheKey]!;
    }

    final future = _resolveInternal(song, type, cacheKey);
    _inFlightResolutions[cacheKey] = future;
    return future.whenComplete(() {
      _inFlightResolutions.remove(cacheKey);
    });
  }

  Future<StemResult> _resolveInternal(Song song, StemType type, String cacheKey) async {
    // 1. Check local persistent AI stem file
    try {
      final localStem = await _checkLocalAiStem(song, type);
      if (localStem != null) {
        _cacheResult(cacheKey, localStem);
        return localStem;
      }
    } catch (_) {}

    // 2. Tier 1: YouTube Smart Stem Matching
    try {
      final ytResult = await _resolveYouTubeSmartStem(song, type);
      if (ytResult != null && ytResult.isSuccess) {
        _cacheResult(cacheKey, ytResult);
        return ytResult;
      }
    } catch (e) {
      LogService.w('StemService', 'Tier 1 YouTube stem matching error: $e');
    }

    // 3. Fallback to Tier 3 DSP
    final fallback = StemResult.dspFallback(
      type: type,
      reason: 'No studio stem match found within duration tolerance; using enhanced DSP.',
    );
    _cacheResult(cacheKey, fallback);
    return fallback;
  }

  void _cacheResult(String key, StemResult result) {
    if (_stemCache.length >= _maxCacheEntries) {
      _stemCache.remove(_stemCache.keys.first);
    }
    _stemCache[key] = result;
  }

  /// TIER 1: YouTube Smart Stem Matcher with Duration Validation and Heuristics
  Future<StemResult?> _resolveYouTubeSmartStem(Song song, StemType type) async {
    final cleanT = _sanitizeSongTitle(song.title);
    final cleanA = song.artist != 'Unknown Artist' && song.artist.isNotEmpty ? song.artist.trim() : '';

    // Build prioritized search queries
    final queries = <String>[];
    if (type == StemType.instrumental) {
      if (cleanA.isNotEmpty) {
        queries.add('$cleanT $cleanA instrumental');
        queries.add('$cleanT $cleanA karaoke');
      }
      queries.add('$cleanT official instrumental');
      queries.add('$cleanT backing track');
      queries.add('$cleanT off vocal');
    } else {
      if (cleanA.isNotEmpty) {
        queries.add('$cleanT $cleanA acapella');
        queries.add('$cleanT $cleanA vocals only');
      }
      queries.add('$cleanT isolated vocals');
      queries.add('$cleanT vocal stem');
      queries.add('$cleanT a cappella');
    }

    final originalDuration = song.duration;
    const maxDeltaSeconds = 7; // Maximum allowed duration discrepancy (maintains lyrics sync)

    for (final q in queries.take(3)) {
      LogService.stream('StemService', 'Searching YouTube for stem: "$q"...');
      final candidates = await YouTubeImporterService.searchYouTube(q, limit: 10);
      if (candidates.isEmpty) continue;

      Song? bestCandidate;
      int highestScore = -100;
      Duration bestDelta = Duration.zero;

      for (final cand in candidates) {
        final score = _scoreCandidate(
          candidate: cand,
          original: song,
          cleanTitle: cleanT,
          cleanArtist: cleanA,
          type: type,
          maxDeltaSeconds: maxDeltaSeconds,
        );

        if (score > highestScore) {
          highestScore = score;
          bestCandidate = cand;
          bestDelta = (cand.duration - originalDuration).abs();
        }
      }

      // If we found a candidate with strong confidence (score >= 45)
      if (bestCandidate != null && highestScore >= 45) {
        final videoId = bestCandidate.id.replaceFirst('yt_', '').trim();
        LogService.stream(
          'StemService',
          'Matched stem candidate: "${bestCandidate.title}" (Score: $highestScore, Delta: ${bestDelta.inSeconds}s)',
        );

        // Extract direct playable Opus / AAC audio stream
        final streamUrls = await YouTubeImporterService.getAudioStreamUrls(videoId);
        if (streamUrls.isNotEmpty) {
          return StemResult.youtubeMatch(
            type: type,
            streamUrl: streamUrls.first,
            videoId: videoId,
            title: bestCandidate.title,
            duration: bestCandidate.duration,
            delta: bestDelta,
            score: highestScore,
          );
        }
      }
    }

    return null;
  }

  /// Heuristic scoring engine for stem candidates
  int _scoreCandidate({
    required Song candidate,
    required Song original,
    required String cleanTitle,
    required String cleanArtist,
    required StemType type,
    required int maxDeltaSeconds,
  }) {
    final candTitle = candidate.title.toLowerCase();
    final candAuthor = candidate.artist.toLowerCase();
    final origDur = original.duration;
    final candDur = candidate.duration;

    // 1. Duration check (CRITICAL for synced lyrics)
    if (origDur.inSeconds > 10 && candDur.inSeconds > 0) {
      final delta = (candDur - origDur).inSeconds.abs();
      if (delta > maxDeltaSeconds) {
        return -9999; // Reject tracks that will desync lyrics or are extended cuts
      }
    }

    int score = 0;

    // 2. Closeness to original duration
    final deltaSec = (candDur - origDur).inSeconds.abs();
    if (deltaSec == 0) {
      score += 60;
    } else if (deltaSec <= 2) {
      score += 45;
    } else if (deltaSec <= 4) {
      score += 30;
    } else if (deltaSec <= 7) {
      score += 15;
    }

    // 3. Anti-Junk / Exclusion filters
    const junkWords = [
      'guitar cover', 'piano cover', 'acoustic cover', 'slowed', 'reverb',
      '8d audio', 'nightcore', 'sped up', 'reaction', 'parody', 'synthesia',
      'synthesizer tutorial'
    ];
    for (final junk in junkWords) {
      if (candTitle.contains(junk) && !cleanTitle.toLowerCase().contains(junk)) {
        return -9999;
      }
    }

    // 4. Positive Keyword Matching
    if (type == StemType.instrumental) {
      if (candTitle.contains('official instrumental') || candTitle.contains('original instrumental')) {
        score += 55;
      } else if (candTitle.contains('instrumental version')) {
        score += 45;
      } else if (candTitle.contains('instrumental')) {
        score += 35;
      }
      if (candTitle.contains('karaoke')) score += 35;
      if (candTitle.contains('backing track')) score += 30;
      if (candTitle.contains('off vocal') || candTitle.contains('no vocals')) score += 30;
    } else {
      if (candTitle.contains('studio acapella') || candTitle.contains('official acapella')) {
        score += 60;
      } else if (candTitle.contains('acapella') || candTitle.contains('a cappella')) {
        score += 45;
      }
      if (candTitle.contains('vocals only') || candTitle.contains('isolated vocals')) {
        score += 40;
      }
      if (candTitle.contains('vocal stem')) score += 35;
    }

    // 5. Channel and Artist Credibility
    if (cleanArtist.isNotEmpty && (candAuthor.contains(cleanArtist.toLowerCase()) || candTitle.contains(cleanArtist.toLowerCase()))) {
      score += 25;
    }
    if (candAuthor.contains('- topic')) {
      score += 35; // Official YouTube Music Topic Release
    }
    for (final chan in _proKaraokeChannels) {
      if (candAuthor.contains(chan) || candTitle.contains(chan)) {
        score += 40;
        break;
      }
    }

    return score;
  }

  /// TIER 2: Check if Demucs AI stem was previously generated and cached to disk
  Future<StemResult?> _checkLocalAiStem(Song song, StemType type) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cleanId = song.id.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final stemFile = File('${docDir.path}/stems/${cleanId}_${type.name}.mp3');
      if (await stemFile.exists() && (await stemFile.length()) > 50000) {
        return StemResult.aiSeparated(type: type, localFilePath: stemFile.path);
      }
    } catch (_) {}
    return null;
  }

  /// TIER 2: Free AI Demucs via Hugging Face Space (Gradio 4 SSE API)
  Future<StemResult?> separateAudioWithDemucs({
    required File inputFile,
    required Song song,
    required StemType type,
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final stemsDir = Directory('${docDir.path}/stems');
      if (!await stemsDir.exists()) {
        await stemsDir.create(recursive: true);
      }

      const hfSpaceBase = 'https://abidlabs-music-separation.hf.space';

      // 1. Upload audio file to Gradio
      final uploadUri = Uri.parse('$hfSpaceBase/upload');
      final request = http.MultipartRequest('POST', uploadUri)
        ..files.add(await http.MultipartFile.fromPath('files', inputFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final responseBody = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode != 200) return null;

      final uploadJson = jsonDecode(responseBody) as List?;
      if (uploadJson == null || uploadJson.isEmpty) return null;
      final tempRemotePath = uploadJson.first as String;

      // 2. Enqueue Demucs prediction task
      final callUri = Uri.parse('$hfSpaceBase/call/predict');
      final callResp = await http.post(
        callUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "data": [
            {
              "path": tempRemotePath,
              "meta": {"_type": "gradio.FileData"}
            }
          ]
        }),
      ).timeout(const Duration(seconds: 20));

      if (callResp.statusCode != 200) return null;
      final eventId = (jsonDecode(callResp.body) as Map<String, dynamic>)['event_id'] as String?;
      if (eventId == null) return null;

      // 3. Stream result via SSE until completion (up to 120s timeout)
      final sseUri = Uri.parse('$hfSpaceBase/call/predict/$eventId');
      final client = http.Client();
      final sseReq = http.Request('GET', sseUri);
      final sseResp = await client.send(sseReq).timeout(const Duration(seconds: 120));

      String? vocalsUrl;
      String? instrumentalUrl;

      await for (final line in sseResp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data:')) {
          final dataStr = line.replaceFirst('data:', '').trim();
          try {
            final parsed = jsonDecode(dataStr);
            if (parsed is List && parsed.length >= 2) {
              vocalsUrl = parsed[0]['url'] as String? ?? '$hfSpaceBase/file=${parsed[0]['path']}';
              instrumentalUrl = parsed[1]['url'] as String? ?? '$hfSpaceBase/file=${parsed[1]['path']}';
              break;
            }
          } catch (_) {}
        }
      }

      final targetUrl = type == StemType.vocals ? vocalsUrl : instrumentalUrl;
      if (targetUrl == null) return null;

      // 4. Download and cache separated stem locally
      final cleanId = song.id.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final targetFile = File('${stemsDir.path}/${cleanId}_${type.name}.mp3');
      final dlResp = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 30));
      if (dlResp.statusCode == 200) {
        await targetFile.writeAsBytes(dlResp.bodyBytes);
        return StemResult.aiSeparated(type: type, localFilePath: targetFile.path);
      }
    } catch (e) {
      LogService.w('StemService', 'Demucs AI separation error: $e');
    }
    return null;
  }

  /// Invalidate cache for a song
  void invalidate(String songId) {
    _stemCache.remove('${songId}_${StemType.instrumental.name}');
    _stemCache.remove('${songId}_${StemType.vocals.name}');
  }

  /// Clear all cache
  void clearAll() {
    _stemCache.clear();
    _inFlightResolutions.clear();
  }

  /// Clear all cache across the singleton
  static void clearMemoryCache() {
    instance.clearAll();
  }
}
