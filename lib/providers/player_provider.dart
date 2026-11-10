import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/audio_handler.dart';
import '../services/catalog_service.dart';
import '../services/download_service.dart';
import '../services/lyrics_service.dart';
import '../services/storage_service.dart';
import '../services/youtube_importer_service.dart';
import '../services/stream_resolver_service.dart';
import '../services/stem_service.dart';
import '../services/smart_radio_service.dart';
import '../services/widget_service.dart';
import '../services/performance_service.dart';
import '../services/metadata_correction_service.dart';


class SavedPlaybackSession {
  final Song song;
  final int positionMs;
  final List<Song> queue;
  final int currentIndex;
  final DateTime savedAt;

  const SavedPlaybackSession({
    required this.song,
    required this.positionMs,
    required this.queue,
    required this.currentIndex,
    required this.savedAt,
  });

  factory SavedPlaybackSession.fromMap(Map<String, dynamic> map) {
    final song = Song.fromMap(Map<String, dynamic>.from(map['song'] as Map));
    final qList = (map['queue'] as List? ?? [])
        .map((m) => Song.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    return SavedPlaybackSession(
      song: song,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      queue: qList,
      currentIndex: (map['currentIndex'] as num?)?.toInt() ?? 0,
      savedAt: DateTime.tryParse(map['savedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

enum IsolationMode {
  none,
  vocalsOnly,
  instrumentsOnly,
}

class PlayerProvider extends ChangeNotifier {
  final SineAudioHandler _audioHandler;
  final StorageService _storageService;

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  bool _isShuffle = false;
  List<Song> _unshuffledQueue = [];
  String _repeatMode = 'off'; // 'off', 'all', 'one'
  String _activeTab = 'queue'; // 'queue', 'playlists', 'favorites', 'downloads', 'history'
  String _activeCategory = 'trending';
  String _playingFrom = 'Today\'s Top Hits';

  // Infinite YouTube Mix state (NewPipe-style continuation)
  bool _isMixActive = false;
  bool get isMixActive => _isMixActive;
  String? _activeMixPlaylistId;
  String? _mixContinuationToken;
  String? _mixLastVideoId;
  String? _mixLastParams;
  bool _isLoadingMoreMixTracks = false;
  final Set<String> _mixSeenVideoIds = {};

  String _searchQuery = '';
  List<Song> _searchResults = [];
  List<Song> _favorites = [];
  List<Song> _history = [];
  List<Playlist> _playlists = [];
  List<Song> _downloads = [];
  final List<Song> _recommendations = [];
  List<Song> _categoryTracks = [];
  bool _isAutoplayEnabled = false;
  // Spotify-Grade Smart Radio & Autoplay state
  bool _isRadioActive = false;
  bool get isRadioActive => _isRadioActive;
  Song? _radioSeedSong;
  Song? get radioSeedSong => _radioSeedSong;
  bool _radioIsArtist = false;
  bool get radioIsArtist => _radioIsArtist;
  String? _radioContinuationToken;
  String? _radioLastVideoId;
  String? _radioLastParams;
  final Set<String> _radioSeenVideoIds = {};
  bool _isLoadingMoreRadioTracks = false;

  bool _isLoadingRecommendations = false;
  bool get isLoadingRecommendations => _isLoadingRecommendations;


  /// Counts consecutive stream resolution failures to break infinite skip loops
  int _consecutiveStreamFailures = 0;
  static const int _maxConsecutiveFailures = 3;

  // Pure YouTube NewPipe Library state
  List<Song> _youtubeTracks = [];
  bool _isLoadingYouTube = false;
  String _searchEngine = 'YouTube';

  // Equalizer state
  String _eqPreset = 'Flat';
  bool _eqEnabled = false;
  double _bassBoost = 0.0;
  Map<int, double> _bandGains = {};
  IsolationMode _isolationMode = IsolationMode.none;
  // Studio Stem Isolation & Seamless Stream Swapping
  bool _isLoadingStem = false;
  bool get isLoadingStem => _isLoadingStem;
  bool _isStudioStemActive = false;
  bool get isStudioStemActive => _isStudioStemActive;
  String? _stemStatusBadgeText;
  String? get stemStatusBadgeText => _stemStatusBadgeText;
  final Map<String, String> _originalStreamCache = {};

  // Core Features: Settings, Headroom & Session Recovery

  bool _clippingProtection = true;
  bool get clippingProtectionEnabled => _clippingProtection;

  String _playbackRecoveryMode = 'prompt'; // 'prompt', 'always', 'off'
  String get playbackRecoveryMode => _playbackRecoveryMode;

  SavedPlaybackSession? _recoverableSession;
  SavedPlaybackSession? get recoverableSession => _recoverableSession;

  String _stemEnginePreference = 'auto'; // 'auto', 'bsRoformer', 'demucs', 'youtube', 'dsp'
  String get stemEnginePreference => _stemEnginePreference;

  bool _performanceHudEnabled = false;
  bool get performanceHudEnabled => _performanceHudEnabled;

  StemPipelineDiagnostic? get lastStemDiagnostic => StemService.instance.lastDiagnostic;




  LyricsResult _lyrics = LyricsResult.empty;
  bool _isLoadingLyrics = false;
  bool _isLoadingStream = false;
  int _playSessionId = 0;
  Song? _lastFailedSong;
  Song? get lastFailedSong => _lastFailedSong;
  final ValueNotifier<Song?> playbackErrorNotifier = ValueNotifier<Song?>(null);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<int> activeLyricIndexNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<int> sleepSecondsNotifier = ValueNotifier<int>(0);

  Timer? _sleepTimer;
  Timer? _bandSaveTimer;
  int _sleepSecondsRemaining = 0;
  bool _sleepAtTrackEnd = false;
  int _crossfadeSeconds = 0;
  int _pitchSemitones = 0;
  bool _volumeNormalizationEnabled = true;

  int get pitchSemitones => _pitchSemitones;
  bool get volumeNormalizationEnabled => _volumeNormalizationEnabled;
  bool _gaplessPlayback = true;
  Timer? _searchDebounce;
  bool _isSearching = false;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  bool _isDisposed = false;
  bool _isScrubbing = false;
  bool get isScrubbing => _isScrubbing;
  void setScrubbing(bool scrubbing) {
    _isScrubbing = scrubbing;
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  PlayerProvider(this._audioHandler, this._storageService) {
    _init();
  }

  // Getters
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  Song? get currentSong => _queue.isNotEmpty && _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  bool get isPlaying => _isPlaying;
  bool get isLoadingStream => _isLoadingStream;
  Duration get position => _position;
  Duration get duration => _duration;
  double get speed => _speed;
  bool get isShuffle => _isShuffle;
  bool get shuffle => _isShuffle;
  String get repeatMode => _repeatMode;
  String get activeTab => _activeTab;
  String get activeCategory => _activeCategory;
  String? get activeMood => _activeCategory;
  String get playingFrom => _playingFrom;
  void setPlayingFrom(String source) {
    _playingFrom = source;
    notifyListeners();
  }
  String get searchQuery => _searchQuery;
  List<Song> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  List<Song> get favorites => _favorites;
  List<Song> get history => _history;
  List<Playlist> get playlists => _playlists;
  List<Song> get downloads => _downloads;
  List<Song> get recommendations => _recommendations;
  List<Song> get categoryTracks => _categoryTracks;
  bool get isAutoplayEnabled => _isAutoplayEnabled;
  int get sleepSecondsRemaining => _sleepSecondsRemaining;
  bool get sleepAtTrackEnd => _sleepAtTrackEnd;
  int get crossfadeSeconds => _crossfadeSeconds;
  bool get gaplessPlayback => _gaplessPlayback;

  List<Song> get youtubeTracks => _youtubeTracks;
  bool get isLoadingYouTube => _isLoadingYouTube;
  String get searchEngine => _searchEngine;

  void setSearchEngine(String engine) {
    _searchEngine = engine;
    if (_searchQuery.trim().isNotEmpty) {
      search(_searchQuery);
    } else {
      notifyListeners();
    }
  }

  String get eqPreset => _eqPreset;
  bool get eqEnabled => _eqEnabled;
  double get bassBoost => _bassBoost;
  Map<int, double> get bandGains => _bandGains;
  IsolationMode get isolationMode => _isolationMode;
  SineAudioHandler get audioHandler => _audioHandler;

  LyricsResult get lyrics => _lyrics;
  List<LyricLine> get syncedLyrics => _lyrics.syncedLyrics;
  String get plainLyrics => _lyrics.plainLyrics;
  bool get hasSyncedLyrics => _lyrics.hasSynced;
  bool get isLoadingLyrics => _isLoadingLyrics;

  int _findLyricIndex(Duration pos) {
    if (_lyrics.syncedLyrics.isEmpty) return -1;
    for (int i = _lyrics.syncedLyrics.length - 1; i >= 0; i--) {
      if (pos >= _lyrics.syncedLyrics[i].timestamp) {
        return i;
      }
    }
    return -1;
  }

  int get currentLyricIndex {
    if (_lyrics.syncedLyrics.isEmpty) return -1;
    final cached = activeLyricIndexNotifier.value;
    if (cached >= 0 && cached < _lyrics.syncedLyrics.length) {
      return cached;
    }
    return _findLyricIndex(_position);
  }

  void _init() {
    _favorites = _storageService.loadFavorites();
    _history = _storageService.loadHistory();
    _playlists = _storageService.loadPlaylists();
    _downloads = _storageService.loadDownloads();
    _speed = _storageService.loadPlaybackSpeed();
    _repeatMode = _storageService.loadRepeatMode();
    _isShuffle = _storageService.loadShuffle();
    _eqPreset = _storageService.loadEqualizerPreset();
    _eqEnabled = _storageService.loadEqualizerEnabled();
    _bassBoost = _storageService.loadBassBoost();
    _bandGains = _storageService.loadBandGains();
    _isAutoplayEnabled = _storageService.loadAutoplayEnabled();
    _crossfadeSeconds = _storageService.loadCrossfadeSeconds();
    _audioHandler.setCrossfadeSeconds(_crossfadeSeconds);
    _gaplessPlayback = _storageService.loadGaplessPlayback();
    _audioHandler.setGaplessPlayback(_gaplessPlayback);

    _clippingProtection = _storageService.loadClippingProtection();
    _audioHandler.setClippingProtection(_clippingProtection);

    _playbackRecoveryMode = _storageService.loadPlaybackRecoveryMode();

    _stemEnginePreference = _storageService.loadStemEnginePreference();
    StemService.instance.setEnginePreference(_stemEnginePreference);

    _performanceHudEnabled = _storageService.loadPerformanceHudEnabled();
    PerformanceService.instance.setHudVisible(_performanceHudEnabled);
    if (_performanceHudEnabled) {
      PerformanceService.instance.start();
    }

    // Check for recoverable previous playback session
    final savedSessionMap = _storageService.loadSavedSession();
    if (savedSessionMap != null && _playbackRecoveryMode != 'off') {
      try {
        final session = SavedPlaybackSession.fromMap(savedSessionMap);
        if (_playbackRecoveryMode == 'always') {
          _queue = List.from(session.queue);
          _currentIndex = session.currentIndex.clamp(0, _queue.isNotEmpty ? _queue.length - 1 : 0);
          _unshuffledQueue = List.from(_queue);
        } else {
          _recoverableSession = session;
        }
      } catch (_) {}
    }


    // Re-sync downloads on completion or cold start
    DownloadService.progressStream.listen((p) {
      if (p.isCompleted) {
        _downloads = _storageService.loadDownloads();
        notifyListeners();
      }
    });
    DownloadService.syncDownloadsFromDisk(_storageService).then((_) {
      _downloads = _storageService.loadDownloads();
      notifyListeners();
    });

    // Wire up hardware / notification / completion navigation callbacks
    _audioHandler.setNavigationCallbacks(
      onSkipNext: () => skipNext(),
      onSkipPrevious: () => skipPrevious(),
      onCompleted: () => _handleSongCompleted(),
      onPlaybackFailed: (failedSong) {
        debugPrint('[PlayerProvider] Stream failed for: ${failedSong.title}');
        _consecutiveStreamFailures++;
        _lastFailedSong = failedSong;
        playbackErrorNotifier.value = null;
        playbackErrorNotifier.value = failedSong;
        StreamResolverService.invalidateCache(failedSong.id);
        YouTubeImporterService.invalidateCache(failedSong.id);

        if (_consecutiveStreamFailures >= _maxConsecutiveFailures) {
          debugPrint('[PlayerProvider] Exceeded max consecutive stream failures ($_maxConsecutiveFailures). Halting queue auto-advance.');
          _isPlaying = false;
          _isLoadingStream = false;
          notifyListeners();
          return;
        }

        // Resilient auto-advance: if in a playlist or queue, keep playing next track instead of cutting off!
        if (_queue.length > 1) {
          debugPrint('[PlayerProvider] Auto-advancing to next track after failure (failure count: $_consecutiveStreamFailures)...');
          skipNext(isAuto: true);
        } else {
          _isPlaying = false;
          _isLoadingStream = false;
          notifyListeners();
        }
      },
    );

    // Never persist isolation mode across app restarts
    if (_eqPreset == 'Vocals Only' || _eqPreset == 'Instruments Only') {
      _eqPreset = 'Flat';
      _storageService.saveEqualizerPreset('Flat');
    }
    _isolationMode = IsolationMode.none;
    _isStudioStemActive = false;
    _stemStatusBadgeText = null;
    _isLoadingStem = false;

    // Apply saved EQ preset & settings (custom band gains first so preset sync reads restored curve)
    if (_bandGains.isNotEmpty) {
      _audioHandler.setCustomBandGains(_bandGains);
    }
    _audioHandler.setEqualizerEnabled(_eqEnabled);
    if (_bassBoost > 0.0) {
      _audioHandler.setBassBoost(_bassBoost);
    }
    _audioHandler.applyEqualizerPreset(_eqPreset);
    _audioHandler.setSpeed(_speed);
    _audioHandler.setPlayerRepeatMode(_repeatMode);

    // Ensure all restored lists are completely free of legacy mock/placeholder tracks
    _favorites = _favorites.where((s) => !Song.isPlaceholder(s)).toList();
    _history = _history.where((s) => !Song.isPlaceholder(s)).toList();
    _downloads = _downloads.where((s) => !Song.isPlaceholder(s)).toList();
    _playlists = _playlists
        .map((p) => p.copyWith(songs: p.songs.where((s) => !Song.isPlaceholder(s)).toList()))
        .toList();

    // On fresh app launch, start with an empty queue and unselected player so the player does not show the previous session's track
    _queue = [];
    _currentIndex = -1;

    // Load initial trending discovery tracks
    _loadInitialDiscoveryTracks();

    // Listen to player streams: positionNotifier delivers 120 FPS buttery updates
    // directly to scrubbers and lyric tickers without thrashing the main widget tree
    _posSub = _audioHandler.player.positionStream.listen((pos) {
      if (_isScrubbing) return;
      _position = pos;
      positionNotifier.value = pos;
      // Session saved on explicit pause or track change to avoid 120fps disk thrash
      final lyricIdx = _findLyricIndex(pos);
      if (lyricIdx != activeLyricIndexNotifier.value) {
        activeLyricIndexNotifier.value = lyricIdx;
      }
    });

    _durSub = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null && (_duration - dur).abs() > const Duration(milliseconds: 500)) {
        _duration = dur;
        notifyListeners();
      }
    });

    _stateSub = _audioHandler.player.playerStateStream.listen((state) {
      final playing = state.playing;
      if (playing && state.processingState == ProcessingState.ready) {
        // Stream is actively playing and loaded — reset failure counter
        _consecutiveStreamFailures = 0;
        _isLoadingStream = false;
        // NewPipe pattern: Once active track is playing cleanly,
        // prefetch ONLY the immediate next track (WINDOW_SIZE = 1) in the background
        _prefetchNextTrack();
      }
      if (state.processingState == ProcessingState.idle) {
        _isLoadingStream = false;
      }
      if (_isPlaying != playing) {
        _isPlaying = playing;
        SineWidgetService.updateWidget(
          title: currentSong?.title,
          artist: currentSong?.artist,
          isPlaying: _isPlaying,
        );
        notifyListeners();
      }
    });
  }

  Future<void> _handleSongCompleted() async {
    // 0. Spotify-grade Sleep Timer: End of Track
    if (_sleepAtTrackEnd) {
      _sleepAtTrackEnd = false;
      _sleepTimer?.cancel();
      _sleepTimer = null;
      _sleepSecondsRemaining = 0;
      _isPlaying = false;
      _isLoadingStream = false;
      notifyListeners();
      await _audioHandler.pause();
      return;
    }

    // 1. Single track loop mode: seek to start and replay instantly
    if (_repeatMode == 'one') {
      _consecutiveStreamFailures = 0;
      await _audioHandler.seek(Duration.zero);
      await _audioHandler.play();
      return;
    }

    // Guard against premature / corrupted completions
    if (_position.inSeconds < 5 && _duration.inSeconds > 15) {
      _consecutiveStreamFailures++;
      debugPrint('[PlayerProvider] Track completed prematurely at ${_position.inSeconds}s (duration: ${_duration.inSeconds}s). Failure count: $_consecutiveStreamFailures');
      if (_consecutiveStreamFailures >= _maxConsecutiveFailures) {
        debugPrint('[PlayerProvider] Halting auto-advance due to repeated premature completions.');
        _isPlaying = false;
        _isLoadingStream = false;
        notifyListeners();
        return;
      }
    } else {
      _consecutiveStreamFailures = 0;
    }

    // 2. Advance to next track in active queue
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      notifyListeners();
      await playSong(_queue[_currentIndex], isAutoAdvance: true);
      if (_isMixActive) {
        _fetchMoreMixTracksIfNeeded();
      }
      return;
    }

    // 3. YouTube Mix infinite continuation (NewPipe-style): fetch next batch before halting
    if (_isMixActive && _activeMixPlaylistId != null) {
      await _fetchMoreMixTracksIfNeeded();
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        notifyListeners();
        await playSong(_queue[_currentIndex], isAutoAdvance: true);
        return;
      }
    }

    // 4. Queue repeat all mode: loop back to beginning
    if (_repeatMode == 'all' && _queue.isNotEmpty) {
      _currentIndex = 0;
      notifyListeners();
      await playSong(_queue[0], isAutoAdvance: true);
      return;
    }

    // 5. Infinite Radio Continuation: If active, fetch next batch before halting
    if (_isRadioActive) {
      await _fetchMoreRadioTracksIfNeeded();
      if (_currentIndex < _queue.length - 1) {
        _currentIndex++;
        notifyListeners();
        await playSong(_queue[_currentIndex], isAutoAdvance: true);
        return;
      }
    }

    // 6. Spotify-Grade Smart Autoplay: If enabled and queue finishes, seamlessly continue with similar tracks
    if (_isAutoplayEnabled && _queue.isNotEmpty) {
      final lastSong = _queue.last;
      debugPrint('[PlayerProvider] Autoplay: Queue completed. Generating smart radio continuation from "${lastSong.title}"...');
      try {
        final autoTracks = await SmartRadioService.instance.generateAutoplayTracks(
          lastSong: lastSong,
          recentHistory: _history,
          limit: 20,
        );
        if (autoTracks.isNotEmpty) {
          _isRadioActive = true;
          _radioSeedSong = lastSong;
          _playingFrom = 'Smart Autoplay: ${lastSong.title}';
          _queue.addAll(autoTracks);
          if (_isShuffle) {
            _unshuffledQueue.addAll(autoTracks);
          }
          _currentIndex++;
          notifyListeners();
          await playSong(_queue[_currentIndex], isAutoAdvance: true);
          return;
        }
      } catch (e) {
        debugPrint('[PlayerProvider] Autoplay generation failed: $e');
      }
    }

    // 7. End of explicit queue reached: stop cleanly
    _isPlaying = false;
    _position = Duration.zero;
    _isLoadingStream = false;
    notifyListeners();
    await _audioHandler.pause();
    await _audioHandler.seek(Duration.zero);
  }

  void _prefetchNextTrack() {
    if (_currentIndex + 1 < _queue.length) {
      final nextTrack = _queue[_currentIndex + 1];
      StreamResolverService.preloadNextSong(nextTrack);
    }
    if (_isRadioActive) {
      _fetchMoreRadioTracksIfNeeded();
    }
  }

  /// NewPipe-style infinite mix expansion: loads the next batch whenever nearing the queue tail
  Future<void> _fetchMoreMixTracksIfNeeded() async {
    if (!_isMixActive || _isLoadingMoreMixTracks || _activeMixPlaylistId == null) return;
    if (_queue.length - _currentIndex <= 4) {
      _isLoadingMoreMixTracks = true;
      try {
        final result = await YouTubeImporterService.fetchNextMixBatch(
          playlistId: _activeMixPlaylistId!,
          continuationToken: _mixContinuationToken,
          currentVideoId: _mixLastVideoId,
          currentParams: _mixLastParams,
          seenIds: _mixSeenVideoIds,
        );
        if (result != null) {
          if (result.continuationToken != null) _mixContinuationToken = result.continuationToken;
          if (result.nextVideoId != null) _mixLastVideoId = result.nextVideoId;
          if (result.nextParams != null) _mixLastParams = result.nextParams;

          if (result.songs.isNotEmpty) {
            _queue.addAll(result.songs);
            if (_isShuffle) {
              _unshuffledQueue.addAll(result.songs);
            }
            notifyListeners();
            debugPrint('[PlayerProvider] Infinitely appended ${result.songs.length} new mix tracks. Total in queue: ${_queue.length}');
          }
        }
      } catch (e) {
        debugPrint('[PlayerProvider] Error fetching next mix batch: $e');
      } finally {
        _isLoadingMoreMixTracks = false;
      }
    }
  }

  Future<void> playSong(Song song, {List<Song>? contextQueue, bool isAutoAdvance = false, String? playingFrom, Duration? initialPosition}) async {
    if (!isAutoAdvance) {
      // User-initiated tap or explicit playlist selection: reset failure counter
      _consecutiveStreamFailures = 0;
    }
    if (playingFrom != null) {
      _playingFrom = playingFrom;
    }
    
    if (contextQueue != null) {
      _queue = List.from(contextQueue);
      _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) {
        _queue.insert(0, song);
        _currentIndex = 0;
      }
    } else if (!isAutoAdvance) {
      final existing = _queue.indexWhere((s) => s.id == song.id);
      if (existing != -1) {
        _currentIndex = existing;
      } else {
        _queue.add(song);
        _currentIndex = _queue.length - 1;
      }
    }

    _recordHistory(song);
    SineWidgetService.updateWidget(
      title: song.title,
      artist: song.artist,
      isPlaying: true,
    );
    _position = Duration.zero;
    _duration = song.duration;
    _isPlaying = true;
    _isLoadingStream = true;
    _isLoadingStem = false;
    _lyrics = LyricsResult.empty;
    _isLoadingLyrics = true;
    activeLyricIndexNotifier.value = -1;
    _isStudioStemActive = false;
    _stemStatusBadgeText = null;
    _isolationMode = IsolationMode.none;
    _originalStreamCache.remove(song.id);
    notifyListeners();

    final thisSession = ++_playSessionId;

    // Offline interception: if this song was downloaded to disk, play offline seamlessly
    Song resolvedSong = song;
    var sPath = song.streamUrl.replaceFirst('file://', '');
    if (Platform.isWindows && sPath.startsWith('/') && sPath.length > 2 && sPath[2] == ':') {
      sPath = sPath.substring(1);
    }
    if ((song.source == 'download' || sPath.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(sPath)) && File(sPath).existsSync()) {
      resolvedSong = song;
    } else {
      final downloadedIndex = _downloads.indexWhere((d) =>
          d.id == song.id ||
          d.id.replaceFirst('yt_', '') == song.id.replaceFirst('yt_', '') ||
          (d.title.trim().toLowerCase() == song.title.trim().toLowerCase() &&
              d.artist.trim().toLowerCase() == song.artist.trim().toLowerCase()));

      if (downloadedIndex != -1) {
        final downloaded = _downloads[downloadedIndex];
        var checkPath = downloaded.streamUrl.replaceFirst('file://', '');
        if (Platform.isWindows && checkPath.startsWith('/') && checkPath.length > 2 && checkPath[2] == ':') {
          checkPath = checkPath.substring(1);
        }
        if (File(checkPath).existsSync()) {
          resolvedSong = downloaded;
        }
      }
    }

    // Correct swapped or mistaken artist/title metadata asynchronously via API
    unawaited(
      MetadataCorrectionService.correctMetadata(song.title, song.artist).then((corrected) {
        if (_playSessionId == thisSession && currentSong?.id == song.id) {
          if (corrected.wasSwapped || (corrected.isVerified && (corrected.cleanTitle != song.title || corrected.cleanArtist != song.artist))) {
            if (_queue.isNotEmpty && _currentIndex >= 0 && _currentIndex < _queue.length) {
              final updated = _queue[_currentIndex].copyWith(
                title: corrected.cleanTitle,
                artist: corrected.cleanArtist,
              );
              _queue[_currentIndex] = updated;
              _audioHandler.updateSongMediaItem(updated);
              notifyListeners();
              // Re-fetch lyrics with verified canonical title and artist
              _loadLyrics(updated);
            }
          }
        }
      }).catchError((_) {}),
    );

    // Defer lyrics metadata until after song playback has initiated
    // (giving 100% network bandwidth to the initial audio chunks)
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (currentSong?.id == song.id && _playSessionId == thisSession) {
        _loadLyrics(song);
      }
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (currentSong?.id == song.id && _playSessionId == thisSession) {
        _loadRecommendations(song);
      }
    });

