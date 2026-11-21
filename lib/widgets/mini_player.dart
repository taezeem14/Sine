import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../services/cover_color_service.dart';
import '../theme/ember_theme.dart';
import 'vinyl_disc.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  static bool _isNavigating = false;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  Future<void> _openNowPlaying(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, anim, secAnim) => const NowPlayingScreen(),
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, anim, secAnim, child) {
            final slideTween = Tween(begin: const Offset(0.0, 0.14), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutQuint));
            final fadeTween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutQuint));
            return SlideTransition(
              position: anim.drive(slideTween),
              child: FadeTransition(
                opacity: anim.drive(fadeTween),
                child: child,
              ),
            );
          },
        ),
      );
    } finally {
      _isNavigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Surgical selectors: zero unnecessary rebuilds on unrelated Provider updates
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final isLoading = context.select<PlayerProvider, bool>((p) => p.isLoadingStream);
    final isolationMode = context.select<PlayerProvider, IsolationMode>((p) => p.isolationMode);
    final isFav = context.select<PlayerProvider, bool>(
      (p) => song != null && p.isFavorite(song.id),
    );
    final duration = context.select<PlayerProvider, Duration>((p) => p.duration);
    final player = context.read<PlayerProvider>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: song == null
          ? const SizedBox.shrink(key: ValueKey('mini_empty'))
          : _buildActiveBar(
              context: context,
              player: player,
              song: song,
              isPlaying: isPlaying,
              isLoading: isLoading,
              isolationMode: isolationMode,
              isFav: isFav,
              duration: duration,
            ),
    );
  }

  Widget _buildActiveBar({
    required BuildContext context,
    required PlayerProvider player,
    required Song song,
    required bool isPlaying,
    required bool isLoading,
    required IsolationMode isolationMode,
    required bool isFav,
    required Duration duration,
  }) {
    final palette = CoverColorService.instance.getPaletteSync(song);
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      key: const ValueKey('mini_active'),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        player.stopPlayback();
      },
      onHorizontalDragStart: (_) {
        setState(() => _isDragging = true);
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(-64.0, 64.0);
        });
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragOffset < -36 || velocity < -240) {
          HapticFeedback.lightImpact();
          player.skipNext();
        } else if (_dragOffset > 36 || velocity > 240) {
          HapticFeedback.lightImpact();
          player.skipPrevious();
        }
        setState(() {
          _isDragging = false;
          _dragOffset = 0.0;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _isDragging = false;
          _dragOffset = 0.0;
        });
      },
      onTap: () => _openNowPlaying(context),
      child: AnimatedContainer(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(_dragOffset * 0.45, 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(EmberColors.surfaceContainerLow, palette.dominant, 0.14)!
                  .withValues(alpha: 0.96),
              EmberColors.surfaceContainerLow.withValues(alpha: 0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Color.lerp(EmberColors.outlineVariant, palette.dominant, 0.35)!
                .withValues(alpha: 0.65),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.dominant.withValues(alpha: isPlaying ? 0.16 : 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 2.5px top progress bar (Isolated RepaintBoundary for 120 FPS rendering)
            RepaintBoundary(
              child: ValueListenableBuilder<Duration>(
                valueListenable: player.positionNotifier,
                builder: (context, pos, _) {
                  final totalMs = duration.inMilliseconds;
                  final double progress =
                      totalMs > 0 ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Vinyl disc with art peek
                  RepaintBoundary(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VinylDisc(
                          size: 44,
                          isPlaying: isPlaying,
                          labelColor: palette.dominant,
                          accentColor: palette.accent,
                        ),
                        Hero(
                          tag: 'player_art_${song.id.isNotEmpty ? song.id : "default"}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: song.artworkUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: song.artworkUrl,
                                    width: 28,
                                    height: 28,
                                    memCacheWidth: 80,
                                    memCacheHeight: 80,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => FaIcon(
                                      FontAwesomeIcons.music,
                                      size: 14,
                                      color: accent,
                                    ),
                                  )
                                : FaIcon(FontAwesomeIcons.music, size: 14, color: accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Animated Title & Artist cross-fade on track change
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.18),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey('meta_${song.id}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: EmberColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (isolationMode != IsolationMode.none) ...[
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.35),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    isolationMode == IsolationMode.instrumentsOnly
                                        ? 'AI KARAOKE'
                                        : 'AI VOCALS',
                                    style: TextStyle(
                                      color: EmberColors.primaryBlueHi,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: EmberColors.textMuted,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Animated Favorite Heart
                  IconButton(
                    icon: AnimatedScale(
                      scale: isFav ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: FaIcon(
                        isFav ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                        size: 18,
                        color: isFav ? accent : EmberColors.textMuted,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.toggleFavorite(song);
                    },
                    splashRadius: 20,
                  ),
                  // Circular Play/Pause button with subtle glow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: isPlaying ? 0.4 : 0.2),
                          blurRadius: isPlaying ? 12 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                key: ValueKey('mini_loading'),
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : FaIcon(
                                isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                                key: ValueKey(isPlaying ? 'mini_pause' : 'mini_play'),
                                color: Colors.white,
                                size: 15,
                              ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        player.togglePlay();
                      },
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Skip Next
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.forwardStep,
                      size: 17,
                      color: EmberColors.textSecondary,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.skipNext();
                    },
                    splashRadius: 20,
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
