import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../screens/tabs/pulsepipe_search_tab.dart';
import '../screens/track_options_sheet.dart';
import '../services/catalog_service.dart';
import '../theme/ember_theme.dart';

class CategoryDetailSheet extends StatefulWidget {
  final GenreBrowseCardData category;

  const CategoryDetailSheet({
    super.key,
    required this.category,
  });

  static Future<void> show(BuildContext context, GenreBrowseCardData category) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryDetailSheet(category: category),
    );
  }

  @override
  State<CategoryDetailSheet> createState() => _CategoryDetailSheetState();
}

class _CategoryDetailSheetState extends State<CategoryDetailSheet> {
  List<Song> _tracks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _continuationToken;
  final Set<String> _seenIds = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryTracks();
  }

  Future<void> _loadCategoryTracks() async {
    final page = await CatalogService.fetchCategoryPage(
      widget.category.title,
      customQuery: widget.category.query,
      seenIds: _seenIds,
    );

    if (mounted) {
      setState(() {
        _tracks = page.songs;
        _continuationToken = page.continuationToken;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoading ||
        _isLoadingMore ||
        _continuationToken == null ||
        _continuationToken!.isEmpty) {
      return;
    }

    setState(() => _isLoadingMore = true);
    try {
      final page = await CatalogService.fetchCategoryPage(
        widget.category.title,
        customQuery: widget.category.query,
        continuationToken: _continuationToken,
        seenIds: _seenIds,
      );
      if (mounted) {
        final existingIds = _tracks.map((s) => s.id).toSet();
        final uniqueNew = page.songs.where((s) => existingIds.add(s.id)).toList();
        setState(() {
          _continuationToken = page.continuationToken;
          if (uniqueNew.isNotEmpty) {
            _tracks = [..._tracks, ...uniqueNew];
          }
          _isLoadingMore = false;
        });
        if (uniqueNew.isNotEmpty && mounted) {
          final player = context.read<PlayerProvider>();
          if (player.playingFrom == widget.category.title) {
            player.addTracksToQueue(uniqueNew);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _playAll(PlayerProvider player, {bool shuffle = false}) {
    if (_tracks.isEmpty) return;
    final list = List<Song>.from(_tracks);
    if (shuffle) list.shuffle();

    player.playPlaylist(
      Playlist(
        id: 'category_${widget.category.title.toLowerCase().replaceAll(' ', '_')}',
        title: widget.category.title,
        description: 'Curated ${widget.category.title} tracks • High-Fidelity Opus Stream',
        songs: list,
        createdAt: DateTime.now(),
        coverUrl: list.first.artworkUrl,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    context.select<PlayerProvider, (String?, bool)>((p) => (p.currentSong?.id, p.isPlaying));
    final isOled = context.select<PlayerProvider, bool>((p) => p.isOledBlack);
    final accent = Theme.of(context).colorScheme.primary;
    final hasMore = _continuationToken != null && _continuationToken!.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(
          top: BorderSide(color: EmberColors.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header Card with Category Gradient
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.category.gradient.first.withValues(alpha: 0.8),
                  widget.category.gradient.last.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: widget.category.gradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FaIcon(widget.category.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isLoading
                                ? 'Loading curated tracks...'
                                : '${_tracks.length}${hasMore ? "+" : ""} high-fidelity tracks',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.play, size: 13),
                      label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: _tracks.isNotEmpty ? () => _playAll(player) : null,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.shuffle, size: 12),
                      label: const Text('Shuffle', style: TextStyle(fontSize: 13)),
                      onPressed: _tracks.isNotEmpty ? () => _playAll(player, shuffle: true) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Infinite Paginated Track List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: accent),
                  )
                : _tracks.isEmpty
                    ? const Center(
                        child: Text(
                          'No tracks found in this category.',
                          style: TextStyle(color: EmberColors.textMuted),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification &&
                              notification.metrics.maxScrollExtent > 0 &&
                              notification.metrics.extentAfter < 450) {
                            _loadMoreTracks();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          itemCount: _tracks.length + (_isLoadingMore ? 1 : 0),
                          padding: const EdgeInsets.only(bottom: 24),
                          itemBuilder: (context, index) {
                            if (index >= _tracks.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                                  ),
                                ),
                              );
                            }

                            final song = _tracks[index];
                            final isCurrent = player.currentSong?.id == song.id;

                            return Container(
                              key: ValueKey(song.id),
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCurrent ? accent.withValues(alpha: 0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                dense: true,
                                visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
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
                                      child: const Icon(Icons.music_note, color: EmberColors.textMuted, size: 20),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? accent : EmberColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: EmberColors.textSecondary, fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: FaIcon(
                                        player.isFavorite(song.id) ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                                        size: 14,
                                        color: player.isFavorite(song.id) ? accent : EmberColors.textMuted,
                                      ),
                                      onPressed: () => player.toggleFavorite(song),
                                    ),
                                    IconButton(
                                      icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14, color: EmberColors.textMuted),
                                      onPressed: () => TrackOptionsSheet.show(context, song),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  player.playCategoryTracks(
                                    _tracks,
                                    startIndex: index,
                                    targetSong: song,
                                    playingFrom: widget.category.title,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
