import '../../widgets/music_detector_sheet.dart';
import '../../widgets/category_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../theme/ember_theme.dart';
import '../../widgets/spectrum_bars.dart';
import '../track_options_sheet.dart';
import '../sine_qr_scanner_screen.dart';

typedef SineSearchTab = PulsePipeSearchTab;

class PulsePipeSearchTab extends StatefulWidget {
  const PulsePipeSearchTab({super.key});

  @override
  State<PulsePipeSearchTab> createState() => _PulsePipeSearchTabState();
}

class _PulsePipeSearchTabState extends State<PulsePipeSearchTab> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _recentSearches = [];

  final List<GenreBrowseCardData> _browseCategories = const [
    GenreBrowseCardData(
      title: 'Electric & Dance',
      gradient: [Color(0xFF1565C0), Color(0xFF2979FF)],
      icon: FontAwesomeIcons.bolt,
      query: 'Dance Electronic',
    ),
    GenreBrowseCardData(
      title: 'Today\'s Top Hits',
      gradient: [Color(0xFF304FFE), Color(0xFF536DFE)],
      icon: FontAwesomeIcons.fire,
      query: 'Top Hits',
    ),
    GenreBrowseCardData(
      title: 'Pop Global',
      gradient: [Color(0xFFE91E63), Color(0xFFFF4081)],
      icon: FontAwesomeIcons.star,
      query: 'Pop',
    ),
    GenreBrowseCardData(
      title: 'Hip-Hop & Rap',
      gradient: [Color(0xFFFF6D00), Color(0xFFFF9100)],
      icon: FontAwesomeIcons.microphoneLines,
      query: 'Hip Hop',
    ),
    GenreBrowseCardData(
      title: 'Rock & Alt',
      gradient: [Color(0xFFD50000), Color(0xFFFF1744)],
      icon: FontAwesomeIcons.guitar,
      query: 'Rock',
    ),
    GenreBrowseCardData(
      title: 'Indie Vibes',
      gradient: [Color(0xFF6200EA), Color(0xFF7C4DFF)],
      icon: FontAwesomeIcons.headphones,
      query: 'Indie',
    ),
    GenreBrowseCardData(
      title: 'Chill & Lo-Fi',
      gradient: [Color(0xFF00BFA5), Color(0xFF1DE9B6)],
      icon: FontAwesomeIcons.mugSaucer,
      query: 'Chill Lofi',
    ),
    GenreBrowseCardData(
      title: 'Bollywood Hits',
      gradient: [Color(0xFFC51162), Color(0xFFF50057)],
      icon: FontAwesomeIcons.compactDisc,
      query: 'Bollywood',
    ),
    GenreBrowseCardData(
      title: 'Pakistani Hits',
      gradient: [Color(0xFF00C853), Color(0xFF69F0AE)],
      icon: FontAwesomeIcons.music,
      query: 'Pakistani Music',
    ),
    GenreBrowseCardData(
      title: 'Workout & Hype',
      gradient: [Color(0xFFFFAB00), Color(0xFFFFD740)],
      icon: FontAwesomeIcons.dumbbell,
      query: 'Workout',
    ),
    GenreBrowseCardData(
      title: 'Classical & Piano',
      gradient: [Color(0xFF37474F), Color(0xFF78909C)],
      icon: FontAwesomeIcons.recordVinyl,
      query: 'Classical',
    ),
    GenreBrowseCardData(
      title: 'Acoustic & Folk',
      gradient: [Color(0xFF4E342E), Color(0xFF8D6E63)],
      icon: FontAwesomeIcons.featherPointed,
      query: 'Acoustic',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _loadRecentSearches();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _recentSearches = prefs.getStringList('sine_recent_searches') ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _recentSearches.remove(clean);
    _recentSearches.insert(0, clean);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.sublist(0, 8);
    }
    if (mounted) setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('sine_recent_searches', _recentSearches);
    } catch (_) {}
  }

  Future<void> _clearRecentSearches() async {
    if (mounted) setState(() => _recentSearches.clear());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sine_recent_searches');
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String query) async {
    if (mounted) setState(() => _recentSearches.remove(query));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('sine_recent_searches', _recentSearches);
    } catch (_) {}
  }

  Future<void> _openQrScanner() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SineQrScannerScreen()),
    );
    if (!mounted) return;
    if (scanned != null && scanned.trim().isNotEmpty) {
      _controller.text = scanned.trim();
      final player = context.read<PlayerProvider>();
      player.search(scanned.trim());
      _saveRecentSearch(scanned.trim());
      setState(() {});
    }
  }

  void _onCategoryTap(GenreBrowseCardData category, PlayerProvider player) {
    CategoryDetailSheet.show(context, category);
  }



  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isSearching = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: EmberColors.obsidianBase,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey<String>('sine_search_scroll'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Header Title "Search"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    const Text(
                      'Search',
                      style: TextStyle(
                        color: EmberColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.microphoneLines, color: EmberColors.primaryBlue, size: 18),
                      tooltip: 'Audile Music Detector',
                      onPressed: () => MusicDetectorSheet.show(context),
                    ),
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.camera, color: EmberColors.textPrimary, size: 18),
                      tooltip: 'Scan QR Code',
                      onPressed: _openQrScanner,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: EmberColors.primaryBlue.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.bolt, size: 11, color: EmberColors.primaryBlue),
                          const SizedBox(width: 5),
                          Text(
                            'Sine Hi-Fi',
                            style: TextStyle(
                              color: EmberColors.primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Persistent Search Input Box
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: EmberColors.charcoalCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? EmberColors.electricBlue
                          : EmberColors.glassBorder.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.magnifyingGlass,
                        size: 16,
                        color: EmberColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search songs, artists, albums...',
                            hintStyle: TextStyle(
                              color: EmberColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (text) {
                            player.search(text);
                            setState(() {});
                          },
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              _saveRecentSearch(text);
                            }
                          },
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                            player.search('');
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const FaIcon(
                              FontAwesomeIcons.xmark,
                              size: 16,
                              color: EmberColors.textMuted,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _openQrScanner,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const FaIcon(
                              FontAwesomeIcons.camera,
                              size: 15,
                              color: EmberColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Search Results or Browse Categories
            if (isSearching) ...[
              if (player.isSearching && player.searchResults.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(EmberColors.electricBlue),
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (player.searchResults.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.compactDisc, size: 48, color: EmberColors.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'Couldn\'t find that song',
                          style: TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching for a different title, artist, or paste a YouTube link.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: EmberColors.textMuted.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Builder(
                  builder: (context) {
                    final searchResultsSnapshot = List<Song>.from(player.searchResults);
                    final topSong = searchResultsSnapshot.isNotEmpty ? searchResultsSnapshot.first : null;
                    final otherSongs = searchResultsSnapshot.length > 1 ? searchResultsSnapshot.sublist(1) : <Song>[];

                    return SliverMainAxisGroup(
                      slivers: [
                        if (topSong != null) ...[
                          const SliverPadding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Top result',
                                style: TextStyle(
                                  color: EmberColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _SpotifyTopResultCard(
                              song: topSong,
                              isCurrent: player.currentSong?.id == topSong.id,
                              isPlaying: player.currentSong?.id == topSong.id && player.isPlaying,
                              onTap: () {
                                final q = _controller.text.trim();
                                if (q.isNotEmpty) _saveRecentSearch(q);
                                player.playCategoryTracks(
                                  searchResultsSnapshot,
                                  startIndex: 0,
                                  targetSong: topSong,
                                  playingFrom: q.isNotEmpty ? 'Search: "$q"' : 'Top Result',
                                );
                              },
                              onOptions: () => TrackOptionsSheet.show(context, topSong),
                            ),
                          ),
                        ],
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Songs',
                                  style: TextStyle(
                                    color: EmberColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${searchResultsSnapshot.length} tracks',
                                  style: const TextStyle(
                                    color: EmberColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 150),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final song = otherSongs[index];
                                final isCurrent = player.currentSong?.id == song.id;

                                return _SearchResultRow(
                                  song: song,
                                  isCurrent: isCurrent,
                                  isPlaying: isCurrent && player.isPlaying,
                                  onTap: () {
                                    final q = _controller.text.trim();
                                    if (q.isNotEmpty) _saveRecentSearch(q);
                                    player.playCategoryTracks(
                                      searchResultsSnapshot,
                                      startIndex: index + 1,
                                      targetSong: song,
                                      playingFrom: q.isNotEmpty ? 'Search: "$q"' : 'Search Results',
                                    );
                                  },
                                  onOptions: () => TrackOptionsSheet.show(context, song),
                                );
                              },
                              childCount: otherSongs.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ] else ...[
              // Idle Browse Mode: Recent Searches (if any) + "Browse all"
              if (_recentSearches.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent searches',
                          style: TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: _clearRecentSearches,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Clear all',
                            style: TextStyle(color: EmberColors.textMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recentSearches.map((query) {
                        return Container(
                          decoration: BoxDecoration(
                            color: EmberColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              _controller.text = query;
                              player.search(query);
                              _saveRecentSearch(query);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_rounded, size: 14, color: EmberColors.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    query,
                                    style: TextStyle(color: EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeRecentSearch(query),
                                    child: Icon(Icons.close_rounded, size: 14, color: EmberColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Browse all',
                    style: TextStyle(
                      color: EmberColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.7,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cat = _browseCategories[index];
                      return RepaintBoundary(
                        key: ValueKey(cat.title),
                        child: _GenreCard(
                          category: cat,
                          onTap: () => _onCategoryTap(cat, player),
                        ),
                      );
                    },
                    childCount: _browseCategories.length,
                    addAutomaticKeepAlives: true,
                    addRepaintBoundaries: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GenreBrowseCardData {
  final String title;
  final List<Color> gradient;
  final FaIconData icon;
  final String query;

  const GenreBrowseCardData({
    required this.title,
    required this.gradient,
    required this.icon,
    required this.query,
  });
}

class _GenreCard extends StatelessWidget {
  final GenreBrowseCardData category;
  final VoidCallback onTap;

  const _GenreCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: category.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Text(
                category.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Transform.rotate(
                  angle: 0.35,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      category.icon,
                      size: 24,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _SearchResultRow({
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
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
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  CachedNetworkImage(
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
                      child: const Center(
                        child: FaIcon(FontAwesomeIcons.music, size: 18, color: EmberColors.textMuted),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 48,
                      height: 48,
                      color: EmberColors.charcoalCard,
                      child: const Center(
                        child: FaIcon(FontAwesomeIcons.music, size: 18, color: EmberColors.textMuted),
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      width: 48,
                      height: 48,
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: FaIcon(
                          isPlaying ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.play,
                          size: 16,
                          color: EmberColors.electricBlue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Title & Artist
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: EmberColors.primaryBlue.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(3),
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
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: EmberColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Options Button
            IconButton(
              icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 15, color: EmberColors.textMuted),
              onPressed: onOptions,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotifyTopResultCard extends StatelessWidget {
  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _SpotifyTopResultCard({
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: EmberColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? EmberColors.primaryBlue.withValues(alpha: 0.5)
              : EmberColors.outlineVariant.withValues(alpha: 0.5),
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: song.artworkUrl,
                        width: 76,
                        height: 76,
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          width: 76,
                          height: 76,
                          color: EmberColors.surfaceContainerHigh,
                          child: Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16, color: EmberColors.textMuted),
                      onPressed: onOptions,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: EmberColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242424),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Song',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: EmberColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isCurrent && isPlaying)
                      const SpectrumBars(isPlaying: true, height: 18)
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EmberColors.primaryBlue,
                          boxShadow: [
                            BoxShadow(
                              color: EmberColors.primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
