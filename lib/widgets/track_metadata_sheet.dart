import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';

/// Offline metadata viewer and tag editor sheet for Sine tracks (inspired by Metrolist)
class TrackMetadataSheet extends StatefulWidget {
  final Song song;
  const TrackMetadataSheet({super.key, required this.song});

  static void show(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackMetadataSheet(song: song),
    );
  }

  @override
  State<TrackMetadataSheet> createState() => _TrackMetadataSheetState();
}

class _TrackMetadataSheetState extends State<TrackMetadataSheet> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  void _cleanYouTubeFormatting() {
    String rawTitle = _titleController.text;
    String rawArtist = _artistController.text;

    // Detect "Artist - Title" pattern
    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      if (parts.length >= 2) {
        rawArtist = parts[0].trim();
        rawTitle = parts.sublist(1).join(' - ').trim();
      }
    }

    // Strip common YouTube tag brackets
    final cleanedTitle = rawTitle
        .replaceAll(RegExp(r'\[(Official|Music Video|Audio|HD|4K|Lyrics?)[^\]]*\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\((Official|Music Video|Audio|HD|4K|Lyrics?)[^\)]*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .trim();

    setState(() {
      _titleController.text = cleanedTitle;
      _artistController.text = rawArtist;
    });

    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.song;
    final isLocal = s.streamUrl.startsWith('/') || s.streamUrl.startsWith('file://');

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: EmberColors.obsidianBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: EmberColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const FaIcon(FontAwesomeIcons.penToSquare, size: 16, color: EmberColors.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Track Metadata',
                      style: TextStyle(color: EmberColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _cleanYouTubeFormatting,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: EmberColors.primaryBlue),
                  label: const Text('Auto-Clean', style: TextStyle(color: EmberColors.primaryBlue, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Technical Specs Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EmberColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: s.artworkUrl.isNotEmpty
                        ? Image.network(
                            s.artworkUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 44,
                              height: 44,
                              color: EmberColors.surfaceContainerHigh,
                              child: const Icon(Icons.music_note, color: EmberColors.textMuted, size: 20),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: EmberColors.surfaceContainerHigh,
                            child: const Icon(Icons.music_note, color: EmberColors.textMuted, size: 20),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLocal ? 'Offline Audio File' : 'YouTube Stream Stem',
                          style: const TextStyle(color: EmberColors.primaryBlueHi, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Duration: ${s.duration.inMinutes}:${(s.duration.inSeconds % 60).toString().padLeft(2, '0')} • ID: ${s.id}',
                          style: const TextStyle(color: EmberColors.textMuted, fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Track Title
            TextField(
              controller: _titleController,
              style: const TextStyle(color: EmberColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Track Title',
                labelStyle: const TextStyle(color: EmberColors.textSecondary, fontSize: 12),
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: FaIcon(FontAwesomeIcons.music, size: 14, color: EmberColors.primaryBlue),
                ),
                filled: true,
                fillColor: EmberColors.surfaceContainerLow,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: EmberColors.outlineVariant.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EmberColors.primaryBlue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Artist Name
            TextField(
              controller: _artistController,
              style: const TextStyle(color: EmberColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Artist / Channel Name',
                labelStyle: const TextStyle(color: EmberColors.textSecondary, fontSize: 12),
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: FaIcon(FontAwesomeIcons.userPen, size: 14, color: EmberColors.primaryBlue),
                ),
                filled: true,
                fillColor: EmberColors.surfaceContainerLow,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: EmberColors.outlineVariant.withValues(alpha: 0.6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EmberColors.primaryBlue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EmberColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: () {
                  final newTitle = _titleController.text.trim();
                  final newArtist = _artistController.text.trim();
                  if (newTitle.isNotEmpty) {
                    final updated = widget.song.copyWith(
                      title: newTitle,
                      artist: newArtist.isNotEmpty ? newArtist : widget.song.artist,
                    );
                    context.read<PlayerProvider>().updateSongMetadata(updated);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: EmberColors.surfaceContainerHigh,
                        content: Text('Track metadata saved successfully!', style: TextStyle(color: EmberColors.primaryBlueHi)),
                      ),
                    );
                  }
                },
                child: const Text('Save Metadata Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