    try {
      await _audioHandler.playSong(resolvedSong);
      if (initialPosition != null && initialPosition > Duration.zero) {
        await _audioHandler.seek(initialPosition);
      }
    } catch (e, st) {
      debugPrint('[PlayerProvider] playSong execution error: $e\n$st');
      _isPlaying = false;
      _isLoadingStream = false;
      notifyListeners();
      return;
    }
    if (_playSessionId != thisSession) {
      // Newer song selection superseded this one; discard outdated state updates
      return;
    }
    _isLoadingStream = false;
    notifyListeners();
    if (_eqEnabled) {
      if (_bandGains.isNotEmpty) {
        _audioHandler.setCustomBandGains(_bandGains);
      }
      _audioHandler.ensureEqualizerSynced(forceRebind: false);
    }
    if (_isMixActive) {
      _fetchMoreMixTracksIfNeeded();
    }
    if (_isRadioActive) {
      _fetchMoreRadioTracksIfNeeded();
    }
  }

  /// On-demand lyrics loader triggered immediately when lyrics view is expanded
  Future<void> loadLyricsForCurrentSong({bool force = false}) async {
    final s = currentSong;
    if (s == null) return;
    if (!force && _lyrics.isNotEmpty) return;
    if (!force && _isLoadingLyrics) return;
    await _loadLyrics(s);
  }

  Future<void> _loadLyrics(Song song) async {
    if (LyricsService.isTempoModified(song.title, song.artist)) {
      _isLoadingLyrics = false;
      _lyrics = LyricsResult.empty;
      activeLyricIndexNotifier.value = -1;
      notifyListeners();
      return;
    }

    _isLoadingLyrics = true;
    _lyrics = LyricsResult.empty;
    activeLyricIndexNotifier.value = -1;
    notifyListeners();

    try {
      final res = await LyricsService.fetchLyrics(
        song.title,
        song.artist,
        trackDuration: song.duration,
      );
      if (currentSong?.id == song.id) {
        _lyrics = res;
        _isLoadingLyrics = false;
        activeLyricIndexNotifier.value = _findLyricIndex(_position);
        notifyListeners();
      }
    } catch (_) {
      if (currentSong?.id == song.id) {
        _isLoadingLyrics = false;
        notifyListeners();
      }
    }
  }

  Future<void> startRadio(Song song, {bool isArtistRadio = false}) async {
    _isRadioActive = true;
    _isMixActive = false;
    _activeMixPlaylistId = null;
    _radioSeedSong = song;
    _radioIsArtist = isArtistRadio;
    _radioSeenVideoIds.clear();

    _playingFrom = isArtistRadio ? 'Artist Radio: ${song.artist}' : 'Song Radio: ${song.title}';
    notifyListeners();

    try {
      final station = await SmartRadioService.instance.generateRadioStation(
        seedSong: song,
        isArtistRadio: isArtistRadio,
      );

      _radioContinuationToken = station.continuationToken;
      _radioLastVideoId = station.nextVideoId;
      _radioLastParams = station.nextParams;
      _radioSeenVideoIds.addAll(station.seenVideoIds);

      _queue = List.from(station.songs);
      _currentIndex = 0;
      notifyListeners();

      await playSong(song, playingFrom: _playingFrom);
    } catch (e) {
      debugPrint('[PlayerProvider] Error starting radio: $e');
      _queue = [song];
      _currentIndex = 0;
      await playSong(song, playingFrom: _playingFrom);
    }
  }

  Future<void> toggleAutoplay() async {
    _isAutoplayEnabled = !_isAutoplayEnabled;
    await _storageService.saveAutoplayEnabled(_isAutoplayEnabled);
    notifyListeners();
  }

  /// NewPipe & YouTube Music style infinite radio continuation: loads next batch near queue tail
  Future<void> _fetchMoreRadioTracksIfNeeded() async {
    if (!_isRadioActive || _isLoadingMoreRadioTracks) return;
    if (_queue.length - _currentIndex <= 4) {
      _isLoadingMoreRadioTracks = true;
      try {
        final seedVid = _radioSeedSong?.id.replaceFirst('yt_', '');
        final batch = await SmartRadioService.instance.fetchNextRadioBatch(
          seedVideoId: seedVid,
          continuationToken: _radioContinuationToken,
          lastVideoId: _radioLastVideoId,
          lastParams: _radioLastParams,
          seenIds: _radioSeenVideoIds,
        );
        if (batch != null && batch.songs.isNotEmpty) {
          _radioContinuationToken = batch.continuationToken;
          _radioLastVideoId = batch.nextVideoId;
          _radioLastParams = batch.nextParams;
          _queue.addAll(batch.songs);
          if (_isShuffle) {
            _unshuffledQueue.addAll(batch.songs);
          }
          notifyListeners();
          debugPrint('[PlayerProvider] Infinitely appended ${batch.songs.length} new radio tracks. Total in queue: ${_queue.length}');
        }
      } catch (e) {
        debugPrint('[PlayerProvider] Error fetching next radio batch: $e');
      } finally {
        _isLoadingMoreRadioTracks = false;
      }
    }
  }

  /// Asynchronously loads smart recommendations for the currently playing track
  Future<void> _loadRecommendations(Song song) async {
    _isLoadingRecommendations = true;
    notifyListeners();
    try {
      final recs = await SmartRadioService.instance.fetchQueueRecommendations(
        currentSong: song,
        currentQueue: _queue,
        limit: 15,
      );
      if (currentSong?.id == song.id) {
        _recommendations.clear();
        _recommendations.addAll(recs);
      }
    } catch (e) {
      debugPrint('[PlayerProvider] Load recommendations error: $e');
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh or explicit refresh for queue recommendations
  Future<void> refreshRecommendations() async {
    final cur = currentSong;
    if (cur != null) {
      SmartRadioService.clearCaches();
      await _loadRecommendations(cur);
    }
  }

  Future<void> retryFetchLyrics() async {
    final cur = currentSong;
    if (cur != null) {
      LyricsService.invalidateCache(cur.title, cur.artist);
      await _loadLyrics(cur);
    }
  }

  Future<void> togglePlay() async {
    if (_isPlaying) {
      _saveCurrentSession();
      await _audioHandler.pause();
    } else {
      if (currentSong != null) {
        if (_audioHandler.currentSong == null) {
          await playSong(currentSong!);
        } else {
          await _audioHandler.play();
        }
      } else if (_queue.isNotEmpty) {
        await playSong(_queue[0]);
      }
    }
  }

  Future<void> togglePlayPause() => togglePlay();

  /// Completely halt playback, dismiss active song, and return to no song playing state
  Future<void> stopPlayback() async {
    try {
      await _audioHandler.stop();
    } catch (_) {}
    _queue.clear();
    _currentIndex = 0;
    _isPlaying = false;
    SineWidgetService.updateWidget(
      title: 'No Song Playing',
      artist: 'Tap to open Sine',
      isPlaying: false,
    );
    _position = Duration.zero;
    _duration = Duration.zero;
    _lyrics = LyricsResult.empty;
    _isLoadingLyrics = false;
    _consecutiveStreamFailures = 0;
    notifyListeners();
  }

  Future<void> skipNext({bool isAuto = false}) async {
    if (!isAuto) {
      _consecutiveStreamFailures = 0;
    }
    if (_queue.isEmpty) return;
    if (_repeatMode == 'one' && isAuto) {
      await _audioHandler.seek(Duration.zero);
      await _audioHandler.play();
      return;
    }

    int nextIdx = _currentIndex + 1;
    if (nextIdx >= _queue.length) {
      if (_isMixActive) {
        await _fetchMoreMixTracksIfNeeded();
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
          notifyListeners();
          await playSong(_queue[_currentIndex], isAutoAdvance: true);
          return;
        }
      }
      if (_isRadioActive) {
        await _fetchMoreRadioTracksIfNeeded();
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
          notifyListeners();
          await playSong(_queue[_currentIndex], isAutoAdvance: true);
          return;
        }
      }
      if (_repeatMode == 'all') {
        nextIdx = 0;
      } else if (_isAutoplayEnabled && _queue.isNotEmpty) {
        final lastSong = _queue.last;
        final autoTracks = await SmartRadioService.instance.generateAutoplayTracks(
          lastSong: lastSong,
          recentHistory: _history,
          limit: 20,
        );
        if (autoTracks.isNotEmpty) {
          _isRadioActive = true;
          _radioSeedSong = lastSong;
          _playingFrom = 'Smart Autoplay: ${lastSong.title}';
          _queue.addAll(autoTracks);
          if (_isShuffle) {
            _unshuffledQueue.addAll(autoTracks);
          }
          _currentIndex++;
          notifyListeners();
          await playSong(_queue[_currentIndex], isAutoAdvance: true);
          return;
        } else {
          _isPlaying = false;
          _position = Duration.zero;
          _isLoadingStream = false;
          notifyListeners();
          await _audioHandler.pause();
          await _audioHandler.seek(Duration.zero);
          return;
        }
      } else {
        _isPlaying = false;
        _position = Duration.zero;
        _isLoadingStream = false;
        notifyListeners();
        await _audioHandler.pause();
        await _audioHandler.seek(Duration.zero);
        return; // End of queue
      }
    }
    _currentIndex = nextIdx;
    notifyListeners();
    await playSong(_queue[_currentIndex], isAutoAdvance: true);
    if (_isMixActive) {
      _fetchMoreMixTracksIfNeeded();
    }
    if (_isRadioActive) {
      _fetchMoreRadioTracksIfNeeded();
    }
  }

  Future<void> skipPrevious() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
      await playSong(_queue[_currentIndex]);
    } else if (_repeatMode == 'all' && _queue.isNotEmpty) {
      _currentIndex = _queue.length - 1;
      notifyListeners();
      await playSong(_queue[_currentIndex]);
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> seek(Duration position) async {
    _position = position;
    positionNotifier.value = position;
    notifyListeners();
    await _audioHandler.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    _speed = (speed * 100).round() / 100.0;
    await _storageService.savePlaybackSpeed(_speed);
    await _audioHandler.setSpeed(_speed);
    notifyListeners();
  }

  Future<void> cycleRepeatMode() async {
    if (_repeatMode == 'off') {
      _repeatMode = 'all';
    } else if (_repeatMode == 'all') {
      _repeatMode = 'one';
    } else {
      _repeatMode = 'off';
    }
    await _storageService.saveRepeatMode(_repeatMode);
    await _audioHandler.setPlayerRepeatMode(_repeatMode);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;
    await _storageService.saveShuffle(_isShuffle);
    if (_isShuffle && _queue.length > 1) {
      _unshuffledQueue = List.from(_queue);
      final cur = currentSong;
      if (cur != null && _currentIndex >= 0 && _currentIndex < _queue.length) {
        // Keep played history intact, shuffle only upcoming songs
        final played = _queue.sublist(0, _currentIndex + 1);
        final upcoming = _queue.sublist(_currentIndex + 1);
        upcoming.shuffle();
        _queue = [...played, ...upcoming];
      } else {
        _queue.shuffle();
      }
    } else if (!_isShuffle && _unshuffledQueue.isNotEmpty) {
      final cur = currentSong;
      _queue = List.from(_unshuffledQueue);
      if (cur != null) {
        _currentIndex = _queue.indexWhere((s) => s.id == cur.id);
        if (_currentIndex == -1) _currentIndex = 0;
      }
    }
    notifyListeners();
  }

  void setTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  Future<void> _loadInitialDiscoveryTracks() async {
    _activeCategory = 'trending';
    _isSearching = true;
    try {
      final trending = await CatalogService.fetchTrendingTracks();
      final nonPlaceholders = trending.where((s) => !Song.isPlaceholder(s)).toList();
      if (nonPlaceholders.isNotEmpty) {
        _categoryTracks = nonPlaceholders;
        _searchResults = nonPlaceholders;
        if (_queue.isEmpty) {
          _queue = List.from(nonPlaceholders);
        }
      }
    } catch (e) {
      debugPrint('Error loading initial trending tracks: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> selectCategory(String categoryKey) async {
    _activeCategory = categoryKey;
    _activeTab = 'discover';
    _isSearching = true;
    notifyListeners();
    try {
      final liveTracks = await CatalogService.fetchCategoryTracks(categoryKey);
      final nonPlaceholders = liveTracks.where((s) => !Song.isPlaceholder(s)).toList();
      if (nonPlaceholders.isNotEmpty && _activeCategory == categoryKey) {
        _categoryTracks = nonPlaceholders;
        _searchResults = nonPlaceholders;
        if (_queue.isEmpty) {
          _queue = List.from(nonPlaceholders);
        }
      }
    } catch (e) {
      debugPrint('Error selecting category: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> playCategoryTracks(List<Song> tracks, {int startIndex = 0, Song? targetSong, String? playingFrom}) async {
    final validTracks = tracks.where((s) => !Song.isPlaceholder(s)).toList();
    if (validTracks.isEmpty) return;
    _consecutiveStreamFailures = 0;
    _isMixActive = false;
    _activeMixPlaylistId = null;
    _queue = List.from(validTracks);
    if (targetSong != null) {
      final targetIdx = _queue.indexWhere((s) => s.id == targetSong.id);
      _currentIndex = targetIdx != -1 ? targetIdx : startIndex.clamp(0, _queue.length - 1);
    } else {
      _currentIndex = startIndex.clamp(0, _queue.length - 1);
    }
    if (playingFrom != null) {
      _playingFrom = playingFrom;
    }
    notifyListeners();
    await playSong(_queue[_currentIndex], playingFrom: _playingFrom);
  }

  void addTracksToQueue(List<Song> tracks) {
    final validTracks = tracks.where((s) => !Song.isPlaceholder(s)).toList();
    if (validTracks.isEmpty) return;
    _queue.addAll(validTracks);
    if (_isShuffle) {
      _unshuffledQueue.addAll(validTracks);
    }
    notifyListeners();
  }

  // Backward-compatible alias
  Future<void> selectMood(String moodKey) => selectCategory(moodKey);

  void search(String query, {String? engine}) {
    if (engine != null) {
      _searchEngine = engine;
    }
    _searchQuery = query;
    _searchDebounce?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _isSearching = false;
      _searchResults = CatalogService.getAllTracks();
      notifyListeners();
      return;
    }

    // Auto-detect pasted YouTube URLs for zero-friction importing
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.contains('youtube.com') ||
        trimmed.contains('youtu.be')) {
      _isSearching = true;
      notifyListeners();
      importMediaUrl(trimmed).then((msg) {
        _isSearching = false;
        notifyListeners();
      });
      return;
    }

    _isSearching = true;
    notifyListeners();

    // Debounce 250ms before firing live YouTube NewPipe search
    _searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await CatalogService.searchOnline(trimmed, limit: 35);

        if (_searchQuery == query) {
          _searchResults = results;
          _isSearching = false;
          notifyListeners();
        }
      } catch (_) {
        if (_searchQuery == query) {
          _isSearching = false;
          notifyListeners();
        }
      }
    });
  }


  // ==========================================
  // SETTINGS, CLIPPING & RECOVERY METHODS
  // ==========================================

  void _saveCurrentSession() {
    if (currentSong == null) return;
    _storageService.saveSavedSession({
      'song': currentSong!.toMap(),
      'positionMs': _position.inMilliseconds,
      'queue': _queue.map((s) => s.toMap()).toList(),
      'currentIndex': _currentIndex,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }



  Future<void> setClippingProtection(bool enabled) async {
    _clippingProtection = enabled;
    await _storageService.saveClippingProtection(enabled);
    await _audioHandler.setClippingProtection(enabled);
    notifyListeners();
  }

  Future<void> setPlaybackRecoveryMode(String mode) async {
    _playbackRecoveryMode = mode;
    await _storageService.savePlaybackRecoveryMode(mode);
    notifyListeners();
  }

  Future<void> setStemEnginePreference(String engine) async {
    _stemEnginePreference = engine;
    StemService.instance.setEnginePreference(engine);
    await _storageService.saveStemEnginePreference(engine);
    notifyListeners();
  }

  Future<void> setPerformanceHudEnabled(bool enabled) async {
    _performanceHudEnabled = enabled;
    await _storageService.savePerformanceHudEnabled(enabled);
    PerformanceService.instance.setHudVisible(enabled);
    if (enabled) {
      PerformanceService.instance.start();
    } else {
      PerformanceService.instance.stop();
    }
    notifyListeners();
  }

  void resumeRecoveredSession() {
    if (_recoverableSession == null) return;
    final session = _recoverableSession!;
    _recoverableSession = null;
    _storageService.clearSavedSession();
    _queue = List.from(session.queue);
    _currentIndex = session.currentIndex.clamp(0, _queue.isNotEmpty ? _queue.length - 1 : 0);
    _unshuffledQueue = List.from(_queue);
    playSong(session.song, initialPosition: Duration(milliseconds: session.positionMs));
    notifyListeners();
  }

  void dismissRecoverableSession() {
    _recoverableSession = null;
    _storageService.clearSavedSession();
    notifyListeners();
  }

  void preSeparateStems(Song song, {StemType type = StemType.instrumental}) {
    StemService.instance.enqueueBackgroundSeparation(song, type);
    notifyListeners();
  }

  void deduplicateQueue() {
    if (_queue.length <= 1) return;
    final seenIds = <String>{};
    final newQueue = <Song>[];
    final currentId = currentSong?.id;

    for (final song in _queue) {
      if (seenIds.add(song.id)) {
        newQueue.add(song);
      }
    }

    _queue = newQueue;
    if (currentId != null) {
      final newIdx = _queue.indexWhere((s) => s.id == currentId);
      _currentIndex = newIdx != -1 ? newIdx : 0;
    } else {
      _currentIndex = _queue.isEmpty ? -1 : 0;
    }
    _unshuffledQueue = List.from(_queue);
    _storageService.saveSavedQueue(_queue);
    notifyListeners();
  }

  // Queue manipulation
  void playNext(Song song) {
    if (currentSong == null && _queue.isEmpty) {
      _queue.add(song);
      _currentIndex = 0;
      playSong(song);
      return;
    }
    final existingIdx = _queue.indexWhere((s) => s.id == song.id);
    if (existingIdx == _currentIndex) return; // Don't re-insert the currently playing song
    if (existingIdx != -1) {
      _queue.removeAt(existingIdx);
      if (existingIdx < _currentIndex) _currentIndex--;
    }
    final targetIdx = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(targetIdx, song);
    if (_isShuffle && !_unshuffledQueue.any((s) => s.id == song.id)) {
      _unshuffledQueue.add(song);
    }
    notifyListeners();
  }

  void addToQueue(Song song) {
    if (!_queue.any((s) => s.id == song.id)) {
      _queue.add(song);
      if (_isShuffle && !_unshuffledQueue.any((s) => s.id == song.id)) {
        _unshuffledQueue.add(song);
      }
      if (currentSong == null) {
        _currentIndex = 0;
        playSong(song);
      } else {
        notifyListeners();
      }
    }
  }

  void removeTrackAt(int index) {
    if (index < 0 || index >= _queue.length) return;
    final removed = _queue.removeAt(index);
    if (_isShuffle) {
      _unshuffledQueue.removeWhere((s) => s.id == removed.id);
    }

    if (index == _currentIndex) {
      if (_queue.isEmpty) {
        stopPlayback();
      } else {
        _currentIndex = _currentIndex.clamp(0, _queue.length - 1);
        playSong(_queue[_currentIndex]);
      }
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.isEmpty ? 0 : (_queue.length - 1).clamp(0, _queue.length - 1);
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final targetIndex = newIndex.clamp(0, _queue.length - 1);
    final item = _queue.removeAt(oldIndex);
    _queue.insert(targetIndex, item);

    if (oldIndex == _currentIndex) {
      _currentIndex = targetIndex;
    } else if (oldIndex < _currentIndex && targetIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && targetIndex <= _currentIndex) {
      _currentIndex++;
    }
    notifyListeners();
  }

  void clearQueue() {
    final cur = currentSong;
    _queue.clear();
    _unshuffledQueue.clear();
    _isShuffle = false;
    _storageService.saveShuffle(false);
    _isMixActive = false;
    _isRadioActive = false;
    _activeMixPlaylistId = null;
    _radioSeedSong = null;
    _mixContinuationToken = null;
    _mixLastVideoId = null;
    _mixLastParams = null;
    _mixSeenVideoIds.clear();
    if (cur != null) {
      _queue.add(cur);
      _unshuffledQueue.add(cur);
      _currentIndex = 0;
    } else {
      _currentIndex = 0;
    }
    notifyListeners();
  }

  // Playlists
  Future<void> createPlaylist(String title, {String description = ''}) async {
    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isNotEmpty ? title.trim() : 'New Playlist',
      description: description,
      songs: const [],
      createdAt: DateTime.now(),
    );
    await _storageService.savePlaylist(newPlaylist);
    _playlists = _storageService.loadPlaylists();
    notifyListeners();
  }

  Future<void> importScannedPlaylist(Playlist playlist) async {
    final cleanId = (playlist.id.isNotEmpty && playlist.id != 'downloaded_songs')
        ? playlist.id
        : 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final toSave = playlist.copyWith(id: cleanId);
    final existingIdx = _playlists.indexWhere((p) => p.id == cleanId);
    if (existingIdx != -1) {
      _playlists[existingIdx] = toSave;
    } else {
      _playlists.insert(0, toSave);
    }
    await _storageService.savePlaylists(_playlists);
    _playlists = _storageService.loadPlaylists();
    notifyListeners();
  }

  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final p = _playlists[idx];
      final updated = p.copyWith(title: newTitle.trim().isNotEmpty ? newTitle.trim() : p.title);
      await _storageService.savePlaylist(updated);
      _playlists = _storageService.loadPlaylists();
      notifyListeners();
    }
  }

  Future<void> reorderPlaylistSongs(String playlistId, int oldIndex, int newIndex) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final p = _playlists[idx];
      final songs = List<Song>.from(p.songs);
      if (oldIndex < 0 || oldIndex >= songs.length) return;
      if (oldIndex < newIndex) newIndex -= 1;
      if (newIndex < 0 || newIndex >= songs.length) return;
      final moved = songs.removeAt(oldIndex);
      songs.insert(newIndex, moved);
      final updated = p.copyWith(songs: songs);
      await _storageService.savePlaylist(updated);
      _playlists = _storageService.loadPlaylists();
      notifyListeners();
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    await _storageService.addSongToPlaylist(playlistId, song);
    _playlists = _storageService.loadPlaylists();
    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final p = _playlists[idx];
      final updated = p.copyWith(
        songs: p.songs.where((s) => s.id != songId).toList(),
      );
      await _storageService.savePlaylist(updated);
      _playlists = _storageService.loadPlaylists();
      notifyListeners();
    }
  }

  Future<void> removeSongFromPlaylistAt(String playlistId, int index) async {
    if (playlistId == 'downloaded_songs') {
      if (index >= 0 && index < _downloads.length) {
        await deleteDownload(_downloads[index].id);
      }
      return;
    }
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final p = _playlists[idx];
      final songs = List<Song>.from(p.songs);
      if (index >= 0 && index < songs.length) {
        songs.removeAt(index);
        final updated = p.copyWith(songs: songs);
        await _storageService.savePlaylist(updated);
        _playlists = _storageService.loadPlaylists();
        notifyListeners();
      }
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _storageService.deletePlaylist(playlistId);
    _playlists = _storageService.loadPlaylists();
    notifyListeners();
  }

  Future<void> playPlaylist(Playlist playlist, {int startIndex = 0, bool shuffle = false}) async {
    if (playlist.songs.isNotEmpty) {
      _consecutiveStreamFailures = 0;
      final isMix = playlist.id.startsWith('yt_mix_');
      if (isMix) {
        _isMixActive = true;
        _activeMixPlaylistId = playlist.id.replaceFirst('yt_mix_', '');
        _mixContinuationToken = playlist.continuationToken;
        _mixLastVideoId = playlist.songs.isNotEmpty ? playlist.songs.last.id.replaceFirst('yt_', '') : null;
        _mixLastParams = null;
        _mixSeenVideoIds.clear();
        _mixSeenVideoIds.addAll(playlist.songs.map((s) => s.id.replaceFirst('yt_', '')));
        _playingFrom = 'YouTube Mix: ${playlist.title}';
      } else {
        _isMixActive = false;
        _activeMixPlaylistId = null;
        _playingFrom = 'Playlist: ${playlist.title}';
      }
      if (shuffle) {
        _isShuffle = true;
        _storageService.saveShuffle(true);
        _unshuffledQueue = List.from(playlist.songs);
        final shuffled = List<Song>.from(playlist.songs)..shuffle();
        await playSong(shuffled[0], contextQueue: shuffled, playingFrom: _playingFrom);
        return;
      }
      final idx = startIndex.clamp(0, playlist.songs.length - 1);
      await playSong(playlist.songs[idx], contextQueue: playlist.songs, playingFrom: _playingFrom);
    }
  }

  // YouTube Importer
  Future<String> importYouTubeUrl(String url) async {
    final result = await YouTubeImporterService.importFromUrl(url);
    if (result.error != null) {
      return 'Import failed: ${result.error}';
    }
    if (result.type == YouTubeImportType.video && result.song != null) {
      addToQueue(result.song!);
      return 'Added "${result.song!.title}" to queue';
    } else if (result.type == YouTubeImportType.playlist && result.playlist != null) {
      for (final s in result.playlist!.songs) {
        addToQueue(s);
      }
      return 'Added ${result.playlist!.songs.length} tracks from "${result.playlist!.title}"';
    }
    return 'Could not import track or playlist';
  }

  // Offline Downloads
  bool isDownloaded(String songId) {
    final cleanId = songId.replaceFirst('yt_', '');
    return _downloads.any((s) => s.id == songId || s.id.replaceFirst('yt_', '') == cleanId);
  }

  Future<String?> downloadAudio(Song song) async {
    final path = await DownloadService.downloadAudio(song, _storageService);
    if (path != null) {
      _downloads = _storageService.loadDownloads();
      notifyListeners();
    }
    return path;
  }

  Future<String?> downloadVideo(Song song) async {
    return await DownloadService.downloadVideo(song);
  }

  Future<void> deleteDownload(String songId) async {
    final cleanId = songId.replaceFirst('yt_', '');
    final idx = _downloads.indexWhere((s) => s.id == songId || s.id.replaceFirst('yt_', '') == cleanId);
    if (idx != -1) {
      final songToRemove = _downloads[idx];
      if (currentSong?.id == songId || currentSong?.id.replaceFirst('yt_', '') == cleanId) {
        try {
          await _audioHandler.stop();
        } catch (_) {}
      }
      if (songToRemove.streamUrl.isNotEmpty) {
        try {
          var filePath = songToRemove.streamUrl.replaceFirst('file://', '');
          if (Platform.isWindows && filePath.startsWith('/') && filePath.length > 2 && filePath[2] == ':') {
            filePath = filePath.substring(1);
          }
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting download file: $e');
        }
      }
      _downloads.removeAt(idx);
      await _storageService.saveDownloads(_downloads);
      notifyListeners();
    }
  }

  /// Purges any legacy mock/placeholder tracks from all storage lists and flushes stream caches
  Future<void> purgePlaceholders() async {
    _favorites = _favorites.where((s) => !Song.isPlaceholder(s)).toList();
    _history = _history.where((s) => !Song.isPlaceholder(s)).toList();
    _downloads = _downloads.where((s) => !Song.isPlaceholder(s)).toList();
    _queue = _queue.where((s) => !Song.isPlaceholder(s)).toList();
    _unshuffledQueue = _unshuffledQueue.where((s) => !Song.isPlaceholder(s)).toList();
    _playlists = _playlists
        .map((p) => p.copyWith(songs: p.songs.where((s) => !Song.isPlaceholder(s)).toList()))
        .toList();
    await _storageService.saveFavorites(_favorites);
    await _storageService.saveHistory(_history);
    await _storageService.saveDownloads(_downloads);
    await _storageService.savePlaylists(_playlists);
    StreamResolverService.clearAllCaches();
    YouTubeImporterService.clearAllCaches();
    notifyListeners();
  }

  // Equalizer
  Future<void> setEqualizerPreset(String preset, {List<double>? presetGains}) async {
    _eqPreset = preset;
    if (preset != 'Vocals Only' && preset != 'Instruments Only') {
      _isolationMode = IsolationMode.none;
    }
    if (presetGains != null) {
      for (int i = 0; i < presetGains.length; i++) {
        _bandGains[i] = presetGains[i];
      }
      await _storageService.saveBandGains(_bandGains);
    }
    await _storageService.saveEqualizerPreset(preset);
    if (preset == 'Custom' && _bandGains.isNotEmpty) {
      _audioHandler.setCustomBandGains(_bandGains);
    }
    await _audioHandler.applyEqualizerPreset(preset);
    notifyListeners();
  }

  Future<void> toggleIsolationMode(IsolationMode mode) async {
    if (_isolationMode == mode) {
      await revertToOriginalTrack();
      return;
    }

    final song = currentSong;
    if (song == null) {
      _isolationMode = IsolationMode.none;
      _isLoadingStem = false;
      _stemStatusBadgeText = null;
      notifyListeners();
      return;
    }

    // Cache current original stream URL before swapping
    if (!_originalStreamCache.containsKey(song.id) && _audioHandler.activeStreamUrl != null) {
      _originalStreamCache[song.id] = _audioHandler.activeStreamUrl!;
    }

    _isolationMode = mode;
    _isLoadingStem = true;
    _stemStatusBadgeText = mode == IsolationMode.instrumentsOnly
        ? 'Searching Karaoke...'
        : 'Searching Acapella...';
    notifyListeners();

    try {
      final stemType = mode == IsolationMode.instrumentsOnly
          ? StemType.instrumental
          : StemType.vocals;

      final stemResult = await StemService.instance.resolveStem(
        song: song,
        type: stemType,
        targetDuration: _duration > Duration.zero ? _duration : song.duration,
      );

      if (currentSong?.id != song.id || _isolationMode != mode) {
        return;
      }

      if (stemResult.isStudioStem && stemResult.streamUrl != null) {
        final originalUrl = _originalStreamCache[song.id] ?? _audioHandler.activeStreamUrl;
        final bool swapped = await _audioHandler.swapAudioStream(
          stemResult.streamUrl!,
          currentPosition: _position,
          playImmediately: _isPlaying,
          isLocal: stemResult.isLocal,
          fallbackUrls: stemResult.fallbackUrls,
          originalStreamUrl: originalUrl,
        );

        if (swapped && currentSong?.id == song.id && _isolationMode == mode) {
          _isStudioStemActive = true;
          _stemStatusBadgeText = mode == IsolationMode.instrumentsOnly
              ? (stemResult.source == StemSource.aiSeparation
                  ? 'Demucs AI Karaoke'
                  : (stemResult.isLocal ? 'Offline Karaoke' : 'Studio Karaoke'))
              : (stemResult.source == StemSource.aiSeparation
                  ? 'Demucs AI Acapella'
                  : (stemResult.isLocal ? 'Offline Acapella' : 'Studio Acapella'));
        } else {
          _isStudioStemActive = false;
          _isolationMode = IsolationMode.none;
          _stemStatusBadgeText = null;
        }
      } else {
        _isStudioStemActive = false;
        _isolationMode = IsolationMode.none;
        _stemStatusBadgeText = null;
      }
    } catch (e) {
      debugPrint('[PlayerProvider] Stem toggle error: $e');
      _isStudioStemActive = false;
      _isolationMode = IsolationMode.none;
      _stemStatusBadgeText = null;
    } finally {
      _isLoadingStem = false;
      notifyListeners();
    }
  }

  Future<void> revertToOriginalTrack() async {
    final bool wasStudioStem = _isStudioStemActive;
    _isolationMode = IsolationMode.none;
    _isStudioStemActive = false;
    _stemStatusBadgeText = null;
    _isLoadingStem = false;

    if (wasStudioStem) {
      final song = currentSong;
      if (song != null) {
        final cachedOriginalUrl = _originalStreamCache[song.id];
        if (cachedOriginalUrl != null) {
          await _audioHandler.swapAudioStream(
            cachedOriginalUrl,
            currentPosition: _position,
            playImmediately: _isPlaying,
          );
        } else {
          final candidates = await StreamResolverService.resolvePlayableStreamCandidates(song);
          if (candidates.isNotEmpty) {
            await _audioHandler.swapAudioStream(
              candidates.first,
              fallbackUrls: candidates.length > 1 ? candidates.sublist(1) : const [],
              currentPosition: _position,
              playImmediately: _isPlaying,
            );
          }
        }
      }
    }

    notifyListeners();
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _storageService.saveEqualizerEnabled(enabled);
    await _audioHandler.setEqualizerEnabled(enabled);
    notifyListeners();
  }

  Future<void> setBassBoost(double gain) async {
    _bassBoost = gain;
    if (gain > 0.0 && !_eqEnabled) {
      _eqEnabled = true;
      await _storageService.saveEqualizerEnabled(true);
      await _audioHandler.setEqualizerEnabled(true);
    }
    await _storageService.saveBassBoost(gain);
    await _audioHandler.setBassBoost(gain);
    notifyListenersPlatform();
  }

  void notifyListenersPlatform() => notifyListeners();

  Future<void> setBandGain(int index, double gain) async {
    _bandGains[index] = gain;
    _eqPreset = 'Custom';
    _isolationMode = IsolationMode.none;
    _audioHandler.setCustomBandGains(_bandGains);
    notifyListeners();
    _bandSaveTimer?.cancel();
    _bandSaveTimer = Timer(const Duration(milliseconds: 150), () {
      _storageService.saveBandGains(_bandGains);
      _storageService.saveEqualizerPreset('Custom');
    });
    await _audioHandler.setBandGain(index, gain);
  }

  Future<void> resetEqualizer() async {
    _eqEnabled = false;
    _bassBoost = 0.0;
    _eqPreset = 'Flat';
    _isolationMode = IsolationMode.none;
    _bandGains.clear();
    await _storageService.saveEqualizerEnabled(false);
    await _storageService.saveBassBoost(0.0);
    await _storageService.saveEqualizerPreset('Flat');
    await _storageService.saveBandGains({});
    _audioHandler.setCustomBandGains({0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0});
    await _audioHandler.setEqualizerEnabled(false);
    await _audioHandler.setBassBoost(0.0);
    await _audioHandler.applyEqualizerPreset('Flat');
    notifyListeners();
  }

  // Favorites & History
  Future<void> toggleFavorite(Song song) async {
    final idx = _favorites.indexWhere((s) => s.id == song.id);
    if (idx >= 0) {
      _favorites.removeAt(idx);
    } else {
      _favorites.add(song.copyWith(isFavorite: true));
    }
    await _storageService.saveFavorites(_favorites);
    notifyListeners();
  }

  bool isFavorite(String songId) {
    return _favorites.any((s) => s.id == songId);
  }

  void _recordHistory(Song song) {
    _history.removeWhere((s) => s.id == song.id);
    _history.insert(0, song);
    if (_history.length > 200) _history.removeLast();
    _storageService.saveHistory(_history);
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _storageService.clearHistory();
    notifyListeners();
  }

  Future<void> loadYouTubeCategory(String categoryKey) async {
    final cached = CatalogService.getCachedCategory(categoryKey);
    if (cached != null && cached.isNotEmpty) {
      _youtubeTracks = cached;
      notifyListeners();
      return;
    }

    _isLoadingYouTube = true;
    notifyListeners();

    try {
      final tracks = await CatalogService.fetchCategory(categoryKey);
      if (tracks.isNotEmpty) {
        _youtubeTracks = tracks;
      }
    } catch (e) {
      debugPrint('Error loading YouTube category $categoryKey: $e');
    } finally {
      _isLoadingYouTube = false;
      notifyListeners();
    }
  }

  Future<void> loadYouTubeTrending() async {
    if (_youtubeTracks.isNotEmpty) return;
    _isLoadingYouTube = true;
    notifyListeners();

    try {
      final tracks = await CatalogService.fetchTrending();
      if (tracks.isNotEmpty) {
        _youtubeTracks = tracks;
      }
    } catch (e) {
      debugPrint('Error loading YouTube trending: $e');
    } finally {
      _isLoadingYouTube = false;
      notifyListeners();
    }
  }

  Future<String?> importMediaUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return null;

    // YouTube URL parsing via NewPipe Extractor
    if (clean.contains('youtube.com') || clean.contains('youtu.be')) {
      final res = await YouTubeImporterService.importFromUrl(clean);
      if (res.playlist != null && res.playlist!.songs.isNotEmpty) {
        final pl = res.playlist!;
        _playlists.insert(0, pl);
        _storageService.savePlaylists(_playlists);
        await playPlaylist(pl);
        notifyListeners();
        return 'Imported YouTube playlist "${pl.title}" (${pl.songs.length} tracks)';
      } else if (res.song != null) {
        addToQueue(res.song!);
        await playSong(res.song!, playingFrom: 'YouTube: ${res.song!.title}');
        return 'Playing "${res.song!.title}"';
      }
      return res.error ?? 'Could not parse YouTube link';
    }

    return null;
  }

  void startSleepTimer(int minutes) {
    if (minutes <= 0) {
      cancelSleepTimer();
      return;
    }
    _sleepTimer?.cancel();
    _sleepAtTrackEnd = false;
    _sleepSecondsRemaining = minutes * 60;
    sleepSecondsNotifier.value = _sleepSecondsRemaining;
    notifyListeners();

    final targetTime = DateTime.now().add(Duration(minutes: minutes));

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      final remaining = targetTime.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        _sleepSecondsRemaining = remaining;
        sleepSecondsNotifier.value = remaining;
        // Metrolist & Audile smart fade-out curve over the last 20 seconds
        if (remaining <= 20) {
          final frac = (remaining / 20.0).clamp(0.0, 1.0);
          final fadeMultiplier = frac * frac;
          _audioHandler.setSleepFadeMultiplier(fadeMultiplier);
        } else {
          _audioHandler.setSleepFadeMultiplier(1.0);
        }
      } else {
        cancelSleepTimer();
        _audioHandler.pause();
        _audioHandler.resetSleepFade();
      }
    });
  }

  void setSleepAtTrackEnd(bool enable) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepSecondsRemaining = 0;
    sleepSecondsNotifier.value = 0;
    _sleepAtTrackEnd = enable;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepSecondsRemaining = 0;
    sleepSecondsNotifier.value = 0;
    _sleepAtTrackEnd = false;
    _audioHandler.resetSleepFade();
    notifyListeners();
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    _crossfadeSeconds = seconds.clamp(0, 12);
    await _storageService.saveCrossfadeSeconds(_crossfadeSeconds);
    await _audioHandler.setCrossfadeSeconds(_crossfadeSeconds);
    notifyListeners();
  }

  Future<void> setGaplessPlayback(bool enabled) async {
    _gaplessPlayback = enabled;
    await _storageService.saveGaplessPlayback(enabled);
    await _audioHandler.setGaplessPlayback(enabled);
    notifyListeners();
  }

  Future<void> setPitchSemitones(int semitones) async {
    _pitchSemitones = semitones.clamp(-6, 6);
    final pitchFactor = math.pow(2.0, _pitchSemitones / 12.0).toDouble();
    await _audioHandler.setPitch(pitchFactor);
    notifyListeners();
  }

  Future<void> setVolumeNormalizationEnabled(bool enabled) async {
    _volumeNormalizationEnabled = enabled;
    await _audioHandler.setNormalizationGain(enabled ? 0.85 : 1.0);
    notifyListeners();
  }

  Future<void> updateSongMetadata(Song updatedSong) async {
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].id == updatedSong.id) {
        _queue[i] = updatedSong;
      }
    }
    if (currentSong?.id == updatedSong.id) {
      await _audioHandler.updateSongMediaItem(updatedSong);
    }
    final favIdx = _favorites.indexWhere((s) => s.id == updatedSong.id);
    if (favIdx != -1) {
      _favorites[favIdx] = updatedSong;
      await _storageService.saveFavorites(_favorites);
    }
    final histIdx = _history.indexWhere((s) => s.id == updatedSong.id);
    if (histIdx != -1) {
      _history[histIdx] = updatedSong;
      await _storageService.saveHistory(_history);
    }
    notifyListeners();
  }

  String exportLibraryBackup() {
    return _storageService.exportBackupJson();
  }

  Future<({int playlistsCount, int favoritesCount, int historyCount})?> importLibraryBackup(
    String jsonStr, {
    bool merge = true,
  }) async {
    final result = await _storageService.importBackupJson(jsonStr, merge: merge);
    if (result != null) {
      _playlists = _storageService.loadPlaylists();
      _favorites = _storageService.loadFavorites();
      _history = _storageService.loadHistory();
      notifyListeners();
    }
    return result;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioHandler.setNavigationCallbacks();
    playbackErrorNotifier.dispose();
    positionNotifier.dispose();
    activeLyricIndexNotifier.dispose();
    sleepSecondsNotifier.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _sleepTimer?.cancel();
    _bandSaveTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }
}
