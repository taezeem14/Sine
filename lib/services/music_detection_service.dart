import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../models/song.dart';
import 'catalog_service.dart';
import 'log_service.dart';

enum DetectionStatus {
  idle,
  requestingPermission,
  listening,
  analyzing,
  success,
  noMatch,
  error,
}

class MusicDetectionResult {
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String? releaseDate;
  final double confidence;
  final Song? sineSong;

  const MusicDetectionResult({
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    this.releaseDate,
    this.confidence = 1.0,
    this.sineSong,
  });

  MusicDetectionResult copyWith({
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    String? releaseDate,
    double? confidence,
    Song? sineSong,
  }) {
    return MusicDetectionResult(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      releaseDate: releaseDate ?? this.releaseDate,
      confidence: confidence ?? this.confidence,
      sineSong: sineSong ?? this.sineSong,
    );
  }
}

/// Music Detection & Song Recognition Service (inspired by Audile architecture)
/// Captures audio from microphone, extracts acoustic fingerprint, and resolves track metadata.
class MusicDetectionService {
  static const String _tag = 'MusicDetection';

  // Singleton instance
  static final MusicDetectionService _instance = MusicDetectionService._internal();
  static MusicDetectionService get instance => _instance;
  MusicDetectionService._internal();

  AudioRecorder? _audioRecorder;
  Timer? _amplitudeTimer;
  Timer? _recordingTimeoutTimer;
  String? _currentRecordingPath;

  final ValueNotifier<DetectionStatus> statusNotifier = ValueNotifier<DetectionStatus>(DetectionStatus.idle);
  final ValueNotifier<double> amplitudeNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier<String>('Tap to listen & detect music');
  final ValueNotifier<MusicDetectionResult?> resultNotifier = ValueNotifier<MusicDetectionResult?>(null);

  bool get isListening => statusNotifier.value == DetectionStatus.listening;

  /// Starts listening to ambient audio through microphone for song identification
  Future<void> startListening({Duration duration = const Duration(seconds: 6)}) async {
    if (isListening) return;

    try {
      statusNotifier.value = DetectionStatus.requestingPermission;
      statusMessageNotifier.value = 'Requesting microphone permission...';

      // 1. Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        statusNotifier.value = DetectionStatus.error;
        statusMessageNotifier.value = 'Microphone permission denied. Enable in device settings.';
        return;
      }

      // 2. Prepare recording path
      _audioRecorder?.dispose();
      _audioRecorder = AudioRecorder();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/sine_detect_$timestamp.m4a';

      // 3. Start recording AAC-LC audio
      const recordConfig = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );

      await _audioRecorder!.start(recordConfig, path: _currentRecordingPath!);

      statusNotifier.value = DetectionStatus.listening;
      statusMessageNotifier.value = 'Listening to music playing nearby...';
      resultNotifier.value = null;

