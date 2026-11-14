import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';
import '../widgets/spectrum_bars.dart';
import 'track_options_sheet.dart';

typedef SineQueueScreen = QueueDiscoveryScreen;

class QueueDiscoveryScreen extends StatefulWidget {
  const QueueDiscoveryScreen({super.key});

  @override
  State<QueueDiscoveryScreen> createState() => _QueueDiscoveryScreenState();
}

class _QueueDiscoveryScreenState extends State<QueueDiscoveryScreen> {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSong = player.currentSong;
    final queue = player.queue;
    final currentIndex = player.currentIndex;
    final upNext = currentIndex >= 0 && currentIndex < queue.length - 1
        ? queue.sublist(currentIndex + 1)
        : <Song>[];
    final recommendations = player.recommendations;

    return Scaffold(
      backgroundColor: EmberColors.obsidianBase,
      appBar: AppBar(
        backgroundColor: EmberColors.obsidianBase,
        elevation: 0,
        leading: IconButton(
          icon: FaIcon(FontAwesomeIcons.chevronDown, size: 18, color: EmberColors.textPrimary),
          tooltip: 'Close Queue',
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Queue',
          style: TextStyle(
            color: EmberColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (upNext.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                player.clearQueue();
              },
              icon: FaIcon(FontAwesomeIcons.trashCan, size: 12, color: EmberColors.textMuted),
              label: const Text(
                'Clear',
                style: TextStyle(
                  color: EmberColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ==========================================
          // 1. NOW PLAYING SPOTLIGHT
          // ==========================================
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'NOW PLAYING',
                style: TextStyle(
                  color: EmberColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          if (currentSong != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: EmberColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: EmberColors.primaryBlue.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Album Art with Playing Overlay
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CachedNetworkImage(
                                imageUrl: currentSong.artworkUrl,
                                width: 52,
                                height: 52,
                                memCacheWidth: 150,
                                memCacheHeight: 150,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(
                                  width: 52,
                                  height: 52,
                                  color: EmberColors.surfaceContainerHigh,
                                  child: Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
                                ),
                              ),
                              if (player.isPlaying)
                                Container(
                                  width: 52,
                                  height: 52,
                                  color: Colors.black.withValues(alpha: 0.35),
                                  child: const Center(
                                    child: RepaintBoundary(
                                      child: SpectrumBars(isPlaying: true, height: 16),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Track Title & Artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentSong.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: EmberColors.primaryBlueHi,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: EmberColors.primaryBlue.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Opus HQ',
                                      style: TextStyle(
                                        color: EmberColors.primaryBlue,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      currentSong.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: EmberColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Favorite Heart Button
                        IconButton(
                          icon: FaIcon(
                            player.isFavorite(currentSong.id)
                                ? FontAwesomeIcons.solidHeart
                                : FontAwesomeIcons.heart,
                            size: 18,
                            color: player.isFavorite(currentSong.id)
                                ? EmberColors.primaryBlue
                                : EmberColors.textMuted,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            player.toggleFavorite(currentSong);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No track currently playing',
                  style: TextStyle(color: EmberColors.textMuted, fontSize: 13),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ==========================================
          // 2. NEXT IN QUEUE (REORDERABLE & DISMISSIBLE)
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT IN QUEUE',
                        style: TextStyle(
                          color: EmberColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (player.playingFrom.isNotEmpty)
                        Text(
                          'From: ${player.playingFrom}',
                          style: const TextStyle(
                            color: EmberColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${upNext.length} upcoming',
                    style: const TextStyle(
                      color: EmberColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (upNext.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(
                  child: Text(
                    'Queue is empty • Next tracks will play via Smart Autoplay',
                    style: TextStyle(color: EmberColors.textMuted, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              sliver: SliverReorderableList(
                itemCount: upNext.length,
                onReorder: (oldIdx, newIdx) {
                  HapticFeedback.lightImpact();
                  final actualOld = currentIndex + 1 + oldIdx;
                  final actualNew = currentIndex + 1 + newIdx;
                  player.reorderQueue(actualOld, actualNew);
                },
                itemBuilder: (context, index) {
                  final song = upNext[index];
                  final globalIdx = currentIndex + 1 + index;

                  return ReorderableDelayedDragStartListener(
                    key: ValueKey('queue_${song.id}_$globalIdx'),
                    index: index,
                    child: Dismissible(
                      key: ValueKey('dismiss_${song.id}_$globalIdx'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: EmberColors.error.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Remove',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            SizedBox(width: 8),
                            FaIcon(FontAwesomeIcons.trashCan, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                      onDismissed: (_) {
                        HapticFeedback.mediumImpact();
                        final targetIdx = player.queue.indexWhere((s) => s.id == song.id);
                        if (targetIdx != -1) {
                          player.removeTrackAt(targetIdx);
                        } else if (globalIdx < player.queue.length) {
                          player.removeTrackAt(globalIdx);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: EmberColors.surfaceContainerHigh,
                            duration: const Duration(seconds: 2),
                            content: Text(
                              'Removed "${song.title}" from queue',
                              style: TextStyle(color: EmberColors.textPrimary, fontSize: 12.5),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: EmberColors.surfaceContainerLowest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            player.playSong(song);
                          },
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: song.artworkUrl,
                              width: 44,
                              height: 44,
                              memCacheWidth: 150,
                              memCacheHeight: 150,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                width: 44,
                                height: 44,
                                color: EmberColors.surfaceContainerHigh,
                                child: Icon(Icons.music_note_rounded, color: EmberColors.textMuted, size: 18),
                              ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EmberColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EmberColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14, color: EmberColors.textMuted),
                                onPressed: () => TrackOptionsSheet.show(context, song),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(Icons.drag_handle_rounded, color: EmberColors.textMuted, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ==========================================
          // 3. SMART AUTOPLAY & RECOMMENDATIONS
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMART AUTOPLAY & RADIO',
                        style: TextStyle(
                          color: EmberColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Keep playing similar tracks when queue finishes',
                        style: TextStyle(
                          color: EmberColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: player.isAutoplayEnabled,
                    activeTrackColor: EmberColors.primaryBlue,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      player.toggleAutoplay();
                    },
                  ),
                ],
              ),
            ),
          ),

          if (player.isAutoplayEnabled && recommendations.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = recommendations[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: EmberColors.surfaceContainerLowest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          player.playSong(song);
                        },
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: song.artworkUrl,
                            width: 44,
                            height: 44,
                            memCacheWidth: 150,
                            memCacheHeight: 150,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              width: 44,
                              height: 44,
                              color: EmberColors.surfaceContainerHigh,
                              child: Icon(Icons.music_note_rounded, color: EmberColors.textMuted, size: 18),
                            ),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: EmberColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded, color: EmberColors.primaryBlue, size: 22),
                          tooltip: 'Add to queue',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            player.addToQueue(song);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: EmberColors.surfaceContainerHigh,
                                duration: const Duration(seconds: 1),
                                content: Text(
                                  'Added "${song.title}" to queue',
                                  style: TextStyle(color: EmberColors.primaryBlueHi, fontSize: 12.5),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  childCount: recommendations.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
