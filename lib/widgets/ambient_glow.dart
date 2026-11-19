import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/ember_theme.dart';

/// Ethereal continuous ambient lighting surrounding the player vinyl and album cover.
/// Renders an orbital, pulsing aura dynamically colored by the song's cover artwork.
class AmbientGlow extends StatefulWidget {
  final Widget child;
  final bool isPlaying;
  final Color? glowColor;
  final Color? secondaryGlowColor;

  const AmbientGlow({
    super.key,
    required this.child,
    this.isPlaying = true,
    this.glowColor,
    this.secondaryGlowColor,
  });

  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _colorTransitionController;

  late Color _previousGlowColor;
  late Color _currentGlowColor;
  late Color _previousSecondaryColor;
  late Color _currentSecondaryColor;

  @override
  void initState() {
    super.initState();
    // Continuous smooth breathing pulse (3.6s loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.isPlaying) {
      _pulseController.repeat(reverse: true);
    }

    // Continuous 24-second orbital aura rotation (never restarts or jerks)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _currentGlowColor = widget.glowColor ?? EmberColors.primaryBlue;
    _previousGlowColor = _currentGlowColor;
    _currentSecondaryColor = widget.secondaryGlowColor ?? const Color(0xFF00D2FF);
    _previousSecondaryColor = _currentSecondaryColor;

    _colorTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant AmbientGlow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _pulseController.animateTo(
          0.3,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      }
    }

    // Continuous motion ticker must keep running without resetting
    if (!_rotationController.isAnimating) {
      _rotationController.repeat();
    }

    final newGlow = widget.glowColor ?? EmberColors.primaryBlue;
    final newSecondary = widget.secondaryGlowColor ?? const Color(0xFF00D2FF);

    if (oldWidget.glowColor != widget.glowColor ||
        oldWidget.secondaryGlowColor != widget.secondaryGlowColor) {
      _previousGlowColor = _computeActiveGlow();
      _previousSecondaryColor = _computeActiveSecondary();
      _currentGlowColor = newGlow;
      _currentSecondaryColor = newSecondary;
      _colorTransitionController.forward(from: 0.0);
    }
  }

  Color _computeActiveGlow() {
    final t = _colorTransitionController.value;
    if (t >= 1.0) return _currentGlowColor;
    return Color.lerp(_previousGlowColor, _currentGlowColor, t) ?? _currentGlowColor;
  }

  Color _computeActiveSecondary() {
    final t = _colorTransitionController.value;
    if (t >= 1.0) return _currentSecondaryColor;
    return Color.lerp(_previousSecondaryColor, _currentSecondaryColor, t) ?? _currentSecondaryColor;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _colorTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Continuous Ambient Light Aura
          AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _rotationController,
              _colorTransitionController,
            ]),
            builder: (context, _) {
              final activeColor = _computeActiveGlow();
              final activeSecondary = _computeActiveSecondary();
              final pulse = _pulseController.value; // 0.0 to 1.0
              final rotAngle = _rotationController.value * 2 * math.pi;

              final intensity = widget.isPlaying ? (0.28 + 0.16 * pulse) : 0.12;
              final outerSpread = widget.isPlaying ? (22.0 + 8.0 * pulse) : 12.0;
              final outerBlur = widget.isPlaying ? (64.0 + 20.0 * pulse) : 40.0;

              return Transform.rotate(
                angle: rotAngle,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Primary cover color glow (broad dispersion)
                      BoxShadow(
                        color: activeColor.withValues(alpha: intensity),
                        blurRadius: outerBlur,
                        spreadRadius: outerSpread,
                      ),
                      // Secondary cover harmonic glow (halo effect)
                      BoxShadow(
                        color: activeSecondary.withValues(alpha: intensity * 0.65),
                        blurRadius: outerBlur * 1.3,
                        spreadRadius: outerSpread * 0.6,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}
