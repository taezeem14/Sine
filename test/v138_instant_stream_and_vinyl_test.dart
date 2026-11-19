import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/services/cover_color_service.dart';
import 'package:spotify_newpipe/widgets/ambient_glow.dart';
import 'package:spotify_newpipe/widgets/vinyl_disc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('v1.3.8 Release & Version Integrity Suite', () {
    test('AppConstants strictly matches v1.3.8 release specifications', () {
      expect(AppConstants.appName, 'Sine');
      expect(AppConstants.version, '1.3.8');
      expect(AppConstants.buildNumber, 38);
      expect(AppConstants.fullVersion, '1.3.8+38');
      expect(AppConstants.releaseTag, 'v1.3.8');
    });

    test('pubspec.yaml specifies version 1.3.8+38 and just_audio dependency override', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: 1.3.8+38'));
      expect(pubspec, contains('dependency_overrides:'));
      expect(pubspec, contains('just_audio:'));
      expect(pubspec, contains('path: packages/just_audio'));
    });

    test('F-Droid metadata and release script match v1.3.8', () {
      final yml = File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync();
      expect(yml, contains('CurrentVersion: 1.3.8'));
      expect(yml, contains('CurrentVersionCode: 38'));

      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, contains("'v1.3.8'"));
    });

    test('README.md and index.html reference v1.3.8 and Sine-v1.3.8.apk', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, contains('v1.3.8'));
      expect(readme, contains('Sine-v1.3.8.apk'));

      final html = File('index.html').readAsStringSync();
      expect(html, contains('v1.3.8'));
      expect(html, contains('Sine-v1.3.8.apk'));
    });
  });

  group('v1.3.8 Cover Color Extraction Service Suite', () {
    test('CoverColorService generates instant synchronous harmonic palette from Song metadata', () {
      final song = Song(
        id: 'yt_abc123',
        title: 'Starboy',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 50),
        streamUrl: 'https://youtube.com/watch?v=abc123',
        artworkUrl: 'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
      );

      final palette = CoverColorService.instance.getPaletteSync(song);
      expect(palette, isNotNull);
      expect(palette.dominant, isA<Color>());
      expect(palette.secondary, isA<Color>());
      expect(palette.accent, isA<Color>());
      // Distinct harmonic separation
      expect(palette.dominant != palette.secondary, isTrue);
    });

    test('CoverColorService handles null song safely with fallback palette', () {
      final palette = CoverColorService.instance.getPaletteSync(null);
      expect(palette, isNotNull);
      expect(palette.dominant, isA<Color>());
    });

    test('CoverColorService produces deterministic palette for identical song titles', () {
      final song1 = Song(
        id: '1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 20),
        streamUrl: 'test',
        artworkUrl: 'art',
      );
      final song2 = Song(
        id: '2',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        duration: const Duration(minutes: 3, seconds: 20),
        streamUrl: 'test2',
        artworkUrl: 'art',
      );

      final pal1 = CoverColorService.instance.getPaletteSync(song1);
      final pal2 = CoverColorService.instance.getPaletteSync(song2);
      expect(pal1.dominant, equals(pal2.dominant));
      expect(pal1.secondary, equals(pal2.secondary));
    });
  });

  group('v1.3.8 Ambient Light & Dynamic Vinyl Disc Widgets Suite', () {
    testWidgets('AmbientGlow renders with dynamic cover colors and continuous halo', (tester) async {
      const testColor = Color(0xFFFF5722);
      const testSecondary = Color(0xFFFF9800);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AmbientGlow(
                isPlaying: true,
                glowColor: testColor,
                secondaryGlowColor: testSecondary,
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AmbientGlow), findsOneWidget);
      // Continuous animation ticks smoothly
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AmbientGlow), findsOneWidget);
    });

    testWidgets('VinylDisc renders with cover-matched labelColor and accentColor', (tester) async {
      const testLabelColor = Color(0xFFE91E63);
      const testAccentColor = Color(0xFF9C27B0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VinylDisc(
                size: 240,
                isPlaying: true,
                labelColor: testLabelColor,
                accentColor: testAccentColor,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VinylDisc), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VinylDisc), findsOneWidget);
    });
  });

  group('v1.3.8 YouTube Stream Latency & Engine Architecture Suite', () {
    test('youtube_importer_service.dart prioritizes androidSdkless profile to eliminate 2-3s delay', () {
      final code = File('lib/services/youtube_importer_service.dart').readAsStringSync();
      // androidSdkless must be first to avoid PO token failures and 4-second timeout
      expect(code, contains('YoutubeApiClient.androidSdkless'));
      final sdklessIdx = code.indexOf('YoutubeApiClient.androidSdkless');
      final vrIdx = code.indexOf('YoutubeApiClient.androidVr');
      expect(sdklessIdx, lessThan(vrIdx));
    });

    test('youtube_importer_service.dart prioritizes pure audio streams over bulky muxed video', () {
      final code = File('lib/services/youtube_importer_service.dart').readAsStringSync();
      // AAC (mp4Audio) and WebM Opus (webmAudio) must be prioritized
      expect(code, contains('mp4Audio.withHighestBitrate()'));
      expect(code, contains('webmAudio.withHighestBitrate()'));
    });

    test('youtube_importer_service.dart unthrottles candidates concurrently via Future.wait', () {
      final code = File('lib/services/youtube_importer_service.dart').readAsStringSync();
      expect(code, contains('Future.wait'));
      expect(code, contains('YouTubeCipherService.unthrottleUrl'));
    });

    test('audio_handler.dart passes initialPosition directly into setUrl to eliminate secondary seek delay', () {
      final code = File('lib/services/audio_handler.dart').readAsStringSync();
      expect(code, contains('initialPosition: initPos'));
    });
  });
}
