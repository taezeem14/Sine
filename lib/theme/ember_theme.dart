import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

typedef SineColors = EmberColors;
typedef SineTheme = EmberTheme;

enum SineThemePreset {
  blue('Electric Blue', Color(0xFF2979FF)),
  green('Emerald Green', Color(0xFF1DB954)),
  orange('Sunset Orange', Color(0xFFFF6D00)),
  red('Crimson Red', Color(0xFFFF1744)),
  yellow('Electric Yellow', Color(0xFFFFD600)),
  purple('Neon Purple', Color(0xFFD500F9)),
  monochrome('Monochromatic', Color(0xFFE0E0E0)),
  custom('Custom Accent', Color(0xFF2979FF));

  final String label;
  final Color accentColor;
  const SineThemePreset(this.label, this.accentColor);

  static SineThemePreset fromKey(String? key) {
    switch (key?.toLowerCase().trim()) {
      case 'green':
        return SineThemePreset.green;
      case 'orange':
        return SineThemePreset.orange;
      case 'red':
        return SineThemePreset.red;
      case 'yellow':
        return SineThemePreset.yellow;
      case 'purple':
        return SineThemePreset.purple;
      case 'monochrome':
      case 'monochromatic':
        return SineThemePreset.monochrome;
      case 'custom':
        return SineThemePreset.custom;
      case 'blue':
      default:
        return SineThemePreset.blue;
    }
  }
}

class EmberColors {
  EmberColors._();

  static Color _currentPrimary = const Color(0xFF2979FF);

  static Color get currentPrimary => _currentPrimary;

  static void applyThemeColor(Color color) {
    _currentPrimary = color;
  }

  static void applyThemePreset(SineThemePreset preset) {
    _currentPrimary = preset.accentColor;
  }

  // Surface & Foundations (Pitch Black & Obsidian Surfaces)
  static const Color obsidianBase = Color(0xFF121212);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceContainerLowest = Color(0xFF000000);
  static const Color surfaceContainerLow = Color(0xFF181818);
  static const Color surfaceContainer = Color(0xFF242424);
  static const Color surfaceContainerHigh = Color(0xFF282828);
  static const Color surfaceContainerHighest = Color(0xFF333333);

  // Dynamic Signature Accent Theme Shade
  static Color get primaryBlue => _currentPrimary;
  static Color get primaryBlueHi => _currentPrimary;
  static Color get secondaryCyan => _currentPrimary;
  static Color get secondaryAzure => _currentPrimary;
  static Color get tertiaryBlue => _currentPrimary;

  // Convenience aliases for Electric Blue Sine theme
  static Color get electricBlue => _currentPrimary;
  static Color get electricBlueHi => _currentPrimary;
  static const Color charcoalCard = surfaceContainerLow;
  static const Color surfaceDark = surfaceContainer;
  static const Color glassBorder = outlineVariant;
  static const Color youtubeRed = Color(0xFFFF0000);

  // Backward-compatible aliases for existing widgets — all unified to ONE shade of blue
  static Color get primaryAmber => _currentPrimary;
  static Color get primaryAmberHi => _currentPrimary;
  static Color get secondaryHoney => _currentPrimary;
  static Color get secondaryOrange => _currentPrimary;
  static Color get tertiaryGold => _currentPrimary;

  // Text & Content Hierarchy (Pure Contrast)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF9E9E9E);

  // System & Borders
  static const Color outline = Color(0xFF3E3E3E);
  static const Color outlineVariant = Color(0xFF282828);
  static const Color borderSubtle = Color(0xFF282828);
  static const Color error = Color(0xFFE05252);
  static Color get pulseBlue => _currentPrimary;
}

class EmberTheme {
  EmberTheme._();

  static ThemeData get darkTheme => buildTheme(accentColor: EmberColors.currentPrimary, useGoogleFonts: true);

  static ThemeData buildTheme({Color? accentColor, bool useGoogleFonts = true}) {
    final activeAccent = accentColor ?? EmberColors.currentPrimary;
    TextTheme mergedTextTheme;
    if (useGoogleFonts) {
      try {
        final baseTextTheme = Typography.material2021().white;

        final headlineFont = GoogleFonts.soraTextTheme(baseTextTheme);
        final bodyFont = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme);
        final labelFont = GoogleFonts.spaceGroteskTextTheme(baseTextTheme);

        mergedTextTheme = bodyFont.copyWith(
          displayLarge: headlineFont.displayLarge?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.bold),
          displayMedium: headlineFont.displayMedium?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.bold),
          displaySmall: headlineFont.displaySmall?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.bold),
          headlineLarge: headlineFont.headlineLarge?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.w700),
          headlineMedium: headlineFont.headlineMedium?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.w700),
          headlineSmall: headlineFont.headlineSmall?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.w600),
          titleLarge: headlineFont.titleLarge?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.w600),
          titleMedium: headlineFont.titleMedium?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.w500),
          titleSmall: headlineFont.titleSmall?.copyWith(color: EmberColors.textSecondary, fontWeight: FontWeight.w500),
          bodyLarge: bodyFont.bodyLarge?.copyWith(color: EmberColors.textPrimary),
          bodyMedium: bodyFont.bodyMedium?.copyWith(color: EmberColors.textSecondary),
          bodySmall: bodyFont.bodySmall?.copyWith(color: EmberColors.textMuted),
          labelLarge: labelFont.labelLarge?.copyWith(color: EmberColors.textPrimary, fontWeight: FontWeight.w600),
          labelMedium: labelFont.labelMedium?.copyWith(color: EmberColors.textSecondary),
          labelSmall: labelFont.labelSmall?.copyWith(color: EmberColors.textMuted, letterSpacing: 0.5),
        );
      } catch (_) {
        mergedTextTheme = const TextTheme();
      }
    } else {
      mergedTextTheme = const TextTheme();
    }

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: EmberColors.obsidianBase,
      canvasColor: EmberColors.surface,
      cardColor: EmberColors.surfaceContainerLow,
      dividerColor: EmberColors.outlineVariant,
      colorScheme: ColorScheme.dark(
        surface: EmberColors.surface,
        primary: activeAccent,
        secondary: activeAccent,
        tertiary: activeAccent,
        error: EmberColors.error,
        onSurface: EmberColors.textPrimary,
        onPrimary: EmberColors.obsidianBase,
      ),
      textTheme: mergedTextTheme,
      iconTheme: const IconThemeData(color: EmberColors.textSecondary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: mergedTextTheme.titleMedium?.copyWith(
          color: EmberColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: EmberColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activeAccent,
          foregroundColor: EmberColors.obsidianBase,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
