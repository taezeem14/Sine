import 'dart:async';

import 'dart:convert';

import 'dart:io';

import 'dart:math' as math;

import 'dart:typed_data';

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

// ---------------------------------------------------------------------------

// CRC32 CHECKSUM IMPLEMENTATION

// ---------------------------------------------------------------------------

class ShazamCrc32 {

  static final List<int> _table = _generateTable();

  static List<int> _generateTable() {

    final table = List<int>.filled(256, 0);

    for (int i = 0; i < 256; i++) {

      int c = i;

      for (int k = 0; k < 8; k++) {

        if ((c & 1) != 0) {

          c = 0xedb88320 ^ (c >>> 1);

        } else {

          c = c >>> 1;

        }

      }

      table[i] = c;

    }

    return table;

  }

  static int compute(Uint8List bytes, int offset, int length) {

    int crc = 0xffffffff;

    final end = offset + length;

    for (int i = offset; i < end; i++) {

      crc = _table[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);

    }

    return crc ^ 0xffffffff;

  }

}

// ---------------------------------------------------------------------------

// AUDIO RESAMPLER (LINEAR INTERPOLATION 44.1kHz -> 16kHz MONO PCM)

// ---------------------------------------------------------------------------

class AudioResampler {

  static Uint8List resamplePcm16(Uint8List inputData, int inputRate, int outputRate) {

    if (inputRate == outputRate) return inputData;

    if (inputData.length < 2) return inputData;

    final inputLength = inputData.length ~/ 2;

    final byteData = ByteData.sublistView(inputData);

    final inputSamples = Int16List(inputLength);

    for (int i = 0; i < inputLength; i++) {

      inputSamples[i] = byteData.getInt16(i * 2, Endian.little);

    }

    final ratio = outputRate / inputRate;

    final outputLength = (inputSamples.length * ratio).toInt();

    if (outputLength <= 0) return Uint8List(0);

    final outputSamples = Int16List(outputLength);

    for (int i = 0; i < outputLength; i++) {

      final srcPos = i / ratio;

      final srcIndex = srcPos.toInt();

      final fraction = srcPos - srcIndex;

      int sample;

      if (srcIndex + 1 < inputSamples.length) {

        sample = (inputSamples[srcIndex] * (1.0 - fraction) + inputSamples[srcIndex + 1] * fraction).toInt();

      } else if (srcIndex < inputSamples.length) {

        sample = inputSamples[srcIndex];

      } else {

        sample = 0;

      }

      outputSamples[i] = sample.clamp(-32768, 32767);

    }

    final outputBytes = Uint8List(outputLength * 2);

    final outByteData = ByteData.sublistView(outputBytes);

    for (int i = 0; i < outputLength; i++) {

      outByteData.setInt16(i * 2, outputSamples[i], Endian.little);

    }

    return outputBytes;

  }

}

// ---------------------------------------------------------------------------

// SHAZAM PURE-DART SIGNATURE GENERATOR (SONGREC / AUDILE COMPLIANT)

// ---------------------------------------------------------------------------

class _FrequencyPeak {

  final int fftPassNumber;

  final int peakMagnitude;

  final int correctedPeakFrequencyBin;

  _FrequencyPeak({

    required this.fftPassNumber,

    required this.peakMagnitude,

    required this.correctedPeakFrequencyBin,

  });

}

class ShazamSignatureGenerator {

  static const int sampleRate = 16000;

  static const int fftSize = 2048;

  static const int fftOutputSize = fftSize ~/ 2 + 1; // 1025

  static const int maxPeaks = 255;

  static const double maxTimeSeconds = 12.0;

  static const int ringBufSize = 256;

  static const int band250To520 = 0;

  static const int band520To1450 = 1;

  static const int band1450To3500 = 2;

  static const int band3500To5500 = 3;

  static final Float64List hanning = Float64List.fromList(

    List.generate(fftSize, (i) => 0.5 * (1.0 - math.cos(2.0 * math.pi * (i + 1) / 2049.0))),

  );

