import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/player_provider.dart';
import '../widgets/spotify_graph_equalizer.dart';
import 'sound_shaping_sheet.dart';

/// Standalone Spotify 2026-grade Equalizer screen matching the Spotify layout
/// with electric blue Sine theme, interactive 6-band graph EQ, smooth Bezier curves,
/// full preset list with checkmarks, and integrated Hearth Bass Boost & Stem controls.
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EqualizerScreen()),
    );
  }

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  bool _showAdvancedShaping = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F), // True Spotify obsidian pitch-black
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0F),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Equalizer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: player.eqEnabled,
              activeThumbColor: const Color(0xFF00D4FF),
              activeTrackColor: const Color(0xFF00D4FF).withValues(alpha: 0.35),
              inactiveThumbColor: Colors.white.withValues(alpha: 0.6),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              onChanged: (val) {
                HapticFeedback.selectionClick();
                player.setEqualizerEnabled(val);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Status indicator if EQ is disabled
              if (!player.eqEnabled)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white.withValues(alpha: 0.6), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Equalizer is currently off. Toggle top switch to activate.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Interactive 6-Band Graph Equalizer with Electric Blue Theme
              const SpotifyGraphEqualizer(),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              ),
              const SizedBox(height: 14),

              // Quick Access Sound Shaping Accordion (Hearth Bass & Stem Isolation)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141418),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _showAdvancedShaping,
                      onExpansionChanged: (exp) => setState(() => _showAdvancedShaping = exp),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(FontAwesomeIcons.sliders, size: 13, color: Color(0xFF00D4FF)),
                      ),
                      title: const Text(
                        'Hearth Bass & Studio Stems',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Bass Boost: ${(player.bassBoost * 100).toInt()}% • Mode: ${player.isolationMode == IsolationMode.vocalsOnly ? "Acapella" : (player.isolationMode == IsolationMode.instrumentsOnly ? "Karaoke" : "Full Track")}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(color: Colors.white.withValues(alpha: 0.06)),
                              const SizedBox(height: 8),

                              // Bass Boost Slider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Hearth Bass Boost',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${(player.bassBoost * 100).toInt()}%',
                                    style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.5,
                                  activeTrackColor: const Color(0xFF00D4FF),
                                  thumbColor: Colors.white,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                                ),
                                child: Slider(
                                  value: player.bassBoost.clamp(0.0, 1.0),
                                  min: 0.0,
                                  max: 1.0,
                                  onChanged: (val) {
                                    player.setBassBoost(val);
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),
                              // Stem Isolation quick toggles
                              const Text(
                                'AI STEM ISOLATION',
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StemQuickCard(
                                      title: 'Vocals',
                                      subtitle: 'Acapella',
                                      icon: Icons.mic_rounded,
                                      isActive: player.isolationMode == IsolationMode.vocalsOnly,
                                      isLoading: player.isLoadingStem && player.isolationMode == IsolationMode.vocalsOnly,
                                      onTap: () => player.toggleIsolationMode(IsolationMode.vocalsOnly),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StemQuickCard(
                                      title: 'Karaoke',
                                      subtitle: 'Instrumental',
                                      icon: Icons.music_note_rounded,
                                      isActive: player.isolationMode == IsolationMode.instrumentsOnly,
                                      isLoading: player.isLoadingStem && player.isolationMode == IsolationMode.instrumentsOnly,
                                      onTap: () => player.toggleIsolationMode(IsolationMode.instrumentsOnly),
                                    ),
                                  ),
                                ],
                              ),
                              if (player.isolationMode != IsolationMode.none) ...[
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.restore_rounded, size: 14, color: Color(0xFF00D4FF)),
                                    label: const Text(
                                      'Revert to Original Audio',
                                      style: TextStyle(color: Color(0xFF00D4FF), fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    onPressed: () => player.revertToOriginalTrack(),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    SoundShapingSheet.show(context);
                                  },
                                  child: const Text(
                                    'Open Full Sound Shaping Studio →',
                                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StemQuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _StemQuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF00D4FF).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF00D4FF).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF)),
              )
            else
              Icon(
                icon,
                size: 16,
                color: isActive ? const Color(0xFF00D4FF) : Colors.white.withValues(alpha: 0.6),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isActive ? const Color(0xFF00D4FF) : Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
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
    );
  }
}
