import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_newpipe/models/downloaded_video.dart';
import 'package:spotify_newpipe/services/catalog_service.dart';
import 'package:spotify_newpipe/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.3.4 Features & Optimizations Verification', () {
    test('T1. DownloadedVideo model serialization and size formatting', () {
      final video = DownloadedVideo(
        id: 'test_vid_1',
        title: 'Illenium - Nightlight (Official Video)',
        artist: 'Illenium',
        filePath: '/storage/emulated/0/Movies/Sine/test_vid_1.mp4',
        artworkUrl: 'https://img.youtube.com/vi/test/hqdefault.jpg',
        sizeBytes: 45 * 1024 * 1024 + 512 * 1024, // ~45.5 MB
        duration: const Duration(minutes: 3, seconds: 42),
        downloadedAt: DateTime(2026, 11, 17, 1, 0, 0),
      );

      expect(video.sizeFormatted, '45.5 MB');

      final map = video.toMap();
      final restored = DownloadedVideo.fromMap(map);

      expect(restored.id, video.id);
      expect(restored.title, video.title);
      expect(restored.artist, video.artist);
      expect(restored.filePath, video.filePath);
      expect(restored.sizeBytes, video.sizeBytes);
      expect(restored.duration.inSeconds, 222);
    });

    test('T2. StorageService downloaded videos persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      expect(storage.loadDownloadedVideos(), isEmpty);

      final video = DownloadedVideo(
        id: 'vid_42',
        title: 'Deadmau5 - Strobe (Live)',
        artist: 'Deadmau5',
        filePath: '/storage/emulated/0/Movies/Sine/vid_42.mp4',
        artworkUrl: '',
        sizeBytes: 104857600, // 100 MB
        downloadedAt: DateTime(2026, 11, 17, 1, 30, 0),
      );

      await storage.saveDownloadedVideos([video]);
      final loaded = storage.loadDownloadedVideos();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'vid_42');
      expect(loaded.first.sizeFormatted, '100.0 MB');

      await storage.deleteDownloadedVideo('vid_42');
      expect(storage.loadDownloadedVideos(), isEmpty);
    });

    test('T3. Notification Style Widget Layout & RemoteViews Safety (Redmi Note 5 Pro MIUI)', () {
      final widgetXml = File('android/app/src/main/res/layout/sine_music_widget.xml').readAsStringSync();

      // Crucial: No bare <View> tags allowed on Redmi Note 5 Pro (causes MIUI RemoteViews crash)
      final bareViewPattern = RegExp(r'<View[\s/>]');
      expect(bareViewPattern.hasMatch(widgetXml), isFalse,
          reason: 'Widget must not contain bare <View> tags for MIUI compatibility');

      // Crucial: Must include all notification elements
      expect(widgetXml.contains('widget_root'), isTrue);
      expect(widgetXml.contains('widget_album_art'), isTrue);
      expect(widgetXml.contains('widget_song_title'), isTrue);
      expect(widgetXml.contains('widget_song_artist'), isTrue);
      expect(widgetXml.contains('widget_progress_bar'), isTrue);
      expect(widgetXml.contains('widget_btn_prev'), isTrue);
      expect(widgetXml.contains('widget_btn_play'), isTrue);
      expect(widgetXml.contains('widget_btn_next'), isTrue);
    });

    test('T4. Android Widget Info XML declares valid initialLayout and provider configuration', () {
      final infoXml = File('android/app/src/main/res/xml/sine_widget_info.xml').readAsStringSync();
      expect(infoXml.contains('initialLayout="@layout/sine_music_widget"'), isTrue);
      expect(infoXml.contains('minWidth="250dp"'), isTrue);
      expect(infoXml.contains('minHeight="110dp"'), isTrue);
    });

    test('T5. AndroidManifest FileProvider and Widget Provider registrations', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(manifest.contains('androidx.core.content.FileProvider'), isTrue);
      expect(manifest.contains('\${applicationId}.fileprovider'), isTrue);
      expect(manifest.contains('.SineMusicWidgetProvider'), isTrue);
      expect(manifest.contains('android.appwidget.action.APPWIDGET_UPDATE'), isTrue);
    });

    test('T6. Trending Section electric dance curation & anti-spam filter', () {
      final catalog = CatalogService.categories.firstWhere((c) => c.key == 'trending');
      expect(catalog.title, 'Trending Electric Hits');
      expect(catalog.searchQuery.contains('electronic dance'), isTrue);
    });
  });
}