  static String fromPcm16Mono16kHz(Uint8List samples) {

    if (samples.length < 2 || samples.length % 2 != 0) {

      throw ArgumentError("Samples must be a non-empty byte array with even length (16-bit PCM)");

    }

    final byteData = ByteData.sublistView(samples);

    final pcm = Int16List(samples.length ~/ 2);

    for (int i = 0; i < pcm.length; i++) {

      pcm[i] = byteData.getInt16(i * 2, Endian.little);

    }

    return _SignatureState().process(pcm);

  }

}

class _SignatureState {

  final Int32List samplesRing = Int32List(ShazamSignatureGenerator.fftSize);

  int samplesPos = 0;

  final List<Float64List> fftOutputs = List.generate(

    ShazamSignatureGenerator.ringBufSize,

    (_) => Float64List(ShazamSignatureGenerator.fftOutputSize),

  );

  int fftPos = 0;

  int fftNumWritten = 0;

  final List<Float64List> spreadFfts = List.generate(

    ShazamSignatureGenerator.ringBufSize,

    (_) => Float64List(ShazamSignatureGenerator.fftOutputSize),

  );

  int spreadPos = 0;

  int spreadNumWritten = 0;

  int numSamples = 0;

  final List<List<_FrequencyPeak>> bandPeaks = List.generate(4, (_) => []);

  int totalPeaks = 0;

  String process(Int16List pcm) {

    int offset = 0;

    while (offset + 128 <= pcm.length) {

      final elapsedSec = numSamples / ShazamSignatureGenerator.sampleRate;

      if (elapsedSec >= ShazamSignatureGenerator.maxTimeSeconds &&

          totalPeaks >= ShazamSignatureGenerator.maxPeaks) {

        break;

      }

      numSamples += 128;

      feedSamples(pcm, offset, 128);

      doFFT();

      doPeakSpreadingAndRecognition();

      offset += 128;

    }

    return encodeSignature();

  }

  void feedSamples(Int16List pcm, int start, int count) {

    for (int k = start; k < start + count; k++) {

      samplesRing[samplesPos] = pcm[k];

      samplesPos = (samplesPos + 1) % ShazamSignatureGenerator.fftSize;

    }

  }

  void doFFT() {

    final windowed = Float64List(ShazamSignatureGenerator.fftSize);

    for (int i = 0; i < ShazamSignatureGenerator.fftSize; i++) {

      final ringIdx = (samplesPos + i) % ShazamSignatureGenerator.fftSize;

      windowed[i] = samplesRing[ringIdx].toDouble() * ShazamSignatureGenerator.hanning[i];

    }

    final result = computeRfft(windowed);

    fftOutputs[fftPos].setAll(0, result);

    fftPos = (fftPos + 1) % ShazamSignatureGenerator.ringBufSize;

    fftNumWritten++;

  }

  void doPeakSpreadingAndRecognition() {

    doPeakSpreading();

    if (spreadNumWritten >= 47) {

      doPeakRecognition();

    }

  }

  void doPeakSpreading() {

    final lastFftIdx = (fftPos - 1 + ShazamSignatureGenerator.ringBufSize) % ShazamSignatureGenerator.ringBufSize;

    final spread = Float64List.fromList(fftOutputs[lastFftIdx]);

    for (int pos = 0; pos < ShazamSignatureGenerator.fftOutputSize - 2; pos++) {

      spread[pos] = math.max(spread[pos], math.max(spread[pos + 1], spread[pos + 2]));

    }

    for (int pos = 0; pos < ShazamSignatureGenerator.fftOutputSize; pos++) {

      double maxVal = spread[pos];

      for (final offset in const [-1, -3, -6]) {

        final idx = ((spreadPos + offset) % ShazamSignatureGenerator.ringBufSize + ShazamSignatureGenerator.ringBufSize) % ShazamSignatureGenerator.ringBufSize;

        final oldVal = spreadFfts[idx][pos];

        if (oldVal > maxVal) maxVal = oldVal;

        spreadFfts[idx][pos] = maxVal;

      }

    }

    spreadFfts[spreadPos].setAll(0, spread);

    spreadPos = (spreadPos + 1) % ShazamSignatureGenerator.ringBufSize;

    spreadNumWritten++;

  }

