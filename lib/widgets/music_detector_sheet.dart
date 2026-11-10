import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../screens/lyrics_sheet.dart';
import '../services/music_detection_service.dart';
import '../theme/ember_theme.dart';

class MusicDetectorSheet extends StatefulWidget {
  const MusicDetectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicDetectorSheet(),
    );
  }

  @override
  State<MusicDetectorSheet> createState() => _MusicDetectorSheetState();
}

class _MusicDetectorSheetState extends State<MusicDetectorSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _lyricsSearchController = TextEditingController();
  bool _isLyricsSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Auto-start listening when sheet opens (clear stale terminal match/error first)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = MusicDetectionService.instance;
      service.resetIfTerminal();
      if (service.statusNotifier.value == DetectionStatus.idle) {
        service.startListening();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _lyricsSearchController.dispose();
    final service = MusicDetectionService.instance;
    if (service.isListening) {
      service.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = MusicDetectionService.instance;
    final player = context.watch<PlayerProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: EmberColors.obsidianBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: EmberColors.outlineVariant, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<DetectionStatus>(
          valueListenable: service.statusNotifier,
          builder: (context, status, _) {
            return ValueListenableBuilder<MusicDetectionResult?>(
              valueListenable: service.resultNotifier,
              builder: (context, result, _) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: EmberColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: EmberColors.primaryBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.waveSquare,
                                color: EmberColors.primaryBlue,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Audile Music Detector',
                                  style: TextStyle(
                                    color: EmberColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Acoustic Fingerprint Recognition',
                                  style: TextStyle(
                                    color: EmberColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: FaIcon(
                                _isLyricsSearchOpen ? FontAwesomeIcons.microphoneLines : FontAwesomeIcons.magnifyingGlass,
                                color: EmberColors.textSecondary,
                                size: 16,
                              ),
                              tooltip: _isLyricsSearchOpen ? 'Acoustic Radar' : 'Search by Lyrics',
                              onPressed: () {
                                setState(() {
                                  _isLyricsSearchOpen = !_isLyricsSearchOpen;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: EmberColors.textMuted, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Manual Lyrics/Humming Search View
                      if (_isLyricsSearchOpen) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Search What You Heard',
                                style: TextStyle(
                                  color: EmberColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Enter snippets of lyrics or artist/title clues from ambient music:',
                                style: TextStyle(color: EmberColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _lyricsSearchController,
                                style: const TextStyle(color: EmberColors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g., "never gonna give you up"',
                                  hintStyle: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
                                  filled: true,
                                  fillColor: EmberColors.surfaceContainerLow,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: EmberColors.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.arrow_forward_rounded, color: EmberColors.primaryBlue),
                                    onPressed: () {
                                      final q = _lyricsSearchController.text.trim();
                                      if (q.isNotEmpty) {
                                        service.identifyByQuery(q);
                                      }
                                    },
                                  ),
                                ),
                                onSubmitted: (q) {
                                  if (q.trim().isNotEmpty) {
                                    service.identifyByQuery(q.trim());
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Matched Result State
                      if (status == DetectionStatus.success && result != null)
                        _buildMatchedResultView(result, player)
                      else if (status == DetectionStatus.noMatch || status == DetectionStatus.error)
                        _buildNoMatchView(service)
                      else
                        // Radar Waveform Listening State
                        _buildRadarListeningView(service, status),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRadarListeningView(MusicDetectionService service, DetectionStatus status) {
    final isListening = status == DetectionStatus.listening;
    final isAnalyzing = status == DetectionStatus.analyzing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Concentric Animated Ripple Waves
          ValueListenableBuilder<double>(
            valueListenable: service.amplitudeNotifier,
            builder: (context, amplitude, _) {
              return SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dynamic Radar Ripple Rings
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(220, 220),
                          painter: _RadarWavePainter(
                            progress: _pulseController.value,
                            amplitude: amplitude,
                            isListening: isListening,
                            isAnalyzing: isAnalyzing,
                          ),
                        );
                      },
                    ),

                    // Center Radar Touch Target Button
                    GestureDetector(
                      onTap: () {
                        if (isListening) {
                          service.stopAndIdentify();
                        } else {
                          service.startListening();
                        }
                      },
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), EmberColors.primaryBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: EmberColors.primaryBlue.withValues(alpha: isListening ? 0.45 : 0.2),
                              blurRadius: isListening ? 28 : 14,
                              spreadRadius: isListening ? 6 + (amplitude * 12) : 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: FaIcon(
                            isAnalyzing ? FontAwesomeIcons.gear : FontAwesomeIcons.microphoneLines,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Real-time Status Message
          ValueListenableBuilder<String>(
            valueListenable: service.statusMessageNotifier,
            builder: (context, msg, _) {
              return Column(
                children: [
                  Text(
                    isAnalyzing ? 'Analyzing Audio' : (isListening ? 'Listening...' : 'Ready'),
                    style: const TextStyle(
                      color: EmberColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: EmberColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Action Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isListening ? EmberColors.surfaceContainerHigh : EmberColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: FaIcon(
              isListening ? FontAwesomeIcons.stop : FontAwesomeIcons.play,
              size: 13,
            ),
            label: Text(
              isListening ? 'Identify Now' : 'Start Listening',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (isListening) {
                service.stopAndIdentify();
              } else {
                service.startListening();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedResultView(MusicDetectionResult result, PlayerProvider player) {
    final sineSong = result.sineSong;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Album Cover with Glow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: EmberColors.primaryBlue.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: result.artworkUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: result.artworkUrl,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        width: 140,
                        height: 140,
                        color: EmberColors.surfaceContainerHigh,
                        child: const Icon(Icons.music_note, color: EmberColors.textMuted, size: 48),
                      ),
                    )
                  : Container(
                      width: 140,
                      height: 140,
                      color: EmberColors.surfaceContainerHigh,
                      child: const Icon(Icons.music_note, color: EmberColors.textMuted, size: 48),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Quality Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EmberColors.primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: EmberColors.primaryBlue.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.bolt, size: 10, color: EmberColors.primaryBlue),
                SizedBox(width: 4),
                Text(
                  'VERIFIED AUDIO MATCH',
                  style: TextStyle(
                    color: EmberColors.primaryBlueHi,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            result.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: EmberColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: EmberColors.textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 18),

          // Action Buttons: Play Stream, Favorite, Lyrics
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmberColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.play, size: 14),
                  label: const Text('Play Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    if (sineSong != null) {
                      player.playSong(sineSong, playingFrom: 'Music Detection (Audile)');
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: 10),
              if (sineSong != null) ...[
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: EmberColors.surfaceContainerHigh,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: FaIcon(
                    player.isFavorite(sineSong.id) ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                    color: player.isFavorite(sineSong.id) ? EmberColors.primaryBlue : EmberColors.textPrimary,
                    size: 16,
                  ),
                  tooltip: 'Add to Liked Songs',
                  onPressed: () => player.toggleFavorite(sineSong),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: EmberColors.surfaceContainerHigh,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const FaIcon(FontAwesomeIcons.alignLeft, color: EmberColors.textPrimary, size: 16),
                  tooltip: 'View Lyrics',
                  onPressed: () {
                    LyricsSheet.show(context, sineSong);
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          TextButton(
            onPressed: () => MusicDetectionService.instance.startListening(),
            child: const Text('Detect Another Song', style: TextStyle(color: EmberColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchView(MusicDetectionService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.redAccent, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Couldn\'t Identify Song',
            style: TextStyle(
              color: EmberColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<String>(
            valueListenable: service.statusMessageNotifier,
            builder: (context, msg, _) => Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: EmberColors.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EmberColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                onPressed: () => service.startListening(),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: EmberColors.textPrimary,
                  side: const BorderSide(color: EmberColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const FaIcon(FontAwesomeIcons.keyboard, size: 13),
                label: const Text('Type Lyrics'),
                onPressed: () => setState(() => _isLyricsSearchOpen = true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering dynamic acoustic radar wave ripples
class _RadarWavePainter extends CustomPainter {
  final double progress;
  final double amplitude;
  final bool isListening;
  final bool isAnalyzing;

  _RadarWavePainter({
    required this.progress,
    required this.amplitude,
    required this.isListening,
    required this.isAnalyzing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    if (isListening || isAnalyzing) {
      for (int i = 0; i < 3; i++) {
        final waveProgress = (progress + (i * 0.33)) % 1.0;
        final radius = 48.0 + (maxRadius - 48.0) * waveProgress * (1.0 + amplitude * 0.4);
        final opacity = (1.0 - waveProgress).clamp(0.0, 1.0) * (isAnalyzing ? 0.35 : 0.65);

        final paint = Paint()
          ..color = (isAnalyzing ? EmberColors.secondaryCyan : EmberColors.primaryBlue).withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawCircle(center, radius, paint);
      }
    } else {
      // Idle faint ring
      final paint = Paint()
        ..color = EmberColors.outlineVariant.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, 64.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isAnalyzing != isAnalyzing;
  }
}
