import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/widgets/spotify_graph_equalizer.dart';
import 'package:spotify_newpipe/widgets/bouncy_tap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('v1.3.7 / v1.3.8 / v1.3.9 Release & Version Integrity Suite', () {
    test('AppConstants strictly matches release specifications', () {
      expect(AppConstants.appName, 'Sine');
      expect(AppConstants.version, anyOf(['1.3.7', '1.3.8', '1.3.9', '1.4.0']));
      expect(AppConstants.buildNumber, anyOf([37, 38, 39, 40]));
      expect(AppConstants.fullVersion, anyOf(['1.3.7+37', '1.3.8+38', '1.3.9+39', '1.4.0+40']));
      expect(AppConstants.releaseTag, anyOf(['v1.3.7', 'v1.3.8', 'v1.3.9', 'v1.4.0']));
    });

    test('pubspec.yaml specifies valid version and just_audio dependency override', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, anyOf([contains('version: 1.3.7+37'), contains('version: 1.3.8+38'), contains('version: 1.3.9+39'), contains('version: 1.4.0+40')]));
      expect(pubspec, contains('dependency_overrides:'));
      expect(pubspec, contains('just_audio:'));
      expect(pubspec, contains('path: packages/just_audio'));
    });

    test('F-Droid metadata and release script match version specs', () {
      final yml = File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync();
      expect(yml, anyOf([contains('CurrentVersion: 1.3.7'), contains('CurrentVersion: 1.3.8'), contains('CurrentVersion: 1.3.9'), contains('CurrentVersion: 1.4.0')]));
      expect(yml, anyOf([contains('CurrentVersionCode: 37'), contains('CurrentVersionCode: 38'), contains('CurrentVersionCode: 39'), contains('CurrentVersionCode: 40')]));

      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, anyOf([contains("'v1.3.7'"), contains("'v1.3.8'"), contains("'v1.3.9'"), contains("'v1.4.0'")]));
    });
  });

  group('v1.3.7 Pure OG Sine Equalizer & Attribution Cleansing Suite', () {
    test('SpotifyGraphEqualizer contains 25 clean OG presets without AutoEq, JamesDSP, or APO', () {
      const presets = SpotifyGraphEqualizer.standardPresets;
      expect(presets.length, 25);

      // Verify complete elimination of external DSP references
      for (final p in presets) {
        expect(p.name, isNot(contains('AutoEq')));
        expect(p.name, isNot(contains('JamesDSP')));
        expect(p.name, isNot(contains('Equalizer APO')));
        expect(p.name, isNot(contains('Harman')));
        expect(p.name, isNot(contains('Nightcore')));
        expect(p.name, isNot(contains('Slowed')));
        expect(p.description, isNot(contains('AutoEq')));
        expect(p.description, isNot(contains('JamesDSP')));
        expect(p.description, isNot(contains('Equalizer APO')));

        // Valid categories
        expect(p.category, anyOf('Bass & Beats', 'Vocal & Clarity', 'Acoustic & Mood'));
        expect(p.gains.length, 6);
        for (final g in p.gains) {
          expect(g, greaterThanOrEqualTo(-12.0));
          expect(g, lessThanOrEqualTo(12.0));
        }
      }

      // Key classic OG presets presence
      final presetNames = presets.map((p) => p.name).toList();
      expect(presetNames, contains('Flat'));
      expect(presetNames, contains('Bass Boost'));
      expect(presetNames, contains('Bass Reducer'));
      expect(presetNames, contains('Hip-Hop'));
      expect(presetNames, contains('Electronic'));
      expect(presetNames, contains('Dance'));
      expect(presetNames, contains('Club'));
      expect(presetNames, contains('Vocal Booster'));
      expect(presetNames, contains('Vocal Air'));
      expect(presetNames, contains('Spoken Word'));
      expect(presetNames, contains('Acoustic'));
      expect(presetNames, contains('Rock'));
      expect(presetNames, contains('Pop'));
      expect(presetNames, contains('Jazz'));
      expect(presetNames, contains('Piano'));
    });

    test('AppConstants openSourceAttributions does NOT contain AutoEq, JamesDSP, or Equalizer APO', () {
      final names = AppConstants.openSourceAttributions.map((a) => a['name']).toList();
      expect(names, isNot(contains('AutoEq')));
      expect(names, isNot(contains('JamesDSP')));
      expect(names, isNot(contains('Equalizer APO')));

      // Retains valid active open source components
      expect(names, contains('Audile'));
      expect(names, contains('zemer-cipher'));
      expect(names, contains('BetterLyrics'));
      expect(names, contains('Metrolist'));
    });

    test('Equalizer screen dialog reflects 6-band hardware equalizer instead of external DSP', () {
      final eqScreen = File('lib/screens/equalizer_screen.dart').readAsStringSync();
      expect(eqScreen, isNot(contains('AutoEq')));
      expect(eqScreen, isNot(contains('JamesDSP')));
      expect(eqScreen, contains('Sine Hardware Equalizer'));
      expect(eqScreen, contains('Pure hardware AudioTrack filtering'));
    });
  });

  group('v1.3.7 Sound Shaping Sheet Cleansing (No Nightcore/Slowed)', () {
    test('Sound shaping sheet does NOT contain Nightcore or Slowed options', () {
      final sheetCode = File('lib/screens/sound_shaping_sheet.dart').readAsStringSync();
      expect(sheetCode, isNot(contains('Nightcore')));
      expect(sheetCode, isNot(contains('Slowed')));
      expect(sheetCode, isNot(contains('1-Tap Acoustic Presets')));
    });

    test('PlayerProvider acoustic preset neutral behavior', () {
      final providerCode = File('lib/providers/player_provider.dart').readAsStringSync();
      expect(providerCode, isNot(contains("preset == 'nightcore'")));
      expect(providerCode, isNot(contains("preset == 'slowed'")));
      expect(providerCode, isNot(contains("slowedReverb")));
    });
  });

  group('v1.3.7 Native AudioTrack Playback Parameters & Anti-Distortion Suite', () {
    test('Vendored just_audio AudioPlayer.java enables native AudioTrack playback parameters', () {
      final javaFile = File('packages/just_audio/android/src/main/java/com/ryanheise/just_audio/AudioPlayer.java');
      expect(javaFile.existsSync(), isTrue, reason: 'just_audio must be vendored in packages/just_audio');
      final javaCode = javaFile.readAsStringSync();
      expect(javaCode, contains('defaultRenderersFactory.setEnableAudioTrackPlaybackParams(true)'));
    });

    test('AudioHandler schedules DSP sync and protects EQ during speed or pitch shifts', () {
      final handlerCode = File('lib/services/audio_handler.dart').readAsStringSync();

      // Ensure setSpeed and setPitch trigger DSP sync to reassert band gains
      expect(handlerCode, contains('await _scheduleDspSync(forceRebind: false);'));

      // Ensure headroom is gentle (0.94) to avoid dropping volume
      expect(handlerCode, contains('final double pitchSpeedHeadroom = isPitchOrSpeedShifted ? 0.94 : 1.0;'));

      // Ensure LoudnessEnhancer and hardware Equalizer remain enabled when shifted
      expect(handlerCode, contains('targetGain = isPitchOrSpeedShifted ? (_bassBoost * 2.5) : (_bassBoost * 3.5);'));
    });
  });

  group('v1.3.7 Smooth UI Animations Suite', () {
    testWidgets('BouncyTap scales smoothly on press and springs back on release', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BouncyTap(
                onTap: () => tapped = true,
                child: const Text('Bounce Button'),
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.text('Bounce Button');
      expect(buttonFinder, findsOneWidget);

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // Verify Transform.scale is present
      final scaleFinder = find.ancestor(of: buttonFinder, matching: find.byType(Transform));
      expect(scaleFinder, findsOneWidget);

      // Release
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}
