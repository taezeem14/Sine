import 'package:flutter/material.dart';
import '../services/performance_service.dart';
import '../theme/ember_theme.dart';

class PerformanceHudOverlay extends StatelessWidget {
  final Widget child;

  const PerformanceHudOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: PerformanceService.instance.isHudVisibleNotifier,
          builder: (context, isVisible, _) {
            if (!isVisible) return const SizedBox.shrink();

            return Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              right: 12,
              child: ValueListenableBuilder<PerformanceSnapshot>(
                valueListenable: PerformanceService.instance.snapshotNotifier,
                builder: (context, snap, _) {
                  final isJankHigh = snap.jankPercentage > 5.0;
                  final fpsColor = snap.currentFps >= 55.0
                      ? EmberColors.primaryAmber
                      : (snap.currentFps >= 40.0 ? Colors.orangeAccent : EmberColors.error);

                  return IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isJankHigh
                              ? EmberColors.error.withValues(alpha: 0.8)
                              : EmberColors.primaryAmber.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: fpsColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${snap.currentFps.toStringAsFixed(0)} FPS',
                                style: TextStyle(
                                  color: fpsColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'avg ${snap.averageFps.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: EmberColors.textMuted,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'B:${snap.lastBuildMs.toStringAsFixed(1)}ms',
                                style: const TextStyle(
                                  color: EmberColors.textSecondary,
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'R:${snap.lastRasterMs.toStringAsFixed(1)}ms',
                                style: const TextStyle(
                                  color: EmberColors.textSecondary,
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (snap.droppedFrames > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'drop:${snap.droppedFrames}',
                                  style: TextStyle(
                                    color: isJankHigh ? EmberColors.error : EmberColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
