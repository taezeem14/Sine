import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.4.3 Release & Version Integrity Suite', () {
    test('All version artifacts strictly match v1.4.3+43', () {
      expect(AppConstants.version, '1.4.3');
      expect(AppConstants.buildNumber, 43);
      expect(AppConstants.fullVersion, '1.4.3+43');
      expect(AppConstants.releaseTag, 'v1.4.3');

      expect(File('pubspec.yaml').readAsStringSync(), contains('version: 1.4.3+43'));
      expect(
        File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync(),
        allOf(contains('CurrentVersion: 1.4.3'), contains('CurrentVersionCode: 43')),
      );
      expect(File('scripts/fetch_cloud_release.py').readAsStringSync(), contains("'v1.4.3'"));
      expect(File('README.md').readAsStringSync(), allOf(contains('v1.4.3'), contains('Sine-v1.4.3.apk')));
      expect(File('index.html').readAsStringSync(), allOf(contains('v1.4.3'), contains('Sine-v1.4.3.apk')));
    });
  });

  group('v1.4.3 Classic MiniPlayer Restoration Suite', () {
    test('MiniPlayer contains rotating VinylDisc art peek & classic Obsidian UI layout', () {
      final code = File('lib/widgets/mini_player.dart').readAsStringSync();
      expect(code, contains("import 'vinyl_disc.dart';"));
      expect(code, contains('VinylDisc('));
      expect(code, contains('LinearProgressIndicator('));
      expect(code, contains('FontAwesomeIcons.forwardStep'));
      expect(code, contains('FontAwesomeIcons.pause'));
      expect(code, contains('FontAwesomeIcons.play'));
      expect(code, contains('FontAwesomeIcons.solidHeart'));
      expect(code, contains('activeAccentColor'));
      expect(code, contains('isOledBlack'));
      expect(code, contains('player.stopPlayback()'));
      expect(code, contains('onHorizontalDragStart'));
      expect(code, contains('onHorizontalDragUpdate'));
      expect(code, contains('onHorizontalDragEnd'));
      expect(code, contains('onVerticalDragStart'));
      expect(code, contains('onVerticalDragUpdate'));
      expect(code, contains('onVerticalDragEnd'));
      expect(code, contains('onLongPress'));
      expect(code, contains('_dragOffsetNotifier'));
      expect(code, contains('begin: const Offset(0.0, 1.0)'));
    });
  });

  group('v1.4.3 Older UI Audits & Modernization Suite', () {
    test('PulsePipeHomeTab uses _HomeTrackTile with granular selectors & zero unused variables', () {
      final code = File('lib/screens/tabs/pulsepipe_home_tab.dart').readAsStringSync();
      expect(code, contains('class _HomeTrackTile extends StatelessWidget'));
      expect(code, contains('_HomeTrackTile('));
      expect(code, contains('if (hasSession && player.recoverableSession != null)'));
      expect(code, contains('if (isYtLoading)'));
      expect(code, isNot(contains('final currentSongId = context.select')));
      expect(code, isNot(contains('final favoritesCount = context.select')));
    });

    test('PulsePipeLibraryTab has mounted guards and clean imports', () {
      final code = File('lib/screens/tabs/pulsepipe_library_tab.dart').readAsStringSync();
      expect(code, isNot(contains("import '../../models/downloaded_video.dart';")));
      expect(code, isNot(contains('void _openDownloads(')));
      expect(code, contains('if (dCtx.mounted)'));
    });

    test('CategoryDetailSheet supports OLED Black & dynamic theme accent', () {
      final code = File('lib/widgets/category_detail_sheet.dart').readAsStringSync();
      expect(code, contains('isOledBlack'));
      expect(code, contains('isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase'));
      expect(code, contains('Theme.of(context).colorScheme.primary'));
    });

    test('AppLockScreen supports OLED Black & dynamic theme accent on keypad & icons', () {
      final code = File('lib/screens/app_lock_screen.dart').readAsStringSync();
      expect(code, contains('Theme.of(context).colorScheme.primary'));
      expect(code, contains('isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase'));
      expect(code, contains('_buildKeypadRow'));
    });

    test('TrackMetadataSheet uses CachedNetworkImage & dynamic theme accent', () {
      final code = File('lib/widgets/track_metadata_sheet.dart').readAsStringSync();
      expect(code, contains("import 'package:cached_network_image/cached_network_image.dart';"));
      expect(code, contains('CachedNetworkImage('));
      expect(code, contains('Theme.of(context).colorScheme.primary'));
      expect(code, contains('isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase'));
    });

    test('PlaylistDetailSheet supports OLED Black mode in bottom sheet', () {
      final code = File('lib/screens/playlist_detail_sheet.dart').readAsStringSync();
      expect(code, contains('isOledBlack'));
      expect(code, contains('isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase'));
    });

    test('DiagnosticsLogScreen supports OLED Black mode & dynamic theme accent', () {
      final code = File('lib/screens/diagnostics_log_screen.dart').readAsStringSync();
      expect(code, contains('isOledBlack'));
      expect(code, contains('isOled ? EmberColors.pitchBlack : EmberColors.obsidianBase'));
      expect(code, contains('Theme.of(context).colorScheme.primary'));
    });
  });
}
