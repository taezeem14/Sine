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
    final raw = _prefs.getStringList(_downloadsKey) ?? _prefs.getStringList(_downloadsLegacyKey) ?? [];
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
    return _prefs?.getString(_eqPresetKey) ?? _prefs?.getString(_eqPresetLegacyKey) ?? 'Flat';
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
}
