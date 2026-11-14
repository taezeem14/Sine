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

  @override
  void initState() {
    super.initState();
    _loadCategoryTracks();
  }

  Future<void> _loadCategoryTracks() async {
    // Map query to catalog key or search query
    final query = widget.category.query.toLowerCase().replaceAll('-', '').replaceAll(' ', '_');
    final songs = await CatalogService.fetchCategory(query);

    if (mounted) {
      setState(() {
        _tracks = songs.isNotEmpty ? songs : [];
        _isLoading = false;
      });
    }

    if (_tracks.isEmpty) {
      final searchResults = await CatalogService.searchOnline(widget.category.query, limit: 30);
      if (mounted) {
        setState(() {
          _tracks = searchResults;
          _isLoading = false;
        });
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
    final player = context.watch<PlayerProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: EmberColors.obsidianBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
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
                // Drag handle
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
                            _isLoading ? 'Loading curated tracks...' : '${_tracks.length} high-fidelity tracks',
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

                // Controls: Play All & Shuffle
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmberColors.primaryBlue,
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

          // Track List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: EmberColors.primaryBlue),
                  )
                : _tracks.isEmpty
                    ? const Center(
                        child: Text(
                          'No tracks found in this category.',
                          style: TextStyle(color: EmberColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _tracks.length,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemBuilder: (context, index) {
                          final song = _tracks[index];
                          final isCurrent = player.currentSong?.id == song.id;

                          return Container(
                            key: ValueKey(song.id),
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent ? EmberColors.primaryBlue.withValues(alpha: 0.12) : Colors.transparent,
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
                                    child: Icon(Icons.music_note, color: EmberColors.textMuted, size: 20),
                                  ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? EmberColors.primaryBlue : EmberColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: EmberColors.textSecondary, fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: FaIcon(
                                      player.isFavorite(song.id) ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                                      size: 14,
                                      color: player.isFavorite(song.id) ? EmberColors.primaryBlue : EmberColors.textMuted,
                                    ),
                                    onPressed: () => player.toggleFavorite(song),
                                  ),
                                  IconButton(
                                    icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 14, color: EmberColors.textMuted),
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
        ],
      ),
    );
  }
}
