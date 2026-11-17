import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/upi_donation_view.dart';
import 'equalizer_screen.dart';
import 'diagnostics_log_screen.dart';
import 'app_lock_screen.dart';
import 'car_mode_screen.dart';
import '../services/app_lock_service.dart';
import '../constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  final int initialTab;
  const SettingsScreen({super.key, this.initialTab = 0});

  static void show(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
    final player = context.watch<PlayerProvider>();
    final isOled = player.isOledBlack;
    final sheetBg = isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase;

    return AnimatedTheme(
      data: player.themeData,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final activeAccent = Theme.of(context).colorScheme.primary;
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
                          color: activeAccent.withValues(alpha: 0.16),
                        ),
                        child: FaIcon(FontAwesomeIcons.gear, color: activeAccent, size: 18),
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
                    color: isOled ? const Color(0xFF0D0D0D) : EmberColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: activeAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: activeAccent.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: sheetBg,
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
        ),
      ),
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLockStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                Text('Neural Stem Separation Engine', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Prioritize AI models or local matching for Karaoke & Acapella isolation.', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
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
                Text('Playback Session Recovery', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('How Sine handles previously active playback when the app is restarted.', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
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

  void _showOpenSourceCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmberColors.obsidianBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EmberColors.primaryBlue.withValues(alpha: 0.15),
              ),
              child: FaIcon(FontAwesomeIcons.scaleBalanced, color: EmberColors.primaryBlue, size: 16),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'GPL-3.0 Attributions',
                style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sine is free open-source software licensed under GNU General Public License v3.0 (GPL-3.0). We proudly credit and attribute these outstanding upstream projects:',
                  style: TextStyle(color: EmberColors.textSecondary.withValues(alpha: 0.9), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                ...AppConstants.openSourceAttributions.map((item) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EmberColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['name'] ?? '',
                              style: TextStyle(color: EmberColors.primaryBlueHi, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: EmberColors.primaryBlue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['license'] ?? 'GPL-3.0',
                                style: TextStyle(color: EmberColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'By ${item['organization']} • ${item['repo']}',
                          style: TextStyle(color: EmberColors.textMuted, fontSize: 10.5, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['role'] ?? '',
                          style: TextStyle(color: EmberColors.textSecondary, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: EmberColors.primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExportBackupDialog(BuildContext context, PlayerProvider player) {
    bool isExporting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: EmberColors.obsidianBase,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              FaIcon(FontAwesomeIcons.fileExport, color: EmberColors.primaryBlue, size: 18),
              const SizedBox(width: 10),
              Text('Export Library Backup', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saves your entire music database (Playlists, Favorites, History & Custom EQ Gains) into a persistent JSON backup file.',
                style: TextStyle(color: EmberColors.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EmberColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Playlists: ${player.playlists.length}', style: TextStyle(color: EmberColors.textPrimary, fontSize: 12)),
                    Text('• Favorites: ${player.favorites.length}', style: TextStyle(color: EmberColors.textPrimary, fontSize: 12)),
                    Text('• History Tracks: ${player.history.length}', style: TextStyle(color: EmberColors.textPrimary, fontSize: 12)),
                    Text('• Target: /Sine-Music/Backups/', style: TextStyle(color: EmberColors.primaryBlueHi, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Persists safely across app updates and uninstalls.', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: EmberColors.textSecondary,
                side: BorderSide(color: EmberColors.outlineVariant),
              ),
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Copy JSON', style: TextStyle(fontSize: 12)),
              onPressed: () {
                final jsonStr = player.exportLibraryBackup();
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: EmberColors.surfaceContainerHigh,
                    content: Text('Backup JSON copied to clipboard!', style: TextStyle(color: EmberColors.primaryBlueHi)),
                  ),
                );
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: EmberColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              icon: isExporting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_alt_rounded, size: 16),
              label: Text(isExporting ? 'Saving...' : 'Save File'),
              onPressed: isExporting
                  ? null
                  : () async {
                      setDialogState(() => isExporting = true);
                      final file = await player.exportLibraryBackupToFile();
                      setDialogState(() => isExporting = false);
                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        final messenger = ScaffoldMessenger.of(context);
                        if (file != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: EmberColors.surfaceContainerHigh,
                              duration: const Duration(seconds: 4),
                              content: Text('Backup saved to:\n${file.path}', style: TextStyle(color: EmberColors.primaryBlueHi, fontSize: 12)),
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text('Failed to save backup file to storage.', style: TextStyle(color: Colors.white)),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showRestoreBackupDialog(BuildContext context, PlayerProvider player) {
    final controller = TextEditingController();
    bool mergeData = true;
    bool isScanning = true;
    bool isRestoring = false;
    List<File> backupFiles = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isScanning) {
            player.getAvailableBackupFiles().then((files) {
              if (ctx.mounted) {
                setDialogState(() {
                  backupFiles = files;
                  isScanning = false;
                });
              }
            });
          }

          return AlertDialog(
            backgroundColor: player.isOledBlack ? EmberColors.pitchBlack : EmberColors.obsidianBase,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                FaIcon(FontAwesomeIcons.fileImport, color: EmberColors.primaryBlue, size: 18),
                const SizedBox(width: 10),
                Text('Restore Library', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restore playlists, favorites, and settings from a backup file or pasted JSON.',
                      style: TextStyle(color: EmberColors.textSecondary, fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('FOUND BACKUPS ON STORAGE', style: TextStyle(color: EmberColors.primaryBlueHi, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        if (!isScanning)
                          InkWell(
                            onTap: () {
                              setDialogState(() => isScanning = true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.refresh_rounded, size: 13, color: EmberColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text('Refresh', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (isScanning)
                      Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: EmberColors.primaryBlue),
                        ),
                      )
                    else if (backupFiles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: EmberColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No backup files found in /Sine-Music/Backups.\nYou can paste JSON or enter a path below.',
                          style: TextStyle(color: EmberColors.textMuted, fontSize: 11),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: EmberColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: backupFiles.length,
                          separatorBuilder: (_, __) => Divider(color: EmberColors.outlineVariant.withValues(alpha: 0.2), height: 1),
                          itemBuilder: (c, idx) {
                            final file = backupFiles[idx];
                            final fileName = file.path.split(Platform.pathSeparator).last;
                            int sizeKb = 0;
                            DateTime? modified;
                            try {
                              sizeKb = (file.lengthSync() / 1024).round();
                              modified = file.lastModifiedSync();
                            } catch (_) {}
                            final modStr = modified != null
                                ? '${modified.month}/${modified.day} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}'
                                : '';

                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              leading: FaIcon(FontAwesomeIcons.fileCode, size: 16, color: EmberColors.primaryBlue),
                              title: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: EmberColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${sizeKb} KB • $modStr',
                                style: TextStyle(color: EmberColors.textMuted, fontSize: 10.5),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: EmberColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: isRestoring
                                    ? null
                                    : () async {
                                        setDialogState(() => isRestoring = true);
                                        final messenger = ScaffoldMessenger.of(context);
                                        final nav = Navigator.of(ctx);
                                        final res = await player.importLibraryBackupFromFile(file, merge: mergeData);
                                        setDialogState(() => isRestoring = false);
                                        if (ctx.mounted) nav.pop();
                                        if (res != null) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              backgroundColor: EmberColors.surfaceContainerHigh,
                                              content: Text(
                                                'Restored ${res.playlistsCount} playlists, ${res.favoritesCount} favorites, ${res.historyCount} history tracks!',
                                                style: TextStyle(color: EmberColors.primaryBlueHi),
                                              ),
                                            ),
                                          );
                                        } else {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.redAccent,
                                              content: Text('Failed to read backup file.', style: TextStyle(color: Colors.white)),
                                            ),
                                          );
                                        }
                                      },
                                child: const Text('Restore', style: TextStyle(fontSize: 11)),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text('OR PASTE JSON MANUALLY', style: TextStyle(color: EmberColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      style: TextStyle(color: EmberColors.textPrimary, fontSize: 11, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'Paste {"format": "SINE_BACKUP", ...}',
                        hintStyle: TextStyle(color: EmberColors.textMuted, fontSize: 11),
                        filled: true,
                        fillColor: EmberColors.surfaceContainerLow,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Merge with existing library', style: TextStyle(color: EmberColors.textPrimary, fontSize: 12)),
                      subtitle: Text('Uncheck to completely overwrite current database', style: TextStyle(color: EmberColors.textMuted, fontSize: 10.5)),
                      value: mergeData,
                      activeColor: EmberColors.primaryBlue,
                      onChanged: (val) => setDialogState(() => mergeData = val ?? true),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: EmberColors.primaryBlue, foregroundColor: Colors.white),
                onPressed: isRestoring
                    ? null
                    : () async {
                        final raw = controller.text.trim();
                        if (raw.isEmpty) return;
                        setDialogState(() => isRestoring = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        final res = await player.importLibraryBackup(raw, merge: mergeData);
                        setDialogState(() => isRestoring = false);
                        if (ctx.mounted) nav.pop();
                        if (res != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: EmberColors.surfaceContainerHigh,
                              content: Text(
                                'Restored ${res.playlistsCount} playlists, ${res.favoritesCount} favorites, ${res.historyCount} history tracks!',
                                style: TextStyle(color: EmberColors.primaryBlueHi),
                              ),
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text('Invalid backup JSON payload. Could not restore.', style: TextStyle(color: Colors.white)),
                            ),
                          );
                        }
                      },
                child: const Text('Restore from Text'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, PlayerProvider player) {
    final currentPreset = player.activeThemePreset;
    final activeAccent = Theme.of(context).colorScheme.primary;
    final isOled = player.isOledBlack;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOled ? const Color(0xFF0D0D0D) : EmberColors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: isOled ? 0.25 : 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Interactive Theme Preview Card
          _LiveThemePreviewCard(
            accentColor: activeAccent,
            presetName: currentPreset == SineThemePreset.custom
                ? 'Custom Accent (#${activeAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()})'
                : currentPreset.label,
            isOled: isOled,
          ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeAccent.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.palette_rounded, color: activeAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Accent Color',
                      style: TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentPreset == SineThemePreset.custom
                          ? 'Custom Accent (#${activeAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()})'
                          : currentPreset.label,
                      style: const TextStyle(
                        color: EmberColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeAccent,
                  boxShadow: [
                    BoxShadow(
                      color: activeAccent.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ...SineThemePreset.values.where((p) => p != SineThemePreset.custom).map((preset) {
                  final isSelected = currentPreset == preset;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      player.setThemePreset(preset);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: preset.accentColor,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: preset.accentColor.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: (preset == SineThemePreset.monochrome || preset == SineThemePreset.yellow)
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            preset.label.split(' ').first,
                            style: TextStyle(
                              color: isSelected ? EmberColors.textPrimary : EmberColors.textMuted,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showCustomColorPicker(context, player),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.yellow,
                              Colors.green,
                              Colors.cyan,
                              Colors.blue,
                              Colors.purple,
                              Colors.red,
                            ],
                          ),
                          border: Border.all(
                            color: currentPreset == SineThemePreset.custom ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: currentPreset == SineThemePreset.custom
                              ? [
                                  BoxShadow(
                                    color: activeAccent.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: currentPreset == SineThemePreset.custom
                            ? const Icon(Icons.colorize_rounded, size: 17, color: Colors.white)
                            : const Icon(Icons.add_rounded, size: 19, color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Custom',
                        style: TextStyle(
                          color: currentPreset == SineThemePreset.custom ? EmberColors.textPrimary : EmberColors.textMuted,
                          fontSize: 10,
                          fontWeight: currentPreset == SineThemePreset.custom ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: EmberColors.outlineVariant.withValues(alpha: 0.15)),
          const SizedBox(height: 14),
          // True OLED Pitch Black Mode Toggle
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isOled ? Colors.white : activeAccent).withValues(alpha: 0.16),
                ),
                child: Icon(
                  Icons.brightness_2_rounded,
                  color: isOled ? Colors.white : activeAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'True OLED Black Mode',
                      style: TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOled
                          ? 'Pure Pitch Black (#000000) • Maximizes battery life'
                          : 'Deep Obsidian Charcoal (#121212) • Smooth dark contrast',
                      style: const TextStyle(
                        color: EmberColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOled,
                activeThumbColor: activeAccent,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  player.setOledBlack(val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomColorPicker(BuildContext context, PlayerProvider player) {
    Color pickerColor = player.customThemeColor;
    int r = (pickerColor.r * 255).round();
    int g = (pickerColor.g * 255).round();
    int b = (pickerColor.b * 255).round();
    HSVColor hsvColor = HSVColor.fromColor(pickerColor);
    final hexController = TextEditingController(
      text: pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
    );

    final curatedSwatches = const [
      Color(0xFF00E5FF),
      Color(0xFF00BFA5),
      Color(0xFFFF4081),
      Color(0xFF7C4DFF),
      Color(0xFFAEEA00),
      Color(0xFFFFD700),
      Color(0xFFFF6F61),
      Color(0xFF00BFFF),
      Color(0xFFB388FF),
      Color(0xFFFFAB00),
      Color(0xFFE91E63),
      Color(0xFFFFFFFF),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPickerState) {
          final hexStr = '#${pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

          return AlertDialog(
            backgroundColor: player.isOledBlack ? EmberColors.pitchBlack : EmberColors.obsidianBase,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pickerColor.withValues(alpha: 0.2),
                  ),
                  child: Icon(Icons.colorize_rounded, color: pickerColor, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Custom Theme Color',
                  style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: EmberColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pickerColor,
                              boxShadow: [
                                BoxShadow(
                                  color: pickerColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hexStr,
                                style: TextStyle(
                                  color: pickerColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'RGB: ($r, $g, $b)',
                                style: const TextStyle(
                                  color: EmberColors.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hex Code Input Field
                    const Text(
                      'Hex Color Code',
                      style: TextStyle(color: EmberColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: EmberColors.surfaceContainerHigh.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Text('#', style: TextStyle(color: EmberColors.textMuted, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: hexController,
                              maxLength: 6,
                              style: const TextStyle(
                                color: EmberColors.textPrimary,
                                fontSize: 13.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                                hintText: 'RRGGBB',
                                hintStyle: TextStyle(color: EmberColors.textMuted),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                final clean = val.replaceAll('#', '').trim();
                                if (clean.length == 6) {
                                  final parsed = int.tryParse('0xFF$clean');
                                  if (parsed != null) {
                                    setPickerState(() {
                                      pickerColor = Color(parsed);
                                      r = (pickerColor.r * 255).round();
                                      g = (pickerColor.g * 255).round();
                                      b = (pickerColor.b * 255).round();
                                      hsvColor = HSVColor.fromColor(pickerColor);
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hue Spectrum Bar
                    const Text(
                      'Hue Spectrum Picker',
                      style: TextStyle(color: EmberColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 28,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        ),
                        child: Slider(
                          value: hsvColor.hue,
                          min: 0,
                          max: 360,
                          onChanged: (val) {
                            setPickerState(() {
                              hsvColor = hsvColor.withHue(val);
                              pickerColor = hsvColor.toColor();
                              r = (pickerColor.r * 255).round();
                              g = (pickerColor.g * 255).round();
                              b = (pickerColor.b * 255).round();
                              hexController.text = pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Curated Neon & Vivid Accents',
                      style: TextStyle(color: EmberColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: curatedSwatches.map((color) {
                        final isPicked = pickerColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setPickerState(() {
                              pickerColor = color;
                              r = (color.r * 255).round();
                              g = (color.g * 255).round();
                              b = (color.b * 255).round();
                              hsvColor = HSVColor.fromColor(color);
                              hexController.text = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(
                                color: isPicked ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isPicked
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: (color.r * 0.299 + color.g * 0.587 + color.b * 0.114) > 0.6 ? Colors.black : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Precision RGB Sliders',
                      style: TextStyle(color: EmberColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 22, child: Text('R', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(
                          child: Slider(
                            value: r.toDouble(),
                            min: 0,
                            max: 255,
                            activeColor: Colors.redAccent,
                            onChanged: (val) {
                              setPickerState(() {
                                r = val.round();
                                pickerColor = Color.fromARGB(255, r, g, b);
                                hsvColor = HSVColor.fromColor(pickerColor);
                                hexController.text = pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 30, child: Text('$r', style: const TextStyle(color: EmberColors.textMuted, fontSize: 11))),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 22, child: Text('G', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(
                          child: Slider(
                            value: g.toDouble(),
                            min: 0,
                            max: 255,
                            activeColor: Colors.greenAccent,
                            onChanged: (val) {
                              setPickerState(() {
                                g = val.round();
                                pickerColor = Color.fromARGB(255, r, g, b);
                                hsvColor = HSVColor.fromColor(pickerColor);
                                hexController.text = pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 30, child: Text('$g', style: const TextStyle(color: EmberColors.textMuted, fontSize: 11))),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 22, child: Text('B', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(
                          child: Slider(
                            value: b.toDouble(),
                            min: 0,
                            max: 255,
                            activeColor: Colors.lightBlueAccent,
                            onChanged: (val) {
                              setPickerState(() {
                                b = val.round();
                                pickerColor = Color.fromARGB(255, r, g, b);
                                hsvColor = HSVColor.fromColor(pickerColor);
                                hexController.text = pickerColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 30, child: Text('$b', style: const TextStyle(color: EmberColors.textMuted, fontSize: 11))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pickerColor,
                  foregroundColor: (pickerColor.r * 0.299 + pickerColor.g * 0.587 + pickerColor.b * 0.114) > 0.6 ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  player.setThemePreset(SineThemePreset.custom, customColor: pickerColor);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: EmberColors.surfaceContainerHigh,
                      content: Text('Custom theme accent applied ($hexStr)!', style: TextStyle(color: pickerColor, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
                child: const Text('Apply Theme', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOptionTile(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? EmberColors.primaryBlue.withValues(alpha: 0.14) : EmberColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? EmberColors.primaryBlue : Colors.transparent),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, style: TextStyle(color: isSelected ? EmberColors.primaryBlueHi : EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: EmberColors.primaryBlue, size: 18) : null,
        onTap: onTap,
      ),
    );
  }


    Widget _buildSearchBar(Color activeAccent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EmberColors.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? activeAccent.withValues(alpha: 0.6)
              : EmberColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search settings, audio, backup...',
          hintStyle: const TextStyle(color: EmberColors.textMuted, fontSize: 13),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _searchQuery.isNotEmpty ? activeAccent : EmberColors.textMuted,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: EmberColors.textMuted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val.trim());
        },
      ),
    );
  }

  List<Widget> _buildFilteredItems(BuildContext context, PlayerProvider player, Color activeAccent, String query) {
    final q = query.toLowerCase();
    final items = <Widget>[];

    bool matches(String text) => text.toLowerCase().contains(q);

    if (matches('donate') || matches('upi') || matches('support') || matches('creator') || matches('taezeem')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.indianRupeeSign,
          iconColor: activeAccent,
          title: 'Donate via UPI (7006616470@fam)',
          subtitle: 'Support development directly using GPay, PhonePe, Paytm or FamPay',
          trailing: FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: activeAccent),
          onTap: widget.onNavigateToDonate,
        ),
      );
    }

    if (matches('lock') || matches('passcode') || matches('pin') || matches('security') || matches('protect')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.lock,
          iconColor: activeAccent,
          title: 'App Lock Passcode',
          subtitle: _isLockEnabled ? 'Passcode active • Require 4-digit PIN on app launch' : 'Secure your Sine music player with a 4-digit PIN',
          trailing: Switch(
            value: _isLockEnabled,
            activeThumbColor: activeAccent,
            onChanged: (val) => _toggleLock(val),
          ),
          onTap: () => _toggleLock(!_isLockEnabled),
        ),
      );
      if (_isLockEnabled) {
        items.add(
          _SettingsTile(
            icon: FontAwesomeIcons.key,
            title: 'Change Passcode',
            subtitle: 'Update your 4-digit security PIN',
            trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
            onTap: _changePasscode,
          ),
        );
      }
    }

    if (matches('theme') || matches('accent') || matches('color') || matches('oled') || matches('black') || matches('palette')) {
      items.add(_buildThemeSection(context, player));
    }

    if (matches('widget') || matches('home') || matches('screen') || matches('now playing')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.tableCellsLarge,
          iconColor: EmberColors.secondaryCyan,
          title: 'Sine Now Playing Widget (4x2)',
          subtitle: 'Control playback, view track title and artist directly from your home screen. Long-press home screen to add!',
          trailing: Text('Available', style: TextStyle(color: activeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          onTap: null,
        ),
      );
    }

    if (matches('equalizer') || matches('eq') || matches('sound') || matches('bass') || matches('audio')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.sliders,
          title: 'Equalizer & Audio Shaping',
          subtitle: 'Preset: ${player.eqPreset} • Bass Boost: ${(player.bassBoost * 100).round()}%',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => EqualizerScreen.open(context),
        ),
      );
    }

    if (matches('clip') || matches('clipping') || matches('headroom') || matches('protection') || matches('distortion')) {
      items.add(
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
      );
    }

    if (matches('stem') || matches('neural') || matches('vocal') || matches('karaoke') || matches('acapella') || matches('demucs') || matches('roformer')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.brain,
          iconColor: activeAccent,
          title: 'Neural Stem Engine Preference',
          subtitle: 'AI Model: ${player.stemEnginePreference.toUpperCase()} • SOTA Vocal & Backing Separation',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => _showStemEngineSheet(context, player),
        ),
      );
    }

    if (matches('recover') || matches('session') || matches('restart') || matches('prompt') || matches('restore')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.clockRotateLeft,
          iconColor: activeAccent,
          title: 'Playback Session Recovery',
          subtitle: 'Mode: ${player.playbackRecoveryMode.toUpperCase()} • Reliable app restart recovery',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => _showRecoveryModeSheet(context, player),
        ),
      );
    }

    if (matches('hud') || matches('fps') || matches('frame') || matches('performance') || matches('monitor')) {
      items.add(
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
      );
    }

    if (matches('crossfade') || matches('fade') || matches('overlap') || matches('transition')) {
      items.add(_CrossfadeSettingsTile(player: player));
    }

    if (matches('gapless') || matches('pause') || matches('seamless')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.arrowsLeftRight,
          title: 'Gapless Playback',
          subtitle: 'Eliminate pause between sequential tracks',
          trailing: Switch(
            value: player.gaplessPlayback,
            activeThumbColor: activeAccent,
            onChanged: (val) => player.setGaplessPlayback(val),
          ),
          onTap: () => player.setGaplessPlayback(!player.gaplessPlayback),
        ),
      );
    }

    if (matches('autoplay') || matches('smart') || matches('radio') || matches('recommend')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.bolt,
          title: 'Autoplay Smart Radio',
          subtitle: 'Automatically queue recommended tracks when songs end',
          trailing: Switch(
            value: player.isAutoplayEnabled,
            activeThumbColor: activeAccent,
            onChanged: (_) => player.toggleAutoplay(),
          ),
          onTap: () => player.toggleAutoplay(),
        ),
      );
    }

    if (matches('stop') || matches('cut') || matches('dismiss') || matches('clear')) {
      items.add(
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
      );
    }

    if (matches('dedup') || matches('duplicate') || matches('queue')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.layerGroup,
          title: 'Deduplicate Active Queue',
          subtitle: 'Remove all duplicate tracks while preserving active playback',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () {
            player.deduplicateQueue();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: EmberColors.surfaceContainerHigh,
                duration: const Duration(seconds: 2),
                content: Text('Active queue deduplicated cleanly!', style: TextStyle(color: activeAccent)),
              ),
            );
          },
        ),
      );
    }

    if (matches('purge') || matches('clean') || matches('cache') || matches('storage') || matches('placeholder')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.broom,
          title: 'Purge Placeholders & Clean Cache',
          subtitle: 'Eradicate legacy mock songs and clear temp audio cache',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: EmberColors.surfaceContainerHigh,
                duration: const Duration(seconds: 1),
                content: Text('Cleaning storage and purging old cache...', style: TextStyle(color: activeAccent)),
              ),
            );
            await player.purgePlaceholders();
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                backgroundColor: EmberColors.surfaceContainerHigh,
                duration: const Duration(seconds: 2),
                content: Text('Storage cleaned & cache flushed successfully!', style: TextStyle(color: activeAccent)),
              ),
            );
          },
        ),
      );
    }

    if (matches('backup') || matches('export') || matches('json') || matches('file')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.fileExport,
          iconColor: activeAccent,
          title: 'Export Library Backup (JSON File)',
          subtitle: 'Save playlists, favorites, history & EQ to /Sine-Music/Backups',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => _showExportBackupDialog(context, player),
        ),
      );
    }

    if (matches('restore') || matches('import') || matches('backup')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.fileImport,
          iconColor: activeAccent,
          title: 'Restore Library from Backup',
          subtitle: '1-tap restore from /Sine-Music/Backups or paste JSON',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => _showRestoreBackupDialog(context, player),
        ),
      );
    }

    if (matches('version') || matches('build') || matches('sine') || matches('app')) {
      items.add(
        const _SettingsTile(
          icon: FontAwesomeIcons.mobileScreen,
          title: 'Sine Version',
          subtitle: '${AppConstants.releaseTag} (Release Build)',
          trailing: Text(AppConstants.version, style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
          onTap: null,
        ),
      );
    }

    if (matches('newpipe') || matches('youtube') || matches('stream') || matches('opus') || matches('aac')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.music,
          iconColor: activeAccent,
          title: 'NewPipe YouTube Audio Engine',
          subtitle: 'Hardware-accelerated Opus (160 kbps) & AAC (128 kbps) stream extraction',
          trailing: Text('Lossless/HD', style: TextStyle(color: activeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          onTap: null,
        ),
      );
    }

    if (matches('open source') || matches('free') || matches('ad') || matches('privacy')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.shieldHeart,
          title: 'Open Source & Ad-Free',
          subtitle: 'No telemetry, zero third-party ads, strictly local storage',
          trailing: Text('100% Free', style: TextStyle(color: activeAccent, fontSize: 12)),
          onTap: null,
        ),
      );
    }

    if (matches('credit') || matches('license') || matches('gpl') || matches('attribution')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.scaleBalanced,
          iconColor: activeAccent,
          title: 'Open Source Credits & Attribution',
          subtitle: 'GNU GPL-3.0 attribution for Audile, zemer-cipher, BetterLyrics & Metrolist',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () => _showOpenSourceCreditsDialog(context),
        ),
      );
    }

    if (matches('diag') || matches('log') || matches('exoplayer') || matches('telemetry') || matches('debug')) {
      items.add(
        _SettingsTile(
          icon: FontAwesomeIcons.terminal,
          iconColor: activeAccent,
          title: 'Diagnostics & Log Extractor',
          subtitle: 'Live ExoPlayer telemetry, candidate stream inspector & bug reporter',
          trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsLogScreen()),
            );
          },
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final activeAccent = Theme.of(context).colorScheme.primary;

    final filteredItems = _searchQuery.isNotEmpty
        ? _buildFilteredItems(context, player, activeAccent, _searchQuery)
        : <Widget>[];

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildSearchBar(activeAccent),
        if (_searchQuery.isNotEmpty) ...[
          if (filteredItems.isNotEmpty)
            _SettingsGroupCard(children: filteredItems)
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: EmberColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No settings found for "$_searchQuery"',
                    style: const TextStyle(color: EmberColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
        ] else ...[
          // ==========================================
          // SOLE CREATOR & AUTHOR SPOTLIGHT CARD
          // ==========================================
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  activeAccent.withValues(alpha: 0.18),
                  EmberColors.surfaceContainerHigh.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: activeAccent.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: activeAccent.withValues(alpha: 0.08),
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
                        color: activeAccent,
                        boxShadow: [
                          BoxShadow(
                            color: activeAccent.withValues(alpha: 0.4),
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
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Muhammad Taezeem Tariq',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: EmberColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              FaIcon(
                                FontAwesomeIcons.solidCircleCheck,
                                color: activeAccent,
                                size: 14,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: activeAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Author & Creator',
                              style: TextStyle(
                                color: activeAccent,
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
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.github, size: 14, color: EmberColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'github.com/taezeem14',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onNavigateToDonate?.call();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: activeAccent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: activeAccent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Support Taezeem via UPI (7006616470@fam)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: (activeAccent.r * 0.299 + activeAccent.g * 0.587 + activeAccent.b * 0.114) > 0.6 ? Colors.black : Colors.white,
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

          const SizedBox(height: 18),

          // ==========================================
          // SECTION 0: CREATOR SUPPORT & DONATIONS
          // ==========================================
          const _SectionHeader(title: 'Creator Support & Donations'),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.indianRupeeSign,
                iconColor: activeAccent,
                title: 'Donate via UPI (7006616470@fam)',
                subtitle: 'Support development directly using GPay, PhonePe, Paytm or FamPay',
                trailing: FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: activeAccent),
                onTap: widget.onNavigateToDonate,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==========================================
          // SECTION: SECURITY & APP LOCK
          // ==========================================
          const _SectionHeader(title: 'Security & App Lock'),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.lock,
                iconColor: activeAccent,
                title: 'App Lock Passcode',
                subtitle: _isLockEnabled ? 'Passcode active • Require 4-digit PIN on app launch' : 'Secure your Sine music player with a 4-digit PIN',
                trailing: Switch(
                  value: _isLockEnabled,
                  activeThumbColor: activeAccent,
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
            ],
          ),

          const SizedBox(height: 14),

          // ==========================================
          // SECTION: THEME & ACCENT CUSTOMIZATION
          // ==========================================
          const _SectionHeader(title: 'Theme & Accent Customization'),
          _buildThemeSection(context, player),

          const SizedBox(height: 14),

          // ==========================================
          // SECTION: HOME SCREEN WIDGETS
          // ==========================================
          const _SectionHeader(title: 'Android Home Screen Widgets'),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.tableCellsLarge,
                iconColor: EmberColors.secondaryCyan,
                title: 'Sine Now Playing Widget (4x2)',
                subtitle: 'Control playback, view track title and artist directly from your home screen. Long-press home screen to add!',
                trailing: Text('Available', style: TextStyle(color: activeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==========================================
          // SECTION 1: AUDIO & SOUND SHAPING
          // ==========================================
          const _SectionHeader(title: 'Audio & Sound Engine'),
          _SettingsGroupCard(
            children: [
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
                icon: FontAwesomeIcons.volumeHigh,
                iconColor: const Color(0xFF38BDF8),
                title: 'Loudness Normalization (EBU R128)',
                subtitle: 'Automatic audio volume leveling to streaming standards across all tracks',
                trailing: Switch(
                  value: player.isLoudnessNormalizationEnabled,
                  activeThumbColor: const Color(0xFF38BDF8),
                  onChanged: (val) => player.setLoudnessNormalizationEnabled(val),
                ),
                onTap: () => player.setLoudnessNormalizationEnabled(!player.isLoudnessNormalizationEnabled),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.forwardFast,
                iconColor: const Color(0xFFF59E0B),
                title: 'Skip Silence & Dead Air Trimming',
                subtitle: 'Automatically advance past silent lead-in padding at track start',
                trailing: Switch(
                  value: player.isSkipSilenceEnabled,
                  activeThumbColor: const Color(0xFFF59E0B),
                  onChanged: (val) => player.setSkipSilenceEnabled(val),
                ),
                onTap: () => player.setSkipSilenceEnabled(!player.isSkipSilenceEnabled),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.brain,
                iconColor: activeAccent,
                title: 'Neural Stem Engine Preference',
                subtitle: 'AI Model: ${player.stemEnginePreference.toUpperCase()} • SOTA Vocal & Backing Separation',
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
                onTap: () => _showStemEngineSheet(context, player),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.clockRotateLeft,
                iconColor: activeAccent,
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
              _CrossfadeSettingsTile(player: player),
              _SettingsTile(
                icon: FontAwesomeIcons.arrowsLeftRight,
                title: 'Gapless Playback',
                subtitle: 'Eliminate pause between sequential tracks',
                trailing: Switch(
                  value: player.gaplessPlayback,
                  activeThumbColor: activeAccent,
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
                  activeThumbColor: activeAccent,
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
            ],
          ),

          const SizedBox(height: 14),

          // ==========================================
          // SECTION: MOTION GESTURES & DRIVING
          // ==========================================
          const _SectionHeader(title: 'Motion Gestures & Car Mode'),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.car,
                iconColor: const Color(0xFF38BDF8),
                title: 'Car Mode (Driving Mode)',
                subtitle: 'Minimalist fullscreen interface with large touch targets and swipe gestures',
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
                onTap: () {
                  Navigator.pop(context);
                  CarModeScreen.show(context);
                },
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.hand,
                iconColor: const Color(0xFFA855F7),
                title: 'Shake to Skip Track',
                subtitle: 'Firmly shake your device to skip to the next track',
                trailing: Switch(
                  value: player.isShakeToSkipEnabled,
                  activeThumbColor: const Color(0xFFA855F7),
                  onChanged: (val) => player.setShakeToSkipEnabled(val),
                ),
                onTap: () => player.setShakeToSkipEnabled(!player.isShakeToSkipEnabled),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.mobileScreenButton,
                iconColor: const Color(0xFF10B981),
                title: 'Flip Down to Pause',
                subtitle: 'Turn phone face down to pause audio, face up to resume',
                trailing: Switch(
                  value: player.isFlipToPauseEnabled,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) => player.setFlipToPauseEnabled(val),
                ),
                onTap: () => player.setFlipToPauseEnabled(!player.isFlipToPauseEnabled),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==========================================
          // SECTION 2: STORAGE & CACHE
          // ==========================================
          const _SectionHeader(title: 'Storage & Database'),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: FontAwesomeIcons.layerGroup,
                title: 'Deduplicate Active Queue',
                subtitle: 'Remove all duplicate tracks while preserving active playback',
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
                onTap: () {
                  player.deduplicateQueue();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: EmberColors.surfaceContainerHigh,
                      duration: const Duration(seconds: 2),
                      content: Text('Active queue deduplicated cleanly!', style: TextStyle(color: activeAccent)),
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
                    SnackBar(
                      backgroundColor: EmberColors.surfaceContainerHigh,
                      duration: const Duration(seconds: 1),
                      content: Text('Cleaning storage and purging old cache...', style: TextStyle(color: activeAccent)),
                    ),
                  );
                  await player.purgePlaceholders();
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: EmberColors.surfaceContainerHigh,
                      duration: const Duration(seconds: 2),
                      content: Text('Storage cleaned & cache flushed successfully!', style: TextStyle(color: activeAccent)),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.fileExport,
                iconColor: activeAccent,
                title: 'Export Library Backup (JSON File)',
                subtitle: 'Save playlists, favorites, history & EQ to /Sine-Music/Backups',
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
                onTap: () => _showExportBackupDialog(context, player),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.fileImport,
                iconColor: activeAccent,
                title: 'Restore Library from Backup',
                subtitle: '1-tap restore from /Sine-Music/Backups or paste JSON',
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
                onTap: () => _showRestoreBackupDialog(context, player),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==========================================
          // SECTION 3: APP INFO & SYSTEM
          // ==========================================
          const _SectionHeader(title: 'System & Architecture'),
          _SettingsGroupCard(
            children: [
              const _SettingsTile(
                icon: FontAwesomeIcons.mobileScreen,
                title: 'Sine Version',
                subtitle: '${AppConstants.releaseTag} (Release Build)',
                trailing: Text(AppConstants.version, style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                onTap: null,
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.music,
                iconColor: activeAccent,
                title: 'NewPipe YouTube Audio Engine',
                subtitle: 'Hardware-accelerated Opus (160 kbps) & AAC (128 kbps) stream extraction',
                trailing: Text('Lossless/HD', style: TextStyle(color: activeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                onTap: null,
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.shieldHeart,
                title: 'Open Source & Ad-Free',
                subtitle: 'No telemetry, zero third-party ads, strictly local storage',
                trailing: Text('100% Free', style: TextStyle(color: activeAccent, fontSize: 12)),
                onTap: null,
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.scaleBalanced,
                iconColor: activeAccent,
                title: 'Open Source Credits & Attribution',
                subtitle: 'GNU GPL-3.0 attribution for Audile, zemer-cipher, BetterLyrics & Metrolist',
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
                onTap: () => _showOpenSourceCreditsDialog(context),
              ),
              _SettingsTile(
                icon: FontAwesomeIcons.terminal,
                iconColor: activeAccent,
                title: 'Diagnostics & Log Extractor',
                subtitle: 'Live ExoPlayer telemetry, candidate stream inspector & bug reporter',
                trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DiagnosticsLogScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
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

class _SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroupCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isOled = player.isOledBlack;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOled ? const Color(0xFF0D0D0D) : EmberColors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EmberColors.outlineVariant.withValues(alpha: isOled ? 0.25 : 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 58,
                endIndent: 16,
                color: EmberColors.outlineVariant.withValues(alpha: isOled ? 0.15 : 0.25),
              ),
          ],
        ],
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
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (iconColor ?? accent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: FaIcon(
                    icon,
                    size: 16,
                    color: iconColor ?? accent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EmberColors.textMuted,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CrossfadeSettingsTile extends StatelessWidget {
  final PlayerProvider player;

  const _CrossfadeSettingsTile({required this.player});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final seconds = player.crossfadeSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.shuffle,
                    size: 16,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crossfade Audio',
                      style: TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      seconds > 0
                          ? 'Overlap track transitions by ${seconds}s'
                          : 'Off • Seamless direct transitions',
                      style: const TextStyle(
                        color: EmberColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: seconds > 0
                      ? accent.withValues(alpha: 0.18)
                      : EmberColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: seconds > 0
                        ? accent.withValues(alpha: 0.5)
                        : EmberColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  seconds > 0 ? '${seconds}s' : 'Off',
                  style: TextStyle(
                    color: seconds > 0 ? accent : EmberColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: accent,
              inactiveTrackColor: EmberColors.outlineVariant.withValues(alpha: 0.4),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.16),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              valueIndicatorColor: accent,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            child: Slider(
              value: player.crossfadeSeconds.toDouble(),
              min: 0,
              max: 12,
              divisions: 12,
              label: player.crossfadeSeconds > 0 ? '${player.crossfadeSeconds}s' : 'Off',
              onChanged: (val) {
                HapticFeedback.selectionClick();
                player.setCrossfadeSeconds(val.toInt());
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveThemePreviewCard extends StatelessWidget {
  final Color accentColor;
  final String presetName;
  final bool isOled;

  const _LiveThemePreviewCard({
    required this.accentColor,
    required this.presetName,
    required this.isOled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOled ? const Color(0xFF000000) : const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE PREVIEW',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                presetName,
                style: const TextStyle(
                  color: EmberColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mini Player Preview Mock
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starlight Melody',
                      maxLines: 1,
                      style: TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sine Music • Hi-Res Audio',
                      maxLines: 1,
                      style: TextStyle(
                        color: EmberColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mini Track Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 0.45,
              backgroundColor: EmberColors.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
