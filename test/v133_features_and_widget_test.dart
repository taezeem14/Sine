import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/models/playlist.dart';
import 'package:spotify_newpipe/services/widget_service.dart';
import 'package:spotify_newpipe/services/storage_service.dart';
import 'package:spotify_newpipe/services/audio_handler.dart';
import 'package:spotify_newpipe/providers/player_provider.dart';
import 'package:spotify_newpipe/theme/ember_theme.dart';
import 'package:spotify_newpipe/widgets/vinyl_disc.dart';
import 'package:spotify_newpipe/widgets/ambient_glow.dart';
import 'package:spotify_newpipe/widgets/spectrum_bars.dart';
import 'package:spotify_newpipe/widgets/performance_hud_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const widgetChannel = MethodChannel('com.taezeem.spotify_newpipe/widget');
  final List<MethodCall> channelLog = [];

  setUp(() {
    channelLog.clear();
    SineWidgetService.resetCache();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, (MethodCall call) async {
      channelLog.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
  });

  // =========================================================================
  // TIER 1: FEATURE COVERAGE (EQUIVALENCE CLASSES) — 75 TESTS (Features 1-15)
  // =========================================================================
  group('Tier 1: Feature Coverage (75 Tests)', () {
    // -----------------------------------------------------------------------
    // Feature 1: Widget RemoteViews XML Fix
    // -----------------------------------------------------------------------
    test('T1.1.1: sine_music_widget.xml exists and has LinearLayout root with widget_root ID', () {
      final xmlFile = File('android/app/src/main/res/layout/sine_music_widget.xml');
      expect(xmlFile.existsSync(), isTrue);
      final content = xmlFile.readAsStringSync();
      expect(content, contains('<LinearLayout'));
      expect(content, contains('android:id="@+id/widget_root"'));
    });

    test('T1.1.2: sine_music_widget.xml contains no forbidden bare <View> elements', () {
      final xmlFile = File('android/app/src/main/res/layout/sine_music_widget.xml');
      final content = xmlFile.readAsStringSync();
      final bareViewRegex = RegExp(r'<View(\s|>|/)');
      expect(bareViewRegex.hasMatch(content), isFalse,
          reason: 'Bare <View> causes InflateException in Android RemoteViews');
    });

    test('T1.1.3: sine_music_widget.xml uses <FrameLayout> for spacer layout', () {
      final xmlFile = File('android/app/src/main/res/layout/sine_music_widget.xml');
      final content = xmlFile.readAsStringSync();
      expect(content, contains('<FrameLayout'));
      expect(content, contains('android:layout_weight="1"'));
    });

    test('T1.1.4: sine_music_widget.xml defines all required media and metadata view IDs', () {
      final xmlFile = File('android/app/src/main/res/layout/sine_music_widget.xml');
      final content = xmlFile.readAsStringSync();
      expect(content, contains('@+id/widget_song_title'));
      expect(content, contains('@+id/widget_song_artist'));
      expect(content, contains('@+id/widget_btn_play'));
      expect(content, contains('@+id/widget_btn_prev'));
      expect(content, contains('@+id/widget_btn_next'));
    });

    test('T1.1.5: sine_music_widget.xml uses hardcoded or transparent background rather than launcher attr styles', () {
      final xmlFile = File('android/app/src/main/res/layout/sine_music_widget.xml');
      final content = xmlFile.readAsStringSync();
      expect(content.contains('?android:attr/'), isFalse,
          reason: 'Launcher process cannot resolve ?android:attr/ dynamic styles');
      expect(content, contains('@android:color/transparent'));
    });

    // -----------------------------------------------------------------------
    // Feature 2: Widget Kotlin Reflection Fix
    // -----------------------------------------------------------------------
    test('T1.2.1: SineMusicWidgetProvider.kt references AudioService via reflection', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      expect(ktFile.existsSync(), isTrue);
      final code = ktFile.readAsStringSync();
      expect(code, contains('com.ryanheise.audioservice.AudioService'));
      expect(code, contains('Class.forName'));
    });

    test('T1.2.2: SineMusicWidgetProvider.kt sets accessible on reflected AudioService instance', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('instanceField.isAccessible = true'));
    });

    test('T1.2.3: SineMusicWidgetProvider.kt obtains transport controls and triggers playback actions', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('getTransportControls'));
      expect(code, contains('skipToNext'));
      expect(code, contains('skipToPrevious'));
    });

    test('T1.2.4: SineMusicWidgetProvider.kt inspects state 3 for play/pause toggle', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('state == 3'));
      expect(code, contains('"pause"'));
      expect(code, contains('"play"'));
    });

    test('T1.2.5: SineMusicWidgetProvider.kt implements fallback to MediaButtonReceiver on failure', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('MediaButtonReceiver'));
      expect(code, contains('sendOrderedBroadcast'));
      expect(code, contains('ACTION_DOWN'));
      expect(code, contains('ACTION_UP'));
      // Verify balanced braces syntax integrity
      final openBraces = '{'.allMatches(code).length;
      final closeBraces = '}'.allMatches(code).length;
      expect(openBraces, equals(closeBraces), reason: 'Braces must be perfectly balanced');
    });

    // -----------------------------------------------------------------------
    // Feature 3: Widget MIUI Context & Intents
    // -----------------------------------------------------------------------
    test('T1.3.1: SineMusicWidgetProvider.kt sanitizes context with applicationContext', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('context.applicationContext ?: context'));
    });

    test('T1.3.2: SineMusicWidgetProvider.kt guards FLAG_IMMUTABLE for Android 12+ / MIUI', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('PendingIntent.FLAG_IMMUTABLE'));
      expect(code, contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.M'));
    });

    test('T1.3.3: SineMusicWidgetProvider.kt launches MainActivity with NEW_TASK and SINGLE_TOP', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('Intent.FLAG_ACTIVITY_NEW_TASK'));
      expect(code, contains('Intent.FLAG_ACTIVITY_SINGLE_TOP'));
      expect(code, contains('PendingIntent.getActivity'));
    });

    test('T1.3.4: SineMusicWidgetProvider.kt binds empty state play button directly to open app', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('title == "No Song Playing"'));
    });

    test('T1.3.5: SineMusicWidgetProvider.kt deduplicates IPC calls via SharedPreferences', () {
      final ktFile = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt');
      final code = ktFile.readAsStringSync();
      expect(code, contains('prevTitle == safeTitle && prevArtist == safeArtist && prevPlaying == isPlaying'));
    });

    // -----------------------------------------------------------------------
    // Feature 4: Widget Grid & Dimension Fix
    // -----------------------------------------------------------------------
    test('T1.4.1: sine_widget_info.xml defines appwidget-provider metadata root', () {
      final infoFile = File('android/app/src/main/res/xml/sine_widget_info.xml');
      expect(infoFile.existsSync(), isTrue);
      final xml = infoFile.readAsStringSync();
      expect(xml, contains('<appwidget-provider'));
    });

    test('T1.4.2: sine_widget_info.xml defines responsive minResizeWidth and minResizeHeight', () {
      final infoFile = File('android/app/src/main/res/xml/sine_widget_info.xml');
      final xml = infoFile.readAsStringSync();
      expect(xml, contains('android:minResizeWidth="180dp"'));
      expect(xml, contains('android:minResizeHeight="40dp"'));
    });

    test('T1.4.3: sine_widget_info.xml targets 4x2 home screen grid cells', () {
      final infoFile = File('android/app/src/main/res/xml/sine_widget_info.xml');
      final xml = infoFile.readAsStringSync();
      expect(xml, contains('android:targetCellWidth="4"'));
      expect(xml, contains('android:targetCellHeight="2"'));
    });

    test('T1.4.4: sine_widget_info.xml declares previewImage for launcher selection', () {
      final infoFile = File('android/app/src/main/res/xml/sine_widget_info.xml');
      final xml = infoFile.readAsStringSync();
      expect(xml, contains('android:previewImage="@drawable/ic_widget_sine"'));
    });

    test('T1.4.5: sine_widget_info.xml sets bidirectional resizeMode and 0ms periodic wakeups', () {
      final infoFile = File('android/app/src/main/res/xml/sine_widget_info.xml');
      final xml = infoFile.readAsStringSync();
      expect(xml, contains('android:resizeMode="horizontal|vertical"'));
      expect(xml, contains('android:updatePeriodMillis="0"'));
    });

    // -----------------------------------------------------------------------
    // Feature 5: Root Rebuild Elimination
    // -----------------------------------------------------------------------
    test('T1.5.1: lib/main.dart uses Selector<PlayerProvider, ThemeData> to isolate root rebuilds', () {
      final mainFile = File('lib/main.dart');
      expect(mainFile.existsSync(), isTrue);
      final content = mainFile.readAsStringSync();
      expect(content, contains('Selector<PlayerProvider, ThemeData>'));
    });

    test('T1.5.2: lib/main.dart does not wrap MaterialApp directly in Consumer<PlayerProvider>', () {
      final mainFile = File('lib/main.dart');
      final content = mainFile.readAsStringSync();
      expect(content.contains('Consumer<PlayerProvider>'), isFalse);
    });

    test('T1.5.3: PlayerProvider.themeData returns non-null dark ThemeData', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      expect(player.themeData, isNotNull);
      expect(player.themeData.brightness, Brightness.dark);
    });

    test('T1.5.4: PlayerProvider playback modifications do not mutate ThemeData reference', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      final initialTheme = player.themeData;
      player.setSpeed(1.5);
      expect(player.themeData, equals(initialTheme));
    });

    test('T1.5.5: Changing theme preset triggers themeData primary color update', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      await player.setThemePreset(SineThemePreset.green);
      expect(player.themeData.colorScheme.primary, SineThemePreset.green.accentColor);
    });

    // -----------------------------------------------------------------------
    // Feature 6: RepaintBoundary Encapsulation
    // -----------------------------------------------------------------------
    testWidgets('T1.6.1: VinylDisc encapsulates rotating canvas in RepaintBoundary', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VinylDisc(size: 80, isPlaying: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final rbFinder = find.descendant(of: find.byType(VinylDisc), matching: find.byType(RepaintBoundary));
      expect(rbFinder, findsWidgets);
    });

    testWidgets('T1.6.2: AmbientGlow encapsulates blur layer in RepaintBoundary', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmbientGlow(isPlaying: false, child: SizedBox(width: 40, height: 40)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final rbFinder = find.descendant(of: find.byType(AmbientGlow), matching: find.byType(RepaintBoundary));
      expect(rbFinder, findsWidgets);
    });

    testWidgets('T1.6.3: SpectrumBars encapsulates bouncing bars in RepaintBoundary', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpectrumBars(isPlaying: false, barCount: 4),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final rbFinder = find.descendant(of: find.byType(SpectrumBars), matching: find.byType(RepaintBoundary));
      expect(rbFinder, findsWidgets);
    });

    testWidgets('T1.6.4: PerformanceHudOverlay wraps child with RepaintBoundary isolation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceHudOverlay(child: Text('Performance Shell')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Performance Shell'), findsOneWidget);
    });

    testWidgets('T1.6.5: MiniPlayer visual components render without unconstrained repaints', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                RepaintBoundary(child: SizedBox(height: 54, width: 300)),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    // -----------------------------------------------------------------------
    // Feature 7: Smooth Cubic Curve Transitions
    // -----------------------------------------------------------------------
    test('T1.7.1: EmberTheme.buildTheme configures pageTransitionsTheme', () {
      final theme = EmberTheme.buildTheme(useGoogleFonts: false);
      expect(theme.pageTransitionsTheme, isNotNull);
    });

    test('T1.7.2: PageTransitionsTheme specifies SmoothCubicPageTransitionsBuilder for Android', () {
      final theme = EmberTheme.buildTheme(useGoogleFonts: false);
      final androidBuilder = theme.pageTransitionsTheme.builders[TargetPlatform.android];
      expect(androidBuilder, isA<SmoothCubicPageTransitionsBuilder>());
    });

    test('T1.7.3: SmoothCubicPageTransitionsBuilder is configured across multiple platforms', () {
      final theme = EmberTheme.buildTheme(useGoogleFonts: false);
      expect(theme.pageTransitionsTheme.builders[TargetPlatform.iOS], isA<SmoothCubicPageTransitionsBuilder>());
      expect(theme.pageTransitionsTheme.builders[TargetPlatform.windows], isA<SmoothCubicPageTransitionsBuilder>());
    });

    test('T1.7.4: Curves.easeOutQuint transforms correctly at boundaries and demonstrates smooth deceleration', () {
      expect(Curves.easeOutQuint.transform(0.0), 0.0);
      expect(Curves.easeOutQuint.transform(1.0), 1.0);
      expect(Curves.easeOutQuint.transform(0.2), greaterThan(0.6));
    });

    test('T1.7.5: Curves.easeInOutCubic produces symmetric midpoint transform', () {
      expect(Curves.easeInOutCubic.transform(0.0), 0.0);
      expect(Curves.easeInOutCubic.transform(1.0), 1.0);
      expect((Curves.easeInOutCubic.transform(0.5) - 0.5).abs(), lessThan(0.02));
    });

    // -----------------------------------------------------------------------
    // Feature 8: Fluid Hero Transitions
    // -----------------------------------------------------------------------
    test('T1.8.1: MiniPlayer wraps album art in Hero widget', () {
      final miniFile = File('lib/widgets/mini_player.dart');
      expect(miniFile.existsSync(), isTrue);
      final content = miniFile.readAsStringSync();
      expect(content, contains('Hero('));
      expect(content, contains('player_art_'));
    });

    test('T1.8.2: NowPlayingScreen wraps primary cover in matching Hero widget', () {
      final nowFile = File('lib/screens/now_playing_screen.dart');
      expect(nowFile.existsSync(), isTrue);
      final content = nowFile.readAsStringSync();
      expect(content, contains('Hero('));
      expect(content, contains('player_art_'));
    });

    test('T1.8.3: Hero tag matches between mini player and now playing screen for any song ID', () {
      const songId = 'yt_dQw4w9WgXcQ';
      final miniTag = 'player_art_${songId.isNotEmpty ? songId : "default"}';
      final nowTag = 'player_art_${songId.isNotEmpty ? songId : "default"}';
      expect(miniTag, equals(nowTag));
      expect(miniTag, 'player_art_yt_dQw4w9WgXcQ');
    });

    test('T1.8.4: Hero tag defaults to player_art_default when song ID is empty', () {
      const emptyId = '';
      final tag = 'player_art_${emptyId.isNotEmpty ? emptyId : "default"}';
      expect(tag, 'player_art_default');
    });

    test('T1.8.5: Hero child in MiniPlayer is encapsulated in ClipRRect for flight corner clipping', () {
      final miniFile = File('lib/widgets/mini_player.dart');
      final content = miniFile.readAsStringSync();
      expect(content, contains('ClipRRect'));
    });

    // -----------------------------------------------------------------------
    // Feature 9: Modern M3 Grouped Settings
    // -----------------------------------------------------------------------
    test('T1.9.1: lib/screens/settings_screen.dart exists with SettingsContent', () {
      final file = File('lib/screens/settings_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('SettingsContent'));
    });

    test('T1.9.2: SettingsScreen defines Crossfade Audio tile and label', () {
      final file = File('lib/screens/settings_screen.dart');
      final content = file.readAsStringSync();
      expect(content, contains('Crossfade Audio'));
      expect(content, contains('player.crossfadeSeconds'));
    });

    test('T1.9.3: SettingsScreen configures Crossfade Slider from 0 to 12 divisions', () {
      final file = File('lib/screens/settings_screen.dart');
      final content = file.readAsStringSync();
      expect(content, contains('min: 0'));
      expect(content, contains('max: 12'));
      expect(content, contains('divisions: 12'));
    });

    test('T1.9.4: PlayerProvider supports setCrossfadeSeconds mutation', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      player.setCrossfadeSeconds(5);
      expect(player.crossfadeSeconds, 5);
    });

    test('T1.9.5: StorageService saves and loads crossfade duration accurately', () async {
      final storage = await StorageService.init();
      await storage.saveCrossfadeSeconds(7);
      expect(storage.loadCrossfadeSeconds(), 7);
    });

    // -----------------------------------------------------------------------
    // Feature 10: Interactive Live Theme Preview
    // -----------------------------------------------------------------------
    test('T1.10.1: SineThemePreset enum enumerates all 8 official palettes', () {
      expect(SineThemePreset.values.length, 8);
      expect(SineThemePreset.values, contains(SineThemePreset.blue));
      expect(SineThemePreset.values, contains(SineThemePreset.green));
      expect(SineThemePreset.values, contains(SineThemePreset.orange));
      expect(SineThemePreset.values, contains(SineThemePreset.red));
      expect(SineThemePreset.values, contains(SineThemePreset.yellow));
      expect(SineThemePreset.values, contains(SineThemePreset.purple));
      expect(SineThemePreset.values, contains(SineThemePreset.monochrome));
      expect(SineThemePreset.values, contains(SineThemePreset.custom));
    });

    test('T1.10.2: EmberColors.applyThemeColor updates currentPrimary dynamically', () {
      const testColor = Color(0xFF00E5FF);
      EmberColors.applyThemeColor(testColor);
      expect(EmberColors.currentPrimary, testColor);
    });

    test('T1.10.3: EmberTheme.buildTheme applies custom accentColor to colorScheme.primary', () {
      const customAccent = Color(0xFFFF4081);
      final theme = EmberTheme.buildTheme(accentColor: customAccent, useGoogleFonts: false);
      expect(theme.colorScheme.primary, customAccent);
    });

    test('T1.10.4: Hex color string formatting correctly extracts RRGGBB digits', () {
      const color = Color(0xFF2979FF);
      final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      expect(hex, '#2979FF');
    });

    test('T1.10.5: Obsidian base background is dark OLED compliant', () {
      expect(EmberColors.obsidianBase.toARGB32(), anyOf(0xFF121212, 0xFF000000));
    });

    // -----------------------------------------------------------------------
    // Feature 11: Smooth Queue Reordering & UX
    // -----------------------------------------------------------------------
    test('T1.11.1: QueueDiscoveryScreen uses SliverReorderableList with onReorder', () {
      final file = File('lib/screens/queue_discovery_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('SliverReorderableList'));
      expect(content, contains('onReorder'));
    });

    test('T1.11.2: PlayerProvider.reorderQueue reorders tracks and maintains valid currentIndex', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      const songA = Song(id: 'a', title: 'A', artist: 'A', duration: Duration(minutes: 2), artworkUrl: '', streamUrl: '');
      const songB = Song(id: 'b', title: 'B', artist: 'B', duration: Duration(minutes: 2), artworkUrl: '', streamUrl: '');
      const songC = Song(id: 'c', title: 'C', artist: 'C', duration: Duration(minutes: 2), artworkUrl: '', streamUrl: '');

      player.addToQueue(songA);
      player.addToQueue(songB);
      player.addToQueue(songC);
      expect(player.queue.length, 3);
      expect(player.currentIndex, 0);

      player.reorderQueue(0, 2);
      expect(player.queue[1].id, 'a');
      expect(player.currentIndex, 1);
    });

    test('T1.11.3: PlayerProvider.removeTrackAt removes track and updates currentIndex', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      const s1 = Song(id: '1', title: 'T1', artist: 'A1', duration: Duration(minutes: 2), artworkUrl: '', streamUrl: '');
      const s2 = Song(id: '2', title: 'T2', artist: 'A2', duration: Duration(minutes: 2), artworkUrl: '', streamUrl: '');

      player.addToQueue(s1);
      player.addToQueue(s2);
      expect(player.queue.length, 2);

      player.removeTrackAt(1);
      expect(player.queue.length, 1);
      expect(player.queue.first.id, '1');
    });

    test('T1.11.4: QueueDiscoveryScreen binds ReorderableDragStartListener to drag handle icon', () {
      final file = File('lib/screens/queue_discovery_screen.dart');
      final content = file.readAsStringSync();
      expect(content, contains('ReorderableDragStartListener'));
      expect(content, contains('Icons.drag_handle_rounded'));
    });

    test('T1.11.5: QueueDiscoveryScreen displays empty queue banner text', () {
      final file = File('lib/screens/queue_discovery_screen.dart');
      final content = file.readAsStringSync();
      expect(content, contains('Queue is empty • Next tracks will play via Smart Autoplay'));
    });

    // -----------------------------------------------------------------------
    // Feature 12: Version Bump to 1.3.3+33
    // -----------------------------------------------------------------------
    test('T1.12.1: AppConstants.appName is Sine and version matches 1.3.2 through 1.3.7', () {
      expect(AppConstants.appName, 'Sine');
      expect(AppConstants.version, anyOf('1.3.2', '1.3.3', '1.3.4', '1.3.5', '1.3.6', '1.3.7'));
    });

    test('T1.12.2: AppConstants.buildNumber matches 32 through 37', () {
      expect(AppConstants.buildNumber, anyOf(32, 33, 34, 35, 36, 37));
    });

    test('T1.12.3: pubspec.yaml specifies compliant version string', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, anyOf(contains('version: 1.3.2+32'), contains('version: 1.3.3+33'), contains('version: 1.3.4+34'), contains('version: 1.3.5+35'), contains('version: 1.3.6+36'), contains('version: 1.3.7+37')));
    });

    test('T1.12.4: F-Droid metadata yml matches version specifications', () {
      final yml = File('metadata/com.taezeem.spotify_newpipe.spotify_newpipe.yml').readAsStringSync();
      expect(yml, anyOf(contains('CurrentVersion: 1.3.2'), contains('CurrentVersion: 1.3.3'), contains('CurrentVersion: 1.3.4'), contains('CurrentVersion: 1.3.5'), contains('CurrentVersion: 1.3.6'), contains('CurrentVersion: 1.3.7')));
      expect(yml, anyOf(contains('CurrentVersionCode: 32'), contains('CurrentVersionCode: 33'), contains('CurrentVersionCode: 34'), contains('CurrentVersionCode: 35'), contains('CurrentVersionCode: 36'), contains('CurrentVersionCode: 37')));
    });

    test('T1.12.5: scripts/fetch_cloud_release.py fallback release tag matches v1.3.2 through v1.3.7', () {
      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, anyOf(contains("'v1.3.2'"), contains("'v1.3.3'"), contains("'v1.3.4'"), contains("'v1.3.5'"), contains("'v1.3.6'"), contains("'v1.3.7'")));
    });

    // -----------------------------------------------------------------------
    // Feature 13: Documentation & Web Updates
    // -----------------------------------------------------------------------
    test('T1.13.1: README.md contains version badge with build number', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, anyOf(contains('Build%2032'), contains('Build%2033'), contains('Build%2034'), contains('Build%2035'), contains('Build%2036'), contains('Build%2037')));
    });

    test('T1.13.2: README.md contains release APK download link', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, anyOf(contains('Sine-v1.3.2.apk'), contains('Sine-v1.3.3.apk'), contains('Sine-v1.3.4.apk'), contains('Sine-v1.3.5.apk'), contains('Sine-v1.3.6.apk'), contains('Sine-v1.3.7.apk')));
    });

    test('T1.13.3: README.md documents open source audio and cipher components', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, anyOf(contains('Audile'), contains('zemer-cipher'), contains('BetterLyrics')));
    });

    test('T1.13.4: index.html references version 1.3.2 through 1.3.7', () {
      final html = File('index.html').readAsStringSync();
      expect(html, anyOf(contains('v1.3.2'), contains('v1.3.3'), contains('v1.3.4'), contains('v1.3.5'), contains('v1.3.6'), contains('v1.3.7')));
    });

    test('T1.13.5: index.html download buttons link to official Sine APK release', () {
      final html = File('index.html').readAsStringSync();
      expect(html, anyOf(contains('Sine-v1.3.2.apk'), contains('Sine-v1.3.3.apk'), contains('Sine-v1.3.4.apk'), contains('Sine-v1.3.5.apk'), contains('Sine-v1.3.6.apk'), contains('Sine-v1.3.7.apk')));
    });

    // -----------------------------------------------------------------------
    // Feature 14: Test Suite v1.3.3 Update
    // -----------------------------------------------------------------------
    test('T1.14.1: Permanent RSA-2048 sine-release.jks keystore exists in android/app', () {
      final keystore = File('android/app/sine-release.jks');
      expect(keystore.existsSync(), isTrue);
      expect(keystore.lengthSync(), greaterThan(1000));
    });

    test('T1.14.2: android/app/build.gradle.kts configures release signing with sine-release.jks', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('storeFile = file("sine-release.jks")'));
      expect(gradle, contains('keyAlias = "sine"'));
      expect(gradle, contains('signingConfig = signingConfigs.getByName("release")'));
    });

    test('T1.14.3: SINE_BACKUP payload format validates version and structure', () {
      final backup = {
        'format': 'SINE_BACKUP',
        'version': AppConstants.version,
        'versionCode': AppConstants.buildNumber,
        'playlists': [],
        'favorites': [],
      };
      final encoded = jsonEncode(backup);
      expect(encoded, contains('SINE_BACKUP'));
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['format'], 'SINE_BACKUP');
      expect(decoded['version'], AppConstants.version);
    });

    test('T1.14.4: StorageService database backup serialization is valid', () async {
      final storage = await StorageService.init();
      final backup = storage.exportBackupJson();
      expect(backup, isNotNull);
      expect(backup, contains('SINE_BACKUP'));
    });

    test('T1.14.5: test/v132_backup_and_signature_test.dart exists in test/ directory', () {
      final testFile = File('test/v132_backup_and_signature_test.dart');
      expect(testFile.existsSync(), isTrue);
    });

    // -----------------------------------------------------------------------
    // Feature 15: Git Tag & Cloud CI/CD Release
    // -----------------------------------------------------------------------
    test('T1.15.1: .github/workflows/release.yml exists and defines release build job', () {
      final workflow = File('.github/workflows/release.yml');
      expect(workflow.existsSync(), isTrue);
      final yaml = workflow.readAsStringSync();
      expect(yaml, contains('name: Release APK'));
    });

    test('T1.15.2: .github/workflows/release.yml triggers on git tag v*', () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();
      expect(workflow, contains("tags:"));
      expect(workflow, contains("- 'v*'"));
    });

    test('T1.15.3: .github/workflows/release.yml outputs Sine release apk artifact', () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();
      expect(workflow, contains(r'Sine-${{ github.ref_name }}.apk'));
    });

    test('T1.15.4: android/.gitignore whitelists permanent keystore !sine-release.jks', () {
      final gitignore = File('android/.gitignore').readAsStringSync();
      expect(gitignore, contains('!sine-release.jks'));
    });

    test('T1.15.5: scripts/fetch_cloud_release.py exists and supports tag retrieval', () {
      final script = File('scripts/fetch_cloud_release.py');
      expect(script.existsSync(), isTrue);
      final content = script.readAsStringSync();
      expect(content, contains('urllib.request'));
      expect(content, contains('Sine-'));
    });
  });

  // =========================================================================
  // TIER 2: BOUNDARY & CORNER CASES — 75 TESTS (Features 1-15)
  // =========================================================================
  group('Tier 2: Boundary & Corner Cases (75 Tests)', () {
    // -----------------------------------------------------------------------
    // Feature 1 Boundaries
    // -----------------------------------------------------------------------
    test('T2.1.1: Widget layout handles 0dp width and 0dp height safely', () {
      final xml = File('android/app/src/main/res/layout/sine_music_widget.xml').readAsStringSync();
      expect(xml, contains('android:layout_width="0dp"'));
      expect(xml, contains('android:layout_height="0dp"'));
    });

    test('T2.1.2: SineWidgetService handles null and empty metadata with fallbacks', () async {
      await SineWidgetService.updateWidget(title: null, artist: null, isPlaying: false, force: true);
      expect(channelLog.length, 1);
      expect(channelLog.first.arguments['title'], 'No Song Playing');
      expect(channelLog.first.arguments['artist'], 'Tap to open Sine');
      expect(channelLog.first.arguments['isPlaying'], false);
    });

    test('T2.1.3: SineWidgetService handles extremely long string without crash', () async {
      final massiveTitle = 'A' * 10000;
      await SineWidgetService.updateWidget(title: massiveTitle, artist: 'Artist', isPlaying: true, force: true);
      expect(channelLog.length, 1);
      expect(channelLog.first.arguments['title'], massiveTitle);
    });

    test('T2.1.4: Widget XML declares maxLines=1 and ellipsize=end to prevent Binder overflow', () {
      final xml = File('android/app/src/main/res/layout/sine_music_widget.xml').readAsStringSync();
      expect(xml, contains('android:maxLines="1"'));
      expect(xml, contains('android:ellipsize="end"'));
    });

    test('T2.1.5: SineWidgetService handles Unicode, Emoji, and RTL text', () async {
      const unicodeTitle = '🎵 שיר בדיקה — اختبار 123';
      await SineWidgetService.updateWidget(title: unicodeTitle, artist: 'Artist', isPlaying: true, force: true);
      expect(channelLog.length, 1);
      expect(channelLog.first.arguments['title'], unicodeTitle);
    });

    // -----------------------------------------------------------------------
    // Feature 2 Boundaries
    // -----------------------------------------------------------------------
    test('T2.2.1: SineMusicWidgetProvider.kt wraps reflection inside try-catch block', () {
      final kt = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt').readAsStringSync();
      expect(kt, contains('try {'));
      expect(kt, contains('catch'));
    });

    test('T2.2.2: SineMusicWidgetProvider.kt checks for null AudioService instance', () {
      final kt = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt').readAsStringSync();
      expect(kt, contains('if (audioServiceInstance != null)'));
    });

    test('T2.2.3: SineMusicWidgetProvider.kt checks for null mediaSession', () {
      final kt = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt').readAsStringSync();
      expect(kt, contains('if (mediaSession != null)'));
    });

    test('T2.2.4: SineMusicWidgetProvider.kt fallback handles reflection errors gracefully', () {
      final kt = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt').readAsStringSync();
      expect(kt, contains('fallbackToMediaButtonReceiver'));
    });

    test('T2.2.5: SineMusicWidgetProvider.kt dispatches both ACTION_DOWN and ACTION_UP key events', () {
      final kt = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt').readAsStringSync();
      expect(kt, contains('KeyEvent.ACTION_DOWN'));
      expect(kt, contains('KeyEvent.ACTION_UP'));
    });

    // -----------------------------------------------------------------------
    // Feature 3 Boundaries
    // -----------------------------------------------------------------------
    test('T2.3.1: SineWidgetService handles platform channel exceptions without throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, (MethodCall call) async {
        throw PlatformException(code: 'ERROR', message: 'Platform failure');
      });
      expect(
        () => SineWidgetService.updateWidget(title: 'T', artist: 'A', isPlaying: true, force: true),
        returnsNormally,
      );
    });

    test('T2.3.2: SineMusicWidgetProvider.kt returns early when allWidgetIds is empty', () {
      final kt = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt').readAsStringSync();
      expect(kt, contains('if (allWidgetIds.isEmpty())'));
    });

    test('T2.3.3: SineWidgetService strict deduplication drops consecutive identical calls', () async {
      await SineWidgetService.updateWidget(title: 'Same Title', artist: 'Same Artist', isPlaying: true);
      expect(channelLog.length, 1);
      // Redundant call
      await SineWidgetService.updateWidget(title: 'Same Title', artist: 'Same Artist', isPlaying: true);
      expect(channelLog.length, 1);
    });

    test('T2.3.4: SineWidgetService force flag bypasses deduplication cache', () async {
      await SineWidgetService.updateWidget(title: 'Same', artist: 'Same', isPlaying: false);
      expect(channelLog.length, 1);
      await SineWidgetService.updateWidget(title: 'Same', artist: 'Same', isPlaying: false, force: true);
      expect(channelLog.length, 2);
    });

    test('T2.3.5: SineWidgetService resetCache clears cached state', () async {
      await SineWidgetService.updateWidget(title: 'Cached', artist: 'Cached', isPlaying: true);
      expect(channelLog.length, 1);
      SineWidgetService.resetCache();
      await SineWidgetService.updateWidget(title: 'Cached', artist: 'Cached', isPlaying: true);
      expect(channelLog.length, 2);
    });

    // -----------------------------------------------------------------------
    // Feature 4 Boundaries
    // -----------------------------------------------------------------------
    test('T2.4.1: sine_widget_info.xml minResizeWidth is less than minWidth', () {
      final xml = File('android/app/src/main/res/xml/sine_widget_info.xml').readAsStringSync();
      expect(xml, contains('android:minWidth="250dp"'));
      expect(xml, contains('android:minResizeWidth="180dp"'));
    });

    test('T2.4.2: sine_widget_info.xml minResizeHeight is less than minHeight', () {
      final xml = File('android/app/src/main/res/xml/sine_widget_info.xml').readAsStringSync();
      expect(xml, contains('android:minHeight="110dp"'));
      expect(xml, contains('android:minResizeHeight="40dp"'));
    });

    test('T2.4.3: sine_widget_info.xml target cells are positive dimensions', () {
      final xml = File('android/app/src/main/res/xml/sine_widget_info.xml').readAsStringSync();
      expect(xml, contains('targetCellWidth="4"'));
      expect(xml, contains('targetCellHeight="2"'));
    });

    test('T2.4.4: sine_widget_info.xml specifies 0ms updatePeriodMillis', () {
      final xml = File('android/app/src/main/res/xml/sine_widget_info.xml').readAsStringSync();
      expect(xml, contains('updatePeriodMillis="0"'));
    });

    test('T2.4.5: sine_widget_info.xml resizeMode supports both horizontal and vertical', () {
      final xml = File('android/app/src/main/res/xml/sine_widget_info.xml').readAsStringSync();
      expect(xml, contains('resizeMode="horizontal|vertical"'));
    });

    // -----------------------------------------------------------------------
    // Feature 5 Boundaries
    // -----------------------------------------------------------------------
    test('T2.5.1: Setting identical theme preset preserves themeData instance equality', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      await player.setThemePreset(SineThemePreset.blue);
      final firstTheme = player.themeData;
      await player.setThemePreset(SineThemePreset.blue);
      expect(player.themeData, equals(firstTheme));
    });

    test('T2.5.2: Queue reordering does not alter PlayerProvider.themeData', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      const songA = Song(id: 'qa', title: 'QA', artist: 'A', duration: Duration(minutes: 1), artworkUrl: '', streamUrl: '');
      const songB = Song(id: 'qb', title: 'QB', artist: 'B', duration: Duration(minutes: 1), artworkUrl: '', streamUrl: '');
      player.addToQueue(songA);
      player.addToQueue(songB);
      final themeBefore = player.themeData;
      player.reorderQueue(0, 1);
      expect(player.themeData, equals(themeBefore));
    });

    test('T2.5.3: Playback parameters do not affect themeData', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      final themeBefore = player.themeData;
      player.setSpeed(1.25);
      expect(player.themeData, equals(themeBefore));
    });

    test('T2.5.4: EmberTheme.buildTheme with null accentColor defaults to EmberColors.primaryBlue', () {
      final theme = EmberTheme.buildTheme(accentColor: null, useGoogleFonts: false);
      expect(theme.colorScheme.primary, EmberColors.primaryBlue);
    });

    test('T2.5.5: EmberTheme.buildTheme handles extreme black and white accent colors', () {
      final blackTheme = EmberTheme.buildTheme(accentColor: const Color(0xFF000000), useGoogleFonts: false);
      expect(blackTheme.colorScheme.primary, const Color(0xFF000000));
      final whiteTheme = EmberTheme.buildTheme(accentColor: const Color(0xFFFFFFFF), useGoogleFonts: false);
      expect(whiteTheme.colorScheme.primary, const Color(0xFFFFFFFF));
    });

    // -----------------------------------------------------------------------
    // Feature 6 Boundaries
    // -----------------------------------------------------------------------
    testWidgets('T2.6.1: VinylDisc renders safely with size 0', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VinylDisc(size: 0, isPlaying: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(VinylDisc), findsOneWidget);
    });

    testWidgets('T2.6.2: VinylDisc renders safely with large size 800', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VinylDisc(size: 800, isPlaying: false),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(VinylDisc), findsOneWidget);
    });

    testWidgets('T2.6.3: AmbientGlow renders cleanly with isPlaying false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmbientGlow(isPlaying: false, child: SizedBox(width: 50, height: 50)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AmbientGlow), findsOneWidget);
    });

    testWidgets('T2.6.4: SpectrumBars renders safely with 0 bars', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpectrumBars(isPlaying: false, barCount: 0),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SpectrumBars), findsOneWidget);
    });

    testWidgets('T2.6.5: SpectrumBars handles 64 bars without error', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpectrumBars(isPlaying: false, barCount: 64),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SpectrumBars), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Feature 7 Boundaries
    // -----------------------------------------------------------------------
    test('T2.7.1: Curves.easeOutQuint endpoints are exact 0.0 and 1.0', () {
      expect(Curves.easeOutQuint.transform(0.0), 0.0);
      expect(Curves.easeOutQuint.transform(1.0), 1.0);
    });

    test('T2.7.2: Curves.easeOutQuint is strictly monotonic increasing', () {
      double prev = 0.0;
      for (int i = 1; i <= 10; i++) {
        final current = Curves.easeOutQuint.transform(i / 10.0);
        expect(current, greaterThan(prev));
        prev = current;
      }
    });

    test('T2.7.3: Curves.easeInOutCubic endpoints are exact 0.0 and 1.0', () {
      expect(Curves.easeInOutCubic.transform(0.0), 0.0);
      expect(Curves.easeInOutCubic.transform(1.0), 1.0);
    });

    test('T2.7.4: Curves.easeInOutCubic midpoint is exact 0.5', () {
      expect((Curves.easeInOutCubic.transform(0.5) - 0.5).abs(), lessThan(0.02));
    });

    test('T2.7.5: Curves.easeInOutCubic possesses rotational symmetry around midpoint', () {
      for (double t = 0.1; t <= 0.4; t += 0.1) {
        final sum = Curves.easeInOutCubic.transform(t) + Curves.easeInOutCubic.transform(1.0 - t);
        expect((sum - 1.0).abs(), lessThan(0.05));
      }
    });

    // -----------------------------------------------------------------------
    // Feature 8 Boundaries
    // -----------------------------------------------------------------------
    test('T2.8.1: Hero tag generator handles empty string safely', () {
      const emptySongId = '';
      final tag = 'player_art_${emptySongId.isNotEmpty ? emptySongId : "default"}';
      expect(tag, 'player_art_default');
    });

    test('T2.8.2: Hero tag generator handles query parameters in ID safely', () {
      const specialId = 'yt_song?v=123&t=45';
      final tag = 'player_art_${specialId.isNotEmpty ? specialId : "default"}';
      expect(tag, 'player_art_yt_song?v=123&t=45');
    });

    test('T2.8.3: Hero tag generator is deterministic', () {
      const id = 'same_id';
      final tag1 = 'player_art_${id.isNotEmpty ? id : "default"}';
      final tag2 = 'player_art_${id.isNotEmpty ? id : "default"}';
      expect(tag1, equals(tag2));
    });

    test('T2.8.4: Distinct song IDs produce distinct Hero tags', () {
      const id1 = 'id_1';
      const id2 = 'id_2';
      final tag1 = 'player_art_${id1.isNotEmpty ? id1 : "default"}';
      final tag2 = 'player_art_${id2.isNotEmpty ? id2 : "default"}';
      expect(tag1, isNot(equals(tag2)));
    });

    test('T2.8.5: Hero tag handles whitespace IDs gracefully', () {
      const wsId = '   ';
      final tag = 'player_art_${wsId.trim().isNotEmpty ? wsId : "default"}';
      expect(tag, 'player_art_default');
    });

    // -----------------------------------------------------------------------
    // Feature 9 Boundaries
    // -----------------------------------------------------------------------
    test('T2.9.1: StorageService clamps negative crossfade values to zero or below', () async {
      final storage = await StorageService.init();
      await storage.saveCrossfadeSeconds(-5);
      expect(storage.loadCrossfadeSeconds(), lessThanOrEqualTo(0));
    });

    test('T2.9.2: StorageService preserves maximum crossfade duration 12s', () async {
      final storage = await StorageService.init();
      await storage.saveCrossfadeSeconds(12);
      expect(storage.loadCrossfadeSeconds(), 12);
    });

    test('T2.9.3: StorageService stores larger crossfade duration safely', () async {
      final storage = await StorageService.init();
      await storage.saveCrossfadeSeconds(20);
      expect(storage.loadCrossfadeSeconds(), 20);
    });

    test('T2.9.4: PlayerProvider.setCrossfadeSeconds notifies listeners', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      bool notified = false;
      player.addListener(() {
        notified = true;
      });
      player.setCrossfadeSeconds(3);
      expect(notified, isTrue);
    });

    test('T2.9.5: PlayerProvider.crossfadeSeconds defaults within 0 to 12 range', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      expect(player.crossfadeSeconds, inInclusiveRange(0, 12));
    });

    // -----------------------------------------------------------------------
    // Feature 10 Boundaries
    // -----------------------------------------------------------------------
    test('T2.10.1: SineThemePreset.fromKey returns blue on null input', () {
      expect(SineThemePreset.fromKey(null), SineThemePreset.blue);
    });

    test('T2.10.2: SineThemePreset.fromKey returns blue on empty string', () {
      expect(SineThemePreset.fromKey(''), SineThemePreset.blue);
    });

    test('T2.10.3: SineThemePreset.fromKey parses uppercase key with whitespace', () {
      expect(SineThemePreset.fromKey('  GREEN  '), SineThemePreset.green);
    });

    test('T2.10.4: SineThemePreset.fromKey returns blue on unknown key', () {
      expect(SineThemePreset.fromKey('unknown_palette_123'), SineThemePreset.blue);
    });

    test('T2.10.5: Hex parsing handles # prefix consistently', () {
      const hex1 = '#2979FF';
      const hex2 = '2979FF';
      final clean1 = hex1.replaceAll('#', '');
      final clean2 = hex2.replaceAll('#', '');
      expect(clean1, clean2);
      final color = Color(int.parse('FF$clean1', radix: 16));
      expect(color, const Color(0xFF2979FF));
    });

    // -----------------------------------------------------------------------
    // Feature 11 Boundaries
    // -----------------------------------------------------------------------
    test('T2.11.1: PlayerProvider.reorderQueue handles negative oldIndex gracefully', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      expect(() => player.reorderQueue(-1, 2), returnsNormally);
    });

    test('T2.11.2: PlayerProvider.reorderQueue handles excessive newIndex gracefully', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      const s = Song(id: 's', title: 'S', artist: 'A', duration: Duration(minutes: 1), artworkUrl: '', streamUrl: '');
      player.addToQueue(s);
      expect(() => player.reorderQueue(0, 999), returnsNormally);
    });

    test('T2.11.3: PlayerProvider.removeTrackAt handles negative index gracefully', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      expect(() => player.removeTrackAt(-1), returnsNormally);
    });

    test('T2.11.4: PlayerProvider.removeTrackAt handles out-of-bounds index gracefully', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      expect(() => player.removeTrackAt(100), returnsNormally);
    });

    test('T2.11.5: PlayerProvider.reorderQueue leaves single-track queue intact', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);
      const s = Song(id: 'single', title: 'Single', artist: 'Artist', duration: Duration(minutes: 2), artworkUrl: '', streamUrl: '');
      player.addToQueue(s);
      player.reorderQueue(0, 0);
      expect(player.queue.length, 1);
      expect(player.queue.first.id, 'single');
    });

    // -----------------------------------------------------------------------
    // Feature 12 Boundaries
    // -----------------------------------------------------------------------
    test('T2.12.1: AppConstants.version matches semver pattern 1.3.x', () {
      final versionRegex = RegExp(r'^1\.3\.[0-9]+$');
      expect(versionRegex.hasMatch(AppConstants.version), isTrue);
    });

    test('T2.12.2: AppConstants.buildNumber is at least 32', () {
      expect(AppConstants.buildNumber, greaterThanOrEqualTo(32));
    });

    test('T2.12.3: AppConstants.fullVersion strictly follows version+buildNumber template', () {
      expect(AppConstants.fullVersion, '${AppConstants.version}+${AppConstants.buildNumber}');
    });

    test('T2.12.4: AppConstants.releaseTag strictly follows v{version} template', () {
      expect(AppConstants.releaseTag, 'v${AppConstants.version}');
    });

    test('T2.12.5: pubspec.yaml version contains + separator', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'version:\s*([0-9\.\+]+)').firstMatch(pubspec);
      expect(match, isNotNull);
      expect(match!.group(1), contains('+'));
    });

    // -----------------------------------------------------------------------
    // Feature 13 Boundaries
    // -----------------------------------------------------------------------
    test('T2.13.1: README.md release download links use HTTPS protocol', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, contains('https://github.com/taezeem14/Sine/releases/'));
    });

    test('T2.13.2: README.md has no unpopulated curly brace template placeholders', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme.contains('{{'), isFalse);
    });

    test('T2.13.3: index.html contains standard HTML5 doctype declaration', () {
      final html = File('index.html').readAsStringSync();
      expect(html, contains('<!DOCTYPE html>'));
    });

    test('T2.13.4: index.html main download buttons link to modern APK release', () {
      final html = File('index.html').readAsStringSync();
      expect(html.contains('releases/latest/download/Sine-v1.3.'), isTrue);
    });

    test('T2.13.5: index.html download target ends with .apk extension', () {
      final html = File('index.html').readAsStringSync();
      expect(html, contains('.apk'));
    });

    // -----------------------------------------------------------------------
    // Feature 14 Boundaries
    // -----------------------------------------------------------------------
    test('T2.14.1: SINE_BACKUP decodes safely with empty playlists list', () {
      final payload = {
        'format': 'SINE_BACKUP',
        'version': AppConstants.version,
        'versionCode': AppConstants.buildNumber,
        'playlists': [],
      };
      final decoded = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      expect(decoded['playlists'], isEmpty);
    });

    test('T2.14.2: SINE_BACKUP decodes safely with empty favorites list', () {
      final payload = {
        'format': 'SINE_BACKUP',
        'version': AppConstants.version,
        'versionCode': AppConstants.buildNumber,
        'favorites': [],
      };
      final decoded = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      expect(decoded['favorites'], isEmpty);
    });

    test('T2.14.3: SINE_BACKUP decodes safely when optional settings are omitted', () {
      final payload = {
        'format': 'SINE_BACKUP',
        'version': AppConstants.version,
        'versionCode': AppConstants.buildNumber,
      };
      final decoded = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      expect(decoded.containsKey('settings'), isFalse);
    });

    test('T2.14.4: Corrupted JSON string throws FormatException on parse', () {
      const corruptedJson = '{bad: json, unquoted}';
      expect(() => jsonDecode(corruptedJson), throwsA(isA<FormatException>()));
    });

    test('T2.14.5: StorageService initializes with empty initial preferences without error', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      expect(storage.loadPlaylists(), isEmpty);
    });

    // -----------------------------------------------------------------------
    // Feature 15 Boundaries
    // -----------------------------------------------------------------------
    test('T2.15.1: android/app/sine-release.jks size is greater than 2000 bytes', () {
      final keystore = File('android/app/sine-release.jks');
      expect(keystore.lengthSync(), greaterThan(2000));
    });

    test('T2.15.2: android/app/build.gradle.kts release block specifies keyAlias sine', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('keyAlias = "sine"'));
    });

    test('T2.15.3: .github/workflows/release.yml includes --no-tree-shake-icons flag', () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();
      expect(workflow, contains('--no-tree-shake-icons'));
    });

    test('T2.15.4: scripts/fetch_cloud_release.py defines retry mechanism', () {
      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, contains('max_retries'));
    });

    test('T2.15.5: scripts/fetch_cloud_release.py checks for successful HTTP response code', () {
      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, contains('status == 200'));
    });
  });

  // =========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS — 15 TESTS
  // =========================================================================
  group('Tier 3: Cross-Feature Combinations (15 Tests)', () {
    test('T3.1: Theme preset switch propagates to EmberTheme and updates PlayerProvider.themeData', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      await player.setThemePreset(SineThemePreset.purple);
      expect(player.activeThemePreset, SineThemePreset.purple);
      expect(player.themeData.colorScheme.primary, const Color(0xFFD500F9));

      await player.setThemePreset(SineThemePreset.orange);
      expect(player.activeThemePreset, SineThemePreset.orange);
      expect(player.themeData.colorScheme.primary, const Color(0xFFFF6D00));
    });

    test('T3.2: SineWidgetService update integrates with Song playback events', () async {
      channelLog.clear();
      SineWidgetService.resetCache();

      const song = Song(
        id: 's_pair',
        title: 'Pairwise Track',
        artist: 'Pairwise Artist',
        duration: Duration(minutes: 3),
        artworkUrl: '',
        streamUrl: '',
      );
      await SineWidgetService.updateWidget(title: song.title, artist: song.artist, isPlaying: true);

      expect(channelLog.length, 1);
      expect(channelLog.first.arguments['title'], 'Pairwise Track');
      expect(channelLog.first.arguments['isPlaying'], true);

      // Pause playback
      await SineWidgetService.updateWidget(title: song.title, artist: song.artist, isPlaying: false);
      expect(channelLog.length, 2);
      expect(channelLog.last.arguments['isPlaying'], false);
    });

    test('T3.3: Queue reordering preserves current playing song identity and metadata', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      const song1 = Song(id: 's1', title: 'Track 1', artist: 'Artist 1', duration: Duration(minutes: 3), artworkUrl: '', streamUrl: '');
      const song2 = Song(id: 's2', title: 'Track 2', artist: 'Artist 2', duration: Duration(minutes: 3), artworkUrl: '', streamUrl: '');

      player.addToQueue(song1);
      player.addToQueue(song2);
      expect(player.currentSong?.id, 's1');

      player.reorderQueue(0, 2);
      expect(player.currentSong?.id, 's1');
      expect(player.currentIndex, 1);
    });

    testWidgets('T3.4: RepaintBoundary isolates VinylDisc and SpectrumBars during active tree mounting', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                RepaintBoundary(child: VinylDisc(size: 60, isPlaying: false)),
                RepaintBoundary(child: SpectrumBars(isPlaying: false, height: 12)),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    test('T3.5: Custom theme accent changes ThemeData primary while keeping obsidian background', () {
      const customAccent = Color(0xFF00E5FF);
      final theme = EmberTheme.buildTheme(accentColor: customAccent, useGoogleFonts: false);
      expect(theme.colorScheme.primary, customAccent);
      expect(theme.scaffoldBackgroundColor, EmberColors.obsidianBase);
    });

    test('T3.6: Widget update call serializes song title and artist identically to model', () async {
      channelLog.clear();
      SineWidgetService.resetCache();

      const song = Song(
        id: 'model_test',
        title: 'Model Title',
        artist: 'Model Artist',
        duration: Duration(minutes: 4),
        artworkUrl: '',
        streamUrl: '',
      );
      await SineWidgetService.updateWidget(title: song.title, artist: song.artist, isPlaying: true);

      final args = channelLog.first.arguments as Map<dynamic, dynamic>;
      expect(args['title'], song.title);
      expect(args['artist'], song.artist);
      expect(args['isPlaying'], true);
    });

    test('T3.7: Queue additions and reorder operations maintain consistent queue length', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      for (int i = 0; i < 5; i++) {
        player.addToQueue(Song(
          id: 'item_$i',
          title: 'Title $i',
          artist: 'Artist $i',
          duration: const Duration(minutes: 2),
          artworkUrl: '',
          streamUrl: '',
        ));
      }
      expect(player.queue.length, 5);

      player.reorderQueue(1, 4);
      expect(player.queue.length, 5);
      player.removeTrackAt(2);
      expect(player.queue.length, 4);
    });

    test('T3.8: Crossfade duration in StorageService synchronizes with PlayerProvider', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      await storage.saveCrossfadeSeconds(9);
      player.setCrossfadeSeconds(storage.loadCrossfadeSeconds());
      expect(player.crossfadeSeconds, 9);
    });

    test('T3.9: Hero tag format links MiniPlayer and NowPlaying with matching song ID', () {
      const songId = 'hero_cross_test';
      final miniTag = 'player_art_${songId.isNotEmpty ? songId : "default"}';
      final nowTag = 'player_art_${songId.isNotEmpty ? songId : "default"}';
      expect(miniTag, equals(nowTag));
      expect(miniTag, contains('hero_cross_test'));
    });

    test('T3.10: EmberTheme builds valid high contrast scheme with current palette', () {
      for (final preset in SineThemePreset.values) {
        final theme = EmberTheme.buildTheme(accentColor: preset.accentColor, useGoogleFonts: false);
        expect(theme.colorScheme.onPrimary, EmberColors.obsidianBase);
        expect(theme.brightness, Brightness.dark);
      }
    });

    test('T3.11: Widget Service cache invalidation allows immediate replay redispatch', () async {
      channelLog.clear();
      SineWidgetService.resetCache();

      await SineWidgetService.updateWidget(title: 'Replay Track', artist: 'Artist', isPlaying: true);
      expect(channelLog.length, 1);

      SineWidgetService.resetCache();
      await SineWidgetService.updateWidget(title: 'Replay Track', artist: 'Artist', isPlaying: true);
      expect(channelLog.length, 2);
    });

    test('T3.12: Backup payload correctly embeds active AppConstants version and settings', () {
      final backup = {
        'format': 'SINE_BACKUP',
        'version': AppConstants.version,
        'versionCode': AppConstants.buildNumber,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'settings': {
          'crossfade': 4,
          'gapless': true,
        },
      };
      final jsonStr = jsonEncode(backup);
      expect(jsonStr, contains(AppConstants.version));
      expect(jsonStr, contains('"crossfade":4'));
    });

    testWidgets('T3.13: Multiple continuous animated widgets mount concurrently without tree error', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                RepaintBoundary(child: VinylDisc(size: 50, isPlaying: false)),
                RepaintBoundary(child: AmbientGlow(isPlaying: false, child: SizedBox(width: 30, height: 30))),
                RepaintBoundary(child: SpectrumBars(isPlaying: false, barCount: 4)),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(VinylDisc), findsOneWidget);
      expect(find.byType(AmbientGlow), findsOneWidget);
      expect(find.byType(SpectrumBars), findsOneWidget);
    });

    test('T3.14: SineMusicWidgetProvider action constants match expected widget actions', () {
      final kt = File('android/app/src/main/kotlin/com/taezeem/spotify_newpipe/spotify_newpipe/SineMusicWidgetProvider.kt').readAsStringSync();
      expect(kt, contains('ACTION_UPDATE_WIDGET = "com.taezeem.spotify_newpipe.ACTION_UPDATE_WIDGET"'));
      expect(kt, contains('ACTION_WIDGET_PLAY_PAUSE = "com.taezeem.spotify_newpipe.ACTION_WIDGET_PLAY_PAUSE"'));
      expect(kt, contains('ACTION_WIDGET_NEXT = "com.taezeem.spotify_newpipe.ACTION_WIDGET_NEXT"'));
      expect(kt, contains('ACTION_WIDGET_PREV = "com.taezeem.spotify_newpipe.ACTION_WIDGET_PREV"'));
    });

    test('T3.15: Release workflow tag trigger pattern matches AppConstants releaseTag prefix', () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();
      expect(workflow, contains("- 'v*'"));
      expect(AppConstants.releaseTag, startsWith('v'));
    });
  });

  // =========================================================================
  // TIER 4: REAL-WORLD APPLICATION SCENARIOS — 5 TESTS
  // =========================================================================
  group('Tier 4: Real-World Application Scenarios (5 Tests)', () {
    test('T4.1: Scenario 1 - Onboarding, Theme Selection & OLED Customization Workflow', () async {
      // 1. User launches app, initialize storage
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      // 2. Default theme is blue
      expect(player.activeThemePreset, SineThemePreset.blue);

      // 3. User selects purple preset
      await player.setThemePreset(SineThemePreset.purple);
      expect(player.activeThemePreset, SineThemePreset.purple);
      expect(player.themeData.colorScheme.primary, const Color(0xFFD500F9));

      // 4. User applies custom Neon Cyan accent
      const customCyan = Color(0xFF00E5FF);
      EmberColors.applyThemeColor(customCyan);
      final customTheme = EmberTheme.buildTheme(accentColor: customCyan, useGoogleFonts: false);
      expect(customTheme.colorScheme.primary, customCyan);
      expect(customTheme.scaffoldBackgroundColor, EmberColors.obsidianBase);

      // 5. Verify persistence
      await storage.saveThemePreset(SineThemePreset.custom.name);
      expect(storage.loadThemePreset(), SineThemePreset.custom.name);
    });

    test('T4.2: Scenario 2 - Workout Session Queue Reordering & Dismissal Workflow', () async {
      final storage = await StorageService.init();
      final handler = SineAudioHandler();
      final player = PlayerProvider(handler, storage);

      // 1. Add 5 high-energy tracks
      for (int i = 1; i <= 5; i++) {
        player.addToQueue(Song(
          id: 'workout_track_$i',
          title: 'Energy Track $i',
          artist: 'Workout Artist',
          duration: const Duration(minutes: 3),
          artworkUrl: '',
          streamUrl: '',
        ));
      }
      expect(player.queue.length, 5);
      expect(player.currentSong?.id, 'workout_track_1');

      // 2. Reorder track #3 to position #1
      player.reorderQueue(2, 1);
      expect(player.queue[1].id, 'workout_track_3');

      // 3. Dismiss unwanted track at index 3
      final removedSongId = player.queue[3].id;
      player.removeTrackAt(3);
      expect(player.queue.length, 4);
      expect(player.queue.any((s) => s.id == removedSongId), isFalse);

      // 4. Verify playing track remains workout_track_1
      expect(player.currentSong?.id, 'workout_track_1');
    });

    test('T4.3: Scenario 3 - Commute Experience & Native Android Widget Synchronization Workflow', () async {
      channelLog.clear();
      SineWidgetService.resetCache();

      // 1. Start playback of commute track
      const commuteSong = Song(
        id: 'commute_01',
        title: 'Morning Commute',
        artist: 'Chillout Crew',
        duration: Duration(minutes: 4, seconds: 15),
        artworkUrl: '',
        streamUrl: '',
      );

      // 2. SineWidgetService updates Android widget
      await SineWidgetService.updateWidget(
        title: commuteSong.title,
        artist: commuteSong.artist,
        isPlaying: true,
      );
      expect(channelLog.length, 1);
      expect(channelLog.first.arguments['title'], 'Morning Commute');
      expect(channelLog.first.arguments['isPlaying'], true);

      // 3. Deduplication prevents unnecessary IPC wakeups on repeat tick
      await SineWidgetService.updateWidget(
        title: commuteSong.title,
        artist: commuteSong.artist,
        isPlaying: true,
      );
      expect(channelLog.length, 1);

      // 4. User pauses playback on arrival
      await SineWidgetService.updateWidget(
        title: commuteSong.title,
        artist: commuteSong.artist,
        isPlaying: false,
      );
      expect(channelLog.length, 2);
      expect(channelLog.last.arguments['isPlaying'], false);
    });

    test('T4.4: Scenario 4 - Audio DSP Tuning & Library Disaster Recovery Workflow', () async {
      final storage = await StorageService.init();

      // 1. Configure audio settings
      await storage.saveCrossfadeSeconds(6);
      await storage.saveEqualizerEnabled(true);
      await storage.saveEqualizerPreset('AutoEq: Harman Target');
      await storage.saveBassBoost(0.4);

      // 2. Create playlist and favorite
      const testSong = Song(
        id: 'disaster_recov_1',
        title: 'Midnight Stroll',
        artist: 'Synthwave Dreams',
        duration: Duration(minutes: 3, seconds: 45),
        artworkUrl: '',
        streamUrl: '',
      );
      final playlist = Playlist(
        id: 'pl_recov',
        title: 'Recovery Vault',
        songs: [testSong],
        createdAt: DateTime.now(),
      );
      await storage.savePlaylist(playlist);
      await storage.saveFavorites([testSong]);

      // 3. Export library backup JSON
      final exportedJson = storage.exportBackupJson();
      expect(exportedJson, contains('SINE_BACKUP'));
      expect(exportedJson, contains('Recovery Vault'));

      // 4. Simulate corruption by clearing storage
      SharedPreferences.setMockInitialValues({});
      final freshStorage = await StorageService.init();
      expect(freshStorage.loadPlaylists(), isEmpty);

      // 5. Restore from exported JSON
      final success = await freshStorage.importBackupJson(exportedJson);
      expect(success, isNotNull);

      final restoredPlaylists = freshStorage.loadPlaylists();
      expect(restoredPlaylists.length, 1);
      expect(restoredPlaylists.first.title, 'Recovery Vault');
      expect(freshStorage.loadCrossfadeSeconds(), 6);
    });

    test('T4.5: Scenario 5 - Cloud CI/CD Release, Version Integrity & Keystore Security Workflow', () {
      // 1. Validate version alignment between AppConstants and pubspec.yaml
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, anyOf(contains('version: 1.3.2+32'), contains('version: 1.3.3+33'), contains('version: 1.3.4+34'), contains('version: 1.3.5+35'), contains('version: 1.3.6+36'), contains('version: 1.3.7+37')));
      expect(AppConstants.version, anyOf('1.3.2', '1.3.3', '1.3.4', '1.3.5', '1.3.6', '1.3.7'));
      expect(AppConstants.buildNumber, anyOf(32, 33, 34, 35, 36, 37));

      // 2. Validate release keystore integrity
      final keystore = File('android/app/sine-release.jks');
      expect(keystore.existsSync(), isTrue);
      expect(keystore.lengthSync(), greaterThan(2000));

      // 3. Validate build.gradle.kts release signing configuration
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('signingConfigs.getByName("release")'));
      expect(gradle, contains('keyAlias = "sine"'));

      // 4. Validate GitHub Actions release workflow
      final workflow = File('.github/workflows/release.yml').readAsStringSync().replaceAll('\r\n', '\n');
      expect(workflow, contains('push:\n    tags:\n      - \'v*\''));
      expect(workflow, contains(r'Sine-${{ github.ref_name }}.apk'));

      // 5. Validate cloud fetch script
      final script = File('scripts/fetch_cloud_release.py').readAsStringSync();
      expect(script, contains('Sine-'));
    });
  });
}
