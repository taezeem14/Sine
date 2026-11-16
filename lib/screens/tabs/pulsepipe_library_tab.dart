import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/song.dart';
import '../../models/playlist.dart';
import '../../models/downloaded_video.dart';
import '../../providers/player_provider.dart';
import '../../theme/ember_theme.dart';
import '../playlist_detail_sheet.dart';
import '../track_options_sheet.dart';
import '../settings_screen.dart';
import '../../widgets/sine_qr_code_sheet.dart';

typedef SineLibraryTab = PulsePipeLibraryTab;

class PulsePipeLibraryTab extends StatefulWidget {
  const PulsePipeLibraryTab({super.key});

  @override
  State<PulsePipeLibraryTab> createState() => _PulsePipeLibraryTabState();
}

class _PulsePipeLibraryTabState extends State<PulsePipeLibraryTab> {
  String _selectedFilter = 'All'; // 'All', 'Playlists', 'Liked Songs', 'Downloads', 'History'
  String _downloadSubTab = 'Songs'; // 'Songs' or 'Videos'

  final List<String> _filters = const [
    'All',
    'Playlists',
    'Liked Songs',
    'Downloads',
    'History',
  ];

  void _showCreatePlaylistDialog(BuildContext context, PlayerProvider player) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmberColors.charcoalCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create playlist',
          style: TextStyle(color: EmberColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: EmberColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: EmberColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: EmberColors.electricBlue),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: EmberColors.electricBlueHi, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EmberColors.electricBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                player.createPlaylist(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showImportUrlDialog(BuildContext context, PlayerProvider player) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmberColors.charcoalCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            FaIcon(FontAwesomeIcons.link, size: 18, color: EmberColors.electricBlue),
            SizedBox(width: 10),
            Text('Import Link', style: TextStyle(color: EmberColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste any YouTube track or playlist link:',
              style: TextStyle(color: EmberColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: EmberColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://www.youtube.com/watch?v=... or playlist URL',
                hintStyle: TextStyle(color: EmberColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: EmberColors.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EmberColors.electricBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Importing stream metadata...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                final res = await player.importMediaUrl(url);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res ?? 'Import complete')),
                  );
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showAddMenu(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.charcoalCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: EmberColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: FaIcon(FontAwesomeIcons.circlePlus, color: EmberColors.electricBlue),
              title: Text('Create Playlist', style: TextStyle(color: EmberColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _showCreatePlaylistDialog(context, player);
              },
            ),
            ListTile(
              leading: FaIcon(FontAwesomeIcons.link, color: EmberColors.electricBlue),
              title: Text('Import YouTube Link', style: TextStyle(color: EmberColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _showImportUrlDialog(context, player);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openLikedSongs(BuildContext context, PlayerProvider player) {
    final pl = Playlist(
      id: 'liked_songs',
      title: 'Liked Songs',
      description: 'Your favorite tracks',
      songs: player.favorites,
      createdAt: DateTime.now(),
    );
    PlaylistDetailSheet.show(context, pl);
  }

  void _openDownloads(BuildContext context, PlayerProvider player) {
    final pl = Playlist(
      id: 'downloaded_songs',
      title: 'Downloaded Songs',
      description: 'Tracks stored locally on your device for offline playback',
      songs: player.downloads,
      createdAt: DateTime.now(),
    );
    PlaylistDetailSheet.show(context, pl);
  }

  @override
  Widget build(BuildContext context) {
    context.select<PlayerProvider, int>((p) => p.favorites.length);
    context.select<PlayerProvider, int>((p) => p.downloads.length);
    context.select<PlayerProvider, int>((p) => p.downloadedVideos.length);
    context.select<PlayerProvider, int>((p) => p.playlists.length);
    context.select<PlayerProvider, int>((p) => p.history.length);
    context.select<PlayerProvider, String?>((p) => p.currentSong?.id);
    final player = context.read<PlayerProvider>();

    return Scaffold(
      backgroundColor: EmberColors.obsidianBase,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Header: "Your Library" + Add Button + Settings
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    const Text(
                      'Your Library',
                      style: TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.plus, size: 20, color: EmberColors.textPrimary),
                      tooltip: 'Add Playlist or Import Link',
                      onPressed: () => _showAddMenu(context, player),
                    ),
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.gear, size: 19, color: EmberColors.textSecondary),
                      tooltip: 'Settings & Info',
                      onPressed: () => SettingsScreen.show(context),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Filter Pills
            SliverToBoxAdapter(
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? EmberColors.electricBlue : EmberColors.charcoalCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? EmberColors.electricBlue
                                : EmberColors.glassBorder.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : EmberColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // 3. Pinned "Liked Songs" Row (shown when filter is All or Liked Songs)
            if (_selectedFilter == 'All' || _selectedFilter == 'Liked Songs')
              SliverToBoxAdapter(
                child: _LibraryRowItem(
                  iconGradient: const [Color(0xFF1565C0), Color(0xFF2979FF)],
                  icon: FontAwesomeIcons.solidHeart,
                  title: 'Liked Songs',
                  subtitle: 'Playlist • ${player.favorites.length} songs',
                  isPinned: true,
                  onTap: () => _openLikedSongs(context, player),
                ),
              ),

            // 4. "Downloaded Songs" Row (shown when filter is All)
            if (_selectedFilter == 'All')
              SliverToBoxAdapter(
                child: _LibraryRowItem(
                  iconGradient: const [Color(0xFF00C853), Color(0xFF69F0AE)],
                  icon: FontAwesomeIcons.circleArrowDown,
                  title: 'Downloaded Songs',
                  subtitle: 'Offline Storage • ${player.downloads.length} songs',
                  isPinned: false,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Downloads';
                      _downloadSubTab = 'Songs';
                    });
                  },
                ),
              ),

            // 4B. "Downloaded Videos" Row (shown when filter is All)
            if (_selectedFilter == 'All')
              SliverToBoxAdapter(
                child: _LibraryRowItem(
                  iconGradient: const [Color(0xFF7C4DFF), Color(0xFF00D2FF)],
                  icon: FontAwesomeIcons.video,
                  title: 'Downloaded Videos',
                  subtitle: 'MP4 Gallery • ${player.downloadedVideos.length} videos',
                  isPinned: false,
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'Downloads';
                      _downloadSubTab = 'Videos';
                    });
                  },
                ),
              ),

            // 4C. Downloads Section (Audio & Video Sub-Tabs)
            if (_selectedFilter == 'Downloads') ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: EmberColors.charcoalCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: EmberColors.glassBorder.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _downloadSubTab = 'Songs');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _downloadSubTab == 'Songs'
                                    ? EmberColors.primaryBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.music_note_rounded,
                                    size: 15,
                                    color: _downloadSubTab == 'Songs'
                                        ? Colors.white
                                        : EmberColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Audio (${player.downloads.length})',
                                    style: TextStyle(
                                      color: _downloadSubTab == 'Songs'
                                          ? Colors.white
                                          : EmberColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _downloadSubTab = 'Videos');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _downloadSubTab == 'Videos'
                                    ? EmberColors.primaryBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    size: 15,
                                    color: _downloadSubTab == 'Videos'
                                        ? Colors.white
                                        : EmberColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Videos (${player.downloadedVideos.length})',
                                    style: TextStyle(
                                      color: _downloadSubTab == 'Videos'
                                          ? Colors.white
                                          : EmberColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_downloadSubTab == 'Songs') ...[
                if (player.downloads.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EmberColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: () {
                              final pl = Playlist(
                                id: 'downloaded_songs',
                                title: 'Downloaded Songs',
                                songs: player.downloads,
                                createdAt: DateTime.now(),
                              );
                              player.playPlaylist(pl, startIndex: 0);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EmberColors.textPrimary,
                              side: BorderSide(color: EmberColors.outlineVariant.withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            onPressed: () {
                              final pl = Playlist(
                                id: 'downloaded_songs',
                                title: 'Downloaded Songs',
                                songs: player.downloads,
                                createdAt: DateTime.now(),
                              );
                              player.playPlaylist(pl, startIndex: 0, shuffle: true);
                            },
                            icon: const FaIcon(FontAwesomeIcons.shuffle, size: 13),
                            label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = player.downloads[index];
                        final isCurrent = player.currentSong?.id == song.id;
                        return Dismissible(
                          key: ValueKey('dl_song_${song.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: const Color(0xFFD32F2F),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) async {
                            HapticFeedback.mediumImpact();
                            final deletedSong = song;
                            await player.deleteDownload(song.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Removed "${deletedSong.title}" from downloads'),
                                backgroundColor: EmberColors.surfaceContainerHigh,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  textColor: EmberColors.primaryBlue,
                                  onPressed: () {
                                    player.restoreDownloadedSong(deletedSong);
                                  },
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.artworkUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: song.artworkUrl,
                                      width: 48,
                                      height: 48,
                                      memCacheWidth: 150,
                                      memCacheHeight: 150,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        width: 48,
                                        height: 48,
                                        color: EmberColors.surfaceContainerHigh,
                                        child: Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: EmberColors.surfaceContainerHigh,
                                      child: Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
                                    ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? EmberColors.primaryBlue : EmberColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${song.artist} • Offline Audio',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: EmberColors.textMuted, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14, color: EmberColors.textMuted),
                              onPressed: () => TrackOptionsSheet.show(context, song),
                            ),
                            onTap: () {
                              final pl = Playlist(
                                id: 'downloaded_songs',
                                title: 'Downloaded Songs',
                                songs: player.downloads,
                                createdAt: DateTime.now(),
                              );
                              player.playPlaylist(pl, startIndex: index);
                            },
                          ),
                        );
                      },
                      childCount: player.downloads.length,
                    ),
                  ),
                ] else
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(FontAwesomeIcons.circleArrowDown, size: 42, color: EmberColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No downloaded songs yet',
                              style: TextStyle(color: EmberColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tap the three dots on any song and select "Download Audio" to listen offline without internet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: EmberColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                // Videos Sub-Tab
                if (player.downloadedVideos.isNotEmpty) ...[
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = player.downloadedVideos[index];
                        return Dismissible(
                          key: ValueKey('dl_vid_${video.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: const Color(0xFFD32F2F),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) async {
                            HapticFeedback.mediumImpact();
                            final deletedVideo = video;
                            await player.deleteDownloadedVideo(video.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted video "${deletedVideo.title}"'),
                                backgroundColor: EmberColors.surfaceContainerHigh,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: video.artworkUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: video.artworkUrl,
                                          width: 54,
                                          height: 54,
                                          memCacheWidth: 150,
                                          memCacheHeight: 150,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(
                                            width: 54,
                                            height: 54,
                                            color: EmberColors.surfaceContainerHigh,
                                            child: Icon(Icons.videocam_rounded, color: EmberColors.primaryBlue),
                                          ),
                                        )
                                      : Container(
                                          width: 54,
                                          height: 54,
                                          color: EmberColors.surfaceContainerHigh,
                                          child: Icon(Icons.videocam_rounded, color: EmberColors.primaryBlue),
                                        ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 15),
                                ),
                              ],
                            ),
                            title: Text(
                              video.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: EmberColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${video.artist} • ${video.sizeFormatted} • MP4',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: EmberColors.textMuted),
                              tooltip: 'Open in Video Player',
                              onPressed: () => player.openDownloadedVideo(video.filePath),
                            ),
                            onTap: () async {
                              final ok = await player.openDownloadedVideo(video.filePath);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open video file in external player'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                      childCount: player.downloadedVideos.length,
                    ),
                  ),
                ] else
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(FontAwesomeIcons.video, size: 42, color: EmberColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'No downloaded videos yet',
                              style: TextStyle(color: EmberColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tap the three dots on any song and select "Download Video" to save MP4 videos for offline playback in your gallery.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: EmberColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],

            // 5. Custom Playlists (shown when filter is All or Playlists)
            if (_selectedFilter == 'All' || _selectedFilter == 'Playlists') ...[
              if (player.playlists.isEmpty && _selectedFilter == 'Playlists')
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.music, size: 42, color: EmberColors.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'No playlists yet',
                          style: TextStyle(color: EmberColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap + to create your first playlist.',
                          style: TextStyle(color: EmberColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EmberColors.electricBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () => _showCreatePlaylistDialog(context, player),
                          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                          label: const Text('Create Playlist'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (player.playlists.isNotEmpty && _selectedFilter == 'All')
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Text(
                        'Playlists',
                        style: TextStyle(
                          color: EmberColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pl = player.playlists[index];
                      return Dismissible(
                        key: ValueKey('playlist_${pl.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: const Color(0xFFD32F2F),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 6),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.mediumImpact();
                          final deletedPl = pl;
                          player.deletePlaylist(pl.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted playlist "${deletedPl.title}"'),
                              backgroundColor: EmberColors.surfaceContainerHigh,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        child: _PlaylistRowItem(
                          playlist: pl,
                          onTap: () => PlaylistDetailSheet.show(context, pl),
                          onOptions: () {
                            // Options to share, delete or manage
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: EmberColors.charcoalCard,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: FaIcon(FontAwesomeIcons.qrcode, color: EmberColors.primaryBlue),
                                      title: Text('Share Playlist QR Code', style: TextStyle(color: EmberColors.textPrimary)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        SineQrCodeSheet.showForPlaylist(context, pl);
                                      },
                                    ),
                                    ListTile(
                                      leading: const FaIcon(FontAwesomeIcons.trashCan, color: Colors.redAccent),
                                      title: const Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        player.deletePlaylist(pl.id);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: player.playlists.length,
                  ),
                ),
              ],
            ],

            // 6. History Section (shown when filter is All or History)
            if (_selectedFilter == 'All' || _selectedFilter == 'History') ...[
              if (player.history.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recently Played',
                          style: TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Clear option in History as requested by the user
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: EmberColors.textMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: EmberColors.charcoalCard,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text('Clear History', style: TextStyle(color: EmberColors.textPrimary)),
                                content: const Text(
                                  'Are you sure you want to clear your listening history?',
                                  style: TextStyle(color: EmberColors.textSecondary),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      player.clearHistory();
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const FaIcon(FontAwesomeIcons.trashCan, size: 12),
                          label: const Text('Clear', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = player.history[index];
                        final isCurrent = player.currentSong?.id == song.id;

                        // Width of song in history is identical to queue and search
                        return InkWell(
                          onTap: () {
                            player.playCategoryTracks(List<Song>.from(player.history), startIndex: index, targetSong: song, playingFrom: 'Listening History');
                          },
                          splashColor: EmberColors.electricBlue.withValues(alpha: 0.15),
                          highlightColor: EmberColors.charcoalCard,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: song.artworkUrl,
                                    width: 48,
                                    height: 48,
                                    memCacheWidth: 150,
                                    memCacheHeight: 150,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(
                                      width: 48,
                                      height: 48,
                                      color: EmberColors.charcoalCard,
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      width: 48,
                                      height: 48,
                                      color: EmberColors.charcoalCard,
                                      child: const Center(
                                        child: FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.textMuted),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent ? EmberColors.electricBlue : EmberColors.textPrimary,
                                          fontSize: 14.5,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        song.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: EmberColors.textSecondary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14, color: EmberColors.textMuted),
                                  onPressed: () => TrackOptionsSheet.show(context, song),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: player.history.length,
                    ),
                  ),
                ),
              ] else if (_selectedFilter == 'History')
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.clockRotateLeft, size: 40, color: EmberColors.textMuted),
                        SizedBox(height: 12),
                        Text('No history yet', style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('Songs you play will appear here.', style: TextStyle(color: EmberColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 170)),
          ],
        ),
      ),
    );
  }
}

class _LibraryRowItem extends StatelessWidget {
  final List<Color> iconGradient;
  final FaIconData icon;
  final String title;
  final String subtitle;
  final bool isPinned;
  final VoidCallback onTap;

  const _LibraryRowItem({
    required this.iconGradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPinned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: EmberColors.electricBlue.withValues(alpha: 0.15),
      highlightColor: EmberColors.charcoalCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: iconGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: FaIcon(icon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: EmberColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isPinned) ...[
                        FaIcon(FontAwesomeIcons.thumbtack, size: 10, color: EmberColors.electricBlue),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: EmberColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EmberColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _PlaylistRowItem extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _PlaylistRowItem({
    required this.playlist,
    required this.onTap,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: EmberColors.electricBlue.withValues(alpha: 0.15),
      highlightColor: EmberColors.charcoalCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: playlist.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: playlist.coverUrl!,
                      width: 54,
                      height: 54,
                      memCacheWidth: 150,
                      memCacheHeight: 150,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 54,
                        height: 54,
                        color: EmberColors.charcoalCard,
                        child: const Center(
                          child: FaIcon(FontAwesomeIcons.music, size: 18, color: EmberColors.textMuted),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 54,
                        height: 54,
                        color: EmberColors.charcoalCard,
                        child: const Center(
                          child: FaIcon(FontAwesomeIcons.music, size: 18, color: EmberColors.textMuted),
                        ),
                      ),
                    )
                  : Container(
                      width: 54,
                      height: 54,
                      color: EmberColors.charcoalCard,
                      child: Center(
                        child: FaIcon(FontAwesomeIcons.music, size: 20, color: EmberColors.electricBlue),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: EmberColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Playlist • ${playlist.songs.length} songs',
                    style: const TextStyle(
                      color: EmberColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14, color: EmberColors.textMuted),
              onPressed: onOptions,
            ),
          ],
        ),
      ),
    );
  }
}
