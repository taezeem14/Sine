import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';

class SpotifyEqPreset {
  final String name;
  final List<double> gains; // 6 standard bands: 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 15kHz

  const SpotifyEqPreset(this.name, this.gains);
}

class SpotifyGraphEqualizer extends StatefulWidget {
  const SpotifyGraphEqualizer({super.key});

  static const List<String> frequencyLabels = [
    '60 Hz',
    '150 Hz',
    '400 Hz',
    '1 kHz',
    '2.4 kHz',
    '15 kHz',
  ];

  static const List<SpotifyEqPreset> standardPresets = [
    SpotifyEqPreset('Dance', [4.5, 3.0, -1.0, 0.0, 3.0, 4.0]),
    SpotifyEqPreset('Deep', [5.5, 3.5, 1.5, -1.0, -2.5, -4.0]),
    SpotifyEqPreset('Electronic', [4.5, 2.5, 0.0, -1.0, 2.0, 4.5]),
    SpotifyEqPreset('Flat', [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
    SpotifyEqPreset('Hip-Hop', [5.5, 4.0, 1.0, 1.0, 3.0, 3.0]),
    SpotifyEqPreset('Jazz', [3.0, 2.0, -1.0, 1.0, 2.0, 3.0]),
    SpotifyEqPreset('Latin', [4.0, 2.0, 0.0, 0.0, 3.0, 4.0]),
    SpotifyEqPreset('Loudness', [6.0, 3.0, -1.0, 0.0, 2.0, 5.0]),
    SpotifyEqPreset('Lounge', [2.0, 3.0, 1.0, -1.0, 0.0, -1.5]),
    SpotifyEqPreset('Piano', [1.0, 2.0, 3.0, 2.0, 3.0, 2.0]),
    SpotifyEqPreset('Pop', [3.0, 2.0, 2.0, 3.0, 2.0, 2.0]),
    SpotifyEqPreset('R&B', [5.5, 4.0, 1.0, 2.0, 3.0, 2.0]),
    SpotifyEqPreset('Rock', [5.0, 3.0, -1.0, 1.0, 3.0, 4.0]),
    SpotifyEqPreset('Small Speakers', [-3.0, 2.0, 4.0, 3.0, 3.0, 2.0]),
    SpotifyEqPreset('Spoken Word', [-4.0, -1.0, 3.0, 4.0, 2.0, -2.0]),
    SpotifyEqPreset('Treble Booster', [-1.0, 0.0, 0.0, 2.0, 4.0, 6.0]),
    SpotifyEqPreset('Treble Reducer', [0.0, 0.0, 0.0, -1.0, -3.0, -5.0]),
    SpotifyEqPreset('Vocal Booster', [-2.0, 0.0, 3.0, 4.0, 2.0, -1.0]),
    SpotifyEqPreset('Bass Boost', [6.0, 4.0, 1.5, 0.0, 0.0, 0.0]),
    SpotifyEqPreset('Lo-Fi', [-1.0, 2.0, 3.0, 1.0, -2.0, -4.0]),
  ];

  @override
  State<SpotifyGraphEqualizer> createState() => _SpotifyGraphEqualizerState();
}

class _SpotifyGraphEqualizerState extends State<SpotifyGraphEqualizer> with SingleTickerProviderStateMixin {
  late List<double> _currentGains;
  late List<double> _targetGains;
  late AnimationController _animController;
  int? _activeDragBand;
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  static const Color spotifyGreen = Color(0xFF1ED760);
  static const Color spotifyGreenDark = Color(0xFF1DB954);

  @override
  void initState() {
    super.initState();
    _currentGains = List.filled(6, 0.0);
    _targetGains = List.filled(6, 0.0);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_animController.value);
        setState(() {
          for (int i = 0; i < 6; i++) {
            _currentGains[i] = _currentGains[i] + (_targetGains[i] - _currentGains[i]) * t;
          }
        });
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromPlayer();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _syncFromPlayer() {
    final player = context.read<PlayerProvider>();
    final presetName = player.eqPreset;

    List<double> gains;
    final matched = SpotifyGraphEqualizer.standardPresets.where((p) => p.name.toLowerCase() == presetName.toLowerCase());
    if (matched.isNotEmpty) {
      gains = List.from(matched.first.gains);
    } else if (player.bandGains.isNotEmpty) {
      gains = List.generate(6, (i) => player.bandGains[i] ?? 0.0);
    } else {
      gains = List.filled(6, 0.0);
    }

    setState(() {
      _currentGains = List.from(gains);
      _targetGains = List.from(gains);
    });
  }

  void _selectPreset(SpotifyEqPreset preset) {
    HapticFeedback.selectionClick();
    final player = context.read<PlayerProvider>();

    _targetGains = List.from(preset.gains);
    _animController.forward(from: 0.0);

    player.setEqualizerPreset(preset.name);
    for (int i = 0; i < preset.gains.length; i++) {
      player.setBandGain(i, preset.gains[i]);
    }
  }

  void _handlePan(Offset localPos, Size size) {
    const horizontalPadding = 24.0;
    final usableWidth = size.width - (horizontalPadding * 2);
    final colWidth = usableWidth / 5.0;

    final touchX = (localPos.dx - horizontalPadding).clamp(0.0, usableWidth);
    final bandIndex = (touchX / colWidth).round().clamp(0, 5);

    // Calculate gain from vertical position (-12 dB to +12 dB)
    const verticalPadding = 28.0;
    final usableHeight = size.height - (verticalPadding * 2);
    final clampedY = (localPos.dy - verticalPadding).clamp(0.0, usableHeight);
    final normalized = 1.0 - (clampedY / usableHeight); // 0.0 at bottom, 1.0 at top
    final gain = ((normalized * 24.0) - 12.0).clamp(-12.0, 12.0);

    final roundedGain = (gain * 10).round() / 10.0;

    setState(() {
      _activeDragBand = bandIndex;
      _currentGains[bandIndex] = roundedGain;
      _targetGains[bandIndex] = roundedGain;
    });

    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds > 60) {
      _lastHaptic = now;
      HapticFeedback.lightImpact();
    }

    final player = context.read<PlayerProvider>();
    player.setBandGain(bandIndex, roundedGain);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final activePreset = player.eqPreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Interactive Graph Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 195,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (d) => _handlePan(d.localPosition, size),
                      onPanUpdate: (d) => _handlePan(d.localPosition, size),
                      onPanEnd: (_) => setState(() => _activeDragBand = null),
                      onPanCancel: () => setState(() => _activeDragBand = null),
                      child: CustomPaint(
                        size: size,
                        painter: _SpotifyEqPainter(
                          gains: _currentGains,
                          activeBand: _activeDragBand,
                          strokeColor: spotifyGreen,
                          gradientDark: spotifyGreenDark,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Frequency Labels
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: SpotifyGraphEqualizer.frequencyLabels.map((lbl) {
                    return Text(
                      lbl,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Presets Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRESETS',
                style: TextStyle(
                  color: EmberColors.textMuted.withValues(alpha: 0.8),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (activePreset == 'Custom')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: spotifyGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: spotifyGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Custom Curve',
                    style: TextStyle(
                      color: spotifyGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Vertical List of Presets (Identical to Spotify's Equalizer list in user's image)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: SpotifyGraphEqualizer.standardPresets.length,
          itemBuilder: (context, index) {
            final preset = SpotifyGraphEqualizer.standardPresets[index];
            final isSelected = activePreset.toLowerCase() == preset.name.toLowerCase();

            return InkWell(
              onTap: () => _selectPreset(preset),
              splashColor: spotifyGreen.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      preset.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFE0E0E0),
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check,
                        color: spotifyGreen,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SpotifyEqPainter extends CustomPainter {
  final List<double> gains;
  final int? activeBand;
  final Color strokeColor;
  final Color gradientDark;

  _SpotifyEqPainter({
    required this.gains,
    required this.activeBand,
    required this.strokeColor,
    required this.gradientDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gains.length < 2) return;

    const horizontalPadding = 24.0;
    const verticalPadding = 28.0;
    final usableWidth = size.width - (horizontalPadding * 2);
    final usableHeight = size.height - (verticalPadding * 2);
    final colWidth = usableWidth / (gains.length - 1);

    // 1. Draw subtle vertical frequency track guide lines
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    for (int i = 0; i < gains.length; i++) {
      final x = horizontalPadding + (i * colWidth);
      canvas.drawLine(
        Offset(x, verticalPadding),
        Offset(x, size.height - verticalPadding + 10),
        guidePaint,
      );
    }

    // 2. Center 0 dB subtle horizontal guideline
    final zeroLineY = verticalPadding + (usableHeight / 2);
    final zeroPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(horizontalPadding - 8, zeroLineY),
      Offset(size.width - horizontalPadding + 8, zeroLineY),
      zeroPaint,
    );

    // 3. Compute control points (x, y) for each frequency band
    final points = <Offset>[];
    for (int i = 0; i < gains.length; i++) {
      final x = horizontalPadding + (i * colWidth);
      final normalizedGain = (gains[i].clamp(-12.0, 12.0) + 12.0) / 24.0;
      final y = size.height - verticalPadding - (normalizedGain * usableHeight);
      points.add(Offset(x, y));
    }

    // 4. Generate smooth Monotone/Cubic Bezier curve through all points
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      // Smooth control points
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // 5. Draw filled gradient area under the curve
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height - verticalPadding + 14);
    fillPath.lineTo(points.first.dx, size.height - verticalPadding + 14);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          strokeColor.withValues(alpha: 0.75),
          gradientDark.withValues(alpha: 0.40),
          const Color(0xFF141414).withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // 6. Draw bright stroke line
    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // 7. Draw circular white draggable control knobs at each frequency point
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isDragged = activeBand == i;

      // Soft shadow under knob
      canvas.drawCircle(
        pt.translate(0, 2),
        isDragged ? 12.0 : 10.0,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );

      // Glow halo if actively dragged
      if (isDragged) {
        canvas.drawCircle(
          pt,
          16.0,
          Paint()
            ..color = strokeColor.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
        );
      }

      // Pure white circular knob
      canvas.drawCircle(
        pt,
        isDragged ? 11.5 : 9.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotifyEqPainter oldDelegate) {
    return oldDelegate.gains != gains || oldDelegate.activeBand != activeBand;
  }
}
