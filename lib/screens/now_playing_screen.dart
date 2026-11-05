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
import '../services/smart_radio_service.dart';
import '../services/lyrics_service.dart';
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

  static String _getMonthlyListeners(String artist) {
    final clean = artist.trim().toLowerCase();
    final topArtists = <String, String>{
      'the weeknd': '114,820,910',
      'taylor swift': '105,430,224',
      'drake': '86,120,450',
      'billie eilish': '98,400,120',
      'ariana grande': '84,650,890',
      'ed sheeran': '82,100,340',
      'bad bunny': '76,500,200',
      'justin bieber': '75,200,110',
      'eminem': '72,300,800',
      'dua lipa': '78,210,900',
      'post malone': '68,900,400',
      'arijit singh': '44,920,150',
      'atif aslam': '23,450,800',
      'sidhu moose wala': '18,740,600',
      'coldplay': '80,410,230',
      'bruno mars': '112,450,890',
      'lady gaga': '92,300,450',
      'travis scott': '67,820,100',
      'kanye west': '63,400,500',
      'kendrick lamar': '69,200,300',
      'rihanna': '79,150,000',
    };

    for (final entry in topArtists.entries) {
      if (clean.contains(entry.key)) {
        return '${entry.value} monthly listeners';
      }
    }

    // Deterministic realistic listener count calculation based on artist hash
    final hash = clean.codeUnits.fold<int>(0, (prev, elem) => (prev * 31 + elem) & 0x7FFFFFFF);
    final count = 1500000 + (hash % 35000000);
    final formatted = count.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formatted monthly listeners';
  }

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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                                      ? 'Demucs Karaoke Active'
                                      : 'Demucs Acapella Active'),
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

              const SizedBox(height: 8),

              // 3. Center Viewport: Animated flip between Album Art / Vinyl and Synchronized Lyrics
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 310,
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
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: 290,
                                      height: 250,
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          // Vinyl disc peek from right
                                          Positioned(
                                            right: 0,
                                            child: RepaintBoundary(
                                              child: VinylDisc(
                                                size: 210,
                                                isPlaying: isPlaying,
                                              ),
                                            ),
                                          ),
                                          // Square album cover
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(24),
                                            child: Container(
                                              width: 230,
                                              height: 230,
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

              const SizedBox(height: 12),

              // 4. Title, Artist & Spotify-style Bouncy Heart
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
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

              const SizedBox(height: 14),

              // 5. Scrubber Bar & Timecodes (Isolated 120 FPS Rebuild Boundary)
              const _ScrubberSection(),

              const SizedBox(height: 8),

              // 6. Transport Controls (Shuffle, Previous, Play/Pause, Next, Repeat)
              const _TransportControlsSection(),

              const SizedBox(height: 12),

              // 7. Utility Action Pills (Lyrics Toggle, EQ, Sleep, Speed, Queue)
              _UtilityPillsRow(
                showLyrics: _showLyrics,
                onToggleLyrics: () => setState(() => _showLyrics = !_showLyrics),
              ),

              const SizedBox(height: 20),

              // ==========================================
              // 8. SPOTIFY-STYLE CONTENT CARDS (SCROLLABLE)
              // ==========================================

              // A. Spotify Synced Lyrics Preview Card
              if (!_showLyrics && !LyricsService.isTempoModified(song.title, song.artist))
                _SpotifyLyricsPreviewCard(
                  onExpand: () => setState(() => _showLyrics = true),
                ),

              // B. About the Artist Card (Real Photo, Monthly Listeners, Bio & Radio)
              _SpotifyAboutArtistCard(
                artist: song.artist,
                artworkUrl: song.artworkUrl,
                monthlyListeners: _getMonthlyListeners(song.artist),
              ),

              // C. Song Credits Card (Performed by, Written by, Source, Engine)
              _SpotifyCreditsCard(song: song),

              // D. Next in Queue Preview Card
              const _SpotifyNextUpCard(),

              const SizedBox(height: 48),
            ],
          ),
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

// =========================================================================
// SPOTIFY CONTENT CARDS (Live Lyrics, About Artist, Credits, Next Up)
// =========================================================================

class _SpotifyLyricsPreviewCard extends StatelessWidget {
  final VoidCallback onExpand;

