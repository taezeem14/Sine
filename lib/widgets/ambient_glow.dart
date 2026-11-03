import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/ember_theme.dart';

class AmbientGlow extends StatefulWidget {
  final Widget child;
  final bool isPlaying;
  final Color glowColor;

  const AmbientGlow({
    super.key,
    required this.child,
    this.isPlaying = true,
    this.glowColor = EmberColors.primaryAmber,
  });

  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AmbientGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.animateTo(0.0, duration: const Duration(milliseconds: 600), curve: Curves.easeOut);
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
        final breathe = math.sin(_controller.value * math.pi) * 0.15;
        final spreadRadius = 24.0 * (1.0 + breathe);
        final blurRadius = 48.0 * (1.0 + breathe);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: widget.isPlaying ? 0.35 : 0.15),
                blurRadius: blurRadius,
                spreadRadius: spreadRadius,
              ),
              BoxShadow(
                color: EmberColors.secondaryHoney.withValues(alpha: widget.isPlaying ? 0.20 : 0.08),
                blurRadius: blurRadius * 1.5,
                spreadRadius: spreadRadius * 0.8,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
