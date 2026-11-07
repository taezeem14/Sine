import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/vinyl_disc.dart';
import '../widgets/synchronized_lyrics_view.dart';
import '../widgets/sine_qr_code_sheet.dart';
import 'equalizer_screen.dart';
import 'playback_speed_sheet.dart';
import 'track_options_sheet.dart';
import 'queue_discovery_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final song = context.select<PlayerProvider, Song?>((p) => p.currentSong);

    if (song == null) {
      return Scaffold(
        backgroundColor: EmberColors.obsidianBase,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.chevronDown, size: 20, color: EmberColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.music, size: 48, color: EmberColors.textMuted),
              const SizedBox(height: 16),
              const Text('No song playing', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Playback has been stopped', style: TextStyle(color: EmberColors.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EmberColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final playingFrom = context.select<PlayerProvider, String>((p) => p.playingFrom);
    final isolationMode = context.select<PlayerProvider, IsolationMode>((p) => p.isolationMode);
    final stemBadge = context.select<PlayerProvider, String?>((p) => p.stemStatusBadgeText);
    final isStemLoading = context.select<PlayerProvider, bool>((p) => p.isLoadingStem);
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);

    return Scaffold(
      backgroundColor: EmberColors.obsidianBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // 1. Top Navigation Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.chevronDown, size: 18, color: EmberColors.textPrimary),
                              tooltip: 'Collapse',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'PLAYING FROM',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: EmberColors.textMuted,
                                          letterSpacing: 1.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    playingFrom.toUpperCase(),
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: EmberColors.primaryBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Quick Sine QR Code Share
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.qrcode, size: 18, color: EmberColors.textSecondary),
                              tooltip: 'Show Sine QR Code',
                              onPressed: () => SineQrCodeSheet.show(context, song),
                            ),
                            // Three Dots Menu -> Opens Track Options Bottom Sheet
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 18, color: EmberColors.textSecondary),
                              tooltip: 'More Options',
                              onPressed: () => TrackOptionsSheet.show(context, song),
                            ),
                          ],
                        ),
                      ),

                      // 2. Active Studio Stem Status Banner
                      if (isolationMode != IsolationMode.none)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: EmberColors.primaryBlue.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isStemLoading) ...[
                                      const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: EmberColors.primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ] else ...[
                                      Icon(
                                        isolationMode == IsolationMode.instrumentsOnly
                                            ? Icons.music_note_rounded
                                            : Icons.mic_rounded,
                                        size: 13,
                                        color: EmberColors.primaryBlue,
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      stemBadge ??
                                          (isolationMode == IsolationMode.instrumentsOnly
                                              ? 'AI Karaoke Active'
                                              : 'AI Acapella Active'),
                                      style: const TextStyle(
                                        color: EmberColors.primaryBlue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => context.read<PlayerProvider>().revertToOriginalTrack(),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 15,
                                        color: EmberColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 3. Center Viewport: Animated flip between Album Art / Vinyl and Synchronized Lyrics
                      // Expanded ensures it occupies all available vertical display space without any dead space at the bottom
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim),
                                  child: child,
                                ),
                              ),
                              child: _showLyrics
                                  ? Container(
                                      key: const ValueKey('lyrics_mode'),
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: EmberColors.surfaceContainerLow.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: const RepaintBoundary(
                                          child: SynchronizedLyricsView(),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      key: const ValueKey('vinyl_mode'),
                                      child: GestureDetector(
                                        onTap: () => setState(() => _showLyrics = true),
                                        child: RepaintBoundary(
                                          child: AmbientGlow(
                                            isPlaying: isPlaying,
                                            child: FittedBox(
                                              fit: BoxFit.contain,
                                              child: AnimatedScale(
                                                scale: isPlaying ? 1.0 : 0.94,
                                                duration: const Duration(milliseconds: 350),
                                                curve: Curves.easeOutBack,
                                                child: SizedBox(
                                                  width: 320,
                                                  height: 280,
                                                  child: Stack(
                                                    alignment: Alignment.centerLeft,
                                                    children: [
                                                      // Vinyl disc peek from right
                                                      Positioned(
                                                        right: 0,
                                                        child: RepaintBoundary(
                                                          child: VinylDisc(
                                                            size: 240,
                                                            isPlaying: isPlaying,
                                                          ),
                                                        ),
                                                      ),
                                                      // Square album cover
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(24),
                                                        child: Container(
                                                          width: 260,
                                                          height: 260,
                                                          decoration: BoxDecoration(
                                                            color: EmberColors.surfaceContainerHigh,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors.black.withValues(alpha: 0.5),
                                                                blurRadius: 20,
                                                                offset: const Offset(4, 4),
                                                              ),
                                                            ],
                                                          ),
                                                          child: song.artworkUrl.isNotEmpty
                                                              ? CachedNetworkImage(
                                                                  imageUrl: song.artworkUrl,
                                                                  memCacheWidth: 600,
                                                                  fit: BoxFit.cover,
                                                                  errorWidget: (_, _, _) => const Center(
                                                                    child: FaIcon(FontAwesomeIcons.music, size: 48, color: EmberColors.primaryBlue),
                                                                  ),
                                                                )
                                                              : const Center(
                                                                  child: FaIcon(FontAwesomeIcons.music, size: 48, color: EmberColors.primaryBlue),
                                                                ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // 4. Title, Artist & Spotify-style Bouncy Heart
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          color: EmberColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.4,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song.artist,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: EmberColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            _SpotifyHeartButton(song: song),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 5. Scrubber Bar & Timecodes (Isolated 120 FPS Rebuild Boundary)
                      const _ScrubberSection(),

                      const SizedBox(height: 6),

                      // 6. Transport Controls (Shuffle, Previous, Play/Pause, Next, Repeat)
                      const _TransportControlsSection(),

                      const SizedBox(height: 12),

                      // 7. Utility Action Pills (Lyrics Toggle, EQ, Sleep, Speed, Queue)
                      _UtilityPillsRow(
                        showLyrics: _showLyrics,
                        onToggleLyrics: () => setState(() => _showLyrics = !_showLyrics),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =========================================================================
// ISOLATED 120 FPS SCRUBBER SECTION (Eliminates whole-screen rebuild jitter)
// =========================================================================

class _ScrubberSection extends StatefulWidget {
  const _ScrubberSection();

  @override
  State<_ScrubberSection> createState() => _ScrubberSectionState();
}

class _ScrubberSectionState extends State<_ScrubberSection> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final duration = context.select<PlayerProvider, Duration>((p) => p.duration);
    final totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ValueListenableBuilder<Duration>(
        valueListenable: player.positionNotifier,
        builder: (context, position, _) {
          final currentMs = _isDragging ? _dragValue : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();

          return Column(
            children: [
              RepaintBoundary(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: EmberColors.primaryBlue,
                    inactiveTrackColor: EmberColors.outlineVariant.withValues(alpha: 0.6),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    overlayColor: EmberColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: currentMs.clamp(0.0, totalMs),
                    max: totalMs,
                    onChangeStart: (val) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = val;
                      });
                      context.read<PlayerProvider>().setScrubbing(true);
                    },
                    onChanged: (val) {
                      setState(() {
                        _dragValue = val;
                      });
                    },
                    onChangeEnd: (val) {
                      setState(() {
                        _isDragging = false;
                      });
                      final p = context.read<PlayerProvider>();
                      p.setScrubbing(false);
                      p.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _format(Duration(milliseconds: currentMs.toInt())),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: EmberColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '-${_format(duration > Duration(milliseconds: currentMs.toInt()) ? duration - Duration(milliseconds: currentMs.toInt()) : Duration.zero)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: EmberColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =========================================================================
// SPOTIFY TRANSPORT CONTROLS
// =========================================================================

class _TransportControlsSection extends StatelessWidget {
  const _TransportControlsSection();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: FaIcon(
              FontAwesomeIcons.shuffle,
              color: player.isShuffle ? EmberColors.primaryBlue : EmberColors.textMuted,
              size: 18,
            ),
            tooltip: player.isShuffle ? 'Shuffle: On' : 'Shuffle: Off',
            onPressed: () {
              HapticFeedback.lightImpact();
              player.toggleShuffle();
            },
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.backwardStep, color: EmberColors.textPrimary, size: 24),
            tooltip: 'Previous',
            onPressed: () {
              HapticFeedback.lightImpact();
              player.skipPrevious();
            },
          ),
          // Hero 68px circular play/pause button with glowing blue shadow
          AnimatedScale(
            scale: player.isLoadingStream ? 0.93 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [EmberColors.primaryBlueHi, EmberColors.primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: EmberColors.primaryBlue.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                icon: player.isLoadingStream
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : FaIcon(
                        player.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                        color: Colors.white,
                        size: 24,
                      ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  player.togglePlay();
                },
              ),
            ),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.forwardStep, color: EmberColors.textPrimary, size: 24),
            tooltip: 'Next',
            onPressed: () {
              HapticFeedback.lightImpact();
              player.skipNext();
            },
          ),
          IconButton(
            icon: Icon(
              player.repeatMode == 'one'
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: player.repeatMode != 'off' ? EmberColors.primaryBlue : EmberColors.textMuted,
              size: 24,
            ),
            tooltip: player.repeatMode == 'one'
                ? 'Repeat: One'
                : (player.repeatMode == 'all' ? 'Repeat: All' : 'Repeat: Off'),
            onPressed: () {
              HapticFeedback.lightImpact();
              player.cycleRepeatMode();
            },
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// SPOTIFY BOUNCY ANIMATED HEART BUTTON
// =========================================================================

class _SpotifyHeartButton extends StatefulWidget {
  final Song song;
  const _SpotifyHeartButton({required this.song});

  @override
  State<_SpotifyHeartButton> createState() => _SpotifyHeartButtonState();
}

class _SpotifyHeartButtonState extends State<_SpotifyHeartButton> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.mediumImpact();
    _anim.forward(from: 0.0);
    final player = context.read<PlayerProvider>();
    final isFav = player.isFavorite(widget.song.id);
    player.toggleFavorite(widget.song);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: EmberColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            FaIcon(
              !isFav ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
              color: !isFav ? EmberColors.primaryBlue : EmberColors.textMuted,
              size: 15,
            ),
            const SizedBox(width: 10),
            Text(
              !isFav ? 'Added to Liked Songs' : 'Removed from Liked Songs',
              style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<PlayerProvider, bool>((p) => p.isFavorite(widget.song.id));

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final scale = 1.0 + (0.35 * (1.0 - (2 * (_anim.value - 0.5)).abs()));
          return Transform.scale(
            scale: scale,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FaIcon(
                isFavorite ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                size: 24,
                color: isFavorite ? EmberColors.primaryBlue : EmberColors.textMuted,
              ),
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// UTILITY PILLS ROW
// =========================================================================

class _UtilityPillsRow extends StatelessWidget {
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  static bool _isQueueNavigating = false;

  const _UtilityPillsRow({
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  void _showSleepTimerDialog(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.45,
          maxChildSize: 0.88,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: EmberColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: ValueListenableBuilder<int>(
                  valueListenable: player.sleepSecondsNotifier,
                  builder: (context, remainingSecs, _) {
                    final isTimerActive = player.sleepAtTrackEnd || remainingSecs > 0;
                    final remainingText = player.sleepAtTrackEnd
                        ? 'At end of this song'
                        : (remainingSecs > 0
                            ? '${(remainingSecs / 60).ceil()} mins remaining'
                            : 'Off');

                    return ListView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: EmberColors.textMuted.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'Sleep Timer',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: EmberColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            isTimerActive ? 'Active: $remainingText' : 'Set music to stop automatically',
                            style: TextStyle(
                              color: isTimerActive ? EmberColors.primaryBlue : EmberColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Clear & Explicit Cancel / Turn Off Option (Always Available)
                        ListTile(
                          leading: Icon(
                            Icons.timer_off_rounded,
                            color: isTimerActive ? EmberColors.error : EmberColors.textMuted,
                          ),
                          title: Text(
                            'Turn Off Timer',
                            style: TextStyle(
                              color: isTimerActive ? EmberColors.error : EmberColors.textSecondary,
                              fontWeight: isTimerActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            isTimerActive ? 'Cancel the active sleep timer immediately' : 'No sleep timer is currently active',
                            style: const TextStyle(color: EmberColors.textMuted, fontSize: 11),
                          ),
                          trailing: !isTimerActive ? const Icon(Icons.check, color: EmberColors.textMuted, size: 18) : null,
                          onTap: () {
                            player.cancelSleepTimer();
                            Navigator.pop(context);
                          },
                        ),
                        const Divider(color: EmberColors.outlineVariant, height: 16),

                        ListTile(
                          leading: const Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
                          title: const Text('End of this song', style: TextStyle(color: EmberColors.textPrimary, fontWeight: FontWeight.w600)),
                          trailing: player.sleepAtTrackEnd ? const Icon(Icons.check, color: EmberColors.primaryBlue) : null,
                          onTap: () {
                            player.setSleepAtTrackEnd(true);
                            Navigator.pop(context);
                          },
                        ),
                        for (final mins in [5, 10, 15, 30, 45, 60, 90, 120])
                          ListTile(
                            leading: const FaIcon(FontAwesomeIcons.clock, size: 16, color: EmberColors.textMuted),
                            title: Text('$mins minutes', style: const TextStyle(color: EmberColors.textPrimary)),
                            trailing: (!player.sleepAtTrackEnd && remainingSecs == mins * 60)
                                ? const Icon(Icons.check, color: EmberColors.primaryBlue)
                                : null,
                            onTap: () {
                              player.startSleepTimer(mins);
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4, top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _PillAction(
              icon: FontAwesomeIcons.alignLeft,
              label: showLyrics ? 'Cover' : 'Lyrics',
              active: showLyrics,
              onTap: onToggleLyrics,
            ),
            const SizedBox(width: 8),
            _PillAction(
              icon: FontAwesomeIcons.sliders,
              label: player.eqPreset.split(' ').first,
              active: player.eqEnabled,
              onTap: () => EqualizerScreen.open(context),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: player.sleepSecondsNotifier,
              builder: (context, remainingSecs, _) {
                final isTimerActive = player.sleepAtTrackEnd || remainingSecs > 0;
                final label = player.sleepAtTrackEnd
                    ? 'Track End'
                    : (remainingSecs > 0
                        ? '${(remainingSecs / 60).ceil()}m'
                        : 'Sleep');
                return _PillAction(
                  icon: FontAwesomeIcons.moon,
                  label: label,
                  active: isTimerActive,
                  onTap: () => _showSleepTimerDialog(context, player),
                );
              },
            ),
            const SizedBox(width: 8),
            _PillAction(
              icon: FontAwesomeIcons.gaugeHigh,
              label: '${(player.speed * 10).round() == player.speed * 10 ? player.speed.toStringAsFixed(1) : player.speed.toStringAsFixed(2)}x',
              active: (player.speed - 1.0).abs() > 0.01,
              onTap: () => PlaybackSpeedSheet.show(context),
            ),
            const SizedBox(width: 8),
            _PillAction(
              icon: FontAwesomeIcons.listUl,
              label: player.queue.isNotEmpty
                  ? 'Queue (${player.currentIndex + 1}/${player.queue.length})'
                  : 'Queue',
              active: player.queue.length > 1,
              onTap: () {
                if (_isQueueNavigating) return;
                _isQueueNavigating = true;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QueueDiscoveryScreen()),
                ).then((_) => _isQueueNavigating = false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final FaIconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PillAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? EmberColors.primaryBlue.withValues(alpha: 0.18) : EmberColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: active ? EmberColors.primaryBlue : EmberColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 12, color: active ? EmberColors.primaryBlue : EmberColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? EmberColors.primaryBlueHi : EmberColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

