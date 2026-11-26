import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/models/playlist.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/services/catalog_service.dart';
import 'package:spotify_newpipe/services/storage_service.dart';
import 'package:spotify_newpipe/services/youtube_importer_service.dart';
import 'package:spotify_newpipe/theme/ember_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.5 Release & Reverted v1.4.3 UI Integrity Suite', () {
    test('All version artifacts strictly match v1.4.5+45', () {
      expect(AppConstants.version, '1.4.5');
      expect(AppConstants.buildNumber, 45);
      expect(AppConstants.fullVersion, '1.4.5+45');
      expect(AppConstants.releaseTag, 'v1.4.5');

      expect(File('pubspec.yaml').readAsStringSync(), contains('version: 1.4.5+45'));
      expect(
        File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync(),
        allOf(contains('CurrentVersion: 1.4.5'), contains('CurrentVersionCode: 45')),
      );
      expect(File('scripts/fetch_cloud_release.py').readAsStringSync(), contains("'v1.4.5'"));
      expect(File('README.md').readAsStringSync(), allOf(contains('v1.4.5'), contains('Sine-v1.4.5.apk')));
      expect(File('index.html').readAsStringSync(), allOf(contains('v1.4.5'), contains('Sine-v1.4.5.apk')));
    });

    test('UI reverted to v1.4.3 Sine aesthetic & Original OG MiniPlayer with 120 FPS swipes', () {
      expect(SineThemePreset.values.length, 8);
      expect(SineThemePreset.fromKey(null), SineThemePreset.blue);
      expect(SineThemePreset.green.label, isNot('Spotify Green'));

      final miniCode = File('lib/widgets/mini_player.dart').readAsStringSync();
      // Original pre-color-coded OG MiniPlayer traits
      expect(miniCode, contains('EmberColors.surfaceContainerLow.withValues(alpha: 0.95)'));
      expect(miniCode, contains('EmberColors.outlineVariant.withValues(alpha: 0.6)'));
      expect(miniCode, contains('VinylDisc('));
      expect(miniCode, isNot(contains('labelColor:')));
      // Swipe features preserved
      expect(miniCode, contains('onHorizontalDragEnd'));
      expect(miniCode, contains('onVerticalDragEnd'));
      expect(miniCode, contains('player.stopPlayback()'));
      expect(miniCode, contains('_dragOffsetNotifier'));
    });
  });

  group('v1.4.5 Universal Playlist & Backup Export/Import Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Exports and re-imports SINE_PLAYLIST with BOM, code fences & smart track merge', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      const songA = Song(
        id: 'yt_dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: Duration(minutes: 3, seconds: 33),
        artworkUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        streamUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      const songB = Song(
        id: 'yt_3JZ_D3ELwOQ',
        title: 'See You Again',
        artist: 'Wiz Khalifa',
        duration: Duration(minutes: 3, seconds: 50),
        artworkUrl: 'https://i.ytimg.com/vi/3JZ_D3ELwOQ/hqdefault.jpg',
        streamUrl: 'https://www.youtube.com/watch?v=3JZ_D3ELwOQ',
      );

      final pl = Playlist(
        id: 'pl_test_1',
        title: 'Road Trip Anthems',
        description: 'Test export',
        songs: [songA],
        createdAt: DateTime.utc(2026, 11, 27),
        continuationToken: 'tok_abc',
        nextVideoId: 'dQw4w9WgXcQ',
      );

      final exported = storage.exportPlaylistJson(pl);
      expect(StorageService.detectJsonFormat(exported), 'SINE_PLAYLIST');

      // Wrap in UTF-8 BOM and Markdown code fence (common chat app copy/paste artifact)
      final wrapped = '\uFEFF```json\n$exported\n```';
      final imported1 = await storage.importPlaylistJson(wrapped);
      expect(imported1, isNotNull);
      expect(imported1!.title, 'Road Trip Anthems');
      expect(imported1.songs.length, 1);
      expect(imported1.continuationToken, 'tok_abc');
      expect(imported1.nextVideoId, 'dQw4w9WgXcQ');

      // Re-import updated version with extra track -> smart merge keeps both tracks!
      final exported2 = storage.exportPlaylistJson(pl.copyWith(songs: [songB]));
      final imported2 = await storage.importPlaylistJson(exported2);
      expect(imported2, isNotNull);
      expect(imported2!.songs.length, 2);
    });

    test('Imports NewPipe exported playlist JSON seamlessly', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      final newPipeJson = jsonEncode({
        'app_version': '0.27.2',
        'playlists': [
          {
            'name': 'My NewPipe Mix',
            'streams': [
              {
                'url': 'https://www.youtube.com/watch?v=fJ9rUzIMcZQ',
                'title': 'Queen - Bohemian Rhapsody',
                'uploader': 'Queen Official',
                'duration': 359,
              },
              {
                'url': 'https://www.youtube.com/watch?v=kJQP7kiw5Fk',
                'title': 'Luis Fonsi - Despacito',
                'uploader': 'Luis Fonsi',
                'duration': 282,
              },
            ],
          }
        ],
      });

      final imported = await storage.importPlaylistJson(newPipeJson);
      expect(imported, isNotNull);
      expect(imported!.title, 'My NewPipe Mix');
      expect(imported.songs.length, 2);
      expect(imported.songs.first.id, 'yt_fJ9rUzIMcZQ');
    });
  });

  group('v1.4.5 Categories, NewPipe Pagination & MediaStore Audio Suite', () {
    test('CatalogService normalizes all Home genre pills distinctly', () {
      expect(CatalogService.normalizeCategoryKey('All'), 'trending');
      expect(CatalogService.normalizeCategoryKey('Top Hits'), 'top_hits');
      expect(CatalogService.normalizeCategoryKey('Pop'), 'pop');
      expect(CatalogService.normalizeCategoryKey('Hip-Hop'), 'hiphop');
      expect(CatalogService.normalizeCategoryKey('Electronic'), 'electronic');
      expect(CatalogService.normalizeCategoryKey('Lo-Fi'), 'lofi');
      expect(CatalogService.normalizeCategoryKey('Rock'), 'rock');

      expect(
        CatalogService.getCategoryMeta('Top Hits').title,
        isNot(CatalogService.getCategoryMeta('Electronic').title),
      );
    });

    test('YouTubeImporterService extracts seed video IDs accurately without corrupting RDCLAK mixes', () {
      expect(YouTubeImporterService.extractSeedVideoIdFromMixId('RDdQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(YouTubeImporterService.extractSeedVideoIdFromMixId('RDAMVMdQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(YouTubeImporterService.extractSeedVideoIdFromMixId('RDMMdQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      // Curated radio IDs like RDCLAK5uy_... do NOT embed an 11-char video ID at index 2..13
      expect(
        YouTubeImporterService.extractSeedVideoIdFromMixId('RDCLAK5uy_kmPRjHDECIcuVwnKsx2Ng7fyNgFKWNJFs'),
        isNull,
      );
    });

    test('MediaStore content:// URIs and device source songs are never flagged as placeholders', () {
      const mediaStoreSong = Song(
        id: 'media_4092',
        title: 'Midnight City',
        artist: 'M83',
        duration: Duration(minutes: 4, seconds: 3),
        artworkUrl: '',
        streamUrl: 'content://media/external/audio/media/4092',
        source: 'device',
      );
      expect(Song.isPlaceholder(mediaStoreSong), isFalse);

      final mainActivityKt = File(
        'android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/MainActivity.kt',
      ).readAsStringSync();
      expect(mainActivityKt, contains('queryDeviceAudio'));
      expect(mainActivityKt, contains('saveDocumentJson'));
      expect(mainActivityKt, contains('pickDocumentJson'));
      expect(mainActivityKt, contains('MediaStore.Audio.Media'));
    });
  });
}
