import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/song.dart';

/// Immutable, dark-UI-calibrated color palette extracted directly from a track's album artwork.
@immutable
class CoverPalette {
  final Color dominant;
  final Color secondary;
  final Color accent;
  final bool isExtracted;

  const CoverPalette({
    required this.dominant,
    required this.secondary,
    required this.accent,
    this.isExtracted = false,
  });

  /// Restrained dark neutral slate palette used before artwork pixels finish decoding
  /// or when a track has no artwork (never flashes fake rainbow hues).
  static const CoverPalette defaultPalette = CoverPalette(
    dominant: Color(0xFF2B3240),
    secondary: Color(0xFF1C212B),
    accent: Color(0xFF64748B),
    isExtracted: false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoverPalette &&
          runtimeType == other.runtimeType &&
          dominant == other.dominant &&
          secondary == other.secondary &&
          accent == other.accent &&
          isExtracted == other.isExtracted;

  @override
  int get hashCode => Object.hash(dominant, secondary, accent, isExtracted);
}

class _HueBucket {
  double rSum = 0;
  double gSum = 0;
  double bSum = 0;
  double weight = 0;
  int count = 0;
}

class CoverColorService {
  CoverColorService._();
  static final CoverColorService instance = CoverColorService._();

  static const int _maxCacheEntries = 140;
  static const int _hueBucketCount = 36; // 10 degrees per bucket

  final Map<String, CoverPalette> _cache = {};
  final Map<String, Future<CoverPalette>> _inFlight = {};

  /// Bumped whenever a real artwork palette is extracted and cached, allowing
  /// MiniPlayer, FluidMeshGradientBackground, and NowPlayingScreen to stay in lockstep.
  final ValueNotifier<int> paletteRevision = ValueNotifier<int>(0);

  /// Synchronous lookup: returns the real extracted palette if cached,
  /// otherwise returns a refined neutral obsidian-slate placeholder (never a random rainbow).
  CoverPalette getPaletteSync(Song? song) {
    if (song == null) return CoverPalette.defaultPalette;
    final key = _getCacheKey(song);
    final cached = _cache[key];
    if (cached != null) return cached;
    return _neutralFallbackPalette(song);
  }

  /// Extracts true dominant, secondary, and accent colors from the album artwork bitmap.
  /// Shares Flutter's CachedNetworkImage disk/memory cache to avoid double network fetches.
  Future<CoverPalette> getPalette(Song song) async {
    final key = _getCacheKey(song);
    final cached = _cache[key];
    if (cached != null) return cached;

    final existingFuture = _inFlight[key];
    if (existingFuture != null) return existingFuture;

    final future = _runExtraction(song, key);
    _inFlight[key] = future;
    return future;
  }

  Future<CoverPalette> _runExtraction(Song song, String key) async {
    try {
      final palette = await _extractColorsFromArtwork(song);
      if (palette.isExtracted) {
        _cachePalette(key, palette);
        paletteRevision.value++;
      }
      return palette;
    } catch (_) {
      // Do NOT poison _cache on transient network failure; return clean neutral fallback
      return _neutralFallbackPalette(song);
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Fire-and-forget pre-extraction so MiniPlayer & NowPlayingScreen have real cover colors ready immediately.
  void prefetchPalette(Song? song) {
    if (song == null || song.artworkUrl.trim().isEmpty) return;
    final key = _getCacheKey(song);
    if (_cache.containsKey(key) || _inFlight.containsKey(key)) return;
    getPalette(song).ignore();
  }

  void _cachePalette(String key, CoverPalette palette) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = palette;
  }

  String _getCacheKey(Song song) {
    final url = song.artworkUrl.trim();
    if (url.isNotEmpty) return url;
    if (song.id.isNotEmpty) return song.id;
    return '${song.title}_${song.artist}';
  }

  /// Subtle, deterministic neutral obsidian-slate palette (distinct dominant/secondary, never loud/random).
  CoverPalette _neutralFallbackPalette(Song song) {
    final hash = (song.title.hashCode ^ song.artist.hashCode).abs();
    // Keep subtly within cool charcoal/slate range (hue 205–235, very low saturation 0.14–0.20)
    final hue = 205.0 + (hash % 30).toDouble();
    final dom = HSLColor.fromAHSL(1.0, hue, 0.18, 0.24).toColor();
    final sec = HSLColor.fromAHSL(1.0, (hue + 14) % 360, 0.15, 0.16).toColor();
    final acc = HSLColor.fromAHSL(1.0, hue, 0.24, 0.48).toColor();
    return CoverPalette(
      dominant: dom,
      secondary: sec,
      accent: acc,
      isExtracted: false,
    );
  }

  Future<CoverPalette> _extractColorsFromArtwork(Song song) async {
    final url = song.artworkUrl.trim();
    if (url.isEmpty) {
      return _neutralFallbackPalette(song);
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        // Reuse CachedNetworkImageProvider so we read straight from disk/memory cache (~10ms)
        return await _decodeAndExtract(CachedNetworkImageProvider(url), song);
      } catch (_) {
        // Some older YouTube tracks lack maxresdefault.jpg (HTTP 404); transparently retry hqdefault.jpg
        if (url.contains('maxresdefault.jpg')) {
          final hqUrl = url.replaceFirst('maxresdefault.jpg', 'hqdefault.jpg');
          return await _decodeAndExtract(CachedNetworkImageProvider(hqUrl), song);
        }
        rethrow;
      }
    }

    var path = url.replaceFirst('file://', '');
    if (Platform.isWindows && path.startsWith('/') && path.length > 2 && path[2] == ':') {
      path = path.substring(1);
    }
    final file = File(path);
    if (await file.exists()) {
      return await _decodeAndExtract(FileImage(file), song);
    }
    return _neutralFallbackPalette(song);
  }

