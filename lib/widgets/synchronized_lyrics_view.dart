import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/player_provider.dart';
import '../services/lyrics_service.dart';
import '../theme/ember_theme.dart';

class SynchronizedLyricsView extends StatefulWidget {
  const SynchronizedLyricsView({super.key});

  @override
  State<SynchronizedLyricsView> createState() => _SynchronizedLyricsViewState();
}

class _SynchronizedLyricsViewState extends State<SynchronizedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastIndex = -1;
  bool _userScrolling = false;
  Timer? _userScrollTimer;

  String? _currentSongId;

  @override
  void dispose() {
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    _lineKeys.clear();
    super.dispose();
  }

  void _scrollToIndex(int index, int totalLines) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions ||
        _userScrolling ||
        index < 0 ||
        index >= totalLines) {
      return;
    }

    final lineKey = _lineKeys[index];
    final keyContext = lineKey?.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // Precise fallback: proportional positioning against full extent with viewport centering
    final maxScroll = _scrollController.position.maxScrollExtent;
    final ratio = totalLines > 1 ? (index / (totalLines - 1)) : 0.0;
    final targetOffset = ratio * maxScroll;
    final clamped = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final cur = player.currentSong;

    if (cur != null && cur.id != _currentSongId) {
      _currentSongId = cur.id;
      _lineKeys.clear();
      _lastIndex = -1;
      _userScrolling = false;
    }

    if (cur == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.music, size: 32, color: EmberColors.textMuted),
            SizedBox(height: 12),
            Text('No song playing', style: TextStyle(color: EmberColors.textMuted)),
          ],
        ),
      );
    }

    if (LyricsService.isTempoModified(cur.title, cur.artist)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EmberColors.surfaceContainerHigh.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(FontAwesomeIcons.gaugeHigh, size: 32, color: EmberColors.textMuted),
              ),
              const SizedBox(height: 16),
              const Text(
                'Lyrics Unavailable for Modified-Tempo Audio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: EmberColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Synchronized lyrics are disabled on slowed, reverb, or sped-up tracks to prevent audio timing mismatch.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: EmberColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (player.isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: EmberColors.primaryAmber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding lyrics for ${cur.title}...',
              style: const TextStyle(color: EmberColors.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final synced = player.syncedLyrics;
    final hasSynced = player.hasSyncedLyrics;
    final plain = player.plainLyrics;

    if (hasSynced && synced.isNotEmpty) {
      final activeIdx = player.currentLyricIndex;

      if (activeIdx != _lastIndex && activeIdx >= 0) {
        _lastIndex = activeIdx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToIndex(activeIdx, synced.length);
          }
        });
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = (constraints.maxHeight * 0.42).clamp(40.0, 400.0);
          final bottomPadding = (constraints.maxHeight * 0.60).clamp(60.0, 600.0);

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              NotificationListener<UserScrollNotification>(
                onNotification: (notif) {
                  if (notif.direction != ScrollDirection.idle) {
                    _userScrolling = true;
                    _userScrollTimer?.cancel();
                  } else {
                    _userScrollTimer?.cancel();
                    _userScrollTimer = Timer(const Duration(seconds: 3), () {
                      if (mounted) _userScrolling = false;
                    });
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: topPadding,
                    bottom: bottomPadding,
                  ),
                  itemCount: synced.length,
                  itemBuilder: (context, index) {
                    final line = synced[index];
                    final isActive = index == activeIdx;

                    if (line.text.trim().isEmpty) {
                      return const SizedBox(height: 16);
                    }

                    return Center(
                      child: GestureDetector(
                        onTap: () {
                          player.seek(line.timestamp);
                          _userScrolling = false;
                          _scrollToIndex(index, synced.length);
                        },
                        child: AnimatedContainer(
                          key: _lineKeys.putIfAbsent(index, () => GlobalKey()),
                          duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? EmberColors.primaryAmber.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isActive
                            ? Border.all(color: EmberColors.primaryAmber.withValues(alpha: 0.35), width: 1.2)
                            : null,
                      ),
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive
                              ? EmberColors.primaryAmberHi
                              : EmberColors.textPrimary.withValues(alpha: 0.4),
                          fontSize: isActive ? 18 : 15,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          height: 1.5,
                          letterSpacing: isActive ? 0.3 : 0.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
                ),
              ),
              if (player.isolationMode == IsolationMode.instrumentsOnly)
                Positioned(
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: EmberColors.obsidianBase.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: EmberColors.primaryAmber.withValues(alpha: 0.6), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: EmberColors.primaryAmber.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_external_on_rounded, size: 13, color: EmberColors.primaryAmber),
                        SizedBox(width: 6),
                        Text(
                          'KARAOKE STAGE • SING ALONG',
                          style: TextStyle(
                            color: EmberColors.primaryAmber,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    if (plain.trim().isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: SelectableText(
          plain,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: EmberColors.textPrimary,
            fontSize: 16,
            height: 2.0,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.alignLeft, size: 36, color: EmberColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Instrumental / No lyrics available',
            style: TextStyle(color: EmberColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => player.retryFetchLyrics(),
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 14, color: EmberColors.primaryAmber),
            label: const Text('Search Again', style: TextStyle(color: EmberColors.primaryAmber)),
          ),
        ],
      ),
    );
  }
}
