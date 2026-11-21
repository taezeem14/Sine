import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/cover_color_service.dart';
import '../theme/ember_theme.dart';

/// Vivid, GPU-composited continuous ambient aurora driven strictly by the real
/// extracted album artwork palette from [CoverColorService].
///
/// Key engineering invariants:
/// - Strictly integer harmonic frequencies (1*t, 2*t) over a 14-second cycle so
///   f(0) == f(2pi) and f'(0) == f'(2pi): mathematically C-infinity seamless loop
///   that NEVER teleports or restarts.
/// - Automatically pauses ticking ONLY while its hosting ModalRoute is actively
///   sliding in/out, guaranteeing locked 60/120 FPS maximize & minimize animations,
///   then resumes seamlessly from the exact same orbital angle.
/// - Zero title-hash faking: strictly faithful to the real album cover colors.
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
  Animation<double>? _routeAnimation;
  bool _isRouteTransitioning = false;

  @override
  void initState() {
    super.initState();
    // Smooth, clearly visible 14-second continuous fluid aurora loop (never resets)
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
      value: 1.0,
    );

    final initialPalette = _resolveImmediatePalette();
    _targetColors = _paletteToFluidColors(initialPalette);
    _previousColors = List<Color>.from(_targetColors);

    CoverColorService.instance.paletteRevision.addListener(_onPaletteRevisionChanged);
    _ensureArtworkExtracted();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeAnim = ModalRoute.of(context)?.animation;
    if (routeAnim != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_onRouteStatusChanged);
      _routeAnimation = routeAnim;
      _routeAnimation?.addStatusListener(_onRouteStatusChanged);
      if (routeAnim != null) {
        _onRouteStatusChanged(routeAnim.status);
      }
    }
  }

  void _onRouteStatusChanged(AnimationStatus status) {
    final transitioning =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (transitioning == _isRouteTransitioning) return;
    _isRouteTransitioning = transitioning;
    if (transitioning) {
      // Freeze orbital ticker cleanly during maximize/minimize route slide for 120 FPS
      if (_motionController.isAnimating) {
        _motionController.stop(canceled: false);
      }
    } else {
      // Resume seamlessly from the exact stopped angle (zero jump/reset)
      if (mounted && !_motionController.isAnimating) {
        _motionController.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant FluidMeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isRouteTransitioning && !_motionController.isAnimating) {
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
    _routeAnimation?.removeStatusListener(_onRouteStatusChanged);
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

  /// Elevates extracted cover colors into rich, luminous dark-mode aurora tones
  /// while preserving the exact extracted hue 100% (or refined silvery slate for B&W covers).
  static Color _boostForAurora(
    Color color, {
    required double minLightness,
    required double maxLightness,
    required double satBoost,
  }) {
    final hsl = HSLColor.fromColor(color);
    final bool isMonochrome = hsl.saturation < 0.16;
    if (isMonochrome) {
      return HSLColor.fromAHSL(
        1.0,
        hsl.hue,
        hsl.saturation.clamp(0.0, 0.14),
        (hsl.lightness + 0.12).clamp(minLightness, maxLightness),
      ).toColor();
    }
    return HSLColor.fromAHSL(
      1.0,
      hsl.hue,
      (hsl.saturation + satBoost).clamp(0.42, 0.88),
      (hsl.lightness + 0.10).clamp(minLightness, maxLightness),
    ).toColor();
  }

  List<Color> _paletteToFluidColors(CoverPalette p) {
    final primary = _boostForAurora(
      p.dominant,
      minLightness: 0.42,
      maxLightness: 0.62,
      satBoost: 0.10,
    );
    final secondary = _boostForAurora(
      p.secondary,
      minLightness: 0.34,
      maxLightness: 0.54,
      satBoost: 0.08,
    );
    final accent = _boostForAurora(
      p.accent,
      minLightness: 0.48,
      maxLightness: 0.68,
      satBoost: 0.12,
    );
    // Subtle deeper wash derived directly from dominant hue to anchor lower-screen fluid depth
    final domHsl = HSLColor.fromColor(primary);
    final deepWash = HSLColor.fromAHSL(
      1.0,
      (domHsl.hue + 10) % 360,
      (domHsl.saturation * 0.88).clamp(0.0, 0.82),
      (domHsl.lightness * 0.68).clamp(0.24, 0.46),
    ).toColor();

    return [primary, secondary, accent, deepWash];
  }

  void _transitionToPalette(CoverPalette next) {
    final nextColors = _paletteToFluidColors(next);
    if (_targetColors[0] == nextColors[0] &&
        _targetColors[1] == nextColors[1] &&
        _targetColors[2] == nextColors[2] &&
        _targetColors[3] == nextColors[3]) {
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
      Color.lerp(_previousColors[3], _targetColors[3], t) ?? _targetColors[3],
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

        // Isolated GPU-composited continuous cover-matched fluid aurora
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_motionController, _colorTransitionController]),
            builder: (context, _) {
              final activeColors = _computeActiveColors();
              // Strictly integer harmonic multiples (1*t, 2*t) -> C-infinity seamless loop with ZERO seam jumps
              final t = _motionController.value * 2 * math.pi;

              // Orb 1: Primary dominant wave sweeping upper-left <-> center-right
              final x1 = 0.34 + 0.30 * math.sin(t);
              final y1 = 0.24 + 0.16 * math.cos(t);

              // Orb 2: Secondary harmonic wave countering across center <-> lower-right
              final x2 = 0.68 + 0.28 * math.cos(t + 1.1);
              final y2 = 0.56 + 0.22 * math.sin(t + 1.1);

              // Orb 3: Luminous accent highlight drifting smoothly through figure-8 arc (2*t harmonic)
              final x3 = 0.50 + 0.26 * math.sin(t * 2 + 0.6);
              final y3 = 0.36 + 0.18 * math.cos(t + 2.4);

              // Orb 4: Deep lower-left anchor wash balancing the lower player controls
              final x4 = 0.24 + 0.24 * math.cos(t + 3.6);
              final y4 = 0.78 + 0.14 * math.sin(t + 3.6);

              return CustomPaint(
                painter: _FluidAuroraPainter(
                  p1: Offset(x1, y1),
                  p2: Offset(x2, y2),
                  p3: Offset(x3, y3),
                  p4: Offset(x4, y4),
                  colors: activeColors,
                  isPlaying: widget.isPlaying,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),

        // Light, sculpted readability scrim: preserves full aurora vibrancy while keeping controls legible
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EmberColors.obsidianBase.withValues(alpha: 0.20),
                  Colors.transparent,
                  EmberColors.obsidianBase.withValues(alpha: 0.34),
                  EmberColors.obsidianBase.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.32, 0.74, 1.0],
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

class _FluidAuroraPainter extends CustomPainter {
  final Offset p1;
  final Offset p2;
  final Offset p3;
  final Offset p4;
  final List<Color> colors;
  final bool isPlaying;

  _FluidAuroraPainter({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
    required this.colors,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c1 = Offset(p1.dx * size.width, p1.dy * size.height);
    final c2 = Offset(p2.dx * size.width, p2.dy * size.height);
    final c3 = Offset(p3.dx * size.width, p3.dy * size.height);
    final c4 = Offset(p4.dx * size.width, p4.dy * size.height);

    final shortest = size.shortestSide;
    final r1 = shortest * 0.92;
    final r2 = shortest * 0.88;
    final r3 = shortest * 0.74;
    final r4 = shortest * 0.82;

    final scale = isPlaying ? 1.0 : 0.76;

    void drawOrb(Offset center, double radius, Color color, double coreAlpha, double midAlpha) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: (coreAlpha * scale).clamp(0.0, 1.0)),
            color.withValues(alpha: (midAlpha * scale).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    drawOrb(c4, r4, colors[3], 0.50, 0.20);
    drawOrb(c1, r1, colors[0], 0.72, 0.34);
    drawOrb(c2, r2, colors[1], 0.62, 0.28);
    drawOrb(c3, r3, colors[2], 0.44, 0.16);
  }

  @override
  bool shouldRepaint(covariant _FluidAuroraPainter oldDelegate) {
    return oldDelegate.p1 != p1 ||
        oldDelegate.p2 != p2 ||
        oldDelegate.p3 != p3 ||
        oldDelegate.p4 != p4 ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.colors[0] != colors[0] ||
        oldDelegate.colors[1] != colors[1] ||
        oldDelegate.colors[2] != colors[2] ||
        oldDelegate.colors[3] != colors[3];
  }
}
