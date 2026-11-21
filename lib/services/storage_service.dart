import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/downloaded_video.dart';
import 'download_service.dart';

class StorageService {
  static const String _favsKey = 'sine_favorites_v1';
  static const String _favsLegacyKey = 'ember_favorites_v1';
  static const String _histKey = 'sine_history_v1';
  static const String _histLegacyKey = 'ember_history_v1';
  static const String _speedKey = 'sine_playback_speed';
  static const String _speedLegacyKey = 'ember_playback_speed';
  static const String _playlistsKey = 'sine_playlists_v1';
  static const String _playlistsLegacyKey = 'ember_playlists_v1';
  static const String _downloadsKey = 'sine_downloads_v1';
  static const String _downloadsLegacyKey = 'ember_downloads_v1';
  static const String _videosKey = 'sine_downloaded_videos_v1';
  static const String _eqPresetKey = 'sine_eq_preset';
  static const String _eqPresetLegacyKey = 'ember_eq_preset';
  static const String _eqEnabledKey = 'sine_eq_enabled';
  static const String _eqEnabledLegacyKey = 'ember_eq_enabled';
  static const String _eqBassBoostKey = 'sine_eq_bass_boost';
  static const String _eqBassBoostLegacyKey = 'ember_eq_bass_boost';
  static const String _eqBandGainsKey = 'sine_eq_band_gains';
  static const String _eqBandGainsLegacyKey = 'ember_eq_band_gains';
  static const String _repeatModeKey = 'sine_repeat_mode';
  static const String _repeatModeLegacyKey = 'pulsepipe_repeat_mode';
  static const String _shuffleKey = 'sine_shuffle';
  static const String _shuffleLegacyKey = 'pulsepipe_shuffle';

  static const String _autoplayKey = 'sine_autoplay_smart_radio';
  static const String _autoplayLegacyKey = 'pulsepipe_autoplay_smart_radio';

  static const String _searchesKey = 'sine_recent_searches_v1';
  static const String _searchesLegacyKey = 'ember_recent_searches_v1';
  static const String _crossfadeKey = 'sine_crossfade_seconds';
  static const String _gaplessKey = 'sine_gapless_playback';
  static const String _clippingProtectionKey = 'sine_clipping_protection';
  static const String _recoveryModeKey = 'sine_playback_recovery_mode';
  static const String _savedSessionKey = 'sine_saved_playback_session';
  static const String _savedQueueKey = 'sine_saved_queue_tracks';
  static const String _stemEngineKey = 'sine_stem_engine_preference';
  static const String _performanceHudKey = 'sine_performance_hud_enabled';
  static const String _themePresetKey = 'sine_theme_preset_v1';
  static const String _customThemeColorKey = 'sine_custom_theme_color_v1';
  static const String _oledBlackKey = 'sine_oled_black_mode_v1';
  static const String _loudnessNormalizationKey = 'sine_loudness_normalization';
  static const String _skipSilenceKey = 'sine_skip_silence';
  static const String _acousticPresetKey = 'sine_acoustic_preset';
  static const String _bassExciterKey = 'sine_bass_exciter';
  static const String _spatializerKey = 'sine_spatializer';
  static const String _shakeToSkipKey = 'sine_shake_to_skip';
  static const String _flipToPauseKey = 'sine_flip_to_pause';

  final SharedPreferences? _prefs;
  final List<Song> _memFavorites = [];
  final List<Song> _memHistory = [];
  final List<Playlist> _memPlaylists = [];
  final List<Song> _memDownloads = [];
  final List<DownloadedVideo> _memDownloadedVideos = [];
  final List<String> _memSearches = [];
  double _memSpeed = 1.0;

