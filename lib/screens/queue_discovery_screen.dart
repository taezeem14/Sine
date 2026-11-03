import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../services/catalog_service.dart';
import '../theme/ember_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/spectrum_bars.dart';
import 'track_options_sheet.dart';
import 'playlist_detail_sheet.dart';
import 'settings_screen.dart';


class QueueDiscoveryScreen extends StatefulWidget {
  const QueueDiscoveryScreen({super.key});

  @override
  State<QueueDiscoveryScreen> createState() => _QueueDiscoveryScreenState();
}

class _QueueDiscoveryScreenState extends State<QueueDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: EmberColors.obsidianBase,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Brand, Title & Quick Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EmberColors.primaryAmber.withValues(alpha: 0.16),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.fire,
                      color: EmberColors.primaryAmber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SINE',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: EmberColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                      ),
                      Text(
                        'YOUTUBE MUSIC STREAMING',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: EmberColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Import YouTube Link Button
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.link, color: EmberColors.primaryAmber, size: 16),
                    tooltip: 'Import YouTube Link',
                    onPressed: () => _showImportUrlDialog(context, player),
                  ),
                  // Settings & Creator Button
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.gear, color: EmberColors.textSecondary, size: 18),
                    tooltip: 'Settings & Creator',
                    onPressed: () => SettingsScreen.show(context),
                  ),

                ],
              ),
            ),

            // Search Capsule Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: EmberColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 15, color: EmberColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Search YouTube Music or paste link...',
                          hintStyle: TextStyle(color: EmberColors.textMuted, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) => player.search(val),
                      ),
                    ),
                    if (player.isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EmberColors.primaryAmber,
                          ),
                        ),
                      ),
                    if (_searchController.text.isNotEmpty && !player.isSearching)
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.xmark, size: 14, color: EmberColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          player.search('');
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Music Categories Quick Picks Horizontal Bar
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                itemCount: CatalogService.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = CatalogService.categories[i];
                  final isSelected = player.activeCategory == cat.key;
                  return InkWell(
                    onTap: () => player.selectCategory(cat.key),
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? EmberColors.primaryAmber.withValues(alpha: 0.2)
                            : EmberColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isSelected
                              ? EmberColors.primaryAmber
                              : EmberColors.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          FaIcon(
                            cat.icon,
                            size: 12,
                            color: isSelected ? EmberColors.primaryAmber : EmberColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.title,
                            style: TextStyle(
                              color: isSelected ? EmberColors.primaryAmber : EmberColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Sub-tabs (Discover, YouTube Music, Queue, Playlists, Favorites, Downloads, History, Settings)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _TabPill(
                    label: 'Discover',
                    active: player.activeTab == 'discover',
                    onTap: () => player.setTab('discover'),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'YouTube Music',
                    active: player.activeTab == 'youtube',
                    onTap: () {
                      player.setTab('youtube');
                      if (player.youtubeTracks.isEmpty) {
                        player.loadYouTubeTrending();
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'Queue',
                    active: player.activeTab == 'queue',
                    onTap: () => player.setTab('queue'),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'Playlists',
                    active: player.activeTab == 'playlists',
                    onTap: () => player.setTab('playlists'),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'Favorites',
                    active: player.activeTab == 'favorites',
                    onTap: () => player.setTab('favorites'),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'Downloads',
                    active: player.activeTab == 'downloads',
                    onTap: () => player.setTab('downloads'),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'History',
                    active: player.activeTab == 'history',
                    onTap: () => player.setTab('history'),
                  ),
                  const SizedBox(width: 6),
                  _TabPill(
                    label: 'Settings',
                    active: player.activeTab == 'settings',
                    onTap: () => player.setTab('settings'),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: _buildTabContent(context, player),
            ),

            // Docked Frosted Mini Player
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, PlayerProvider player) {
    if (_searchController.text.isNotEmpty) {
      return _buildSearchList(context, player);
    }

    switch (player.activeTab) {
      case 'discover':
        return _buildDiscoverTab(context, player);
      case 'youtube':
        return _buildYouTubeTab(context, player);
      case 'playlists':
        return _buildPlaylistsTab(context, player);
      case 'favorites':
        return _buildSongList(context, player, player.favorites, emptyMsg: 'No favorite tracks pinned yet');
      case 'downloads':
        return _buildDownloadsTab(context, player);
      case 'history':
        return _buildHistoryTab(context, player);
      case 'settings':
        return const SettingsContent();
      case 'queue':
      default:
        return _buildQueueTab(context, player);
    }
  }


  // Dedicated Music Discovery Tab (Trending Hits, Global Top 50, Pop & Dance, etc.)
  Widget _buildDiscoverTab(BuildContext context, PlayerProvider player) {
    final cat = CatalogService.categories.firstWhere(
      (c) => c.key == player.activeCategory,
      orElse: () => CatalogService.categories.first,
    );
    final tracks = player.categoryTracks;

    if (player.isSearching && tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5, color: EmberColors.primaryAmber),
            const SizedBox(height: 14),
            Text('Loading ${cat.title}...', style: const TextStyle(color: EmberColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(cat.icon, size: 36, color: EmberColors.primaryAmber),
            const SizedBox(height: 12),
            Text('No tracks loaded for ${cat.title}', style: const TextStyle(color: EmberColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: EmberColors.primaryAmber),
              onPressed: () => player.selectCategory(cat.key),
              child: const Text('Refresh', style: TextStyle(color: EmberColors.obsidianBase, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Category Header with Play All & Add to Queue
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FaIcon(cat.icon, size: 14, color: EmberColors.primaryAmber),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            cat.title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EmberColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tracks.length} tracks • ${cat.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: EmberColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EmberColors.primaryAmber,
                      foregroundColor: EmberColors.obsidianBase,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                    ),
                    onPressed: () => player.playCategoryTracks(tracks),
                    icon: const FaIcon(FontAwesomeIcons.play, size: 11),
                    label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Add All to Queue',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(6),
                    icon: const FaIcon(FontAwesomeIcons.listCheck, size: 14, color: EmberColors.primaryAmber),
                    onPressed: () {
                      player.addTracksToQueue(tracks);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: EmberColors.surfaceContainerHigh,
                          content: Text('Added ${tracks.length} tracks to queue', style: const TextStyle(color: EmberColors.primaryAmberHi)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final song = tracks[index];
              final isCurrent = player.currentSong?.id == song.id;
              return _buildTrackRow(context, player, song, isCurrent, contextQueue: tracks);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchList(BuildContext context, PlayerProvider player) {
    if (player.isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: EmberColors.primaryAmber),
            SizedBox(height: 14),
            Text('Searching YouTube Music...', style: TextStyle(color: EmberColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (player.searchResults.isEmpty) {
      return Center(
        child: Text('No results for "${_searchController.text}"', style: const TextStyle(color: EmberColors.textMuted, fontSize: 13)),
      );
    }

    return _buildSongList(context, player, player.searchResults, isSearch: true);
  }

  // Interactive Reorderable Queue Tab with Recommendations
  Widget _buildQueueTab(BuildContext context, PlayerProvider player) {
    final queue = player.queue;
    final reco = player.recommendations;

    if (queue.isEmpty) {
      return const Center(
        child: Text('Queue is empty. Select a music category or search songs above.', style: TextStyle(color: EmberColors.textMuted, fontSize: 13)),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NOW PLAYING & QUEUE (${queue.length})',
                  style: const TextStyle(
                    color: EmberColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                if (queue.length > 1)
                  InkWell(
                    onTap: () => player.clearQueue(),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.trashCan, size: 12, color: EmberColors.textMuted),
                          SizedBox(width: 4),
                          Text('Clear', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Reorderable Active Queue with identical horizontal padding to History
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverReorderableList(
            itemCount: queue.length,
            onReorder: (oldIdx, newIdx) => player.reorderQueue(oldIdx, newIdx),
            itemBuilder: (context, index) {
              final song = queue[index];
              final isCurrent = player.currentSong?.id == song.id;

              return ReorderableDelayedDragStartListener(
                key: ValueKey('queue_${song.id}_$index'),
                index: index,
                child: Dismissible(
                  key: ValueKey('dismiss_${song.id}_$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: EmberColors.error.withValues(alpha: 0.8),
                    child: const FaIcon(FontAwesomeIcons.trashCan, color: Colors.white, size: 16),
                  ),
                  onDismissed: (_) => player.removeTrackAt(index),
                  child: _buildTrackRow(context, player, song, isCurrent, isQueue: true),
                ),
              );
            },
          ),
        ),

        // Recommendations Section
        if (reco.isNotEmpty || player.isLoadingRecommendations) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.radio, size: 14, color: EmberColors.primaryAmber),
                      const SizedBox(width: 8),
                      Text(
                        'SINE RADIO & UP NEXT',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: EmberColors.primaryAmber,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                      if (player.isLoadingRecommendations) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: EmberColors.primaryAmber),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 12, color: EmberColors.textMuted),
                        tooltip: 'Refresh recommendations',
                        onPressed: () => player.refreshRecommendations(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 10),
                      Text('Autoplay', style: TextStyle(color: EmberColors.textMuted.withValues(alpha: 0.8), fontSize: 11)),
                      const SizedBox(width: 4),
                      Switch(
                        value: player.isAutoplayEnabled,
                        activeTrackColor: EmberColors.primaryAmber,
                        onChanged: (_) => player.toggleAutoplay(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = reco[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: EmberColors.surfaceContainerLow.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: song.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.artworkUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => const FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
                              )
                            : const FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: EmberColors.primaryAmber),
                            onPressed: () {
                              player.addToQueue(song);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: EmberColors.surfaceContainerHigh, content: Text('Added "${song.title}" to queue', style: const TextStyle(color: EmberColors.primaryAmberHi))),
                              );
                            },
                          ),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 16, color: EmberColors.textMuted),
                            onPressed: () => TrackOptionsSheet.show(context, song),
                          ),
                        ],
                      ),
                      onTap: () => player.playSong(song, playingFrom: 'Recommended Tracks'),
                    ),
                  ),
                );
              },
              childCount: reco.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ],
    );
  }

  // Playlists Tab
  Widget _buildPlaylistsTab(BuildContext context, PlayerProvider player) {
    final playlists = player.playlists;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR PLAYLISTS (${playlists.length})',
                style: const TextStyle(color: EmberColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EmberColors.primaryAmber.withValues(alpha: 0.18),
                      foregroundColor: EmberColors.primaryAmber,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                    ),
                    onPressed: () {
                      final ctrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: EmberColors.surfaceContainerHigh,
                          title: const Text('Create Playlist', style: TextStyle(color: EmberColors.textPrimary)),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            style: const TextStyle(color: EmberColors.textPrimary),
                            decoration: const InputDecoration(hintText: 'Playlist name...'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: EmberColors.primaryAmber),
                              onPressed: () {
                                if (ctrl.text.trim().isNotEmpty) {
                                  player.createPlaylist(ctrl.text.trim());
                                  Navigator.pop(dCtx);
                                }
                              },
                              child: const Text('Create', style: TextStyle(color: EmberColors.obsidianBase, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ).then((_) => ctrl.dispose());
                    },
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 11),
                    label: const Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: playlists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.folderPlus, size: 40, color: EmberColors.textMuted),
                        const SizedBox(height: 12),
                        const Text('No playlists saved yet', style: TextStyle(color: EmberColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                          'Create and organize custom playlists saved locally to your device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: EmberColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EmberColors.primaryAmber,
                            foregroundColor: EmberColors.obsidianBase,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                          ),
                          onPressed: () => player.createPlaylist('My Top Mix'),
                          icon: const FaIcon(FontAwesomeIcons.plus, size: 11),
                          label: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: playlists.length,
                  itemBuilder: (context, i) {
                    final pl = playlists[i];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: EmberColors.surfaceContainerLow.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: pl.coverUrl != null && pl.coverUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: pl.coverUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const FaIcon(FontAwesomeIcons.music, size: 20, color: EmberColors.primaryAmber),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: EmberColors.surfaceContainerHigh,
                                  child: const Center(child: FaIcon(FontAwesomeIcons.listCheck, size: 20, color: EmberColors.primaryAmber)),
                                ),
                        ),
                        title: Text(pl.title, style: const TextStyle(color: EmberColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${pl.songs.length} tracks', style: const TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.play, size: 14, color: EmberColors.primaryAmber),
                              onPressed: () => player.playPlaylist(pl),
                            ),
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14, color: EmberColors.textMuted),
                              onPressed: () => player.deletePlaylist(pl.id),
                            ),
                          ],
                        ),
                        onTap: () => PlaylistDetailSheet.show(context, pl),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Downloads Tab
  Widget _buildDownloadsTab(BuildContext context, PlayerProvider player) {
    final downloads = player.downloads;

    if (downloads.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.download, size: 40, color: EmberColors.textMuted),
            SizedBox(height: 12),
            Text('No downloaded tracks yet', style: TextStyle(color: EmberColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Tap the three dots on any song to download MP3/MP4', style: TextStyle(color: EmberColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OFFLINE TRACKS (${downloads.length})', style: const TextStyle(color: EmberColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Text('100% Offline Ready', style: TextStyle(color: EmberColors.primaryAmber, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: downloads.length,
            itemBuilder: (context, i) {
              final song = downloads[i];
              final isCurrent = player.currentSong?.id == song.id;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: isCurrent ? EmberColors.primaryAmber.withValues(alpha: 0.12) : EmberColors.surfaceContainerLow.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: song.artworkUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
                          )
                        : const FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
                  ),
                  title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isCurrent ? EmberColors.primaryAmber : EmberColors.textPrimary, fontWeight: FontWeight.w500)),
                  subtitle: Text('${song.artist} • Offline MP3', style: const TextStyle(color: EmberColors.textMuted, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14, color: EmberColors.textMuted),
                        onPressed: () => player.deleteDownload(song.id),
                      ),
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 16, color: EmberColors.textMuted),
                        onPressed: () => TrackOptionsSheet.show(context, song),
                      ),
                    ],
                  ),
                  onTap: () => player.playSong(song, playingFrom: 'Category: ${player.activeCategory.replaceAll('_', ' ')}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Dedicated Playback History Tab with Clear Action
  Widget _buildHistoryTab(BuildContext context, PlayerProvider player) {
    final history = player.history;

    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.clockRotateLeft, size: 38, color: EmberColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No playback history yet',
              style: TextStyle(color: EmberColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Tracks you play will show up here.',
              style: TextStyle(color: EmberColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PLAYBACK HISTORY (${history.length})',
                style: const TextStyle(
                  color: EmberColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              InkWell(
                onTap: () => _showClearHistoryDialog(context, player),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.trashCan, size: 12, color: EmberColors.textMuted),
                      SizedBox(width: 4),
                      Text('Clear', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final song = history[index];
              final isCurrent = player.currentSong?.id == song.id;
              return _buildTrackRow(context, player, song, isCurrent, contextQueue: history);
            },
          ),
        ),
      ],
    );
  }

  void _showClearHistoryDialog(BuildContext context, PlayerProvider player) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: EmberColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            FaIcon(FontAwesomeIcons.clockRotateLeft, size: 16, color: EmberColors.primaryAmber),
            SizedBox(width: 10),
            Text('Clear History?', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear your listening history? This cannot be undone.',
          style: TextStyle(color: EmberColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EmberColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dCtx);
              await player.clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: EmberColors.surfaceContainerHigh,
                    content: Text('Playback history cleared', style: TextStyle(color: EmberColors.primaryAmberHi)),
                  ),
                );
              }
            },
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // YouTube Music Explorer (Spotube reference)
  Widget _buildYouTubeTab(BuildContext context, PlayerProvider player) {
    final tracks = player.youtubeTracks;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(FontAwesomeIcons.youtube, size: 14, color: Color(0xFFFF0000)),
                      SizedBox(width: 8),
                      Text(
                        'YOUTUBE MUSIC EXPLORER',
                        style: TextStyle(
                          color: EmberColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text('Trending hits & official artist uploads', style: TextStyle(color: EmberColors.textMuted, fontSize: 11)),
                ],
              ),
              if (tracks.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  ),
                  onPressed: () => player.playPlaylist(
                    Playlist(
                      id: 'yt_trending',
                      title: 'YouTube Trending',
                      description: 'Trending YouTube Music Tracks',
                      songs: tracks,
                      createdAt: DateTime.now(),
                    ),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.play, size: 11),
                  label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
            ],
          ),
        ),
        Expanded(
          child: player.isLoadingYouTube && tracks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF0000)),
                      SizedBox(height: 14),
                      Text('Connecting to YouTube Music...', style: TextStyle(color: EmberColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : tracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.youtube, size: 36, color: Color(0xFFFF0000)),
                          const SizedBox(height: 12),
                          const Text('No tracks loaded from YouTube', style: TextStyle(color: EmberColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0000)),
                            onPressed: () => player.loadYouTubeTrending(),
                            child: const Text('Load Trending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final song = tracks[index];
                        final isCurrent = player.currentSong?.id == song.id;
                        return _buildTrackRow(context, player, song, isCurrent, contextQueue: tracks);
                      },
                    ),
        ),
      ],
    );
  }

  void _showImportUrlDialog(BuildContext context, PlayerProvider player) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: EmberColors.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    FaIcon(FontAwesomeIcons.link, size: 16, color: EmberColors.primaryAmber),
                    SizedBox(width: 10),
                    Text('Import from YouTube', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paste any YouTube video or playlist link to stream instantly.',
                  style: TextStyle(color: EmberColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=... or playlist link',
                    hintStyle: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: EmberColors.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmberColors.primaryAmber,
                        foregroundColor: EmberColors.obsidianBase,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final text = ctrl.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: EmberColors.surfaceContainerHigh,
                              content: Text('Importing media...', style: TextStyle(color: EmberColors.primaryAmber)),
                            ),
                          );
                          final msg = await player.importMediaUrl(text);
                          if (context.mounted && msg != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: EmberColors.surfaceContainerHigh,
                                content: Text(msg, style: const TextStyle(color: EmberColors.primaryAmberHi)),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Import & Play', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) => ctrl.dispose());
  }

  // Generic Song List (Favorites, History, Search)
  Widget _buildSongList(BuildContext context, PlayerProvider player, List<Song> songs, {String? emptyMsg, bool isSearch = false}) {
    if (songs.isEmpty) {
      return Center(
        child: Text(emptyMsg ?? 'No tracks found', style: const TextStyle(color: EmberColors.textMuted, fontSize: 13)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isCurrent = player.currentSong?.id == song.id;
        return _buildTrackRow(context, player, song, isCurrent, contextQueue: isSearch ? songs : null);
      },
    );
  }

  Widget _buildTrackRow(BuildContext context, PlayerProvider player, Song song, bool isCurrent, {bool isQueue = false, List<Song>? contextQueue}) {
    final artSize = isQueue ? 38.0 : 44.0;

    return Container(
      margin: EdgeInsets.symmetric(vertical: isQueue ? 2 : 3),
      decoration: BoxDecoration(
        color: isCurrent
            ? EmberColors.primaryAmber.withValues(alpha: 0.12)
            : EmberColors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? EmberColors.primaryAmber.withValues(alpha: 0.6) : Colors.transparent,
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: isQueue ? const VisualDensity(horizontal: -1, vertical: -2) : VisualDensity.compact,
        contentPadding: EdgeInsets.symmetric(horizontal: isQueue ? 10 : 12, vertical: isQueue ? 0 : 2),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song.artworkUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: song.artworkUrl,
                      width: artSize,
                      height: artSize,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => FaIcon(FontAwesomeIcons.music, size: artSize * 0.4, color: EmberColors.primaryAmber),
                    )
                  : FaIcon(FontAwesomeIcons.music, size: artSize * 0.4, color: EmberColors.primaryAmber),
            ),
            if (isCurrent)
              Container(
                width: artSize,
                height: artSize,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: SpectrumBars(
                    isPlaying: player.isPlaying,
                    height: 14,
                    barCount: 4,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? EmberColors.primaryAmber : EmberColors.textPrimary,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            fontSize: isQueue ? 13.5 : 14,
          ),
        ),
        subtitle: Row(
          children: [
            const FaIcon(FontAwesomeIcons.youtube, size: 10, color: Color(0xFFFF0000)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: EmberColors.textMuted, fontSize: 11.5),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isQueue) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: FaIcon(FontAwesomeIcons.bars, size: 12, color: EmberColors.textMuted),
              ),
            ] else ...[
              IconButton(
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
                icon: FaIcon(
                  player.isFavorite(song.id) ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                  size: 14,
                  color: player.isFavorite(song.id) ? EmberColors.primaryAmber : EmberColors.textMuted,
                ),
                onPressed: () => player.toggleFavorite(song),
              ),
            ],
            IconButton(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(4),
              icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 14, color: EmberColors.textMuted),
              onPressed: () => TrackOptionsSheet.show(context, song),
            ),
          ],
        ),
        onTap: () {
          player.playSong(song, contextQueue: contextQueue, playingFrom: 'Active Queue');
        },
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? EmberColors.primaryAmber : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? EmberColors.obsidianBase : EmberColors.textMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
