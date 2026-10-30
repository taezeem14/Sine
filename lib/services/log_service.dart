import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

enum LogLevel { debug, info, warning, error, stream, exoplayer }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get levelLabel {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.stream:
        return 'STREAM';
      case LogLevel.exoplayer:
        return 'EXOPLAYER';
    }
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() {
    final err = error != null ? ' | Error: $error' : '';
    return '[$formattedTime] [$levelLabel] [$tag] $message$err';
  }
}

/// Centralized In-App Diagnostics and Log Extractor Service (NewPipe Architecture)
class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  static LogService get instance => _instance;

  LogService._internal() {
    _initDeviceSpecs();
  }

  static const int _maxBufferSize = 350;
  final List<LogEntry> _logs = [];

  // Active playback state telemetry
  String _activeSongTitle = 'None';
  String _activeSongArtist = 'None';
  String _activeSongId = '';
  String _activeStreamUrl = '';
  List<String> _lastCandidates = [];
  String _exoplayerState = 'Idle';
  String? _lastError;
  String? _lastStackTrace;
  int _consecutiveFailures = 0;
  String _osInfo = 'Unknown OS';

  List<LogEntry> get logs => List.unmodifiable(_logs);
  String get activeSongTitle => _activeSongTitle;
  String get activeSongArtist => _activeSongArtist;
  String get activeSongId => _activeSongId;
  String get activeStreamUrl => _activeStreamUrl;
  List<String> get lastCandidates => List.unmodifiable(_lastCandidates);
  String get exoplayerState => _exoplayerState;
  String? get lastError => _lastError;
  String? get lastStackTrace => _lastStackTrace;
  int get consecutiveFailures => _consecutiveFailures;
  String get osInfo => _osInfo;

  void _initDeviceSpecs() {
    try {
      _osInfo = '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
    } catch (_) {
      _osInfo = 'Unknown Platform';
    }
  }

  // --- LOGGING METHODS ---

  static void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    _instance._addEntry(entry);

    // Also output to console in debug mode
    if (kDebugMode) {
      debugPrint(entry.toString());
      if (error != null) debugPrint('Exception detail: $error');
      if (stackTrace != null) debugPrint('Stack: $stackTrace');
    }
  }

  static void d(String tag, String message) => log(LogLevel.debug, tag, message);
  static void i(String tag, String message) => log(LogLevel.info, tag, message);
  static void w(String tag, String message) => log(LogLevel.warning, tag, message);
  static void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      log(LogLevel.error, tag, message, error: error, stackTrace: stack);
  static void stream(String tag, String message) => log(LogLevel.stream, tag, message);
  static void exoplayer(String tag, String message) => log(LogLevel.exoplayer, tag, message);

  bool _pendingNotify = false;
  void _addEntry(LogEntry entry) {
    if (_logs.length >= _maxBufferSize) {
      _logs.removeAt(0);
    }
    _logs.add(entry);
    if (!_pendingNotify) {
      _pendingNotify = true;
      Future.microtask(() {
        _pendingNotify = false;
        notifyListeners();
      });
    }
  }

  // --- PLAYBACK TELEMETRY RECORDERS ---

  void recordActiveTrack(Song song) {
    _activeSongTitle = song.title;
    _activeSongArtist = song.artist;
    _activeSongId = song.id;
    _activeStreamUrl = song.streamUrl;
    stream('PlaybackEngine', 'Target song changed to "${song.title}" (${song.id})');
    notifyListeners();
  }

  void recordCandidates(List<String> candidates) {
    _lastCandidates = List.from(candidates);
    stream('Resolver', 'Resolved ${candidates.length} playable stream candidate(s)');
    notifyListeners();
  }

  void recordExoState(String state) {
    _exoplayerState = state;
    exoplayer('ExoPlayer', 'State transition: $state');
    notifyListeners();
  }

  void recordPlaybackFailure(Song song, Object error, [StackTrace? stack]) {
    _consecutiveFailures++;
    _lastError = error.toString();
    _lastStackTrace = stack?.toString();
    e('PlaybackFailure', 'Failed playing "${song.title}" (${song.id}): $error', error, stack);
    notifyListeners();
  }

  void recordPlaybackSuccess(Song song) {
    _consecutiveFailures = 0;
    _lastError = null;
    _lastStackTrace = null;
    i('PlaybackSuccess', 'Successfully streaming "${song.title}"');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    _lastError = null;
    _lastStackTrace = null;
    notifyListeners();
  }

  // --- REPORT EXPORTERS ---

  /// Generate a structured GitHub/NewPipe-style Markdown Diagnostic Report
  String generateMarkdownReport() {
    final buffer = StringBuffer();
    final now = DateTime.now().toUtc().toIso8601String();

    buffer.writeln('## Sine Diagnostics & Error Report');
    buffer.writeln('* __App:__ Sine v1.0.9 (Build 11)');
    buffer.writeln('* __OS:__ $_osInfo');
    buffer.writeln('* __Engine:__ just_audio 0.9.44 / Android ExoPlayer (DSP Hardware Decoder)');
    buffer.writeln('* __Timestamp:__ `$now`');
    buffer.writeln('* __Consecutive Failures:__ $_consecutiveFailures');
    buffer.writeln();

    buffer.writeln('### Active Track State');
    buffer.writeln('* __Title:__ $_activeSongTitle');
    buffer.writeln('* __Artist:__ $_activeSongArtist');
    buffer.writeln('* __Song ID:__ `$_activeSongId`');
    buffer.writeln('* __ExoPlayer State:__ `$_exoplayerState`');
    if (_activeStreamUrl.isNotEmpty) {
      final safeUrl = _sanitizeUrl(_activeStreamUrl);
      buffer.writeln('* __Source Stream:__ `$safeUrl`');
    }
    buffer.writeln();

    buffer.writeln('### Resolved Stream Candidates (${_lastCandidates.length})');
    if (_lastCandidates.isEmpty) {
      buffer.writeln('* No candidates were resolved.');
    } else {
      for (int i = 0; i < _lastCandidates.length; i++) {
        final c = _sanitizeUrl(_lastCandidates[i]);
        buffer.writeln('${i + 1}. `$c`');
      }
    }
    buffer.writeln();

    if (_lastError != null) {
      buffer.writeln('### Last Playback Error');
      buffer.writeln('```');
      buffer.writeln(_lastError);
      if (_lastStackTrace != null && _lastStackTrace!.isNotEmpty) {
        buffer.writeln('\n--- Stack Trace ---');
        buffer.writeln(_lastStackTrace);
      }
      buffer.writeln('```');
      buffer.writeln();
    }

    buffer.writeln('<details><summary><b>Live Logcat & Extractor Trace (Last ${_logs.length} entries)</b></summary><p>');
    buffer.writeln();
    buffer.writeln('```log');
    for (final entry in _logs) {
      buffer.writeln(entry.toString());
    }
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('</p></details>');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*Report generated by Sine In-App Diagnostic Extractor*');

    return buffer.toString();
  }

  /// Copies full Markdown report to system clipboard
  Future<void> copyReportToClipboard() async {
    final report = generateMarkdownReport();
    try {
      await Clipboard.setData(ClipboardData(text: report));
      i('LogExtractor', 'Diagnostic Markdown report copied to clipboard');
    } catch (e) {
      w('LogExtractor', 'Failed to copy report to clipboard: $e');
      rethrow;
    }
  }

  /// Exports diagnostic report as structured JSON
  String exportJson() {
    final map = {
      'app': 'Sine',
      'version': '1.0.9+11',
      'os': _osInfo,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'consecutive_failures': _consecutiveFailures,
      'active_track': {
        'title': _activeSongTitle,
        'artist': _activeSongArtist,
        'id': _activeSongId,
        'stream_url': _sanitizeUrl(_activeStreamUrl),
      },
      'exoplayer_state': _exoplayerState,
      'last_error': _lastError,
      'last_stack_trace': _lastStackTrace,
      'candidates': _lastCandidates.map(_sanitizeUrl).toList(),
      'logs': _logs.map((l) => {
        'time': l.formattedTime,
        'level': l.levelLabel,
        'tag': l.tag,
        'message': l.message,
        'error': l.error,
      }).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  String _sanitizeUrl(String url) {
    if (url.length <= 120) return url;
    try {
      final uri = Uri.parse(url);
      final queryParams = uri.queryParameters;
      final itag = queryParams['itag'] ?? '';
      final expire = queryParams['expire'] ?? '';
      final mime = queryParams['mime'] ?? '';
      return '${uri.scheme}://${uri.host}${uri.path}?[itag=$itag, expire=$expire, mime=$mime]';
    } catch (_) {
      return '${url.substring(0, 100)}...';
    }
  }

  // --- REAL-TIME LIVE STREAM EXTRACTION TESTER ---

  /// Executes an end-to-end sandbox extraction test for any video ID or search query
  Future<StreamTestResult> runExtractionTest(String query) async {
    final sw = Stopwatch()..start();
    final steps = <String>[];
    String? cleanId;

    steps.add('Target Query: "$query"');

    // 1. Resolve ID
    if (query.startsWith('yt_')) {
      cleanId = query.replaceFirst('yt_', '');
    } else if (query.contains('watch?v=') || query.contains('youtu.be/')) {
      final reg = RegExp(r'(?:v=|\/)([0-9A-Za-z_-]{11})');
      cleanId = reg.firstMatch(query)?.group(1);
    } else if (query.length == 11 && !query.contains(' ')) {
      cleanId = query;
    }

    final yt = YoutubeExplode();
    try {
      if (cleanId == null) {
        steps.add('Searching YouTube for "$query"...');
        final searchResults = await yt.search.search(query);
        if (searchResults.isEmpty) {
          steps.add('FAIL: No search results found on YouTube.');
          return StreamTestResult(
            success: false,
            durationMs: sw.elapsedMilliseconds,
            steps: steps,
          );
        }
        cleanId = searchResults.first.id.value;
        steps.add('Found video: "${searchResults.first.title}" (ID: $cleanId)');
      } else {
        steps.add('Extracted Video ID: $cleanId');
      }

      steps.add('Querying YouTube InnerTube stream manifest (requireWatchPage: false)...');
      final manifestStart = sw.elapsedMilliseconds;
      final manifest = await yt.videos.streamsClient.getManifest(
        cleanId,
        requireWatchPage: false,
      ).timeout(const Duration(seconds: 8));
      final manifestDuration = sw.elapsedMilliseconds - manifestStart;
      steps.add('InnerTube manifest resolved in ${manifestDuration}ms.');

      final audioStreams = manifest.audioOnly.toList();
      steps.add('Total Audio Streams Found: ${audioStreams.length}');

      for (final a in audioStreams) {
        steps.add(
          '-> Container: ${a.container.name.toUpperCase()} | itag: ${a.tag} | Bitrate: ${a.bitrate.kiloBitsPerSecond.toStringAsFixed(1)} kbps | Size: ${(a.size.totalMegaBytes).toStringAsFixed(2)} MB',
        );
      }

      // Test candidate reachability with HTTP HEAD
      if (audioStreams.isNotEmpty) {
        final bestStream = audioStreams.withHighestBitrate();
        steps.add('Probing best stream (${bestStream.container.name}, itag ${bestStream.tag})...');
        final probeStart = sw.elapsedMilliseconds;
        try {
          final headResp = await http.head(
            bestStream.url,
            headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
          ).timeout(const Duration(seconds: 6));
          final probeDuration = sw.elapsedMilliseconds - probeStart;
          steps.add('HTTP HEAD Status: ${headResp.statusCode} (${headResp.reasonPhrase}) in ${probeDuration}ms');
          if (headResp.statusCode == 200 || headResp.statusCode == 206) {
            steps.add('SUCCESS: Stream candidate is directly playable!');
          } else {
            steps.add('WARNING: Stream candidate returned HTTP ${headResp.statusCode}');
          }
        } catch (probeError) {
          steps.add('HTTP Probe warning: $probeError (ExoPlayer may still stream via GET)');
        }
      }

      return StreamTestResult(
        success: audioStreams.isNotEmpty,
        durationMs: sw.elapsedMilliseconds,
        steps: steps,
      );
    } catch (e) {
      steps.add('ERROR: Extraction failed: $e');
      return StreamTestResult(
        success: false,
        durationMs: sw.elapsedMilliseconds,
        steps: steps,
        error: e.toString(),
      );
    } finally {
      yt.close();
    }
  }
}

class StreamTestResult {
  final bool success;
  final int durationMs;
  final List<String> steps;
  final String? error;

  StreamTestResult({
    required this.success,
    required this.durationMs,
    required this.steps,
    this.error,
  });
}
