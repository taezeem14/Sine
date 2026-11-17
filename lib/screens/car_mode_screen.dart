import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../theme/ember_theme.dart';

class CarModeScreen extends StatelessWidget {
  const CarModeScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const CarModeScreen(),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSong = player.currentSong;
    final isPlaying = player.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -250) {
                // Swipe Left -> Skip Next
                HapticFeedback.mediumImpact();
                player.skipToNext();
              } else if (details.primaryVelocity! > 250) {
                // Swipe Right -> Skip Prev
                HapticFeedback.mediumImpact();
                player.skipToPrevious();
              }
            }
          },
          onTap: () {
            HapticFeedback.selectionClick();
            player.togglePlayPause();
          },
          child: Container(
            color: Colors.transparent, // Ensure gesture detector covers whole area
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Action Bar: Exit & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        FaIcon(FontAwesomeIcons.car, size: 20, color: EmberColors.primaryBlue),
                        const SizedBox(width: 10),
                        Text(
                          'CAR MODE',
                          style: TextStyle(
                            color: EmberColors.primaryBlueHi,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.xmark, size: 24, color: Colors.white),
                      tooltip: 'Exit Car Mode',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // Center Album Thumbnail / Disc
                if (currentSong != null)
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: EmberColors.primaryBlue.withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: currentSong.artworkUrl,
                      memCacheWidth: 280,
                      memCacheHeight: 280,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: EmberColors.charcoalCard,
                        child: Center(
                          child: FaIcon(FontAwesomeIcons.music, size: 48, color: EmberColors.primaryBlue),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Giant Readable Title and Artist
                Text(
                  currentSong?.title ?? 'No Song Playing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  currentSong?.artist ?? 'Tap anywhere to play',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(flex: 1),

                // Simple High-Contrast Progress Bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    activeTrackColor: EmberColors.primaryBlue,
                    inactiveTrackColor: const Color(0xFF1E293B),
                    thumbColor: EmberColors.primaryBlueHi,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  ),
                  child: Slider(
                    value: player.duration.inMilliseconds > 0
                        ? (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (val) {
                      final targetMs = (val * player.duration.inMilliseconds).round();
                      player.seek(Duration(milliseconds: targetMs));
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Huge Touch Target Media Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Favorite Toggle
                    IconButton(
                      iconSize: 32,
                      icon: FaIcon(
                        currentSong != null && player.isFavorite(currentSong.id)
                            ? FontAwesomeIcons.solidHeart
                            : FontAwesomeIcons.heart,
                        color: currentSong != null && player.isFavorite(currentSong.id)
                            ? EmberColors.primaryBlue
                            : Colors.white70,
                      ),
                      onPressed: currentSong == null
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              player.toggleFavorite(currentSong);
                            },
                    ),

                    // Previous Track (68dp)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 30,
                        icon: const FaIcon(FontAwesomeIcons.backwardStep, color: Colors.white),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          player.skipToPrevious();
                        },
                      ),
                    ),

                    // Giant Center Play/Pause (92dp)
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0072FF), Color(0xFF00D2FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D2FF).withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        iconSize: 42,
                        icon: FaIcon(
                          isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          player.togglePlayPause();
                        },
                      ),
                    ),

                    // Next Track (68dp)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 30,
                        icon: const FaIcon(FontAwesomeIcons.forwardStep, color: Colors.white),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          player.skipToNext();
                        },
                      ),
                    ),

                    // 15s Forward Jump
                    IconButton(
                      iconSize: 28,
                      icon: const FaIcon(FontAwesomeIcons.rotateRight, color: Colors.white70),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        player.seek(player.position + const Duration(seconds: 15));
                      },
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // Hint
                const Text(
                  'Swipe anywhere: ← Next  |  Prev →',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
