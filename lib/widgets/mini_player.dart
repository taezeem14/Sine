import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/ember_theme.dart';

/// Docked floating MiniPlayer featuring Sine's clean signature theme surface,
/// zero-rebuild ValueNotifier swipe physics (swipe down to dismiss & stop playback,
/// swipe up to expand NowPlaying, swipe left/right to skip), and locked 60/120 FPS
/// full-sheet bottom-up player expansion.
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
    // Signature classic Sine surface palette (clean, refined dark obsidian + theme accent hairline)
    final Color surfaceStart = isOled ? const Color(0xFF0D0F14) : const Color(0xFF151822);
    final Color surfaceEnd = isOled ? const Color(0xFF080A0E) : const Color(0xFF10131B);
    final Color borderTint = accentColor.withValues(alpha: 0.24);
    final Color progressColor = accentColor;

    // Pre-build static bar content ONCE so 120 FPS drag gesture updates never rebuild children
    final barContent = Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [surfaceStart, surfaceEnd],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderTint, width: 0.9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtle top drag pill indicator (physical cue for swipe down to dismiss / up to expand)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 26,
              height: 2.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 6, 8),
            child: Row(
              children: [
                // Crisp rounded-square album artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: EmberColors.surfaceContainerHigh,
                    child: song.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: song.artworkUrl,
                            width: 44,
                            height: 44,
                            memCacheWidth: 160,
                            memCacheHeight: 160,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Center(
                              child: FaIcon(
                                FontAwesomeIcons.music,
                                size: 16,
                                color: accentColor,
                              ),
                            ),
                          )
                        : Center(
                            child: FaIcon(
                              FontAwesomeIcons.music,
                              size: 16,
                              color: accentColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 11),

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

                // Clean Favorite Button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: FaIcon(
                    isFav ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                    size: 16,
                    color: isFav ? accentColor : Colors.white.withValues(alpha: 0.62),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    player.toggleFavorite(song);
                  },
                  splashRadius: 20,
                ),

                // Clean Play / Pause Button
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Material(
                    color: accentColor.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        player.togglePlay();
                      },
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: isLoading
                              ? SizedBox(
                                  key: const ValueKey('mini_loading'),
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                  ),
                                )
                              : FaIcon(
                                  isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                                  key: ValueKey(isPlaying ? 'mini_pause' : 'mini_play'),
                                  color: Colors.white,
                                  size: 14,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Skip Next Button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: FaIcon(
                    FontAwesomeIcons.forwardStep,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.80),
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

          // Precision 2px bottom progress hairline in Sine's signature theme accent
          RepaintBoundary(
            child: ValueListenableBuilder<Duration>(
              valueListenable: player.positionNotifier,
              builder: (context, pos, _) {
                final totalMs = duration.inMilliseconds;
                final double progress =
                    totalMs > 0 ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.0,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                );
              },
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      key: const ValueKey('mini_active'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNowPlaying(context),

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
