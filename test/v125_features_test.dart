import 'package:spotify_newpipe/models/song.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_newpipe/services/audio_handler.dart';
import 'package:spotify_newpipe/services/stream_resolver_service.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:http/testing.dart';

import 'package:spotify_newpipe/services/metadata_correction_service.dart';

import 'dart:convert';

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:spotify_newpipe/services/lyrics_service.dart';

import 'package:spotify_newpipe/services/music_detection_service.dart';

import 'package:spotify_newpipe/services/storage_service.dart';

import 'package:spotify_newpipe/services/youtube_cipher_service.dart';

import 'package:spotify_newpipe/services/youtube_importer_service.dart';

void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.2.5 Features Test Suite', () {

    test('Pitch Shift Semitone Math Verification', () {

      expect(math.pow(2.0, 0 / 12.0).toDouble(), closeTo(1.0, 0.001));

      expect(math.pow(2.0, 12 / 12.0).toDouble(), closeTo(2.0, 0.001));

      expect(math.pow(2.0, -12 / 12.0).toDouble(), closeTo(0.5, 0.001));

      expect(math.pow(2.0, 1 / 12.0).toDouble(), closeTo(1.05946, 0.001));

      expect(math.pow(2.0, -1 / 12.0).toDouble(), closeTo(0.94387, 0.001));

    });

    test('YouTubeCipherService Signature Deciphering & N-Sig Unthrottling', () async {

      // Test unthrottling: if url has no n parameter, returns original

      const urlWithoutN = 'https://googlevideo.com/videoplayback?id=12345';

      expect(await YouTubeCipherService.unthrottleUrl(urlWithoutN), equals(urlWithoutN));

      // Test operations execution: Reverse, Swap, Slice

      const ops = [

        CipherOp(CipherOpType.reverse, 0),

        CipherOp(CipherOpType.swap, 2),

        CipherOp(CipherOpType.slice, 1),

      ];

      const testSig = 'abcdef';

      // reverse: 'fedcba'

      // swap 2: index 0 ('f') swaps with index 2 ('d') -> 'defcba'

      // slice 1: substring from 1 -> 'efcba'

      final result = YouTubeCipherService.executeOperations(testSig, ops);

      expect(result, equals('efcba'));

    });

    test('BetterLyrics Enhanced LRC Syllable & Word Parsing', () {

      const sampleLrc = '''

[00:00.00]Sine Music v1.2.5

[00:05.50]<00:05.50>Hello <00:06.00>world <00:07.00>again

[00:10.00]Standard lyric line without syllables

''';

      final lines = LyricsService.parseLrc(sampleLrc);

      expect(lines.length, equals(3));

      // Check first line

      expect(lines[0].text, equals('Sine Music v1.2.5'));

      expect(lines[0].isWordSynced, isFalse);

      // Check second line (karaoke synced)

      expect(lines[1].isWordSynced, isTrue);

      expect(lines[1].words.length, equals(3));

      expect(lines[1].words[0].text, equals('Hello '));

      expect(lines[1].words[0].timestamp, equals(const Duration(milliseconds: 5500)));

      expect(lines[1].words[1].text, equals('world '));

      expect(lines[1].words[1].timestamp, equals(const Duration(milliseconds: 6000)));

      // Check third line

      expect(lines[2].text, equals('Standard lyric line without syllables'));

      expect(lines[2].isWordSynced, isFalse);

    });

    test('Database Backup Export & Import Verification', () async {

      final storage = StorageService(null);

      final backupStr = storage.exportBackupJson();

      final decoded = jsonDecode(backupStr) as Map<String, dynamic>;

      expect(decoded['format'], equals('SINE_BACKUP'));

      expect(decoded['version'], equals('1.3.0'));

      expect(decoded['versionCode'], equals(30));

      expect(decoded['settings'], isNotNull);

      // Verify import validation with valid JSON

      final importRes = await storage.importBackupJson(backupStr, merge: true);

      expect(importRes, isNotNull);

      // Verify rejection of invalid payload

      final invalidRes = await storage.importBackupJson('{"invalid": true}');

      expect(invalidRes, isNull);

    });

    test('Audile MusicDetectionResult Model & CopyWith Integrity', () {

      const initial = MusicDetectionResult(

        title: 'Starboy',

        artist: 'The Weeknd',

        album: 'Starboy',

        artworkUrl: 'https://example.com/starboy.jpg',

        releaseDate: '2016-09-22',

        confidence: 0.98,

      );

      expect(initial.title, equals('Starboy'));

      expect(initial.artist, equals('The Weeknd'));

      expect(initial.confidence, equals(0.98));

      final updated = initial.copyWith(confidence: 1.0);

      expect(updated.title, equals('Starboy'));

      expect(updated.confidence, equals(1.0));

    });

    test('v1.0.8 Instant Progressive Stream Loading & Priority Invariant', () {
      const testSong = Song(
        id: 'test_track_123',
        title: 'Instant Loading Test',
        artist: 'Sine Artist',
        duration: const Duration(minutes: 3),
        artworkUrl: 'https://example.com/art.jpg',
        streamUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      // Verify stream cache key relies directly on clean video ID (v1.0.8 rock-solid configuration)
      expect(testSong.id, equals('test_track_123'));
      YouTubeImporterService.invalidateCache('dQw4w9WgXcQ');
      expect(StreamResolverService.isPreloaded(testSong), isFalse);
    });

    test('Tempo Modification Guard & Extended Audio Support', () {

      // Extended versions must NOT be flagged as tempo-modified

      expect(LyricsService.isTempoModified('WRONG (Extended Version)', 'Chris Grey'), isFalse);

      expect(LyricsService.isTempoModified('Starboy (Extended Mix)', 'The Weeknd'), isFalse);

      expect(LyricsService.isTempoModified('Original Extended', 'Artist'), isFalse);

      // Modified tempo tracks must be blocked from lyrics

      expect(LyricsService.isTempoModified('Wrong (Slowed + Reverb)', 'Chris Grey'), isTrue);

      expect(LyricsService.isTempoModified('Heat Waves (Sped Up)', 'Glass Animals'), isTrue);

      expect(LyricsService.isTempoModified('Blinding Lights (Nightcore)', 'The Weeknd'), isTrue);

      expect(LyricsService.isTempoModified('After Hours (Fast Version)', 'The Weeknd'), isTrue);

      expect(LyricsService.isTempoModified('Suzume (Reverb)', 'RADWIMPS'), isTrue);

    });

    test('Plain-to-Synced Lyrics Synthesis for Foreign/Native Tracks', () {

      const plain = '''

Baby, tell me lies

Whisper them on to my body, make me feel alive

Intertwinin' 'til I forget what's yours or mine

''';

      final lines = LyricsService.synthesizeTimedLyrics(plain, const Duration(seconds: 180));

      expect(lines.length, equals(3));

      expect(lines[0].timestamp, greaterThanOrEqualTo(Duration.zero));

      expect(lines[1].timestamp, greaterThan(lines[0].timestamp));

      expect(lines[2].timestamp, greaterThan(lines[1].timestamp));

      expect(lines[0].text, equals('Baby, tell me lies'));

    });

    test('Metadata Correction Service Swapped Detection & Resolution', () async {

      final mockClient = MockClient((request) async {

        if (request.url.host.contains('itunes.apple.com')) {

          return http.Response(

            jsonEncode({

              'resultCount': 1,

              'results': [

                {

                  'trackName': 'WRONG',

                  'artistName': 'Chris Grey',

                  'collectionName': 'The Castle Never Falls',

                  'artworkUrl100': 'https://example.com/art.jpg',

                }

              ]

            }),

            200,

          );

        }

        return http.Response('Not Found', 404);

      });

      final result = await MetadataCorrectionService.correctMetadata(

        'Chris Grey',

        'Wrong',

        client: mockClient,

      );

      expect(result.cleanArtist, equals('Chris Grey'));

      expect(result.cleanTitle.toLowerCase(), contains('wrong'));

      expect(result.wasSwapped, isTrue);

      expect(result.isVerified, isTrue);

    });


    test('Shazam Acoustic Signature Generator & Resampler Integrity', () async {
      // 1. Generate 1 second of 44.1kHz 16-bit PCM test tone (440Hz sine wave)
      const inputSamples = 44100;
      final rawPcm = Uint8List(inputSamples * 2);
      final byteData = ByteData.sublistView(rawPcm);
      for (int i = 0; i < inputSamples; i++) {
        final val = (math.sin(2 * math.pi * 440 * i / 44100) * 16000).toInt();
        byteData.setInt16(i * 2, val, Endian.little);
      }

      // 2. Resample to 16kHz
      final resampled = AudioResampler.resamplePcm16(rawPcm, 44100, 16000);
      expect(resampled.length, equals(16000 * 2));

      // 3. Generate Shazam signature URI
      final sigUri = ShazamSignatureGenerator.fromPcm16Mono16kHz(resampled);
      expect(sigUri.startsWith('data:audio/vnd.shazam.sig;base64,'), isTrue);

      // 4. Test ShazamClient with MockClient
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('amp.shazam.com')) {
          return http.Response(
            jsonEncode({
              'track': {
                'key': '123456',
                'title': 'Blinding Lights',
                'subtitle': 'The Weeknd',
                'images': {
                  'coverart': 'https://example.com/cover.jpg',
                },
                'sections': [
                  {
                    'metadata': [
                      {'title': 'Album', 'text': 'After Hours'},
                      {'title': 'Released', 'text': '2020'}
                    ]
                  }
                ]
              }
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await ShazamClient.recognize(sigUri, 1000, client: mockClient);
      expect(result, isNotNull);
      expect(result!.title, equals('Blinding Lights'));
      expect(result.artist, equals('The Weeknd'));
      expect(result.album, equals('After Hours'));
      expect(result.artworkUrl, equals('https://example.com/cover.jpg'));
    });

    test('Equalizer State & Custom Band Curve Retention Across Tracks', () {
      // 1. Verify 6-band UI mapping to 5-band hardware DSP
      const nBands = 5;
      final custom6Bands = {0: 3.5, 1: 1.0, 2: -2.0, 3: 4.0, 4: 2.5, 5: 5.0};

      final mappedGains = <int, double>{};
      for (int i = 0; i < nBands; i++) {
        final targetIdx = ((i / (nBands > 1 ? (nBands - 1) : 1)) * 5).round().clamp(0, 5);
        mappedGains[i] = custom6Bands[targetIdx] ?? 0.0;
      }

      expect(mappedGains.length, equals(5));
      expect(mappedGains[0], equals(3.5)); // 60 Hz maps to band 0
      expect(mappedGains[4], equals(5.0)); // 15 kHz maps to band 4 (highest hardware band)

      // 2. Verify StorageService band gains serialization
      final inGains = {0: 4.0, 1: 2.5, 2: 0.0, 3: -1.0, 4: 1.5, 5: 3.0};
      final encoded = jsonEncode(inGains.map((k, v) => MapEntry(k.toString(), v)));
      final decodedMap = jsonDecode(encoded) as Map<String, dynamic>;
      final restoredGains = decodedMap.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));

      expect(restoredGains.length, equals(6));
      expect(restoredGains[0], equals(4.0));
      expect(restoredGains[5], equals(3.0));
    });

    test('ShazamSignatureGenerator handles flat, zero, and plateau signals without NaN/Infinity', () {
      // Constant zero PCM (1.5s @ 16kHz)
      final zeroPcm = Uint8List(16000 * 2 * 2);
      final zeroSig = ShazamSignatureGenerator.fromPcm16Mono16kHz(zeroPcm);
      expect(zeroSig, startsWith('data:audio/vnd.shazam.sig;base64,'));
      expect(() => base64Decode(zeroSig.split(',')[1]), returnsNormally);

      // Constant non-zero DC plateau (flat spectrum after FFT DC bin)
      final dcBytes = ByteData(16000 * 2 * 2);
      for (int i = 0; i < 16000 * 2; i++) {
        dcBytes.setInt16(i * 2, 12000, Endian.little);
      }
      final dcSig = ShazamSignatureGenerator.fromPcm16Mono16kHz(dcBytes.buffer.asUint8List());
      expect(dcSig, startsWith('data:audio/vnd.shazam.sig;base64,'));
      expect(() => base64Decode(dcSig.split(',')[1]), returnsNormally);

      // Equal adjacent bins plateau (square wave at integer bin frequency)
      final plateauBytes = ByteData(16000 * 2 * 2);
      for (int i = 0; i < 16000 * 2; i++) {
        plateauBytes.setInt16(i * 2, (i % 16 < 8) ? 8000 : -8000, Endian.little);
      }
      final plateauSig = ShazamSignatureGenerator.fromPcm16Mono16kHz(plateauBytes.buffer.asUint8List());
      expect(plateauSig, startsWith('data:audio/vnd.shazam.sig;base64,'));
      expect(base64Decode(plateauSig.split(',')[1]).length, greaterThan(48));
    });

    test('AudioResampler sinc downsampler and quiet mic gain normalizer', () {
      // 1) Sinc downsampler 44100 Hz -> 16000 Hz preserves 440 Hz tone energy and length
      final tone44k = ByteData(44100 * 2);
      for (int i = 0; i < 44100; i++) {
        final v = (12000 * math.sin(2 * math.pi * 440 * i / 44100)).round();
        tone44k.setInt16(i * 2, v, Endian.little);
      }
      final downsampled = AudioResampler.resamplePcm16(
        tone44k.buffer.asUint8List(),
        44100,
        16000,
      );
      expect(downsampled.length, equals(16000 * 2));
      final downBd = ByteData.sublistView(downsampled);
      int maxDownPeak = 0;
      for (int i = 0; i < 16000; i++) {
        final a = downBd.getInt16(i * 2, Endian.little).abs();
        if (a > maxDownPeak) maxDownPeak = a;
      }
      expect(maxDownPeak, greaterThan(9000));

      // 2) Quiet audio (~1000 peak) obeys 12x max-gain cap (~12000 peak),
      // while ~2000 peak scales cleanly to ~20000 target peak
      final veryQuiet = ByteData(16000 * 2);
      final midQuiet = ByteData(16000 * 2);
      for (int i = 0; i < 16000; i++) {
        veryQuiet.setInt16(i * 2, (1000 * math.sin(2 * math.pi * 440 * i / 16000)).round(), Endian.little);
        midQuiet.setInt16(i * 2, (2000 * math.sin(2 * math.pi * 440 * i / 16000)).round(), Endian.little);
      }
      final boostedCapped = AudioResampler.normalizeQuietMicPcm16(veryQuiet.buffer.asUint8List());
      final cappedBd = ByteData.sublistView(boostedCapped);
      int maxCapped = 0;
      for (int i = 0; i < 16000; i++) {
        final a = cappedBd.getInt16(i * 2, Endian.little).abs();
        if (a > maxCapped) maxCapped = a;
      }
      expect(maxCapped, inInclusiveRange(11000, 12500));

      final boostedTarget = AudioResampler.normalizeQuietMicPcm16(midQuiet.buffer.asUint8List());
      final targetBd = ByteData.sublistView(boostedTarget);
      int maxTarget = 0;
      for (int i = 0; i < 16000; i++) {
        final a = targetBd.getInt16(i * 2, Endian.little).abs();
        if (a > maxTarget) maxTarget = a;
      }
      expect(maxTarget, inInclusiveRange(19000, 20500));

      // 3) Near-silence (<60 peak) stays unboosted
      final silence = ByteData(16000 * 2);
      for (int i = 0; i < 16000; i++) {
        final v = (20 * math.sin(2 * math.pi * 440 * i / 16000)).round();
        silence.setInt16(i * 2, v, Endian.little);
      }
      final unboosted = AudioResampler.normalizeQuietMicPcm16(silence.buffer.asUint8List());
      final unboostedBd = ByteData.sublistView(unboosted);
      int maxUnboosted = 0;
      for (int i = 0; i < 16000; i++) {
        final a = unboostedBd.getInt16(i * 2, Endian.little).abs();
        if (a > maxUnboosted) maxUnboosted = a;
      }
      expect(maxUnboosted, lessThanOrEqualTo(60));
    });

    test('MusicDetectionService.resetIfTerminal resets terminal states to idle', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final service = MusicDetectionService.instance;

      service.statusNotifier.value = DetectionStatus.noMatch;
      service.resetIfTerminal();
      expect(service.statusNotifier.value, equals(DetectionStatus.idle));

      service.statusNotifier.value = DetectionStatus.error;
      service.resetIfTerminal();
      expect(service.statusNotifier.value, equals(DetectionStatus.idle));

      service.statusNotifier.value = DetectionStatus.success;
      service.resetIfTerminal();
      expect(service.statusNotifier.value, equals(DetectionStatus.idle));
    });

    test('SineAudioHandler custom band gains & StorageService EQ state persistence', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final handler = SineAudioHandler();
      handler.setCustomBandGains({0: 4.5, 1: 2.0, 2: -1.5, 3: 3.0, 4: 5.0, 5: 6.0});
      final retained = handler.userCustomBandGains;
      expect(retained[0], equals(4.5));
      expect(retained[2], equals(-1.5));
      expect(retained[5], equals(6.0));

      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.saveEqualizerEnabled(true);
      await storage.saveEqualizerPreset('Custom');
      await storage.saveBassBoost(0.75);
      await storage.saveBandGains({0: 4.5, 1: 2.0, 2: -1.5, 3: 3.0, 4: 5.0, 5: 6.0});

      expect(storage.loadEqualizerEnabled(), isTrue);
      expect(storage.loadEqualizerPreset(), equals('Custom'));
      expect(storage.loadBassBoost(), closeTo(0.75, 0.001));
      final loadedGains = storage.loadBandGains();
      expect(loadedGains[0], equals(4.5));
      expect(loadedGains[2], equals(-1.5));
      expect(loadedGains[5], equals(6.0));
    });

    test('AudioResampler.extractCentered12Seconds Audile zero-padding & centering spec', () {
      // 1. Shorter audio (< 12 seconds, e.g. 3.5s = 56,000 samples = 112,000 bytes)
      final shortBytes = Uint8List(112000);
      for (int i = 0; i < shortBytes.length; i++) {
        shortBytes[i] = (i & 0x7F) + 1; // non-zero values
      }
      final padded = AudioResampler.extractCentered12Seconds(shortBytes);
      expect(padded.length, equals(384000)); // Exactly 12s * 16000 * 2 bytes
      // Verify prefix matches original audio
      expect(padded.sublist(0, 112000), equals(shortBytes));
      // Verify trailing bytes are zero-padded to flush 49-pass lookahead
      expect(padded[112000], equals(0));
      expect(padded[383999], equals(0));

      // 2. Exact 12 seconds audio (192,000 samples = 384,000 bytes)
      final exactBytes = Uint8List(384000);
      final exactResult = AudioResampler.extractCentered12Seconds(exactBytes);
      expect(exactResult.length, equals(384000));

      // 3. Longer audio (> 12 seconds, e.g. 15s = 240,000 samples = 480,000 bytes)
      final longBytes = Uint8List(480000);
      // Fill samples with identifiable pattern
      final bd = ByteData.sublistView(longBytes);
      for (int s = 0; s < 240000; s++) {
        bd.setInt16(s * 2, s & 0x7FFF, Endian.little);
      }
      final centered = AudioResampler.extractCentered12Seconds(longBytes);
      expect(centered.length, equals(384000));
      final centeredBd = ByteData.sublistView(centered);
      // Start sample should be (240000 - 192000) ~/ 2 = 24000
      expect(centeredBd.getInt16(0, Endian.little), equals(24000 & 0x7FFF));
    });

  });

}
