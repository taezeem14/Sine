import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/ember_theme.dart';
import 'vinyl_disc.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        player.stopPlayback();
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            player.skipNext();
          } else if (details.primaryVelocity! > 200) {
            player.skipPrevious();
          }
        }
      },
      onTap: () async {
        if (_isNavigating) return;
        _isNavigating = true;
        HapticFeedback.lightImpact();
        try {
          await Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, anim, secAnim) => const NowPlayingScreen(),
              transitionDuration: const Duration(milliseconds: 320),
              reverseTransitionDuration: const Duration(milliseconds: 280),
              transitionsBuilder: (context, anim, secAnim, child) {
                final slideTween = Tween(begin: const Offset(0.0, 0.15), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
                final fadeTween = Tween(begin: 0.0, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeOut));
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
      },
      child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        decoration: BoxDecoration(
          color: EmberColors.surfaceContainerLow.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 2px top progress bar (RepaintBoundary for 120 FPS buttery rendering)
            RepaintBoundary(
              child: ValueListenableBuilder<Duration>(
                valueListenable: player.positionNotifier,
                builder: (context, pos, _) {
                  final totalMs = player.duration.inMilliseconds;
                  final double progress = totalMs > 0 ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(EmberColors.primaryBlue),
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
                          size: 42,
                          isPlaying: player.isPlaying,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: song.artworkUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: song.artworkUrl,
                                  width: 28,
                                  height: 28,
                                  memCacheWidth: 80,
                                  memCacheHeight: 80,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => FaIcon(FontAwesomeIcons.music, size: 14, color: EmberColors.primaryBlue),
                                )
                              : FaIcon(FontAwesomeIcons.music, size: 14, color: EmberColors.primaryBlue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: EmberColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (player.isolationMode != IsolationMode.none) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: EmberColors.primaryBlue.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: EmberColors.primaryBlue.withValues(alpha: 0.3), width: 0.8),
                                ),
                                child: Text(
                                  player.isolationMode == IsolationMode.instrumentsOnly ? 'AI KARAOKE' : 'AI VOCALS',
                                  style: const TextStyle(
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
                  // Favorite Heart
                  IconButton(
                    icon: FaIcon(
                      player.isFavorite(song.id) ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                      size: 18,
                      color: player.isFavorite(song.id) ? EmberColors.primaryBlue : EmberColors.textMuted,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.toggleFavorite(song);
                    },
                    splashRadius: 20,
                  ),
                  // Circular Play/Pause button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: EmberColors.primaryBlue,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: player.isLoadingStream
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : FaIcon(
                              player.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                              color: Colors.white,
                              size: 16,
                            ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        player.togglePlay();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Skip Next
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.forwardStep, size: 18, color: EmberColors.textSecondary),
                    onPressed: () => player.skipNext(),
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