  Future<CoverPalette> _decodeAndExtract(ImageProvider provider, Song song) async {
    // 32x32 decode (~1024 pixels): fast, accurate spatial color coverage
    final resizeProvider = ResizeImage(provider, width: 32, height: 32);
    final completer = Completer<ui.Image>();
    final stream = resizeProvider.resolve(const ImageConfiguration(size: Size(32, 32)));

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) {
          // Clone the ui.Image handle so disposing our copy in `finally` never
          // invalidates the shared ImageInfo held inside Flutter's ImageCache.
          completer.complete(info.image.clone());
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

    ui.Image? image;
    try {
      image = await completer.future;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return _neutralFallbackPalette(song);
      }
      return extractPaletteFromRgbaBytes(
        byteData.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } finally {
      stream.removeListener(listener);
      image?.dispose();
    }
  }

  /// Pure deterministic perceptual color extraction from raw RGBA bitmap bytes.
  /// Exposed cleanly for direct unit testing without network I/O.
  @visibleForTesting
  static CoverPalette extractPaletteFromRgbaBytes(
    List<int> rgba, {
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      return CoverPalette.defaultPalette;
    }

    // Center-crop inset (~14% on each side) to automatically ignore YouTube's
    // 16:9 black letterbox bars on hqdefault.jpg and edge channel watermarks.
    final xStart = width >= 8 ? (width * 0.14).floor() : 0;
    final xEnd = width >= 8 ? (width * 0.86).ceil() : width;
    final yStart = height >= 8 ? (height * 0.14).floor() : 0;
    final yEnd = height >= 8 ? (height * 0.86).ceil() : height;

    final buckets = List<_HueBucket>.generate(_hueBucketCount, (_) => _HueBucket());

    double neutralR = 0;
    double neutralG = 0;
    double neutralB = 0;
    int neutralCount = 0;
    int chromaticCount = 0;
    int totalValid = 0;

    for (int y = yStart; y < yEnd; y++) {
      for (int x = xStart; x < xEnd; x++) {
        final idx = (y * width + x) * 4;
        if (idx + 3 >= rgba.length) continue;

        final r = rgba[idx];
        final g = rgba[idx + 1];
        final b = rgba[idx + 2];
        final a = rgba[idx + 3];
        if (a < 180) continue;

        totalValid++;
        final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));

        // Skip near-pure black letterbox/shadows and blown-out pure white glare
        if (hsl.lightness < 0.06 || hsl.lightness > 0.94) {
          neutralR += r;
          neutralG += g;
          neutralB += b;
          neutralCount++;
          continue;
        }

        if (hsl.saturation < 0.12) {
          neutralR += r;
          neutralG += g;
          neutralB += b;
          neutralCount++;
          continue;
        }

        chromaticCount++;
        final bucketIndex = ((hsl.hue % 360) / (360.0 / _hueBucketCount))
            .floor()
            .clamp(0, _hueBucketCount - 1);

        // Area-first perceptual weighting: dominant regions win, NOT a single tiny bright pixel.
        // Smooth bell curve peaking around natural mid-tone lightness (0.45) and rich saturation.
        final lightnessFactor = 1.0 - ((hsl.lightness - 0.45).abs() * 1.15).clamp(0.0, 0.72);
        final saturationFactor = 0.45 + (hsl.saturation * 0.85);
        final weight = lightnessFactor * saturationFactor;

        final bucket = buckets[bucketIndex];
        bucket.rSum += r * weight;
        bucket.gSum += g * weight;
        bucket.bSum += b * weight;
        bucket.weight += weight;
        bucket.count++;
      }
    }