  void doPeakRecognition() {

    final fftMinus46 = fftOutputs[(fftPos - 46 + ShazamSignatureGenerator.ringBufSize * 2) % ShazamSignatureGenerator.ringBufSize];

    final spreadMinus49 = spreadFfts[(spreadPos - 49 + ShazamSignatureGenerator.ringBufSize * 2) % ShazamSignatureGenerator.ringBufSize];

    const otherOffsets = [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249];

    const neighbors = [-10, -7, -4, -3, 1, 2, 5, 8];

    for (int binPos = 10; binPos < ShazamSignatureGenerator.fftOutputSize - 8; binPos++) {

      final fftVal = fftMinus46[binPos];

      if (fftVal < 1.0 / 64.0 || fftVal < spreadMinus49[binPos]) continue;

      double maxNeighborSpread49 = 0.0;

      for (final neighborOffset in neighbors) {

        final v = spreadMinus49[binPos + neighborOffset];

        if (v > maxNeighborSpread49) maxNeighborSpread49 = v;

      }

      if (fftVal <= maxNeighborSpread49) continue;

      double maxNeighborOther = maxNeighborSpread49;

      for (final otherOffset in otherOffsets) {

        final spreadIdx = ((spreadPos + otherOffset) % ShazamSignatureGenerator.ringBufSize + ShazamSignatureGenerator.ringBufSize) % ShazamSignatureGenerator.ringBufSize;

        final v = spreadFfts[spreadIdx][binPos - 1];

        if (v > maxNeighborOther) maxNeighborOther = v;

      }

      if (fftVal <= maxNeighborOther) continue;

      final fftNumber = spreadNumWritten - 46;

      final peakMag = math.log(math.max(1.0 / 64.0, fftVal)) * 1477.3 + 6144;

      final peakMagBefore = math.log(math.max(1.0 / 64.0, fftMinus46[binPos - 1])) * 1477.3 + 6144;

      final peakMagAfter = math.log(math.max(1.0 / 64.0, fftMinus46[binPos + 1])) * 1477.3 + 6144;

      final peakVariation1 = peakMag * 2 - peakMagBefore - peakMagAfter;

      final peakVariation2 = (peakMagAfter - peakMagBefore) * 32 / peakVariation1;

      final correctedBin = binPos * 64.0 + peakVariation2;

      final frequencyHz = correctedBin * (16000.0 / 2.0 / 1024.0 / 64.0);

      int band;

      if (frequencyHz < 250.0) {

        continue;

      } else if (frequencyHz < 520.0) {

        band = ShazamSignatureGenerator.band250To520;

      } else if (frequencyHz < 1450.0) {

        band = ShazamSignatureGenerator.band520To1450;

      } else if (frequencyHz < 3500.0) {

        band = ShazamSignatureGenerator.band1450To3500;

      } else if (frequencyHz <= 5500.0) {

        band = ShazamSignatureGenerator.band3500To5500;

      } else {

        continue;

      }

      bandPeaks[band].add(

        _FrequencyPeak(

          fftPassNumber: fftNumber,

          peakMagnitude: peakMag.toInt(),

          correctedPeakFrequencyBin: correctedBin.toInt(),

        ),

      );

      totalPeaks++;

    }

  }

