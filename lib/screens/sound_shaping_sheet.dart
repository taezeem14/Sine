import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/spotify_graph_equalizer.dart';

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
  double? _localBassBoost;
  DateTime _lastBassSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final player = Provider.of<PlayerProvider>(context, listen: false);
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
                            color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const FaIcon(FontAwesomeIcons.sliders, size: 16, color: EmberColors.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sound Shaping & DSP',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: EmberColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Acoustic Limiter, Hardware EQ & Pitch',
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
                          });
                          player.resetEqualizer();
                          player.setPitchSemitones(0);
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
                        activeTrackColor: EmberColors.primaryBlue,
                        onChanged: (val) => player.setEqualizerEnabled(val),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // AI SOTA & Studio Stem Isolation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'AI SOTA & STUDIO STEM ISOLATION',
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EmberColors.primaryBlue.withValues(alpha: 0.5), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: EmberColors.primaryBlue.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (player.isLoadingStem) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2, color: EmberColors.primaryBlue),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            player.stemStatusBadgeText!,
                            style: const TextStyle(
                              color: EmberColors.primaryBlueHi,
                              fontSize: 10.5,
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
                      subtitle: 'AI acapella & studio vocals',
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
                      subtitle: 'AI karaoke & backing tracks',
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
                          Icon(Icons.restore_rounded, size: 14, color: EmberColors.primaryBlue),
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
              const SizedBox(height: 18),

              // Bass Boost / Sub-Warmth Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hearth Bass Boost', style: TextStyle(color: EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${((_localBassBoost ?? player.bassBoost) * 100).toInt()}%', style: const TextStyle(color: EmberColors.primaryBlueHi, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: EmberColors.primaryBlue,
                  thumbColor: EmberColors.primaryBlueHi,
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

              const SizedBox(height: 14),
              const Divider(color: EmberColors.outlineVariant, height: 1),
              const SizedBox(height: 14),

              // Spotify-Style Interactive Graph Equalizer & Presets
              const SpotifyGraphEqualizer(),

              const SizedBox(height: 16),
              const Divider(color: EmberColors.outlineVariant, height: 1),
              const SizedBox(height: 16),

              // Pitch Transpose Section (Metrolist -6 to +6 semitones)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(FontAwesomeIcons.music, size: 13, color: EmberColors.primaryBlue),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pitch Transpose (${player.pitchSemitones > 0 ? "+${player.pitchSemitones}" : "${player.pitchSemitones}"} st)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: EmberColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: player.pitchSemitones == 0 ? null : () => player.setPitchSemitones(0),
                    child: Text(
                      'Original Key',
                      style: TextStyle(
                        color: player.pitchSemitones == 0 ? EmberColors.textMuted : EmberColors.primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: EmberColors.primaryBlue,
                  inactiveTrackColor: EmberColors.surfaceContainerHigh,
                  thumbColor: EmberColors.primaryBlueHi,
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: player.pitchSemitones.toDouble().clamp(-6.0, 6.0),
                  min: -6.0,
                  max: 6.0,
                  divisions: 12,
                  label: player.pitchSemitones == 0 ? 'Original (0 st)' : '${player.pitchSemitones > 0 ? "+${player.pitchSemitones}" : "${player.pitchSemitones}"} st',
                  onChanged: (val) {
                    player.setPitchSemitones(val.round());
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [-3, -2, -1, 0, 1, 2, 3].map((st) {
                    final isSelected = player.pitchSemitones == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(st == 0 ? '0 (Key)' : (st > 0 ? '+$st' : '$st')),
                        selected: isSelected,
                        selectedColor: EmberColors.primaryBlue.withValues(alpha: 0.25),
                        backgroundColor: EmberColors.surfaceContainerLow,
                        labelStyle: TextStyle(
                          color: isSelected ? EmberColors.primaryBlue : EmberColors.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: isSelected ? EmberColors.primaryBlue : EmberColors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        onSelected: (_) {
                          player.setPitchSemitones(st);
                          HapticFeedback.lightImpact();
                        },
                      ),
                    );
                  }).toList(),
                ),
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
                          color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(FontAwesomeIcons.gaugeHigh, size: 14, color: EmberColors.primaryBlue),
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
                        color: player.speed == 1.0 ? EmberColors.textMuted : EmberColors.primaryBlue,
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
                        activeTrackColor: EmberColors.primaryBlue,
                        inactiveTrackColor: EmberColors.outlineVariant.withValues(alpha: 0.4),
                        thumbColor: EmberColors.primaryBlueHi,
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

              const SizedBox(height: 16),
              const Divider(color: EmberColors.outlineVariant, height: 1),
              const SizedBox(height: 16),

              // ReplayGain Volume Normalization Card (Metrolist / Audile EBU R128 standard)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EmberColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.equalizer_rounded, color: EmberColors.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ReplayGain Volume Leveler',
                            style: TextStyle(
                              color: EmberColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target: -14 LUFS (EBU R128) • Seamless volume balance without digital distortion',
                            style: TextStyle(
                              color: EmberColors.textMuted.withValues(alpha: 0.9),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: player.volumeNormalizationEnabled,
                      activeTrackColor: EmberColors.primaryBlue,
                      onChanged: (val) => player.setVolumeNormalizationEnabled(val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [
                      Color(0x3300D4FF),
                      Color(0x1A2979FF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive ? null : EmberColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? EmberColors.primaryBlue
                  : EmberColors.outlineVariant.withValues(alpha: 0.6),
              width: isActive ? 1.6 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: EmberColors.primaryBlue.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
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
                          ? EmberColors.primaryBlue.withValues(alpha: 0.25)
                          : EmberColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 15,
                      color: isActive ? EmberColors.primaryBlue : EmberColors.textSecondary,
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: EmberColors.primaryBlue),
                    )
                  else if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI ACTIVE',
                        style: TextStyle(
                          color: Colors.black,
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
                  color: isActive ? EmberColors.primaryBlueHi : EmberColors.textPrimary,
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
                  color: isActive ? EmberColors.primaryBlue.withValues(alpha: 0.85) : EmberColors.textMuted,
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