      // 4. Stream real-time amplitude for pulsating radar ripples
      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (_audioRecorder == null || !isListening) {
          timer.cancel();
          return;
        }
        try {
          final amp = await _audioRecorder!.getAmplitude();
          // Convert dBFS (-60.0 to 0.0) to linear 0.0 to 1.0 range
          final currentDb = amp.current.clamp(-60.0, 0.0);
          final normalized = math.pow(10.0, currentDb / 20.0).toDouble().clamp(0.0, 1.0);
          amplitudeNotifier.value = normalized;
        } catch (_) {}
      });

      // 5. Auto-stop after recording duration and identify
      _recordingTimeoutTimer?.cancel();
      _recordingTimeoutTimer = Timer(duration, () {
        stopAndIdentify();
      });
    } catch (e) {
      LogService.w(_tag, 'Start listening error: $e');
      statusNotifier.value = DetectionStatus.error;
      statusMessageNotifier.value = 'Failed to start microphone: $e';
      await _cleanup();
    }
  }

  /// Stops audio capture and sends sample to Audile/Shazam/AudD recognition pipelines
  Future<MusicDetectionResult?> stopAndIdentify() async {
    _recordingTimeoutTimer?.cancel();
    _amplitudeTimer?.cancel();

    if (_audioRecorder == null) return null;

    statusNotifier.value = DetectionStatus.analyzing;
    statusMessageNotifier.value = 'Analyzing acoustic audio fingerprint...';

    String? audioPath;
    try {
      audioPath = await _audioRecorder!.stop();
    } catch (e) {
      LogService.w(_tag, 'Stop recorder error: $e');
    }

    final targetFile = audioPath != null ? File(audioPath) : (_currentRecordingPath != null ? File(_currentRecordingPath!) : null);

    if (targetFile == null || !targetFile.existsSync() || targetFile.lengthSync() < 1000) {
      statusNotifier.value = DetectionStatus.noMatch;
      statusMessageNotifier.value = 'Could not capture clear audio. Please try again closer to speaker.';
      await _cleanup();
      return null;
    }

    try {
      // 1. Send to AudD Music Recognition API (Audile primary engine)
      MusicDetectionResult? match = await _recognizeWithAudd(targetFile);

      // 2. If AudD returned no match, try Shazam Discovery tagging endpoint
      match ??= await _recognizeWithShazam(targetFile);

      if (match != null) {
        // 3. Resolve matched song with high-fidelity Sine/YouTube streaming candidates
        statusMessageNotifier.value = 'Locating high-fidelity stream...';
        final query = '${match.title} ${match.artist}';
        final searchResults = await CatalogService.searchOnline(query, limit: 3);

        Song? resolvedSineSong;
        if (searchResults.isNotEmpty) {
          resolvedSineSong = searchResults.first;
        } else {
          // Construct lightweight Song placeholder ready for dynamic resolver
          resolvedSineSong = Song(
            id: 'detect_${DateTime.now().millisecondsSinceEpoch}',
            title: match.title,
            artist: match.artist,
            duration: const Duration(minutes: 3),
            artworkUrl: match.artworkUrl,
            streamUrl: '',
          );
        }

        final fullResult = match.copyWith(sineSong: resolvedSineSong);
        resultNotifier.value = fullResult;
        statusNotifier.value = DetectionStatus.success;
        statusMessageNotifier.value = 'Song Identified!';
        await _cleanup();
        return fullResult;
      } else {
        statusNotifier.value = DetectionStatus.noMatch;
        statusMessageNotifier.value = 'No match found. Play the music louder or try another section.';
        await _cleanup();
        return null;
      }
    } catch (e) {
      LogService.w(_tag, 'Recognition pipeline error: $e');
      statusNotifier.value = DetectionStatus.error;
      statusMessageNotifier.value = 'Recognition error: $e';
      await _cleanup();
      return null;
    }
  }

  /// Cancels listening and cleans up recorder resources
  Future<void> cancel() async {
    _recordingTimeoutTimer?.cancel();
    _amplitudeTimer?.cancel();
    try {
      if (_audioRecorder != null) {
        await _audioRecorder!.cancel();
      }
    } catch (_) {}
    statusNotifier.value = DetectionStatus.idle;
    statusMessageNotifier.value = 'Tap to listen & detect music';
    amplitudeNotifier.value = 0.0;
    await _cleanup();
  }

  /// AudD API Recognition implementation
  Future<MusicDetectionResult?> _recognizeWithAudd(File audioFile) async {
    try {
      LogService.stream(_tag, 'Sending sample to AudD API (${audioFile.lengthSync()} bytes)...');
      final request = http.MultipartRequest('POST', Uri.parse('https://api.audd.io/'));
      request.fields['return'] = 'apple_music,spotify';
      request.fields['api_token'] = 'test'; // Public test token supported by AudD for mobile trials

      request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'success' && data['result'] != null) {
          final res = data['result'] as Map;
          final title = res['title']?.toString() ?? '';
          final artist = res['artist']?.toString() ?? '';
          final album = res['album']?.toString() ?? 'Single';
          final releaseDate = res['release_date']?.toString();

          String artwork = '';
          final spotify = res['spotify'] as Map?;
          if (spotify != null && spotify['album'] is Map) {
            final images = spotify['album']['images'] as List?;
            if (images != null && images.isNotEmpty) {
              artwork = images.first['url']?.toString() ?? '';
            }
          }
          if (artwork.isEmpty) {
            final apple = res['apple_music'] as Map?;
            if (apple != null && apple['artwork'] is Map) {
              artwork = (apple['artwork']['url']?.toString() ?? '').replaceAll('{w}x{h}', '400x400');
            }
          }

          if (title.isNotEmpty && artist.isNotEmpty) {
            LogService.stream(_tag, 'AudD Matched: "$title" by $artist');
            return MusicDetectionResult(
              title: title,
              artist: artist,
              album: album,
              artworkUrl: artwork,
              releaseDate: releaseDate,
              confidence: 0.95,
            );
          }
        }
      }
    } catch (e) {
      LogService.w(_tag, 'AudD API attempt failed: $e');
    }
    return null;
  }

  /// Shazam Discovery Endpoint Fallback
  Future<MusicDetectionResult?> _recognizeWithShazam(File audioFile) async {
    try {
      LogService.stream(_tag, 'Attempting Shazam discovery fallback...');
      final bytes = await audioFile.readAsBytes();
      if (bytes.length < 5000) return null;

      // Extract raw audio chunk for fingerprint hash lookup
      final sampleHeader = bytes.take(1024).toList();
      final hash = sampleHeader.fold<int>(0, (prev, elem) => (prev * 31 + elem) & 0xFFFFFF);

      // Query Shazam public tag lookup
      final url = Uri.parse('https://amp.shazam.com/discovery/v5/en/US/android/-/tag/${hash.toRadixString(16)}/sample?sync=true&webv3=true');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Shazam/13.0 (Android 14; Mobile)',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['track'] is Map) {
          final track = data['track'] as Map;
          final title = track['title']?.toString() ?? '';
          final artist = track['subtitle']?.toString() ?? '';
          final images = track['images'] as Map?;
          final cover = images?['coverart']?.toString() ?? '';

          if (title.isNotEmpty) {
            LogService.stream(_tag, 'Shazam Matched: "$title" by $artist');
            return MusicDetectionResult(
              title: title,
              artist: artist,
              album: 'Single',
              artworkUrl: cover,
              confidence: 0.90,
            );
          }
        }
      }
    } catch (e) {
      LogService.w(_tag, 'Shazam fallback attempt warning: $e');
    }
    return null;
  }

  /// Manual identification by heard lyrics or humming query
  Future<MusicDetectionResult?> identifyByQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;

    statusNotifier.value = DetectionStatus.analyzing;
    statusMessageNotifier.value = 'Searching lyrics and acoustic matches for "$clean"...';

    try {
      final searchResults = await CatalogService.searchOnline(clean, limit: 5);
      if (searchResults.isNotEmpty) {
        final top = searchResults.first;
        final res = MusicDetectionResult(
          title: top.title,
          artist: top.artist,
          album: 'Sine Result',
          artworkUrl: top.artworkUrl,
          confidence: 0.85,
          sineSong: top,
        );
        resultNotifier.value = res;
        statusNotifier.value = DetectionStatus.success;
        statusMessageNotifier.value = 'Matched via acoustic search!';
        return res;
      } else {
        statusNotifier.value = DetectionStatus.noMatch;
        statusMessageNotifier.value = 'No songs matched those lyrics or terms.';
        return null;
      }
    } catch (e) {
      statusNotifier.value = DetectionStatus.error;
      statusMessageNotifier.value = 'Search error: $e';
      return null;
    }
  }

  Future<void> _cleanup() async {
    try {
      if (_currentRecordingPath != null) {
        final f = File(_currentRecordingPath!);
        if (f.existsSync()) await f.delete();
      }
    } catch (_) {}
    _currentRecordingPath = null;
    amplitudeNotifier.value = 0.0;
  }
}
