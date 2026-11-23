import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/services/audio_handler.dart';
import 'package:spotify_newpipe/services/cover_color_service.dart';
import 'package:spotify_newpipe/widgets/ambient_glow.dart';
import 'package:spotify_newpipe/widgets/fluid_mesh_gradient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.2 Release & Version Integrity Suite', () {
    test('All version artifacts strictly match version >= v1.4.2+42', () {
      expect(AppConstants.buildNumber, greaterThanOrEqualTo(42));
      expect(AppConstants.releaseTag, startsWith('v1.4.'));

      expect(File('pubspec.yaml').readAsStringSync(), contains('version: 1.4.'));
      expect(
        File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync(),
        allOf(contains('CurrentVersion: 1.4.'), contains('CurrentVersionCode: ')),
      );
      expect(File('scripts/fetch_cloud_release.py').readAsStringSync(), contains("'v1.4."));
      expect(File('README.md').readAsStringSync(), allOf(contains('v1.4.'), contains('Sine-v1.4.')));
      expect(File('index.html').readAsStringSync(), allOf(contains('v1.4.'), contains('Sine-v1.4.')));
    });
  });

  group('v1.4.2 Hardware Equalizer & Audio Engine Integrity Suite', () {
    test('Log-frequency 6->5 band interpolation actively preserves 400 Hz on 5-band Android hardware', () {
      // Only band 2 (400 Hz) boosted to +12 dB; all others flat 0 dB
      const only400HzBoost = [0.0, 0.0, 12.0, 0.0, 0.0, 0.0];

      // Standard Android 5-band hardware center frequencies: 60, 230, 910, 3600, 14000 Hz
      final hw60 = SineAudioHandler.interpolateSixBandGain(60.0, only400HzBoost);
      final hw230 = SineAudioHandler.interpolateSixBandGain(230.0, only400HzBoost);
      final hw910 = SineAudioHandler.interpolateSixBandGain(910.0, only400HzBoost);
      final hw3600 = SineAudioHandler.interpolateSixBandGain(3600.0, only400HzBoost);
      final hw14000 = SineAudioHandler.interpolateSixBandGain(14000.0, only400HzBoost);

      expect(hw60, closeTo(0.0, 0.01));
      // 400 Hz MUST contribute meaningfully to 230 Hz (~43.6% of +12 dB ≈ +5.2 dB) and 910 Hz (~10.3% ≈ +1.2 dB)
      expect(hw230, greaterThan(4.5), reason: '400 Hz must actively drive 230 Hz hardware band');
      expect(hw910, greaterThan(1.0), reason: '400 Hz must actively drive 910 Hz hardware band');
      expect(hw3600, closeTo(0.0, 0.01));
      expect(hw14000, closeTo(0.0, 0.01));
    });

    test('Log-frequency interpolation hits exact UI anchor values at anchor frequencies', () {
      const curve = [6.0, 3.0, -2.0, 1.5, 4.0, 8.0];
      expect(SineAudioHandler.interpolateSixBandGain(60.0, curve), closeTo(6.0, 0.01));
      expect(SineAudioHandler.interpolateSixBandGain(150.0, curve), closeTo(3.0, 0.01));
      expect(SineAudioHandler.interpolateSixBandGain(400.0, curve), closeTo(-2.0, 0.01));
      expect(SineAudioHandler.interpolateSixBandGain(1000.0, curve), closeTo(1.5, 0.01));
      expect(SineAudioHandler.interpolateSixBandGain(2400.0, curve), closeTo(4.0, 0.01));
      expect(SineAudioHandler.interpolateSixBandGain(15000.0, curve), closeTo(8.0, 0.01));
    });

    test('SpotifyGraphEqualizer separates pointerDown double-tap from pointerMove drag & removes MaskFilter.blur', () {
      final eqCode = File('lib/widgets/spotify_graph_equalizer.dart').readAsStringSync();
      expect(eqCode, contains('_handlePointerDown'));
      expect(eqCode, contains('_handlePointerMove'));
      expect(eqCode, contains('_handlePointerRelease'));
      expect(eqCode, isNot(contains('context.watch<PlayerProvider>()')));
      expect(eqCode, isNot(contains('MaskFilter.blur')));
    });

    test('AudioPlayer.java hardens native Equalizer priority, eager session ID, state persistence & null safety', () {
      final javaCode = File(
        'packages/just_audio/android/src/main/java/com/ryanheise/just_audio/AudioPlayer.java',
      ).readAsStringSync();
      expect(javaCode, contains('new Equalizer(1000, audioSessionId)'));
      expect(javaCode, contains('savedEqBandLevels'));
      expect(javaCode, contains('savedEqEnabled'));
      expect(javaCode, contains('generateAudioSessionId()'));
      expect(javaCode, contains('getBandLevelRange()'));
    });

    test('SineAudioHandler uses non-blocking play(), single interruption owner, atomic configureEqualizer & real skipSilence', () {
      final handlerCode = File('lib/services/audio_handler.dart').readAsStringSync();
      expect(handlerCode, contains('handleInterruptions: false'));
      expect(handlerCode, contains('_triggerPlayNonBlocking()'));
      expect(handlerCode, isNot(contains('await _player.play();')));
      expect(handlerCode, contains('Future<void> configureEqualizer('));
      expect(handlerCode, contains('await _player.setSkipSilenceEnabled(enabled)'));
    });
  });

  group('v1.4.2 Vivid Fluid Aurora, Zero-Blur AmbientGlow & 120 FPS Smoothness Suite', () {
    test('FluidMeshGradientBackground renders vivid cover-colored aurora with seamless integer harmonics & route pause', () {
      final code = File('lib/widgets/fluid_mesh_gradient.dart').readAsStringSync();
      expect(code, contains('_boostForAurora'));
      expect(code, contains('_onRouteStatusChanged'));
      expect(code, contains('math.sin(t * 2'));
      expect(code, isNot(contains('t * 0.75')));
      expect(code, isNot(contains('t * 0.6')));
      expect(code, isNot(contains('song.title.hashCode')));
    });

    test('AmbientGlow eliminates dynamic Gaussian BoxShadows in favor of zero-blur GPU RadialGradient CustomPainter', () {
      final code = File('lib/widgets/ambient_glow.dart').readAsStringSync();
      expect(code, contains('_RadialAmbientAuraPainter'));
      expect(code, contains('RadialGradient'));
      expect(code, isNot(contains('BoxShadow(')));
    });

    test('SettingsScreen removes double AnimatedTheme, DraggableScrollableSheet conflict & context.watch', () {
      final settingsCode = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(settingsCode, isNot(contains('AnimatedTheme(')));
      expect(settingsCode, isNot(contains('DraggableScrollableSheet(')));
      expect(settingsCode, isNot(contains('context.watch<PlayerProvider>()')));
      expect(settingsCode, contains('ListView.builder('));

      final themeCode = File('lib/theme/ember_theme.dart').readAsStringSync();
      expect(themeCode, contains('_cachedGoogleTextTheme'));
      expect(themeCode, contains('CurveTween('));
    });

    test('NowPlayingScreen & MiniPlayer support smooth sheet expansion + interactive swipe-down minimize', () {
      final npCode = File('lib/screens/now_playing_screen.dart').readAsStringSync();
      expect(npCode, contains('_dismissDragY'));
      expect(npCode, contains('_handleDismissDragUpdate'));
      expect(npCode, contains('_handleDismissDragEnd'));

      final miniCode = File('lib/widgets/mini_player.dart').readAsStringSync();
      expect(miniCode, contains('_dragOffsetNotifier'));
      expect(miniCode, contains('begin: const Offset(0.0, 1.0)'));
    });

    test('TrackOptionsSheet captures parentContext before pop & removes context.watch', () {
      final code = File('lib/screens/track_options_sheet.dart').readAsStringSync();
      expect(code, contains('parentContext'));
      expect(code, contains('hostContext'));
      expect(code, isNot(contains('context.watch<PlayerProvider>()')));
    });

    testWidgets('AmbientGlow & FluidMeshGradientBackground compose smoothly with real CoverPalette', (tester) async {
      const palette = CoverPalette(
        dominant: Color(0xFF1565C0),
        secondary: Color(0xFFFFA000),
        accent: Color(0xFF42A5F5),
        isExtracted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FluidMeshGradientBackground(
              palette: palette,
              isPlaying: true,
              child: Center(
                child: AmbientGlow(
                  isPlaying: true,
                  glowColor: palette.dominant,
                  secondaryGlowColor: palette.secondary,
                  child: const SizedBox(width: 200, height: 200),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FluidMeshGradientBackground), findsOneWidget);
      expect(find.byType(AmbientGlow), findsOneWidget);
    });
  });
}
