import 'dart:async';
import 'package:flutter/foundation.dart';
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


enum BackgroundStemStatus {
  idle,
  enqueued,
  downloadingBuffer,
  uploadingGradio,
  separatingNeural,
  completed,
  failed,
}

class BackgroundStemTask {
  final Song song;
  final StemType type;
  final DateTime enqueuedAt;
  BackgroundStemStatus status;
  String? resultPath;
  String? errorMessage;

  BackgroundStemTask({
    required this.song,
    required this.type,
    required this.enqueuedAt,
    this.status = BackgroundStemStatus.enqueued,
    this.resultPath,
    this.errorMessage,
  });
}

class StemDiagnosticStep {
  final String stage;
  final DateTime timestamp;
  final Duration latency;
  final bool isSuccess;
  final String details;
  final Map<String, dynamic> metadata;

  const StemDiagnosticStep({
    required this.stage,
    required this.timestamp,
    required this.latency,
    required this.isSuccess,
    required this.details,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
    'stage': stage,
    'timestamp': timestamp.toIso8601String(),
    'latencyMs': latency.inMilliseconds,
    'isSuccess': isSuccess,
    'details': details,
    'metadata': metadata,
  };
}

class StemPipelineDiagnostic {
  final String id;
  final String songId;
  final String songTitle;
  final String songArtist;
  final StemType requestedStem;
  final DateTime startedAt;
  DateTime? completedAt;
  StemSource finalSource;
  bool isSuccess;
  String? resolvedFileOrUrl;
  final List<StemDiagnosticStep> steps;
  String? failureReason;

  Duration get totalLatency => (completedAt ?? DateTime.now()).difference(startedAt);

  StemPipelineDiagnostic({
    required this.id,
    required this.songId,
    required this.songTitle,
    required this.songArtist,
    required this.requestedStem,
    required this.startedAt,
    this.completedAt,
    this.finalSource = StemSource.dspFallback,
    this.isSuccess = false,
    this.resolvedFileOrUrl,
    List<StemDiagnosticStep>? steps,
    this.failureReason,
  }) : steps = steps ?? [];

  void addStep({
    required String stage,
    required Duration latency,
    required bool isSuccess,
    required String details,
    Map<String, dynamic> metadata = const {},
  }) {
    steps.add(StemDiagnosticStep(
      stage: stage,
      timestamp: DateTime.now(),
      latency: latency,
      isSuccess: isSuccess,
      details: details,
      metadata: metadata,
    ));
  }

  void complete({
    required StemSource source,
    required bool success,
    String? resolvedTarget,
    String? reason,
  }) {
    completedAt = DateTime.now();
    finalSource = source;
    isSuccess = success;
    resolvedFileOrUrl = resolvedTarget;
    failureReason = reason;
  }
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

  // Diagnostic history & notification
  final List<StemPipelineDiagnostic> _diagnosticHistory = [];
  List<StemPipelineDiagnostic> get diagnosticHistory => List.unmodifiable(_diagnosticHistory);
  final ValueNotifier<StemPipelineDiagnostic?> lastDiagnosticNotifier = ValueNotifier(null);
  StemPipelineDiagnostic? get lastDiagnostic => lastDiagnosticNotifier.value;

  // Background queue processing
  final ValueNotifier<BackgroundStemTask?> activeBackgroundTaskNotifier = ValueNotifier(null);
  final List<BackgroundStemTask> _backgroundQueue = [];
  bool _isProcessingBackground = false;

  // Engine preference: 'auto', 'bsRoformer', 'demucs', 'youtube', 'dsp'
  String _enginePreference = 'auto';
  String get enginePreference => _enginePreference;
  void setEnginePreference(String engine) {
    _enginePreference = engine;
  }

  /// Enqueue track for background neural stem separation
  void enqueueBackgroundSeparation(Song song, StemType type) {
    if (_backgroundQueue.any((t) => t.song.id == song.id && t.type == type)) return;
    final task = BackgroundStemTask(
      song: song,
      type: type,
      enqueuedAt: DateTime.now(),
    );
    _backgroundQueue.add(task);
    _processBackgroundQueue();
  }

