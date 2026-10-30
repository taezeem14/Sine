import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';

class SoundShapingSheet extends StatefulWidget {
  const SoundShapingSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SoundShapingSheet(),
    );
  }

  @override
  State<SoundShapingSheet> createState() => _SoundShapingSheetState();
}

class _SoundShapingSheetState extends State<SoundShapingSheet> {
  Future<AndroidEqualizerParameters>? _parametersFuture;
  double? _localBassBoost;
  DateTime _lastBassSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final player = Provider.of<PlayerProvider>(context, listen: false);
    _parametersFuture = player.audioHandler.equalizer.parameters;
    _localBassBoost = player.bassBoost;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: EmberColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EmberColors.primaryAmber.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const FaIcon(FontAwesomeIcons.sliders, size: 16, color: EmberColors.primaryAmber),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sound Shaping & EQ',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: EmberColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Analog Warmth & Multi-Band DSP',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: EmberColors.textMuted,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _localBassBoost = null;
                            _parametersFuture = player.audioHandler.equalizer.parameters;
                          });
                          player.resetEqualizer();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Reset', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: player.eqEnabled,
                        activeTrackColor: EmberColors.primaryAmber,
                        onChanged: (val) => player.setEqualizerEnabled(val),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Studio Stem Isolation (YouTube Smart Stems + AI Demucs + DSP Fallback)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'STUDIO STEM ISOLATION & KARAOKE',
                      style: TextStyle(
                        color: EmberColors.textMuted,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (player.stemStatusBadgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EmberColors.primaryAmber.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (player.isLoadingStem) ...[
                            const SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: EmberColors.primaryAmber),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            player.stemStatusBadgeText!,
                            style: const TextStyle(
                              color: EmberColors.primaryAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _IsolationCard(
                      title: 'Vocals Only',
                      subtitle: 'Isolate voice (acapella)',
                      icon: Icons.mic_rounded,
                      isActive: player.isolationMode == IsolationMode.vocalsOnly,
                      isLoading: player.isLoadingStem && player.isolationMode == IsolationMode.vocalsOnly,
                      onTap: () => player.toggleIsolationMode(IsolationMode.vocalsOnly),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _IsolationCard(
                      title: 'Instruments Only',
                      subtitle: 'Remove voice (karaoke)',
                      icon: Icons.music_note_rounded,
                      isActive: player.isolationMode == IsolationMode.instrumentsOnly,
                      isLoading: player.isLoadingStem && player.isolationMode == IsolationMode.instrumentsOnly,
                      onTap: () => player.toggleIsolationMode(IsolationMode.instrumentsOnly),
                    ),
                  ),
                ],
              ),
              if (player.isolationMode != IsolationMode.none) ...[
                const SizedBox(height: 10),
                Center(
                  child: InkWell(
                    onTap: () => player.revertToOriginalTrack(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: EmberColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EmberColors.surfaceContainerHighest),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restore_rounded, size: 14, color: EmberColors.primaryAmber),
                          SizedBox(width: 6),
                          Text(
                            'Revert to Original Studio Track',
                            style: TextStyle(
                              color: EmberColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // Presets
              const Text('ACOUSTIC PROFILES', style: TextStyle(color: EmberColors.textMuted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in ['Warm Tape', 'Lo-Fi', 'Bass Boost', 'Vocal Air', 'Acoustic', 'Flat'])
                    ChoiceChip(
                      label: Text(p),
                      selected: player.eqPreset == p,
                      selectedColor: EmberColors.primaryAmber,
                      labelStyle: TextStyle(
                        color: player.eqPreset == p ? EmberColors.obsidianBase : EmberColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      backgroundColor: EmberColors.surfaceContainerLow,
                      onSelected: (_) {
                        setState(() {
                          _localBassBoost = null;
                          _parametersFuture = player.audioHandler.equalizer.parameters;
                        });
                        player.setEqualizerPreset(p);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Bass Boost / Sub-Warmth Slider (Throttled 50ms & instant local UI feedback)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hearth Bass Boost', style: TextStyle(color: EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${((_localBassBoost ?? player.bassBoost) * 100).toInt()}%', style: const TextStyle(color: EmberColors.primaryAmber, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: EmberColors.primaryAmber,
                  thumbColor: EmberColors.primaryAmberHi,
                  inactiveTrackColor: EmberColors.surfaceContainerHigh,
                ),
                child: Slider(
                  value: (_localBassBoost ?? player.bassBoost).clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() => _localBassBoost = val);
                    final now = DateTime.now();
                    if (now.difference(_lastBassSent).inMilliseconds >= 50) {
                      _lastBassSent = now;
                      player.setBassBoost(val);
                    }
                  },
                  onChangeEnd: (val) {
                    setState(() => _localBassBoost = val);
                    player.setBassBoost(val);
                  },
                ),
              ),

              const SizedBox(height: 16),
              // Multi-Band Frequency Sliders
              const Text('FREQUENCY BANDS', style: TextStyle(color: EmberColors.textMuted, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              FutureBuilder<AndroidEqualizerParameters>(
                future: _parametersFuture,
                builder: (context, snapshot) {
                  final params = snapshot.data;
                  if (params == null || params.bands.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.center,
                      child: const Text('Hardware equalizer ready on playback', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                    );
                  }

                  return Column(
                    children: [
                      for (int i = 0; i < params.bands.length; i++)
                        _BandSlider(
                          key: ValueKey('band_$i'),
                          band: params.bands[i],
                          minDecibels: params.minDecibels,
                          maxDecibels: params.maxDecibels,
                          onChanged: (gain) => player.setBandGain(i, gain),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: EmberColors.outlineVariant, height: 1),
              const SizedBox(height: 16),
              // Playback Speed Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: EmberColors.primaryAmber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(FontAwesomeIcons.gaugeHigh, size: 14, color: EmberColors.primaryAmber),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Playback Speed (${player.speed.toStringAsFixed(2)}x)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: EmberColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: player.speed == 1.0 ? null : () => player.setSpeed(1.0),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Normal',
                      style: TextStyle(
                        color: player.speed == 1.0 ? EmberColors.textMuted : EmberColors.primaryAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('0.25x', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: EmberColors.primaryAmber,
                        inactiveTrackColor: EmberColors.outlineVariant.withValues(alpha: 0.4),
                        thumbColor: EmberColors.primaryAmberHi,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: player.speed.clamp(0.25, 2.0),
                        min: 0.25,
                        max: 2.0,
                        divisions: 35,
                        onChanged: (val) {
                          final rounded = (val * 100).round() / 100.0;
                          player.setSpeed(rounded);
                        },
                      ),
                    ),
                  ),
                  const Text('2.0x', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BandSlider extends StatefulWidget {
  final AndroidEqualizerBand band;
  final double minDecibels;
  final double maxDecibels;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    super.key,
    required this.band,
    required this.minDecibels,
    required this.maxDecibels,
    required this.onChanged,
  });

  @override
  State<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends State<_BandSlider> {
  late double _gain;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _gain = widget.band.gain;
  }

  @override
  void didUpdateWidget(covariant _BandSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.band.gain != widget.band.gain) {
      _gain = widget.band.gain;
    }
  }

  @override
  Widget build(BuildContext context) {
    double freq = widget.band.centerFrequency;
    if (freq > 20000) {
      freq = freq / 1000.0;
    }
    final freqStr = freq >= 1000 ? '${(freq / 1000).toStringAsFixed(1)} kHz' : '${freq.round()} Hz';
    final minDb = widget.minDecibels.isFinite ? widget.minDecibels : -12.0;
    final maxDb = widget.maxDecibels.isFinite && widget.maxDecibels > minDb ? widget.maxDecibels : 12.0;
    final safeGain = _gain.isFinite ? _gain.clamp(minDb, maxDb) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text(
              freqStr,
              style: const TextStyle(color: EmberColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: EmberColors.primaryAmber,
                thumbColor: EmberColors.textPrimary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                inactiveTrackColor: EmberColors.surfaceContainerHigh,
              ),
              child: Slider(
                value: safeGain,
                min: minDb,
                max: maxDb,
                onChanged: (val) {
                  setState(() => _gain = val);
                  final now = DateTime.now();
                  if (now.difference(_lastSent).inMilliseconds >= 50) {
                    _lastSent = now;
                    widget.onChanged(val);
                  }
                },
                onChangeEnd: (val) {
                  setState(() => _gain = val);
                  widget.onChanged(val);
                },
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              _gain.abs() < 0.05
                  ? '0.0 dB'
                  : '${_gain > 0 ? '+' : ''}${_gain.toStringAsFixed(1)} dB',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: _gain.abs() > 0.5 ? EmberColors.primaryAmber : EmberColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IsolationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _IsolationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? EmberColors.primaryAmber.withValues(alpha: 0.14)
                : EmberColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? EmberColors.primaryAmber
                  : EmberColors.outlineVariant.withValues(alpha: 0.6),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isActive
                          ? EmberColors.primaryAmber.withValues(alpha: 0.25)
                          : EmberColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 15,
                      color: isActive ? EmberColors.primaryAmber : EmberColors.textSecondary,
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: EmberColors.primaryAmber),
                    )
                  else if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryAmber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: EmberColors.obsidianBase,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? EmberColors.primaryAmber : EmberColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isActive ? EmberColors.primaryAmberHi.withValues(alpha: 0.8) : EmberColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
