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

enum IsolationMode {
  none,
  vocalsOnly,
  instrumentsOnly,
}

class PlayerProvider extends ChangeNotifier {
  final SineAudioHandler _audioHandler;
  final StorageService _storageService;

  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  bool _isShuffle = false;
  List<Song> _unshuffledQueue = [];
  String _repeatMode = 'off'; // 'off', 'all', 'one'
  String _activeTab = 'queue'; // 'queue', 'playlists', 'favorites', 'downloads', 'history'
  String _activeCategory = 'trending';
  String _playingFrom = 'Trending';

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


  LyricsResult _lyrics = LyricsResult.empty;
  bool _isLoadingLyrics = false;
  bool _isLoadingStream = false;
  int _playSessionId = 0;
  Song? _lastFailedSong;
  Song? get lastFailedSong => _lastFailedSong;
  final ValueNotifier<Song?> playbackErrorNotifier = ValueNotifier<Song?>(null);

  Timer? _sleepTimer;
  int _sleepSecondsRemaining = 0;
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

  int get currentLyricIndex {
    if (_lyrics.syncedLyrics.isEmpty) return -1;
    final pos = _position;
    for (int i = _lyrics.syncedLyrics.length - 1; i >= 0; i--) {
      if (pos >= _lyrics.syncedLyrics[i].timestamp) {
        return i;
      }
    }
    return -1;
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

    // Apply saved EQ preset & settings
    _audioHandler.setEqualizerEnabled(_eqEnabled);
    _audioHandler.setBassBoost(_bassBoost);
    _audioHandler.applyEqualizerPreset(_eqPreset);
    _audioHandler.setSpeed(_speed);
    _audioHandler.setPlayerRepeatMode(_repeatMode);
    if (_eqPreset == 'Vocals Only') {
      _isolationMode = IsolationMode.vocalsOnly;
    } else if (_eqPreset == 'Instruments Only') {
      _isolationMode = IsolationMode.instrumentsOnly;
    }
    if (_eqPreset == 'Custom' && _bandGains.isNotEmpty) {
      for (final entry in _bandGains.entries) {
        _audioHandler.setBandGain(entry.key, entry.value);
      }
    }

    // Ensure all restored lists are completely free of legacy mock/placeholder tracks
    _favorites = _favorites.where((s) => !Song.isPlaceholder(s)).toList();
    _history = _history.where((s) => !Song.isPlaceholder(s)).toList();
    _downloads = _downloads.where((s) => !Song.isPlaceholder(s)).toList();
    _playlists = _playlists
        .map((p) => p.copyWith(songs: p.songs.where((s) => !Song.isPlaceholder(s)).toList()))
        .toList();

    // Restore previous queue from history or offline downloads, avoiding mock placeholder tracks
    if (_history.isNotEmpty) {
      _queue = List.from(_history.take(20));
    } else if (_downloads.isNotEmpty) {
      _queue = List.from(_downloads);
    } else {
      _queue = [];
    }

    // Load initial trending discovery tracks
    _loadInitialDiscoveryTracks();

    // Listen to player streams with throttled position notifications to prevent UI jank
    int lastNotifiedSec = -1;
    DateTime lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
    _posSub = _audioHandler.player.positionStream.listen((pos) {
      if (_isScrubbing) return;
      _position = pos;
      final now = DateTime.now();
      if (pos.inSeconds != lastNotifiedSec || now.difference(lastNotifyTime).inMilliseconds >= 300) {
        lastNotifiedSec = pos.inSeconds;
        lastNotifyTime = now;
        notifyListeners();
      }
    });

    _durSub = _audioHandler.player.durationStream.listen((dur) {
      if (dur != null) {
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
        notifyListeners();
      }
    });
  }

