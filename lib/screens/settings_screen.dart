import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/upi_donation_view.dart';
import 'sound_shaping_sheet.dart';
import 'diagnostics_log_screen.dart';

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

class SettingsContent extends StatelessWidget {
  final ScrollController? scrollController;
  final VoidCallback? onNavigateToDonate;

  const SettingsContent({super.key, this.scrollController, this.onNavigateToDonate});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return ListView(
      controller: scrollController,
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
                onTap: onNavigateToDonate,
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.heart, size: 14, color: EmberColors.obsidianBase),
                      SizedBox(width: 8),
                      Text(
                        'Support Taezeem via UPI (7006616470@fam) 💖',
                        style: TextStyle(
                          color: EmberColors.obsidianBase,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
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
          onTap: onNavigateToDonate,
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
          onTap: () => SoundShapingSheet.show(context),
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
          icon: FontAwesomeIcons.gaugeHigh,
          title: 'Audio Streaming Quality',
          subtitle: 'High Bitrate YouTube Opus (160 kbps) & AAC (128 kbps)',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EmberColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: EmberColors.outlineVariant),
            ),
            child: const Text('High Bitrate', style: TextStyle(color: EmberColors.primaryAmber, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          onTap: null,
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
          subtitle: 'v1.0.9 (Release Build)',
          trailing: Text('1.0.9', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
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
          iconColor: const Color(0xFF00E5FF),
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
