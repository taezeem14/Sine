import 'dart:async';
import 'package:flutter/foundation.dart';
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

  bool _karaokeMode = true;
  bool _showTranslation = false;
  bool _showRomanization = false;
  bool _isTranslating = false;
  bool _isRomanizing = false;

  String? _currentSongId;
  List<LyricLine>? _enhancedLines;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final player = context.read<PlayerProvider>();
        if (player.currentSong != null && player.lyrics.syncedLyrics.isEmpty && !player.isLoadingLyrics) {
          player.loadLyricsForCurrentSong();
        }
      }
    });
  }

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

  Future<void> _handleToggleTranslation(List<LyricLine> sourceLines) async {
    setState(() => _showTranslation = !_showTranslation);
    if (_showTranslation && (_enhancedLines == null || !_enhancedLines!.any((l) => l.translation != null))) {
      setState(() => _isTranslating = true);
      try {
        final translated = await LyricsService.translateLyrics(sourceLines);
        if (mounted) {
          setState(() {
            _enhancedLines = translated;
            _isTranslating = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _handleToggleRomanization(List<LyricLine> sourceLines) async {
    setState(() => _showRomanization = !_showRomanization);
    if (_showRomanization && (_enhancedLines == null || !_enhancedLines!.any((l) => l.romanization != null))) {
      setState(() => _isRomanizing = true);
      try {
        final target = _enhancedLines ?? sourceLines;
        final romanized = await LyricsService.romanizeLyrics(target);
        if (mounted) {
          setState(() {
            _enhancedLines = romanized;
            _isRomanizing = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isRomanizing = false);
      }
    }
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
      _enhancedLines = null;
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
                color: EmberColors.primaryBlue,
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

    final rawSynced = player.syncedLyrics;
    final hasSynced = player.hasSyncedLyrics;
    final plain = player.plainLyrics;
    final synced = _enhancedLines ?? rawSynced;

    if (hasSynced && synced.isNotEmpty) {
      return ValueListenableBuilder<int>(
        valueListenable: player.activeLyricIndexNotifier,
        builder: (context, activeIdx, _) {
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
              final topPadding = (constraints.maxHeight * 0.42).clamp(40.0, 360.0);
              final bottomPadding = (constraints.maxHeight * 0.65).clamp(120.0, 750.0);

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
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? EmberColors.primaryBlue.withValues(alpha: 0.16)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: isActive
                                    ? Border.all(color: EmberColors.primaryBlue.withValues(alpha: 0.40), width: 1.2)
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Romanization badge
                                  if (_showRomanization && line.romanization != null && line.romanization!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        line.romanization!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isActive
                                              ? EmberColors.primaryBlue.withValues(alpha: 0.85)
                                              : EmberColors.textMuted.withValues(alpha: 0.6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),

                                  // Main lyric line (karaoke word sweep or standard text)
                                  if (_karaokeMode && line.isWordSynced && isActive)
                                    _KaraokeLineWidget(
                                      line: line,
                                      positionNotifier: player.positionNotifier,
                                    )
                                  else
                                    Text(
                                      line.text,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isActive
                                            ? EmberColors.primaryBlueHi
                                            : EmberColors.textPrimary.withValues(alpha: 0.4),
                                        fontSize: isActive ? 18 : 15,
                                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                        height: 1.5,
                                        letterSpacing: isActive ? 0.3 : 0.0,
                                      ),
                                    ),

                                  // Translation subtitle
                                  if (_showTranslation && line.translation != null && line.translation!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        line.translation!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isActive
                                              ? EmberColors.textSecondary
                                              : EmberColors.textMuted.withValues(alpha: 0.5),
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Floating Lyric Enhancement Pill Toolbar
                  Positioned(
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: EmberColors.surfaceContainerLow.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: EmberColors.outlineVariant.withValues(alpha: 0.7)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LyricsPill(
                            icon: Icons.mic_external_on_rounded,
                            label: 'Karaoke',
                            isActive: _karaokeMode,
                            onTap: () => setState(() => _karaokeMode = !_karaokeMode),
                          ),
                          const SizedBox(width: 6),
                          _LyricsPill(
                            icon: Icons.translate_rounded,
                            label: _isTranslating ? '...' : 'Translate',
                            isActive: _showTranslation,
                            onTap: () => _handleToggleTranslation(rawSynced),
                          ),
                          const SizedBox(width: 6),
                          _LyricsPill(
                            icon: Icons.spellcheck_rounded,
                            label: _isRomanizing ? '...' : 'Romaji',
                            isActive: _showRomanization,
                            onTap: () => _handleToggleRomanization(rawSynced),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 14, color: EmberColors.primaryBlue),
            label: const Text('Search Again', style: TextStyle(color: EmberColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}

class _LyricsPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LyricsPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? EmberColors.primaryBlue.withValues(alpha: 0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? EmberColors.primaryBlue : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? EmberColors.primaryBlue : EmberColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? EmberColors.primaryBlue : EmberColors.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KaraokeLineWidget extends StatelessWidget {
  final LyricLine line;
  final ValueListenable<Duration> positionNotifier;

  const _KaraokeLineWidget({
    required this.line,
    required this.positionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: line.words.map((word) {
        return _KaraokeWordWidget(
          word: word,
          positionNotifier: positionNotifier,
        );
      }).toList(),
    );
  }
}

class _KaraokeWordWidget extends StatelessWidget {
  final LyricWord word;
  final ValueListenable<Duration> positionNotifier;

  const _KaraokeWordWidget({
    required this.word,
    required this.positionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: positionNotifier,
      builder: (context, currentPos, _) {
        final startMs = word.timestamp.inMilliseconds;
        final durMs = word.duration.inMilliseconds;
        final curMs = currentPos.inMilliseconds;

        final leadMs = (durMs * 0.10).round();
        final effectiveStart = startMs - leadMs;
        final totalSpan = (durMs * 1.5).round();

        double progress = 0.0;
        if (curMs >= effectiveStart + totalSpan) {
          progress = 1.0;
        } else if (curMs > effectiveStart && totalSpan > 0) {
          progress = ((curMs - effectiveStart) / totalSpan).clamp(0.0, 1.0);
        }

        const activeStyle = TextStyle(
          color: EmberColors.primaryBlueHi,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.5,
          letterSpacing: 0.3,
        );

        const inactiveStyle = TextStyle(
          color: Color(0x66FFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.5,
          letterSpacing: 0.3,
        );

        if (progress <= 0.0) {
          return Text(word.text, style: inactiveStyle);
        }
        if (progress >= 1.0) {
          return Text(word.text, style: activeStyle);
        }

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                progress,
                (progress + 0.08).clamp(0.0, 1.0),
              ],
              colors: const [
                EmberColors.primaryBlueHi,
                Color(0x66FFFFFF),
              ],
            ).createShader(bounds);
          },
          child: Text(word.text, style: activeStyle),
        );
      },
    );
  }
}
