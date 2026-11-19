import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/song.dart';
import '../theme/ember_theme.dart';

class CoverPalette {
  final Color dominant;
  final Color secondary;
  final Color accent;

  const CoverPalette({
    required this.dominant,
    required this.secondary,
    required this.accent,
  });

  static const CoverPalette defaultPalette = CoverPalette(
    dominant: Color(0xFF2979FF),
    secondary: Color(0xFF00D2FF),
    accent: Color(0xFF7928CA),
  );
}

class CoverColorService {
  CoverColorService._();
  static final CoverColorService instance = CoverColorService._();

  static const int _maxCacheEntries = 120;
  final Map<String, CoverPalette> _cache = {};
  final Map<String, Completer<CoverPalette>> _inFlight = {};

  /// Synchronous instant fallback colors derived from track metadata
  CoverPalette getPaletteSync(Song? song) {
    if (song == null) return CoverPalette.defaultPalette;
    final key = _getCacheKey(song);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    return _deriveHarmonicPalette(song);
  }

  /// Extracts true dominant and vibrant colors directly from the song's album artwork bitmap
  Future<CoverPalette> getPalette(Song song) async {
    final key = _getCacheKey(song);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!.future;
    }

    final completer = Completer<CoverPalette>();
    _inFlight[key] = completer;

    try {
      final palette = await _extractColorsFromArtwork(song);
      _cachePalette(key, palette);
      completer.complete(palette);
      return palette;
    } catch (_) {
      final fallback = _deriveHarmonicPalette(song);
      _cachePalette(key, fallback);
      completer.complete(fallback);
      return fallback;
    } finally {
      _inFlight.remove(key);
    }
  }

  void _cachePalette(String key, CoverPalette palette) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = palette;
  }

  String _getCacheKey(Song song) {
    if (song.artworkUrl.isNotEmpty) return song.artworkUrl;
    if (song.id.isNotEmpty) return song.id;
    return '${song.title}_${song.artist}';
  }

  CoverPalette _deriveHarmonicPalette(Song song) {
    final hash = (song.title.hashCode ^ song.artist.hashCode).abs();
    final baseHue = (hash % 360).toDouble();

    final dominant = HSLColor.fromAHSL(1.0, baseHue, 0.75, 0.52).toColor();
    final secondary = HSLColor.fromAHSL(1.0, (baseHue + 40) % 360, 0.82, 0.60).toColor();
    final accent = HSLColor.fromAHSL(1.0, (baseHue + 120) % 360, 0.70, 0.45).toColor();

    return CoverPalette(dominant: dominant, secondary: secondary, accent: accent);
  }

  Future<CoverPalette> _extractColorsFromArtwork(Song song) async {
    final url = song.artworkUrl.trim();
    if (url.isEmpty) {
      return _deriveHarmonicPalette(song);
    }

    ImageProvider provider;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      provider = NetworkImage(url);
    } else {
      var path = url.replaceFirst('file://', '');
      if (Platform.isWindows && path.startsWith('/') && path.length > 2 && path[2] == ':') {
        path = path.substring(1);
      }
      final file = File(path);
      if (await file.exists()) {
        provider = FileImage(file);
      } else {
        return _deriveHarmonicPalette(song);
      }
    }

    // Downscale to 24x24 bitmap for instant, zero-latency pixel analysis (~576 pixels)
    final resizeProvider = ResizeImage(provider, width: 24, height: 24);
    final completer = Completer<ui.Image>();
    final stream = resizeProvider.resolve(const ImageConfiguration(size: Size(24, 24)));

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          completer.complete(info.image);
        }
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(exception);
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);

    final image = await completer.future.timeout(const Duration(milliseconds: 1500));
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return _deriveHarmonicPalette(song);
    }

    final bytes = byteData.buffer.asUint8List();
    double bestVibranceScore = -1.0;
    Color dominantColor = _deriveHarmonicPalette(song).dominant;
    Color secondaryColor = _deriveHarmonicPalette(song).secondary;

    // Scan pixels: score by saturation * lightness contrast
    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final a = bytes[i + 3];

      if (a < 128) continue; // Ignore transparent pixels

      final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));

      // Skip dark muddy backgrounds and blown-out whites
      if (hsl.lightness < 0.15 || hsl.lightness > 0.88) continue;
      if (hsl.saturation < 0.20) continue; // Skip grey washed-out pixels

      // Vibrance weighting: high saturation + pleasing mid-tone lightness
      final score = hsl.saturation * (1.0 - (hsl.lightness - 0.50).abs() * 1.5);
      if (score > bestVibranceScore) {
        bestVibranceScore = score;
        secondaryColor = dominantColor;
        dominantColor = hsl.toColor();
      }
    }

    if (bestVibranceScore <= 0) {
      return _deriveHarmonicPalette(song);
    }

    final domHsl = HSLColor.fromColor(dominantColor);
    final accentHsl = HSLColor.fromAHSL(
      1.0,
      (domHsl.hue + 45) % 360,
      (domHsl.saturation + 0.1).clamp(0.4, 1.0),
      (domHsl.lightness + 0.1).clamp(0.3, 0.7),
    );

    return CoverPalette(
      dominant: dominantColor,
      secondary: secondaryColor,
      accent: accentHsl.toColor(),
    );
  }
}
