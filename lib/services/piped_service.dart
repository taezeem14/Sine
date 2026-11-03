import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'log_service.dart';

/// Piped API service — YouTube audio proxy with multi-instance failover.
///
/// Used as a FALLBACK when youtube_explode_dart fails (e.g. cipher changes,
/// throttling, or InnerTube player rejections). Piped instances proxy audio
/// through their servers, bypassing IP-binding issues.
///
/// Instance priority: Try each instance in order, skip on timeout/error.
class PipedService {
  PipedService._();

  static const _instances = [
    'https://pipedapi.adminforge.de',
    'https://pipedapi.smnz.de',
    'https://piped-api.lunar.icu',
    'https://pipedapi.leptons.xyz',
    'https://pipedapi.ducks.party',
  ];

  static final Map<String, DateTime> _cooldowns = {};
  static const Duration _failureCooldown = Duration(minutes: 5);

  static List<String> get _healthyInstances {
    final now = DateTime.now();
    final healthy = _instances.where((inst) {
      final cd = _cooldowns[inst];
      return cd == null || now.difference(cd) >= _failureCooldown;
    }).toList();
    return healthy.isNotEmpty ? healthy : List<String>.from(_instances);
  }

  static void _markInstanceFailure(String instance) {
    _cooldowns[instance] = DateTime.now();
  }

  /// Cache resolved streams for 45 minutes to avoid IP token drift
  static final Map<String, _CachedStream> _cache = {};
  static const _cacheTtl = Duration(minutes: 45);

  /// Resolve the best audio stream URL for a YouTube video ID.
  ///
  /// Returns a proxied audio URL that works on any network, or null if
  /// all instances fail.
  static Future<String?> getAudioStream(String videoId) async {
    // Check cache first
    final cached = _cache[videoId];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.url;
    }

    for (final instance in _healthyInstances) {
      try {
        final url = Uri.parse('$instance/streams/$videoId');
        final resp = await http.get(url, headers: {
          'Accept': 'application/json',
          'User-Agent': 'Sine/1.0 (Android ExoPlayer)',
        }).timeout(const Duration(milliseconds: 2500));

        if (resp.statusCode != 200) {
          _markInstanceFailure(instance);
          LogService.w('PipedService', 'Instance $instance returned HTTP ${resp.statusCode} for $videoId');
          continue;
        }

        final decoded = jsonDecode(resp.body);
        if (decoded is! Map) continue;
        final data = Map<String, dynamic>.from(decoded);
        final audioStreams = data['audioStreams'] as List? ?? [];
        final proxyUrl = data['proxyUrl'] as String?;

        if (audioStreams.isEmpty) continue;

        // Sort by bitrate descending, prefer M4A/AAC for Android hardware decoder compatibility
        final sorted = audioStreams
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
        if (sorted.isEmpty) continue;

        sorted.sort((a, b) {
          final bitrateA = (a['bitrate'] as num?) ?? 0;
          final bitrateB = (b['bitrate'] as num?) ?? 0;
          // Prefer M4A/AAC over WebM/Opus
          final formatA = (a['format'] as String? ?? '').toUpperCase();
          final formatB = (b['format'] as String? ?? '').toUpperCase();
          final isM4aA = formatA.contains('M4A') || formatA.contains('MP4') ? 1 : 0;
          final isM4aB = formatB.contains('M4A') || formatB.contains('MP4') ? 1 : 0;
          if (isM4aA != isM4aB) return isM4aB - isM4aA;
          return bitrateB.compareTo(bitrateA);
        });

        final best = sorted.first;
        String streamUrl = best['url'] as String? ?? '';

        if (streamUrl.isEmpty) continue;

        // Rewrite direct googlevideo.com URL to go through the Piped proxy
        // This prevents 403 IP-binding errors on mobile networks
        if (streamUrl.contains('googlevideo.com')) {
          final proxyTarget = (proxyUrl != null && proxyUrl.isNotEmpty) ? proxyUrl : instance;
          final parsed = Uri.parse(streamUrl);
          final proxyBase = Uri.parse(proxyTarget);
          final basePath = proxyBase.path.endsWith('/')
              ? proxyBase.path.substring(0, proxyBase.path.length - 1)
              : proxyBase.path;

          streamUrl = Uri(
            scheme: proxyBase.scheme,
            host: proxyBase.host,
            port: proxyBase.hasPort ? proxyBase.port : null,
            path: '$basePath${parsed.path}',
            query: parsed.query,
          ).toString();
        }

        // Cache the result with size bounds
        if (_cache.length >= 60) {
          cleanCache();
          if (_cache.length >= 60) {
            _cache.remove(_cache.keys.first);
          }
        }
        _cache[videoId] = _CachedStream(url: streamUrl, timestamp: DateTime.now());
        LogService.stream('PipedService', 'Resolved proxy audio for "$videoId" via $instance (${best['format']})');
        debugPrint('[PipedService] Resolved audio for "$videoId" via $instance (${best['format']} ${best['quality']})');
        return streamUrl;
      } catch (e) {
        _markInstanceFailure(instance);
        LogService.w('PipedService', 'Instance $instance failed for "$videoId": $e');
        debugPrint('[PipedService] Instance $instance failed for "$videoId": $e');
        continue;
      }
    }