  const _SpotifyLyricsPreviewCard({required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final lyrics = player.syncedLyrics;
    final hasSynced = player.hasSyncedLyrics;
    final plain = player.plainLyrics;
    final isLoading = player.isLoadingLyrics;

    if (!isLoading && !hasSynced && plain.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EmberColors.primaryBlue.withValues(alpha: 0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onExpand,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lyrics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Text('More', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.open_in_full_rounded, size: 11, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<int>(
                  valueListenable: player.activeLyricIndexNotifier,
                  builder: (context, currentIdx, _) {
                    final String activeText;
                    if (isLoading) {
                      activeText = 'Loading lyrics...';
                    } else if (hasSynced && lyrics.isNotEmpty) {
                      if (currentIdx >= 0 && currentIdx < lyrics.length) {
                        activeText = lyrics[currentIdx].text;
                      } else {
                        activeText = lyrics.first.text;
                      }
                    } else if (plain.trim().isNotEmpty) {
                      activeText = plain.split('\n').firstWhere(
                            (l) => l.trim().isNotEmpty,
                            orElse: () => 'Lyrics available',
                          );
                    } else {
                      activeText = '♪ Synced Lyrics Available ♪';
                    }

                    return Text(
                      activeText,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotifyAboutArtistCard extends StatelessWidget {
  final String artist;
  final String artworkUrl;
  final String monthlyListeners;

  const _SpotifyAboutArtistCard({
    required this.artist,
    required this.artworkUrl,
    required this.monthlyListeners,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: EmberColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artist Header Image with Rounded Top
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: artworkUrl,
                    memCacheWidth: 400,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(color: EmberColors.surfaceContainerHigh),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          EmberColors.surfaceContainerLow.withValues(alpha: 0.8),
                          EmberColors.surfaceContainerLow,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'About the artist',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.verified_rounded, color: EmberColors.primaryBlue, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  monthlyListeners,
                  style: const TextStyle(
                    color: EmberColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmberColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final player = context.read<PlayerProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    SmartRadioService.instance
                        .generateArtistRadio(artistName: artist)
                        .then((tracks) {
                      if (tracks.isNotEmpty) {
                        player.playCategoryTracks(
                          tracks,
                          playingFrom: 'Artist Radio: $artist',
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: EmberColors.surfaceContainerHigh,
                            content: Text('Playing Artist Radio for $artist', style: const TextStyle(color: EmberColors.primaryBlueHi)),
                          ),
                        );
                      }
                    });
                  },
                  icon: const FaIcon(FontAwesomeIcons.radio, size: 13),
                  label: const Text('Start Artist Radio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotifyCreditsCard extends StatelessWidget {
  final Song song;
  const _SpotifyCreditsCard({required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EmberColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credits',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          _CreditRow(label: 'Performed by', value: song.artist),
          const SizedBox(height: 10),
          _CreditRow(label: 'Track', value: song.title),
          const SizedBox(height: 10),
          const _CreditRow(label: 'Source', value: 'YouTube Music Opus Audio (160 kbps, 48 kHz)'),
          const SizedBox(height: 10),
          const _CreditRow(label: 'Audio DSP', value: 'Sine 6-Band Graph EQ & Hearth Bass Engine'),
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String label;
  final String value;
  const _CreditRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: EmberColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _SpotifyNextUpCard extends StatelessWidget {
  const _SpotifyNextUpCard();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;
    final nextIdx = player.currentIndex + 1;
    final nextSong = (nextIdx >= 0 && nextIdx < queue.length) ? queue[nextIdx] : null;

    if (nextSong == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: EmberColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: nextSong.artworkUrl,
            width: 44,
            height: 44,
            memCacheWidth: 150,
            memCacheHeight: 150,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              width: 44,
              height: 44,
              color: EmberColors.surfaceContainerHigh,
              child: const Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
            ),
          ),
        ),
        title: Row(
          children: [
            const Text(
              'NEXT UP  •  ',
              style: TextStyle(color: EmberColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            Expanded(
              child: Text(
                nextSong.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Text(
          nextSong.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: EmberColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: EmberColors.textMuted),
        onTap: () {
          if (_UtilityPillsRow._isQueueNavigating) return;
          _UtilityPillsRow._isQueueNavigating = true;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QueueDiscoveryScreen()),
          ).then((_) => _UtilityPillsRow._isQueueNavigating = false);
        },
      ),
    );
  }
}
