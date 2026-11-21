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
  static bool _isOledBlack = false;

  static Color get currentPrimary => _currentPrimary;
  static bool get isOledBlack => _isOledBlack;

  static void setOledBlack(bool enabled) {
    _isOledBlack = enabled;
  }

  static void applyThemeColor(Color color) {
    _currentPrimary = color;
  }

  static void applyThemePreset(SineThemePreset preset) {
    _currentPrimary = preset.accentColor;
  }

  // Surface & Foundations (Pitch Black & Obsidian Surfaces)
  static const Color pitchBlack = Color(0xFF000000);
  static const Color obsidianCharcoal = Color(0xFF121212);
  static const Color obsidianBase = Color(0xFF121212);
  static Color get currentBackground => _isOledBlack ? pitchBlack : obsidianCharcoal;
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

  static const Curve entryCurve = Curves.easeOutQuint;
  static const Curve modalCurve = Curves.easeInOutCubic;

  static ThemeData get darkTheme => buildTheme(
    accentColor: EmberColors.currentPrimary,
    isOledBlack: EmberColors.isOledBlack,
    useGoogleFonts: true,
  );

  static TextTheme? _cachedGoogleTextTheme;

  static TextTheme _resolveTextTheme(bool useGoogleFonts) {
    final canFetchFonts = useGoogleFonts && GoogleFonts.config.allowRuntimeFetching;
    if (!canFetchFonts) return const TextTheme();
    if (_cachedGoogleTextTheme != null) return _cachedGoogleTextTheme!;
    try {
      final baseTextTheme = Typography.material2021().white;

      final headlineFont = GoogleFonts.soraTextTheme(baseTextTheme);
      final bodyFont = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme);
      final labelFont = GoogleFonts.spaceGroteskTextTheme(baseTextTheme);

      _cachedGoogleTextTheme = bodyFont.copyWith(
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
      return _cachedGoogleTextTheme!;
    } catch (_) {
      return const TextTheme();
    }
  }

  static ThemeData buildTheme({
    Color? accentColor,
    bool? isOledBlack,
    bool useGoogleFonts = true,
  }) {
    final activeAccent = accentColor ?? EmberColors.currentPrimary;
    final oled = isOledBlack ?? EmberColors.isOledBlack;
    final bg = oled ? EmberColors.pitchBlack : EmberColors.obsidianBase;
    final surfaceBg = oled ? EmberColors.pitchBlack : EmberColors.surface;
    final cardBg = oled ? const Color(0xFF0D0D0D) : EmberColors.surfaceContainerLow;
    final mergedTextTheme = _resolveTextTheme(useGoogleFonts);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      canvasColor: surfaceBg,
      cardColor: cardBg,
      dividerColor: EmberColors.outlineVariant,
      colorScheme: ColorScheme.dark(
        surface: surfaceBg,
        primary: activeAccent,
        secondary: activeAccent,
        tertiary: activeAccent,
        error: EmberColors.error,
        onSurface: EmberColors.textPrimary,
        onPrimary: bg,
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothCubicPageTransitionsBuilder(),
          TargetPlatform.iOS: SmoothCubicPageTransitionsBuilder(),
          TargetPlatform.linux: SmoothCubicPageTransitionsBuilder(),
          TargetPlatform.macOS: SmoothCubicPageTransitionsBuilder(),
          TargetPlatform.windows: SmoothCubicPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Smooth cubic page transition builder utilizing [Curves.easeOutCubic] for entry
/// and [Curves.easeInOutCubic] for secondary transitions via zero-leak [CurveTween] chains.
class SmoothCubicPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothCubicPageTransitionsBuilder();

  static final Animatable<Offset> _entrySlideTween = Tween<Offset>(
    begin: const Offset(0.08, 0.0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  static final Animatable<double> _entryFadeTween = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  static final Animatable<Offset> _secondarySlideTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.04, 0.0),
  ).chain(CurveTween(curve: Curves.easeInOutCubic));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(_entrySlideTween),
      child: FadeTransition(
        opacity: animation.drive(_entryFadeTween),
        child: SlideTransition(
          position: secondaryAnimation.drive(_secondarySlideTween),
          child: child,
        ),
      ),
    );
  }
}