  Future<void> _processBackgroundQueue() async {
    if (_isProcessingBackground || _backgroundQueue.isEmpty) return;
    _isProcessingBackground = true;

    while (_backgroundQueue.isNotEmpty) {
      final task = _backgroundQueue.first;
      activeBackgroundTaskNotifier.value = task;
      task.status = BackgroundStemStatus.downloadingBuffer;
      activeBackgroundTaskNotifier.value = task;

      try {
        final result = await resolveStem(song: task.song, type: task.type);
        if (result.isSuccess && result.streamUrl != null) {
          task.status = BackgroundStemStatus.completed;
          task.resultPath = result.streamUrl;
        } else {
          task.status = BackgroundStemStatus.failed;
          task.errorMessage = result.errorMessage ?? 'Separation produced no output';
        }
      } catch (e) {
        task.status = BackgroundStemStatus.failed;
        task.errorMessage = e.toString();
      }

      _backgroundQueue.removeAt(0);
      activeBackgroundTaskNotifier.value = null;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isProcessingBackground = false;
  }

  /// Interactive benchmark & diagnostic separation tester
  Future<StemPipelineDiagnostic> runDiagnosticSeparation(Song song, StemType type) async {
    final cacheKey = '${song.id}_${type.name}';
    _stemCache.remove(cacheKey);
    final diagnostic = StemPipelineDiagnostic(
      id: 'diag_${DateTime.now().millisecondsSinceEpoch}',
      songId: song.id,
      songTitle: song.title,
      songArtist: song.artist,
      requestedStem: type,
      startedAt: DateTime.now(),
    );
    await _resolveInternal(song, type, cacheKey, diagnostic: diagnostic);
    return diagnostic;
  }

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
    'official instrumental',
    'studio instrumental',
    'mr karaoke',
    'zoom karaoke',
    'sunfly karaoke',
    'pianonest',
    'costantino carrara',
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

    final future = _resolveInternal(song, type, cacheKey, targetDuration: targetDuration);
    _inFlightResolutions[cacheKey] = future;
    return future.whenComplete(() {
      _inFlightResolutions.remove(cacheKey);
    });
  }

