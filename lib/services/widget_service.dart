import 'package:flutter/services.dart';

class SineWidgetService {
  SineWidgetService._();

  static const MethodChannel _channel = MethodChannel('com.taezeem.spotify_newpipe/widget');

  static String? _lastTitle;
  static String? _lastArtist;
  static bool? _lastIsPlaying;

  static Future<void> updateWidget({
    required String? title,
    required String? artist,
    required bool isPlaying,
    bool force = false,
  }) async {
    final safeTitle = title ?? 'No Song Playing';
    final safeArtist = artist ?? 'Tap to open Sine';

    // Strict deduplication: never invoke MethodChannel or Android AppWidgetManager if state hasn't changed
    if (!force &&
        _lastTitle == safeTitle &&
        _lastArtist == safeArtist &&
        _lastIsPlaying == isPlaying) {
      return;
    }

    _lastTitle = safeTitle;
    _lastArtist = safeArtist;
    _lastIsPlaying = isPlaying;

    try {
      await _channel.invokeMethod('updateWidget', {
        'title': safeTitle,
        'artist': safeArtist,
        'isPlaying': isPlaying,
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
  }
}
