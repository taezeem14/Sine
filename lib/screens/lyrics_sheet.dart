import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/synchronized_lyrics_view.dart';

class LyricsSheet extends StatelessWidget {
  final Song song;

  const LyricsSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LyricsSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSong = context.watch<PlayerProvider>().currentSong ?? song;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: EmberColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: EmberColors.outlineVariant, width: 1)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: EmberColors.textMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lyrics',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: EmberColors.primaryAmber,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${activeSong.title} • ${activeSong.artist}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: EmberColors.textMuted,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: EmberColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: EmberColors.outlineVariant, height: 1),
          const Expanded(
            child: SynchronizedLyricsView(),
          ),
        ],
      ),
    );
  }
}
