import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/services/lyrics_service.dart';
import 'package:spotify_newpipe/widgets/fluid_mesh_gradient.dart';
import 'package:spotify_newpipe/widgets/lyric_story_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.3.6 Enhancements & Stability Verification Suite', () {
    const song = Song(
      id: 'test_song_136',
      title: 'Midnight City',
      artist: 'M83',
      duration: Duration(seconds: 244),
      artworkUrl: 'https://example.com/cover.jpg',
      streamUrl: 'https://example.com/audio.opus',
    );

    final mockLyrics = [
      LyricLine(timestamp: const Duration(seconds: 5), text: 'Waiting in a car'),
      LyricLine(timestamp: const Duration(seconds: 10), text: 'Waiting for a ride in the dark'),
      LyricLine(timestamp: const Duration(seconds: 15), text: 'The night city grows'),
      LyricLine(timestamp: const Duration(seconds: 20), text: 'Look and see her eyes, they glow'),
      LyricLine(timestamp: const Duration(seconds: 25), text: 'Waiting in a car'),
    ];

    testWidgets('T1. LyricStoryCardSheet supports selecting up to 4 lines with interactive toggling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LyricStoryCardSheet(
              song: song,
              initialSelectedLines: mockLyrics.take(2).toList(),
              allLyrics: mockLyrics,
            ),
          ),
        ),
      );

      // Verify header shows (2/4)
      expect(find.text('Lyric Story (2/4)'), findsOneWidget);
      expect(find.text('Waiting in a car'), findsOneWidget);
      expect(find.text('Waiting for a ride in the dark'), findsOneWidget);

      // Open line picker
      final linePickerToggle = find.text('Choose Lines (2/4 selected)');
      expect(linePickerToggle, findsOneWidget);
      await tester.tap(linePickerToggle);
      await tester.pumpAndSettle();

      // Tap 3rd line: 'The night city grows'
      final thirdLine = find.text('The night city grows');
      expect(thirdLine, findsOneWidget);
      await tester.tap(thirdLine);
      await tester.pumpAndSettle();

      // Header should now reflect 3 lines selected
      expect(find.text('Lyric Story (3/4)'), findsOneWidget);

      // Tap 4th line: 'Look and see her eyes, they glow'
      final fourthLine = find.text('Look and see her eyes, they glow');
      expect(fourthLine, findsOneWidget);
      await tester.ensureVisible(fourthLine);
      await tester.pumpAndSettle();
      await tester.tap(fourthLine);
      await tester.pumpAndSettle();

      expect(find.text('Lyric Story (4/4)'), findsOneWidget);
    });

    testWidgets('T2. FluidMeshGradientBackground continuous orbital motion and smooth transition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: FluidMeshGradientBackground(
                song: song,
                isPlaying: true,
                child: SizedBox(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FluidMeshGradientBackground), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));

      // Rebuilding with new song should trigger smooth color transition without crashing or resetting
      const nextSong = Song(
        id: 'test_song_136_b',
        title: 'Instant Crush',
        artist: 'Daft Punk',
        duration: Duration(seconds: 337),
        artworkUrl: 'https://example.com/cover2.jpg',
        streamUrl: 'https://example.com/audio2.opus',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: FluidMeshGradientBackground(
                song: nextSong,
                isPlaying: true,
                child: SizedBox(),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(FluidMeshGradientBackground), findsOneWidget);
    });

    test('T3. Android MainActivity native image scanning & viewing registration', () {
      final mainActivityFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/MainActivity.kt');
      expect(mainActivityFile.existsSync(), isTrue);
      final code = mainActivityFile.readAsStringSync();

      expect(code, contains('scanMediaFile'));
      expect(code, contains('MediaScannerConnection.scanFile'));
      expect(code, contains('openImage'));
      expect(code, contains('image/*'));
    });

    test('T4. Sound shaping sheet clean Equalizer invariant (no corrupting sliders in EQ)', () {
      final soundShapingFile = File('lib/screens/sound_shaping_sheet.dart');
      expect(soundShapingFile.existsSync(), isTrue);
      final content = soundShapingFile.readAsStringSync();

      // Bass Exciter and 3D Spatializer sliders were removed from the EQ section
      expect(content, isNot(contains('Dynamic Bass Exciter (Sub-Harmonics)')));
      expect(content, isNot(contains('3D Spatializer (Stereo Width)')));
    });

    test('T5. AudioHandler pure pitch & speed shifts without hardware effect rebinding', () {
      final audioHandlerFile = File('lib/services/audio_handler.dart');
      expect(audioHandlerFile.existsSync(), isTrue);
      final code = audioHandlerFile.readAsStringSync();

      // Verify setSpeed does not trigger forced rebind of Equalizer AudioEffects
      final setSpeedIdx = code.indexOf('Future<void> setSpeed(double speed)');
      expect(setSpeedIdx, isNot(-1));
      final speedBody = code.substring(setSpeedIdx, setSpeedIdx + 300);
      expect(speedBody, isNot(contains('forceRebind: true')));

      // Verify setPitch does not trigger forced rebind of Equalizer AudioEffects
      final setPitchIdx = code.indexOf('Future<void> setPitch(double pitch)');
      expect(setPitchIdx, isNot(-1));
      final pitchBody = code.substring(setPitchIdx, setPitchIdx + 300);
      expect(pitchBody, isNot(contains('forceRebind: true')));

      // Verify LoudnessEnhancer is suppressed when pitch or speed is shifted
      expect(code, contains('final bool isPitchOrSpeedShifted ='));
      expect(code, contains('await _loudnessEnhancer.setEnabled(false)'));
    });

    test('T6. SynchronizedLyricsView floating toolbar horizontal scroll constraint', () {
      final lyricsViewFile = File('lib/widgets/synchronized_lyrics_view.dart');
      expect(lyricsViewFile.existsSync(), isTrue);
      final content = lyricsViewFile.readAsStringSync();

      // Floating toolbar must be horizontally scrollable to prevent overflow
      expect(content, contains('scrollDirection: Axis.horizontal'));
      expect(content, contains('Floating Lyric Enhancement Pill Toolbar'));
      expect(content, contains('left: 10'));
      expect(content, contains('right: 10'));
    });
  });
}
