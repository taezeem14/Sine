import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';

class SpotifyEqPreset {
  final String name;
  final List<double> gains; // 6 standard bands: 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 15kHz
  final String category;
  final String description;

  const SpotifyEqPreset(
    this.name,
    this.gains, {
    this.category = 'Genre Classics',
    this.description = '',
  });
}

class SpotifyGraphEqualizer extends StatefulWidget {
  final ValueChanged<bool>? onDragStateChanged;

  const SpotifyGraphEqualizer({
    super.key,
    this.onDragStateChanged,
  });

  static const List<String> frequencyLabels = [
    '60 Hz',
    '150 Hz',
    '400 Hz',
    '1 kHz',
    '2.4 kHz',
    '15 kHz',
  ];

  static const List<SpotifyEqPreset> standardPresets = [
    // 1. AutoEq Studio Target Curves (Open-Source Jaakko Pasanen)
    SpotifyEqPreset(
      'AutoEq: Harman Target',
      [5.2, 2.8, -0.5, 0.2, 2.5, 4.2],
      category: 'AutoEq Studio',
      description: 'Gold-standard research acoustic curve for natural, spacious staging',
    ),
    SpotifyEqPreset(
      'AutoEq: Audiophile Neutral',
      [1.8, 0.5, 0.0, 0.2, 0.8, 1.2],
      category: 'AutoEq Studio',
      description: 'Diffuse-field calibrated flat monitor response',
    ),
    SpotifyEqPreset(
      'AutoEq: Harman Bass Boost',
      [6.5, 4.2, 0.8, -0.2, 1.5, 3.8],
      category: 'AutoEq Studio',
      description: 'Punchy low-shelf response with clean vocal headroom',
    ),
    SpotifyEqPreset(
      'AutoEq: Vocal Forward',
      [-1.5, 1.0, 3.5, 4.5, 2.2, -0.5],
      category: 'AutoEq Studio',
      description: 'Brings vocals and lead instruments up-front without sibilance',
    ),

    // 2. JamesDSP Acoustic DSP Models (TheJamesDSP / James34602)
    SpotifyEqPreset(
      'JamesDSP: Pure Clarity',
      [2.5, -1.0, 1.0, 3.0, 4.5, 5.5],
      category: 'JamesDSP Acoustic',
      description: 'Acoustic air, sparkle, and tight low-end resonance',
    ),
    SpotifyEqPreset(
      'JamesDSP: Bass Resonance',
      [6.8, 4.5, 1.0, 0.0, 1.5, 2.0],
      category: 'JamesDSP Acoustic',
      description: 'Deep sub-harmonic warmth with attenuated room boominess',
    ),
    SpotifyEqPreset(
      'JamesDSP: Tube Amp Warmth',
      [3.5, 2.0, 0.5, -0.5, -1.5, -3.0],
      category: 'JamesDSP Acoustic',
      description: 'Analog vacuum tube 2nd-order harmonic simulation',
    ),
    SpotifyEqPreset(
      'JamesDSP: Studio Master',
      [3.0, 1.5, -0.5, 1.2, 2.8, 3.5],
      category: 'JamesDSP Acoustic',
      description: 'Dynamic reference mastering profile for high-end headphones',
    ),

    // 3. Equalizer APO & ISO 226 Contours (jthedering)
    SpotifyEqPreset(
      'Equalizer APO: Loudness Contour',
      [6.0, 2.5, -1.5, -0.5, 2.0, 5.5],
      category: 'APO / Loudness',
      description: 'ISO 226 equal-loudness contour compensation for low-volume playback',
    ),
    SpotifyEqPreset(
      'Equalizer APO: Acoustic Space',
      [1.5, 0.5, 1.5, 2.5, 4.0, 6.0],
      category: 'APO / Loudness',
      description: 'Soundstage spatial widening with presence & brilliance lift',
    ),

    // 4. Genre Classics & Master Presets
    SpotifyEqPreset('Dance', [4.5, 3.0, -1.0, 0.0, 3.0, 4.0], category: 'Genre Classics'),
    SpotifyEqPreset('Deep', [5.5, 3.5, 1.5, -1.0, -2.5, -4.0], category: 'Genre Classics'),
    SpotifyEqPreset('Electronic', [4.5, 2.5, 0.0, -1.0, 2.0, 4.5], category: 'Genre Classics'),
    SpotifyEqPreset('Flat', [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], category: 'Genre Classics'),
    SpotifyEqPreset('Hip-Hop', [5.5, 4.0, 1.0, 1.0, 3.0, 3.0], category: 'Genre Classics'),
    SpotifyEqPreset('Jazz', [3.0, 2.0, -1.0, 1.0, 2.0, 3.0], category: 'Genre Classics'),
    SpotifyEqPreset('Latin', [4.0, 2.0, 0.0, 0.0, 3.0, 4.0], category: 'Genre Classics'),
    SpotifyEqPreset('Loudness', [6.0, 3.0, -1.0, 0.0, 2.0, 5.0], category: 'Genre Classics'),
    SpotifyEqPreset('Lounge', [2.0, 3.0, 1.0, -1.0, 0.0, -1.5], category: 'Genre Classics'),
    SpotifyEqPreset('Piano', [1.0, 2.0, 3.0, 2.0, 3.0, 2.0], category: 'Genre Classics'),
    SpotifyEqPreset('Pop', [3.0, 2.0, 2.0, 3.0, 2.0, 2.0], category: 'Genre Classics'),
    SpotifyEqPreset('R&B', [5.5, 4.0, 1.0, 2.0, 3.0, 2.0], category: 'Genre Classics'),
    SpotifyEqPreset('Rock', [5.0, 3.0, -1.0, 1.0, 3.0, 4.0], category: 'Genre Classics'),
    SpotifyEqPreset('Small Speakers', [-3.0, 2.0, 4.0, 3.0, 3.0, 2.0], category: 'Genre Classics'),
    SpotifyEqPreset('Spoken Word', [-4.0, -1.0, 3.0, 4.0, 2.0, -2.0], category: 'Genre Classics'),
    SpotifyEqPreset('Treble Booster', [-1.0, 0.0, 0.0, 2.0, 4.0, 6.0], category: 'Genre Classics'),
    SpotifyEqPreset('Treble Reducer', [0.0, 0.0, 0.0, -1.0, -3.0, -5.0], category: 'Genre Classics'),
    SpotifyEqPreset('Vocal Booster', [-2.0, 0.0, 3.0, 4.0, 2.0, -1.0], category: 'Genre Classics'),
    SpotifyEqPreset('Bass Boost', [6.0, 4.0, 1.5, 0.0, 0.0, 0.0], category: 'Genre Classics'),
    SpotifyEqPreset('Lo-Fi', [-1.0, 2.0, 3.0, 1.0, -2.0, -4.0], category: 'Genre Classics'),
  ];

