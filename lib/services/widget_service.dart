import 'package:flutter/services.dart';

class SineWidgetService {
  SineWidgetService._();

  static const MethodChannel _channel = MethodChannel('com.taezeem.spotify_newpipe/widget');

  static Future<void> updateWidget({
    required String? title,
    required String? artist,
    required bool isPlaying,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
      });
    } catch (_) {
      // Gracefully ignore on unsupported platforms or when widget is not present
    }
  }
}