    // Authentic Monochrome / Black-and-White / Low-Chroma Artwork Handling:
    // If < 8% of valid center pixels are chromatic, honor the monochrome aesthetic!
    if (totalValid == 0 || chromaticCount < math.max(3, (totalValid * 0.08).round())) {
      if (neutralCount > 0) {
        final avgR = (neutralR / neutralCount).round().clamp(0, 255);
        final avgG = (neutralG / neutralCount).round().clamp(0, 255);
        final avgB = (neutralB / neutralCount).round().clamp(0, 255);
        final baseHsl = HSLColor.fromColor(Color.fromARGB(255, avgR, avgG, avgB));
        final calibratedDom = HSLColor.fromAHSL(
          1.0,
          baseHsl.hue,
          baseHsl.saturation.clamp(0.0, 0.14),
          baseHsl.lightness.clamp(0.24, 0.44),
        ).toColor();
        final calibratedSec = HSLColor.fromAHSL(
          1.0,
          baseHsl.hue,
          baseHsl.saturation.clamp(0.0, 0.10),
          (baseHsl.lightness * 0.65).clamp(0.14, 0.28),
        ).toColor();
        final calibratedAcc = HSLColor.fromAHSL(
          1.0,
          baseHsl.hue,
          baseHsl.saturation.clamp(0.0, 0.16),
          (baseHsl.lightness + 0.22).clamp(0.52, 0.72),
        ).toColor();
        return CoverPalette(
          dominant: calibratedDom,
          secondary: calibratedSec,
          accent: calibratedAcc,
          isExtracted: true,
        );
      }
      return CoverPalette.defaultPalette;
    }

    // Smooth circular 3-bucket neighborhood score so split hue boundaries (e.g., 359° & 1°) combine naturally
    double bestScore = -1.0;
    int bestBucket = 0;
    for (int i = 0; i < _hueBucketCount; i++) {
      final prev = buckets[(i - 1 + _hueBucketCount) % _hueBucketCount];
      final curr = buckets[i];
      final next = buckets[(i + 1) % _hueBucketCount];
      final clusterWeight = curr.weight + (prev.weight + next.weight) * 0.45;
      if (clusterWeight > bestScore) {
        bestScore = clusterWeight;
        bestBucket = i;
      }
    }

    Color avgClusterColor(int centerIdx) {
      double r = 0, g = 0, b = 0, w = 0;
      for (final offset in const [-1, 0, 1]) {
        final idx = (centerIdx + offset + _hueBucketCount) % _hueBucketCount;
        final bkt = buckets[idx];
        final factor = offset == 0 ? 1.0 : 0.45;
        r += bkt.rSum * factor;
        g += bkt.gSum * factor;
        b += bkt.bSum * factor;
        w += bkt.weight * factor;
      }
      if (w <= 0) return CoverPalette.defaultPalette.dominant;
      return Color.fromARGB(
        255,
        (r / w).round().clamp(0, 255),
        (g / w).round().clamp(0, 255),
        (b / w).round().clamp(0, 255),
      );
    }

    final rawDominant = avgClusterColor(bestBucket);
    final domHsl = HSLColor.fromColor(rawDominant);

    // Calibrate dominant color for dark-mode luxury (true hue preserved 100%, refined luminance & saturation)
    final dominant = HSLColor.fromAHSL(
      1.0,
      domHsl.hue,
      domHsl.saturation.clamp(0.24, 0.78),
      domHsl.lightness.clamp(0.30, 0.54),
    ).toColor();

    // Find genuine second distinct color cluster (>= 4 buckets = 40° away) with meaningful area coverage
    double secondBestScore = -1.0;
    int secondBucket = -1;
    for (int i = 0; i < _hueBucketCount; i++) {
      final rawDiff = (i - bestBucket).abs();
      final circularDist = math.min(rawDiff, _hueBucketCount - rawDiff);
      if (circularDist < 4) continue;
      final prev = buckets[(i - 1 + _hueBucketCount) % _hueBucketCount];
      final curr = buckets[i];
      final next = buckets[(i + 1) % _hueBucketCount];
      final clusterWeight = curr.weight + (prev.weight + next.weight) * 0.45;
      if (clusterWeight > secondBestScore) {
        secondBestScore = clusterWeight;
        secondBucket = i;
      }
    }

    final Color secondary;
    if (secondBucket != -1 && secondBestScore >= bestScore * 0.16) {
      final rawSec = avgClusterColor(secondBucket);
      final secHsl = HSLColor.fromColor(rawSec);
      secondary = HSLColor.fromAHSL(
        1.0,
        secHsl.hue,
        secHsl.saturation.clamp(0.22, 0.74),
        secHsl.lightness.clamp(0.22, 0.44),
      ).toColor();
    } else {
      // Single-hue cover (e.g., pure crimson or pure navy): stay faithful with a deeper tonal shade
      secondary = HSLColor.fromAHSL(
        1.0,
        (domHsl.hue + 14) % 360,
        (domHsl.saturation * 0.85).clamp(0.18, 0.70),
        (domHsl.lightness * 0.62).clamp(0.16, 0.34),
      ).toColor();
    }

    // Refined highlight accent derived directly from the extracted dominant hue
    final accent = HSLColor.fromAHSL(
      1.0,
      domHsl.hue,
      (domHsl.saturation + 0.08).clamp(0.28, 0.84),
      (domHsl.lightness + 0.14).clamp(0.46, 0.66),
    ).toColor();

    return CoverPalette(
      dominant: dominant,
      secondary: secondary,
      accent: accent,
      isExtracted: true,
    );
  }
}
