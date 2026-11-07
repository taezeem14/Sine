import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PerformanceSnapshot {
  final double currentFps;
  final double averageFps;
  final double low1PercentFps;
  final int totalFrames;
  final int droppedFrames;
  final double jankPercentage;
  final double lastBuildMs;
  final double lastRasterMs;
  final double lastTotalSpanMs;
  final double targetRefreshRate;

  const PerformanceSnapshot({
    this.currentFps = 60.0,
    this.averageFps = 60.0,
    this.low1PercentFps = 58.0,
    this.totalFrames = 0,
    this.droppedFrames = 0,
    this.jankPercentage = 0.0,
    this.lastBuildMs = 0.0,
    this.lastRasterMs = 0.0,
    this.lastTotalSpanMs = 0.0,
    this.targetRefreshRate = 120.0,
  });
}

class PerformanceService {
  static final PerformanceService instance = PerformanceService._();
  PerformanceService._();

  static const int _maxFrameHistory = 120;
  final DoubleLinkedQueue<FrameTiming> _timingHistory = DoubleLinkedQueue<FrameTiming>();

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  final ValueNotifier<PerformanceSnapshot> snapshotNotifier = ValueNotifier(const PerformanceSnapshot());
  final ValueNotifier<bool> isHudVisibleNotifier = ValueNotifier(false);

  int _totalFrameCount = 0;
  int _droppedFrameCount = 0;
  double _targetRefreshRate = 120.0; // Standard modern Android 120Hz display

  void start() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void stop() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
  }

  void resetStats() {
    _timingHistory.clear();
    _totalFrameCount = 0;
    _droppedFrameCount = 0;
    snapshotNotifier.value = PerformanceSnapshot(targetRefreshRate: _targetRefreshRate);
  }

  void setHudVisible(bool visible) {
    isHudVisibleNotifier.value = visible;
  }

  void setTargetRefreshRate(double rate) {
    _targetRefreshRate = rate.clamp(60.0, 144.0);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_isMonitoring || timings.isEmpty) return;

    final frameBudgetMs = 1000.0 / _targetRefreshRate; // 8.33ms at 120Hz, 16.67ms at 60Hz

    for (final timing in timings) {
      _totalFrameCount++;
      _timingHistory.addLast(timing);
      if (_timingHistory.length > _maxFrameHistory) {
        _timingHistory.removeFirst();
      }

      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;

      // Frame dropped if build + raster exceeds budget + 2ms buffer
      if (buildMs + rasterMs > frameBudgetMs + 2.0) {
        _droppedFrameCount++;
      }

      if (_totalFrameCount % 5 == 0) {
        _updateSnapshot(lastBuild: buildMs, lastRaster: rasterMs, lastTotal: totalMs);
      }
    }
  }

  void _updateSnapshot({
    required double lastBuild,
    required double lastRaster,
    required double lastTotal,
  }) {
    if (_timingHistory.isEmpty) return;

    final historyList = _timingHistory.toList();
    final frameRates = <double>[];

    for (final timing in historyList) {
      final spanMicros = timing.totalSpan.inMicroseconds;
      if (spanMicros > 0) {
        final fps = (1000000.0 / spanMicros).clamp(10.0, _targetRefreshRate);
        frameRates.add(fps);
      }
    }

    final avgFps = frameRates.isNotEmpty
        ? (frameRates.reduce((a, b) => a + b) / frameRates.length).clamp(1.0, _targetRefreshRate)
        : 60.0;

    // 1% low calculation
    frameRates.sort();
    final low1Index = (frameRates.length * 0.01).floor().clamp(0, frameRates.length - 1);
    final low1Fps = frameRates.isNotEmpty ? frameRates[low1Index] : avgFps;

    final currentFps = frameRates.isNotEmpty ? frameRates.last : avgFps;
    final jankPct = _totalFrameCount > 0
        ? ((_droppedFrameCount / _totalFrameCount) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    snapshotNotifier.value = PerformanceSnapshot(
      currentFps: double.parse(currentFps.toStringAsFixed(1)),
      averageFps: double.parse(avgFps.toStringAsFixed(1)),
      low1PercentFps: double.parse(low1Fps.toStringAsFixed(1)),
      totalFrames: _totalFrameCount,
      droppedFrames: _droppedFrameCount,
      jankPercentage: double.parse(jankPct.toStringAsFixed(2)),
      lastBuildMs: double.parse(lastBuild.toStringAsFixed(2)),
      lastRasterMs: double.parse(lastRaster.toStringAsFixed(2)),
      lastTotalSpanMs: double.parse(lastTotal.toStringAsFixed(2)),
      targetRefreshRate: _targetRefreshRate,
    );
  }
}
