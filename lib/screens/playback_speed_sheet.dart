import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';

/// YouTube-style adjustable playback speed sheet with fine-tuning slider and standard presets
class PlaybackSpeedSheet extends StatelessWidget {
  const PlaybackSpeedSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PlaybackSpeedSheet(),
    );
  }

  static const List<double> _youtubePresets = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSpeed = player.speed;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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

            // Header
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
                        child: const FaIcon(
                          FontAwesomeIcons.gaugeHigh,
                          size: 16,
                          color: EmberColors.primaryAmber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playback Speed',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: EmberColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'YouTube-style speed control with DSP pitch preservation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: EmberColors.textMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: (currentSpeed - 1.0).abs() < 0.01 ? null : () => player.setSpeed(1.0),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Normal (1.0x)',
                    style: TextStyle(
                      color: (currentSpeed - 1.0).abs() < 0.01 ? EmberColors.textMuted : EmberColors.primaryAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Big Speed Display Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: EmberColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (currentSpeed - 1.0).abs() > 0.01
                        ? EmberColors.primaryAmber.withValues(alpha: 0.4)
                        : EmberColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  (currentSpeed - 1.0).abs() < 0.01 ? '1.0x • Normal' : '${currentSpeed.toStringAsFixed(2)}x',
                  style: TextStyle(
                    color: (currentSpeed - 1.0).abs() > 0.01 ? EmberColors.primaryAmberHi : EmberColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Continuous Fine-Tuning Slider (0.25x - 2.0x, step 0.05x)
            Row(
              children: [
                const Text(
                  '0.25x',
                  style: TextStyle(color: EmberColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: EmberColors.primaryAmber,
                      inactiveTrackColor: EmberColors.outlineVariant.withValues(alpha: 0.4),
                      thumbColor: EmberColors.primaryAmberHi,
                      overlayColor: EmberColors.primaryAmber.withValues(alpha: 0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    ),
                    child: Slider(
                      value: currentSpeed.clamp(0.25, 2.0),
                      min: 0.25,
                      max: 2.0,
                      divisions: 35, // 0.05 step
                      onChanged: (val) {
                        final rounded = (val * 100).round() / 100.0;
                        player.setSpeed(rounded);
                      },
                    ),
                  ),
                ),
                const Text(
                  '2.0x',
                  style: TextStyle(color: EmberColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // YouTube Preset Chips
            const Text(
              'PRESETS',
              style: TextStyle(
                color: EmberColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _youtubePresets.map((preset) {
                final isSelected = (currentSpeed - preset).abs() < 0.02;
                final label = preset == 1.0 ? 'Normal' : '${preset}x';

                return InkWell(
                  onTap: () => player.setSpeed(preset),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? EmberColors.primaryAmber.withValues(alpha: 0.2)
                          : EmberColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? EmberColors.primaryAmber : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? EmberColors.primaryAmberHi : EmberColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