  Future<StemResult> _resolveInternal(
    Song song,
    StemType type,
    String cacheKey, {
    Duration? targetDuration,
    StemPipelineDiagnostic? diagnostic,
  }) async {
    final diag = diagnostic ?? StemPipelineDiagnostic(
      id: 'diag_${DateTime.now().millisecondsSinceEpoch}',
      songId: song.id,
      songTitle: song.title,
      songArtist: song.artist,
      requestedStem: type,
      startedAt: DateTime.now(),
    );

    // 1. Check local persistent AI / studio stem file (0ms hit)
    final cacheSw = Stopwatch()..start();
    try {
      final localStem = await _checkLocalAiStem(song, type);
      cacheSw.stop();
      if (localStem != null) {
        LogService.stream('StemService', 'Local disk cache hit for "${song.title}" (${type.name})');
        diag.addStep(
          stage: 'Tier 1: Local Disk Cache',
          latency: cacheSw.elapsed,
          isSuccess: true,
          details: '0ms Disk Hit: ${localStem.streamUrl}',
        );
        diag.complete(source: StemSource.aiSeparation, success: true, resolvedTarget: localStem.streamUrl);
        _recordDiagnostic(diag);
        _cacheResult(cacheKey, localStem);
        return localStem;
      } else {
        diag.addStep(
          stage: 'Tier 1: Local Disk Cache',
          latency: cacheSw.elapsed,
          isSuccess: false,
          details: 'Cache miss. Proceeding to remote neural separation.',
        );
      }
    } catch (e) {
      cacheSw.stop();
      diag.addStep(
        stage: 'Tier 1: Local Disk Cache',
        latency: cacheSw.elapsed,
        isSuccess: false,
        details: 'Cache check error: $e',
      );
    }

    // 2. PRIORITY #1: SOTA AI Neural Engine (BS-RoFormer 12.97 dB SDR & Demucs v4)
    if (_enginePreference != 'youtube' && _enginePreference != 'dsp') {
      final aiSw = Stopwatch()..start();
      try {
        LogService.stream('StemService', 'Prioritizing SOTA AI Neural separation for "${song.title}" (${type.name})...');
        final aiResult = await separateAudioWithAi(song: song, type: type, diagnostic: diag);
        aiSw.stop();
        if (aiResult != null && aiResult.isSuccess) {
          LogService.stream('StemService', 'AI source separation successful for "${song.title}" (${type.name})');
          diag.addStep(
            stage: 'Tier 2: SOTA AI Neural Engine',
            latency: aiSw.elapsed,
            isSuccess: true,
            details: 'Separation complete: ${aiResult.streamUrl}',
          );
          diag.complete(source: StemSource.aiSeparation, success: true, resolvedTarget: aiResult.streamUrl);
          _recordDiagnostic(diag);
          _cacheResult(cacheKey, aiResult);
          return aiResult;
        } else {
          diag.addStep(
            stage: 'Tier 2: SOTA AI Neural Engine',
            latency: aiSw.elapsed,
            isSuccess: false,
            details: 'AI Neural spaces unavailable or timed out.',
          );
        }
      } catch (e) {
        aiSw.stop();
        LogService.w('StemService', 'AI separation error: $e');
        diag.addStep(
          stage: 'Tier 2: SOTA AI Neural Engine',
          latency: aiSw.elapsed,
          isSuccess: false,
          details: 'AI error: $e',
        );
      }
    } else {
      diag.addStep(
        stage: 'Tier 2: SOTA AI Neural Engine',
        latency: Duration.zero,
        isSuccess: false,
        details: 'Skipped by engine preference ($_enginePreference)',
      );
    }

    // 3. SECONDARY: High-Speed Studio Master Matcher (Sing King, KaraFun, Official Topic Instrumental releases)
    if (_enginePreference != 'dsp') {
      final ytSw = Stopwatch()..start();
      try {
        LogService.stream('StemService', 'Searching verified studio backing stems for "${song.title}" (${type.name})...');
        final ytResult = await _resolveYouTubeSmartStem(song, type, targetDuration: targetDuration, diagnostic: diag);
        ytSw.stop();
        if (ytResult != null && ytResult.isSuccess) {
          LogService.stream('StemService', 'Studio Master matched for "${song.title}" (${type.name})');
          diag.addStep(
            stage: 'Tier 3: YouTube Studio Matcher',
            latency: ytSw.elapsed,
            isSuccess: true,
            details: 'Matched "${ytResult.candidateTitle}" (Score: ${ytResult.confidenceScore})',
          );
          diag.complete(source: StemSource.youtubeSmartMatch, success: true, resolvedTarget: ytResult.streamUrl);
          _recordDiagnostic(diag);
          _cacheResult(cacheKey, ytResult);
          return ytResult;
        } else {
          diag.addStep(
            stage: 'Tier 3: YouTube Studio Matcher',
            latency: ytSw.elapsed,
            isSuccess: false,
            details: 'No candidate satisfied duration/confidence criteria.',
          );
        }
      } catch (e) {
        ytSw.stop();
        LogService.w('StemService', 'Tier 2 Studio stem matching error: $e');
        diag.addStep(
          stage: 'Tier 3: YouTube Studio Matcher',
          latency: ytSw.elapsed,
          isSuccess: false,
          details: 'Search error: $e',
        );
      }
    } else {
      diag.addStep(
        stage: 'Tier 3: YouTube Studio Matcher',
        latency: Duration.zero,
        isSuccess: false,
        details: 'Skipped by engine preference ($_enginePreference)',
      );
    }

    // 4. Fallback: Tier 3 Hardware DSP Vocal Shaper
    final fallback = StemResult.dspFallback(
      type: type,
      reason: 'Studio and AI stems offline; using native DSP vocal notch/boost.',
    );
    diag.addStep(
      stage: 'Tier 4: Hardware DSP Isolation',
      latency: const Duration(milliseconds: 2),
      isSuccess: true,
      details: 'Parametric DSP vocal notch/boost active.',
    );
    diag.complete(
      source: StemSource.dspFallback,
      success: false,
      reason: 'Studio and AI stems offline; using native DSP vocal notch/boost.',
    );
    _recordDiagnostic(diag);
    _cacheResult(cacheKey, fallback);
    return fallback;
  }

