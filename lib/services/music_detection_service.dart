import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
// WINDOWED-SINC ANTI-ALIASED AUDIO RESAMPLER (44.1kHz -> 16kHz MONO PCM)
// ---------------------------------------------------------------------------

class AudioResampler {
  /// Resamples 16-bit little-endian mono PCM audio using a Hamming-windowed sinc
  /// low-pass kernel when downsampling (eliminating high-frequency aliasing above
  /// Nyquist that corrupts Shazam landmark FFT peaks), plus soft mic gain boost
  /// when capturing faint speaker audio across a room.
  static Uint8List resamplePcm16(Uint8List inputData, int inputRate, int outputRate) {
    if (inputData.length < 2) return inputData;
    final usableBytes = inputData.length - (inputData.length % 2);
    if (usableBytes < 2) return Uint8List(0);
    if (inputRate == outputRate) {
      return usableBytes == inputData.length
          ? inputData
          : Uint8List.sublistView(inputData, 0, usableBytes);
    }

    final inputLength = usableBytes ~/ 2;
    final byteData = ByteData.sublistView(inputData);
    final inputSamples = Float64List(inputLength);
    for (int i = 0; i < inputLength; i++) {
      inputSamples[i] = byteData.getInt16(i * 2, Endian.little).toDouble();
    }

    final ratio = outputRate / inputRate;
    final outputLength = (inputLength * ratio).toInt();
    if (outputLength <= 0) return Uint8List(0);

    final outputBytes = Uint8List(outputLength * 2);
    final outByteData = ByteData.sublistView(outputBytes);

    if (inputRate > outputRate) {
      // Anti-aliased windowed-sinc FIR downsampler (cutoff slightly below output Nyquist)
      const int halfTaps = 8;
      final double cutoff = (0.45 * outputRate) / inputRate; // ~0.163 for 44.1k -> 16k

      for (int i = 0; i < outputLength; i++) {
        final double center = i / ratio;
        final int centerIdx = center.floor();
        final double frac = center - centerIdx;

        double sum = 0.0;
        double weightSum = 0.0;
        for (int tap = -halfTaps; tap <= halfTaps; tap++) {
          final int sIdx = centerIdx + tap;
          if (sIdx < 0 || sIdx >= inputLength) continue;
          final double x = tap - frac;
          final double sinc = x.abs() < 1e-6
              ? 2.0 * cutoff
              : math.sin(2.0 * math.pi * cutoff * x) / (math.pi * x);
          final double windowArg = (x + halfTaps) / (2.0 * halfTaps);
          final double hamming = 0.54 - 0.46 * math.cos(2.0 * math.pi * windowArg);
          final double w = sinc * hamming;
          sum += inputSamples[sIdx] * w;
          weightSum += w;
        }
        final double val = weightSum > 1e-6 ? (sum / weightSum) : 0.0;
        outByteData.setInt16(i * 2, val.round().clamp(-32768, 32767), Endian.little);
      }
    } else {
      for (int i = 0; i < outputLength; i++) {
        final srcPos = i / ratio;
        final srcIndex = srcPos.toInt();
        final fraction = srcPos - srcIndex;
        final double sample;
        if (srcIndex + 1 < inputLength) {
          sample = inputSamples[srcIndex] * (1.0 - fraction) + inputSamples[srcIndex + 1] * fraction;
        } else if (srcIndex < inputLength) {
          sample = inputSamples[srcIndex];
        } else {
          sample = 0.0;
        }
        outByteData.setInt16(i * 2, sample.round().clamp(-32768, 32767), Endian.little);
      }
    }

    return outputBytes;
  }

