import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/ember_theme.dart';
import 'vinyl_disc.dart';

/// Restored Classic Floating MiniPlayer featuring Sine's signature obsidian surface,
/// rotating vinyl disc artwork peek, surgical zero-rebuild selectors, responsive controls,
/// and smooth 120 FPS bottom-up NowPlaying sheet expansion.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  static bool _isNavigating = false;

  // Zero-setState drag tracking: drives GPU transform + opacity at 120 FPS without rebuilding children
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<bool> _isDraggingNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _dragOffsetNotifier.dispose();
    _isDraggingNotifier.dispose();
    super.dispose();
  }

  Future<void> _openNowPlaying(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, anim, secAnim) => const NowPlayingScreen(),
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, anim, secAnim, child) {
            final curved = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(curved);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Subtle backdrop dim (zero double-screen FadeTransition saveLayer!)
                IgnorePointer(
                  child: FadeTransition(
                    opacity: curved,
                    child: const ColoredBox(color: Color(0x8A000000)),
                  ),
                ),
                SlideTransition(
                  position: slide,
                  child: RepaintBoundary(child: child),
                ),
              ],
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
    final isOled = context.select<PlayerProvider, bool>((p) => p.isOledBlack);
    final accentColor = context.select<PlayerProvider, Color>((p) => p.activeAccentColor);
    final player = context.read<PlayerProvider>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.45),
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
              isOled: isOled,
              accentColor: accentColor,
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
    required bool isOled,
    required Color accentColor,
  }) {
    // Classic Obsidian surface palette with subtle accent border
    final Color surfaceStart = isOled ? const Color(0xFF0D0F14) : const Color(0xFF151822);
    final Color surfaceEnd = isOled ? const Color(0xFF080A0E) : const Color(0xFF10131B);
    final Color borderTint = accentColor.withValues(alpha: 0.28);
    final Color progressColor = accentColor;

    // Pre-build classic bar content ONCE so 120 FPS drag gesture updates never rebuild children
    final barContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [surfaceStart, surfaceEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderTint, width: 0.9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Classic Rotating Vinyl Disc with centered artwork peek
                RepaintBoundary(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VinylDisc(
                        size: 42,
                        isPlaying: isPlaying,
                        labelColor: accentColor.withValues(alpha: 0.65),
                        accentColor: accentColor,
                      ),
                      Hero(
                        tag: 'player_art_${song.id.isNotEmpty ? song.id : "default"}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: song.artworkUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: song.artworkUrl,
                                  width: 26,
                                  height: 26,
                                  memCacheWidth: 80,
                                  memCacheHeight: 80,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Center(
                                    child: FaIcon(
                                      FontAwesomeIcons.music,
                                      size: 13,
                                      color: accentColor,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.music,
                                    size: 13,
                                    color: accentColor,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Clean Track Title & Artist with restrained cross-fade
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    ),
                    child: Column(
                      key: ValueKey('mini_meta_${song.id}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.15,
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
                                  color: accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isolationMode == IsolationMode.instrumentsOnly
                                      ? 'KARAOKE'
                                      : 'VOCALS',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                            Expanded(
                              child: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
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
                      size: 17,
                      color: isFav ? accentColor : EmberColors.textMuted,
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
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: isPlaying ? 0.4 : 0.2),
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
    );

    return GestureDetector(
      key: const ValueKey('mini_active'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNowPlaying(context),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        player.stopPlayback();
      },

      // Vertical drag: Swipe DOWN to dismiss & stop playback; Swipe UP to expand NowPlaying
      onVerticalDragStart: (_) {
        _isDraggingNotifier.value = true;
      },
      onVerticalDragUpdate: (details) {
        final curr = _dragOffsetNotifier.value;
        _dragOffsetNotifier.value = Offset(
          curr.dx,
          (curr.dy + details.delta.dy).clamp(-28.0, 104.0),
        );
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        final dragY = _dragOffsetNotifier.value.dy;
        if (dragY > 36.0 || velocity > 300.0) {
          HapticFeedback.mediumImpact();
          _isDraggingNotifier.value = false;
          _dragOffsetNotifier.value = Offset.zero;
          player.stopPlayback();
          return;
        }
        if (dragY < -18.0 || velocity < -300.0) {
          _isDraggingNotifier.value = false;
          _dragOffsetNotifier.value = Offset.zero;
          _openNowPlaying(context);
          return;
        }
        _isDraggingNotifier.value = false;
        _dragOffsetNotifier.value = Offset.zero;
      },
      onVerticalDragCancel: () {
        _isDraggingNotifier.value = false;
        _dragOffsetNotifier.value = Offset.zero;
      },

      // Horizontal drag: Swipe Left / Right to skip Next / Previous
      onHorizontalDragStart: (_) {
        _isDraggingNotifier.value = true;
      },
      onHorizontalDragUpdate: (details) {
        final curr = _dragOffsetNotifier.value;
        _dragOffsetNotifier.value = Offset(
          (curr.dx + details.delta.dx).clamp(-48.0, 48.0),
          curr.dy,
        );
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        final dragX = _dragOffsetNotifier.value.dx;
        if (dragX < -30.0 || velocity < -260.0) {
          HapticFeedback.lightImpact();
          player.skipNext();
        } else if (dragX > 30.0 || velocity > 260.0) {
          HapticFeedback.lightImpact();
          player.skipPrevious();
        }
        _isDraggingNotifier.value = false;
        _dragOffsetNotifier.value = Offset.zero;
      },
      onHorizontalDragCancel: () {
        _isDraggingNotifier.value = false;
        _dragOffsetNotifier.value = Offset.zero;
      },

      child: RepaintBoundary(
        child: ValueListenableBuilder<Offset>(
          valueListenable: _dragOffsetNotifier,
          child: barContent,
          builder: (context, offset, child) {
            final isDragging = _isDraggingNotifier.value;
            final dismissProgress = (offset.dy / 92.0).clamp(0.0, 1.0);
            final dragOpacity = (1.0 - dismissProgress * 0.72).clamp(0.24, 1.0);
            final dragScale = 1.0 - (dismissProgress * 0.045);

            return AnimatedOpacity(
              duration: isDragging ? Duration.zero : const Duration(milliseconds: 180),
              opacity: dragOpacity,
              child: AnimatedContainer(
                duration: isDragging ? Duration.zero : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.diagonal3Values(dragScale, dragScale, 1.0)
                  ..setTranslationRaw(offset.dx * 0.42, offset.dy * 0.72, 0.0),
                transformAlignment: Alignment.center,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

