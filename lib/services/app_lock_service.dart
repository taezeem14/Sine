import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  AppLockService._();

  static const String _keyLockEnabled = 'sine_app_lock_enabled_v1';
  static const String _keyPinHash = 'sine_app_lock_pin_hash_v1';

  static bool isUnlockedThisSession = false;

  static String _hashPin(String pin) {
    final bytes = utf8.encode('sine_salt_${pin.trim()}');
    return sha256.convert(bytes).toString();
  }

  static Future<bool> isLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(_keyLockEnabled) ?? false) && (prefs.getString(_keyPinHash) != null);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPinSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyPinHash) != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_keyPinHash);
      if (storedHash == null) return false;
      return storedHash == _hashPin(pin);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = _hashPin(pin);
      await prefs.setString(_keyPinHash, hash);
      await prefs.setBool(_keyLockEnabled, true);
      isUnlockedThisSession = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setLockEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLockEnabled, enabled);
      if (!enabled) {
        isUnlockedThisSession = true;
      }
    } catch (_) {}
  }

  static Future<void> removePin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPinHash);
      await prefs.setBool(_keyLockEnabled, false);
      isUnlockedThisSession = true;
    } catch (_) {}
  }
}
