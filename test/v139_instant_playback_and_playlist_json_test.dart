import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/models/playlist.dart';
import 'package:spotify_newpipe/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.3.9+ Release & Version Integrity Suite', () {
    test('AppConstants matches release specifications', () {
      expect(AppConstants.appName, 'Sine');
      expect(AppConstants.version, matches(RegExp(r'^1\.\d+\.\d+$')));
      expect(AppConstants.buildNumber, greaterThanOrEqualTo(39));
      expect(AppConstants.fullVersion, '${AppConstants.version}+${AppConstants.buildNumber}');
      expect(AppConstants.releaseTag, 'v${AppConstants.version}');
    });

    test('pubspec.yaml specifies compliant semver version', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, matches(RegExp(r'version:\s*1\.\d+\.\d+\+\d+')));
      expect(pubspec, contains('dependency_overrides:'));
      expect(pubspec, contains('just_audio:'));
    });

    test('F-Droid metadata and cloud release script match release', () {
      final yml = File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync();
      expect(yml, matches(RegExp(r'CurrentVersion:\s*1\.\d+\.\d+')));
      expect(yml, matches(RegExp(r'CurrentVersionCode:\s*\d+')));

      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, matches(RegExp(r"'v1\.\d+\.\d+'")));
    });

    test('README.md and index.html reference release assets', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, matches(RegExp(r'v1\.\d+\.\d+')));
      expect(readme, matches(RegExp(r'Sine-v1\.\d+\.\d+\.apk')));

      final html = File('index.html').readAsStringSync();
      expect(html, matches(RegExp(r'v1\.\d+\.\d+')));
      expect(html, matches(RegExp(r'Sine-v1\.\d+\.\d+\.apk')));
    });
  });

  group('v1.3.9 Sub-200ms Instant Audio Playback Architecture Suite', () {
    test('youtube_importer_service.dart prioritizes androidVr profile for fast ~580ms manifest retrieval', () {
      final code = File('lib/services/youtube_importer_service.dart').readAsStringSync();
      expect(code, contains('YoutubeApiClient.androidVr'));
      final vrIdx = code.indexOf('YoutubeApiClient.androidVr');
      final sdklessIdx = code.indexOf('YoutubeApiClient.androidSdkless');
      expect(vrIdx, lessThan(sdklessIdx));
    });

    test('youtube_importer_service.dart prioritizes itag 18 progressive MP4 as Candidate #1 to bypass DASH 403 throttle', () {
      final code = File('lib/services/youtube_importer_service.dart').readAsStringSync();
      expect(code, contains('Priority 1: Progressive Muxed MP4'));
      expect(code, contains('manifest.muxed'));
      final muxedIdx = code.indexOf('manifest.muxed');
      final audioIdx = code.indexOf('mp4Audio.withHighestBitrate()');
      expect(muxedIdx, lessThan(audioIdx));
    });

    test('audio_handler.dart initializes setUrl with Duration.zero to prevent ExoPlayer header seek stall', () {
      final code = File('lib/services/audio_handler.dart').readAsStringSync();
      expect(code, contains('initialPosition: Duration.zero'));
      expect(code, contains('Duration(seconds: 6)'));
    });
  });

  group('v1.3.9 Standalone Settings JSON Extraction & Import Suite', () {
    test('StorageService exports valid SINE_SETTINGS JSON payload', () {
      final storage = StorageService(null);
      final jsonStr = storage.exportSettingsJson();
      expect(jsonStr, isNotEmpty);

      final decoded = jsonDecode(jsonStr);
      expect(decoded is Map, isTrue);
      expect(decoded['format'], 'SINE_SETTINGS');
      expect(decoded['version'], matches(RegExp(r'^1\.\d+\.\d+$')));
      expect(decoded['settings'], isNotNull);
      expect(decoded['settings'] is Map, isTrue);
    });

    test('StorageService imports and validates SINE_SETTINGS correctly', () async {
      final storage = StorageService(null);
      final testPayload = jsonEncode({
        'format': 'SINE_SETTINGS',
        'version': '1.3.9',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'settings': {
          'speed': 1.25,
          'crossfade': 4,
          'gapless': true,
          'clippingProtection': true,
          'recoveryMode': 'always',
          'eqPreset': 'Electronic',
          'eqEnabled': true,
          'eqBassBoost': 3.5,
          'themePreset': 'blue',
          'oledBlack': true,
        },
      });

      final success = await storage.importSettingsJson(testPayload);
      expect(success, isTrue);
    });

    test('importBackupJson gracefully detects SINE_SETTINGS format', () async {
      final storage = StorageService(null);
      final settingsJson = jsonEncode({
        'format': 'SINE_SETTINGS',
        'version': '1.3.9',
        'settings': {
          'speed': 1.0,
          'crossfade': 2,
        },
      });

      final res = await storage.importBackupJson(settingsJson);
      expect(res, isNotNull);
      expect(res?.playlistsCount, 0);
    });
  });

  group('v1.3.9 Song Playlist JSON Extraction & Import Suite', () {
    test('StorageService exports portable SINE_PLAYLIST JSON format', () {
      final storage = StorageService(null);
      final pl = Playlist(
        id: 'pl_rock_classics',
        title: 'Rock Classics',
        description: 'Greatest hits',
        songs: [
          Song(
            id: 'yt_abc1',
            title: 'Bohemian Rhapsody',
            artist: 'Queen',
            duration: const Duration(minutes: 5, seconds: 55),
            streamUrl: 'https://youtube.com/watch?v=abc1',
            artworkUrl: 'https://i.ytimg.com/vi/abc1/hqdefault.jpg',
          ),
          Song(
            id: 'yt_abc2',
            title: 'Hotel California',
            artist: 'Eagles',
            duration: const Duration(minutes: 6, seconds: 30),
            streamUrl: 'https://youtube.com/watch?v=abc2',
            artworkUrl: 'https://i.ytimg.com/vi/abc2/hqdefault.jpg',
          ),
        ],
        createdAt: DateTime.now(),
      );

      final jsonStr = storage.exportPlaylistJson(pl);
      expect(jsonStr, isNotEmpty);

      final decoded = jsonDecode(jsonStr);
      expect(decoded['format'], 'SINE_PLAYLIST');
      expect(decoded['version'], matches(RegExp(r'^1\.\d+\.\d+$')));
      expect(decoded['playlist']['title'], 'Rock Classics');
      expect(decoded['playlist']['songs'].length, 2);
    });

    test('StorageService imports single playlist JSON reliably', () async {
      final storage = StorageService(null);
      final jsonStr = jsonEncode({
        'format': 'SINE_PLAYLIST',
        'version': '1.3.9',
        'playlist': {
          'id': 'pl_synth',
          'title': 'Synthwave Nights',
          'description': 'Retro beats',
          'songs': [
            {
              'id': 'yt_synth1',
              'title': 'Midnight City',
              'artist': 'M83',
              'duration': 240,
              'streamUrl': 'https://youtube.com/watch?v=synth1',
              'artworkUrl': 'art',
            }
          ],
          'createdAt': DateTime.now().toIso8601String(),
        },
      });

      final pl = await storage.importPlaylistJson(jsonStr);
      expect(pl, isNotNull);
      expect(pl?.title, 'Synthwave Nights');
      expect(pl?.songs.length, 1);
      expect(pl?.songs.first.title, 'Midnight City');
    });

    test('importBackupJson gracefully detects single SINE_PLAYLIST format', () async {
      final storage = StorageService(null);
      final jsonStr = jsonEncode({
        'format': 'SINE_PLAYLIST',
        'version': '1.3.9',
        'playlist': {
          'id': 'pl_chill',
          'title': 'Chill Lofi',
          'songs': [
            {
              'id': 'yt_chill1',
              'title': 'Coffee Breath',
              'artist': 'Lofi Beats',
              'duration': 180,
              'streamUrl': 'test',
              'artworkUrl': 'test',
            }
          ],
        },
      });

      final res = await storage.importBackupJson(jsonStr);
      expect(res, isNotNull);
      expect(res?.playlistsCount, 1);
    });
  });
}