  String encodeSignature() {

    final contentsBuilder = BytesBuilder();

    for (int bandId = 0; bandId < 4; bandId++) {

      final peaks = bandPeaks[bandId];

      if (peaks.isEmpty) continue;

      final peakBuilder = BytesBuilder();

      int prevFftPassNumber = 0;

      for (final peak in peaks) {

        final diff = peak.fftPassNumber - prevFftPassNumber;

        if (diff >= 255) {

          peakBuilder.addByte(0xFF);

          _writeLittleEndian32(peakBuilder, peak.fftPassNumber);

          prevFftPassNumber = peak.fftPassNumber;

        }

        peakBuilder.addByte(peak.fftPassNumber - prevFftPassNumber);

        _writeLittleEndian16(peakBuilder, peak.peakMagnitude);

        _writeLittleEndian16(peakBuilder, peak.correctedPeakFrequencyBin);

        prevFftPassNumber = peak.fftPassNumber;

      }

      final peakBytes = peakBuilder.toBytes();

      _writeLittleEndian32(contentsBuilder, 0x60030040 + bandId);

      _writeLittleEndian32(contentsBuilder, peakBytes.length);

      contentsBuilder.add(peakBytes);

      final padBytes = (4 - peakBytes.length % 4) % 4;

      for (int i = 0; i < padBytes; i++) {

        contentsBuilder.addByte(0);

      }

    }

    final contents = contentsBuilder.toBytes();

    final sizeMinusHeader = contents.length + 8;

    final samplesAndOffset = (numSamples + ShazamSignatureGenerator.sampleRate * 0.24).toInt();

    final headerData = ByteData(48);

    headerData.setInt32(0, 0xcafe2580, Endian.little);

    headerData.setInt32(4, 0, Endian.little);

    headerData.setInt32(8, sizeMinusHeader, Endian.little);

    headerData.setInt32(12, 0x94119c00, Endian.little);

    headerData.setInt32(16, 0, Endian.little);

    headerData.setInt32(20, 0, Endian.little);

    headerData.setInt32(24, 0, Endian.little);

    headerData.setInt32(28, 3 << 27, Endian.little);

    headerData.setInt32(32, 0, Endian.little);

    headerData.setInt32(36, 0, Endian.little);

    headerData.setInt32(40, samplesAndOffset, Endian.little);

    headerData.setInt32(44, (15 << 19) + 0x40000, Endian.little);

    final fullBuilder = BytesBuilder();

    fullBuilder.add(headerData.buffer.asUint8List());

    _writeLittleEndian32(fullBuilder, 0x40000000);

    _writeLittleEndian32(fullBuilder, contents.length + 8);

    fullBuilder.add(contents);

    final fullBytes = fullBuilder.toBytes();

    final crcValue = ShazamCrc32.compute(fullBytes, 8, fullBytes.length - 8);

    final crcData = ByteData(4)..setInt32(0, crcValue, Endian.little);

    fullBytes[4] = crcData.getUint8(0);

    fullBytes[5] = crcData.getUint8(1);

    fullBytes[6] = crcData.getUint8(2);

    fullBytes[7] = crcData.getUint8(3);

    final base64 = base64Encode(fullBytes);

    return "data:audio/vnd.shazam.sig;base64,$base64";

  }

  void _writeLittleEndian32(BytesBuilder builder, int value) {

    builder.addByte(value & 0xFF);

    builder.addByte((value >> 8) & 0xFF);

    builder.addByte((value >> 16) & 0xFF);

    builder.addByte((value >> 24) & 0xFF);

  }

  void _writeLittleEndian16(BytesBuilder builder, int value) {

    builder.addByte(value & 0xFF);

    builder.addByte((value >> 8) & 0xFF);

  }

