import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_newpipe/services/lyrics_service.dart';
import 'package:spotify_newpipe/services/storage_service.dart';
import 'package:spotify_newpipe/services/youtube_cipher_service.dart';

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
      expect(decoded['version'], equals('1.2.5'));
      expect(decoded['versionCode'], equals(23));
      expect(decoded['settings'], isNotNull);

      // Verify import validation with valid JSON
      final importRes = await storage.importBackupJson(backupStr, merge: true);
      expect(importRes, isNotNull);

      // Verify rejection of invalid payload
      final invalidRes = await storage.importBackupJson('{"invalid": true}');
      expect(invalidRes, isNull);
    });
  });
}
