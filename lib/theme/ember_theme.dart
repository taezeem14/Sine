import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

typedef SineColors = EmberColors;
typedef SineTheme = EmberTheme;

class EmberColors {
  EmberColors._();

  // Surface & Foundations (Pitch Black & Obsidian Surfaces)
  static const Color obsidianBase = Color(0xFF121212);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceContainerLowest = Color(0xFF000000);
  static const Color surfaceContainerLow = Color(0xFF181818);
  static const Color surfaceContainer = Color(0xFF242424);
  static const Color surfaceContainerHigh = Color(0xFF282828);
  static const Color surfaceContainerHighest = Color(0xFF333333);

  // Sine Electric Blue — ONE Unified Signature Shade: Color(0xFF2979FF)
  static const Color primaryBlue = Color(0xFF2979FF);
  static const Color primaryBlueHi = primaryBlue;
  static const Color secondaryCyan = primaryBlue;
  static const Color secondaryAzure = primaryBlue;
  static const Color tertiaryBlue = primaryBlue;

  // Convenience aliases for Electric Blue Sine theme
  static const Color electricBlue = primaryBlue;
  static const Color electricBlueHi = primaryBlue;
  static const Color charcoalCard = surfaceContainerLow;
  static const Color surfaceDark = surfaceContainer;
  static const Color glassBorder = outlineVariant;
  static const Color youtubeRed = Color(0xFFFF0000);

  // Backward-compatible aliases for existing widgets — all unified to ONE shade of blue
  static const Color primaryAmber = primaryBlue;
  static const Color primaryAmberHi = primaryBlue;
  static const Color secondaryHoney = primaryBlue;
  static const Color secondaryOrange = primaryBlue;
  static const Color tertiaryGold = primaryBlue;

  // Text & Content Hierarchy (Pure Contrast)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF9E9E9E);

  // System & Borders
  static const Color outline = Color(0xFF3E3E3E);
  static const Color outlineVariant = Color(0xFF282828);
  static const Color borderSubtle = Color(0xFF282828);
  static const Color error = Color(0xFFE05252);
  static const Color pulseBlue = Color(0xFF2979FF);
}

class EmberTheme {
  EmberTheme._();

  static ThemeData get darkTheme => buildTheme(useGoogleFonts: true);

  static ThemeData buildTheme({bool useGoogleFonts = true}) {
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
      colorScheme: const ColorScheme.dark(
        surface: EmberColors.surface,
        primary: EmberColors.primaryAmber,
        secondary: EmberColors.secondaryHoney,
        tertiary: EmberColors.tertiaryGold,
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
          backgroundColor: EmberColors.primaryAmber,
          foregroundColor: EmberColors.obsidianBase,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: mergedTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
