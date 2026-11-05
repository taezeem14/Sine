import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/mini_player.dart';
import 'tabs/pulsepipe_home_tab.dart';
import 'tabs/pulsepipe_search_tab.dart';
import 'tabs/pulsepipe_library_tab.dart';
import 'diagnostics_log_screen.dart';
import 'app_lock_screen.dart';
import '../services/app_lock_service.dart';

typedef SineShellScreen = PulsePipeShellScreen;

class PulsePipeShellScreen extends StatefulWidget {
  const PulsePipeShellScreen({super.key});

  @override
  State<PulsePipeShellScreen> createState() => _PulsePipeShellScreenState();
}

class _PulsePipeShellScreenState extends State<PulsePipeShellScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  ValueNotifier<Song?>? _errorNotifier;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
  }

  Future<void> _checkAppLock() async {
    final enabled = await AppLockService.isLockEnabled();
    if (enabled && !AppLockService.isUnlockedThisSession && mounted) {
      setState(() => _isLocked = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      AppLockService.isUnlockedThisSession = false;
    } else if (state == AppLifecycleState.resumed) {
      _checkAppLock();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = Provider.of<PlayerProvider>(context, listen: false).playbackErrorNotifier;
    if (_errorNotifier != notifier) {
      _errorNotifier?.removeListener(_onPlaybackError);
      _errorNotifier = notifier;
      _errorNotifier?.addListener(_onPlaybackError);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _errorNotifier?.removeListener(_onPlaybackError);
    super.dispose();
  }

  void _onPlaybackError() {
    if (!mounted) return;
    final failedSong = _errorNotifier?.value;
    if (failedSong == null) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: EmberColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const FaIcon(FontAwesomeIcons.triangleExclamation, color: Color(0xFFFF5252), size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Stream failed for "${failedSong.title}"',
                style: const TextStyle(color: EmberColors.textPrimary, fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW LOG',
          textColor: EmberColors.primaryAmber,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsLogScreen()),
            );
          },
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmberColors.obsidianBase,
      body: Stack(
        children: [
          // 1. Tab Views
          IndexedStack(
            index: _currentIndex,
            children: [
              PulsePipeHomeTab(
                onOpenSearch: () => _onTabTapped(1),
                onOpenLibrary: () => _onTabTapped(2),
              ),
              const PulsePipeSearchTab(),
              const PulsePipeLibraryTab(),
            ],
          ),

          // 2. Docked Mini Player & Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating MiniPlayer docked above nav bar
                const MiniPlayer(),

                // Sine Bottom Navigation Bar in Electric Blue
                Container(
                  decoration: BoxDecoration(
                    color: EmberColors.obsidianBase.withValues(alpha: 0.98),
                    border: Border(
                      top: BorderSide(
                        color: EmberColors.glassBorder.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _BottomNavItem(
                            icon: FontAwesomeIcons.house,
                            activeIcon: FontAwesomeIcons.house,
                            label: 'Home',
                            isSelected: _currentIndex == 0,
                            onTap: () => _onTabTapped(0),
                          ),
                          _BottomNavItem(
                            icon: FontAwesomeIcons.magnifyingGlass,
                            activeIcon: FontAwesomeIcons.magnifyingGlass,
                            label: 'Search',
                            isSelected: _currentIndex == 1,
                            onTap: () => _onTabTapped(1),
                          ),
                          _BottomNavItem(
                            icon: FontAwesomeIcons.linesLeaning,
                            activeIcon: FontAwesomeIcons.linesLeaning,
                            label: 'Your Library',
                            isSelected: _currentIndex == 2,
                            onTap: () => _onTabTapped(2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Security & App Lock Screen Overlay (if enabled & locked)
          if (_isLocked)
            Positioned.fill(
              child: AppLockScreen(
                mode: AppLockMode.unlock,
                onUnlocked: () => setState(() => _isLocked = false),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final FaIconData icon;
  final FaIconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? EmberColors.electricBlue : EmberColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              isSelected ? activeIcon : icon,
              size: 20,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
