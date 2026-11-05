import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/sine_qr_code_sheet.dart';
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
    final player = context.watch<PlayerProvider>();
    // Look up latest state of this playlist
    final Playlist currentPl;
    if (playlist.id == 'downloaded_songs') {
      currentPl = Playlist(
        id: 'downloaded_songs',
        title: 'Downloaded Songs',
        description: 'Tracks stored locally on your device for offline playback',
        songs: player.downloads,
        createdAt: playlist.createdAt,
      );
    } else {
      currentPl = player.playlists.firstWhere(
        (p) => p.id == playlist.id,
        orElse: () => playlist,
      );
    }

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: currentPl.coverUrl != null && currentPl.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: currentPl.coverUrl!,
                            width: 64,
                            height: 64,
                            memCacheWidth: 150,
                            memCacheHeight: 150,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              width: 64,
                              height: 64,
                              color: EmberColors.surfaceContainerHigh,
                              child: const Center(child: FaIcon(FontAwesomeIcons.music, size: 24, color: EmberColors.primaryAmber)),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: EmberColors.surfaceContainerHigh,
                            child: const Center(child: FaIcon(FontAwesomeIcons.listCheck, size: 24, color: EmberColors.primaryAmber)),
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
                    icon: const FaIcon(FontAwesomeIcons.qrcode, size: 16, color: EmberColors.primaryBlue),
                    tooltip: 'Share Playlist QR Code',
                    onPressed: () => SineQrCodeSheet.showForPlaylist(context, currentPl),
                  ),
                  if (currentPl.id != 'downloaded_songs')
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
                      );
                    },
                  ),
                  if (currentPl.id != 'downloaded_songs')
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
                          side: const BorderSide(color: EmberColors.primaryAmber),
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
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      itemCount: currentPl.songs.length,
                      itemBuilder: (context, index) {
                        final song = currentPl.songs[index];
                        final isCurrent = player.currentSong?.id == song.id;

                        return Dismissible(
                          key: ValueKey('pl_song_${song.id}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: EmberColors.error.withValues(alpha: 0.8),
                            child: const FaIcon(FontAwesomeIcons.trashCan, color: Colors.white, size: 16),
                          ),
                          onDismissed: (_) {
                            player.removeSongFromPlaylistAt(currentPl.id, index);
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
                                        errorWidget: (_, _, _) => const FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
                                      )
                                    : const FaIcon(FontAwesomeIcons.music, size: 16, color: EmberColors.primaryAmber),
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
}
