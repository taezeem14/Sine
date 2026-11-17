import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';

class LocalMusicService {
  LocalMusicService._();

  static const List<String> supportedExtensions = [
    '.mp3',
    '.m4a',
    '.flac',
    '.wav',
    '.aac',
    '.ogg',
  ];

  static const List<String> _audioExtensions = supportedExtensions;

  static (String, String) parseArtistAndTitle(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    final baseName = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;
    String artist = 'Unknown Artist';
    String title = baseName.replaceAll('_', ' ').trim();

    if (baseName.contains(' - ')) {
      final parts = baseName.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].replaceAll('_', ' ').trim();
        title = parts.sublist(1).join(' - ').replaceAll('_', ' ').trim();
      }
    }
    return (artist, title);
  }

  static String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      // Android 13+ (API 33+) uses Permission.audio
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) return true;

      final resAudio = await Permission.audio.request();
      if (resAudio.isGranted) return true;

      // Android 12 and below use Permission.storage
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;

      final resStorage = await Permission.storage.request();
      return resStorage.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Song>> scanDeviceAudioFiles() async {
    final List<Song> foundSongs = [];
    final Set<String> visitedPaths = {};

    final List<Directory> searchDirs = [];

    // 1. Android standard public storage locations
    if (Platform.isAndroid) {
      final candidates = [
        Directory('/storage/emulated/0/Music'),
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
        Directory('/storage/emulated/0/Audio'),
        Directory('/storage/emulated/0/Podcasts'),
      ];
      for (final d in candidates) {
        if (d.existsSync()) {
          searchDirs.add(d);
        }
      }
    }

    // 2. Application specific storage directories
    try {
      final docDir = await getApplicationDocumentsDirectory();
      if (docDir.existsSync()) searchDirs.add(docDir);
    } catch (_) {}

    try {
      final extDirs = await getExternalStorageDirectories();
      if (extDirs != null) {
        for (final ed in extDirs) {
          if (ed.existsSync()) searchDirs.add(ed);
        }
      }
    } catch (_) {}

    for (final dir in searchDirs) {
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final path = entity.path;
            final lower = path.toLowerCase();
            final isAudio = _audioExtensions.any((ext) => lower.endsWith(ext));

            if (isAudio && !visitedPaths.contains(path)) {
              visitedPaths.add(path);
              final song = _songFromFile(entity);
              if (song != null) {
                foundSongs.add(song);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning dir ${dir.path}: $e');
      }
    }

    // Sort alphabetically by title
    foundSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return foundSongs;
  }

  static Song? _songFromFile(File file) {
    try {
      final filename = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : file.path.split(Platform.pathSeparator).last;

      // Strip extension
      final dotIndex = filename.lastIndexOf('.');
      final baseName = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;

      String artist = 'Device Music';
      String title = baseName.replaceAll('_', ' ').trim();

      if (baseName.contains(' - ')) {
        final parts = baseName.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].replaceAll('_', ' ').trim();
          title = parts.sublist(1).join(' - ').replaceAll('_', ' ').trim();
        }
      }

      final stat = file.statSync();
      // Estimate ~3.5 minutes if unknown, or proportional to file size (~1MB = 50s at 160kbps)
      final estimatedSecs = ((stat.size / (160 * 1024 / 8))).clamp(30.0, 600.0).toInt();

      final cleanId = 'local_${file.path.hashCode.abs()}';

      return Song(
        id: cleanId,
        title: title.isEmpty ? 'Untitled Track' : title,
        artist: artist.isEmpty ? 'Local Artist' : artist,
        duration: Duration(seconds: estimatedSecs),
        artworkUrl: '',
        streamUrl: file.path,
        source: 'device',
      );
    } catch (_) {
      return null;
    }
  }
}