  /// Normalizes quiet room recordings so ambient speaker peaks clear Shazam's 1/64
  /// FFT magnitude gate without altering relative spectral ratios.
  static Uint8List normalizeQuietMicPcm16(Uint8List pcm16Bytes) {
    final usable = pcm16Bytes.length - (pcm16Bytes.length % 2);
    if (usable < 2) return pcm16Bytes;
    final len = usable ~/ 2;
    final bd = ByteData.sublistView(pcm16Bytes);

    int maxAbs = 0;
    for (int i = 0; i < len; i++) {
      final a = bd.getInt16(i * 2, Endian.little).abs();
      if (a > maxAbs) maxAbs = a;
    }

    // Do not boost near-silence (< 60) or already-healthy levels (>= 14000)
    if (maxAbs < 60 || maxAbs >= 14000) {
      return usable == pcm16Bytes.length
          ? pcm16Bytes
          : Uint8List.sublistView(pcm16Bytes, 0, usable);
    }

    final gain = (20000.0 / maxAbs).clamp(1.0, 12.0);
    if (gain <= 1.05) return pcm16Bytes;

    final out = Uint8List(usable);
    final outBd = ByteData.sublistView(out);
    for (int i = 0; i < len; i++) {
      final v = (bd.getInt16(i * 2, Endian.little) * gain).round().clamp(-32768, 32767);
      outBd.setInt16(i * 2, v, Endian.little);
    }
    return out;
  }

  /// Extracts exactly a 12-second sample from 16kHz PCM audio (192,000 samples = 384,000 bytes).
  /// Replicates Audile's DecodedAudio.extractCentered12Seconds() & SongRec SignatureGenerator.
  /// If shorter -> pads with zeros at the end so the 49-pass lookahead delay flushes all peaks.
  /// If longer -> takes 12 seconds from the middle.
  static Uint8List extractCentered12Seconds(Uint8List pcm16kBytes) {
    const targetSamples = 12 * ShazamSignatureGenerator.sampleRate; // 192,000 samples
    const targetBytes = targetSamples * 2; // 384,000 bytes
    final totalSamples = pcm16kBytes.length ~/ 2;

    if (totalSamples == targetSamples) return pcm16kBytes;

    final result = Uint8List(targetBytes);
    if (totalSamples < targetSamples) {
      result.setRange(0, pcm16kBytes.length, pcm16kBytes);
      return result;
    }

    final startSample = (totalSamples - targetSamples) ~/ 2;
    final startByte = startSample * 2;
    result.setRange(0, targetBytes, pcm16kBytes, startByte);
    return result;
  }
}

