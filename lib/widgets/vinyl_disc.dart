import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/ember_theme.dart';

class VinylDisc extends StatefulWidget {
  final double size;
  final bool isPlaying;

  const VinylDisc({
    super.key,
    this.size = 140,
    this.isPlaying = true,
  });

  @override
  State<VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<VinylDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        final target = _controller.value + 0.05;
        if (target <= 1.0) {
          _controller.animateTo(
            target,
            duration: const Duration(milliseconds: 400),
            curve: Curves.decelerate,
          );
        } else {
          _controller.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _VinylPainter(),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer vinyl body
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF1E1B18),
          Color(0xFF0F0D0B),
          Color(0xFF1E1B18),
          Color(0xFF0F0D0B),
        ],
        stops: [0.0, 0.4, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bodyPaint);

    // Subtle edge rim
    final rimPaint = Paint()
      ..color = const Color(0xFF2C2927)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 0.5, rimPaint);

    // Grooves
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (double r = radius * 0.42; r < radius * 0.92; r += 4.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Center amber label
    final labelRadius = radius * 0.36;
    final labelPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          EmberColors.primaryAmberHi,
          EmberColors.primaryAmber,
          EmberColors.secondaryHoney,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: labelRadius));
    canvas.drawCircle(center, labelRadius, labelPaint);

    // Center spindle hole
    final holePaint = Paint()..color = EmberColors.obsidianBase;
    canvas.drawCircle(center, radius * 0.08, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