  static String? _safeJsonEncode(Map<String, dynamic> map) {
    try {
      return jsonEncode(map);
    } catch (e) {
      return null;
    }
  }

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[StorageService] SharedPreferences.getInstance failed: $e');
    }

    final service = StorageService(prefs);
    try {
      await service.purgeAllPlaceholders();
    } catch (e) {
      debugPrint('[StorageService] Error purging placeholders (non-fatal): $e');
    }
    return service;
  }

  /// Purges all legacy mock / placeholder songs from all storage keys permanently
  Future<void> purgeAllPlaceholders() async {
    final favs = loadFavorites();
    await saveFavorites(favs);

    final hist = loadHistory();
    await saveHistory(hist);

    final pl = loadPlaylists();
    await savePlaylists(pl);

    final dl = loadDownloads();
    await saveDownloads(dl);
  }

  List<Song> loadFavorites() {
    if (_prefs == null) {
      return List<Song>.from(_memFavorites.where((s) => !Song.isPlaceholder(s)));
    }
    final raw = _prefs.getStringList(_favsKey) ?? _prefs.getStringList(_favsLegacyKey) ?? [];
    final cleaned = <Song>[];
    bool hadPlaceholders = false;

    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is! Map) continue;
        final song = Song.fromMap(Map<String, dynamic>.from(decoded));
        if (Song.isPlaceholder(song)) {
          hadPlaceholders = true;
        } else {
          cleaned.add(song);
        }
      } catch (e) {
        debugPrint('[StorageService] Skipped corrupt favorite entry: $e');
      }
    }

    _memFavorites.clear();
    _memFavorites.addAll(cleaned);

    if (hadPlaceholders) {
      final encoded = cleaned.map((s) => _safeJsonEncode(s.toMap())).whereType<String>().toList();
      _prefs.setStringList(_favsKey, encoded);
    }

    return cleaned;
  }

  Future<void> saveFavorites(List<Song> songs) async {
    final cleaned = songs.where((s) => !Song.isPlaceholder(s)).toList();
    _memFavorites.clear();
    _memFavorites.addAll(cleaned);
    if (_prefs != null) {
      final encoded = cleaned.map((s) => _safeJsonEncode(s.toMap())).whereType<String>().toList();
      await _prefs.setStringList(_favsKey, encoded);
    }
  }

  List<Song> loadHistory() {
    if (_prefs == null) {
      return List<Song>.from(_memHistory.where((s) => !Song.isPlaceholder(s)));
    }
    final raw = _prefs.getStringList(_histKey) ?? _prefs.getStringList(_histLegacyKey) ?? [];
    final cleaned = <Song>[];
    bool hadPlaceholders = false;

    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is! Map) continue;
        final song = Song.fromMap(Map<String, dynamic>.from(decoded));
        if (Song.isPlaceholder(song)) {
          hadPlaceholders = true;
        } else {
          cleaned.add(song);
        }
      } catch (e) {
        debugPrint('[StorageService] Skipped corrupt history entry: $e');
      }
    }

    _memHistory.clear();
    _memHistory.addAll(cleaned);

    if (hadPlaceholders) {
      final encoded = cleaned.map((s) => _safeJsonEncode(s.toMap())).whereType<String>().toList();
      _prefs.setStringList(_histKey, encoded);
    }

    return cleaned;
  }

  Future<void> saveHistory(List<Song> songs) async {
    final cleaned = songs.where((s) => !Song.isPlaceholder(s)).take(200).toList();
    _memHistory.clear();
    _memHistory.addAll(cleaned);
    if (_prefs != null) {
      final encoded = cleaned.map((s) => _safeJsonEncode(s.toMap())).whereType<String>().toList();
      await _prefs.setStringList(_histKey, encoded);
    }
  }

  Future<void> clearHistory() async {
    _memHistory.clear();
    if (_prefs != null) {
      await _prefs.remove(_histKey);
    }
  }

  List<Playlist> loadPlaylists() {
    if (_prefs == null) {
      return List<Playlist>.from(_memPlaylists);
    }
    final raw = _prefs.getStringList(_playlistsKey) ?? _prefs.getStringList(_playlistsLegacyKey) ?? [];
    final list = <Playlist>[];
    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is! Map) continue;
        final pl = Playlist.fromMap(Map<String, dynamic>.from(decoded));
        final sanitizedSongs = pl.songs.where((song) => !Song.isPlaceholder(song)).toList();
        list.add(pl.copyWith(songs: sanitizedSongs));
      } catch (_) {}
    }

    _memPlaylists.clear();
    _memPlaylists.addAll(list);

    return list;
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    _memPlaylists.clear();
    _memPlaylists.addAll(playlists);
    if (_prefs != null) {
      final encoded = playlists.map((p) => _safeJsonEncode(p.toMap())).whereType<String>().toList();
      await _prefs.setStringList(_playlistsKey, encoded);
    }
  }

  Future<void> savePlaylist(Playlist playlist) async {
    final list = List<Playlist>.from(loadPlaylists());
    final idx = list.indexWhere((p) => p.id == playlist.id);
    if (idx != -1) {
      list[idx] = playlist;
    } else {
      list.insert(0, playlist);
    }
    await savePlaylists(list);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final list = List<Playlist>.from(loadPlaylists());
    list.removeWhere((p) => p.id == playlistId);
    await savePlaylists(list);
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    if (Song.isPlaceholder(song)) return;
    final list = List<Playlist>.from(loadPlaylists());
    final idx = list.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final existing = list[idx];
      if (!existing.songs.any((s) => s.id == song.id)) {
        final updatedSongs = List<Song>.from(existing.songs)..add(song);
        final updated = existing.copyWith(
          songs: updatedSongs,
          coverUrl: existing.coverUrl?.isNotEmpty == true
              ? existing.coverUrl
              : (song.artworkUrl.isNotEmpty ? song.artworkUrl : null),
        );
        list[idx] = updated;
        await savePlaylists(list);
      }
    }
  }

  List<Song> loadDownloads() {
    if (_prefs == null) {
      return List<Song>.from(_memDownloads.where((s) => !Song.isPlaceholder(s)));
    }
    var raw = _prefs.getStringList(_downloadsKey);
    if (raw == null || raw.isEmpty) {
      final legacy = _prefs.getStringList(_downloadsLegacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        raw = legacy;
      } else {
        raw = [];
      }
    }
    final cleaned = <Song>[];
    bool hadPlaceholders = false;

    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is! Map) continue;
        final song = Song.fromMap(Map<String, dynamic>.from(decoded));
        if (song.source == 'download' || !Song.isPlaceholder(song)) {
          cleaned.add(song);
        } else {
          hadPlaceholders = true;
        }
      } catch (e) {
        debugPrint('[StorageService] Skipped corrupt download entry: $e');
      }
    }

    _memDownloads.clear();
    _memDownloads.addAll(cleaned);

    if (hadPlaceholders) {
      final encoded = cleaned.map((s) => _safeJsonEncode(s.toMap())).whereType<String>().toList();
      _prefs.setStringList(_downloadsKey, encoded);
    }

    return cleaned;
  }

  Future<void> saveDownloads(List<Song> songs) async {
    final cleaned = songs.where((s) => !Song.isPlaceholder(s)).toList();
    _memDownloads.clear();
    _memDownloads.addAll(cleaned);
    if (_prefs != null) {
      final encoded = cleaned.map((s) => _safeJsonEncode(s.toMap())).whereType<String>().toList();
      await _prefs.setStringList(_downloadsKey, encoded);
    }
  }

  List<DownloadedVideo> loadDownloadedVideos() {
    if (_prefs == null) {
      return List<DownloadedVideo>.from(_memDownloadedVideos);
    }
    final raw = _prefs.getStringList(_videosKey) ?? [];
    final list = <DownloadedVideo>[];
    for (final s in raw) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        list.add(DownloadedVideo.fromMap(map));
      } catch (e) {
        debugPrint('[StorageService] Error parsing downloaded video: $e');
      }
    }
    _memDownloadedVideos.clear();
    _memDownloadedVideos.addAll(list);
    return list;
  }

  Future<void> saveDownloadedVideos(List<DownloadedVideo> videos) async {
    _memDownloadedVideos.clear();
    _memDownloadedVideos.addAll(videos);
    if (_prefs != null) {
      final encoded = videos.map((v) => _safeJsonEncode(v.toMap())).whereType<String>().toList();
      await _prefs.setStringList(_videosKey, encoded);
    }
  }

  Future<void> deleteDownloadedVideo(String id) async {
    final list = loadDownloadedVideos();
    final item = list.firstWhere((v) => v.id == id, orElse: () => list.first);
    if (item.filePath.isNotEmpty) {
      try {
        final f = File(item.filePath);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    final updated = list.where((v) => v.id != id).toList();
    await saveDownloadedVideos(updated);
  }

  String loadRepeatMode() {
    return _prefs?.getString(_repeatModeKey) ?? _prefs?.getString(_repeatModeLegacyKey) ?? 'off';
  }

  Future<void> saveRepeatMode(String mode) async {
    await _prefs?.setString(_repeatModeKey, mode);
  }

  bool loadShuffle() {
    return _prefs?.getBool(_shuffleKey) ?? _prefs?.getBool(_shuffleLegacyKey) ?? false;
  }

  Future<void> saveShuffle(bool shuffle) async {
    await _prefs?.setBool(_shuffleKey, shuffle);
  }

  double loadPlaybackSpeed() {
    return _prefs?.getDouble(_speedKey) ?? _prefs?.getDouble(_speedLegacyKey) ?? _memSpeed;
  }

  Future<void> savePlaybackSpeed(double speed) async {
    _memSpeed = speed;
    await _prefs?.setDouble(_speedKey, speed);
  }

  String loadEqualizerPreset() {
    final p = _prefs?.getString(_eqPresetKey) ?? _prefs?.getString(_eqPresetLegacyKey) ?? 'Flat';
    if (p == 'Vocals Only' || p == 'Instruments Only') {
      return 'Flat';
    }
    return p;
  }

  Future<void> saveEqualizerPreset(String preset) async {
    await _prefs?.setString(_eqPresetKey, preset);
  }

  bool loadEqualizerEnabled() {
    return _prefs?.getBool(_eqEnabledKey) ?? _prefs?.getBool(_eqEnabledLegacyKey) ?? false;
  }

  Future<void> saveEqualizerEnabled(bool enabled) async {
    await _prefs?.setBool(_eqEnabledKey, enabled);
  }

  double loadBassBoost() {
    return _prefs?.getDouble(_eqBassBoostKey) ?? _prefs?.getDouble(_eqBassBoostLegacyKey) ?? 0.0;
  }

  Future<void> saveBassBoost(double gain) async {
    await _prefs?.setDouble(_eqBassBoostKey, gain);
  }

  bool loadAutoplayEnabled() {
    return _prefs?.getBool(_autoplayKey) ?? _prefs?.getBool(_autoplayLegacyKey) ?? true;
  }

  Future<void> saveAutoplayEnabled(bool enabled) async {
    await _prefs?.setBool(_autoplayKey, enabled);
  }

    Map<int, double> loadBandGains() {
    final raw = _prefs?.getString(_eqBandGainsKey) ?? _prefs?.getString(_eqBandGainsLegacyKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final result = <int, double>{};
        for (final entry in decoded.entries) {
          final k = int.tryParse(entry.key.toString());
          final v = (entry.value as num?)?.toDouble();
          if (k != null && v != null) {
            result[k] = v;
          }
        }
        return result;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveBandGains(Map<int, double> gains) async {
    final stringMap = gains.map((k, v) => MapEntry(k.toString(), v));
    await _prefs?.setString(_eqBandGainsKey, jsonEncode(stringMap));
  }

  List<String> loadRecentSearches() {
    if (_prefs == null) {
      return List<String>.from(_memSearches);
    }
    final raw = _prefs.getStringList(_searchesKey) ?? _prefs.getStringList(_searchesLegacyKey) ?? [];
    final cleaned = raw
        .where((s) => s.trim().isNotEmpty && s != 'null')
        .map((s) => s.trim())
        .toSet()
        .toList();
    _memSearches.clear();
    _memSearches.addAll(cleaned);
    return cleaned;
  }

  Future<void> saveRecentSearches(List<String> searches) async {
    final cleaned = searches
        .where((s) => s.trim().isNotEmpty && s != 'null')
        .map((s) => s.trim())
        .take(40)
        .toList();
    _memSearches.clear();
    _memSearches.addAll(cleaned);
    await _prefs?.setStringList(_searchesKey, cleaned);
  }

  Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final current = loadRecentSearches();
    current.removeWhere((q) => q.toLowerCase() == clean.toLowerCase());
    current.insert(0, clean);
    await saveRecentSearches(current);
  }

  Future<void> clearRecentSearches() async {
    _memSearches.clear();
    await _prefs?.remove(_searchesKey);
  }

  int loadCrossfadeSeconds() {
    return _prefs?.getInt(_crossfadeKey) ?? 0;
  }

  Future<void> saveCrossfadeSeconds(int seconds) async {
    await _prefs?.setInt(_crossfadeKey, seconds);
  }

  bool loadGaplessPlayback() {
    return _prefs?.getBool(_gaplessKey) ?? true;
  }

  Future<void> saveGaplessPlayback(bool enabled) async {
    await _prefs?.setBool(_gaplessKey, enabled);
  }

  // Audio Quality Preset (high, medium, dataSaver)

  // Audio Clipping Protection
  bool loadClippingProtection() {
    return _prefs?.getBool(_clippingProtectionKey) ?? true;
  }

  Future<void> saveClippingProtection(bool enabled) async {
    await _prefs?.setBool(_clippingProtectionKey, enabled);
  }

  // Playback Recovery Mode (prompt, always, off)
  String loadPlaybackRecoveryMode() {
    return _prefs?.getString(_recoveryModeKey) ?? 'prompt';
  }

  Future<void> savePlaybackRecoveryMode(String mode) async {
    await _prefs?.setString(_recoveryModeKey, mode);
  }

  // Saved Session Persistence
  Map<String, dynamic>? loadSavedSession() {
    final raw = _prefs?.getString(_savedSessionKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSavedSession(Map<String, dynamic> session) async {
    await _prefs?.setString(_savedSessionKey, jsonEncode(session));
  }

  Future<void> clearSavedSession() async {
    await _prefs?.remove(_savedSessionKey);
  }

  // Saved Queue Tracks
  List<Song> loadSavedQueue() {
    final raw = _prefs?.getStringList(_savedQueueKey) ?? [];
    final songs = <Song>[];
    for (final s in raw) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          final song = Song.fromMap(Map<String, dynamic>.from(decoded));
          if (!Song.isPlaceholder(song)) songs.add(song);
        }
      } catch (_) {}
    }
    return songs;
  }

  Future<void> saveSavedQueue(List<Song> queue) async {
    final list = queue
        .where((s) => !Song.isPlaceholder(s))
        .map((s) => jsonEncode(s.toMap()))
        .toList();
    await _prefs?.setStringList(_savedQueueKey, list);
  }

  // Stem AI Engine Preference (auto, bsRoformer, demucs, youtube, dsp)
  String loadStemEnginePreference() {
    return _prefs?.getString(_stemEngineKey) ?? 'auto';
  }

  Future<void> saveStemEnginePreference(String engine) async {
    await _prefs?.setString(_stemEngineKey, engine);
  }

  // Performance HUD Overlay
  bool loadPerformanceHudEnabled() {
    return _prefs?.getBool(_performanceHudKey) ?? false;
  }

  Future<void> savePerformanceHudEnabled(bool enabled) async {
    await _prefs?.setBool(_performanceHudKey, enabled);
  }

  // Loudness Normalization (EBU R128)
  bool loadLoudnessNormalization() {
    return _prefs?.getBool(_loudnessNormalizationKey) ?? true;
  }

  Future<void> saveLoudnessNormalization(bool enabled) async {
    await _prefs?.setBool(_loudnessNormalizationKey, enabled);
  }

  // Skip Silence / Dead Air Trimming
  bool loadSkipSilence() {
    return _prefs?.getBool(_skipSilenceKey) ?? false;
  }

  Future<void> saveSkipSilence(bool enabled) async {
    await _prefs?.setBool(_skipSilenceKey, enabled);
  }

  // Acoustic Preset (normal, slowedReverb, nightcore)
  String loadAcousticPreset() {
    return _prefs?.getString(_acousticPresetKey) ?? 'normal';
  }

  Future<void> saveAcousticPreset(String preset) async {
    await _prefs?.setString(_acousticPresetKey, preset);
  }

  // Dynamic Bass Exciter (0.0 to 1.0)
  double loadBassExciter() {
    return _prefs?.getDouble(_bassExciterKey) ?? 0.0;
  }

  Future<void> saveBassExciter(double val) async {
    await _prefs?.setDouble(_bassExciterKey, val);
  }

  // 3D Spatializer (0.0 to 1.0)
  double loadSpatializer() {
    return _prefs?.getDouble(_spatializerKey) ?? 0.0;
  }

  Future<void> saveSpatializer(double val) async {
    await _prefs?.setDouble(_spatializerKey, val);
  }

  // Shake to Skip
  bool loadShakeToSkip() {
    return _prefs?.getBool(_shakeToSkipKey) ?? false;
  }

  Future<void> saveShakeToSkip(bool enabled) async {
    await _prefs?.setBool(_shakeToSkipKey, enabled);
  }

  // Flip to Pause
  bool loadFlipToPause() {
    return _prefs?.getBool(_flipToPauseKey) ?? false;
  }

  Future<void> saveFlipToPause(bool enabled) async {
    await _prefs?.setBool(_flipToPauseKey, enabled);
  }

  /// Collects ALL app settings into a strictly JSON-safe Map (all Map keys are String).
  Map<String, dynamic> _collectSettingsMap() {
    // CRITICAL FIX: Map<int, double> from loadBandGains() MUST have String keys for JSON encoding!
    final stringBandGains = loadBandGains().map((k, v) => MapEntry(k.toString(), v));
    return {
      'speed': loadPlaybackSpeed(),
      'crossfade': loadCrossfadeSeconds(),
      'gapless': loadGaplessPlayback(),
      'clippingProtection': loadClippingProtection(),
      'loudnessNormalization': loadLoudnessNormalization(),
      'skipSilence': loadSkipSilence(),
      'autoplay': loadAutoplayEnabled(),
      'repeatMode': loadRepeatMode(),
      'shuffle': loadShuffle(),
      'recoveryMode': loadPlaybackRecoveryMode(),
      'stemEngine': loadStemEnginePreference(),
      'eqPreset': loadEqualizerPreset(),
      'eqEnabled': loadEqualizerEnabled(),
      'eqBassBoost': loadBassBoost(),
      'eqBandGains': stringBandGains,
      'acousticPreset': loadAcousticPreset(),
      'bassExciter': loadBassExciter(),
      'spatializer': loadSpatializer(),
      'themePreset': loadThemePreset(),
      'customThemeColor': loadCustomThemeColor(),
      'oledBlack': loadOledBlack(),
      'flipToPause': loadFlipToPause(),
      'shakeToSkip': loadShakeToSkip(),
    };
  }

  /// Applies a decoded settings Map safely to SharedPreferences.
  Future<void> _applySettingsMap(Map settings) async {
    double? toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    int? toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
    bool? toBool(dynamic v) {
      if (v is bool) return v;
      if (v == 'true' || v == 1) return true;
      if (v == 'false' || v == 0) return false;
      return null;
    }

    final speed = toDouble(settings['speed']);
    if (speed != null) await savePlaybackSpeed(speed.clamp(0.5, 2.0));
    final crossfade = toInt(settings['crossfade']);
    if (crossfade != null) await saveCrossfadeSeconds(crossfade.clamp(0, 12));
    final gapless = toBool(settings['gapless']);
    if (gapless != null) await saveGaplessPlayback(gapless);
    final clipping = toBool(settings['clippingProtection']);
    if (clipping != null) await saveClippingProtection(clipping);
    final loudness = toBool(settings['loudnessNormalization']);
    if (loudness != null) await saveLoudnessNormalization(loudness);
    final skipSilence = toBool(settings['skipSilence']);
    if (skipSilence != null) await saveSkipSilence(skipSilence);
    final autoplay = toBool(settings['autoplay']);
    if (autoplay != null) await saveAutoplayEnabled(autoplay);
    if (settings['repeatMode'] != null) await saveRepeatMode(settings['repeatMode'].toString());
    final shuffle = toBool(settings['shuffle']);
    if (shuffle != null) await saveShuffle(shuffle);
    if (settings['recoveryMode'] != null) await savePlaybackRecoveryMode(settings['recoveryMode'].toString());
    if (settings['stemEngine'] != null) await saveStemEnginePreference(settings['stemEngine'].toString());
    if (settings['eqPreset'] != null) await saveEqualizerPreset(settings['eqPreset'].toString());
    final eqEnabled = toBool(settings['eqEnabled']);
    if (eqEnabled != null) await saveEqualizerEnabled(eqEnabled);
    final bassBoost = toDouble(settings['eqBassBoost']);
    if (bassBoost != null) await saveBassBoost(bassBoost);
    if (settings['eqBandGains'] is Map) {
      final gains = <int, double>{};
      for (final entry in (settings['eqBandGains'] as Map).entries) {
        final k = int.tryParse(entry.key.toString());
        final v = toDouble(entry.value);
        if (k != null && v != null) gains[k] = v;
      }
      await saveBandGains(gains);
    }
    if (settings['acousticPreset'] != null) await saveAcousticPreset(settings['acousticPreset'].toString());
    final bassExciter = toDouble(settings['bassExciter']);
    if (bassExciter != null) await saveBassExciter(bassExciter);
    final spatializer = toDouble(settings['spatializer']);
    if (spatializer != null) await saveSpatializer(spatializer);
    if (settings['themePreset'] != null) await saveThemePreset(settings['themePreset'].toString());
    final customColor = toInt(settings['customThemeColor']);
    if (customColor != null) await saveCustomThemeColor(customColor);
    final oled = toBool(settings['oledBlack']);
    if (oled != null) await saveOledBlack(oled);
    final flip = toBool(settings['flipToPause']);
    if (flip != null) await saveFlipToPause(flip);
    final shake = toBool(settings['shakeToSkip']);
    if (shake != null) await saveShakeToSkip(shake);
  }

  /// Writes a JSON payload using a resilient 4-tier storage strategy:
  /// 1. Public vault: /storage/emulated/0/Sine-Music/<subFolder>
  /// 2. Public Downloads: /storage/emulated/0/Download/Sine-<subFolder>
  /// 3. App External Storage (visible in File Managers without special permissions)
  /// 4. App Internal Documents (100% guaranteed writable fallback)
  Future<File?> _writeJsonToResilientStorage(
    String jsonStr,
    String fileName, {
    required String subFolder,
    bool writeLatestAlias = false,
  }) async {
    Future<File?> tryWrite(Directory dir) async {
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(jsonStr, flush: true);
        if (writeLatestAlias) {
          try {
            final latest = File('${dir.path}/sine_backup_latest.json');
            await latest.writeAsString(jsonStr, flush: true);
          } catch (_) {}
        }
        return file;
      } catch (e) {
        debugPrint('[StorageService] Write failed in ${dir.path}: $e');
        return null;
      }
    }

    // Tier 1: Primary media directory (/storage/emulated/0/Sine-Music/<subFolder>)
    try {
      final mediaDir = await DownloadService.getMediaDirectory(isVideo: false);
      final written = await tryWrite(Directory('${mediaDir.path}/$subFolder'));
      if (written != null) {
        debugPrint('[StorageService] Exported JSON to Tier 1: ${written.path}');
        return written;
      }
    } catch (e) {
      debugPrint('[StorageService] Tier 1 dir lookup failed: $e');
    }

    // Tier 2: Public Downloads folder on Android (/storage/emulated/0/Download/Sine-<subFolder>)
    if (Platform.isAndroid) {
      final dlWritten = await tryWrite(Directory('/storage/emulated/0/Download/Sine-$subFolder'));
      if (dlWritten != null) {
        debugPrint('[StorageService] Exported JSON to Tier 2 (Download): ${dlWritten.path}');
        return dlWritten;
      }

      // Tier 3: App External Storage (accessible via File Manager / USB without permissions)
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final extWritten = await tryWrite(Directory('${ext.path}/$subFolder'));
          if (extWritten != null) {
            debugPrint('[StorageService] Exported JSON to Tier 3 (External): ${extWritten.path}');
            return extWritten;
          }
        }
      } catch (_) {}
    }

    // Tier 4: App Documents /<subFolder> (Always writable on every OS)
    try {
      final docs = await getApplicationDocumentsDirectory();
      final docWritten = await tryWrite(Directory('${docs.path}/$subFolder'));
      if (docWritten != null) {
        debugPrint('[StorageService] Exported JSON to Tier 4 (Documents): ${docWritten.path}');
        return docWritten;
      }
      final rootWritten = await tryWrite(docs);
      if (rootWritten != null) return rootWritten;
    } catch (e) {
      debugPrint('[StorageService] Tier 4 Documents fallback failed: $e');
    }

    return null;
  }

  /// Exports full database backup into portable JSON format (Audile & Metrolist architecture)
  String exportBackupJson() {
    final payload = {
      'format': 'SINE_BACKUP',
      'version': AppConstants.version,
      'versionCode': AppConstants.buildNumber,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'playlists': loadPlaylists().map((p) => p.toMap()).toList(),
      'favorites': loadFavorites().map((s) => s.toMap()).toList(),
      'history': loadHistory().map((s) => s.toMap()).toList(),
      'settings': _collectSettingsMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports full database backup into a persistent JSON file in storage.
  Future<File?> exportBackupToFile({String? customFileName}) async {
    try {
      final jsonStr = exportBackupJson();
      final now = DateTime.now();
      final dateStr = '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';

      final fileName = customFileName ?? 'sine_backup_$dateStr.json';
      return await _writeJsonToResilientStorage(
        jsonStr,
        fileName,
        subFolder: 'Backups',
        writeLatestAlias: true,
      );
    } catch (e) {
      debugPrint('[StorageService] exportBackupToFile error: $e');
      return null;
    }
  }

  /// Exports standalone Settings JSON (Equalizer, Themes, Playback parameters)
  String exportSettingsJson() {
    final payload = {
      'format': 'SINE_SETTINGS',
      'version': AppConstants.version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': _collectSettingsMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports settings to a .json file with resilient multi-tier fallback
  Future<File?> exportSettingsToFile({String? customFileName}) async {
    try {
      final jsonStr = exportSettingsJson();
      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = customFileName ?? 'Sine_Settings_$stamp.json';
      return await _writeJsonToResilientStorage(
        jsonStr,
        fileName,
        subFolder: 'Backups',
      );
    } catch (e) {
      debugPrint('[StorageService] exportSettingsToFile error: $e');
      return null;
    }
  }

  /// Imports and applies Settings JSON
  Future<bool> importSettingsJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      final settings = (map['settings'] is Map ? map['settings'] : map) as Map;
      await _applySettingsMap(settings);
      return true;
    } catch (e) {
      debugPrint('[StorageService] Settings import error: $e');
      return false;
    }
  }

  /// Exports an individual song playlist into portable JSON format
  String exportPlaylistJson(Playlist playlist) {
    final payload = {
      'format': 'SINE_PLAYLIST',
      'version': AppConstants.version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'playlist': playlist.toMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Imports a single playlist from JSON string (supports SINE_PLAYLIST or raw playlist map)
  Future<Playlist?> importPlaylistJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      Map<String, dynamic>? rawPlaylist;
      if (map['playlist'] is Map) {
        rawPlaylist = Map<String, dynamic>.from(map['playlist']);
      } else if (map.containsKey('title') && map.containsKey('songs')) {
        rawPlaylist = map;
      }

      if (rawPlaylist == null) return null;

      final playlist = Playlist.fromMap(rawPlaylist);
      final uniqueId = playlist.id.isNotEmpty && playlist.id != 'liked_songs' && playlist.id != 'downloaded_songs'
          ? playlist.id
          : 'pl_${DateTime.now().millisecondsSinceEpoch}';

      final finalPlaylist = playlist.copyWith(id: uniqueId);
      final existing = loadPlaylists();
      final idx = existing.indexWhere((p) => p.id == finalPlaylist.id);
      if (idx != -1) {
        existing[idx] = finalPlaylist;
      } else {
        existing.add(finalPlaylist);
      }
      await savePlaylists(existing);
      return finalPlaylist;
    } catch (e) {
      debugPrint('[StorageService] importPlaylistJson error: $e');
      return null;
    }
  }

  /// Exports a playlist to a `.json` file in storage with resilient fallback
  Future<File?> exportPlaylistToFile(Playlist playlist, {String? customFileName}) async {
    try {
      final jsonStr = exportPlaylistJson(playlist);
      final sanitizedTitle = playlist.title.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
      final fileName = customFileName ?? 'playlist_${sanitizedTitle.isNotEmpty ? sanitizedTitle : "export"}.json';
      return await _writeJsonToResilientStorage(
        jsonStr,
        fileName,
        subFolder: 'Playlists',
      );
    } catch (e) {
      debugPrint('[StorageService] exportPlaylistToFile error: $e');
      return null;
    }
  }

  /// Lightweight format classifier for UI display badges (BACKUP / SETTINGS / PLAYLIST / JSON)
  static String detectJsonFormat(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final fmt = decoded['format']?.toString();
        if (fmt == 'SINE_BACKUP') return 'SINE_BACKUP';
        if (fmt == 'SINE_SETTINGS') return 'SINE_SETTINGS';
        if (fmt == 'SINE_PLAYLIST') return 'SINE_PLAYLIST';
        if (decoded.containsKey('playlists') || decoded.containsKey('favorites')) return 'SINE_BACKUP';
        if (decoded.containsKey('settings')) return 'SINE_SETTINGS';
        if (decoded.containsKey('playlist') || (decoded.containsKey('title') && decoded.containsKey('songs'))) {
          return 'SINE_PLAYLIST';
        }
      }
    } catch (_) {}
    return 'UNKNOWN';
  }

  /// Lightweight classifier for a backup/export file based on filename & header peek
  static String classifyBackupFile(File file) {
    final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
    if (name.contains('settings')) return 'SETTINGS';
    if (name.contains('playlist')) return 'PLAYLIST';
    if (name.contains('backup')) return 'BACKUP';
    try {
      final raf = file.openSync();
      final bytes = raf.readSync(256);
      raf.closeSync();
      final head = utf8.decode(bytes, allowMalformed: true);
      if (head.contains('SINE_SETTINGS')) return 'SETTINGS';
      if (head.contains('SINE_PLAYLIST')) return 'PLAYLIST';
      if (head.contains('SINE_BACKUP')) return 'BACKUP';
    } catch (_) {}
    return 'JSON';
  }

  /// Discovers existing backup, settings, and playlist JSON files across ALL storage tiers
  /// WITHOUT popping runtime permission dialogs!
  Future<List<File>> listAvailableBackupFiles() async {
    final results = <File>[];
    final seenPaths = <String>{};

    void scanDir(Directory dir, {bool filterSineOnly = false}) {
      try {
        if (!dir.existsSync()) return;
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
            final baseName = entity.path.split(Platform.pathSeparator).last.toLowerCase();
            if (filterSineOnly &&
                !baseName.contains('sine') &&
                !baseName.contains('backup') &&
                !baseName.contains('playlist') &&
                !baseName.contains('settings')) {
              continue;
            }
            final canonical = entity.path;
            if (!seenPaths.contains(canonical)) {
              seenPaths.add(canonical);
              results.add(entity);
            }
          }
        }
      } catch (e) {
        debugPrint('[StorageService] scanDir error in ${dir.path}: $e');
      }
    }

    try {
      if (Platform.isAndroid) {
        // Scan public storage paths directly (silent fail if permission not granted)
        scanDir(Directory('/storage/emulated/0/Sine-Music/Backups'));
        scanDir(Directory('/storage/emulated/0/Sine-Music/Playlists'));
        scanDir(Directory('/storage/emulated/0/Sine-Music'), filterSineOnly: true);
        scanDir(Directory('/storage/emulated/0/Download/Sine-Backups'));
        scanDir(Directory('/storage/emulated/0/Download/Sine-Playlists'));
        scanDir(Directory('/storage/emulated/0/Download'), filterSineOnly: true);
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            scanDir(Directory('${ext.path}/Backups'));
            scanDir(Directory('${ext.path}/Playlists'));
            scanDir(Directory('${ext.path}/Sine-Music/Backups'));
            scanDir(Directory('${ext.path}/Sine-Music/Playlists'));
          }
        } catch (_) {}
      }

      // Always scan App Documents directory (works on all OSes without permissions)
      try {
        final docs = await getApplicationDocumentsDirectory();
        scanDir(Directory('${docs.path}/Backups'));
        scanDir(Directory('${docs.path}/Playlists'));
        scanDir(Directory('${docs.path}/Sine-Music/Backups'));
        scanDir(Directory('${docs.path}/Sine-Music/Playlists'));
        scanDir(docs, filterSineOnly: true);
      } catch (_) {}

      // Sort newest modified first
      results.sort((a, b) {
        try {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        } catch (_) {
          return 0;
        }
      });
    } catch (e) {
      debugPrint('[StorageService] listAvailableBackupFiles error: $e');
    }
    return results;
  }

  /// Locates the primary backup directory cross-platform
  static Future<Directory> getBackupDirectory() async {
    try {
      final mediaDir = await DownloadService.getMediaDirectory(isVideo: false);
      final backupDir = Directory('${mediaDir.path}/Backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      return backupDir;
    } catch (e) {
      debugPrint('[StorageService] Primary backup dir error: $e. Falling back to documents.');
      final docs = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docs.path}/Backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      return backupDir;
    }
  }

  /// Imports backup from a File directly
  Future<({int playlistsCount, int favoritesCount, int historyCount})?> importBackupFromFile(
    File file, {
    bool merge = true,
  }) async {
    try {
      final content = await file.readAsString();
      return importBackupJson(content, merge: merge);
    } catch (e) {
      debugPrint('[StorageService] importBackupFromFile error: $e');
      return null;
    }
  }

  /// Imports and validates backup JSON, merging or restoring library data safely
  Future<({int playlistsCount, int favoritesCount, int historyCount})?> importBackupJson(
    String jsonString, {
    bool merge = true,
  }) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      // 1. Smart handling for SINE_SETTINGS format
      if (map['format'] == 'SINE_SETTINGS' ||
          (map.containsKey('settings') && !map.containsKey('playlists') && !map.containsKey('favorites') && !map.containsKey('history'))) {
        final ok = await importSettingsJson(jsonString);
        if (ok) {
          return (playlistsCount: 0, favoritesCount: 0, historyCount: 0);
        }
        return null;
      }

      // 2. Smart handling for SINE_PLAYLIST format
      if (map['format'] == 'SINE_PLAYLIST' ||
          map['playlist'] is Map ||
          (map.containsKey('songs') && map.containsKey('title') && !map.containsKey('playlists'))) {
        final pl = await importPlaylistJson(jsonString);
        if (pl != null) {
          return (playlistsCount: 1, favoritesCount: 0, historyCount: 0);
        }
        return null;
      }

      if (map['format'] != 'SINE_BACKUP') {
        if (!map.containsKey('playlists') && !map.containsKey('favorites') && !map.containsKey('history')) {
          return null;
        }
      }

      int pCount = 0;
      final rawPlaylists = map['playlists'] as List?;
      if (rawPlaylists != null) {
        final importedPlaylists = <Playlist>[];
        for (final p in rawPlaylists) {
          if (p is Map) {
            try {
              importedPlaylists.add(Playlist.fromMap(Map<String, dynamic>.from(p)));
            } catch (_) {}
          }
        }
        if (merge) {
          final existing = loadPlaylists();
          for (final p in importedPlaylists) {
            final idx = existing.indexWhere((e) => e.id == p.id);
            if (idx == -1) {
              existing.add(p);
            } else {
              // Smart merge: combine tracks inside matching playlists without duplicates
              final mergedSongs = List<Song>.from(existing[idx].songs);
              final songIds = mergedSongs.map((s) => s.id).toSet();
              for (final s in p.songs) {
                if (!songIds.contains(s.id)) {
                  mergedSongs.add(s);
                  songIds.add(s.id);
                }
              }
              existing[idx] = existing[idx].copyWith(songs: mergedSongs);
            }
          }
          await savePlaylists(existing);
        } else {
          await savePlaylists(importedPlaylists);
        }
        pCount = importedPlaylists.length;
      }

      int fCount = 0;
      final rawFavorites = map['favorites'] as List?;
      if (rawFavorites != null) {
        final importedFavs = <Song>[];
        for (final s in rawFavorites) {
          if (s is Map) {
            try {
              final song = Song.fromMap(Map<String, dynamic>.from(s));
              if (!Song.isPlaceholder(song)) importedFavs.add(song);
            } catch (_) {}
          }
        }
        if (merge) {
          final existing = loadFavorites();
          final existingIds = existing.map((s) => s.id).toSet();
          for (final s in importedFavs) {
            if (!existingIds.contains(s.id)) {
              existing.add(s);
              existingIds.add(s.id);
            }
          }
          await saveFavorites(existing);
        } else {
          await saveFavorites(importedFavs);
        }
        fCount = importedFavs.length;
      }

      int hCount = 0;
      final rawHistory = map['history'] as List?;
      if (rawHistory != null) {
        final importedHistory = <Song>[];
        for (final s in rawHistory) {
          if (s is Map) {
            try {
              final song = Song.fromMap(Map<String, dynamic>.from(s));
              if (!Song.isPlaceholder(song)) importedHistory.add(song);
            } catch (_) {}
          }
        }
        if (merge) {
          final existing = loadHistory();
          final existingIds = existing.map((s) => s.id).toSet();
          for (final s in importedHistory) {
            if (!existingIds.contains(s.id)) {
              existing.add(s);
              existingIds.add(s.id);
            }
          }
          await saveHistory(existing);
        } else {
          await saveHistory(importedHistory);
        }
        hCount = importedHistory.length;
      }

      final settings = map['settings'] as Map?;
      if (settings != null) {
        await _applySettingsMap(settings);
      }

      return (playlistsCount: pCount, favoritesCount: fCount, historyCount: hCount);
    } catch (e) {
      debugPrint('[StorageService] Backup import error: $e');
      return null;
    }
  }

  /// Loads saved theme preset name, defaults to 'blue'
  String loadThemePreset() {
    return _prefs?.getString(_themePresetKey) ?? 'blue';
  }

  /// Persists selected theme preset name
  Future<void> saveThemePreset(String presetName) async {
    await _prefs?.setString(_themePresetKey, presetName);
  }

  /// Loads custom theme color ARGB integer if present
  int? loadCustomThemeColor() {
    return _prefs?.getInt(_customThemeColorKey);
  }

  /// Persists custom theme color ARGB integer
  Future<void> saveCustomThemeColor(int colorValue) async {
    await _prefs?.setInt(_customThemeColorKey, colorValue);
  }

  /// Loads true pitch black OLED preference (defaults to false / Obsidian Charcoal)
  bool loadOledBlack() {
    return _prefs?.getBool(_oledBlackKey) ?? false;
  }

  /// Persists true pitch black OLED preference
  Future<void> saveOledBlack(bool enabled) async {
    await _prefs?.setBool(_oledBlackKey, enabled);
  }
}
