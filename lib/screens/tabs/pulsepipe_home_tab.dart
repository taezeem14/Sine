import '../../widgets/music_detector_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/song.dart';
import '../../models/playlist.dart';
import '../../providers/player_provider.dart';
import '../../services/catalog_service.dart';
import '../../theme/ember_theme.dart';
import '../settings_screen.dart';
import '../sound_shaping_sheet.dart';
import '../track_options_sheet.dart';

typedef SineHomeTab = PulsePipeHomeTab;

class PulsePipeHomeTab extends StatefulWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenSearch;

  const PulsePipeHomeTab({
    super.key,
    required this.onOpenLibrary,
    required this.onOpenSearch,
  });

  @override
  State<PulsePipeHomeTab> createState() => _PulsePipeHomeTabState();
}

class _PulsePipeHomeTabState extends State<PulsePipeHomeTab> {
  static const Map<String, String> _pillToCategoryKey = {
    'All': 'trending',
    'Top Hits': 'top_hits',
    'Pop': 'pop',
    'Hip-Hop': 'hiphop',
    'Electronic': 'electronic',
    'Lo-Fi': 'lofi',
    'Rock': 'rock',
  };

  String _pillForCategoryKey(String key) {
    for (final entry in _pillToCategoryKey.entries) {
      if (entry.value == key) return entry.key;
    }
    return 'All';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDurationMs(int ms) {
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final player = context.read<PlayerProvider>();
      player.loadYouTubeTrending();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = context.select<PlayerProvider, bool>((p) => p.recoverableSession != null);
    final isYtLoading = context.select<PlayerProvider, bool>((p) => p.isLoadingYouTube);
    final isYtLoadingMore = context.select<PlayerProvider, bool>((p) => p.isLoadingMoreYouTube);
    final activeCatKey = context.select<PlayerProvider, String>((p) => p.activeHomeCategory);
    final ytTracks = context.select<PlayerProvider, List<Song>>((p) => p.youtubeTracks);
    final isOled = context.select<PlayerProvider, bool>((p) => p.isOledBlack);
    final bgColor = isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase;
    final player = context.read<PlayerProvider>();
    final selectedPill = _pillForCategoryKey(activeCatKey);
    final activeMeta = CatalogService.getCategoryMeta(activeCatKey);

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: EmberColors.surfaceContainerHigh,
        onRefresh: () async {
          await player.loadYouTubeCategory(activeCatKey, force: true);
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              final m = notification.metrics;
              if (m.maxScrollExtent > 0 && m.extentAfter < 500) {
                player.loadMoreYouTubeTracks();
              }
            }
            return false;
          },
          child: CustomScrollView(
        key: const PageStorageKey<String>('sine_home_scroll'),
        cacheExtent: 800,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Top Bar with Greeting & Quick Actions
          SliverAppBar(
            backgroundColor: bgColor.withValues(alpha: 0.95),
            elevation: 0,
            floating: true,
            pinned: false,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Text(
              _getGreeting(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EmberColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: FaIcon(FontAwesomeIcons.microphoneLines, size: 16, color: EmberColors.primaryBlue),
                tooltip: 'Audile Music Detector',
                onPressed: () => MusicDetectorSheet.show(context),
              ),
              IconButton(
                icon: FaIcon(FontAwesomeIcons.sliders, size: 16, color: EmberColors.textPrimary),
                tooltip: 'Audiophile Equalizer',
                onPressed: () => SoundShapingSheet.show(context),
              ),
              IconButton(
                icon: FaIcon(FontAwesomeIcons.clockRotateLeft, size: 16, color: EmberColors.textPrimary),
                tooltip: 'Listening History',
                onPressed: widget.onOpenLibrary,
              ),
              IconButton(
                icon: FaIcon(FontAwesomeIcons.gear, size: 16, color: EmberColors.textPrimary),
                tooltip: 'Settings & Author',
                onPressed: () => SettingsScreen.show(context),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // 1b. Persistent Playback Session Recovery Banner
          if (hasSession && player.recoverableSession != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EmberColors.primaryAmber.withValues(alpha: 0.18),
                      EmberColors.surfaceContainerHigh.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: EmberColors.primaryAmber.withValues(alpha: 0.45),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: EmberColors.primaryAmber.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EmberColors.primaryAmber,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.play_arrow_rounded, color: EmberColors.obsidianBase, size: 24),
                        onPressed: () => player.resumeRecoveredSession(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'RESUME SESSION',
                                style: TextStyle(
                                  color: EmberColors.primaryAmberHi,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${_formatDurationMs(player.recoverableSession!.positionMs)}',
                                style: const TextStyle(
                                  color: EmberColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            player.recoverableSession!.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EmberColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: EmberColors.textMuted, size: 18),
                      tooltip: 'Dismiss',
                      onPressed: () => player.dismissRecoverableSession(),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Filter Pills Row (YouTube Music Genres)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SingleChildScrollView(
                    key: const PageStorageKey<String>('sine_home_genre_pills'),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                  children: _pillToCategoryKey.keys.map((pill) {
                    final isSelected = selectedPill == pill;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          final targetKey = _pillToCategoryKey[pill] ?? 'trending';
                          player.loadYouTubeCategory(targetKey);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? EmberColors.primaryBlue : EmberColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: isSelected ? EmberColors.primaryBlue : EmberColors.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            pill,
                            style: TextStyle(
                              color: isSelected ? Colors.black : EmberColors.textPrimary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                    ),
                  ),
                ),
                if (isYtLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),

          // 3. Quick Access 2-Column Grid (6 Cards)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.1,
              ),
              delegate: SliverChildListDelegate([
                _buildQuickAccessCard(
                  title: 'Liked Tracks',
                  isLikedSongs: true,
                  onTap: widget.onOpenLibrary,
                  isPlaying: player.favorites.any((s) => s.id == player.currentSong?.id),
                ),
                _buildQuickAccessCard(
                  title: 'Today\'s Top Hits',
                  onTap: () => player.loadYouTubeCategory('trending'),
                  icon: FontAwesomeIcons.chartLine,
                  iconColor: EmberColors.primaryBlue,
                  isPlaying: activeCatKey == 'trending',
                ),
                _buildQuickAccessCard(
                  title: 'Global Top 50',
                  onTap: () => player.loadYouTubeCategory('top_hits'),
                  icon: FontAwesomeIcons.trophy,
                  iconColor: EmberColors.secondaryCyan,
                  isPlaying: activeCatKey == 'top_hits',
                ),
                _buildQuickAccessCard(
                  title: 'Hip-Hop Beats',
                  onTap: () => player.loadYouTubeCategory('hiphop'),
                  icon: FontAwesomeIcons.microphoneLines,
                  iconColor: EmberColors.electricBlue,
                  isPlaying: activeCatKey == 'hiphop',
                ),
                _buildQuickAccessCard(
                  title: 'Electronic Pulse',
                  onTap: () => player.loadYouTubeCategory('electronic'),
                  icon: FontAwesomeIcons.bolt,
                  iconColor: EmberColors.secondaryCyan,
                  isPlaying: activeCatKey == 'electronic',
                ),
                _buildQuickAccessCard(
                  title: 'Lo-Fi Chill',
                  onTap: () => player.loadYouTubeCategory('lofi'),
                  icon: FontAwesomeIcons.headphones,
                  iconColor: EmberColors.electricBlue,
                  isPlaying: activeCatKey == 'lofi',
                ),
              ]),
            ),
          ),

          // 4. Section: Active Category Carousel
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: activeMeta.title,
              subtitle: activeMeta.subtitle,
              actionText: 'Play all',
              onAction: () {
                if (ytTracks.isNotEmpty) {
                  player.playPlaylist(
                    Playlist(
                      id: 'yt_cat_$activeCatKey',
                      title: activeMeta.title,
                      description: activeMeta.subtitle,
                      songs: ytTracks,
                      createdAt: DateTime.now(),
                      coverUrl: ytTracks.first.artworkUrl,
                    ),
                  );
                }
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ytTracks.isEmpty
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  : ListView.builder(
                      key: PageStorageKey<String>('sine_home_carousel_$activeCatKey'),
                      scrollDirection: Axis.horizontal,
                      cacheExtent: 600,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ytTracks.length,
                      itemBuilder: (context, index) {
                        final track = ytTracks[index];
                        return RepaintBoundary(
                          key: ValueKey('carousel_${track.id}'),
                          child: _buildTrackCarouselCard(
                            track,
                            () => player.playCategoryTracks(
                              ytTracks,
                              startIndex: index,
                              targetSong: track,
                              playingFrom: activeMeta.title,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 5. Section: Infinite Category / Charts Stream
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: activeCatKey == 'trending'
                  ? 'Global Charts & Fresh Releases'
                  : '${activeMeta.title} • Full Stream',
              subtitle: 'Scroll down for infinite tracks streaming via NewPipe (${ytTracks.length}+ loaded)',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (ytTracks.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                    );
                  }
                  final track = ytTracks[index];
                  return RepaintBoundary(
                    key: ValueKey(track.id),
                    child: _HomeTrackTile(
                      track: track,
                      index: index,
                      allTracks: ytTracks,
                    ),
                  );
                },
                childCount: ytTracks.isEmpty ? 1 : ytTracks.length,
              ),
            ),
          ),

          if (isYtLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),

          // Extra bottom padding for floating mini-player & bottom nav
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required String title,
    String? imageUrl,
    FaIconData? icon,
    Color? iconColor,
    bool isLikedSongs = false,
    required VoidCallback onTap,
    bool isPlaying = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: EmberColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPlaying
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)
                : EmberColors.outlineVariant.withValues(alpha: 0.25),
            width: isPlaying ? 1.2 : 0.7,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            if (isLikedSongs)
              Container(
                width: 52,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: FaIcon(FontAwesomeIcons.solidHeart, size: 18, color: Colors.white),
                ),
              )
            else if (icon != null)
              Container(
                width: 52,
                height: double.infinity,
                color: (iconColor ?? EmberColors.electricBlue).withValues(alpha: 0.15),
                child: Center(
                  child: FaIcon(icon, size: 20, color: iconColor ?? EmberColors.electricBlue),
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: imageUrl ?? '',
                width: 52,
                height: double.infinity,
                memCacheWidth: 150,
                memCacheHeight: 150,
                fit: BoxFit.cover,
                errorWidget: (context, error, stackTrace) => Container(
                  width: 52,
                  color: EmberColors.surfaceContainerHigh,
                  child: const Center(child: FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.textMuted)),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: EmberColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (isPlaying)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: FaIcon(FontAwesomeIcons.volumeHigh, size: 12, color: EmberColors.primaryBlue),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: EmberColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: EmberColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText,
                style: const TextStyle(
                  color: EmberColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackCarouselCard(Song track, VoidCallback onTap) {
    return RepaintBoundary(
      key: ValueKey(track.id),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 135,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: track.artworkUrl,
                width: 135,
                height: 135,
                memCacheWidth: 300,
                memCacheHeight: 300,
                fit: BoxFit.cover,
                errorWidget: (context, error, stackTrace) => Container(
                  width: 135,
                  height: 135,
                  color: EmberColors.surfaceContainerHigh,
                  child: const Center(child: FaIcon(FontAwesomeIcons.music, size: 28, color: EmberColors.textMuted)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EmberColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: EmberColors.electricBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'OPUS',
                    style: TextStyle(
                      color: EmberColors.secondaryCyan,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: EmberColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _HomeTrackTile extends StatelessWidget {
  final Song track;
  final int index;
  final List<Song> allTracks;

  const _HomeTrackTile({
    required this.track,
    required this.index,
    required this.allTracks,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = context.select<PlayerProvider, bool>((p) => p.currentSong?.id == track.id);
    final isPlaying = context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final isFav = context.select<PlayerProvider, bool>((p) => p.isFavorite(track.id));
    final player = context.read<PlayerProvider>();
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isCurrent ? accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        dense: true,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: track.artworkUrl,
                width: 44,
                height: 44,
                memCacheWidth: 150,
                memCacheHeight: 150,
                fit: BoxFit.cover,
                errorWidget: (context, error, stackTrace) => Container(
                  width: 44,
                  height: 44,
                  color: EmberColors.surfaceContainerHigh,
                  child: const FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.textMuted),
                ),
              ),
            ),
            if (isCurrent && isPlaying)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: FaIcon(FontAwesomeIcons.volumeHigh, size: 14, color: accent),
                ),
              ),
          ],
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? accent : EmberColors.textPrimary,
            fontSize: 13,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: EmberColors.textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: FaIcon(
                isFav ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                size: 14,
                color: isFav ? accent : EmberColors.textMuted,
              ),
              onPressed: () => player.toggleFavorite(track),
            ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 13, color: EmberColors.textMuted),
              onPressed: () => TrackOptionsSheet.show(context, track),
            ),
          ],
        ),
        onTap: () => player.playCategoryTracks(
          allTracks,
          startIndex: index,
          targetSong: track,
          playingFrom: 'YouTube Music Top Tracks',
        ),
      ),
    );
  }
}