  void _recordDiagnostic(StemPipelineDiagnostic diag) {
    if (_diagnosticHistory.length >= 30) {
      _diagnosticHistory.removeAt(0);
    }
    _diagnosticHistory.add(diag);
    lastDiagnosticNotifier.value = diag;
  }

  void _cacheResult(String key, StemResult result) {
    if (_stemCache.length >= _maxCacheEntries) {
      _stemCache.remove(_stemCache.keys.first);
    }
    _stemCache[key] = result;
  }

  /// TIER 1: YouTube Smart Stem Matcher with Duration Validation and Heuristics
  Future<StemResult?> _resolveYouTubeSmartStem(Song song, StemType type, {Duration? targetDuration, StemPipelineDiagnostic? diagnostic}) async {
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
      queries.add('$cleanT sing king');
      queries.add('$cleanT karafun');
      queries.add('$cleanT instrumental');
      queries.add('$cleanT karaoke');
      queries.add('$cleanT off vocal');
    } else {
      if (cleanA.isNotEmpty) {
        queries.add('$cleanT $cleanA studio acapella');
        queries.add('$cleanT $cleanA acapella');
        queries.add('$cleanT $cleanA vocals only');
        queries.add('$cleanT $cleanA isolated vocals');
      }
      queries.add('$cleanT official acapella');
      queries.add('$cleanT studio acapella');
      queries.add('$cleanT isolated vocals');
      queries.add('$cleanT acapella');
      queries.add('$cleanT vocals only');
      queries.add('$cleanT vocal stem');
      queries.add('$cleanT vocal track');
      queries.add('$cleanT a cappella');
    }

    final effectiveDuration = (targetDuration != null && targetDuration > Duration.zero)
        ? targetDuration
        : song.duration;
    const maxDeltaSeconds = 18; // Tolerates standard 8-15s count-in / backing track variations

    for (final q in queries.take(5)) {
      LogService.stream('StemService', 'Searching YouTube for stem: "$q"...');
      final candidates = await YouTubeImporterService.searchYouTube(q, limit: 10);
      if (candidates.isEmpty) continue;

      Song? bestCandidate;
      int highestScore = -100;
      Duration bestDelta = Duration.zero;

      for (final cand in candidates) {
        final score = _scoreCandidate(
          candidate: cand,
          effectiveDuration: effectiveDuration,
          cleanTitle: cleanT,
          cleanArtist: cleanA,
          type: type,
          maxDeltaSeconds: maxDeltaSeconds,
        );

        if (score > highestScore) {
          highestScore = score;
          bestCandidate = cand;
          bestDelta = (cand.duration - effectiveDuration).abs();
        }
      }

      // If we found a candidate with confidence (score >= 30)
      if (bestCandidate != null && highestScore >= 30) {
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
    required Duration effectiveDuration,
    required String cleanTitle,
    required String cleanArtist,
    required StemType type,
    required int maxDeltaSeconds,
  }) {
    final candTitle = candidate.title.toLowerCase();
    final candAuthor = candidate.artist.toLowerCase();
    final origDur = effectiveDuration;
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
    } else if (deltaSec <= 8) {
      score += 20;
    } else if (deltaSec <= 18) {
      score += 10;
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

    // Strict Cross-Stem Exclusion Filters (Guarantees no accidental cross-contamination)
    if (type == StemType.vocals) {
      if (candTitle.contains('instrumental') || candTitle.contains('karaoke') || candTitle.contains('backing track') || candTitle.contains('off vocal') || candTitle.contains('no vocal')) {
        return -9999; // Never pick an instrumental when the user asked for Acapella!
      }
    } else {
      if (candTitle.contains('acapella') || candTitle.contains('a cappella') || candTitle.contains('vocals only') || candTitle.contains('isolated vocal') || candTitle.contains('vocal only')) {
        return -9999; // Never pick an acapella when the user asked for Karaoke!
      }
    }

    // 4. Positive Keyword Matching
    if (type == StemType.instrumental) {
      if (candTitle.contains('official instrumental') || candTitle.contains('original instrumental')) {
        score += 60;
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
        score += 70;
      } else if (candTitle.contains('acapella') || candTitle.contains('a cappella')) {
        score += 55;
      }
      if (candTitle.contains('vocals only') || candTitle.contains('isolated vocals') || candTitle.contains('isolated vocal')) {
        score += 50;
      }
      if (candTitle.contains('vocal stem') || candTitle.contains('vocal track')) {
        score += 45;
      }
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

  /// TIER 1: Check if Demucs AI stem was previously generated and cached to disk
  Future<StemResult?> _checkLocalAiStem(Song song, StemType type) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final cleanId = song.id.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final wavFile = File('${docDir.path}/stems/${cleanId}_${type.name}.wav');
      if (await wavFile.exists() && (await wavFile.length()) > 50000) {
        return StemResult.aiSeparated(type: type, localFilePath: wavFile.path);
      }
      final mp3File = File('${docDir.path}/stems/${cleanId}_${type.name}.mp3');
      if (await mp3File.exists() && (await mp3File.length()) > 50000) {
        return StemResult.aiSeparated(type: type, localFilePath: mp3File.path);
      }
    } catch (_) {}
    return null;
  }