  Float64List computeRfft(Float64List windowed) {

    final n = windowed.length;

    final re = Float64List.fromList(windowed);

    final im = Float64List(n);

    int j = 0;

    for (int i = 1; i < n; i++) {

      int bit = n >> 1;

      while ((j & bit) != 0) {

        j ^= bit;

        bit >>= 1;

      }

      j ^= bit;

      if (i < j) {

        final tmpRe = re[i];

        re[i] = re[j];

        re[j] = tmpRe;

        final tmpIm = im[i];

        im[i] = im[j];

        im[j] = tmpIm;

      }

    }

    int len = 2;

    while (len <= n) {

      final halfLen = len >> 1;

      final ang = -math.pi / halfLen;

      final wBaseRe = math.cos(ang);

      final wBaseIm = math.sin(ang);

      int i = 0;

      while (i < n) {

        double wRe = 1.0;

        double wIm = 0.0;

        for (int k = 0; k < halfLen; k++) {

          final u = i + k;

          final v = u + halfLen;

          final evenRe = re[u];

          final evenIm = im[u];

          final oddRe = re[v] * wRe - im[v] * wIm;

          final oddIm = re[v] * wIm + im[v] * wRe;

          re[u] = evenRe + oddRe;

          im[u] = evenIm + oddIm;

          re[v] = evenRe - oddRe;

          im[v] = evenIm - oddIm;

          final newWRe = wRe * wBaseRe - wIm * wBaseIm;

          wIm = wRe * wBaseIm + wIm * wBaseRe;

          wRe = newWRe;

        }

        i += len;

      }

      len <<= 1;

    }

    const scaleFactor = 1.0 / (1 << 17);

    const minVal = 1e-10;

    final magnitudes = Float64List(ShazamSignatureGenerator.fftOutputSize);

    for (int idx = 0; idx < ShazamSignatureGenerator.fftOutputSize; idx++) {

      final r = re[idx];

      final img = im[idx];

      final mag = (r * r + img * img) * scaleFactor;

      magnitudes[idx] = mag < minVal ? minVal : mag;

    }

    return magnitudes;

  }

}

// ---------------------------------------------------------------------------

// SHAZAM HTTP CLIENT

// ---------------------------------------------------------------------------

class ShazamClient {
  static const String _baseUrl = "https://amp.shazam.com/discovery/v5/en/US/android/-/tag";

  static const List<String> _userAgents = [
    "Dalvik/2.1.0 (Linux; U; Android 6.0.1; SM-G920F Build/MMB29K)",
    "Dalvik/2.1.0 (Linux; U; Android 5.1.1; SM-P905V Build/LMY47X)",
    "Dalvik/2.1.0 (Linux; U; Android 5.0.2; VS980 4G Build/LRX22G)",
    "Dalvik/2.1.0 (Linux; U; Android 5.0; SM-G900F Build/LRX21T)",
  ];

  static const List<String> _timezones = [
    "America/New_York",
    "America/Los_Angeles",
    "Europe/London",
    "Europe/Paris",
    "Asia/Tokyo",
  ];

