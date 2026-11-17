import 'package:flutter/services.dart';

class SineWidgetService {
  SineWidgetService._();

  static const MethodChannel _channel = MethodChannel('com.taezeem.spotify_newpipe/widget');

  static String? _lastTitle;
  static String? _lastArtist;
  static bool? _lastIsPlaying;
  static String? _lastArtworkUrl;

  static Future<void> updateWidget({
    required String? title,
    required String? artist,
    required bool isPlaying,
    String? artworkUrl,
    bool force = false,
  }) async {
    final safeTitle = title ?? 'No Song Playing';
    final safeArtist = artist ?? 'Tap to open Sine';

    // Strict deduplication: avoid thrashing Android AppWidgetManager IPC if values are identical
    if (!force &&
        _lastTitle == safeTitle &&
        _lastArtist == safeArtist &&
        _lastIsPlaying == isPlaying &&
        _lastArtworkUrl == artworkUrl) {
      return;
    }

    _lastTitle = safeTitle;
    _lastArtist = safeArtist;
    _lastIsPlaying = isPlaying;
    _lastArtworkUrl = artworkUrl;

    try {
      await _channel.invokeMethod('updateWidget', {
        'title': safeTitle,
        'artist': safeArtist,
        'isPlaying': isPlaying,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
      });
    } catch (_) {
      // Gracefully ignore on unsupported platforms or when widget is not present
    }
  }

  /// Resets cached widget state (e.g. for testing or app resume)
  static void resetCache() {
    _lastTitle = null;
    _lastArtist = null;
    _lastIsPlaying = null;
    _lastArtworkUrl = null;
  }
}
