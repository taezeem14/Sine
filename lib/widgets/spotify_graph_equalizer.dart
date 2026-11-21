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
    // 1. Bass & Beats Presets
    SpotifyEqPreset(
      'Bass Boost',
      [6.0, 4.0, 1.5, 0.0, 0.0, 0.0],
      category: 'Bass & Beats',
      description: 'Maximum sub-bass slam for deep hip-hop and electronic basslines',
    ),
    SpotifyEqPreset(
      'Hip-Hop',
      [5.5, 4.0, 1.0, 1.0, 3.0, 3.0],
      category: 'Bass & Beats',
      description: 'Booming 808s and punchy beats with crisp snare and vocal presence',
    ),
    SpotifyEqPreset(
      'Dance',
      [4.5, 3.0, -1.0, 0.0, 3.0, 4.0],
      category: 'Bass & Beats',
      description: 'Energetic club kick drum with bright synthesizer presence',
    ),
    SpotifyEqPreset(
      'Electronic',
      [4.5, 2.5, 0.0, -1.0, 2.0, 4.5],
      category: 'Bass & Beats',
      description: 'Deep analog bass synthesis and sparkling electronic treble',
    ),
    SpotifyEqPreset(
      'Club',
      [5.0, 3.5, -0.5, 1.5, 3.5, 4.5],
      category: 'Bass & Beats',
      description: 'Loud party floor impact with wide dynamic resonance',
    ),
    SpotifyEqPreset(
      'Deep',
      [5.5, 3.5, 1.5, -1.0, -2.5, -4.0],
      category: 'Bass & Beats',
      description: 'Rich low-end warmth with softened high-frequency edge',
    ),
    SpotifyEqPreset(
      'Loudness',
      [6.0, 3.0, -1.0, 0.0, 2.0, 5.0],
      category: 'Bass & Beats',
      description: 'Dynamic low & high boost for rich, full sound at low listening volumes',
    ),
    SpotifyEqPreset(
      'Bass Reducer',
      [-5.0, -3.0, -1.0, 0.0, 0.0, 0.0],
      category: 'Bass & Beats',
      description: 'Tames overwhelming sub-bass to stop headphone and room vibration',
    ),

    // 2. Vocal & Clarity Presets
    SpotifyEqPreset(
      'Vocal Booster',
      [-2.0, 0.0, 3.0, 4.0, 2.0, -1.0],
      category: 'Vocal & Clarity',
      description: 'Brings singer vocals and lyrics right to the front of the mix',
    ),
    SpotifyEqPreset(
      'Vocal Air',
      [0.0, 0.5, 1.0, 2.0, 2.5, 2.0],
      category: 'Vocal & Clarity',
      description: 'Open, breathable high-register vocal shimmer without sibilance',
    ),
    SpotifyEqPreset(
      'Treble Booster',
      [-1.0, 0.0, 0.0, 2.0, 4.0, 6.0],
      category: 'Vocal & Clarity',
      description: 'Crystal-clear highs, cymbals, acoustic strings, and top-end brilliance',
    ),
    SpotifyEqPreset(
      'Acoustic',
      [1.0, 0.5, 0.5, 0.5, 1.2, 1.0],
      category: 'Vocal & Clarity',
      description: 'Pure organic acoustic balance for unplugged guitar and vocals',
    ),
    SpotifyEqPreset(
      'Spoken Word',
      [-4.0, -1.0, 3.0, 4.0, 2.0, -2.0],
      category: 'Vocal & Clarity',
      description: 'Optimized voice intelligibility for podcasts, interviews, and audiobooks',
    ),
    SpotifyEqPreset(
      'Treble Reducer',
      [0.0, 0.0, 0.0, -1.0, -3.0, -5.0],
      category: 'Vocal & Clarity',
      description: 'Softens fatiguing, harsh, or overly bright high frequencies',
    ),

    // 3. Acoustic & Mood Presets
    SpotifyEqPreset(
      'Flat',
      [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      category: 'Acoustic & Mood',
      description: 'Uncolored studio monitor reference curve (Zero coloration)',
    ),
    SpotifyEqPreset(
      'Rock',
      [5.0, 3.0, -1.0, 1.0, 3.0, 4.0],
      category: 'Acoustic & Mood',
      description: 'Driving electric guitars, punchy kick drum, and vocal cut',
    ),
    SpotifyEqPreset(
      'Pop',
      [3.0, 2.0, 2.0, 3.0, 2.0, 2.0],
      category: 'Acoustic & Mood',
      description: 'Polished commercial radio sound with punchy bass and smooth vocals',
    ),
    SpotifyEqPreset(
      'R&B',
      [5.5, 4.0, 1.0, 2.0, 3.0, 2.0],
      category: 'Acoustic & Mood',
      description: 'Warm soul bass grooves, intimate vocals, and lush instrumentation',
    ),
    SpotifyEqPreset(
      'Jazz',
      [3.0, 2.0, -1.0, 1.0, 2.0, 3.0],
      category: 'Acoustic & Mood',
      description: 'Natural warmth for upright bass, piano, brass, and brushed cymbals',
    ),
    SpotifyEqPreset(
      'Piano',
      [1.0, 2.0, 3.0, 2.0, 3.0, 2.0],
      category: 'Acoustic & Mood',
      description: 'Full grand piano acoustic body and delicate key harmonics',
    ),
    SpotifyEqPreset(
      'Lo-Fi',
      [-1.0, 2.0, 3.0, 1.0, -2.0, -4.0],
      category: 'Acoustic & Mood',
      description: 'Cozy tape-warmed midrange for chill beats and study sessions',
    ),
    SpotifyEqPreset(
      'Warm Tape',
      [2.0, 1.0, 0.0, 0.0, -1.0, -2.0],
      category: 'Acoustic & Mood',
      description: 'Subtle analog saturation with a smooth vintage top-end taper',
    ),
    SpotifyEqPreset(
      'Lounge',
      [2.0, 3.0, 1.0, -1.0, 0.0, -1.5],
      category: 'Acoustic & Mood',
      description: 'Smooth, relaxed ambient balance for effortless listening',
    ),
    SpotifyEqPreset(
      'Latin',
      [4.0, 2.0, 0.0, 0.0, 3.0, 4.0],
      category: 'Acoustic & Mood',
      description: 'Crisp percussion transients and expressive acoustic guitars',
    ),
    SpotifyEqPreset(
      'Small Speakers',
      [-3.0, 2.0, 4.0, 3.0, 3.0, 2.0],
      category: 'Acoustic & Mood',
      description: 'Optimized voice and rhythm clarity for phone or portable speakers',
    ),
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
  Offset? _pointerDownPos;
  String? _lastSyncedPreset;
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAudioSend = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastTappedBand;
  double? _pendingFlushGain;
  int? _pendingFlushBand;
  String _selectedCategory = 'All';
  final ValueNotifier<int> _graphRevision = ValueNotifier<int>(0);

  static Color get sineBlue => EmberColors.primaryBlue;
  static Color get sineBlueDark => EmberColors.primaryBlue;

  static const List<String> _categories = [
    'All',
    'Bass & Beats',
    'Vocal & Clarity',
    'Acoustic & Mood',
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
        for (int i = 0; i < 6; i++) {
          _currentGains[i] = _startGains[i] + (_targetGains[i] - _startGains[i]) * t;
        }
        // Only repaint the isolated graph CustomPaint — never rebuild the 25 preset rows per frame!
        _graphRevision.value++;
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
    _graphRevision.dispose();
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
    _currentGains = List.from(gains);
    _startGains = List.from(gains);
    _targetGains = List.from(gains);
    _graphRevision.value++;
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
    _currentGains[bandIndex] = 0.0;
    _targetGains[bandIndex] = 0.0;
    _startGains[bandIndex] = 0.0;
    _pendingFlushBand = null;
    _pendingFlushGain = null;
    _graphRevision.value++;
    _lastSyncedPreset = 'Custom';
    final player = context.read<PlayerProvider>();
    player.setBandGain(bandIndex, 0.0);
  }

  void _resetAllBands() {
    HapticFeedback.mediumImpact();
    _lastSyncedPreset = 'Flat';
    _startGains = List.from(_currentGains);
    _targetGains = List.filled(6, 0.0);
    _animController.forward(from: 0.0);
    final player = context.read<PlayerProvider>();
    player.setEqualizerPreset('Flat', presetGains: List.filled(6, 0.0));
  }

  int _resolveBandIndex(double dx, Size size) {
    const horizontalPadding = 24.0;
    final usableWidth = size.width - (horizontalPadding * 2);
    final colWidth = usableWidth / 5.0;
    final touchX = (dx - horizontalPadding).clamp(0.0, usableWidth);
    return (touchX / colWidth).round().clamp(0, 5);
  }

  /// Pointer DOWN handler: resolves active band and checks double-tap-to-zero EXCLUSIVELY here
  /// (never inside onPointerMove, which previously snapped dragged bands to 0.0 dB every alternate frame!).
  void _handlePointerDown(Offset localPos, Size size) {
    if (_animController.isAnimating) {
      _animController.stop();
    }

    final bandIndex = _resolveBandIndex(localPos.dx, size);
    _activeDragBand = bandIndex;
    _pointerDownPos = localPos;

    final now = DateTime.now();
    if (_lastTappedBand == bandIndex && now.difference(_lastTapTime).inMilliseconds < 280) {
      _resetBandToZero(bandIndex);
      _lastTappedBand = null;
      _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
      return;
    }
    _lastTappedBand = bandIndex;
    _lastTapTime = now;

    _updateGainFromY(bandIndex, localPos.dy, size, forceSend: true);
  }

  /// Pointer MOVE handler: smoothly tracks vertical drag at 120 FPS while throttling hardware DSP writes.
  void _handlePointerMove(Offset localPos, Size size) {
    final bandIndex = _activeDragBand;
    if (bandIndex == null) return;

    // Cancel double-tap state once user meaningfully drags (> 8px)
    if (_pointerDownPos != null && (localPos - _pointerDownPos!).distance > 8.0) {
      _lastTappedBand = null;
    }

    _updateGainFromY(bandIndex, localPos.dy, size, forceSend: false);
  }

  void _handlePointerRelease() {
    final band = _pendingFlushBand;
    final gain = _pendingFlushGain;
    _pendingFlushBand = null;
    _pendingFlushGain = null;
    _activeDragBand = null;
    _pointerDownPos = null;
    _graphRevision.value++;

    if (band != null && gain != null && mounted) {
      context.read<PlayerProvider>().setBandGain(band, gain);
    }
  }

  void _updateGainFromY(int bandIndex, double dy, Size size, {required bool forceSend}) {
    const verticalPadding = 28.0;
    final usableHeight = size.height - (verticalPadding * 2);
    final clampedY = (dy - verticalPadding).clamp(0.0, usableHeight);
    final normalized = 1.0 - (clampedY / usableHeight);
    final gain = ((normalized * 24.0) - 12.0).clamp(-12.0, 12.0);
    final roundedGain = (gain * 10).round() / 10.0;

    _currentGains[bandIndex] = roundedGain;
    _targetGains[bandIndex] = roundedGain;
    _startGains[bandIndex] = roundedGain;
    _graphRevision.value++;

    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds > 60) {
      _lastHaptic = now;
      HapticFeedback.lightImpact();
    }

    _lastSyncedPreset = 'Custom';
    if (forceSend || now.difference(_lastAudioSend).inMilliseconds >= 35) {
      _lastAudioSend = now;
      _pendingFlushBand = null;
      _pendingFlushGain = null;
      context.read<PlayerProvider>().setBandGain(bandIndex, roundedGain);
    } else {
      _pendingFlushBand = bandIndex;
      _pendingFlushGain = roundedGain;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Surgical selectors: avoid full-tree rebuilds on unrelated playback updates
    final activePreset = context.select<PlayerProvider, String>((p) => p.eqPreset);
    final isEqEnabled = context.select<PlayerProvider, bool>((p) => p.eqEnabled);
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
                        _handlePointerDown(e.localPosition, size);
                      },
                      onPointerMove: (e) {
                        if (_activeDragBand != null) {
                          _handlePointerMove(e.localPosition, size);
                        }
                      },
                      onPointerUp: (e) {
                        widget.onDragStateChanged?.call(false);
                        _handlePointerRelease();
                      },
                      onPointerCancel: (e) {
                        widget.onDragStateChanged?.call(false);
                        _handlePointerRelease();
                      },
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _graphRevision,
                          builder: (context, _, _) => CustomPaint(
                            size: size,
                            painter: _SpotifyEqPainter(
                              gains: List<double>.of(_currentGains),
                              activeBand: _activeDragBand,
                              strokeColor: isEqEnabled ? sineBlue : Colors.white.withValues(alpha: 0.35),
                              gradientDark: isEqEnabled ? sineBlueDark : Colors.white.withValues(alpha: 0.14),
                              isEnabled: isEqEnabled,
                            ),
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
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: sineBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: sineBlue.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  preset.category,
                                  style: TextStyle(
                                    color: sineBlue,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
  final bool isEnabled;

  _SpotifyEqPainter({
    required this.gains,
    required this.activeBand,
    required this.strokeColor,
    required this.gradientDark,
    this.isEnabled = true,
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

      // Zero-blur GPU shadow ring under knob (20x faster than Gaussian blur)
      canvas.drawCircle(
        pt.translate(0, 1.5),
        isDragged ? 12.5 : 10.5,
        Paint()..color = Colors.black.withValues(alpha: 0.42),
      );

      // Zero-blur radial glow halo if actively dragged
      if (isDragged) {
        canvas.drawCircle(
          pt,
          20.0,
          Paint()
            ..shader = RadialGradient(
              colors: [
                strokeColor.withValues(alpha: 0.45),
                strokeColor.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromCircle(center: pt, radius: 20.0)),
        );
      }

      // Crisp circular knob (dimmed gently when EQ bypassed)
      canvas.drawCircle(
        pt,
        isDragged ? 11.5 : 9.5,
        Paint()..color = isEnabled ? Colors.white : Colors.white.withValues(alpha: 0.55),
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
        oldDelegate.gradientDark != gradientDark ||
        oldDelegate.isEnabled != isEnabled;
  }
}
