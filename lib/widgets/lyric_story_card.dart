import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/lyrics_service.dart';
import '../theme/ember_theme.dart';

enum LyricStoryTheme {
  oledGlass,
  sunsetAura,
  cyberNeon,
  minimalObsidian,
}

class LyricStoryCardSheet extends StatefulWidget {
  final Song song;
  final List<LyricLine> selectedLines;

  const LyricStoryCardSheet({
    super.key,
    required this.song,
    required this.selectedLines,
  });

  static void show(BuildContext context, Song song, List<LyricLine> lines) {
    if (lines.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LyricStoryCardSheet(song: song, selectedLines: lines.take(4).toList()),
    );
  }

  @override
  State<LyricStoryCardSheet> createState() => _LyricStoryCardSheetState();
}

class _LyricStoryCardSheetState extends State<LyricStoryCardSheet> {
  LyricStoryTheme _theme = LyricStoryTheme.oledGlass;
  final GlobalKey _cardKey = GlobalKey();
  bool _isExporting = false;

  BoxDecoration _getThemeDecoration(LyricStoryTheme theme) {
    switch (theme) {
      case LyricStoryTheme.oledGlass:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0F172A),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        );
      case LyricStoryTheme.sunsetAura:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF701A75), Color(0xFFC026D3), Color(0xFFEA580C)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC026D3).withValues(alpha: 0.35),
              blurRadius: 24,
            ),
          ],
        );
      case LyricStoryTheme.cyberNeon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF0D9488)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
              blurRadius: 24,
            ),
          ],
        );
      case LyricStoryTheme.minimalObsidian:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF090D16),
          border: Border.all(color: const Color(0xFF334155), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 20,
            ),
          ],
        );
    }
  }

  Future<void> _exportAndShareImage() async {
    setState(() => _isExporting = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sine_lyric_story_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: EmberColors.primaryBlue,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Card saved to: ${file.path.split(Platform.pathSeparator).last}')),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export card: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _copyLyricText() {
    final text = widget.selectedLines.map((l) => l.text).join('\n');
    final formatted = '"$text"\n\n— ${widget.song.title} • ${widget.song.artist} via Sine';
    Clipboard.setData(ClipboardData(text: formatted));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lyrics copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EmberColors.charcoalCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.quoteLeft, size: 16, color: EmberColors.primaryBlue),
                  const SizedBox(width: 10),
                  const Text(
                    'Share Lyric Story',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Story Card Render Target (RepaintBoundary)
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: _getThemeDecoration(_theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const FaIcon(FontAwesomeIcons.waveSquare, size: 12, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'SINE • LOSSLESS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const FaIcon(FontAwesomeIcons.quoteRight, size: 14, color: Colors.white54),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Selected Lyric Lines
                  ...widget.selectedLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        line.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Song & Artist Meta Row
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.song.artworkUrl,
                          width: 44,
                          height: 44,
                          memCacheWidth: 90,
                          memCacheHeight: 90,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.white12,
                            child: const Icon(Icons.music_note, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.song.artist,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Theme Chooser Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildThemePill('OLED Glass', LyricStoryTheme.oledGlass),
              const SizedBox(width: 8),
              _buildThemePill('Sunset', LyricStoryTheme.sunsetAura),
              const SizedBox(width: 8),
              _buildThemePill('Cyber Neon', LyricStoryTheme.cyberNeon),
              const SizedBox(width: 8),
              _buildThemePill('Obsidian', LyricStoryTheme.minimalObsidian),
            ],
          ),

          const SizedBox(height: 20),

          // Action Buttons: Copy Text & Share Image
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.copy, size: 14),
                  label: const Text('Copy Text'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _copyLyricText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const FaIcon(FontAwesomeIcons.shareNodes, size: 14),
                  label: const Text('Save Card'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmberColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isExporting ? null : _exportAndShareImage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemePill(String name, LyricStoryTheme theme) {
    final isSelected = _theme == theme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _theme = theme);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? EmberColors.primaryBlue : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? EmberColors.primaryBlueHi : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
