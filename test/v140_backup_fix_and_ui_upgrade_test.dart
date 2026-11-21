import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/models/playlist.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/services/storage_service.dart';
import 'package:spotify_newpipe/widgets/smooth_animations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.0 Release & Version Integrity Suite', () {
    test('AppConstants, pubspec, metadata, script, README & index.html match v1.4.x release', () {
      expect(AppConstants.appName, 'Sine');
      expect(AppConstants.version, matches(RegExp(r'^1\.4\.\d+$')));
      expect(AppConstants.buildNumber, greaterThanOrEqualTo(40));
      expect(AppConstants.fullVersion, '${AppConstants.version}+${AppConstants.buildNumber}');
      expect(AppConstants.releaseTag, 'v${AppConstants.version}');

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, matches(RegExp(r'version:\s*1\.4\.\d+\+\d+')));

      final yml = File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync();
      expect(yml, matches(RegExp(r'CurrentVersion:\s*1\.4\.\d+')));
      expect(yml, matches(RegExp(r'CurrentVersionCode:\s*\d+')));

      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, matches(RegExp(r"'v1\.4\.\d+'")));

      final readme = File('README.md').readAsStringSync();
      expect(readme, matches(RegExp(r'v1\.4\.\d+')));
      expect(readme, matches(RegExp(r'Sine-v1\.4\.\d+\.apk')));

      final html = File('index.html').readAsStringSync();
      expect(html, matches(RegExp(r'v1\.4\.\d+')));
      expect(html, matches(RegExp(r'Sine-v1\.4\.\d+\.apk')));
    });
  });

  group('v1.4.0 Bulletproof Backup & Settings JSON Bug-Fix Suite', () {
    test('CRITICAL: exportBackupJson & exportSettingsJson succeed with NON-EMPTY int-keyed eqBandGains', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      // Reproduce the exact v1.3.9 crash: non-empty Map<int, double> in EQ band gains!
      await storage.saveBandGains({0: 4.5, 1: 2.0, 2: -1.5, 3: 0.5, 4: 3.0, 5: 5.0});
      await storage.saveEqualizerEnabled(true);
      await storage.saveEqualizerPreset('Custom');
      await storage.saveBassBoost(3.2);
      await storage.saveThemePreset('emerald');
      await storage.saveOledBlack(true);
      await storage.savePlaybackSpeed(1.15);
      await storage.saveCrossfadeSeconds(5);
      await storage.saveShakeToSkip(true);

      await storage.savePlaylist(
        Playlist(
          id: 'pl_1',
          title: 'Night Drive',
          songs: const [
            Song(
              id: 'yt_s1',
              title: 'Blinding Lights',
              artist: 'The Weeknd',
              duration: Duration(minutes: 3, seconds: 20),
              artworkUrl: 'https://i.ytimg.com/vi/s1/hqdefault.jpg',
              streamUrl: 'https://youtube.com/watch?v=s1',
            ),
          ],
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      // Must NOT throw JsonUnsupportedObjectError!
      final backupJson = storage.exportBackupJson();
      final settingsJson = storage.exportSettingsJson();

      final decodedBackup = jsonDecode(backupJson) as Map<String, dynamic>;
      expect(decodedBackup['format'], 'SINE_BACKUP');
      expect(decodedBackup['settings']['eqBandGains'], isA<Map>());
      expect(decodedBackup['settings']['eqBandGains']['0'], 4.5);
      expect(decodedBackup['settings']['eqBandGains']['5'], 5.0);
      expect(decodedBackup['settings']['themePreset'], 'emerald');
      expect(decodedBackup['settings']['oledBlack'], isTrue);
      expect(decodedBackup['settings']['shakeToSkip'], isTrue);

      final decodedSettings = jsonDecode(settingsJson) as Map<String, dynamic>;
      expect(decodedSettings['format'], 'SINE_SETTINGS');
      expect(decodedSettings['settings']['eqBandGains']['2'], -1.5);

      // Now wipe SharedPreferences and verify FULL restore roundtrip!
      SharedPreferences.setMockInitialValues({});
      final freshStorage = await StorageService.init();
      expect(freshStorage.loadBandGains(), isEmpty);
      expect(freshStorage.loadPlaylists(), isEmpty);

      final res = await freshStorage.importBackupJson(backupJson, merge: false);
      expect(res, isNotNull);
      expect(res!.playlistsCount, 1);
      expect(freshStorage.loadPlaylists().first.title, 'Night Drive');
      expect(freshStorage.loadBandGains()[0], 4.5);
      expect(freshStorage.loadBandGains()[5], 5.0);
      expect(freshStorage.loadThemePreset(), 'emerald');
      expect(freshStorage.loadOledBlack(), isTrue);
      expect(freshStorage.loadPlaybackSpeed(), 1.15);
      expect(freshStorage.loadCrossfadeSeconds(), 5);
      expect(freshStorage.loadShakeToSkip(), isTrue);
    });

    test('Smart merge combines new tracks into existing playlist with same ID', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      const songA = Song(
        id: 'yt_a',
        title: 'Track A',
        artist: 'Artist A',
        duration: Duration(minutes: 3),
        artworkUrl: '',
        streamUrl: 'https://youtube.com/watch?v=a',
      );
      const songB = Song(
        id: 'yt_b',
        title: 'Track B',
        artist: 'Artist B',
        duration: Duration(minutes: 4),
        artworkUrl: '',
        streamUrl: 'https://youtube.com/watch?v=b',
      );

      await storage.savePlaylist(
        Playlist(id: 'pl_shared', title: 'My Mix', songs: const [songA], createdAt: DateTime.utc(2026)),
      );

      final incoming = jsonEncode({
        'format': 'SINE_BACKUP',
        'playlists': [
          Playlist(id: 'pl_shared', title: 'My Mix', songs: const [songA, songB], createdAt: DateTime.utc(2026)).toMap(),
        ],
      });

      final res = await storage.importBackupJson(incoming, merge: true);
      expect(res, isNotNull);
      final merged = storage.loadPlaylists().firstWhere((p) => p.id == 'pl_shared');
      expect(merged.songs.length, 2);
      expect(merged.songs.map((s) => s.id), containsAll(['yt_a', 'yt_b']));
    });

    test('Song.fromMap handles both duration_ms and duration (seconds)', () {
      final fromSeconds = Song.fromMap({
        'id': 'yt_sec',
        'title': 'Seconds Track',
        'artist': 'Artist',
        'duration': 215,
        'streamUrl': 'https://youtube.com/watch?v=sec',
      });
      expect(fromSeconds.duration, const Duration(seconds: 215));

      final fromMs = Song.fromMap({
        'id': 'yt_ms',
        'title': 'Millis Track',
        'artist': 'Artist',
        'duration_ms': 185000,
        'stream_url': 'https://youtube.com/watch?v=ms',
      });
      expect(fromMs.duration, const Duration(milliseconds: 185000));
    });

    test('StorageService.detectJsonFormat accurately classifies BACKUP, SETTINGS & PLAYLIST', () {
      expect(StorageService.detectJsonFormat('{"format": "SINE_BACKUP"}'), 'SINE_BACKUP');
      expect(StorageService.detectJsonFormat('{"format": "SINE_SETTINGS"}'), 'SINE_SETTINGS');
      expect(StorageService.detectJsonFormat('{"format": "SINE_PLAYLIST"}'), 'SINE_PLAYLIST');
      expect(StorageService.detectJsonFormat('{"title": "Test", "songs": []}'), 'SINE_PLAYLIST');
      expect(StorageService.detectJsonFormat('not valid json'), 'UNKNOWN');
    });
  });

  group('v1.4.0 Smooth Motion & Anti-Jank Architecture Suite', () {
    testWidgets('AnimatedIndexedStack transitions cleanly between tabs while preserving state', (tester) async {
      int idx = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AnimatedIndexedStack(
                index: idx,
                children: const [
                  Center(child: Text('Tab 0')),
                  Center(child: Text('Tab 1')),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => setState(() => idx = 1),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tab 0'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Tab 1'), findsOneWidget);
    });

    test('Hot-path screens eliminate full context.watch<PlayerProvider>() rebuild bottlenecks', () {
      for (final path in [
        'lib/widgets/mini_player.dart',
        'lib/screens/queue_discovery_screen.dart',
        'lib/screens/playlist_detail_sheet.dart',
        'lib/screens/tabs/pulsepipe_search_tab.dart',
        'lib/screens/lyrics_sheet.dart',
      ]) {
        final code = File(path).readAsStringSync();
        expect(code, isNot(contains('context.watch<PlayerProvider>()')), reason: '$path must use surgical context.select');
      }

      final nowPlaying = File('lib/screens/now_playing_screen.dart').readAsStringSync();
      expect(nowPlaying, isNot(contains('IntrinsicHeight(')));
      expect(nowPlaying, contains('onHorizontalDragEnd'));

      final shell = File('lib/screens/pulsepipe_shell_screen.dart').readAsStringSync();
      expect(shell, contains('AnimatedIndexedStack'));
    });
  });
}
