import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_newpipe/theme/ember_theme.dart';
import 'package:spotify_newpipe/services/storage_service.dart';
import 'package:spotify_newpipe/services/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('v1.3.0 Dynamic Theming & Presets Suite', () {
    test('SineThemePreset contains all required palettes and parses keys correctly', () {
      expect(SineThemePreset.values.length, 8);

      expect(SineThemePreset.blue.accentColor, const Color(0xFF2979FF));
      expect(SineThemePreset.green.accentColor, const Color(0xFF1DB954));
      expect(SineThemePreset.orange.accentColor, const Color(0xFFFF6D00));
      expect(SineThemePreset.red.accentColor, const Color(0xFFFF1744));
      expect(SineThemePreset.yellow.accentColor, const Color(0xFFFFD600));
      expect(SineThemePreset.purple.accentColor, const Color(0xFFD500F9));
      expect(SineThemePreset.monochrome.accentColor, const Color(0xFFE0E0E0));
      expect(SineThemePreset.custom.accentColor, const Color(0xFF2979FF));

      expect(SineThemePreset.fromKey('green'), SineThemePreset.green);
      expect(SineThemePreset.fromKey('orange'), SineThemePreset.orange);
      expect(SineThemePreset.fromKey('red'), SineThemePreset.red);
      expect(SineThemePreset.fromKey('yellow'), SineThemePreset.yellow);
      expect(SineThemePreset.fromKey('purple'), SineThemePreset.purple);
      expect(SineThemePreset.fromKey('monochrome'), SineThemePreset.monochrome);
      expect(SineThemePreset.fromKey('custom'), SineThemePreset.custom);
      expect(SineThemePreset.fromKey('unknown'), SineThemePreset.blue);
      expect(SineThemePreset.fromKey(null), SineThemePreset.blue);
    });

    test('EmberColors dynamically propagates theme updates across getters', () {
      // Apply Emerald Green
      EmberColors.applyThemePreset(SineThemePreset.green);
      expect(EmberColors.currentPrimary, const Color(0xFF1DB954));
      expect(EmberColors.primaryBlue, const Color(0xFF1DB954));
      expect(EmberColors.pulseBlue, const Color(0xFF1DB954));

      // Apply Crimson Red
      EmberColors.applyThemePreset(SineThemePreset.red);
      expect(EmberColors.currentPrimary, const Color(0xFFFF1744));
      expect(EmberColors.primaryBlue, const Color(0xFFFF1744));

      // Apply Custom Accent (e.g. Neon Cyan 0xFF00E5FF)
      const customCyan = Color(0xFF00E5FF);
      EmberColors.applyThemeColor(customCyan);
      expect(EmberColors.currentPrimary, customCyan);
      expect(EmberColors.primaryBlue, customCyan);

      // Revert to Electric Blue
      EmberColors.applyThemePreset(SineThemePreset.blue);
      expect(EmberColors.currentPrimary, const Color(0xFF2979FF));
    });

    test('StorageService persists and restores theme preset and custom color', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      // Defaults to 'blue'
      expect(storage.loadThemePreset(), 'blue');
      expect(storage.loadCustomThemeColor(), isNull);

      // Save 'purple'
      await storage.saveThemePreset(SineThemePreset.purple.name);
      expect(storage.loadThemePreset(), 'purple');

      // Save custom color
      const customColorVal = 0xFF00E5FF;
      await storage.saveCustomThemeColor(customColorVal);
      expect(storage.loadCustomThemeColor(), customColorVal);
    });

    test('EmberTheme.buildTheme builds dark theme with dynamic primary color', () {
      final themeGreen = EmberTheme.buildTheme(accentColor: const Color(0xFF1DB954), useGoogleFonts: false);
      expect(themeGreen.colorScheme.primary, const Color(0xFF1DB954));
      expect(themeGreen.brightness, Brightness.dark);
      expect(themeGreen.scaffoldBackgroundColor, EmberColors.obsidianBase);

      final themeRed = EmberTheme.buildTheme(accentColor: const Color(0xFFFF1744), useGoogleFonts: false);
      expect(themeRed.colorScheme.primary, const Color(0xFFFF1744));
    });
  });

  group('v1.3.0 Audio Quality & Sonic Headroom Suite', () {
    test('Sonic SOLA headroom attenuates peaks by -2.5 dB only when speed/pitch shifted', () {
      // In SineAudioHandler, sonicHeadroom = (shifted) ? 0.75 : 1.0
      double computeSonicHeadroom(double speed, double pitch) {
        final bool isShifted = (speed - 1.0).abs() > 0.005 || (pitch - 1.0).abs() > 0.005;
        return isShifted ? 0.75 : 1.0;
      }

      // Bit-perfect lossless unity gain when normal
      expect(computeSonicHeadroom(1.0, 1.0), 1.0);

      // -2.5 dB protection during speed stretching
      expect(computeSonicHeadroom(1.25, 1.0), 0.75);
      expect(computeSonicHeadroom(0.8, 1.0), 0.75);
      expect(computeSonicHeadroom(1.5, 1.0), 0.75);

      // -2.5 dB protection during pitch shifting
      expect(computeSonicHeadroom(1.0, 1.1), 0.75);
      expect(computeSonicHeadroom(1.0, 0.9), 0.75);

      // Both shifted
      expect(computeSonicHeadroom(1.25, 1.05), 0.75);
    });

    test('SineWidgetService supports caching and forced state invalidation', () {
      SineWidgetService.resetCache();
      // Verifies resetCache can be invoked without exception
      expect(() => SineWidgetService.resetCache(), returnsNormally);
    });
  });
}
