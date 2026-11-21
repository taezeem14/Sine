import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/cover_color_service.dart';
import '../theme/ember_theme.dart';

/// Atmospheric ambient background driven strictly by the real extracted
/// album artwork palette from [CoverColorService].
///
/// Features continuous, unhurried GPU-composited orbital drift and smooth
/// cross-fades between real cover palettes without ever flashing random hash hues.
class FluidMeshGradientBackground extends StatefulWidget {
  final Widget child;
  final Song? song;
  final CoverPalette? palette;
  final bool isPlaying;

  const FluidMeshGradientBackground({
    super.key,
    required this.child,
    this.song,
    this.palette,
    this.isPlaying = true,
  });

  @override
  State<FluidMeshGradientBackground> createState() => _FluidMeshGradientBackgroundState();
}

class _FluidMeshGradientBackgroundState extends State<FluidMeshGradientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _motionController;
  late final AnimationController _colorTransitionController;

  late List<Color> _previousColors;
  late List<Color> _targetColors;
  String? _requestedArtworkKey;

  @override
  void initState() {
    super.initState();
    // Unhurried, cinematic 26-second continuous orbital drift (never resets)
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();

    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      value: 1.0,
    );

    final initialPalette = _resolveImmediatePalette();
    _targetColors = _paletteToColors(initialPalette);
    _previousColors = List<Color>.from(_targetColors);

    CoverColorService.instance.paletteRevision.addListener(_onPaletteRevisionChanged);
    _ensureArtworkExtracted();
  }

  @override
  void didUpdateWidget(covariant FluidMeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_motionController.isAnimating) {
      _motionController.repeat();
    }

    final songChanged = oldWidget.song?.id != widget.song?.id ||
        oldWidget.song?.artworkUrl != widget.song?.artworkUrl;
    final paletteChanged = oldWidget.palette != widget.palette;

    if (songChanged || paletteChanged) {
      _transitionToPalette(_resolveImmediatePalette());
      if (songChanged) {
        _ensureArtworkExtracted();
      }
    }
  }

  @override
  void dispose() {
    CoverColorService.instance.paletteRevision.removeListener(_onPaletteRevisionChanged);
    _motionController.dispose();
    _colorTransitionController.dispose();
    super.dispose();
  }

  CoverPalette _resolveImmediatePalette() {
    if (widget.palette != null) return widget.palette!;
    return CoverColorService.instance.getPaletteSync(widget.song);
  }

  void _onPaletteRevisionChanged() {
    if (!mounted || widget.palette != null || widget.song == null) return;
    final latest = CoverColorService.instance.getPaletteSync(widget.song);
    if (latest.isExtracted) {
      _transitionToPalette(latest);
    }
  }

  void _ensureArtworkExtracted() {
    if (widget.palette != null) return;
    final song = widget.song;
    if (song == null || song.artworkUrl.trim().isEmpty) return;

    final key = '${song.id}_${song.artworkUrl}';
    if (_requestedArtworkKey == key) return;
    _requestedArtworkKey = key;

    CoverColorService.instance.getPalette(song).then((extracted) {
      if (!mounted) return;
      if (widget.song?.artworkUrl == song.artworkUrl && extracted.isExtracted) {
        _transitionToPalette(extracted);
      }
    });
  }

  List<Color> _paletteToColors(CoverPalette p) => [p.dominant, p.secondary, p.accent];

  void _transitionToPalette(CoverPalette next) {
    final nextColors = _paletteToColors(next);
    if (_targetColors[0] == nextColors[0] &&
        _targetColors[1] == nextColors[1] &&
        _targetColors[2] == nextColors[2]) {
      return;
    }
    _previousColors = _computeActiveColors();
    _targetColors = nextColors;
    _colorTransitionController.forward(from: 0.0);
  }

  List<Color> _computeActiveColors() {
    final t = Curves.easeInOutCubic.transform(_colorTransitionController.value);
    if (t >= 1.0) return _targetColors;
    return [
      Color.lerp(_previousColors[0], _targetColors[0], t) ?? _targetColors[0],
      Color.lerp(_previousColors[1], _targetColors[1], t) ?? _targetColors[1],
      Color.lerp(_previousColors[2], _targetColors[2], t) ?? _targetColors[2],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final baseBg = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep Obsidian / OLED Base
        ColoredBox(color: baseBg),

        // Isolated GPU-composited continuous cover-matched ambient mesh
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_motionController, _colorTransitionController]),
            builder: (context, _) {
              final activeColors = _computeActiveColors();
              final t = _motionController.value * 2 * math.pi;

              // Subtle, organic wide-radius drift (upper-center focal glow around artwork + soft base wash)
              final x1 = 0.36 + 0.16 * math.sin(t);
              final y1 = 0.28 + 0.12 * math.cos(t);

              final x2 = 0.68 + 0.15 * math.cos(t * 0.75 + 0.8);
              final y2 = 0.56 + 0.16 * math.sin(t * 0.75 + 0.8);

              final x3 = 0.44 + 0.14 * math.sin(t * 0.6 + 2.1);
              final y3 = 0.42 + 0.12 * math.cos(t * 0.6 + 2.1);

              return CustomPaint(
                painter: _MeshGradientPainter(
                  p1: Offset(x1, y1),
                  p2: Offset(x2, y2),
                  p3: Offset(x3, y3),
                  colors: activeColors,
                  isPlaying: widget.isPlaying,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),

        // Precision Readability Vignette (keeps controls, timecodes, and lyrics effortlessly legible)
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EmberColors.obsidianBase.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.12),
                  EmberColors.obsidianBase.withValues(alpha: 0.78),
                  EmberColors.obsidianBase.withValues(alpha: 0.94),
                ],
                stops: const [0.0, 0.36, 0.76, 1.0],
              ),
            ),
          ),
        ),

        // Foreground Content
        widget.child,
      ],
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final Offset p1;
  final Offset p2;
  final Offset p3;
  final List<Color> colors;
  final bool isPlaying;

  _MeshGradientPainter({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.colors,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c1 = Offset(p1.dx * size.width, p1.dy * size.height);
    final c2 = Offset(p2.dx * size.width, p2.dy * size.height);
    final c3 = Offset(p3.dx * size.width, p3.dy * size.height);

    // Broad, soft-edged atmospheric washes (no hard circular blob edges)
    final r1 = size.shortestSide * 0.85;
    final r2 = size.shortestSide * 0.82;
    final r3 = size.shortestSide * 0.68;

    final intensityScale = isPlaying ? 1.0 : 0.72;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[0].withValues(alpha: 0.54 * intensityScale),
          colors[0].withValues(alpha: 0.22 * intensityScale),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[1].withValues(alpha: 0.44 * intensityScale),
          colors[1].withValues(alpha: 0.16 * intensityScale),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[2].withValues(alpha: 0.28 * intensityScale),
          colors[2].withValues(alpha: 0.09 * intensityScale),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c3, radius: r3));

    canvas.drawCircle(c1, r1, paint1);
    canvas.drawCircle(c2, r2, paint2);
    canvas.drawCircle(c3, r3, paint3);
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return oldDelegate.p1 != p1 ||
        oldDelegate.p2 != p2 ||
        oldDelegate.p3 != p3 ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.colors[0] != colors[0] ||
        oldDelegate.colors[1] != colors[1] ||
        oldDelegate.colors[2] != colors[2];
  }
}
