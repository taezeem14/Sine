import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_newpipe/services/storage_service.dart';
import 'package:spotify_newpipe/services/local_music_service.dart';
import 'package:spotify_newpipe/services/playlist_import_service.dart';
import 'package:spotify_newpipe/widgets/aesthetic_playlist_cover.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.3.5 Features Verification Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('T1. LocalMusicService filename parsing and extension filtering', () {
      final (artist1, title1) = LocalMusicService.parseArtistAndTitle('Daft Punk - One More Time.mp3');
      expect(artist1, equals('Daft Punk'));
      expect(title1, equals('One More Time'));

      final (artist2, title2) = LocalMusicService.parseArtistAndTitle('TrackNameOnly.flac');
      expect(artist2, equals('Unknown Artist'));
      expect(title2, equals('TrackNameOnly'));

      expect(LocalMusicService.formatDuration(Duration(seconds: 195)), equals('3:15'));
      expect(LocalMusicService.formatDuration(Duration(seconds: 45)), equals('0:45'));

      expect(LocalMusicService.supportedExtensions.contains('.mp3'), isTrue);
      expect(LocalMusicService.supportedExtensions.contains('.flac'), isTrue);
      expect(LocalMusicService.supportedExtensions.contains('.m4a'), isTrue);
      expect(LocalMusicService.supportedExtensions.contains('.wav'), isTrue);
      expect(LocalMusicService.supportedExtensions.contains('.aac'), isTrue);
      expect(LocalMusicService.supportedExtensions.contains('.ogg'), isTrue);
      expect(LocalMusicService.supportedExtensions.contains('.txt'), isFalse);
    });

    test('T2. PlaylistImportService URL detection and regex extraction', () {
      final spotifyUrl = 'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=123';
      final appleUrl = 'https://music.apple.com/us/playlist/todays-hits/pl.f4d1060b52a243d195251b14d5b738e9';
      final ytUrl = 'https://youtube.com/playlist?list=PL123456789';
      final invalidUrl = 'https://example.com/not-a-playlist';

      expect(PlaylistImportService.detectSource(spotifyUrl), equals(PlaylistSource.spotify));
      expect(PlaylistImportService.detectSource(appleUrl), equals(PlaylistSource.appleMusic));
      expect(PlaylistImportService.detectSource(ytUrl), equals(PlaylistSource.youtube));
      expect(PlaylistImportService.detectSource(invalidUrl), equals(PlaylistSource.unsupported));

      expect(PlaylistImportService.extractSpotifyPlaylistId(spotifyUrl), equals('37i9dQZF1DXcBWIGoYBM5M'));
      expect(PlaylistImportService.extractAppleMusicPlaylistId(appleUrl), equals('pl.f4d1060b52a243d195251b14d5b738e9'));

      final cleanTitle = PlaylistImportService.cleanTrackTitle('Song Title (Official Music Video) [HD] ft. Artist');
      expect(cleanTitle.contains('Official Music Video'), isFalse);
      expect(cleanTitle.contains('[HD]'), isFalse);
    });

    test('T3. AestheticPlaylistCover theme catalog and color sets', () {
      expect(AestheticPlaylistCover.themes.length, greaterThanOrEqualTo(6));
      final ids = AestheticPlaylistCover.themes.map((t) => t.id).toList();
      expect(ids, contains('neon_pulse'));
      expect(ids, contains('midnight_violet'));
      expect(ids, contains('cyber_amber'));
      expect(ids, contains('aurora_green'));
      expect(ids, contains('hyper_pink'));
      expect(ids, contains('monochrome_glass'));

      final theme1 = AestheticPlaylistCover.getThemeById('neon_pulse');
      expect(theme1.id, equals('neon_pulse'));
      expect(theme1.gradientColors.length, greaterThanOrEqualTo(2));

      // Fallback for unknown theme ID
      final fallbackTheme = AestheticPlaylistCover.getThemeById('unknown_invalid_id');
      expect(fallbackTheme.id, equals('neon_pulse'));
    });

    test('T4. StorageService persistence for DSP, Presets, and Hardware Gestures', () async {
      final storage = await StorageService.init();

      // Defaults
      expect(storage.loadLoudnessNormalization(), isTrue);
      expect(storage.loadSkipSilence(), isFalse);
      expect(storage.loadAcousticPreset(), equals('normal'));
      expect(storage.loadBassExciter(), equals(0.0));
      expect(storage.loadSpatializer(), equals(0.0));
      expect(storage.loadShakeToSkip(), isFalse);
      expect(storage.loadFlipToPause(), isFalse);

      // Save and reload
      await storage.saveLoudnessNormalization(false);
      expect(storage.loadLoudnessNormalization(), isFalse);

      await storage.saveSkipSilence(true);
      expect(storage.loadSkipSilence(), isTrue);

      await storage.saveAcousticPreset('slowedReverb');
      expect(storage.loadAcousticPreset(), equals('slowedReverb'));

      await storage.saveBassExciter(0.45);
      expect(storage.loadBassExciter(), closeTo(0.45, 0.001));

      await storage.saveSpatializer(0.70);
      expect(storage.loadSpatializer(), closeTo(0.70, 0.001));

      await storage.saveShakeToSkip(true);
      expect(storage.loadShakeToSkip(), isTrue);

      await storage.saveFlipToPause(true);
      expect(storage.loadFlipToPause(), isTrue);
    });

    test('T5. Android Auto Automotive declaration and Manifest integration', () {
      final autoXmlFile = File('android/app/src/main/res/xml/automotive_app_desc.xml');
      expect(autoXmlFile.existsSync(), isTrue, reason: 'automotive_app_desc.xml must exist');
      final autoXml = autoXmlFile.readAsStringSync();
      expect(autoXml, contains('<automotiveApp>'));
      expect(autoXml, contains('<uses name="media"'));

      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifest = manifestFile.readAsStringSync();
      expect(manifest, contains('com.google.android.gms.car.application'));
      expect(manifest, contains('@xml/automotive_app_desc'));
    });

    test('T6. Notification-Style Widget Layout & RemoteViews Safety (Redmi Note 5 Pro MIUI)', () {
      final widgetLayoutFile = File('android/app/src/main/res/layout/sine_music_widget.xml');
      expect(widgetLayoutFile.existsSync(), isTrue);
      final layout = widgetLayoutFile.readAsStringSync();

      // MIUI RemoteViews crash prevention: No bare <View> tags allowed
      expect(layout.contains('<View\n') || layout.contains('<View '), isFalse,
          reason: 'Widget layout must not contain bare <View> tags which crash MIUI/Redmi Note 5 Pro');

      // Artwork container & centerCrop
      expect(layout, contains('android:id="@+id/widget_album_art"'));
      expect(layout, contains('android:scaleType="centerCrop"'));
      expect(layout, contains('android:id="@+id/widget_btn_play"'));
      expect(layout, contains('android:id="@+id/widget_btn_prev"'));
      expect(layout, contains('android:id="@+id/widget_btn_next"'));
    });

    test('T7. Accelerometer Physical Gestures Native Integration', () {
      final mainActivityFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/MainActivity.kt');
      expect(mainActivityFile.existsSync(), isTrue);
      final code = mainActivityFile.readAsStringSync();

      expect(code, contains('Sensor.TYPE_ACCELEROMETER'));
      expect(code, contains('SensorEventListener'));
      expect(code, contains('com.taezeem.spotify_newpipe/gestures'));
      expect(code, contains('onShakeDetected'));
      expect(code, contains('onFlipDown'));
      expect(code, contains('onFlipUp'));
    });
  });
}