  Future<void> _handleSongCompleted() async {
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

  Future<void> playSong(Song song, {List<Song>? contextQueue, bool isAutoAdvance = false, String? playingFrom}) async {
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
    _position = Duration.zero;
    _duration = song.duration;
    _isPlaying = true;
    _isLoadingStream = true;
    _isLoadingStem = false;
    _isStudioStemActive = false;
    _stemStatusBadgeText = null;
    _isolationMode = IsolationMode.none;
    _originalStreamCache.remove(song.id);
    notifyListeners();

    final thisSession = ++_playSessionId;

    // Offline interception: if this song was downloaded to disk, play offline seamlessly
    Song resolvedSong = song;
    final downloadedIndex = _downloads.indexWhere((d) => d.id == song.id);
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

    await _audioHandler.playSong(resolvedSong);
    if (_playSessionId != thisSession) {
      // Newer song selection superseded this one; discard outdated state updates
      return;
    }
    _isLoadingStream = false;
    notifyListeners();
    if (_isMixActive) {
      _fetchMoreMixTracksIfNeeded();
    }
    if (_isRadioActive) {
      _fetchMoreRadioTracksIfNeeded();
    }
  }

  Future<void> _loadLyrics(Song song) async {
    _isLoadingLyrics = true;
    _lyrics = LyricsResult.empty;
    notifyListeners();

    try {
      final res = await LyricsService.fetchLyrics(song.title, song.artist);
      if (currentSong?.id == song.id) {
        _lyrics = res;
        _isLoadingLyrics = false;
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

  // Queue manipulation
  void playNext(Song song) {
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

  Future<void> playPlaylist(Playlist playlist, {int startIndex = 0}) async {
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
    return _downloads.any((s) => s.id == songId);
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
    final idx = _downloads.indexWhere((s) => s.id == songId);
    if (idx != -1) {
      final songToRemove = _downloads[idx];
      if (currentSong?.id == songId) {
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
  Future<void> setEqualizerPreset(String preset) async {
    _eqPreset = preset;
    if (preset != 'Vocals Only' && preset != 'Instruments Only') {
      _isolationMode = IsolationMode.none;
    }
    await _storageService.saveEqualizerPreset(preset);
    await _audioHandler.applyEqualizerPreset(preset);
    notifyListeners();
  }

  Future<void> toggleIsolationMode(IsolationMode mode) async {
    if (_isolationMode == mode) {
      await revertToOriginalTrack();
      return;
    }

    _isolationMode = mode;
    _isLoadingStem = true;
    _stemStatusBadgeText = mode == IsolationMode.instrumentsOnly
        ? 'Resolving Studio Karaoke...'
        : 'Resolving Studio Acapella...';
    notifyListeners();

    final song = currentSong;
    if (song == null) {
      _isLoadingStem = false;
      _stemStatusBadgeText = null;
      notifyListeners();
      return;
    }

    // Cache current original stream URL for instantaneous 0ms reversion
    if (!_originalStreamCache.containsKey(song.id) && _audioHandler.activeStreamUrl != null) {
      _originalStreamCache[song.id] = _audioHandler.activeStreamUrl!;
    }

    try {
      final stemType = mode == IsolationMode.instrumentsOnly
          ? StemType.instrumental
          : StemType.vocals;

      final stemResult = await StemService.instance.resolveStem(
        song: song,
        type: stemType,
        targetDuration: _duration > Duration.zero ? _duration : song.duration,
      );

      if (currentSong?.id != song.id) {
        // Track switched while stem resolution was in flight; abort
        return;
      }

      if (stemResult.isStudioStem && stemResult.streamUrl != null) {
        _isStudioStemActive = true;
        _stemStatusBadgeText = mode == IsolationMode.instrumentsOnly
            ? (stemResult.isLocal ? 'Offline Studio Karaoke' : 'Studio Karaoke (Synced)')
            : (stemResult.isLocal ? 'Offline Studio Acapella' : 'Studio Acapella (Synced)');

        // Clear heavy EQ notch since we now have dedicated studio stem audio
        await _audioHandler.applyEqualizerPreset('Flat');
        await _audioHandler.setEqualizerEnabled(false);

        // Swap ExoPlayer audio stream seamlessly at exact current position
        await _audioHandler.swapAudioStream(
          stemResult.streamUrl!,
          currentPosition: _position,
          playImmediately: _isPlaying,
          isLocal: stemResult.isLocal,
        );
      } else {
        // Fallback: apply deep hardware DSP notch filter + psychoacoustic frequency masking
        _isStudioStemActive = false;
        _stemStatusBadgeText = mode == IsolationMode.instrumentsOnly
            ? 'DSP Vocal Shaper'
            : 'DSP Vocal Boost';

        _eqEnabled = true;
        await _storageService.saveEqualizerEnabled(true);
        await _audioHandler.setEqualizerEnabled(true);

        final presetName = mode == IsolationMode.vocalsOnly ? 'Vocals Only' : 'Instruments Only';
        _eqPreset = presetName;
        await _storageService.saveEqualizerPreset(presetName);
        await _audioHandler.applyIsolationFilter(vocalsOnly: mode == IsolationMode.vocalsOnly);

        try {
          final params = await _audioHandler.equalizer.parameters;
          for (int i = 0; i < params.bands.length; i++) {
            _bandGains[i] = params.bands[i].gain;
          }
          await _storageService.saveBandGains(_bandGains);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PlayerProvider] Stem toggle error: $e');
      _stemStatusBadgeText = 'DSP Fallback';
      await _audioHandler.applyIsolationFilter(vocalsOnly: mode == IsolationMode.vocalsOnly);
    } finally {
      _isLoadingStem = false;
      notifyListeners();
    }
  }

  Future<void> revertToOriginalTrack() async {
    _isolationMode = IsolationMode.none;
    _isStudioStemActive = false;
    _stemStatusBadgeText = null;
    _isLoadingStem = false;

    await setEqualizerPreset('Flat');
    await setEqualizerEnabled(false);

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
            currentPosition: _position,
            playImmediately: _isPlaying,
          );
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
    await _storageService.saveBandGains(_bandGains);
    await _storageService.saveEqualizerPreset('Custom');
    await _audioHandler.setBandGain(index, gain);
    notifyListeners();
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
    _sleepSecondsRemaining = minutes * 60;
    notifyListeners();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (_sleepSecondsRemaining > 0) {
        _sleepSecondsRemaining--;
        if (!_isDisposed) notifyListeners();
      } else {
        cancelSleepTimer();
        _audioHandler.pause();
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepSecondsRemaining = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioHandler.setNavigationCallbacks();
    playbackErrorNotifier.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _sleepTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }
}
