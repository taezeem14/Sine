import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/upi_donation_view.dart';
import 'equalizer_screen.dart';
import 'diagnostics_log_screen.dart';
import 'app_lock_screen.dart';
import '../services/app_lock_service.dart';
import '../constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  final int initialTab;
  const SettingsScreen({super.key, this.initialTab = 0});

  static void show(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SettingsScreen(initialTab: initialTab),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: EmberColors.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EmberColors.primaryAmber.withValues(alpha: 0.16),
                    ),
                    child: const FaIcon(FontAwesomeIcons.gear, color: EmberColors.primaryAmber, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Settings & About',
                      style: TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: EmberColors.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: EmberColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: EmberColors.primaryAmber,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: EmberColors.primaryAmber.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: EmberColors.obsidianBase,
                unselectedLabelColor: EmberColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.sliders, size: 13),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.heart, size: 13),
                        SizedBox(width: 8),
                        Text('Donate (UPI)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: EmberColors.outlineVariant, height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SettingsContent(
                    scrollController: scrollController,
                    onNavigateToDonate: () => _tabController.animateTo(1),
                  ),
                  UpiDonationView(scrollController: scrollController),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class SettingsContent extends StatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback? onNavigateToDonate;

  const SettingsContent({super.key, this.scrollController, this.onNavigateToDonate});

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadLockStatus();
  }

  Future<void> _loadLockStatus() async {
    final enabled = await AppLockService.isLockEnabled();
    if (mounted) setState(() => _isLockEnabled = enabled);
  }

  Future<void> _toggleLock(bool enable) async {
    if (enable) {
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(mode: AppLockMode.setupNew),
        ),
      );
      if (success == true) {
        _loadLockStatus();
      }
    } else {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(mode: AppLockMode.unlock),
        ),
      );
      if (verified == true) {
        await AppLockService.removePin();
        _loadLockStatus();
      }
    }
  }

  Future<void> _changePasscode() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AppLockScreen(mode: AppLockMode.unlock),
      ),
    );
    if (verified == true && mounted) {
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const AppLockScreen(mode: AppLockMode.setupNew),
        ),
      );
      if (success == true) {
        _loadLockStatus();
      }
    }
  }

  void _showAudioQualitySheet(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Audio Streaming Quality', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Select audio stream bitrate priority for YouTube NewPipe playback.', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                _buildOptionTile('High Bitrate (Audiophile)', 'WebM Opus (160+ kbps) & AAC (128 kbps)', player.audioQuality == 'high', () {
                  player.setAudioQuality('high');
                  Navigator.pop(context);
                }),
                _buildOptionTile('Medium (Balanced)', 'Fast hardware Muxed MP4 & AAC (128 kbps)', player.audioQuality == 'medium', () {
                  player.setAudioQuality('medium');
                  Navigator.pop(context);
                }),
                _buildOptionTile('Data Saver (Low Bandwidth)', 'Low-bitrate Opus (50-70 kbps) for mobile data', player.audioQuality == 'dataSaver', () {
                  player.setAudioQuality('dataSaver');
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStemEngineSheet(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Neural Stem Separation Engine', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Prioritize AI models or local matching for Karaoke & Acapella isolation.', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                _buildOptionTile('Automatic SOTA (Recommended)', 'BS-RoFormer (12.97dB SDR) -> Demucs v4 -> Studio', player.stemEnginePreference == 'auto', () {
                  player.setStemEnginePreference('auto');
                  Navigator.pop(context);
                }),
                _buildOptionTile('Force BS-RoFormer Only', 'Exclusive world-record SDR neural space', player.stemEnginePreference == 'bsRoformer', () {
                  player.setStemEnginePreference('bsRoformer');
                  Navigator.pop(context);
                }),
                _buildOptionTile('Force Demucs v4 Only', 'Fast 4-source hybrid neural network', player.stemEnginePreference == 'demucs', () {
                  player.setStemEnginePreference('demucs');
                  Navigator.pop(context);
                }),
                _buildOptionTile('YouTube Studio Match Only', 'Bypass AI spaces; match verified backing tracks', player.stemEnginePreference == 'youtube', () {
                  player.setStemEnginePreference('youtube');
                  Navigator.pop(context);
                }),
                _buildOptionTile('DSP Hardware Only (Offline)', 'Zero network data; instant parametric vocal notch', player.stemEnginePreference == 'dsp', () {
                  player.setStemEnginePreference('dsp');
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRecoveryModeSheet(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Playback Session Recovery', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('How Sine handles previously active playback when the app is restarted.', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                _buildOptionTile('Prompt (Recommended)', 'Clean startup; show discrete "Resume" banner on Home', player.playbackRecoveryMode == 'prompt', () {
                  player.setPlaybackRecoveryMode('prompt');
                  Navigator.pop(context);
                }),
                _buildOptionTile('Always Direct Restore', 'Immediately restore queue and seek to exact second', player.playbackRecoveryMode == 'always', () {
                  player.setPlaybackRecoveryMode('always');
                  Navigator.pop(context);
                }),
                _buildOptionTile('Off (Clean Every Start)', 'Discard previous session; always start with clean player', player.playbackRecoveryMode == 'off', () {
                  player.setPlaybackRecoveryMode('off');
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? EmberColors.primaryAmber.withValues(alpha: 0.14) : EmberColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? EmberColors.primaryAmber : Colors.transparent),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, style: TextStyle(color: isSelected ? EmberColors.primaryAmberHi : EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: EmberColors.textMuted, fontSize: 11)),
        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: EmberColors.primaryAmber, size: 18) : null,
        onTap: onTap,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ==========================================
        // SOLE CREATOR & AUTHOR SPOTLIGHT CARD
        // ==========================================
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                EmberColors.primaryAmber.withValues(alpha: 0.18),
                EmberColors.surfaceContainerHigh.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: EmberColors.primaryAmber.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: EmberColors.primaryAmber.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EmberColors.primaryAmber,
                      boxShadow: [
                        BoxShadow(
                          color: EmberColors.primaryAmber.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.fire,
                        size: 26,
                        color: EmberColors.obsidianBase,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Muhammad Taezeem Tariq',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: EmberColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            FaIcon(
                              FontAwesomeIcons.solidCircleCheck,
                              color: EmberColors.primaryAmber,
                              size: 14,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: EmberColors.primaryAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Author & Creator',
                            style: TextStyle(
                              color: EmberColors.primaryAmberHi,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Sine was architected by Muhammad Taezeem Tariq (@taezeem14). Built with a deep obsession for pristine audio quality, zero ads, real-time lyrics, and high-fidelity YouTube audio extraction.',
                style: TextStyle(
                  color: EmberColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  FaIcon(FontAwesomeIcons.github, size: 14, color: EmberColors.textMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'github.com/taezeem14',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: EmberColors.primaryAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: widget.onNavigateToDonate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: EmberColors.primaryAmber,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: EmberColors.primaryAmber.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Support Taezeem via UPI (7006616470@fam)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: EmberColors.obsidianBase,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ==========================================
        // SECTION 0: CREATOR SUPPORT & DONATIONS
        // ==========================================
        const _SectionHeader(title: 'Creator Support & Donations'),
        _SettingsTile(
          icon: FontAwesomeIcons.indianRupeeSign,
          iconColor: EmberColors.primaryAmber,
          title: 'Donate via UPI (7006616470@fam)',
          subtitle: 'Support development directly using GPay, PhonePe, Paytm or FamPay',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.primaryAmber),
          onTap: widget.onNavigateToDonate,
        ),

        const SizedBox(height: 16),

        // ==========================================
        // SECTION: SECURITY & APP LOCK
        // ==========================================
        const _SectionHeader(title: 'Security & App Lock'),
        _SettingsTile(
          icon: FontAwesomeIcons.lock,
          iconColor: EmberColors.primaryBlue,
          title: 'App Lock Passcode',
          subtitle: _isLockEnabled ? 'Passcode active • Require 4-digit PIN on app launch' : 'Secure your Sine music player with a 4-digit PIN',
          trailing: Switch(
            value: _isLockEnabled,
            activeThumbColor: EmberColors.primaryBlue,
            onChanged: (val) => _toggleLock(val),
          ),
          onTap: () => _toggleLock(!_isLockEnabled),
        ),
        if (_isLockEnabled)
          _SettingsTile(
            icon: FontAwesomeIcons.key,
            title: 'Change Passcode',
            subtitle: 'Update your 4-digit security PIN',
            trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
            onTap: _changePasscode,
          ),

        const SizedBox(height: 16),

        // ==========================================
        // SECTION: HOME SCREEN WIDGETS
        // ==========================================
        const _SectionHeader(title: 'Android Home Screen Widgets'),
        const _SettingsTile(
          icon: FontAwesomeIcons.tableCellsLarge,
          iconColor: EmberColors.secondaryCyan,
          title: 'Sine Now Playing Widget (4x2)',
          subtitle: 'Control playback, view track title and artist directly from your home screen. Long-press home screen to add!',
          trailing: Text('Available', style: TextStyle(color: EmberColors.primaryBlueHi, fontSize: 11, fontWeight: FontWeight.bold)),
          onTap: null,
        ),

        const SizedBox(height: 16),

        // ==========================================
        // SECTION 1: AUDIO & SOUND SHAPING
        // ==========================================
        const _SectionHeader(title: 'Audio & Sound Engine'),
        _SettingsTile(
          icon: FontAwesomeIcons.sliders,
          title: 'Equalizer & Audio Shaping',
          subtitle: 'Preset: ${player.eqPreset} • Bass Boost: ${(player.bassBoost * 100).round()}%',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => EqualizerScreen.open(context),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.shieldHalved,
          iconColor: Colors.greenAccent,
          title: 'Audio Clipping Protection',
          subtitle: 'Dynamic digital headroom scaling prevents distortion & crackle during bass/vocal boosts',
          trailing: Switch(
            value: player.clippingProtectionEnabled,
            activeThumbColor: Colors.greenAccent,
            onChanged: (val) => player.setClippingProtection(val),
          ),
          onTap: () => player.setClippingProtection(!player.clippingProtectionEnabled),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.gaugeHigh,
          title: 'Audio Streaming Quality',
          subtitle: 'Bitrate: ${player.audioQuality.toUpperCase()} • High-res WebM Opus & AAC',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EmberColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: EmberColors.outlineVariant),
            ),
            child: Text(player.audioQuality.toUpperCase(), style: const TextStyle(color: EmberColors.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          onTap: () => _showAudioQualitySheet(context, player),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.brain,
          iconColor: EmberColors.primaryBlue,
          title: 'Neural Stem Engine Preference',
          subtitle: 'AI Model: ${player.stemEnginePreference.toUpperCase()} • SOTA Vocal & Backing Separation',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => _showStemEngineSheet(context, player),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.clockRotateLeft,
          iconColor: EmberColors.primaryAmber,
          title: 'Playback Session Recovery',
          subtitle: 'Mode: ${player.playbackRecoveryMode.toUpperCase()} • Reliable app restart recovery',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => _showRecoveryModeSheet(context, player),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.chartLine,
          iconColor: Colors.pinkAccent,
          title: 'Floating Performance HUD',
          subtitle: 'Display real-time 120 FPS & dropped frame monitor overlay across all screens',
          trailing: Switch(
            value: player.performanceHudEnabled,
            activeThumbColor: Colors.pinkAccent,
            onChanged: (val) => player.setPerformanceHudEnabled(val),
          ),
          onTap: () => player.setPerformanceHudEnabled(!player.performanceHudEnabled),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.shuffle,
          title: 'Crossfade Audio',
          subtitle: player.crossfadeSeconds > 0
              ? 'Overlap track transitions by ${player.crossfadeSeconds}s'
              : 'Off • Seamless direct transitions',
          trailing: SizedBox(
            width: 120,
            child: Slider(
              value: player.crossfadeSeconds.toDouble(),
              min: 0,
              max: 12,
              divisions: 12,
              activeColor: EmberColors.primaryBlue,
              inactiveColor: EmberColors.outlineVariant,
              label: player.crossfadeSeconds > 0 ? '${player.crossfadeSeconds}s' : 'Off',
              onChanged: (val) => player.setCrossfadeSeconds(val.toInt()),
            ),
          ),
          onTap: null,
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.arrowsLeftRight,
          title: 'Gapless Playback',
          subtitle: 'Eliminate pause between sequential tracks',
          trailing: Switch(
            value: player.gaplessPlayback,
            activeThumbColor: EmberColors.primaryBlue,
            onChanged: (val) => player.setGaplessPlayback(val),
          ),
          onTap: () => player.setGaplessPlayback(!player.gaplessPlayback),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.bolt,
          title: 'Autoplay Smart Radio',
          subtitle: 'Automatically queue recommended tracks when songs end',
          trailing: Switch(
            value: player.isAutoplayEnabled,
            activeThumbColor: EmberColors.primaryAmber,
            onChanged: (_) => player.toggleAutoplay(),
          ),
          onTap: () => player.toggleAutoplay(),
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.stop,
          iconColor: EmberColors.error,
          title: 'Cut Active Playback',
          subtitle: 'Immediately stop audio and dismiss the playing song',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () {
            final messenger = ScaffoldMessenger.of(context);
            player.stopPlayback();
            Navigator.of(context).pop();
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              const SnackBar(
                backgroundColor: EmberColors.surfaceContainerHigh,
                duration: Duration(seconds: 2),
                content: Text('Playback stopped & dismissed', style: TextStyle(color: EmberColors.textPrimary)),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // ==========================================
        // SECTION 2: STORAGE & CACHE
        // ==========================================
        const _SectionHeader(title: 'Storage & Database'),
                _SettingsTile(
          icon: FontAwesomeIcons.layerGroup,
          title: 'Deduplicate Active Queue',
          subtitle: 'Remove all duplicate tracks while preserving active playback',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () {
            player.deduplicateQueue();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: EmberColors.surfaceContainerHigh,
                duration: Duration(seconds: 2),
                content: Text('Active queue deduplicated cleanly!', style: TextStyle(color: EmberColors.primaryAmberHi)),
              ),
            );
          },
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.broom,
          title: 'Purge Placeholders & Clean Cache',
          subtitle: 'Eradicate legacy mock songs and clear temp audio cache',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              const SnackBar(
                backgroundColor: EmberColors.surfaceContainerHigh,
                duration: Duration(seconds: 1),
                content: Text('Cleaning storage and purging old cache...', style: TextStyle(color: EmberColors.primaryAmber)),
              ),
            );
            await player.purgePlaceholders();
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              const SnackBar(
                backgroundColor: EmberColors.surfaceContainerHigh,
                duration: Duration(seconds: 2),
                content: Text('Storage cleaned & cache flushed successfully!', style: TextStyle(color: EmberColors.primaryAmberHi)),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // ==========================================
        // SECTION 3: APP INFO & SYSTEM
        // ==========================================
        const _SectionHeader(title: 'System & Architecture'),
        const _SettingsTile(
          icon: FontAwesomeIcons.mobileScreen,
          title: 'Sine Version',
          subtitle: '${AppConstants.releaseTag} (Release Build)',
          trailing: Text(AppConstants.version, style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
          onTap: null,
        ),
        const _SettingsTile(
          icon: FontAwesomeIcons.music,
          iconColor: EmberColors.primaryAmber,
          title: 'NewPipe YouTube Audio Engine',
          subtitle: 'Hardware-accelerated Opus (160 kbps) & AAC (128 kbps) stream extraction',
          trailing: Text('Lossless/HD', style: TextStyle(color: EmberColors.primaryAmberHi, fontSize: 12, fontWeight: FontWeight.bold)),
          onTap: null,
        ),
        const _SettingsTile(
          icon: FontAwesomeIcons.shieldHeart,
          title: 'Open Source & Ad-Free',
          subtitle: 'No telemetry, zero third-party ads, strictly local storage',
          trailing: Text('100% Free', style: TextStyle(color: EmberColors.primaryAmber, fontSize: 12)),
          onTap: null,
        ),
        _SettingsTile(
          icon: FontAwesomeIcons.terminal,
          iconColor: EmberColors.primaryBlue,
          title: 'Diagnostics & Log Extractor',
          subtitle: 'Live ExoPlayer telemetry, candidate stream inspector & bug reporter',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsLogScreen()),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: EmberColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final FaIconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: EmberColors.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: EmberColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 16,
              color: iconColor ?? EmberColors.primaryAmber,
            ),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: EmberColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: EmberColors.textMuted,
            fontSize: 11,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