  /// Prepares a valid local audio file from song (either from disk or downloading direct stream on-device)
  Future<File?> _prepareLocalAudioForSong(Song song, Directory stemsDir, String cleanId) async {
    try {
      // 1. Check if song already has a local file on device (e.g. downloaded track)
      if (song.streamUrl.isNotEmpty && !song.streamUrl.startsWith('http')) {
        final f = File(song.streamUrl);
        if (await f.exists() && (await f.length()) > 30000) {
          return f;
        }
      }

      // 2. Check if previously saved temp audio exists
      final tempFile = File('${stemsDir.path}/raw_$cleanId.m4a');
      if (await tempFile.exists() && (await tempFile.length()) > 30000) {
        return tempFile;
      }

      // 3. Download the audio stream directly on the client device (bypasses YouTube 403 IP block on remote servers)
      final ytId = song.id.replaceFirst('yt_', '').trim();
      List<String> streamUrls = [];
      if (ytId.isNotEmpty && ytId.length >= 10 && ytId.length <= 15) {
        streamUrls = await YouTubeImporterService.getAudioStreamUrls(ytId);
      }
      
      final downloadUrl = streamUrls.isNotEmpty
          ? streamUrls.first
          : (song.streamUrl.startsWith('http') ? song.streamUrl : null);

      if (downloadUrl != null) {
        LogService.stream('StemService', 'Downloading audio buffer for AI stem separation: "${song.title}"...');
        final client = http.Client();
        final req = http.Request('GET', Uri.parse(downloadUrl));
        req.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36';
        req.headers['Range'] = 'bytes=0-8388608'; // First 8MB (covers up to ~7 mins of audio)
        
        final streamed = await client.send(req).timeout(const Duration(seconds: 15));
        if (streamed.statusCode == 200 || streamed.statusCode == 206) {
          final bytes = await streamed.stream.toBytes().timeout(const Duration(seconds: 20));
          if (bytes.length > 20000) {
            await tempFile.writeAsBytes(bytes);
            return tempFile;
          }
        }
      }
    } catch (e) {
      LogService.w('StemService', 'Failed to prepare audio buffer for AI: $e');
    }
    return null;
  }

  /// Primary AI Engine: BS-RoFormer (World SOTA 12.97 dB SDR) & Demucs v4
  Future<StemResult?> separateAudioWithAi({
    required Song song,
    required StemType type,
    File? inputFile,
    StemPipelineDiagnostic? diagnostic,
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final stemsDir = Directory('${docDir.path}/stems');
      if (!await stemsDir.exists()) {
        await stemsDir.create(recursive: true);
      }

      final cleanId = song.id.replaceAll(RegExp(r'[^\w\-_]'), '_');

      // Prepare local audio buffer on-device to avoid YouTube 403 Forbidden errors on remote servers
      final localAudio = inputFile ?? await _prepareLocalAudioForSong(song, stemsDir, cleanId);

      // 1. First attempt: BS-RoFormer (Highest fidelity vocal separation)
      final bsResult = (_enginePreference == 'demucs') ? null : await _tryBsRoformerSeparation(
        song: song,
        type: type,
        cleanId: cleanId,
        stemsDir: stemsDir,
        inputFile: localAudio,
        diagnostic: diagnostic,
      );
      if (bsResult != null && bsResult.isSuccess) {
        return bsResult;
      }

      // 2. Second attempt: Demucs v4
      final demucsResult = (_enginePreference == 'bsRoformer') ? null : await _tryDemucsSeparation(
        song: song,
        type: type,
        cleanId: cleanId,
        stemsDir: stemsDir,
        inputFile: localAudio,
        diagnostic: diagnostic,
      );
      if (demucsResult != null && demucsResult.isSuccess) {
        return demucsResult;
      }
    } catch (e) {
      LogService.w('StemService', 'AI separation pipeline error: $e');
    }
    return null;
  }

