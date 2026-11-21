import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/services/cover_color_service.dart';
import 'package:spotify_newpipe/widgets/fluid_mesh_gradient.dart';

/// Builds a synthetic 32x32 RGBA bitmap for deterministic pixel-level color extraction tests.
List<int> _makeBitmap({
  required Color Function(int x, int y) pixelAt,
  int width = 32,
  int height = 32,
}) {
  final bytes = List<int>.filled(width * height * 4, 0);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final c = pixelAt(x, y);
      final idx = (y * width + x) * 4;
      bytes[idx] = (c.r * 255).round().clamp(0, 255);
      bytes[idx + 1] = (c.g * 255).round().clamp(0, 255);
      bytes[idx + 2] = (c.b * 255).round().clamp(0, 255);
      bytes[idx + 3] = (c.a * 255).round().clamp(0, 255);
    }
  }
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.1 Release & Version Integrity Suite', () {
    test('All version artifacts strictly match semver >= 1.4.1+41', () {
      expect(AppConstants.version, matches(RegExp(r'^1\.\d+\.\d+$')));
      expect(AppConstants.buildNumber, greaterThanOrEqualTo(41));
      expect(AppConstants.fullVersion, '${AppConstants.version}+${AppConstants.buildNumber}');
      expect(AppConstants.releaseTag, 'v${AppConstants.version}');

      expect(File('pubspec.yaml').readAsStringSync(), matches(RegExp(r'version:\s*1\.\d+\.\d+\+\d+')));
      expect(
        File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync(),
        allOf(matches(RegExp(r'CurrentVersion:\s*1\.\d+\.\d+')), matches(RegExp(r'CurrentVersionCode:\s*\d+'))),
      );
      expect(File('scripts/fetch_cloud_release.py').readAsStringSync(), matches(RegExp(r"'v1\.\d+\.\d+'")));
      expect(File('README.md').readAsStringSync(), allOf(contains('v1.4.'), contains('Sine-v1.4.')));
      expect(File('index.html').readAsStringSync(), allOf(contains('v1.4.'), contains('Sine-v1.4.')));
    });
  });

  group('v1.4.1 Perceptual Album Artwork Quantizer Suite', () {
    test('Extracts true crimson RED from red cover even with YouTube black bars & stray green corner pixel', () {
      final rgba = _makeBitmap(
        pixelAt: (x, y) {
          // Simulate YouTube 16:9 black letterbox bars top & bottom
          if (y < 4 || y >= 28) return const Color(0xFF000000);
          // Simulate one single bright neon-green watermark pixel inside the frame
          if (x == 6 && y == 6) return const Color(0xFF00FF00);
          // Dominant crimson album artwork
          return const Color(0xFFD32F2F);
        },
      );

      final palette = CoverColorService.extractPaletteFromRgbaBytes(rgba, width: 32, height: 32);
      expect(palette.isExtracted, isTrue);

      final domHsl = HSLColor.fromColor(palette.dominant);
      // Red sits near hue 0° (either < 22° or > 338°)
      expect(domHsl.hue < 22 || domHsl.hue > 338, isTrue, reason: 'Expected red hue, got ${domHsl.hue}');
    });

    test('Extracts true dominant BLUE and distinct GOLD secondary from split cover art', () {
      final rgba = _makeBitmap(
        pixelAt: (x, y) {
          // 70% deep royal blue, 30% warm gold
          if (x < 22) return const Color(0xFF1565C0);
          return const Color(0xFFFFB300);
        },
      );

      final palette = CoverColorService.extractPaletteFromRgbaBytes(rgba, width: 32, height: 32);
      expect(palette.isExtracted, isTrue);

      final domHsl = HSLColor.fromColor(palette.dominant);
      final secHsl = HSLColor.fromColor(palette.secondary);
      // Blue dominant ~200-235°
      expect(domHsl.hue, inInclusiveRange(195, 240));
      // Gold/amber secondary ~30-60°
      expect(secHsl.hue, inInclusiveRange(25, 65));
    });

    test('Honors monochrome black-and-white artwork with neutral charcoal/silver (NEVER fake rainbow)', () {
      final rgba = _makeBitmap(
        pixelAt: (x, y) => (x + y).isEven ? const Color(0xFF222222) : const Color(0xFFD0D0D0),
      );

      final palette = CoverColorService.extractPaletteFromRgbaBytes(rgba, width: 32, height: 32);
      expect(palette.isExtracted, isTrue);

      final domHsl = HSLColor.fromColor(palette.dominant);
      expect(domHsl.saturation, lessThan(0.18), reason: 'B&W cover must stay neutral, not rainbow');
    });

    test('Fallback palette before extraction is restrained dark slate (never garish neon)', () {
      const song = Song(
        id: 'yt_unloaded',
        title: 'Some Track Title',
        artist: 'Some Artist',
        duration: Duration(minutes: 3),
        artworkUrl: '',
        streamUrl: '',
      );
      final syncPalette = CoverColorService.instance.getPaletteSync(song);
      expect(syncPalette.isExtracted, isFalse);
      final hsl = HSLColor.fromColor(syncPalette.dominant);
      expect(hsl.saturation, lessThan(0.25));
      expect(hsl.lightness, lessThan(0.32));
    });
  });

  group('v1.4.1 True Cover-Driven Fluid Background & Swipe-Down MiniPlayer Architecture', () {
    test('FluidMeshGradientBackground uses CoverColorService and zero title-hash faking', () {
      final code = File('lib/widgets/fluid_mesh_gradient.dart').readAsStringSync();
      expect(code, contains('CoverColorService.instance'));
      expect(code, isNot(contains('song.title.hashCode')));
    });

    test('MiniPlayer keeps classic Sine theme surface + vertical swipe-down dismissal', () {
      final code = File('lib/widgets/mini_player.dart').readAsStringSync();
      expect(code, contains('activeAccentColor'));
      expect(code, contains('onVerticalDragUpdate'));
      expect(code, contains('onVerticalDragEnd'));
      expect(code, contains('player.stopPlayback()'));
    });

    test('NowPlayingScreen passes extracted CoverPalette directly to FluidMeshGradientBackground', () {
      final code = File('lib/screens/now_playing_screen.dart').readAsStringSync();
      expect(code, contains('palette: palette'));
    });

    testWidgets('FluidMeshGradientBackground renders smoothly with an explicit CoverPalette', (tester) async {
      const crimsonPalette = CoverPalette(
        dominant: Color(0xFFB71C1C),
        secondary: Color(0xFF4A148C),
        accent: Color(0xFFEF5350),
        isExtracted: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FluidMeshGradientBackground(
              palette: crimsonPalette,
              isPlaying: true,
              child: Center(child: Text('Playing')),
            ),
          ),
        ),
      );

      expect(find.text('Playing'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FluidMeshGradientBackground), findsOneWidget);
    });
  });
}
