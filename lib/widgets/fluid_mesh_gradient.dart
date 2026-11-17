import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/ember_theme.dart';

class FluidMeshGradientBackground extends StatefulWidget {
  final Widget child;
  final Song? song;
  final bool isPlaying;

  const FluidMeshGradientBackground({
    super.key,
    required this.child,
    this.song,
    this.isPlaying = true,
  });

  @override
  State<FluidMeshGradientBackground> createState() => _FluidMeshGradientBackgroundState();
}

class _FluidMeshGradientBackgroundState extends State<FluidMeshGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _motionController;
  late AnimationController _colorTransitionController;

  late List<Color> _previousPalette;
  late List<Color> _currentPalette;

  @override
  void initState() {
    super.initState();
    // Continuous 16-second orbital loop that never resets or jerks
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _currentPalette = _derivePalette(widget.song);
    _previousPalette = List.from(_currentPalette);

    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant FluidMeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Keep motion continuous without ever restarting from zero
    if (!_motionController.isAnimating) {
      _motionController.repeat();
    }

    if (oldWidget.song?.id != widget.song?.id) {
      _previousPalette = _computeActivePalette();
      _currentPalette = _derivePalette(widget.song);
      _colorTransitionController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    _colorTransitionController.dispose();
    super.dispose();
  }

  List<Color> _derivePalette(Song? song) {
    if (song == null) {
      return const [
        Color(0xFF0072FF),
        Color(0xFF00F0FF),
        Color(0xFF7928CA),
      ];
    }
    // Seed harmonic hues from track title & artist
    final hash = (song.title.hashCode ^ song.artist.hashCode).abs();
    final baseHue = (hash % 360).toDouble();

    final c1 = HSLColor.fromAHSL(1.0, baseHue, 0.75, 0.55).toColor();
    final c2 = HSLColor.fromAHSL(1.0, (baseHue + 45) % 360, 0.85, 0.45).toColor();
    final c3 = HSLColor.fromAHSL(1.0, (baseHue + 120) % 360, 0.80, 0.35).toColor();

    return [c1, c2, c3];
  }

  List<Color> _computeActivePalette() {
    final t = _colorTransitionController.value;
    if (t >= 1.0) return _currentPalette;
    return [
      Color.lerp(_previousPalette[0], _currentPalette[0], t) ?? _currentPalette[0],
      Color.lerp(_previousPalette[1], _currentPalette[1], t) ?? _currentPalette[1],
      Color.lerp(_previousPalette[2], _currentPalette[2], t) ?? _currentPalette[2],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Dark Background
        Container(color: EmberColors.obsidianBase),

        // Isolated GPU-composited continuous fluid mesh paint
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_motionController, _colorTransitionController]),
            builder: (context, _) {
              final activeColors = _computeActivePalette();
              final t = _motionController.value * 2 * math.pi;

              // Smooth continuous orbital drift equations (non-intersecting phase shifted paths)
              final x1 = 0.30 + 0.22 * math.sin(t);
              final y1 = 0.32 + 0.18 * math.cos(t);

              final x2 = 0.68 + 0.18 * math.cos(t * 0.75 + 0.5);
              final y2 = 0.62 + 0.22 * math.sin(t * 0.75 + 0.5);

              final x3 = 0.48 + 0.18 * math.sin(t * 1.15 + 1.2);
              final y3 = 0.42 + 0.18 * math.cos(t * 1.15 + 1.2);

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

        // Dark Vignette Overlay to maintain contrast and readable controls
        RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EmberColors.obsidianBase.withValues(alpha: 0.65),
                  Colors.transparent,
                  EmberColors.obsidianBase.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Main Foreground Content (Untouched by background repaint ticks)
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

    final r1 = size.shortestSide * 0.55;
    final r2 = size.shortestSide * 0.60;
    final r3 = size.shortestSide * 0.50;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[0].withValues(alpha: 0.40),
          colors[0].withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[1].withValues(alpha: 0.35),
          colors[1].withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[2].withValues(alpha: 0.30),
          colors[2].withValues(alpha: 0.08),
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
        oldDelegate.colors != colors;
  }
}