  /// Fast case-insensitive helper to look up preset gains
  static List<double> getPresetGains(String presetName) {
    final lower = presetName.toLowerCase().trim();
    final matched = standardPresets.where((p) => p.name.toLowerCase().trim() == lower);
    if (matched.isNotEmpty) {
      return List<double>.from(matched.first.gains);
    }
    return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  }

  @override
  State<SpotifyGraphEqualizer> createState() => _SpotifyGraphEqualizerState();
}

class _SpotifyGraphEqualizerState extends State<SpotifyGraphEqualizer> with SingleTickerProviderStateMixin {
  late List<double> _currentGains;
  late List<double> _startGains;
  late List<double> _targetGains;
  late AnimationController _animController;
  int? _activeDragBand;
  String? _lastSyncedPreset;
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastTappedBand;
  String _selectedCategory = 'All';

  static Color get sineBlue => EmberColors.primaryBlue;
  static Color get sineBlueDark => EmberColors.primaryBlue;

  static const List<String> _categories = [
    'All',
    'AutoEq Studio',
    'JamesDSP Acoustic',
    'APO / Loudness',
    'Genre Classics',
  ];

  @override
  void initState() {
    super.initState();
    _currentGains = List.filled(6, 0.0);
    _startGains = List.filled(6, 0.0);
    _targetGains = List.filled(6, 0.0);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        final t = Curves.easeOutCubic.transform(_animController.value);
        setState(() {
          for (int i = 0; i < 6; i++) {
            _currentGains[i] = _startGains[i] + (_targetGains[i] - _startGains[i]) * t;
          }
        });
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFromPlayer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = Provider.of<PlayerProvider>(context, listen: false);
    if (_activeDragBand == null && _lastSyncedPreset != null && _lastSyncedPreset != player.eqPreset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeDragBand == null) _syncFromPlayer();
      });
    }
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
    final matched = SpotifyGraphEqualizer.standardPresets.where(
      (p) => p.name.toLowerCase().trim() == presetName.toLowerCase().trim(),
    );
    if (matched.isNotEmpty) {
      gains = List.from(matched.first.gains);
    } else if (player.bandGains.isNotEmpty) {
      gains = List.generate(6, (i) => player.bandGains[i] ?? 0.0);
    } else {
      gains = List.filled(6, 0.0);
    }

    _lastSyncedPreset = presetName;
    setState(() {
      _currentGains = List.from(gains);
      _startGains = List.from(gains);
      _targetGains = List.from(gains);
    });
  }

  void _selectPreset(SpotifyEqPreset preset) {
    HapticFeedback.selectionClick();
    final player = context.read<PlayerProvider>();
    _lastSyncedPreset = preset.name;

    _startGains = List.from(_currentGains);
    _targetGains = List.from(preset.gains);
    _animController.forward(from: 0.0);

    player.setEqualizerPreset(preset.name, presetGains: preset.gains);
  }

  void _resetBandToZero(int bandIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentGains[bandIndex] = 0.0;
      _targetGains[bandIndex] = 0.0;
      _startGains[bandIndex] = 0.0;
    });
    _lastSyncedPreset = 'Custom';
    final player = context.read<PlayerProvider>();
    player.setBandGain(bandIndex, 0.0);
  }

  void _resetAllBands() {
    HapticFeedback.mediumImpact();
    _startGains = List.from(_currentGains);
    _targetGains = List.filled(6, 0.0);
    _animController.forward(from: 0.0);
    final player = context.read<PlayerProvider>();
    player.setEqualizerPreset('Flat', presetGains: List.filled(6, 0.0));
  }

  void _handleTouch(Offset localPos, Size size) {
    if (_animController.isAnimating) {
      _animController.stop();
    }

    const horizontalPadding = 24.0;
    final usableWidth = size.width - (horizontalPadding * 2);
    final colWidth = usableWidth / 5.0;

    int bandIndex;
    if (_activeDragBand != null) {
      bandIndex = _activeDragBand!;
    } else {
      final touchX = (localPos.dx - horizontalPadding).clamp(0.0, usableWidth);
      bandIndex = (touchX / colWidth).round().clamp(0, 5);
      _activeDragBand = bandIndex;
    }

    // Check for double-tap on band node to reset to 0 dB
    final now = DateTime.now();
    if (_lastTappedBand == bandIndex && now.difference(_lastTapTime).inMilliseconds < 280) {
      _resetBandToZero(bandIndex);
      _lastTappedBand = null;
      _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
      return;
    }
    _lastTappedBand = bandIndex;
    _lastTapTime = now;

    _updateGainFromY(bandIndex, localPos.dy, size);
  }

  void _updateGainFromY(int bandIndex, double dy, Size size) {
    const verticalPadding = 28.0;
    final usableHeight = size.height - (verticalPadding * 2);
    final clampedY = (dy - verticalPadding).clamp(0.0, usableHeight);
    final normalized = 1.0 - (clampedY / usableHeight);
    final gain = ((normalized * 24.0) - 12.0).clamp(-12.0, 12.0);
    final roundedGain = (gain * 10).round() / 10.0;

    setState(() {
      _currentGains[bandIndex] = roundedGain;
      _targetGains[bandIndex] = roundedGain;
      _startGains[bandIndex] = roundedGain;
    });

    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds > 60) {
      _lastHaptic = now;
      HapticFeedback.lightImpact();
    }

    _lastSyncedPreset = 'Custom';
    final player = context.read<PlayerProvider>();
    player.setBandGain(bandIndex, roundedGain);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final activePreset = player.eqPreset;
    if (_activeDragBand == null && _lastSyncedPreset != null && _lastSyncedPreset != activePreset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeDragBand == null) _syncFromPlayer();
      });
    }

    final filteredPresets = _selectedCategory == 'All'
        ? SpotifyGraphEqualizer.standardPresets
        : SpotifyGraphEqualizer.standardPresets
            .where((p) => p.category == _selectedCategory)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Interactive Graph Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 205,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: sineBlue.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) {
                        widget.onDragStateChanged?.call(true);
                        _handleTouch(e.localPosition, size);
                      },
                      onPointerMove: (e) {
                        if (_activeDragBand != null) {
                          _handleTouch(e.localPosition, size);
                        }
                      },
                      onPointerUp: (e) {
                        widget.onDragStateChanged?.call(false);
                        if (mounted) setState(() => _activeDragBand = null);
                      },
                      onPointerCancel: (e) {
                        widget.onDragStateChanged?.call(false);
                        if (mounted) setState(() => _activeDragBand = null);
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: size,
                          painter: _SpotifyEqPainter(
                            gains: _currentGains,
                            activeBand: _activeDragBand,
                            strokeColor: sineBlue,
                            gradientDark: sineBlueDark,
                          ),
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

        const SizedBox(height: 10),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _categories.map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSel,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.black : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  ),
                  backgroundColor: const Color(0xFF1E1E24),
                  selectedColor: sineBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSel ? sineBlue : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // Presets Header & Reset
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRESETS (${filteredPresets.length})',
                style: TextStyle(
                  color: EmberColors.textMuted.withValues(alpha: 0.8),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (activePreset == 'Custom') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: sineBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sineBlue.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Custom Curve',
                        style: TextStyle(
                          color: sineBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  InkWell(
                    onTap: _resetAllBands,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Reset to Flat',
                        style: TextStyle(
                          color: EmberColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Vertical List of Presets
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredPresets.length,
          itemBuilder: (context, index) {
            final preset = filteredPresets[index];
            final isSelected = activePreset.toLowerCase().trim() == preset.name.toLowerCase().trim();

            return InkWell(
              onTap: () => _selectPreset(preset),
              splashColor: sineBlue.withValues(alpha: 0.12),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                preset.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFFE0E0E0),
                                  fontSize: 15.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              if (preset.category.contains('AutoEq') || preset.category.contains('JamesDSP') || preset.category.contains('APO')) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: sineBlue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: sineBlue.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    preset.category.split(' ').first,
                                    style: TextStyle(
                                      color: sineBlue,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (preset.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              preset.description,
                              style: TextStyle(
                                color: EmberColors.textMuted.withValues(alpha: 0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        color: sineBlue,
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
      ..color = Colors.white.withValues(alpha: 0.08)
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
          gradientDark.withValues(alpha: 0.35),
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

    // 7. Draw circular white draggable control knobs with floating dB readout
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
          17.0,
          Paint()
            ..color = strokeColor.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
        );
      }

      // Pure white circular knob
      canvas.drawCircle(
        pt,
        isDragged ? 11.5 : 9.5,
        Paint()..color = Colors.white,
      );

      // Floating dB readout bubble directly above the active dragged knob
      if (isDragged) {
        final gainVal = gains[i];
        final gainText = '${gainVal > 0 ? "+${gainVal.toStringAsFixed(1)}" : gainVal.toStringAsFixed(1)} dB';
        final textSpan = TextSpan(
          text: gainText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final bubbleCenter = pt.translate(0, -26);
        final bubbleRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: bubbleCenter,
            width: tp.width + 12,
            height: tp.height + 6,
          ),
          const Radius.circular(6),
        );

        canvas.drawRRect(
          bubbleRect,
          Paint()..color = const Color(0xFF1E1E24),
        );
        canvas.drawRRect(
          bubbleRect,
          Paint()
            ..color = strokeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        tp.paint(canvas, bubbleCenter.translate(-tp.width / 2, -tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpotifyEqPainter oldDelegate) {
    return !listEquals(oldDelegate.gains, gains) ||
        oldDelegate.activeBand != activeBand ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.gradientDark != gradientDark;
  }
}
