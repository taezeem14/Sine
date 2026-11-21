import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/smooth_animations.dart';
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
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
    final isOled = context.select<PlayerProvider, bool>((p) => p.isOledBlack);
    final activeAccent = Theme.of(context).colorScheme.primary;
    final bgColor = isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Tab Views with Smooth GPU-Composited Fade + Micro-Scale Transitions
          AnimatedIndexedStack(
            index: _currentIndex,
            duration: const Duration(milliseconds: 220),
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

                // Sine Bottom Navigation Bar (OLED & Theme-Reactive)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: bgColor.withValues(alpha: 0.96),
                    border: Border(
                      top: BorderSide(
                        color: activeAccent.withValues(alpha: 0.16),
                        width: 0.8,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 58,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _BottomNavItem(
                            icon: FontAwesomeIcons.house,
                            activeIcon: FontAwesomeIcons.house,
                            label: 'Home',
                            isSelected: _currentIndex == 0,
                            accentColor: activeAccent,
                            onTap: () => _onTabTapped(0),
                          ),
                          _BottomNavItem(
                            icon: FontAwesomeIcons.magnifyingGlass,
                            activeIcon: FontAwesomeIcons.magnifyingGlass,
                            label: 'Search',
                            isSelected: _currentIndex == 1,
                            accentColor: activeAccent,
                            onTap: () => _onTabTapped(1),
                          ),
                          _BottomNavItem(
                            icon: FontAwesomeIcons.linesLeaning,
                            activeIcon: FontAwesomeIcons.linesLeaning,
                            label: 'Your Library',
                            isSelected: _currentIndex == 2,
                            accentColor: activeAccent,
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
  final Color accentColor;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? accentColor : EmberColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? accentColor.withValues(alpha: 0.35) : Colors.transparent,
                    width: 0.8,
                  ),
                ),
                child: FaIcon(
                  isSelected ? activeIcon : icon,
                  size: isSelected ? 19 : 18,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