  /// Backward-compatible alias for Demucs separation callers
  Future<StemResult?> separateAudioWithDemucs({
    required Song song,
    required StemType type,
    File? inputFile,
  }) => separateAudioWithAi(song: song, type: type, inputFile: inputFile);

  /// Engine 1: BS-RoFormer via Hugging Face Space (SDR 12.97 dB)
  Future<StemResult?> _tryBsRoformerSeparation({
    required Song song,
    required StemType type,
    required String cleanId,
    required Directory stemsDir,
    File? inputFile,
    StemPipelineDiagnostic? diagnostic,
  }) async {
    const spaceBase = 'https://hugging-apps-bs-roformer-leap-audio-separator.hf.space';
    try {
      if (inputFile == null || !await inputFile.exists() || (await inputFile.length()) < 10000) {
        return null;
      }

      final uploadUri = Uri.parse('$spaceBase/gradio_api/upload');
      final request = http.MultipartRequest('POST', uploadUri)
        ..files.add(await http.MultipartFile.fromPath('files', inputFile.path));
      final streamed = await request.send().timeout(const Duration(seconds: 25));
      if (streamed.statusCode != 200) return null;

      final resBody = await streamed.stream.bytesToString();
      final parsed = jsonDecode(resBody) as List?;
      if (parsed == null || parsed.isEmpty) return null;
      final serverAudioPath = parsed.first as String;

      // Model choice uses Unicode em-dash \u2014 as required by Gradio dropdown
      final modelChoice = type == StemType.vocals ? 'Standard \u2014 Vocals' : 'Standard \u2014 Instruments';
      final callUri = Uri.parse('$spaceBase/gradio_api/call/separate');
      final callResp = await http.post(
        callUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': [
            {
              'path': serverAudioPath,
              'meta': {'_type': 'gradio.FileData'}
            },
            modelChoice
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (callResp.statusCode != 200) return null;
      final eventId = (jsonDecode(callResp.body) as Map<String, dynamic>)['event_id'] as String?;
      if (eventId == null) return null;

      final sseUri = Uri.parse('$spaceBase/gradio_api/call/separate/$eventId');
      final client = http.Client();
      final sseReq = http.Request('GET', sseUri);
      final sseResp = await client.send(sseReq).timeout(const Duration(seconds: 35));

      String? primaryUrl;
      String? secondaryUrl;

      await for (final line in sseResp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data:')) {
          final dataStr = line.replaceFirst('data:', '').trim();
          try {
            final parsedData = jsonDecode(dataStr);
            if (parsedData is List && parsedData.length >= 2) {
              final pObj = parsedData[0];
              final sObj = parsedData[1];
              primaryUrl = pObj['url'] as String? ?? '$spaceBase/gradio_api/file=${pObj['path']}';
              secondaryUrl = sObj['url'] as String? ?? '$spaceBase/gradio_api/file=${sObj['path']}';
              break;
            }
          } catch (_) {}
        }
      }

      final vocalsUrl = type == StemType.vocals ? primaryUrl : secondaryUrl;
      final instrumentalUrl = type == StemType.vocals ? secondaryUrl : primaryUrl;

      final targetUrl = type == StemType.vocals ? vocalsUrl : instrumentalUrl;
      if (targetUrl == null) return null;

      final targetFile = File('${stemsDir.path}/${cleanId}_${type.name}.wav');
      final resp = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200 && resp.bodyBytes.length > 10000) {
        await targetFile.writeAsBytes(resp.bodyBytes);

        // Also save complementary stem in background for 0ms subsequent toggle
        final otherType = type == StemType.vocals ? StemType.instrumental : StemType.vocals;
        final otherUrl = type == StemType.vocals ? instrumentalUrl : vocalsUrl;
        if (otherUrl != null) {
          final otherFile = File('${stemsDir.path}/${cleanId}_${otherType.name}.wav');
          http.get(Uri.parse(otherUrl)).then((r) {
            if (r.statusCode == 200 && r.bodyBytes.length > 10000) {
              otherFile.writeAsBytes(r.bodyBytes);
            }
          }).catchError((_) {});
        }

        return StemResult.aiSeparated(type: type, localFilePath: targetFile.path);
      }
    } catch (e) {
      LogService.w('StemService', 'BS-RoFormer separation attempt failed: $e');
    }
    return null;
  }

