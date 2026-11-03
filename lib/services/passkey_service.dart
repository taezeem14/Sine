import 'package:shared_preferences/shared_preferences.dart';

class PasskeyService {
  static const String _keyActivated = 'sine_passkey_activated_v1';
  static const String _keyActivatedLegacy = 'ember_passkey_activated_v1';

  static const Set<String> passkeys = {
    // ── Block 1 ──────────────────────────────────────────────────────
    'EMBR-A7K9', 'EMBR-B3M2', 'EMBR-C8N4', 'EMBR-D1P6', 'EMBR-E5Q8',
    'EMBR-F2R7', 'EMBR-G9S3', 'EMBR-H4T1', 'EMBR-J6U5', 'EMBR-K8V2',
    // ── Block 2 ──────────────────────────────────────────────────────
    'EMBR-L3W9', 'EMBR-M7X4', 'EMBR-N1Y6', 'EMBR-P5Z8', 'EMBR-Q2A3',
    'EMBR-R9B7', 'EMBR-S4C1', 'EMBR-T6D5', 'EMBR-U8E2', 'EMBR-V3F9',
    // ── Block 3 ──────────────────────────────────────────────────────
    'EMBR-W7G4', 'EMBR-X1H6', 'EMBR-Y5J8', 'EMBR-Z2K3', 'EMBR-A9L7',
    'EMBR-B4M1', 'EMBR-C6N5', 'EMBR-D8P2', 'EMBR-E3Q9', 'EMBR-F7R4',
    // ── Block 4 ──────────────────────────────────────────────────────
    'EMBR-G1S6', 'EMBR-H5T8', 'EMBR-J2U3', 'EMBR-K9V7', 'EMBR-L4W1',
    'EMBR-M6X5', 'EMBR-N8Y2', 'EMBR-P3Z9', 'EMBR-Q7A4', 'EMBR-R1B6',
    // ── Block 5 ──────────────────────────────────────────────────────
    'EMBR-S5C8', 'EMBR-T2D3', 'EMBR-U9E7', 'EMBR-V4F1', 'EMBR-W6G5',
    'EMBR-X8H2', 'EMBR-Y3J9', 'EMBR-Z7K4', 'EMBR-A1L6', 'EMBR-B5M8',
    // ── Block 6 ──────────────────────────────────────────────────────
    'EMBR-C2N3', 'EMBR-D9P7', 'EMBR-E4Q1', 'EMBR-F6R5', 'EMBR-G8S2',
    'EMBR-H3T9', 'EMBR-J7U4', 'EMBR-K1V6', 'EMBR-L5W8', 'EMBR-M2X3',
    // ── Block 7 ──────────────────────────────────────────────────────
    'EMBR-N9Y7', 'EMBR-P4Z1', 'EMBR-Q6A5', 'EMBR-R8B2', 'EMBR-S3C9',
    'EMBR-T7D4', 'EMBR-U1E6', 'EMBR-V5F8', 'EMBR-W2G3', 'EMBR-X9H7',
    // ── Block 8 ──────────────────────────────────────────────────────
    'EMBR-Y4J1', 'EMBR-Z6K5', 'EMBR-A8L2', 'EMBR-B2M9', 'EMBR-C7N4',
    'EMBR-D5P6', 'EMBR-E1Q8', 'EMBR-F9R3', 'EMBR-G4S7', 'EMBR-H6T2',
    // ── Block 9 ──────────────────────────────────────────────────────
    'EMBR-J8U9', 'EMBR-K3V4', 'EMBR-L7W6', 'EMBR-M1X8', 'EMBR-N5Y3',
    'EMBR-P9Z7', 'EMBR-Q4A1', 'EMBR-R6B5', 'EMBR-S8C2', 'EMBR-T3D9',
    // ── Block 10 ─────────────────────────────────────────────────────
    'EMBR-U7E4', 'EMBR-V1F6', 'EMBR-W5G8', 'EMBR-X2H3', 'EMBR-Y9J7',
    'EMBR-Z4K1', 'EMBR-A6L5', 'EMBR-B8M2', 'EMBR-C3N9', 'EMBR-D7P4',
  };

  static bool isValid(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return false;
    return passkeys.contains(clean) || passkeys.contains(clean.replaceFirst('SINE-', 'EMBR-'));
  }

  static Future<bool> isActivated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(_keyActivated) ?? prefs.getBool(_keyActivatedLegacy)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> activate(String code) async {
    if (!isValid(code)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyActivated, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
