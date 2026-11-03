import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'screens/pulsepipe_shell_screen.dart';
import 'services/audio_handler.dart';
import 'services/storage_service.dart';
import 'theme/ember_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation & status bar transparent for edge-to-edge obsidian immersion
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: EmberColors.obsidianBase,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      // ignore: avoid_print
      print(message);
    }
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Sine Flutter Error: ${details.exception}');
  };

  SineAudioHandler audioHandler;
  try {
    final rawHandler = await initAudioHandler();
    audioHandler = rawHandler is SineAudioHandler ? rawHandler : SineAudioHandler();
  } catch (e) {
    debugPrint('AudioHandler init fallback: $e');
    audioHandler = SineAudioHandler();
  }

  StorageService storageService;
  try {
    storageService = await StorageService.init();
  } catch (e) {
    debugPrint('StorageService init fallback: $e');
    storageService = StorageService(null);
  }

  runApp(
    SineMobileApp(
      audioHandler: audioHandler,
      storageService: storageService,
    ),
  );
}

typedef EmberMobileApp = SineMobileApp;

class SineMobileApp extends StatelessWidget {
  final SineAudioHandler audioHandler;
  final StorageService storageService;

  const SineMobileApp({
    super.key,
    required this.audioHandler,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlayerProvider(audioHandler, storageService),
        ),
      ],
      child: MaterialApp(
        title: 'Sine',
        debugShowCheckedModeBanner: false,
        theme: EmberTheme.darkTheme,
        home: const PulsePipeShellScreen(),
      ),
    );
  }
}