  /// Engine 2: Demucs v4 via Hugging Face Space
  Future<StemResult?> _tryDemucsSeparation({
    required Song song,
    required StemType type,
    required String cleanId,
    required Directory stemsDir,
    File? inputFile,
    StemPipelineDiagnostic? diagnostic,
  }) async {
    const spaceBase = 'https://abidlabs-music-separation.hf.space';
    try {
      if (inputFile == null || !await inputFile.exists() || (await inputFile.length()) < 10000) {
        return null;
      }

      final uploadUri = Uri.parse('$spaceBase/gradio_api/upload');
      final request = http.MultipartRequest('POST', uploadUri)
        ..files.add(await http.MultipartFile.fromPath('files', inputFile.path));
      final streamed = await request.send().timeout(const Duration(seconds: 25));
      if (streamed.statusCode != 200) return null;

      final resBody = await streamed.stream.bytesToString();
      final parsed = jsonDecode(resBody) as List?;
      if (parsed == null || parsed.isEmpty) return null;
      final serverAudioPath = parsed.first as String;

      final callUri = Uri.parse('$spaceBase/gradio_api/call/inference');
      final callResp = await http.post(
        callUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': [
            {
              'path': serverAudioPath,
              'meta': {'_type': 'gradio.FileData'}
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (callResp.statusCode != 200) return null;
      final eventId = (jsonDecode(callResp.body) as Map<String, dynamic>)['event_id'] as String?;
      if (eventId == null) return null;

      final sseUri = Uri.parse('$spaceBase/gradio_api/call/inference/$eventId');
      final client = http.Client();
      final sseReq = http.Request('GET', sseUri);
      final sseResp = await client.send(sseReq).timeout(const Duration(seconds: 35));

      String? vocalsUrl;
      String? instrumentalUrl;

      await for (final line in sseResp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data:')) {
          final dataStr = line.replaceFirst('data:', '').trim();
          try {
            final parsedData = jsonDecode(dataStr);
            if (parsedData is List && parsedData.length >= 2) {
              final vObj = parsedData[0];
              final iObj = parsedData[1];
              vocalsUrl = vObj['url'] as String? ?? '$spaceBase/gradio_api/file=${vObj['path']}';
              instrumentalUrl = iObj['url'] as String? ?? '$spaceBase/gradio_api/file=${iObj['path']}';
              break;
            }
          } catch (_) {}
        }
      }

      final targetUrl = type == StemType.vocals ? vocalsUrl : instrumentalUrl;
      if (targetUrl == null) return null;

      final targetFile = File('${stemsDir.path}/${cleanId}_${type.name}.wav');
      final resp = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200 && resp.bodyBytes.length > 10000) {
        await targetFile.writeAsBytes(resp.bodyBytes);

        // Also save complementary stem in background
        final otherType = type == StemType.vocals ? StemType.instrumental : StemType.vocals;
        final otherUrl = type == StemType.vocals ? instrumentalUrl : vocalsUrl;
        if (otherUrl != null) {
          final otherFile = File('${stemsDir.path}/${cleanId}_${otherType.name}.wav');
          http.get(Uri.parse(otherUrl)).then((r) {
            if (r.statusCode == 200 && r.bodyBytes.length > 10000) {
              otherFile.writeAsBytes(r.bodyBytes);
            }
          }).catchError((_) {});
        }

        return StemResult.aiSeparated(type: type, localFilePath: targetFile.path);
      }
    } catch (e) {
      LogService.w('StemService', 'Demucs separation attempt failed: $e');
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
