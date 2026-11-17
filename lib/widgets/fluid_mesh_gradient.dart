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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FluidMeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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

    final c1 = HSLColor.fromAHSV(1.0, baseHue, 0.75, 0.55).toColor();
    final c2 = HSLColor.fromAHSV(1.0, (baseHue + 45) % 360, 0.85, 0.45).toColor();
    final c3 = HSLColor.fromAHSV(1.0, (baseHue + 120) % 360, 0.80, 0.35).toColor();

    return [c1, c2, c3];
  }

  @override
  Widget build(BuildContext context) {
    final palette = _derivePalette(widget.song);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base Dark Background
          Container(color: EmberColors.obsidianBase),

          // Animated Fluid Mesh Blobs (GPU composited)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * math.pi;

              // Orbital phase shifts for 3 fluid points
              final x1 = 0.3 + 0.25 * math.sin(t);
              final y1 = 0.3 + 0.20 * math.cos(t);

              final x2 = 0.7 + 0.20 * math.cos(t * 0.8);
              final y2 = 0.6 + 0.25 * math.sin(t * 0.8);

              final x3 = 0.5 + 0.20 * math.sin(t * 1.2 + 1.0);
              final y3 = 0.4 + 0.20 * math.cos(t * 1.2 + 1.0);

              return CustomPaint(
                painter: _MeshGradientPainter(
                  p1: Offset(x1, y1),
                  p2: Offset(x2, y2),
                  p3: Offset(x3, y3),
                  colors: palette,
                  isPlaying: widget.isPlaying,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Dark Vignette Overlay to maintain contrast and readable controls
          Container(
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

          widget.child,
        ],
      ),
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

    final alpha = isPlaying ? 0.38 : 0.22;

    // Blob 1
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[0].withValues(alpha: alpha),
          colors[0].withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));
    canvas.drawCircle(c1, r1, paint1);

    // Blob 2
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[1].withValues(alpha: alpha * 0.9),
          colors[1].withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));
    canvas.drawCircle(c2, r2, paint2);

    // Blob 3
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          colors[2].withValues(alpha: alpha * 0.85),
          colors[2].withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c3, radius: r3));
    canvas.drawCircle(c3, r3, paint3);
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return oldDelegate.p1 != p1 ||
        oldDelegate.p2 != p2 ||
        oldDelegate.p3 != p3 ||
        oldDelegate.isPlaying != isPlaying;
  }
}
