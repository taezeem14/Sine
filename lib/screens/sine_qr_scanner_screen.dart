import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../providers/player_provider.dart';
import '../services/youtube_importer_service.dart';
import '../theme/ember_theme.dart';

class SineQrScannerScreen extends StatefulWidget {
  const SineQrScannerScreen({super.key});

  @override
  State<SineQrScannerScreen> createState() => _SineQrScannerScreenState();
}

class _SineQrScannerScreenState extends State<SineQrScannerScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _scanLineAnim;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );

    _scanLineAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    _processCode(code.trim());
  }

  Future<void> _processCode(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();
    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) return;
    final player = context.read<PlayerProvider>();

    try {
      // 1. Sine Scannable Playlist URI: sine://playlist?id=...&title=...&ytId=...&tracks=...
      if (rawCode.startsWith('sine://playlist')) {
        final uri = Uri.parse(rawCode);
        final playlistId = uri.queryParameters['id'] ?? 'pl_${DateTime.now().millisecondsSinceEpoch}';
        final title = uri.queryParameters['title'] ?? 'Scanned Playlist';
        final ytId = uri.queryParameters['ytId'] ?? '';
        final tracksParam = uri.queryParameters['tracks'] ?? '';

        List<Song> songs = [];
        if (tracksParam.isNotEmpty) {
          final decodedTracks = Uri.decodeComponent(tracksParam);
          final items = decodedTracks.split('~');
          for (final item in items) {
            final parts = item.split('*');
            if (parts.isNotEmpty && parts[0].isNotEmpty) {
              final id = parts[0];
              final artist = parts.length > 1 ? parts[1] : 'Unknown Artist';
              final songTitle = parts.length > 2 ? parts[2] : 'Unknown Title';
              songs.add(
                Song(
                  id: id,
                  title: songTitle,
                  artist: artist,
                  duration: const Duration(minutes: 3, seconds: 30),
                  artworkUrl: 'https://img.youtube.com/vi/${id.replaceFirst('yt_', '')}/hqdefault.jpg',
                  streamUrl: 'https://www.youtube.com/watch?v=${id.replaceFirst('yt_', '')}',
                  source: 'youtube',
                ),
              );
            }
          }
        }

        // If tracks was empty but YouTube playlist id exists, fetch remotely
        if (songs.isEmpty && ytId.isNotEmpty) {
          final result = await YouTubeImporterService.importFromUrl('https://www.youtube.com/playlist?list=$ytId');
          if (result.playlist != null && result.playlist!.songs.isNotEmpty) {
            songs = result.playlist!.songs;
          }
        }

        if (mounted) {
          _showScannedPlaylistSheet(context, player, title, playlistId, songs);
        }
        return;
      }

      // 2. Sine Scannable Track URI: sine://track?id=...&title=...&artist=...
      if (rawCode.startsWith('sine://track')) {
        final uri = Uri.parse(rawCode);
        final id = uri.queryParameters['id'] ?? '';
        final title = uri.queryParameters['title'] ?? 'Unknown Track';
        final artist = uri.queryParameters['artist'] ?? 'Unknown Artist';
        final rawArtwork = uri.queryParameters['artwork'];

        if (id.isNotEmpty) {
          final cleanVid = id.replaceFirst('yt_', '');
          final artwork = (rawArtwork != null && rawArtwork.isNotEmpty)
              ? rawArtwork
              : 'https://img.youtube.com/vi/$cleanVid/hqdefault.jpg';

          final song = Song(
            id: id,
            title: title,
            artist: artist,
            duration: const Duration(minutes: 3, seconds: 30),
            artworkUrl: artwork,
            streamUrl: 'https://www.youtube.com/watch?v=$cleanVid',
            source: 'youtube',
          );

          if (mounted) {
            _showScannedTrackSheet(context, player, song);
          }
          return;
        }
      }

      // 3. YouTube Playlist URL
      final ytPlaylistId = YouTubeImporterService.extractPlaylistId(rawCode);
      if (ytPlaylistId != null && ytPlaylistId.isNotEmpty) {
        final importResult = await YouTubeImporterService.importFromUrl(rawCode);
        if (importResult.playlist != null && importResult.playlist!.songs.isNotEmpty) {
          final pl = importResult.playlist!;
          if (mounted) {
            _showScannedPlaylistSheet(context, player, pl.title, pl.id, pl.songs);
          }
          return;
        }
      }

      // 4. YouTube Video URL or Video ID
      final videoId = YouTubeImporterService.extractVideoId(rawCode);
      if (videoId != null && videoId.isNotEmpty) {
        final importResult = await YouTubeImporterService.importFromUrl(rawCode);
        if (importResult.song != null) {
          final resolvedSong = importResult.song!;
          if (mounted) {
            _showScannedTrackSheet(context, player, resolvedSong);
          }
          return;
        }
      }

      // 5. Fallback: Search text query
      if (mounted) {
        Navigator.of(context).pop(rawCode);
      }
    } catch (e) {
      debugPrint('[SineQrScanner] Scan error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        try {
          _controller.start();
        } catch (_) {}
      }
    }
  }

  void _showScannedTrackSheet(
    BuildContext context,
    PlayerProvider player,
    Song song,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: EmberColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song.artworkUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: song.artworkUrl,
                            width: 62,
                            height: 62,
                            memCacheWidth: 150,
                            memCacheHeight: 150,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              width: 62,
                              height: 62,
                              color: EmberColors.surfaceContainerHigh,
                              child: const Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
                            ),
                          )
                        : Container(
                            width: 62,
                            height: 62,
                            color: EmberColors.surfaceContainerHigh,
                            child: const Icon(Icons.music_note_rounded, color: EmberColors.primaryBlue),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: EmberColors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: EmberColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: EmberColors.primaryBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SINE QR',
                      style: TextStyle(
                        color: EmberColors.primaryBlueHi,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: EmberColors.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: FaIcon(
                        player.isFavorite(song.id) ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                        size: 14,
                        color: player.isFavorite(song.id) ? Colors.redAccent : EmberColors.primaryBlue,
                      ),
                      label: Text(
                        player.isFavorite(song.id) ? 'In Liked Songs' : 'Add to Library',
                        style: const TextStyle(color: EmberColors.textPrimary),
                      ),
                      onPressed: () async {
                        if (!player.isFavorite(song.id)) {
                          await player.toggleFavorite(song);
                        }
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: EmberColors.surfaceContainerHigh,
                              content: Text(
                                'Added "${song.title}" to Liked Songs in Library!',
                                style: const TextStyle(color: EmberColors.primaryBlueHi),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmberColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      label: const Text('Play Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await player.playSong(song);
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isProcessing = false);
        try {
          _controller.start();
        } catch (_) {}
      }
    });
  }

  void _showScannedPlaylistSheet(
    BuildContext context,
    PlayerProvider player,
    String title,
    String playlistId,
    List<Song> songs,
  ) {
    final playlist = Playlist(
      id: playlistId.isNotEmpty && !playlistId.startsWith('scanned_pl_')
          ? playlistId
          : 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.isNotEmpty ? title : 'Scanned Playlist',
      songs: songs,
      createdAt: DateTime.now(),
      coverUrl: songs.isNotEmpty ? songs.first.artworkUrl : null,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: EmberColors.obsidianBase,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: EmberColors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: playlist.coverUrl!,
                            width: 60,
                            height: 60,
                            memCacheWidth: 150,
                            memCacheHeight: 150,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              width: 60,
                              height: 60,
                              color: EmberColors.surfaceContainerHigh,
                              child: const Icon(Icons.queue_music_rounded, color: EmberColors.primaryBlue),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: EmberColors.surfaceContainerHigh,
                            child: const Icon(Icons.queue_music_rounded, color: EmberColors.primaryBlue),
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
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.songs.length} tracks • Sine Playlist',
                          style: const TextStyle(color: EmberColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: EmberColors.primaryBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SINE QR',
                      style: TextStyle(
                        color: EmberColors.primaryBlueHi,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (songs.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: songs.length > 5 ? 5 : songs.length,
                    separatorBuilder: (_, _) => const Divider(color: EmberColors.outlineVariant, height: 1),
                    itemBuilder: (_, idx) {
                      final s = songs[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          '${idx + 1}',
                          style: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
                        ),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          s.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: EmberColors.textMuted, fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
                if (songs.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+ ${songs.length - 5} more tracks',
                      style: const TextStyle(color: EmberColors.primaryBlue, fontSize: 12, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: EmberColors.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.bookmark, size: 14, color: EmberColors.primaryBlue),
                      label: const Text('Add to Library', style: TextStyle(color: EmberColors.textPrimary)),
                      onPressed: () async {
                        await player.importScannedPlaylist(playlist);
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: EmberColors.surfaceContainerHigh,
                              content: Text(
                                'Saved "${playlist.title}" to Library!',
                                style: const TextStyle(color: EmberColors.primaryBlueHi),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmberColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                      label: const Text('Play Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await player.importScannedPlaylist(playlist);
                        await player.playPlaylist(playlist);
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isProcessing = false);
        try {
          _controller.start();
        } catch (_) {}
      }
    });
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmberColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Link or Code', style: TextStyle(color: EmberColors.textPrimary)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: EmberColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Paste YouTube link or Sine QR link...',
            hintStyle: const TextStyle(color: EmberColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: EmberColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EmberColors.primaryBlue),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (textController.text.trim().isNotEmpty) {
                _processCode(textController.text.trim());
              }
            },
            child: const Text('Open', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.bolt, color: Colors.white, size: 18),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.cameraRotate, color: Colors.white, size: 18),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // Dark Viewfinder Vignette Overlay
          LayoutBuilder(
            builder: (context, constraints) {
              const boxSize = 250.0;
              final left = (constraints.maxWidth - boxSize) / 2;
              final top = (constraints.maxHeight - boxSize) / 2 - 40;

              return Stack(
                children: [
                  // Viewfinder Frame
                  Positioned(
                    left: left,
                    top: top,
                    width: boxSize,
                    height: boxSize,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: EmberColors.primaryBlue, width: 2.5),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: EmberColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Animated Scanning Laser
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (context, child) {
                      return Positioned(
                        left: left + 10,
                        top: top + 10 + (_scanLineAnim.value * (boxSize - 20)),
                        width: boxSize - 20,
                        height: 2.5,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                EmberColors.secondaryCyan,
                                EmberColors.primaryBlue,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: EmberColors.secondaryCyan.withValues(alpha: 0.8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Helper Instruction Text
                  Positioned(
                    top: top + boxSize + 28,
                    left: 20,
                    right: 20,
                    child: const Text(
                      'Point camera at a Sine QR code or YouTube link',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Bottom Manual Link Button
          Positioned(
            bottom: 36,
            left: 32,
            right: 32,
            child: ElevatedButton.icon(
              onPressed: _showManualInputDialog,
              icon: const FaIcon(FontAwesomeIcons.keyboard, size: 14, color: Colors.white),
              label: const Text('Paste Link or Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: EmberColors.surfaceContainerLow.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: EmberColors.outlineVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
