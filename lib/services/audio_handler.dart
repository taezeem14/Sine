import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'stream_resolver_service.dart';
import 'sponsorblock_service.dart';
import 'youtube_importer_service.dart';
import 'piped_service.dart';
import 'log_service.dart';


Future<AudioHandler> initAudioHandler() async {
  try {
    return await AudioService.init(
      builder: () => SineAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.taezeem.sine.channel.audio',
        androidNotificationChannelName: 'Sine Playback',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    ).timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        debugPrint('AudioService.init timeout -> using fallback local SineAudioHandler');
        return SineAudioHandler();
      },
    );
  } catch (e, st) {
    debugPrint('AudioService.init error: $e\n$st -> using fallback local SineAudioHandler');
    return SineAudioHandler();
  }
}

typedef EmberAudioHandler = SineAudioHandler;

class SineAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static const Map<String, List<double>> _spotifyPresetMap = {
    'dance': [4.5, 3.0, -1.0, 0.0, 3.0, 4.0],
    'deep': [5.5, 3.5, 1.5, -1.0, -2.5, -4.0],
    'electronic': [4.5, 2.5, 0.0, -1.0, 2.0, 4.5],
    'flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'hip-hop': [5.5, 4.0, 1.0, 1.0, 3.0, 3.0],
    'jazz': [3.0, 2.0, -1.0, 1.0, 2.0, 3.0],
    'latin': [4.0, 2.0, 0.0, 0.0, 3.0, 4.0],
    'loudness': [6.0, 3.0, -1.0, 0.0, 2.0, 5.0],
    'lounge': [2.0, 3.0, 1.0, -1.0, 0.0, -1.5],
    'piano': [1.0, 2.0, 3.0, 2.0, 3.0, 2.0],
    'pop': [3.0, 2.0, 2.0, 3.0, 2.0, 2.0],
    'r&b': [5.5, 4.0, 1.0, 2.0, 3.0, 2.0],
    'rock': [5.0, 3.0, -1.0, 1.0, 3.0, 4.0],
    'small speakers': [-3.0, 2.0, 4.0, 3.0, 3.0, 2.0],
    'spoken word': [-4.0, -1.0, 3.0, 4.0, 2.0, -2.0],
    'treble booster': [-1.0, 0.0, 0.0, 2.0, 4.0, 6.0],
    'treble reducer': [0.0, 0.0, 0.0, -1.0, -3.0, -5.0],
    'vocal booster': [-2.0, 0.0, 3.0, 4.0, 2.0, -1.0],
    'bass boost': [6.0, 4.0, 1.5, 0.0, 0.0, 0.0],
    'lo-fi': [-1.0, 2.0, 3.0, 1.0, -2.0, -4.0],
    'warm tape': [2.0, 1.0, 0.0, 0.0, -1.0, -2.0],
    'vocal air': [0.0, 0.5, 1.0, 2.0, 2.5, 2.0],
    'acoustic': [1.0, 0.5, 0.5, 0.5, 1.2, 1.0],
  };

  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();
  late final AudioPlayer _player;

  Song? _currentSong;
  int _playRequestId = 0;
  String? _activeStreamUrl;
  String? get activeStreamUrl => _activeStreamUrl;
  bool _isSwappingStream = false;
  bool get isSwappingStream => _isSwappingStream;
  int _swapRequestId = 0;
  AsyncCallback? _onSkipNext;
  AsyncCallback? _onSkipPrevious;
  AsyncCallback? _onCompleted;
  ValueChanged<Song>? _onPlaybackFailed;

  /// Guard to prevent ProcessingState.completed from firing _onCompleted
  /// multiple times or prematurely during loading/transitioning
  bool _completionHandled = true;
  bool _currentTrackActive = false;
  bool _wasPlayingBeforeInterrupt = false;
  double _preDuckVolume = 1.0;
  bool _isDucked = false;

  bool _eqEnabled = false;
  double _bassBoost = 0.0;
  String _currentPreset = 'Flat';
  final Map<int, double> _customBandGains = {};

  bool _clippingProtectionEnabled = true;
  double _masterVolume = 1.0;
  double _headroomAttenuation = 1.0;
  bool get clippingProtectionEnabled => _clippingProtectionEnabled;
  double get headroomAttenuation => _headroomAttenuation;

  List<SponsorSegment> _activeSponsorSegments = [];
  final Set<String> _skippedSegmentKeys = {};
  bool _isSkippingSponsor = false;

  /// Clean Android ExoPlayer streaming headers for GoogleVideo CDN
  /// Never send web CORS headers (Origin/Referer/Sec-Fetch-*) on Android streams,
  /// nor hardcoded Range headers (Range: bytes=0-) which conflict with ExoPlayer's internal chunker.
  static const Map<String, String> _youtubeHeaders = {
    'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 11)',
    'Accept': '*/*',
  };

  static const Map<String, String> _proxyHeaders = {
    'User-Agent': 'Sine/1.0 (Android ExoPlayer)',
    'Accept': '*/*',
  };

  Duration _lastKnownPosition = Duration.zero;
  bool _isReconnecting = false;
  int _consecutiveReconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  static String _resolveFilePath(String uriOrPath) {
    if (uriOrPath.startsWith('file://')) {
      try {
        return Uri.parse(uriOrPath).toFilePath(windows: Platform.isWindows);
      } catch (_) {
        var raw = Uri.decodeFull(uriOrPath.replaceFirst('file://', ''));
        if (Platform.isWindows && raw.startsWith('/') && raw.length > 2 && raw[2] == ':') {
          raw = raw.substring(1);
        }
        return raw;
      }
    }
    return uriOrPath;
  }


  SineAudioHandler() {
    _player = AudioPlayer(
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 15),
          maxBufferDuration: Duration(seconds: 45),
          bufferForPlaybackDuration: Duration(milliseconds: 500),
          bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1500),
          backBufferDuration: Duration(seconds: 10),
        ),
        darwinLoadControl: DarwinLoadControl(
          automaticallyWaitsToMinimizeStalling: false,
          preferredForwardBufferDuration: Duration(seconds: 2),
        ),
      ),
      audioPipeline: AudioPipeline(
        androidAudioEffects: [
          _equalizer,
          _loudnessEnhancer,
        ],
      ),
    );
    _initAudioStreams();
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.becomingNoisyEventStream.listen((_) {
        debugPrint('Audio output became noisy (headphones unplugged). Auto-pausing...');
        pause();
      });

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          _wasPlayingBeforeInterrupt = _player.playing;
          switch (event.type) {
            case AudioInterruptionType.duck:
              if (!_isDucked) {
                _preDuckVolume = _player.volume;
                _isDucked = true;
              }
              _player.setVolume((_preDuckVolume * 0.35).clamp(0.01, 1.0));
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_preDuckVolume);
              _isDucked = false;
              break;
            case AudioInterruptionType.pause:
              if (_wasPlayingBeforeInterrupt) play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('AudioSession initialization error: $e');
    }
  }

  AudioPlayer get player => _player;
  Song? get currentSong => _currentSong;
  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;

  void setNavigationCallbacks({
    AsyncCallback? onSkipNext,
    AsyncCallback? onSkipPrevious,
    AsyncCallback? onCompleted,
    ValueChanged<Song>? onPlaybackFailed,
  }) {
    _onSkipNext = onSkipNext;
    _onSkipPrevious = onSkipPrevious;
    _onCompleted = onCompleted;
    _onPlaybackFailed = onPlaybackFailed;
  }

  void _initAudioStreams() {
    // Broadcast playback state changes
    _player.playbackEventStream.listen(
      (PlaybackEvent event) {
        if (_isSwappingStream) {
          // Suppress intermediate idle/Duration.zero events from ExoPlayer during seamless swap
          return;
        }

        final playing = _player.playing;
        final currentProcessing = playbackState.value.processingState;
        final exProcessing = _player.processingState;

        AudioProcessingState mappedState;
        if (exProcessing == ProcessingState.idle && currentProcessing == AudioProcessingState.loading && _currentSong != null) {
          mappedState = AudioProcessingState.loading;
        } else {
          mappedState = const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[exProcessing] ?? AudioProcessingState.idle;
        }

        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              MediaControl.skipToPrevious,
              if (playing) MediaControl.pause else MediaControl.play,
              MediaControl.stop,
              MediaControl.skipToNext,
            ],
            systemActions: const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
            },
            androidCompactActionIndices: const [0, 1, 3],
            processingState: mappedState,
            playing: playing,
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
            speed: _player.speed,
            queueIndex: event.currentIndex,
          ),
        );
      },
      onError: (Object e, StackTrace st) {
        LogService.w('AudioHandler', 'playbackEventStream error: $e');
        if (_currentTrackActive && _currentSong != null && !_isReconnecting && !_isSwappingStream) {
          _handleMidStreamNetworkDrop();
        }
      },
    );

    // Synchronize mediaItem duration dynamically when ExoPlayer resolves stream duration
    _player.durationStream.listen(
      (dur) {
        if (dur != null && mediaItem.value != null && mediaItem.value!.duration != dur) {
          mediaItem.add(mediaItem.value!.copyWith(duration: dur));
        }
      },
      onError: (Object e, StackTrace st) {
        LogService.w('AudioHandler', 'durationStream error: $e');
      },
    );

    // Auto-advance when song finishes (guarded to fire only when track genuinely started and completed playback)
    _player.playerStateStream.listen(
      (state) {
        if (_isSwappingStream) {
          // CRITICAL: Block spurious completion/idle events during seamless stream swap
          return;
        }

        LogService.instance.recordExoState('${state.processingState.name} (playing: ${state.playing})');
        if (state.playing && state.processingState == ProcessingState.ready) {
          _currentTrackActive = true;
          _completionHandled = false;
          // Re-arm hardware equalizer, bass boost, and headroom limiter on the active AudioTrack
          _restorePlaybackParameters();
        }

        if (state.processingState == ProcessingState.completed && _currentTrackActive && !_completionHandled) {
          final total = _player.duration;
          final pos = _player.position;
          // Verify track genuinely played near completion (> 85% or within 4s of end)
          // Also handle short tracks (<= 5 seconds) cleanly
          final isNearEnd = total != null &&
              ((total.inSeconds <= 5 && total.inMilliseconds > 0 && (pos.inMilliseconds / total.inMilliseconds) >= 0.75) ||
               (total.inSeconds > 5 && (pos.inSeconds >= (total.inSeconds - 4) || (total.inMilliseconds > 0 && (pos.inMilliseconds / total.inMilliseconds) >= 0.85))));

          if (!isNearEnd) {
            debugPrint('[AudioHandler] Premature completion event detected (pos: ${pos.inSeconds}s, total: ${total?.inSeconds}s). Attempting auto-reconnect...');
            _handleMidStreamNetworkDrop();
            return;
          }

          _currentTrackActive = false;
          _completionHandled = true;
          _consecutiveReconnectAttempts = 0;
          debugPrint('[AudioHandler] Track "${_currentSong?.title}" completed playback cleanly. Invoking onCompleted.');
          _onCompleted?.call().catchError((e) {
            debugPrint('[AudioHandler] Error in _onCompleted callback: $e');
          });
        }
      },
      onError: (Object e, StackTrace st) {
        LogService.w('AudioHandler', 'playerStateStream error: $e');
        if (_currentTrackActive && _currentSong != null && !_isReconnecting) {
          _handleMidStreamNetworkDrop();
        }
      },
    );

    // SponsorBlock: auto-skip promotional/intro segments during YouTube playback
    _player.positionStream.listen(
      (pos) {
        _lastKnownPosition = pos;
        if (_activeSponsorSegments.isNotEmpty && !_isSkippingSponsor) {
          final currentSec = pos.inMilliseconds / 1000.0;
          final totalSec = (_player.duration?.inMilliseconds ?? 0) / 1000.0;
          for (final segment in _activeSponsorSegments) {
            if (segment.end <= segment.start) continue;

            final segmentKey = '${segment.start.toStringAsFixed(1)}_${segment.end.toStringAsFixed(1)}';
            if (_skippedSegmentKeys.contains(segmentKey)) continue;

            if (currentSec >= segment.start && currentSec < (segment.end - 0.2)) {
              _isSkippingSponsor = true;
              _skippedSegmentKeys.add(segmentKey);

              // Handle outro segment reaching track end
              if (totalSec > 10.0 && segment.end >= (totalSec - 1.5)) {
                debugPrint('SponsorBlock: Outro reached [${segment.start}s - ${segment.end}s]. Completing track cleanly.');
                _isSkippingSponsor = false;
                _currentTrackActive = false;
                _completionHandled = true;
                _lastKnownPosition = _player.duration ?? Duration(seconds: totalSec.toInt());
                _player.stop().catchError((_) {});
                _onCompleted?.call();
                return;
              }

              final targetMs = (segment.end * 1000).toInt() + 100;
              final maxDurationMs = _player.duration?.inMilliseconds ?? targetMs;
              final safeTarget = Duration(milliseconds: targetMs.clamp(0, maxDurationMs > 500 ? maxDurationMs - 200 : maxDurationMs));

              debugPrint('SponsorBlock: auto-skipping ${segment.category} [${segment.start}s - ${segment.end}s] to ${safeTarget.inMilliseconds}ms');

              _player.seek(safeTarget).catchError((e) {
                debugPrint('SponsorBlock seek error: $e');
              }).whenComplete(() {
                _isSkippingSponsor = false;
              });
              break;
            }
          }
        }
      },
      onError: (Object e, StackTrace st) {
        LogService.w('AudioHandler', 'positionStream error: $e');
      },
    );
  }

  /// NewPipe-style auto-reconnection on mid-stream network drop or socket severance
  Future<void> _handleMidStreamNetworkDrop() async {
    if (_isReconnecting) return;
    if (_currentSong == null) return;
    final targetSong = _currentSong!;
    final resumePos = _lastKnownPosition;

    if (_consecutiveReconnectAttempts >= _maxReconnectAttempts) {
      LogService.w('AudioHandler', 'Max reconnect attempts reached for "${targetSong.title}". Skipping to next track.');
      _isReconnecting = false;
      _currentTrackActive = false;
      _completionHandled = true;
      _consecutiveReconnectAttempts = 0;
      _onPlaybackFailed?.call(targetSong);
      return;
    }

    _isReconnecting = true;
    _consecutiveReconnectAttempts++;

    final backoffMs = _consecutiveReconnectAttempts * 750;
    LogService.stream('AudioHandler', 'Network interrupted. Reconnecting (attempt $_consecutiveReconnectAttempts/$_maxReconnectAttempts) in ${backoffMs}ms from ${resumePos.inSeconds}s...');

    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
        playing: true,
        updatePosition: resumePos,
      ),
    );

    await Future.delayed(Duration(milliseconds: backoffMs));
    if (_currentSong?.id != targetSong.id) {
      _isReconnecting = false;
      return;
    }

    // Invalidate stream cache so we obtain fresh stream URLs and tokens
    StreamResolverService.invalidateCache(targetSong.id);
    YouTubeImporterService.invalidateCache(targetSong.id);

    try {
      final candidates = await StreamResolverService.resolvePlayableStreamCandidates(targetSong);
      bool reconnected = false;

      for (int i = 0; i < candidates.length; i++) {
        if (_currentSong?.id != targetSong.id) return;
        final url = candidates[i];
        if (url.isEmpty || url.contains('youtube.com/watch') || url.contains('youtu.be/')) continue;
        final isYouTubeStream = url.contains('googlevideo.com') || url.contains('youtube.com');

        try {
          await _player.setUrl(
            url,
            headers: isYouTubeStream ? _youtubeHeaders : null,
            initialPosition: resumePos,
            preload: true,
          ).timeout(const Duration(seconds: 12));

          await _restorePlaybackParameters();
          await _player.play();
          reconnected = true;
          _isReconnecting = false;
          _consecutiveReconnectAttempts = 0;
          _currentTrackActive = true;
          _completionHandled = false;
          LogService.stream('AudioHandler', 'Successfully resumed "${targetSong.title}" from ${resumePos.inSeconds}s!');
          return;
        } catch (e) {
          try { await _player.stop(); } catch (_) {}
          if (e.toString().contains('403')) break; // Fast bypass to proxy
        }
      }

      // Try Piped / Invidious fallback if direct candidates failed
      if (!reconnected && _currentSong?.id == targetSong.id) {
        final videoId = targetSong.id.startsWith('yt_')
            ? targetSong.id.replaceFirst('yt_', '')
            : YouTubeImporterService.extractVideoId(targetSong.streamUrl);
        if (videoId != null && videoId.isNotEmpty) {
          final pipedUrl = await PipedService.getAudioStream(videoId);
          if (pipedUrl != null && pipedUrl.isNotEmpty && _currentSong?.id == targetSong.id) {
            await _player.setUrl(
              pipedUrl,
              headers: _proxyHeaders,
              initialPosition: resumePos,
              preload: true,
            ).timeout(const Duration(seconds: 7));

            await _player.play();
            await _restorePlaybackParameters();
            _isReconnecting = false;
            _consecutiveReconnectAttempts = 0;
            _currentTrackActive = true;
            _completionHandled = false;
            LogService.stream('AudioHandler', 'Successfully resumed "${targetSong.title}" via fallback proxy from ${resumePos.inSeconds}s!');
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioHandler] Reconnect error: $e');
    }

    _isReconnecting = false;
    if (_consecutiveReconnectAttempts < _maxReconnectAttempts) {
      _handleMidStreamNetworkDrop();
    } else {
      _currentTrackActive = false;
      _completionHandled = true;
      _consecutiveReconnectAttempts = 0;
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      _onPlaybackFailed?.call(targetSong);
    }
  }

  Future<void> playSong(Song song) async {
    final int currentRequestId = ++_playRequestId;

    // Reset flags immediately BEFORE touching ExoPlayer so state transitions during stop() cannot fire _onCompleted
    _currentTrackActive = false;
    _completionHandled = true;
    _currentSong = song;
    _activeSponsorSegments = [];
    _isSkippingSponsor = false;
    _skippedSegmentKeys.clear();

    // Flush ExoPlayer pipeline before loading new track to avoid stale playback events
    try {
      await _player.stop();
    } catch (_) {}

    if (currentRequestId != _playRequestId) return;

    // Query SponsorBlock skip segments concurrently
    Future.microtask(() {
      if (currentRequestId != _playRequestId) return;
      String? ytVideoId;
      if (song.id.startsWith('yt_')) {
        ytVideoId = song.id.substring(3);
      } else {
        ytVideoId = YouTubeImporterService.extractVideoId(song.streamUrl);
      }
      if (ytVideoId != null && ytVideoId.isNotEmpty) {
        SponsorBlockService.instance.getSkipSegments(ytVideoId).then((segments) {
          if (currentRequestId == _playRequestId) {
            _activeSponsorSegments = segments;
            if (segments.isNotEmpty) {
              debugPrint('SponsorBlock: Loaded ${segments.length} skip segments for YouTube video $ytVideoId');
            }
          }
        }).catchError((_) {});
      }
    });

    mediaItem.add(
      MediaItem(
        id: song.id,
        album: 'Sine',
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: song.artworkUrl.isNotEmpty ? Uri.tryParse(song.artworkUrl) : null,
      ),
    );

    // Immediately signal loading + playing state so UI and notification show active playing state
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        processingState: AudioProcessingState.loading,
        playing: true,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );

    try {
      final s = song.streamUrl;
      final isLocal = s.startsWith('/') || s.startsWith('file://') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(s);

      if (isLocal) {
        final localPath = _resolveFilePath(s);
        final file = File(localPath);
        if (await file.exists()) {
          _activeStreamUrl = localPath;
          await _player.setFilePath(localPath, initialPosition: Duration.zero, preload: true);
          if (currentRequestId != _playRequestId) {
            try { await _player.stop(); } catch (_) {}
            return;
          }
          await _restorePlaybackParameters();
          await _player.play();
          return;
        } else {
          // File does not exist locally anymore; fall through to online stream resolver
          LogService.w('AudioHandler', 'Local file not found at $localPath, falling through to online resolver');
        }
      }

      // Online pure YouTube stream resolution via NewPipe extractor
      LogService.instance.recordActiveTrack(song);

      // Resolve direct YouTube Opus / AAC streams
      final candidates = await StreamResolverService.resolvePlayableStreamCandidates(song);
      if (currentRequestId != _playRequestId) return; // Superseded by newer track selection
      if (candidates.isEmpty && s.isNotEmpty && !s.contains('youtube.com/watch') && !s.contains('youtu.be/')) {
        candidates.add(s);
      }
      LogService.instance.recordCandidates(candidates);

      bool started = false;
      for (int i = 0; i < candidates.length; i++) {
        if (currentRequestId != _playRequestId) return; // Superseded by newer track selection
        final url = candidates[i];
        if (url.isEmpty || url.contains('youtube.com/watch') || url.contains('youtu.be/')) continue;
        final isYouTubeStream = url.contains('googlevideo.com') || url.contains('youtube.com');

        try {
          LogService.stream('AudioHandler', 'Connecting to candidate #${i + 1} with Android ExoPlayer headers...');
          _activeStreamUrl = url;
          await _player.setUrl(
            url,
            headers: isYouTubeStream ? _youtubeHeaders : null,
            initialPosition: Duration.zero,
            preload: true,
          ).timeout(const Duration(seconds: 12));
          if (currentRequestId != _playRequestId) {
            try { await _player.stop(); } catch (_) {}
            return;
          }
          await _player.play();
          started = true;
          LogService.instance.recordPlaybackSuccess(song);
          debugPrint('Successfully playing "${song.title}" via candidate #${i + 1}');
          break;
        } catch (e) {
          try { await _player.stop(); } catch (_) {}
          LogService.w('AudioHandler', 'Candidate #${i + 1} connection failed: $e');

          // Resilient fallback: Retry candidate with clean ExoPlayer headers if custom headers triggered Source error / 403
          if (isYouTubeStream) {
            try {
              LogService.stream('AudioHandler', 'Retrying candidate #${i + 1} with clean headers...');
              _activeStreamUrl = url;
              await _player.setUrl(
                url,
                headers: null,
                initialPosition: Duration.zero,
                preload: true,
              ).timeout(const Duration(seconds: 8));
              if (currentRequestId != _playRequestId) {
                try { await _player.stop(); } catch (_) {}
                return;
              }
              await _player.play();
              started = true;
              LogService.instance.recordPlaybackSuccess(song);
              debugPrint('Successfully playing "${song.title}" via candidate #${i + 1} (clean headers)');
              break;
            } catch (retryErr) {
              try { await _player.stop(); } catch (_) {}
              LogService.w('AudioHandler', 'Candidate #${i + 1} retry failed: $retryErr');
            }
          }
        }
      }

      // Tier 1.5: If cached candidates failed/timed out, invalidate cache and perform one fresh direct resolution
      if (!started && currentRequestId == _playRequestId) {
        StreamResolverService.invalidateCache(song.id);
        YouTubeImporterService.invalidateCache(song.id);
        try {
          LogService.stream('AudioHandler', 'Pre-resolved streams exhausted. Attempting fresh direct resolution for "${song.title}"...');
          final freshCandidates = await StreamResolverService.resolvePlayableStreamCandidates(song);
          for (int i = 0; i < freshCandidates.length; i++) {
            if (currentRequestId != _playRequestId) return;
            final url = freshCandidates[i];
            if (url.isEmpty) continue;
            final isYouTubeStream = url.contains('googlevideo.com') || url.contains('youtube.com');
            try {
              LogService.stream('AudioHandler', 'Connecting to fresh candidate #${i + 1}...');
              _activeStreamUrl = url;
              await _player.setUrl(
                url,
                headers: isYouTubeStream ? _youtubeHeaders : null,
                initialPosition: Duration.zero,
                preload: true,
              ).timeout(const Duration(seconds: 12));
              if (currentRequestId != _playRequestId) {
                try { await _player.stop(); } catch (_) {}
                return;
              }
              await _player.play();
              started = true;
              LogService.instance.recordPlaybackSuccess(song);
              debugPrint('Successfully playing "${song.title}" via fresh candidate #${i + 1}');
              break;
            } catch (e) {
              try { await _player.stop(); } catch (_) {}
              LogService.w('AudioHandler', 'Fresh candidate #${i + 1} failed: $e');
              if (isYouTubeStream) {
                try {
                  LogService.stream('AudioHandler', 'Retrying fresh candidate #${i + 1} with clean headers...');
                  _activeStreamUrl = url;
                  await _player.setUrl(
                    url,
                    headers: null,
                    initialPosition: Duration.zero,
                    preload: true,
                  ).timeout(const Duration(seconds: 8));
                  if (currentRequestId != _playRequestId) {
                    try { await _player.stop(); } catch (_) {}
                    return;
                  }
                  await _player.play();
                  started = true;
                  LogService.instance.recordPlaybackSuccess(song);
                  debugPrint('Successfully playing "${song.title}" via fresh candidate #${i + 1} (clean headers)');
                  break;
                } catch (_) {}
              }
            }
          }
        } catch (e) {
          debugPrint('[AudioHandler] Fresh resolution error: $e');
        }
      }

      // Tier 2 Fallback: If all direct YouTube candidate streams fail, try Piped audio proxy
      if (!started && currentRequestId == _playRequestId) {
        final videoId = song.id.startsWith('yt_')
            ? song.id.replaceFirst('yt_', '')
            : YouTubeImporterService.extractVideoId(song.streamUrl);
        if (videoId != null && videoId.isNotEmpty) {
          try {
            LogService.stream('AudioHandler', 'Direct streams failed, attempting Piped proxy fallback for $videoId...');
            final pipedUrl = await PipedService.getAudioStream(videoId);
            if (pipedUrl != null && pipedUrl.isNotEmpty && currentRequestId == _playRequestId) {
              _activeStreamUrl = pipedUrl;
              await _player.setUrl(
                pipedUrl,
                headers: _proxyHeaders,
                initialPosition: Duration.zero,
                preload: true,
              ).timeout(const Duration(seconds: 12));
              if (currentRequestId != _playRequestId) {
                try { await _player.stop(); } catch (_) {}
                return;
              }
              await _player.play();
              started = true;
              LogService.instance.recordPlaybackSuccess(song);
              StreamResolverService.cacheStream(song.id, pipedUrl);
              debugPrint('Successfully playing "${song.title}" via Piped proxy fallback');
            }
          } catch (e) {
            try { await _player.stop(); } catch (_) {}
            LogService.w('AudioHandler', 'Piped proxy fallback error: $e');
            debugPrint('[AudioHandler] Piped proxy fallback error for "${song.title}": $e');
          }
        }
      }

      if (started) {
        await _restorePlaybackParameters();
      }

      if (!started) {
        if (currentRequestId != _playRequestId) return; // Superseded by newer track selection
        debugPrint('All stream candidates failed for "${song.title}". Halting playback gracefully.');
        LogService.instance.recordPlaybackFailure(song, 'All stream candidates exhausted (failed to connect or decode audio)');
        StreamResolverService.invalidateCache(song.id);
        YouTubeImporterService.invalidateCache(song.id);
        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              MediaControl.skipToPrevious,
              MediaControl.play,
              MediaControl.stop,
              MediaControl.skipToNext,
            ],
            processingState: AudioProcessingState.idle,
            playing: false,
          ),
        );
        _onPlaybackFailed?.call(song);
        return;
      }
    } catch (e, st) {
      if (currentRequestId != _playRequestId) return; // Superseded by newer track selection
      debugPrint('Playback error: $e');
      LogService.instance.recordPlaybackFailure(song, e, st);
      StreamResolverService.invalidateCache(song.id);
      YouTubeImporterService.invalidateCache(song.id);
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      _onPlaybackFailed?.call(song);
    }
  }

  // Equalizer & Audio Shaping Controls (Pure Hardware Multi-Band DSP, No Artificial Gain Blowout)
  Future<void> _updateAudioEffects() async {
    try {
      await _equalizer.setEnabled(_eqEnabled);
    } catch (e) {
      debugPrint('Error updating equalizer enabled state: $e');
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _updateAudioEffects();
    if (_eqEnabled) {
      await applyEqualizerPreset(_currentPreset);
    }
  }

  
  Future<void> setClippingProtection(bool enabled) async {
    _clippingProtectionEnabled = enabled;
    await _updateHeadroomGain();
  }

  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);
    _preDuckVolume = _masterVolume;
    await _updateHeadroomGain();
  }

  Future<void> _updateHeadroomGain() async {
    if (!_clippingProtectionEnabled) {
      _headroomAttenuation = 1.0;
      if (!_isDucked) {
        final vol = (_masterVolume * _normalizationGain * _sleepFadeMultiplier).clamp(0.0, 1.0);
        await _player.setVolume(vol).catchError((_) {});
      }
      return;
    }

    double maxBoost = 0.0;

    for (final gain in _customBandGains.values) {
      if (gain > maxBoost) maxBoost = gain;
    }

    if (_spotifyPresetMap.containsKey(_currentPreset.toLowerCase())) {
      final curve = _spotifyPresetMap[_currentPreset.toLowerCase()]!;
      for (final g in curve) {
        if (g > maxBoost) maxBoost = g;
      }
    }

    if (_bassBoost > 0) {
      maxBoost += (_bassBoost * 4.5);
    }

    if (maxBoost > 1.0) {
      final attenuationDb = (maxBoost * 0.45).clamp(0.0, 7.5);
      _headroomAttenuation = (1.0 / (1.0 + (attenuationDb * 0.12))).clamp(0.40, 1.0);
    } else {
      _headroomAttenuation = 1.0;
    }

    if (!_isDucked) {
      try {
        final targetVol = (_masterVolume * _headroomAttenuation * _normalizationGain * _sleepFadeMultiplier).clamp(0.0, 1.0);
        await _player.setVolume(targetVol).catchError((_) {});
      } catch (_) {}
    }
  }

  Future<void> setBassBoost(double gain) async {
    _bassBoost = gain.clamp(0.0, 1.0);
    try {
      if (_bassBoost > 0.0 && !_eqEnabled) {
        _eqEnabled = true;
        await _equalizer.setEnabled(true);
      }
      try {
        await _loudnessEnhancer.setEnabled(_bassBoost > 0.0);
        await _loudnessEnhancer.setTargetGain(_bassBoost * 0.35);
      } catch (_) {}
      if (_eqEnabled) {
        await _equalizer.setEnabled(true);
        await applyEqualizerPreset(_currentPreset);
      }
      await _updateHeadroomGain();
    } catch (e) {
      debugPrint('[AudioHandler] setBassBoost error: $e');
    }
  }

  Future<void> setBandGain(int bandIndex, double gain) async {
    _customBandGains[bandIndex] = gain;
    try {
      final params = await _equalizer.parameters;
      if (bandIndex >= 0 && bandIndex < params.bands.length) {
        final clamped = gain.clamp(params.minDecibels, params.maxDecibels);
        await params.bands[bandIndex].setGain(clamped);
      }
      await _updateHeadroomGain();
    } catch (_) {}
  }

  Future<void> applyEqualizerPreset(String preset) async {
    _currentPreset = preset;
    if (!_eqEnabled) {
      try {
        await _equalizer.setEnabled(false);
      } catch (_) {}
      return;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _equalizer.setEnabled(true);
        final params = await _equalizer.parameters;
        final bands = params.bands;
        final n = bands.length;
        if (n == 0) {
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          return;
        }

        final minDb = params.minDecibels;
        final maxDb = params.maxDecibels;
        double clampGain(double g) => g.clamp(minDb, maxDb);

        // Deep, punchy, rich Hearth Bass boost (pure hardware low-shelf harmonics)
        final bassAdd = _bassBoost * 9.0;
        final lowMidAdd = _bassBoost * 4.5;

        final lowerPreset = preset.toLowerCase().trim();
        if (_spotifyPresetMap.containsKey(lowerPreset)) {
          final targetList = _spotifyPresetMap[lowerPreset]!;
          for (int i = 0; i < n; i++) {
            final targetIdx = ((i / (n > 1 ? (n - 1) : 1)) * (targetList.length - 1)).round().clamp(0, targetList.length - 1);
            var g = targetList[targetIdx];
            if (i == 0) {
              g += bassAdd;
            } else if (i == 1) {
              g += lowMidAdd;
            }
            final finalGain = clampGain(g);
            _customBandGains[i] = finalGain;
            await bands[i].setGain(finalGain);
          }
          return;
        }

        switch (preset) {
          case 'Custom':
            for (int i = 0; i < n; i++) {
              final targetIdx = ((i / (n > 1 ? (n - 1) : 1)) * 5).round().clamp(0, 5);
              final baseGain = _customBandGains[targetIdx] ?? 0.0;
              if (i == 0) {
                await bands[i].setGain(clampGain(baseGain + bassAdd));
              } else if (i == 1) {
                await bands[i].setGain(clampGain(baseGain + lowMidAdd));
              } else {
                await bands[i].setGain(clampGain(baseGain));
              }
            }
            break;
          default:
            for (int i = 0; i < n; i++) {
              if (i == 0) {
                await bands[i].setGain(clampGain(bassAdd));
              } else if (i == 1) {
                await bands[i].setGain(clampGain(lowMidAdd));
              } else {
                await bands[i].setGain(clampGain(0.0));
              }
            }
            break;
        }
        return;
      } catch (e) {
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 100));
        } else {
          debugPrint('[AudioHandler] applyEqualizerPreset error: $e');
        }
      }
    }
  }


  /// Legacy stub: removed DSP filter hack
  Future<void> applyIsolationFilter({required bool vocalsOnly}) async {
    // No-op: Removed DSP filter manipulation
  }

  /// Seamlessly swaps the active audio stream to [newStreamUrl] (e.g. between Original,
  /// Karaoke / Instruments, and Vocals / Acapella) while preserving exact playback position,
  /// playback speed, volume, and repeat state, without stopping playback or resetting to 0:00.
  Future<bool> swapAudioStream(
    String newStreamUrl, {
    required Duration currentPosition,
    required bool playImmediately,
    bool isLocal = false,
    List<String> fallbackUrls = const [],
    String? originalStreamUrl,
  }) async {
    final candidateUrls = <String>[newStreamUrl, ...fallbackUrls]
        .where((u) => u.trim().isNotEmpty)
        .toList();

    if (candidateUrls.isEmpty) {
      LogService.w('AudioHandler', 'swapAudioStream: received empty newStreamUrl and fallbacks');
      return false;
    }

    // If already playing this exact stream, maintain continuity
    if (_activeStreamUrl == candidateUrls.first) {
      if (playImmediately && !_player.playing) {
        await _player.play();
      }
      return true;
    }

    final int currentRequestId = ++_swapRequestId;
    _playRequestId++; // Invalidate previous playSong attempts

    final bool wasPlaying = _player.playing;
    final bool shouldPlay = playImmediately || wasPlaying;
    final Duration targetPosition = currentPosition;
    final String previousActiveStreamUrl = _activeStreamUrl ?? '';

    // If seeking mid-stream (targetPosition > 0), prioritize progressive MP4 streams
    // over WebM streams (which lack front-loaded Cues and crash ExoPlayer with Source error)
    if (targetPosition > Duration.zero) {
      candidateUrls.sort((a, b) {
        final aIsMp4 = a.contains('mime=audio%2Fmp4') ||
            a.contains('itag=140') ||
            a.contains('itag=18') ||
            a.endsWith('.mp4');
        final bIsMp4 = b.contains('mime=audio%2Fmp4') ||
            b.contains('itag=140') ||
            b.contains('itag=18') ||
            b.endsWith('.mp4');
        if (aIsMp4 && !bIsMp4) return -1;
        if (!aIsMp4 && bIsMp4) return 1;
        return 0;
      });
    }

    LogService.stream(
      'AudioHandler',
      'Seamlessly swapping audio stream to "${candidateUrls.first}" at ${targetPosition.inSeconds}s (playImmediately: $shouldPlay, candidates: ${candidateUrls.length})...',
    );

    // 1. Arm completion and auto-advance guards
    _isSwappingStream = true;
    _currentTrackActive = false;
    _completionHandled = true;

    // 2. Broadcast buffering state so notification controls stay alive at target position
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (shouldPlay) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: AudioProcessingState.buffering,
        playing: shouldPlay,
        updatePosition: targetPosition,
        bufferedPosition: targetPosition,
        speed: _activeSpeed,
      ),
    );

    String? successfulUrl;
    dynamic lastError;
    StackTrace? lastStackTrace;

    for (final candidateUrl in candidateUrls) {
      if (currentRequestId != _swapRequestId) {
        debugPrint('[AudioHandler] swapAudioStream #$currentRequestId superseded by #$_swapRequestId');
        _isSwappingStream = false;
        return false;
      }

      try {
        final isLocalFile = isLocal ||
            candidateUrl.startsWith('/') ||
            candidateUrl.startsWith('file://') ||
            RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(candidateUrl);

        final isYouTubeStream = candidateUrl.contains('googlevideo.com') ||
            candidateUrl.contains('youtube.com');
        final headers = isYouTubeStream ? _youtubeHeaders : _proxyHeaders;

        // 3. Switch audio source directly without calling _player.stop()
        if (isLocalFile) {
          final localPath = _resolveFilePath(candidateUrl);
          await _player.setFilePath(
            localPath,
            initialPosition: targetPosition,
            preload: true,
          ).timeout(const Duration(seconds: 10));
        } else {
          await _player.setUrl(
            candidateUrl,
            headers: headers,
            initialPosition: targetPosition,
            preload: true,
          ).timeout(const Duration(seconds: 10));
        }

        successfulUrl = candidateUrl;
        break; // Successfully loaded candidate!
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
        LogService.w('AudioHandler', 'Candidate stream failed in swapAudioStream: $e');
      }
    }

    if (successfulUrl != null) {
      // Check if superseded by rapid subsequent toggles
      if (currentRequestId != _swapRequestId) {
        debugPrint('[AudioHandler] swapAudioStream #$currentRequestId superseded by #$_swapRequestId');
        return false;
      }

      // 4. Restore playback parameters (speed, repeat mode, DSP equalizer)
      await _restorePlaybackParameters();

      // 5. Resume playback if requested or if previously playing
      if (shouldPlay) {
        await _player.play();
      }

      // 6. Update tracking state & disarm guards
      _activeStreamUrl = successfulUrl;
      _lastKnownPosition = targetPosition;
      _currentTrackActive = true;
      _completionHandled = false;
      _consecutiveReconnectAttempts = 0;
      _isSwappingStream = false;

      LogService.stream(
        'AudioHandler',
        'Successfully swapped audio stream! Playing at ${targetPosition.inSeconds}s (speed: ${_activeSpeed}x)',
      );
      return true;
    }

    // AUTO-RECOVERY: All candidates failed! Restore previous active stream immediately so ExoPlayer doesn't crash or stay silent
    if (currentRequestId != _swapRequestId) {
      return false;
    }
    LogService.w('AudioHandler', 'swapAudioStream all candidates failed: $lastError\n$lastStackTrace');

    final recoveryUrl = (originalStreamUrl != null && originalStreamUrl.isNotEmpty)
        ? originalStreamUrl
        : (previousActiveStreamUrl.isNotEmpty ? previousActiveStreamUrl : null);

    if (recoveryUrl != null) {
      try {
        LogService.stream('AudioHandler', 'Auto-recovering previous audio stream: $recoveryUrl');
        final isLocalRec = recoveryUrl.startsWith('/') ||
            recoveryUrl.startsWith('file://') ||
            RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(recoveryUrl);
        if (isLocalRec) {
          await _player.setFilePath(
            _resolveFilePath(recoveryUrl),
            initialPosition: targetPosition,
            preload: true,
          ).timeout(const Duration(seconds: 8));
        } else {
          final recHeaders = (recoveryUrl.contains('googlevideo.com') || recoveryUrl.contains('youtube.com'))
              ? _youtubeHeaders
              : _proxyHeaders;
          await _player.setUrl(
            recoveryUrl,
            headers: recHeaders,
            initialPosition: targetPosition,
            preload: true,
          ).timeout(const Duration(seconds: 8));
        }
        await _restorePlaybackParameters();
        if (shouldPlay) {
          await _player.play();
        }
        _activeStreamUrl = recoveryUrl;
        _currentTrackActive = true;
      } catch (recErr) {
        LogService.w('AudioHandler', 'Stream auto-recovery failed: $recErr');
      }
    }

    _isSwappingStream = false;
    _completionHandled = false;
    return false;
  }

  @override
  Future<void> skipToNext() async {
    if (_onSkipNext != null) {
      await _onSkipNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_onSkipPrevious != null) {
      await _onSkipPrevious!();
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
    // Maintain hardware DSP equalizer, bass boost, and headroom limiter after pause/earbud resume
    _restorePlaybackParameters();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    final targetSec = position.inMilliseconds / 1000.0;
    _skippedSegmentKeys.removeWhere((key) {
      final parts = key.split('_');
      final end = double.tryParse(parts.length > 1 ? parts[1] : parts[0]) ?? 0.0;
      return end > targetSec;
    });
    await _player.seek(position);
  }

  double _activeSpeed = 1.0;
  double _activePitch = 1.0;
  double _normalizationGain = 1.0;
  double _sleepFadeMultiplier = 1.0;

  double get activePitch => _activePitch;
  double get normalizationGain => _normalizationGain;
  double get sleepFadeMultiplier => _sleepFadeMultiplier;
  String _activeRepeatMode = 'off';

  @override
  Future<void> setSpeed(double speed) async {
    _activeSpeed = speed;
    await _player.setSpeed(speed);
  }

  Future<void> setPitch(double pitch) async {
    _activePitch = pitch.clamp(0.5, 2.0);
    try {
      await _player.setPitch(_activePitch).catchError((_) {});
    } catch (_) {}
  }

  Future<void> setNormalizationGain(double gain) async {
    _normalizationGain = gain.clamp(0.2, 1.0);
    await _updateHeadroomGain();
  }

  Future<void> setSleepFadeMultiplier(double multiplier) async {
    _sleepFadeMultiplier = multiplier.clamp(0.0, 1.0);
    await _updateHeadroomGain();
  }

  Future<void> resetSleepFade() async {
    _sleepFadeMultiplier = 1.0;
    await _updateHeadroomGain();
  }

  Future<void> updateSongMediaItem(Song song) async {
    final current = mediaItem.value;
    if (current != null && current.id == song.id) {
      mediaItem.add(
        current.copyWith(
          title: song.title,
          artist: song.artist,
          artUri: song.artworkUrl.isNotEmpty ? Uri.tryParse(song.artworkUrl) : current.artUri,
        ),
      );
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await setPlayerRepeatMode('off');
        break;
      case AudioServiceRepeatMode.one:
        await setPlayerRepeatMode('one');
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await setPlayerRepeatMode('all');
        break;
    }
  }

  Future<void> setPlayerRepeatMode(String mode) async {
    _activeRepeatMode = mode;
    if (mode == 'one') {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }
    final serviceMode = mode == 'one'
        ? AudioServiceRepeatMode.one
        : (mode == 'all' ? AudioServiceRepeatMode.all : AudioServiceRepeatMode.none);
    playbackState.add(playbackState.value.copyWith(repeatMode: serviceMode));
  }

  /// Re-applies active speed, loop, and DSP audio effects when a new audio source prepares
  Future<void> _restorePlaybackParameters() async {
    try {
      if (_activeSpeed != 1.0) {
        await _player.setSpeed(_activeSpeed).catchError((_) {});
      }
      if (_activePitch != 1.0) {
        await _player.setPitch(_activePitch).catchError((_) {});
      }
    } catch (_) {}
    try {
      if (_activeRepeatMode == 'one') {
        await _player.setLoopMode(LoopMode.one).catchError((_) {});
      } else {
        await _player.setLoopMode(LoopMode.off).catchError((_) {});
      }
    } catch (_) {}
    try {
      if (_eqEnabled && _currentPreset != 'Vocals Only' && _currentPreset != 'Instruments Only') {
        await applyEqualizerPreset(_currentPreset).catchError((_) {});
      } else if (!_eqEnabled) {
        await _equalizer.setEnabled(false).catchError((_) {});
      }
    } catch (_) {}
    try {
      if (_bassBoost > 0.0) {
        await _loudnessEnhancer.setEnabled(true).catchError((_) {});
        await _loudnessEnhancer.setTargetGain(_bassBoost * 0.35).catchError((_) {});
      }
    } catch (_) {}
    try {
      await _updateHeadroomGain().catchError((_) {});
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _currentSong = null;
    _activeStreamUrl = null;
    _isSwappingStream = false;
    _currentTrackActive = false;
    _completionHandled = true;
    _isSkippingSponsor = false;
    _activeSponsorSegments = [];
    _skippedSegmentKeys.clear();
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await _player.stop();
    await super.stop();
  }

}
