import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/models/playlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.3.2 Permanent Keystore & File-Based Backup Suite', () {
    test('AppConstants matches v1.3.2/v1.3.3/v1.3.4/v1.3.5/v1.3.6 Release Spec', () {
      expect(AppConstants.appName, 'Sine');
      expect(AppConstants.version, anyOf('1.3.2', '1.3.3', '1.3.4', '1.3.5', '1.3.6'));
      expect(AppConstants.buildNumber, anyOf(32, 33, 34, 35, 36));
      expect(AppConstants.fullVersion, anyOf('1.3.2+32', '1.3.3+33', '1.3.4+34', '1.3.5+35', '1.3.6+36'));
      expect(AppConstants.releaseTag, anyOf('v1.3.2', 'v1.3.3', 'v1.3.4', 'v1.3.5', 'v1.3.6'));
    });

    test('Permanent RSA-2048 sine-release.jks keystore exists in android/app', () {
      final keystore = File('android/app/sine-release.jks');
      expect(keystore.existsSync(), isTrue, reason: 'sine-release.jks must exist to fix INSTALL_FAILED_UPDATE_INCOMPATIBLE');
      expect(keystore.lengthSync(), greaterThan(1000), reason: 'Keystore must contain valid PKCS12 certificate');
    });

    test('build.gradle.kts signs release builds with permanent sine-release.jks', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);
      final content = gradleFile.readAsStringSync();
      expect(content, contains('storeFile = file("sine-release.jks")'));
      expect(content, contains('keyAlias = "sine"'));
      expect(content, contains('signingConfig = signingConfigs.getByName("release")'));
    });

    test('Backup JSON payload structure adheres to SINE_BACKUP schema', () {
      const dummySong = Song(
        id: 'test_track_1',
        title: 'Starboy',
        artist: 'The Weeknd',
        artworkUrl: 'https://img.youtube.com/vi/test_track_1/maxresdefault.jpg',
        streamUrl: 'https://example.com/audio.opus',
        duration: Duration(seconds: 230),
      );

      final dummyPlaylist = Playlist(
        id: 'pl_favorites_test',
        title: 'Synthwave Night',
        songs: [dummySong],
        createdAt: DateTime.now(),
      );

      final payload = {
        'format': 'SINE_BACKUP',
        'version': AppConstants.version,
        'versionCode': AppConstants.buildNumber,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'playlists': [dummyPlaylist.toMap()],
        'favorites': [dummySong.toMap()],
        'history': [dummySong.toMap()],
        'settings': {
          'speed': 1.0,
          'crossfade': 3,
          'gapless': true,
          'clippingProtection': true,
          'recoveryMode': 'auto_resample',
          'stemEngine': 'audiocraft',
          'eqPreset': 'AutoEq: Harman Target',
          'eqEnabled': true,
          'eqBassBoost': 0.3,
          'eqBandGains': {'0': 5.2, '1': 3.1, '2': 0.0, '3': 1.2, '4': 2.8, '5': 4.2},
        },
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
      expect(jsonStr, contains('SINE_BACKUP'));
      expect(jsonStr, contains(AppConstants.version));
      expect(jsonStr, contains('Synthwave Night'));

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['format'], 'SINE_BACKUP');
      expect(decoded['version'], anyOf('1.3.2', '1.3.3', '1.3.4', '1.3.5', '1.3.6'));
      expect(decoded['versionCode'], anyOf(32, 33, 34, 35, 36));

      final playlists = decoded['playlists'] as List;
      expect(playlists.length, 1);
      final parsedPl = Playlist.fromMap(Map<String, dynamic>.from(playlists[0]));
      expect(parsedPl.title, 'Synthwave Night');
      expect(parsedPl.songs.first.title, 'Starboy');
    });
  });
}
