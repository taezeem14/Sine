import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SineGestureService {
  SineGestureService._();

  static const MethodChannel _channel = MethodChannel('com.taezeem.spotify_newpipe/gestures');

  static VoidCallback? _onShake;
  static VoidCallback? _onFlipDown;
  static VoidCallback? _onFlipUp;
  static bool _initialized = false;

  static void init({
    VoidCallback? onShake,
    VoidCallback? onFlipDown,
    VoidCallback? onFlipUp,
  }) {
    _onShake = onShake;
    _onFlipDown = onFlipDown;
    _onFlipUp = onFlipUp;

    if (!_initialized) {
      _channel.setMethodCallHandler(_handleNativeCall);
      _initialized = true;
    }
  }

  static Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onShakeDetected':
        _onShake?.call();
        break;
      case 'onFlipDown':
        _onFlipDown?.call();
        break;
      case 'onFlipUp':
        _onFlipUp?.call();
        break;
    }
  }

  static Future<void> setShakeToSkipEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setShakeToSkipEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<void> setFlipToPauseEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setFlipToPauseEnabled', {'enabled': enabled});
    } catch (_) {}
  }
}
