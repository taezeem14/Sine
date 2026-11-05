import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../theme/ember_theme.dart';

class SineQrCodeSheet extends StatelessWidget {
  final Song? song;
  final Playlist? playlist;

  const SineQrCodeSheet({
    super.key,
    this.song,
    this.playlist,
  }) : assert(song != null || playlist != null, 'Either song or playlist must be provided');

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SineQrCodeSheet(song: song),
    );
  }

  static void showForPlaylist(BuildContext context, Playlist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SineQrCodeSheet(playlist: playlist),
    );
  }

  String get _qrPayload {
    if (playlist != null) {
      final p = playlist!;
      final encodedTitle = Uri.encodeComponent(p.title);
      final isYt = p.id.startsWith('PL') || p.id.startsWith('yt_') || p.id.startsWith('RD');
      final ytId = isYt ? p.id.replaceFirst('yt_pl_', '').replaceFirst('yt_mix_', '') : '';

      // Compact encoding of tracks: id*artist*title separated by ~ (first 25 tracks)
      final compactTracks = p.songs.take(25).map((s) {
        final safeId = s.id.replaceAll('*', '').replaceAll('~', '');
        final safeArtist = s.artist.replaceAll('*', '').replaceAll('~', '');
        final safeTitle = s.title.replaceAll('*', '').replaceAll('~', '');
        return '$safeId*$safeArtist*$safeTitle';
      }).join('~');

      final encodedTracks = Uri.encodeComponent(compactTracks);
      return 'sine://playlist?id=${p.id}&title=$encodedTitle&ytId=$ytId&tracks=$encodedTracks';
    }

    final s = song!;
    final encodedTitle = Uri.encodeComponent(s.title);
    final encodedArtist = Uri.encodeComponent(s.artist);
    return 'sine://track?id=${s.id}&title=$encodedTitle&artist=$encodedArtist';
  }

  String get _itemTitle => playlist?.title ?? song?.title ?? 'Unknown';
  String get _itemSubtitle =>
      playlist != null ? '${playlist!.songs.length} tracks • Sine Playlist' : (song?.artist ?? 'Unknown Artist');
  String get _itemArtwork =>
      playlist != null
          ? (playlist!.coverUrl ?? (playlist!.songs.isNotEmpty ? playlist!.songs.first.artworkUrl : ''))
          : (song?.artworkUrl ?? '');
  String get _codeTag => playlist != null ? 'PLAYLIST' : 'SINE CODE';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: EmberColors.obsidianBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: EmberColors.outlineVariant, width: 1.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: EmberColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Spotify-style Card Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E2638),
                  EmberColors.surfaceContainerLow,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: EmberColors.primaryBlue.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Album Art + Brand
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _itemArtwork.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _itemArtwork,
                              width: 56,
                              height: 56,
                              memCacheWidth: 150,
                              memCacheHeight: 150,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                width: 56,
                                height: 56,
                                color: EmberColors.surfaceContainerHigh,
                                child: Icon(
                                  playlist != null ? Icons.queue_music_rounded : Icons.music_note_rounded,
                                  color: EmberColors.primaryBlue,
                                ),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: EmberColors.surfaceContainerHigh,
                              child: Icon(
                                playlist != null ? Icons.queue_music_rounded : Icons.music_note_rounded,
                                color: EmberColors.primaryBlue,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _itemTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EmberColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _itemSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: EmberColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _codeTag,
                        style: const TextStyle(
                          color: EmberColors.primaryBlueHi,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // QR Code Viewport
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _qrPayload,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0D1B2A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1B263B),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Soundwave Graphic Bars (Spotify-style sound bars)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 24; i++)
                      Container(
                        width: 3.5,
                        height: (12 + (i % 6) * 4.5).toDouble(),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i % 2 == 0 ? EmberColors.primaryBlue : EmberColors.secondaryCyan,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _qrPayload));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          playlist != null
                              ? 'Sine playlist link copied to clipboard!'
                              : 'Sine track link copied to clipboard!',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const FaIcon(FontAwesomeIcons.copy, size: 14, color: EmberColors.primaryBlue),
                  label: const Text('Copy Link', style: TextStyle(color: EmberColors.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: EmberColors.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmberColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