  static String _generateUuidV4() {
    final rnd = math.Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Future<MusicDetectionResult?> recognize(
    String signature,
    int sampleDurationMs, {
    http.Client? client,
  }) async {
    final rnd = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uuid1 = _generateUuidV4().toUpperCase();
    final uuid2 = _generateUuidV4();
    final url = Uri.parse("$_baseUrl/$uuid1/$uuid2?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true&video=v3");

    final headers = {
      "Content-Type": "application/json",
      "User-Agent": _userAgents[rnd.nextInt(_userAgents.length)],
      "Content-Language": "en_US",
    };

    final body = jsonEncode({
      "geolocation": {
        "altitude": rnd.nextDouble() * 400 + 100,
        "latitude": rnd.nextDouble() * 180 - 90,
        "longitude": rnd.nextDouble() * 360 - 180,
      },
      "signature": {
        "samplems": sampleDurationMs,
        "timestamp": timestamp,
        "uri": signature,
      },
      "timestamp": timestamp,
      "timezone": _timezones[rnd.nextInt(_timezones.length)],
    });

    final c = client ?? http.Client();
    final shouldClose = client == null;
    try {
      final response = await c.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        LogService.w('ShazamClient', 'Shazam HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is Map && data['track'] is Map) {
        final track = data['track'] as Map;
        final title = track['title']?.toString() ?? '';
        final artist = track['subtitle']?.toString() ?? '';
        final images = track['images'] as Map?;
        final cover = images?['coverart']?.toString() ?? images?['coverarthq']?.toString() ?? '';
        final sections = track['sections'] as List?;
        String album = 'Single';
        String? releaseDate;

        if (sections != null) {
          for (final s in sections) {
            if (s is Map && s['metadata'] is List) {
              for (final m in s['metadata']) {
                if (m is Map) {
                  final titleField = m['title']?.toString().toLowerCase();
                  if (titleField == 'album') {
                    album = m['text']?.toString() ?? album;
                  } else if (titleField == 'released') {
                    releaseDate = m['text']?.toString();
                  }
                }
              }
            }
          }
        }

        if (title.isNotEmpty) {
          return MusicDetectionResult(
            title: title,
            artist: artist,
            album: album,
            artworkUrl: cover,
            releaseDate: releaseDate,
            confidence: 0.98,
          );
        }
      }
    } catch (e) {
      LogService.w('ShazamClient', 'Recognition network error: $e');
    } finally {
      if (shouldClose) c.close();
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// MUSIC DETECTION SERVICE (AUDILE RECOGNITION ARCHITECTURE)
// ---------------------------------------------------------------------------

class MusicDetectionService {

  static const String _tag = 'MusicDetection';

  static http.Client? customClient;

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

      _currentRecordingPath = '${tempDir.path}/sine_detect_$timestamp.raw';

      // 3. Start recording raw 16-bit PCM Mono audio at 44.1kHz

      const recordConfig = RecordConfig(

        encoder: AudioEncoder.pcm16bits,

        sampleRate: 16000,

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

  /// Stops audio capture and sends acoustic fingerprint to Shazam recognition pipeline

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

    final targetFile = audioPath != null

        ? File(audioPath)

        : (_currentRecordingPath != null ? File(_currentRecordingPath!) : null);

    if (targetFile == null || !targetFile.existsSync() || targetFile.lengthSync() < 2000) {

      statusNotifier.value = DetectionStatus.noMatch;

      statusMessageNotifier.value = 'Could not capture clear audio. Please try again closer to speaker.';

      await _cleanup();

      return null;

    }

    try {

      final rawBytes = await targetFile.readAsBytes();

      await _cleanup();

      if (rawBytes.length < 2000) {

        statusNotifier.value = DetectionStatus.noMatch;

        statusMessageNotifier.value = 'Recording sample too short. Please try again.';

        return null;

      }

            // 1. Native 16.0kHz Mono PCM Audio Sample (Audile & Metrolist standard)
      final pcm16 = rawBytes.length >= 2000
          ? rawBytes
          : AudioResampler.resamplePcm16(rawBytes, 44100, 16000);

      if (pcm16.length < 2000) {

        statusNotifier.value = DetectionStatus.noMatch;

        statusMessageNotifier.value = 'Could not process audio sample.';

        return null;

      }

      // 2. Compute Shazam acoustic signature (pure Dart Cooley-Tukey RFFT + peak spreading)

      final signatureUri = ShazamSignatureGenerator.fromPcm16Mono16kHz(pcm16);

      final sampleDurationMs = (pcm16.length ~/ 2) * 1000 ~/ 16000;

      // 3. Query Shazam recognition endpoint

      MusicDetectionResult? match = await ShazamClient.recognize(

        signatureUri,

        sampleDurationMs,

        client: customClient,

      );

      if (match != null) {

        // 4. Resolve matched song with high-fidelity Sine/YouTube streaming candidates

        statusMessageNotifier.value = 'Locating high-fidelity stream...';

        final query = '${match.title} ${match.artist}';

        final searchResults = await CatalogService.searchOnline(query, limit: 3);

        Song? resolvedSineSong;

        if (searchResults.isNotEmpty) {

          resolvedSineSong = searchResults.first;

        } else {

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

        return fullResult;

      } else {

        statusNotifier.value = DetectionStatus.noMatch;

        statusMessageNotifier.value = 'No match found. Play the music louder or try another section.';

        return null;

      }

    } catch (e) {

      LogService.w(_tag, 'Recognition pipeline error: $e');

      statusNotifier.value = DetectionStatus.error;

      statusMessageNotifier.value = 'Recognition error: $e';

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
