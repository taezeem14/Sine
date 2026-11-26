import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/theme/ember_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.4 Release & Version Integrity Suite', () {
    test('All version artifacts strictly match v1.4.4+44', () {
      expect(AppConstants.version, '1.4.4');
      expect(AppConstants.buildNumber, 44);
      expect(AppConstants.fullVersion, '1.4.4+44');
      expect(AppConstants.releaseTag, 'v1.4.4');

      expect(File('pubspec.yaml').readAsStringSync(), contains('version: 1.4.4+44'));
      expect(
        File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync(),
        allOf(contains('CurrentVersion: 1.4.4'), contains('CurrentVersionCode: 44')),
      );
      expect(File('scripts/fetch_cloud_release.py').readAsStringSync(), contains("'v1.4.4'"));
      expect(File('README.md').readAsStringSync(), allOf(contains('v1.4.4'), contains('Sine-v1.4.4.apk')));
      expect(File('index.html').readAsStringSync(), allOf(contains('v1.4.4'), contains('Sine-v1.4.4.apk')));
    });
  });

  group('v1.4.4 Spotify Theme & Palette Suite', () {
    test('EmberColors defines authentic Spotify palette constants', () {
      expect(EmberColors.spotifyGreen, const Color(0xFF1DB954));
      expect(EmberColors.spotifyBlack, const Color(0xFF121212));
      expect(EmberColors.spotifyCard, const Color(0xFF181818));
      expect(EmberColors.spotifyElevated, const Color(0xFF242424));
    });

    test('SineThemePreset green is labeled Spotify Green and maps via spotify key', () {
      expect(SineThemePreset.green.label, 'Spotify Green');
      expect(SineThemePreset.green.accentColor, const Color(0xFF1DB954));
      expect(SineThemePreset.fromKey('spotify'), SineThemePreset.green);
      expect(SineThemePreset.fromKey('green'), SineThemePreset.green);
      expect(SineThemePreset.values.length, 8);
    });
  });

  group('v1.4.4 Spotify Home Tab Architecture Suite', () {
    test('Home tab contains Spotify header, quick access grid, and 140x140 cards', () {
      final code = File('lib/screens/tabs/pulsepipe_home_tab.dart').readAsStringSync();
      expect(code, contains('_buildQuickAccessCard'));
      expect(code, contains('0xFF450AF5'));
      expect(code, contains('0xFF8E8EE5'));
      expect(code, contains('_buildTrackCarouselCard'));
      expect(code, contains('width: 140'));
      expect(code, contains('height: 140'));
      expect(code, contains('Icons.play_arrow_rounded'));
    });
  });

  group('v1.4.4 Spotify Search & Library Aesthetic Suite', () {
    test('Search tab contains Spotify placeholder and top result card', () {
      final searchCode = File('lib/screens/tabs/pulsepipe_search_tab.dart').readAsStringSync();
      expect(searchCode, contains('What do you want to listen to?'));
      expect(searchCode, contains('_SpotifyTopResultCard'));
    });

    test('Library tab contains Spotify filter pills and Liked Songs gradient', () {
      final libraryCode = File('lib/screens/tabs/pulsepipe_library_tab.dart').readAsStringSync();
      expect(libraryCode, contains('Theme.of(context).colorScheme.primary'));
      expect(libraryCode, contains('Color(0xFF450AF5)'));
      expect(libraryCode, contains('Color(0xFF8E8EE5)'));
    });
  });

  group('v1.4.4 Spotify Player & Controls Suite', () {
    test('Now Playing screen contains Spotify transport controls, active dots, and heart', () {
      final npCode = File('lib/screens/now_playing_screen.dart').readAsStringSync();
      expect(npCode, contains('_TransportControlsSection'));
      expect(npCode, contains('_SpotifyHeartButton'));
      expect(npCode, contains('if (isShuffle)'));
      expect(npCode, contains("if (repeatMode != 'off')"));
      expect(npCode, contains('Theme.of(context).colorScheme.primary'));
    });

    test('MiniPlayer faithfully preserves rotating VinylDisc while adopting Spotify accents', () {
      final miniCode = File('lib/widgets/mini_player.dart').readAsStringSync();
      expect(miniCode, contains('VinylDisc('));
      expect(miniCode, contains('LinearProgressIndicator('));
      expect(miniCode, contains('activeAccentColor'));
    });
  });
}