    // Secondary fallback: Invidious audio proxy endpoint
    final invidiousHosts = [
      'https://invidious.projectsegfau.lt',
      'https://invidious.perennialte.ch',
    ];

    for (final host in invidiousHosts) {
      try {
        final streamUrl = '$host/latest_version?id=$videoId&itag=140';
        final check = await http.head(Uri.parse(streamUrl), headers: {
          'User-Agent': 'Sine/1.0 (Android ExoPlayer)',
        }).timeout(const Duration(seconds: 4));
        if (check.statusCode == 200 || check.statusCode == 302) {
          LogService.stream('PipedService', 'Resolved audio via Invidious proxy fallback for "$videoId"');
          return streamUrl;
        }
      } catch (e) {
        LogService.w('PipedService', 'Invidious instance $host failed for "$videoId": $e');
      }
    }

    LogService.w('PipedService', 'All fallback instances failed for "$videoId"');
    debugPrint('[PipedService] All instances failed for "$videoId"');
    return null;
  }

  /// Resolve muxed MP4 Video stream (video + audio combined) for offline video download
  static Future<String?> getVideoStream(String videoId) async {
    for (final instance in _healthyInstances) {
      try {
        final url = Uri.parse('$instance/streams/$videoId');
        final resp = await http.get(url, headers: {
          'Accept': 'application/json',
          'User-Agent': 'Sine/1.0 (Android ExoPlayer)',
        }).timeout(const Duration(milliseconds: 4000));

        if (resp.statusCode != 200) {
          _markInstanceFailure(instance);
          continue;
        }

        final decoded = jsonDecode(resp.body);
        if (decoded is! Map) continue;
        final data = Map<String, dynamic>.from(decoded);
        final videoStreams = data['videoStreams'] as List? ?? [];
        final proxyUrl = data['proxyUrl'] as String?;

        // Look for streams that have video AND audio (videoOnly == false)
        final muxed = videoStreams
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .where((s) => s['videoOnly'] == false)
            .toList();

        if (muxed.isNotEmpty) {
          // Sort by height descending (e.g. 720p before 360p)
          muxed.sort((a, b) {
            final hA = (a['height'] as num?) ?? 0;
            final hB = (b['height'] as num?) ?? 0;
            return hB.compareTo(hA);
          });
          String streamUrl = muxed.first['url'] as String? ?? '';
          if (streamUrl.isNotEmpty) {
            if (streamUrl.contains('googlevideo.com')) {
              final proxyTarget = (proxyUrl != null && proxyUrl.isNotEmpty) ? proxyUrl : instance;
              final parsed = Uri.parse(streamUrl);
              final proxyBase = Uri.parse(proxyTarget);
              final basePath = proxyBase.path.endsWith('/')
                  ? proxyBase.path.substring(0, proxyBase.path.length - 1)
                  : proxyBase.path;

              streamUrl = Uri(
                scheme: proxyBase.scheme,
                host: proxyBase.host,
                port: proxyBase.hasPort ? proxyBase.port : null,
                path: '$basePath${parsed.path}',
                query: parsed.query,
              ).toString();
            }
            LogService.stream('PipedService', 'Resolved proxy muxed video for "$videoId" via $instance (${muxed.first['quality']})');
            return streamUrl;
          }
        }
      } catch (e) {
        _markInstanceFailure(instance);
      }
    }
    return null;
  }

  /// Search YouTube via Piped. Returns a list of video results.
  /// Each result has: id, title, uploaderName, duration, thumbnail.
  static Future<List<Map<String, dynamic>>> search(String query) async {
    for (final instance in _instances) {
      try {
        final url = Uri.parse('$instance/search?q=${Uri.encodeComponent(query)}&filter=music_songs');
        final resp = await http.get(url, headers: {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 6));

        if (resp.statusCode != 200) continue;

        final decoded = jsonDecode(resp.body);
        if (decoded is! Map) continue;
        final data = Map<String, dynamic>.from(decoded);
        final items = data['items'] as List? ?? [];
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => (item['type'] as String? ?? '') == 'stream')
            .take(10)
            .toList();
      } catch (e) {
        debugPrint('[PipedService] Search failed on $instance: $e');
        continue;
      }
    }
    return [];
  }

  /// Evict expired cache entries.
  static void cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere((_, v) => now.difference(v.timestamp) >= _cacheTtl);
  }
}

class _CachedStream {
  final String url;
  final DateTime timestamp;
  const _CachedStream({required this.url, required this.timestamp});
}
