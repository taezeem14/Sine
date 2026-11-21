import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../constants/app_constants.dart';
import '../widgets/sine_qr_code_sheet.dart';
import '../widgets/aesthetic_playlist_cover.dart';
import 'track_options_sheet.dart';

class PlaylistDetailSheet extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailSheet({super.key, required this.playlist});

  static void show(BuildContext context, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlaylistDetailSheet(playlist: playlist),
    );
  }

  String _formatTotalDuration(Playlist pl) {
    int totalSec = 0;
    for (final s in pl.songs) {
      totalSec += s.duration.inSeconds;
    }
    final mins = totalSec ~/ 60;
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remMins = mins % 60;
      return '${hours}h ${remMins}m';
    }
    return '$mins mins';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    // Surgical selectors: only rebuild when this playlist or active playing track changes
    final currentPl = context.select<PlayerProvider, Playlist>((p) {
      if (playlist.id == 'downloaded_songs') {
        return Playlist(
          id: 'downloaded_songs',
          title: 'Downloaded Songs',
          description: 'Tracks stored locally on your device for offline playback',
          songs: List<Song>.from(p.downloads),
          createdAt: playlist.createdAt,
        );
      } else if (playlist.id == 'liked_songs') {
        return Playlist(
          id: 'liked_songs',
          title: 'Liked Songs',
          description: 'Your favorite tracks',
          songs: List<Song>.from(p.favorites),
          createdAt: playlist.createdAt,
        );
      }
      return p.playlists.firstWhere(
        (pl) => pl.id == playlist.id,
        orElse: () => playlist,
      );
    });
    context.select<PlayerProvider, String?>((p) => p.currentSong?.id);
    context.select<PlayerProvider, bool>((p) => p.isPlaying);
    final isSystemPlaylist = currentPl.id == 'downloaded_songs' || currentPl.id == 'liked_songs';

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: EmberColors.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showAestheticCoverPicker(context, player, currentPl),
                    child: Stack(
                      children: [
                        AestheticPlaylistCover(
                          coverUrl: currentPl.coverUrl,
                          size: 64,
                          borderRadius: 12,
                        ),
                        if (currentPl.id != 'downloaded_songs')
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.palette_rounded, size: 10, color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPl.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${currentPl.songs.length} tracks • ${_formatTotalDuration(currentPl)}',
                          style: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.qrcode, size: 16, color: EmberColors.primaryBlue),
                    tooltip: 'Share Playlist QR Code',
                    onPressed: () => SineQrCodeSheet.showForPlaylist(context, currentPl),
                  ),
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.fileArrowDown, size: 16, color: EmberColors.primaryBlue),
                    tooltip: 'Export Playlist JSON',
                    onPressed: () => _showExportPlaylistDialog(context, player, currentPl),
                  ),
                  if (!isSystemPlaylist)
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16, color: EmberColors.textMuted),
                      tooltip: 'Rename Playlist',
                      onPressed: () {
                      final textController = TextEditingController(text: currentPl.title);
                      showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: EmberColors.surfaceContainerHigh,
                          title: const Text('Rename Playlist', style: TextStyle(color: EmberColors.textPrimary)),
                          content: TextField(
                            controller: textController,
                            autofocus: true,
                            style: const TextStyle(color: EmberColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Playlist Title',
                              hintStyle: TextStyle(color: EmberColors.textMuted),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: EmberColors.primaryAmber),
                              onPressed: () {
                                final newTitle = textController.text.trim();
                                if (newTitle.isNotEmpty) {
                                  player.renamePlaylist(currentPl.id, newTitle);
                                }
                                Navigator.pop(dCtx);
                              },
                              child: const Text('Save', style: TextStyle(color: EmberColors.obsidianBase, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ).then((_) => textController.dispose());
                    },
                  ),
                  if (!isSystemPlaylist)
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16, color: EmberColors.textMuted),
                      tooltip: 'Delete Playlist',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: EmberColors.surfaceContainerHigh,
                            title: const Text('Delete Playlist?', style: TextStyle(color: EmberColors.textPrimary)),
                            content: Text('Are you sure you want to delete "${currentPl.title}"?', style: const TextStyle(color: EmberColors.textSecondary)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: EmberColors.error),
                                onPressed: () {
                                  player.deletePlaylist(currentPl.id);
                                  Navigator.pop(dCtx);
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // Action Buttons (Play All, Shuffle)
            if (currentPl.songs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EmberColors.primaryAmber,
                          foregroundColor: EmberColors.obsidianBase,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          player.playPlaylist(currentPl);
                          Navigator.pop(context);
                        },
                        icon: const FaIcon(FontAwesomeIcons.play, size: 14),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EmberColors.primaryAmber,
                          side: BorderSide(color: EmberColors.primaryAmber),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          final shuffled = List<Song>.from(currentPl.songs)..shuffle();
                          player.playCategoryTracks(shuffled, playingFrom: 'Playlist: ${currentPl.title} (Shuffle)');
                          Navigator.pop(context);
                        },
                        icon: const FaIcon(FontAwesomeIcons.shuffle, size: 14),
                        label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(color: EmberColors.outlineVariant, height: 16),

            // Song list
            Expanded(
              child: currentPl.songs.isEmpty
                  ? SingleChildScrollView(
                      controller: scrollController,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(
                                currentPl.id == 'downloaded_songs' ? FontAwesomeIcons.circleArrowDown : FontAwesomeIcons.music,
                                size: 36,
                                color: EmberColors.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                currentPl.id == 'downloaded_songs' ? 'No downloaded songs yet' : 'No songs in this playlist yet',
                                style: const TextStyle(color: EmberColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentPl.id == 'downloaded_songs'
                                    ? 'Tap the three dots on any song and select "Download Audio" to listen offline.'
                                    : 'Tap the three dots on any song and select "Add to Playlist".',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: currentPl.songs.length,
                      onReorder: (oldIndex, newIndex) {
                        HapticFeedback.mediumImpact();
                        player.reorderPlaylistSongs(currentPl.id, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final song = currentPl.songs[index];
                        final isCurrent = player.currentSong?.id == song.id;

                        return Dismissible(
                          key: ValueKey('pl_song_${song.id}_${song.hashCode}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: EmberColors.error.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'REMOVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(width: 8),
                                FaIcon(FontAwesomeIcons.trashCan, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            final deletedSong = song;
                            final playlistId = currentPl.id;
                            player.removeSongFromPlaylistAt(playlistId, index);
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: EmberColors.surfaceContainerHigh,
                                content: Text(
                                  'Removed "${deletedSong.title}"',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  textColor: EmberColors.primaryAmber,
                                  onPressed: () {
                                    player.addSongToPlaylist(playlistId, deletedSong);
                                  },
                                ),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? EmberColors.primaryAmber.withValues(alpha: 0.12)
                                  : EmberColors.surfaceContainerLow.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: song.artworkUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: song.artworkUrl,
                                        width: 44,
                                        height: 44,
                                        memCacheWidth: 150,
                                        memCacheHeight: 150,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
                                      )
                                    : FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? EmberColors.primaryAmber : EmberColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: EmberColors.textMuted, fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    padding: const EdgeInsets.all(4),
                                    icon: const FaIcon(FontAwesomeIcons.ellipsis, size: 14, color: EmberColors.textMuted),
                                    onPressed: () => TrackOptionsSheet.show(context, song),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        size: 20,
                                        color: EmberColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                player.playPlaylist(currentPl, startIndex: index);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAestheticCoverPicker(BuildContext context, PlayerProvider player, Playlist pl) {
    if (pl.id == 'downloaded_songs') return;
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.charcoalCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text(
                  'Choose Aesthetic Cover',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a glowing generative gradient theme for this playlist',
                  style: TextStyle(color: EmberColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AestheticPlaylistCover.themes.map((theme) {
                    final themeId = 'aesthetic:${theme.id}';
                    final isSelected = pl.coverUrl == themeId;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        player.savePlaylist(pl.copyWith(coverUrl: themeId));
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: AestheticPlaylistCover(
                              coverUrl: themeId,
                              size: 58,
                              borderRadius: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : EmberColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExportPlaylistDialog(BuildContext context, PlayerProvider player, Playlist pl) {
    bool isSaving = false;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: EmberColors.obsidianBase,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              FaIcon(FontAwesomeIcons.fileArrowDown, color: EmberColors.primaryBlue, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Export Playlist JSON',
                  style: TextStyle(color: EmberColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export "${pl.title}" into a portable JSON file. You can share or restore this playlist on any Sine device.',
                style: const TextStyle(color: EmberColors.textSecondary, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EmberColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Title: ${pl.title}', style: const TextStyle(color: EmberColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('• Tracks: ${pl.songs.length}', style: const TextStyle(color: EmberColors.textPrimary, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text('• Duration: ${_formatTotalDuration(pl)}', style: const TextStyle(color: EmberColors.textPrimary, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text('• Format: SINE_PLAYLIST (v${AppConstants.version})', style: TextStyle(color: EmberColors.primaryBlueHi, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: EmberColors.textSecondary,
                side: const BorderSide(color: EmberColors.outlineVariant),
              ),
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Copy JSON', style: TextStyle(fontSize: 12)),
              onPressed: () {
                final jsonStr = player.exportPlaylistJson(pl);
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.of(dCtx).pop();
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: EmberColors.surfaceContainerHigh,
                    content: Text('Playlist "${pl.title}" JSON copied to clipboard!', style: TextStyle(color: EmberColors.primaryBlueHi)),
                  ),
                );
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: EmberColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_alt_rounded, size: 16),
              label: Text(isSaving ? 'Saving...' : 'Save File'),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final file = await player.exportPlaylistToFile(pl);
                      setDialogState(() => isSaving = false);
                      Navigator.of(dCtx).pop();
                      if (file != null) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: EmberColors.surfaceContainerHigh,
                            duration: const Duration(seconds: 4),
                            content: Text('Playlist saved to:\n${file.path}', style: TextStyle(color: EmberColors.primaryBlueHi, fontSize: 12)),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.redAccent,
                            content: Text('Failed to save playlist file.', style: TextStyle(color: Colors.white)),
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
