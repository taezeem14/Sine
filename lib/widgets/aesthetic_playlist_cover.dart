import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/ember_theme.dart';

class AestheticPlaylistTheme {
  final String id;
  final String name;
  final List<Color> colors;
  final FaIconData icon;

  const AestheticPlaylistTheme({
    required this.id,
    required this.name,
    required this.colors,
    required this.icon,
  });

  List<Color> get gradientColors => colors;
}

class AestheticPlaylistCover extends StatelessWidget {
  final String? coverUrl;
  final double size;
  final double borderRadius;
  final Widget? fallbackIcon;

  const AestheticPlaylistCover({
    super.key,
    required this.coverUrl,
    this.size = 56,
    this.borderRadius = 8,
    this.fallbackIcon,
  });

  static const List<AestheticPlaylistTheme> themes = [
    AestheticPlaylistTheme(
      id: 'neon_pulse',
      name: 'Neon Pulse',
      colors: [Color(0xFF00F0FF), Color(0xFF0072FF), Color(0xFF0F172A)],
      icon: FontAwesomeIcons.bolt,
    ),
    AestheticPlaylistTheme(
      id: 'midnight_violet',
      name: 'Midnight Violet',
      colors: [Color(0xFF9D4EDD), Color(0xFF5A189A), Color(0xFF10002B)],
      icon: FontAwesomeIcons.moon,
    ),
    AestheticPlaylistTheme(
      id: 'cyber_amber',
      name: 'Cyber Amber',
      colors: [Color(0xFFFF9E00), Color(0xFFFF5400), Color(0xFF3A0CA3)],
      icon: FontAwesomeIcons.fire,
    ),
    AestheticPlaylistTheme(
      id: 'aurora_green',
      name: 'Aurora Wave',
      colors: [Color(0xFF00F5D4), Color(0xFF00BBF9), Color(0xFF051923)],
      icon: FontAwesomeIcons.waveSquare,
    ),
    AestheticPlaylistTheme(
      id: 'hyper_pink',
      name: 'Hyper Pink',
      colors: [Color(0xFFFF007F), Color(0xFF7928CA), Color(0xFF1A002C)],
      icon: FontAwesomeIcons.compactDisc,
    ),
    AestheticPlaylistTheme(
      id: 'monochrome_glass',
      name: 'Obsidian Minimal',
      colors: [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF090D16)],
      icon: FontAwesomeIcons.headphones,
    ),
  ];

  static AestheticPlaylistTheme getThemeById(String id) {
    return themes.firstWhere(
      (t) => t.id == id,
      orElse: () => themes.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawCover = coverUrl?.trim() ?? '';

    // 1. Procedural Aesthetic Gradient Preset
    if (rawCover.startsWith('aesthetic:')) {
      final themeId = rawCover.replaceFirst('aesthetic:', '');
      final theme = getThemeById(themeId);

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.colors,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colors.first.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: FaIcon(
            theme.icon,
            color: Colors.white.withValues(alpha: 0.9),
            size: size * 0.38,
          ),
        ),
      );
    }

    // 2. Local File Image (zero synchronous existsSync() on UI thread; errorBuilder handles missing paths)
    if (rawCover.isNotEmpty && !rawCover.startsWith('http')) {
      final cacheDim = (size * 2).round().clamp(64, 320);
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(rawCover),
          width: size,
          height: size,
          cacheWidth: cacheDim,
          cacheHeight: cacheDim,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultFallback(),
        ),
      );
    }

    // 3. Remote Network Image
    if (rawCover.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: rawCover,
          width: size,
          height: size,
          memCacheWidth: 200,
          memCacheHeight: 200,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _buildDefaultFallback(),
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            color: EmberColors.charcoalCard,
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.music,
                size: size * 0.28,
                color: EmberColors.textMuted.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      );
    }

    // 4. Default Fallback
    return _buildDefaultFallback();
  }

  Widget _buildDefaultFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: EmberColors.charcoalCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: EmberColors.glassBorder.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Center(
        child: fallbackIcon ??
            FaIcon(
              FontAwesomeIcons.music,
              size: size * 0.35,
              color: EmberColors.primaryBlue.withValues(alpha: 0.7),
            ),
      ),
    );
  }
}
