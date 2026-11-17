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
      'settings': {
        'speed': loadPlaybackSpeed(),
        'crossfade': loadCrossfadeSeconds(),
        'gapless': loadGaplessPlayback(),
        'clippingProtection': loadClippingProtection(),
        'recoveryMode': loadPlaybackRecoveryMode(),
        'stemEngine': loadStemEnginePreference(),
        'eqPreset': loadEqualizerPreset(),
        'eqEnabled': loadEqualizerEnabled(),
        'eqBassBoost': loadBassBoost(),
        'eqBandGains': loadBandGains(),
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports full database backup into a persistent JSON file in storage:
  /// e.g. /storage/emulated/0/Sine-Music/Backups/sine_backup_YYYYMMDD_HHMMSS.json
  /// Returns the written File.
  Future<File?> exportBackupToFile({String? customFileName}) async {
    try {
      final jsonStr = exportBackupJson();
      final backupDir = await getBackupDirectory();

      final now = DateTime.now();
      final dateStr = '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';

      final fileName = customFileName ?? 'sine_backup_$dateStr.json';
      final file = File('${backupDir.path}/$fileName');
      await file.writeAsString(jsonStr, flush: true);

      // Also maintain a convenient 'sine_backup_latest.json'
      try {
        final latestFile = File('${backupDir.path}/sine_backup_latest.json');
        await latestFile.writeAsString(jsonStr, flush: true);
      } catch (_) {}

      debugPrint('[StorageService] Backup exported successfully to ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[StorageService] exportBackupToFile error: $e');
      return null;
    }
  }

  /// Discovers existing backup files in public storage and documents directory
  Future<List<File>> listAvailableBackupFiles() async {
    final results = <File>[];
    final seenPaths = <String>{};

    void scanDir(Directory dir) {
      try {
        if (!dir.existsSync()) return;
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
            if (!seenPaths.contains(entity.path)) {
              seenPaths.add(entity.path);
              results.add(entity);
            }
          }
        }
      } catch (e) {
        debugPrint('[StorageService] scanDir error in ${dir.path}: $e');
      }
    }

    try {
      final backupDir = await getBackupDirectory();
      scanDir(backupDir);

      // Also check the parent Sine-Music directory in case a user dropped a backup there
      final mediaDir = await DownloadService.getMediaDirectory(isVideo: false);
      scanDir(mediaDir);

      // Also check standard documents directory
      try {
        final docs = await getApplicationDocumentsDirectory();
        scanDir(Directory('${docs.path}/Backups'));
        scanDir(docs);
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

      if (map['format'] != 'SINE_BACKUP') {
        if (!map.containsKey('playlists') && !map.containsKey('favorites')) {
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
        if (importedPlaylists.isNotEmpty) {
          final existing = merge ? loadPlaylists() : <Playlist>[];
          final existingIds = existing.map((p) => p.id).toSet();
          for (final p in importedPlaylists) {
            if (!existingIds.contains(p.id)) {
              existing.add(p);
            }
          }
          await savePlaylists(existing);
          pCount = importedPlaylists.length;
        }
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
        if (importedFavs.isNotEmpty) {
          final existing = merge ? loadFavorites() : <Song>[];
          final existingIds = existing.map((s) => s.id).toSet();
          for (final s in importedFavs) {
            if (!existingIds.contains(s.id)) {
              existing.add(s);
            }
          }
          await saveFavorites(existing);
          fCount = importedFavs.length;
        }
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
        if (importedHistory.isNotEmpty) {
          final existing = merge ? loadHistory() : <Song>[];
          final existingIds = existing.map((s) => s.id).toSet();
          for (final s in importedHistory) {
            if (!existingIds.contains(s.id)) {
              existing.add(s);
            }
          }
          await saveHistory(existing);
          hCount = importedHistory.length;
        }
      }

      final settings = map['settings'] as Map?;
      if (settings != null) {
        if (settings['speed'] != null) await savePlaybackSpeed((settings['speed'] as num).toDouble());
        if (settings['crossfade'] != null) await saveCrossfadeSeconds((settings['crossfade'] as num).toInt());
        if (settings['gapless'] != null) await saveGaplessPlayback(settings['gapless'] == true);
        if (settings['clippingProtection'] != null) await saveClippingProtection(settings['clippingProtection'] == true);
        if (settings['recoveryMode'] != null) await savePlaybackRecoveryMode(settings['recoveryMode'].toString());
        if (settings['stemEngine'] != null) await saveStemEnginePreference(settings['stemEngine'].toString());
        if (settings['eqPreset'] != null) await saveEqualizerPreset(settings['eqPreset'].toString());
        if (settings['eqEnabled'] != null) await saveEqualizerEnabled(settings['eqEnabled'] == true);
        if (settings['eqBassBoost'] != null) await saveBassBoost((settings['eqBassBoost'] as num).toDouble());
        if (settings['eqBandGains'] is Map) {
          final gains = <int, double>{};
          for (final entry in (settings['eqBandGains'] as Map).entries) {
            final k = int.tryParse(entry.key.toString());
            final v = (entry.value as num?)?.toDouble();
            if (k != null && v != null) {
              gains[k] = v;
            }
          }
          await saveBandGains(gains);
        }
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