// ---------------------------------------------------------------------------
// SHAZAM PURE-DART SIGNATURE GENERATOR (SONGREC / AUDILE EXACT SPEC)
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
      throw ArgumentError('Samples must be a non-empty byte array with even length (16-bit PCM)');
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

  final List<Float64List> spreadFfts = List.generate(
    ShazamSignatureGenerator.ringBufSize,
    (_) => Float64List(ShazamSignatureGenerator.fftOutputSize),
  );
  int spreadPos = 0;
  int spreadNumWritten = 0;

  int numSamples = 0;
  final List<List<_FrequencyPeak>> bandPeaks = List.generate(4, (_) => []);
  int totalPeaks = 0;

  // Reusable scratch FFT arrays to eliminate per-pass heap allocations
  final Float64List _re = Float64List(ShazamSignatureGenerator.fftSize);
  final Float64List _im = Float64List(ShazamSignatureGenerator.fftSize);
  final Float64List _magnitudes = Float64List(ShazamSignatureGenerator.fftOutputSize);

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
      samplesPos = (samplesPos + 1) & 2047;
    }
  }

  void doFFT() {
    for (int i = 0; i < ShazamSignatureGenerator.fftSize; i++) {
      final ringIdx = (samplesPos + i) & 2047;
      _re[i] = samplesRing[ringIdx].toDouble() * ShazamSignatureGenerator.hanning[i];
      _im[i] = 0.0;
    }
    final result = computeRfftInPlace();
    fftOutputs[fftPos].setAll(0, result);
    fftPos = (fftPos + 1) & 255;
  }

  void doPeakSpreadingAndRecognition() {
    doPeakSpreading();
    spreadNumWritten++;
    if (spreadNumWritten >= 46) {
      doPeakRecognition();
    }
  }

  void doPeakSpreading() {
    final lastFftIdx = (fftPos - 1) & 255;
    final spread = spreadFfts[spreadPos];
    spread.setAll(0, fftOutputs[lastFftIdx]);

    for (int pos = 0; pos <= ShazamSignatureGenerator.fftOutputSize - 3; pos++) {
      final a = spread[pos];
      final b = spread[pos + 1];
      final c = spread[pos + 2];
      spread[pos] = a >= b ? (a >= c ? a : c) : (b >= c ? b : c);
    }

    for (int pos = 0; pos < ShazamSignatureGenerator.fftOutputSize; pos++) {
      final sVal = spread[pos];
      for (final former in const [1, 3, 6]) {
        final idx = (spreadPos - former) & 255;
        if (sVal > spreadFfts[idx][pos]) {
          spreadFfts[idx][pos] = sVal;
        }
      }
    }

    spreadPos = (spreadPos + 1) & 255;
  }

  void doPeakRecognition() {
    final fftMinus46 = fftOutputs[(fftPos - 46) & 255];
    final spreadMinus49 = spreadFfts[(spreadPos - 49) & 255];
    const otherOffsets = [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249];
    const neighbors = [-10, -7, -4, -3, 1, 2, 5, 8];

    for (int binPos = 10; binPos <= 1014; binPos++) {
      final fftVal = fftMinus46[binPos];
      if (fftVal < 1.0 / 64.0 || fftVal < spreadMinus49[binPos - 1]) continue;

      double maxNeighborSpread49 = 0.0;
      for (final neighborOffset in neighbors) {
        final v = spreadMinus49[binPos + neighborOffset];
        if (v > maxNeighborSpread49) maxNeighborSpread49 = v;
      }
      if (fftVal <= maxNeighborSpread49) continue;

      double maxNeighborOther = maxNeighborSpread49;
      for (final otherOffset in otherOffsets) {
        final v = spreadFfts[(spreadPos + otherOffset) & 255][binPos - 1];
        if (v > maxNeighborOther) maxNeighborOther = v;
      }
      if (fftVal <= maxNeighborOther) continue;

      final fftNumber = spreadNumWritten - 46;
      final peakMag = math.log(math.max(1.0 / 64.0, fftVal)) * 1477.3 + 6144.0;
      final peakMagBefore = math.log(math.max(1.0 / 64.0, fftMinus46[binPos - 1])) * 1477.3 + 6144.0;
      final peakMagAfter = math.log(math.max(1.0 / 64.0, fftMinus46[binPos + 1])) * 1477.3 + 6144.0;

      final peakVariation1 = peakMag * 2.0 - peakMagBefore - peakMagAfter;
      final double peakVariation2 = peakVariation1 > 1e-9
          ? (peakMagAfter - peakMagBefore) * 32.0 / peakVariation1
          : 0.0;

      final int correctedBin = (binPos * 64 + peakVariation2.toInt()).clamp(0, 65535);
      final double frequencyHz = correctedBin * (16000.0 / 2.0 / 1024.0 / 64.0);

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
          peakMagnitude: peakMag.toInt().clamp(0, 65535),
          correctedPeakFrequencyBin: correctedBin,
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
    return 'data:audio/vnd.shazam.sig;base64,$base64';
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

  Float64List computeRfftInPlace() {
    const n = ShazamSignatureGenerator.fftSize;
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tmpRe = _re[i];
        _re[i] = _re[j];
        _re[j] = tmpRe;
        final tmpIm = _im[i];
        _im[i] = _im[j];
        _im[j] = tmpIm;
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
          final evenRe = _re[u];
          final evenIm = _im[u];
          final oddRe = _re[v] * wRe - _im[v] * wIm;
          final oddIm = _re[v] * wIm + _im[v] * wRe;
          _re[u] = evenRe + oddRe;
          _im[u] = evenIm + oddIm;
          _re[v] = evenRe - oddRe;
          _im[v] = evenIm - oddIm;
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
    for (int idx = 0; idx < ShazamSignatureGenerator.fftOutputSize; idx++) {
      final r = _re[idx];
      final img = _im[idx];
      final mag = (r * r + img * img) * scaleFactor;
      _magnitudes[idx] = mag < minVal ? minVal : mag;
    }
    return _magnitudes;
  }
}

// ---------------------------------------------------------------------------
// SHAZAM HTTP CLIENT
// ---------------------------------------------------------------------------

class _RecognizePayload {
  final Uint8List raw44kBytes;
  final int inputSampleRate;
  _RecognizePayload(this.raw44kBytes, this.inputSampleRate);
}

({String signature, int sampleDurationMs}) _generateSignatureInIsolate(_RecognizePayload payload) {
  final resampled = AudioResampler.resamplePcm16(
    payload.raw44kBytes,
    payload.inputSampleRate,
    ShazamSignatureGenerator.sampleRate,
  );
  final normalized = AudioResampler.normalizeQuietMicPcm16(resampled);
  final centered12s = AudioResampler.extractCentered12Seconds(normalized);
  final sig = ShazamSignatureGenerator.fromPcm16Mono16kHz(centered12s);
  final durationMs = (normalized.length ~/ 2) * 1000 ~/ ShazamSignatureGenerator.sampleRate;
  return (signature: sig, sampleDurationMs: durationMs);
}

class ShazamClient {
  static const String _baseUrl = 'https://amp.shazam.com/discovery/v5/en/US/android/-/tag';
  static String? lastErrorReason;

  static const List<String> _userAgents = [
    'Dalvik/2.1.0 (Linux; U; Android 6.0.1; SM-G920F Build/MMB29K)',
    'Dalvik/2.1.0 (Linux; U; Android 5.1.1; SM-P905V Build/LMY47X)',
    'Dalvik/2.1.0 (Linux; U; Android 5.0.2; VS980 4G Build/LRX22G)',
    'Dalvik/2.1.0 (Linux; U; Android 5.0; SM-G900F Build/LRX21T)',
    'Dalvik/2.1.0 (Linux; U; Android 6.0.1; A0001 Build/MMB29X)',
    'Dalvik/2.1.0 (Linux; U; Android 6.0.1; SM-G930F Build/MMB29K)',
  ];

  static const List<String> _timezones = [
    'Europe/Paris',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Amsterdam',
    'Europe/Madrid',
    'Europe/Rome',
    'Europe/Brussels',
    'Europe/Vienna',
    'Europe/Dublin',
    'Europe/Copenhagen',
    'Europe/Stockholm',
    'Europe/Oslo',
    'Europe/Helsinki',
    'Europe/Zurich',
    'Europe/Warsaw',
    'Europe/Prague',
    'Europe/Budapest',
    'Europe/Athens',
    'Europe/Lisbon',
  ];

  static String _generateUuidV4() {
    final rnd = math.Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Future<MusicDetectionResult?> recognize(
    String signature,
    int sampleDurationMs, {
    http.Client? client,
  }) async {
    lastErrorReason = null;
    final rnd = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uuid1 = _generateUuidV4().toUpperCase();
    final uuid2 = _generateUuidV4();
    final url = Uri.parse(
      '$_baseUrl/$uuid1/$uuid2?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true&video=v3',
    );

    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': _userAgents[rnd.nextInt(_userAgents.length)],
      'Content-Language': 'en_US',
    };

    final body = jsonEncode({
      'geolocation': {
        'altitude': 100.0 + rnd.nextDouble() * 400.0,
        'latitude': rnd.nextDouble() * 180.0 - 90.0,
        'longitude': rnd.nextDouble() * 360.0 - 180.0,
      },
      'signature': {
        'samplems': sampleDurationMs,
        'timestamp': timestamp,
        'uri': signature,
      },
      'timestamp': timestamp,
      'timezone': _timezones[rnd.nextInt(_timezones.length)],
    });

    final c = client ?? http.Client();
    final shouldClose = client == null;
    try {
      final response = await c.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (response.statusCode == 429) {
        lastErrorReason = 'Shazam server rate limit reached. Wait a few seconds and try again.';
        LogService.w('ShazamClient', 'Shazam HTTP 429 rate limited');
        return null;
      }
      if (response.statusCode != 200) {
        lastErrorReason = 'Shazam service error (HTTP ${response.statusCode})';
        LogService.w('ShazamClient', 'Shazam HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is Map && data['track'] is Map) {
        final track = data['track'] as Map;
        final title = track['title']?.toString() ?? '';
        final artist = track['subtitle']?.toString() ?? '';
        final images = track['images'] as Map?;
        final cover = images?['coverarthq']?.toString() ?? images?['coverart']?.toString() ?? '';
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
      lastErrorReason = 'Network connection error. Check your internet connection.';
      LogService.w('ShazamClient', 'Recognition network error: $e');
    } finally {
      if (shouldClose) c.close();
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// MUSIC DETECTION SERVICE (AUDILE STREAMING ARCHITECTURE)
// ---------------------------------------------------------------------------

class MusicDetectionService {
  static const String _tag = 'MusicDetection';
  static const int _preferredCaptureSampleRate = 48000;
  static const int _fallbackCaptureSampleRate = 44100;
  int _activeCaptureSampleRate = _preferredCaptureSampleRate;
  static http.Client? customClient;

  static final MusicDetectionService _instance = MusicDetectionService._internal();
  static MusicDetectionService get instance => _instance;

  MusicDetectionService._internal();

  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioStreamSub;
  BytesBuilder _pcmChunksBuffer = BytesBuilder(copy: false);
  Timer? _firstProbeTimer;
  Timer? _secondProbeTimer;
  Timer? _recordingTimeoutTimer;

  int _sessionCounter = 0;
  bool _isProbing = false;
  bool _matchedDuringProbe = false;

  final ValueNotifier<DetectionStatus> statusNotifier = ValueNotifier<DetectionStatus>(DetectionStatus.idle);
  final ValueNotifier<double> amplitudeNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> statusMessageNotifier = ValueNotifier<String>('Tap to listen & detect music');
  final ValueNotifier<MusicDetectionResult?> resultNotifier = ValueNotifier<MusicDetectionResult?>(null);

  bool get isListening => statusNotifier.value == DetectionStatus.listening;

  /// Clears previous finished state (success / noMatch / error) so opening the sheet starts fresh
  void resetIfTerminal() {
    final s = statusNotifier.value;
    if (s == DetectionStatus.success || s == DetectionStatus.noMatch || s == DetectionStatus.error) {
      statusNotifier.value = DetectionStatus.idle;
      statusMessageNotifier.value = 'Tap to listen & detect music';
      amplitudeNotifier.value = 0.0;
      resultNotifier.value = null;
    }
  }

  /// Starts listening to ambient audio through microphone via zero-interruption PCM stream
  Future<void> startListening({Duration duration = const Duration(milliseconds: 9500)}) async {
    final st = statusNotifier.value;
    if (st == DetectionStatus.requestingPermission ||
        st == DetectionStatus.listening ||
        st == DetectionStatus.analyzing) {
      return;
    }

    final int thisSession = ++_sessionCounter;

    try {
      statusNotifier.value = DetectionStatus.requestingPermission;
      statusMessageNotifier.value = 'Requesting microphone permission...';

      final micStatus = await Permission.microphone.request();
      if (thisSession != _sessionCounter) return;
      if (!micStatus.isGranted) {
        statusNotifier.value = DetectionStatus.error;
        statusMessageNotifier.value = 'Microphone permission denied. Enable in device settings.';
        return;
      }

      // Properly await teardown of previous recorder instance before acquiring semaphore
      await _disposeRecorder();
      if (thisSession != _sessionCounter) return;

      _pcmChunksBuffer = BytesBuilder(copy: false);
      _isProbing = false;
      _matchedDuringProbe = false;
      resultNotifier.value = null;

      _audioRecorder = AudioRecorder();

      RecordConfig buildRecordConfig(int sampleRate) => RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.mic,
          manageBluetooth: false,
          muteAudio: false,
          audioManagerMode: AudioManagerMode.modeNormal,
        ),
      );

      Stream<Uint8List> pcmStream;
      try {
        _activeCaptureSampleRate = _preferredCaptureSampleRate;
        pcmStream = await _audioRecorder!.startStream(buildRecordConfig(_activeCaptureSampleRate));
      } catch (e) {
        LogService.w(_tag, '48kHz stream failed, falling back to 44.1kHz: $e');
        _activeCaptureSampleRate = _fallbackCaptureSampleRate;
        pcmStream = await _audioRecorder!.startStream(buildRecordConfig(_activeCaptureSampleRate));
      }

      if (thisSession != _sessionCounter) {
        await _disposeRecorder();
        return;
      }

      statusNotifier.value = DetectionStatus.listening;
      statusMessageNotifier.value = 'Listening to music playing nearby...';

      _audioStreamSub = pcmStream.listen(
        (chunk) {
          if (thisSession != _sessionCounter || chunk.isEmpty) return;
          _pcmChunksBuffer.add(chunk);
          _updateAmplitudeFromChunk(chunk);
        },
        onError: (Object err) {
          LogService.w(_tag, 'PCM audio stream error: $err');
        },
      );

      // Audile Stage 1: Fast background probe at 3.5s while continuing to record
      _firstProbeTimer?.cancel();
      _firstProbeTimer = Timer(const Duration(milliseconds: 3500), () {
        if (thisSession == _sessionCounter && isListening) {
          _attemptProbe(thisSession, minSeconds: 3.0);
        }
      });

      // Audile Stage 2: Second background probe at 6.5s while continuing to record
      _secondProbeTimer?.cancel();
      _secondProbeTimer = Timer(const Duration(milliseconds: 6500), () {
        if (thisSession == _sessionCounter && isListening) {
          _attemptProbe(thisSession, minSeconds: 5.5);
        }
      });

      // Audile Stage 3: Full-window capture completion at 9.5s
      _recordingTimeoutTimer?.cancel();
      _recordingTimeoutTimer = Timer(duration, () {
        if (thisSession == _sessionCounter && isListening) {
          stopAndIdentify();
        }
      });
    } catch (e) {
      if (thisSession != _sessionCounter) return;
      LogService.w(_tag, 'Start listening error: $e');
      statusNotifier.value = DetectionStatus.error;
      statusMessageNotifier.value = 'Failed to start microphone: $e';
      await _disposeRecorder();
    }
  }

  void _updateAmplitudeFromChunk(Uint8List chunk) {
    final len = chunk.length ~/ 2;
    if (len <= 0) return;
    final bd = ByteData.sublistView(chunk);
    double sumSq = 0.0;
    // Sample stride for fast O(1)-feel UI metering
    final step = len > 256 ? (len ~/ 256) : 1;
    int count = 0;
    for (int i = 0; i < len; i += step) {
      final s = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sumSq += s * s;
      count++;
    }
    if (count == 0) return;
    final rms = math.sqrt(sumSq / count);
    if (rms <= 1e-6) {
      if (amplitudeNotifier.value != 0.0) {
        amplitudeNotifier.value = 0.0;
      }
      return;
    }
    final db = (20.0 * math.log(rms) / math.ln10).clamp(-55.0, 0.0);
    final norm = ((db + 55.0) / 55.0).clamp(0.0, 1.0);
    if ((norm - amplitudeNotifier.value).abs() >= 0.02) {
      amplitudeNotifier.value = norm;
    }
  }

  Future<void> _attemptProbe(int expectedSession, {required double minSeconds}) async {
    if (_isProbing || _matchedDuringProbe) return;
    final snapshot = _pcmChunksBuffer.toBytes();
    final minBytes = (_activeCaptureSampleRate * 2 * minSeconds).toInt();
    if (snapshot.length < minBytes) return;

    _isProbing = true;
    try {
      // Skip initial 120ms hardware click
      final skipBytes = (_activeCaptureSampleRate * 120 ~/ 1000) * 2;
      final trimmed = snapshot.length > skipBytes + (_activeCaptureSampleRate * 2 * 2)
          ? Uint8List.sublistView(snapshot, skipBytes)
          : snapshot;

      final prepared = await compute(
        _generateSignatureInIsolate,
        _RecognizePayload(trimmed, _activeCaptureSampleRate),
      );

      if (expectedSession != _sessionCounter || !isListening) return;

      final match = await ShazamClient.recognize(
        prepared.signature,
        prepared.sampleDurationMs,
        client: customClient,
      );

      if (match != null && expectedSession == _sessionCounter && isListening) {
        _matchedDuringProbe = true;
        _firstProbeTimer?.cancel();
        _secondProbeTimer?.cancel();
        _recordingTimeoutTimer?.cancel();
        statusNotifier.value = DetectionStatus.analyzing;
        statusMessageNotifier.value = 'Match found! Loading track...';
        await _disposeRecorder();
        await _finalizeMatch(match, expectedSession);
      }
    } catch (e) {
      LogService.w(_tag, 'Probe error (will continue listening): $e');
    } finally {
      _isProbing = false;
    }
  }

  /// Stops audio capture and sends full-window acoustic fingerprint to Shazam
  Future<MusicDetectionResult?> stopAndIdentify() async {
    if (_matchedDuringProbe) return resultNotifier.value;

    final int thisSession = _sessionCounter;
    _firstProbeTimer?.cancel();
    _secondProbeTimer?.cancel();
    _recordingTimeoutTimer?.cancel();

    if (_audioRecorder == null && _pcmChunksBuffer.length == 0) return null;

    statusNotifier.value = DetectionStatus.analyzing;
    statusMessageNotifier.value = 'Analyzing acoustic audio fingerprint...';

    final rawPcm = _pcmChunksBuffer.takeBytes();
    await _disposeRecorder();

    if (thisSession != _sessionCounter) return null;

    // Require >= 1.5 seconds of PCM bytes
    if (rawPcm.length < _activeCaptureSampleRate * 2 * 3 ~/ 2) {
      statusNotifier.value = DetectionStatus.noMatch;
      statusMessageNotifier.value = rawPcm.isEmpty
          ? 'No audio captured from microphone. Check mic access or try closing other recording apps.'
          : 'Sample too short (${(rawPcm.length / (_activeCaptureSampleRate * 2)).toStringAsFixed(1)}s). Hold closer to music longer.';
      return null;
    }

    try {
      // Discard first 150ms ADC startup click if we have plenty of audio
      final skipBytes = (_activeCaptureSampleRate * 150 ~/ 1000) * 2;
      final trimmed = rawPcm.length > skipBytes + (_activeCaptureSampleRate * 2 * 2)
          ? Uint8List.sublistView(rawPcm, skipBytes)
          : rawPcm;

      final prepared = await compute(
        _generateSignatureInIsolate,
        _RecognizePayload(trimmed, _activeCaptureSampleRate),
      );

      if (thisSession != _sessionCounter) return null;

      final match = await ShazamClient.recognize(
        prepared.signature,
        prepared.sampleDurationMs,
        client: customClient,
      );

      if (thisSession != _sessionCounter) return null;

      if (match != null) {
        return await _finalizeMatch(match, thisSession);
      } else {
        if (ShazamClient.lastErrorReason != null) {
          statusNotifier.value = DetectionStatus.error;
          statusMessageNotifier.value = ShazamClient.lastErrorReason!;
        } else {
          statusNotifier.value = DetectionStatus.noMatch;
          statusMessageNotifier.value = 'No match found. Play the music louder or try the chorus.';
        }
        return null;
      }
    } catch (e) {
      if (thisSession != _sessionCounter) return null;
      LogService.w(_tag, 'Recognition pipeline error: $e');
      statusNotifier.value = DetectionStatus.error;
      statusMessageNotifier.value = 'Recognition error: $e';
      return null;
    }
  }

  Future<MusicDetectionResult> _finalizeMatch(MusicDetectionResult match, int thisSession) async {
    statusMessageNotifier.value = 'Locating high-fidelity stream...';
    Song? resolvedSineSong;
    try {
      final query = '${match.title} ${match.artist}';
      final searchResults = await CatalogService.searchOnline(query, limit: 3).timeout(const Duration(seconds: 8));
      if (searchResults.isNotEmpty) {
        resolvedSineSong = searchResults.first;
      }
    } catch (e) {
      LogService.w(_tag, 'Stream catalog lookup fallback for matched song: $e');
    }

    resolvedSineSong ??= Song(
      id: 'detect_${DateTime.now().millisecondsSinceEpoch}',
      title: match.title,
      artist: match.artist,
      duration: const Duration(minutes: 3),
      artworkUrl: match.artworkUrl,
      streamUrl: '',
    );

    final fullResult = match.copyWith(sineSong: resolvedSineSong);
    if (thisSession == _sessionCounter) {
      resultNotifier.value = fullResult;
      statusNotifier.value = DetectionStatus.success;
      statusMessageNotifier.value = 'Song Identified!';
    }
    return fullResult;
  }

  /// Cancels listening and cleans up recorder resources
  Future<void> cancel() async {
    _sessionCounter++;
    _firstProbeTimer?.cancel();
    _secondProbeTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _pcmChunksBuffer.clear();
    await _disposeRecorder();
    statusNotifier.value = DetectionStatus.idle;
    statusMessageNotifier.value = 'Tap to listen & detect music';
    amplitudeNotifier.value = 0.0;
  }

  /// Manual identification by heard lyrics or humming query
  Future<MusicDetectionResult?> identifyByQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return null;
    final int thisSession = ++_sessionCounter;

    await _disposeRecorder();
    statusNotifier.value = DetectionStatus.analyzing;
    statusMessageNotifier.value = 'Searching lyrics and acoustic matches for "$clean"...';

    try {
      final searchResults = await CatalogService.searchOnline(clean, limit: 5);
      if (thisSession != _sessionCounter) return null;
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
      if (thisSession != _sessionCounter) return null;
      statusNotifier.value = DetectionStatus.error;
      statusMessageNotifier.value = 'Search error: $e';
      return null;
    }
  }

  Future<void> _disposeRecorder() async {
    _firstProbeTimer?.cancel();
    _firstProbeTimer = null;
    _secondProbeTimer?.cancel();
    _secondProbeTimer = null;
    _recordingTimeoutTimer?.cancel();
    _recordingTimeoutTimer = null;

    final sub = _audioStreamSub;
    _audioStreamSub = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }

    final rec = _audioRecorder;
    _audioRecorder = null;
    if (rec != null) {
      try {
        await rec.stop().catchError((_) => null);
      } catch (_) {}
      try {
        await rec.dispose();
      } catch (_) {}
    }
    amplitudeNotifier.value = 0.0;
  }
}
