import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist.dart';

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

  final SharedPreferences? _prefs;
  final List<Song> _memFavorites = [];
  final List<Song> _memHistory = [];
  final List<Playlist> _memPlaylists = [];
  final List<Song> _memDownloads = [];
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

  /// Exports full database backup into portable JSON format (Audile & Metrolist architecture)
  String exportBackupJson() {
    final payload = {
      'format': 'SINE_BACKUP',
      'version': '1.2.8',
      'versionCode': 26,
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
}
