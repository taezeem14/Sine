import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SponsorSegment {
  final double start;
  final double end;
  final String category;

  const SponsorSegment({
    required this.start,
    required this.end,
    required this.category,
  });
}

class SponsorBlockService {
  static final SponsorBlockService instance = SponsorBlockService._();
  SponsorBlockService._();

  bool isEnabled = true;

  // LRU cache with timestamp for TTL expiration
  static const int _maxCacheEntries = 100;
  static const Duration _cacheTtl = Duration(hours: 1);
  final Map<String, (DateTime, List<SponsorSegment>)> _cache = {};

  void clearCache() => _cache.clear();

  void invalidate(String videoId) => _cache.remove(videoId);

  static List<SponsorSegment> mergeSegments(List<SponsorSegment> raw) {
    if (raw.isEmpty) return [];
    final valid = raw.where((s) => s.end > s.start).toList();
    if (valid.isEmpty) return [];
    valid.sort((a, b) => a.start.compareTo(b.start));

    final merged = <SponsorSegment>[];
    SponsorSegment current = valid.first;

    for (int i = 1; i < valid.length; i++) {
      final next = valid[i];
      if (next.start <= current.end + 0.5) {
        current = SponsorSegment(
          start: current.start,
          end: next.end > current.end ? next.end : current.end,
          category: current.category,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }

  void _cacheSegments(String videoId, List<SponsorSegment> segments) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[videoId] = (DateTime.now(), segments);
  }

  Future<List<SponsorSegment>> getSkipSegments(String videoId) async {
    if (!isEnabled || videoId.isEmpty) return [];

    final cached = _cache[videoId];
    if (cached != null) {
      if (DateTime.now().difference(cached.$1) < _cacheTtl) {
        return cached.$2;
      }
      _cache.remove(videoId);
    }

    try {
      final uri = Uri.https('sponsor.ajay.app', '/api/skipSegments', {
        'videoID': videoId,
        'categories': jsonEncode(['sponsor', 'intro', 'outro', 'selfpromo']),
      });

      final response = await http
          .get(uri, headers: {'User-Agent': 'Sine/1.0'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final rawList = <SponsorSegment>[];
          for (final item in decoded) {
            if (item is! Map) continue;
            final segArr = item['segment'];
            if (segArr is! List || segArr.length < 2) continue;

            final start = num.tryParse(segArr[0].toString())?.toDouble() ?? 0.0;
            final end = num.tryParse(segArr[1].toString())?.toDouble() ?? 0.0;
            if (end <= start) continue;

            rawList.add(SponsorSegment(
              start: start,
              end: end,
              category: item['category']?.toString() ?? 'sponsor',
            ));
          }

          final normalized = mergeSegments(rawList);
          _cacheSegments(videoId, normalized);
          return normalized;
        }
      } else if (response.statusCode == 404) {
        // Video has no sponsor segments: memoize negative hit
        _cacheSegments(videoId, []);
        return [];
      } else if (response.statusCode == 429) {
        debugPrint('[SponsorBlock] Rate limited (429)');
      }
    } catch (e) {
      debugPrint('[SponsorBlock] Network error for $videoId: $e');
    }

    return [];
  }
}
