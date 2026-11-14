import 'package:flutter/material.dart';
import '../theme/ember_theme.dart';

class AmbientGlow extends StatefulWidget {
  final Widget child;
  final bool isPlaying;
  final Color? glowColor;

  const AmbientGlow({
    super.key,
    required this.child,
    this.isPlaying = true,
    this.glowColor,
  });

  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _opacityAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AmbientGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
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
    return Stack(
      alignment: Alignment.center,
      children: [
        // Static blurred background with animated opacity (GPU composited, zero re-rasterization)
        FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (widget.glowColor ?? EmberColors.primaryAmber).withValues(alpha: widget.isPlaying ? 0.32 : 0.12),
                  blurRadius: 52,
                  spreadRadius: 22,
                ),
                BoxShadow(
                  color: EmberColors.secondaryHoney.withValues(alpha: widget.isPlaying ? 0.18 : 0.06),
                  blurRadius: 78,
                  spreadRadius: 16,
                ),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
