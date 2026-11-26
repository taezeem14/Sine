import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PickedJsonDocument {
  final String name;
  final String content;
  final String? uri;

  const PickedJsonDocument({
    required this.name,
    required this.content,
    this.uri,
  });
}

class SavedJsonDocumentResult {
  final bool saved;
  final bool cancelled;
  final String? name;
  final String? uri;

  const SavedJsonDocumentResult({
    required this.saved,
    this.cancelled = false,
    this.name,
    this.uri,
  });
}

/// Native Android Storage Access Framework (SAF) & MediaStore bridge.
/// Works across Android 8–15 under full Scoped Storage without requiring MANAGE_EXTERNAL_STORAGE.
class NativeStorageBridge {
  NativeStorageBridge._();

  static const MethodChannel _channel = MethodChannel('com.taezeem.spotify_newpipe/storage');

  /// Queries all audio files indexed by Android MediaStore across internal storage & SD cards.
  static Future<List<Map<String, dynamic>>> queryDeviceAudio() async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('queryDeviceAudio');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('[NativeStorageBridge] queryDeviceAudio error: $e');
      return const [];
    }
  }

  /// Opens Android's native system "Save As..." dialog (ACTION_CREATE_DOCUMENT) so the user
  /// can save a JSON playlist, backup, or settings file anywhere (Downloads, Drive, SD card).
  static Future<SavedJsonDocumentResult?> saveJsonViaSystemPicker({
    required String fileName,
    required String jsonContent,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'saveDocumentJson',
        {
          'fileName': fileName,
          'content': jsonContent,
        },
      );
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res);
      return SavedJsonDocumentResult(
        saved: map['saved'] == true,
        cancelled: map['cancelled'] == true,
        name: map['name']?.toString(),
        uri: map['uri']?.toString(),
      );
    } catch (e) {
      debugPrint('[NativeStorageBridge] saveJsonViaSystemPicker error: $e');
      return null;
    }
  }

  /// Opens Android's native system File Picker (ACTION_OPEN_DOCUMENT) so the user can pick
  /// any .json file from Downloads, WhatsApp, Telegram, Google Drive, or SD card.
  static Future<PickedJsonDocument?> pickJsonViaSystemPicker() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickDocumentJson');
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res);
      final content = map['content']?.toString();
      if (content == null || content.trim().isEmpty) return null;
      return PickedJsonDocument(
        name: map['name']?.toString() ?? 'imported.json',
        content: content,
        uri: map['uri']?.toString(),
      );
    } catch (e) {
      debugPrint('[NativeStorageBridge] pickJsonViaSystemPicker error: $e');
      return null;
    }
  }

  /// Shares an exported JSON file via Android's native Share Sheet (WhatsApp, Telegram, Quick Share, etc.).
  static Future<bool> shareFile(
    File file, {
    String title = 'Share Sine JSON',
    String mimeType = 'application/json',
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'shareFile',
        {
          'filePath': file.path,
          'title': title,
          'mimeType': mimeType,
        },
      );
      return ok == true;
    } catch (e) {
      debugPrint('[NativeStorageBridge] shareFile error: $e');
      return false;
    }
  }
}
