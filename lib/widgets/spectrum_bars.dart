import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/ember_theme.dart';

class SpectrumBars extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final int barCount;

  const SpectrumBars({
    super.key,
    required this.isPlaying,
    this.height = 14,
    this.barCount = 4,
  });

  @override
  State<SpectrumBars> createState() => _SpectrumBarsState();
}

class _SpectrumBarsState extends State<SpectrumBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SpectrumBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (i) {
            final phase = (i * 0.45);
            final val = widget.isPlaying
                ? (math.sin((_controller.value * 2 * math.pi) + phase).abs() * 0.75 + 0.25)
                : 0.2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              width: 2.5,
              height: widget.height * val,
              decoration: BoxDecoration(
                color: EmberColors.primaryAmber,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
