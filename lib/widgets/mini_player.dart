import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import '../services/cover_color_service.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  static bool _isNavigating = false;

  // Interactive gesture state (separate X & Y axes cleanly resolved by Flutter's gesture arena)
  double _dragX = 0.0;
  double _dragY = 0.0;
  bool _isDragging = false;

  // Real extracted album cover palette state
  CoverPalette _palette = CoverPalette.defaultPalette;
  String? _lastPaletteKey;

  @override
  void initState() {
    super.initState();
    CoverColorService.instance.paletteRevision.addListener(_onPaletteRevision);
  }

  @override
  void dispose() {
    CoverColorService.instance.paletteRevision.removeListener(_onPaletteRevision);
    super.dispose();
  }

  void _onPaletteRevision() {
    if (!mounted) return;
    final song = context.read<PlayerProvider>().currentSong;
    if (song == null) return;
    final latest = CoverColorService.instance.getPaletteSync(song);
    if (latest != _palette) {
      setState(() => _palette = latest);
    }
  }

  void _syncCoverPalette(Song? song) {
    if (song == null) {
      _lastPaletteKey = null;
      return;
    }
    final key = '${song.id}_${song.artworkUrl}';
    if (_lastPaletteKey == key) return;
    _lastPaletteKey = key;

    // Immediate cached real palette (or refined dark slate while bitmap decodes)
    _palette = CoverColorService.instance.getPaletteSync(song);

    // Trigger real pixel extraction from CachedNetworkImage bitmap
    if (!_palette.isExtracted && song.artworkUrl.trim().isNotEmpty) {
      CoverColorService.instance.getPalette(song).then((extracted) {
        if (!mounted) return;
        if (_lastPaletteKey == key && extracted != _palette) {
          setState(() => _palette = extracted);
        }
      });
    }
  }

  Future<void> _openNowPlaying(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;
    HapticFeedback.lightImpact();
    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, anim, secAnim) => const NowPlayingScreen(),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, anim, secAnim, child) {
            final slideTween = Tween(begin: const Offset(0.0, 0.12), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic));
            final fadeTween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutCubic));
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

    _syncCoverPalette(song);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
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
    final palette = _palette;
    const baseSurface = Color(0xFF12141B);

    // Rich cover-derived surface gradient (unmistakably matched to album artwork while keeping WCAG AAA white text contrast)
    final gradStart = Color.lerp(baseSurface, palette.dominant, 0.56)!;
    final gradEnd = Color.lerp(baseSurface, palette.secondary, 0.42)!;
    final borderTint = Color.lerp(Colors.white, palette.accent, 0.60)!.withValues(alpha: 0.20);
    final progressColor = Color.lerp(palette.accent, Colors.white, 0.32)!;

    // Progressive dismiss visual feedback when swiping down
    final double dismissProgress = (_dragY / 92.0).clamp(0.0, 1.0);
    final double dragOpacity = (1.0 - dismissProgress * 0.72).clamp(0.24, 1.0);
    final double dragScale = 1.0 - (dismissProgress * 0.045);

    return GestureDetector(
      key: const ValueKey('mini_active'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNowPlaying(context),

      // Vertical drag: Swipe DOWN to dismiss & stop playback; Swipe UP to expand NowPlaying
      onVerticalDragStart: (_) {
        setState(() => _isDragging = true);
      },
      onVerticalDragUpdate: (details) {
        setState(() {
          // Allow generous downward travel for dismissal, subtle upward pull for expansion
          _dragY = (_dragY + details.delta.dy).clamp(-26.0, 100.0);
        });
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        if (_dragY > 38.0 || velocity > 320.0) {
          // Dismiss & stop playback cleanly
          HapticFeedback.mediumImpact();
          setState(() {
            _isDragging = false;
            _dragY = 0.0;
            _dragX = 0.0;
          });
          player.stopPlayback();
          return;
        }
        if (_dragY < -20.0 || velocity < -320.0) {
          // Swipe up opens full NowPlayingScreen
          setState(() {
            _isDragging = false;
            _dragY = 0.0;
          });
          _openNowPlaying(context);
          return;
        }
        setState(() {
          _isDragging = false;
          _dragY = 0.0;
        });
      },
      onVerticalDragCancel: () {
        setState(() {
          _isDragging = false;
          _dragY = 0.0;
        });
      },

      // Horizontal drag: Swipe Left / Right to skip Next / Previous
      onHorizontalDragStart: (_) {
        setState(() => _isDragging = true);
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragX = (_dragX + details.delta.dx).clamp(-48.0, 48.0);
        });
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        if (_dragX < -30.0 || velocity < -260.0) {
          HapticFeedback.lightImpact();
          player.skipNext();
        } else if (_dragX > 30.0 || velocity > 260.0) {
          HapticFeedback.lightImpact();
          player.skipPrevious();
        }
        setState(() {
          _isDragging = false;
          _dragX = 0.0;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _isDragging = false;
          _dragX = 0.0;
        });
      },

      child: AnimatedOpacity(
        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 180),
        opacity: dragOpacity,
        child: AnimatedContainer(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(dragScale, dragScale, 1.0)
            ..setTranslationRaw(_dragX * 0.42, _dragY * 0.72, 0.0),
          transformAlignment: Alignment.center,
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [gradStart, gradEnd],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderTint, width: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
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
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 6, 8),
                child: Row(
                  children: [
                    // Crisp rounded-square album artwork with Hero continuity to NowPlayingScreen
                    Hero(
                      tag: 'player_art_${song.id.isNotEmpty ? song.id : "default"}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: Colors.black26,
                          child: song.artworkUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: song.artworkUrl,
                                  width: 44,
                                  height: 44,
                                  memCacheWidth: 120,
                                  memCacheHeight: 120,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const Center(
                                    child: FaIcon(
                                      FontAwesomeIcons.music,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.music,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),

                    // Clean Track Title & Artist with restrained cross-fade
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
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
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isolationMode == IsolationMode.instrumentsOnly
                                          ? 'KARAOKE'
                                          : 'VOCALS',
                                      style: const TextStyle(
                                        color: Colors.white,
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
                                      color: Colors.white.withValues(alpha: 0.70),
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
                        color: isFav ? progressColor : Colors.white.withValues(alpha: 0.65),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        player.toggleFavorite(song);
                      },
                      splashRadius: 20,
                    ),

                    // Clean Play / Pause Button (crisp, high-contrast, zero neon clutter)
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            player.togglePlay();
                          },
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: isLoading
                                  ? const SizedBox(
                                      key: ValueKey('mini_loading'),
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        color: Colors.white.withValues(alpha: 0.82),
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

              // Precision 2px bottom progress hairline harmonized to real cover palette
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
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
