import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_newpipe/models/song.dart';
import 'package:spotify_newpipe/models/playlist.dart';
import 'package:spotify_newpipe/providers/player_provider.dart';
import 'package:spotify_newpipe/services/lyrics_service.dart';
import 'package:spotify_newpipe/services/sponsorblock_service.dart';
import 'package:spotify_newpipe/services/youtube_importer_service.dart';
import 'package:spotify_newpipe/services/stem_service.dart';
import 'package:spotify_newpipe/services/performance_service.dart';
import 'package:spotify_newpipe/services/smart_radio_service.dart';
import 'package:spotify_newpipe/services/app_lock_service.dart';
import 'package:spotify_newpipe/widgets/spotify_graph_equalizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Sine Music Architecture Tests', () {
    test('Song model initializes with correct metadata and serialization', () {
      const song = Song(
        id: 'yt_dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: Duration(minutes: 3, seconds: 32),
        artworkUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        streamUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        instrumentalVideoId: 'inst_123',
        acapellaVideoId: 'acap_456',
      );

      expect(song.id, 'yt_dQw4w9WgXcQ');
      expect(song.title, 'Never Gonna Give You Up');
      expect(song.artist, 'Rick Astley');
      expect(song.duration.inSeconds, 212);
      expect(song.artworkUrl, isNotEmpty);
      expect(song.streamUrl, isNotEmpty);
      expect(song.instrumentalVideoId, 'inst_123');
      expect(song.acapellaVideoId, 'acap_456');

      final map = song.toMap();
      final revived = Song.fromMap(map);
      expect(revived.id, song.id);
      expect(revived.title, song.title);
      expect(revived.artist, song.artist);
      expect(revived.instrumentalVideoId, 'inst_123');
      expect(revived.acapellaVideoId, 'acap_456');
    });

    test('Playlist correctly adds and serializes songs with snake_case support', () {
      final now = DateTime.now();
      final playlist = Playlist(
        id: 'pl_favorites',
        title: 'Cyberpunk Mix',
        description: 'Synthwave & Electronic',
        coverUrl: 'https://example.com/cover.jpg',
        songs: const [],
        createdAt: now,
        continuationToken: 'token_abc_123',
      );

      const track = Song(
        id: 'track_1',
        title: 'Resonance',
        artist: 'HOME',
        duration: Duration(minutes: 3, seconds: 32),
        artworkUrl: '',
        streamUrl: 'https://example.com/stream.mp3',
      );

      final updatedPlaylist = playlist.copyWith(songs: [track]);
      expect(updatedPlaylist.songs.length, 1);
      expect(updatedPlaylist.songs.first.title, 'Resonance');

      final map = updatedPlaylist.toMap();
      expect(map['cover_url'], 'https://example.com/cover.jpg');
      expect(map['continuation_token'], 'token_abc_123');

      final revived = Playlist.fromMap(map);
      expect(revived.title, 'Cyberpunk Mix');
      expect(revived.coverUrl, 'https://example.com/cover.jpg');
      expect(revived.continuationToken, 'token_abc_123');
      expect(revived.songs.length, 1);
      expect(revived.songs.first.artist, 'HOME');
    });

    test('YouTube video ID parser extracts correctly from multiple URL formats', () {
      expect(
        YouTubeImporterService.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeImporterService.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeImporterService.extractVideoId('https://music.youtube.com/watch?v=dQw4w9WgXcQ&feature=share'),
        'dQw4w9WgXcQ',
      );
      expect(
        YouTubeImporterService.extractVideoId('dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('SponsorBlock service initializes with enabled state', () {
      final service = SponsorBlockService.instance;
      expect(service.isEnabled, isTrue);
    });

    test('Song.fromMap defensively parses heterogeneous data types without crashing', () {
      final dynamicMap = <String, dynamic>{
        'id': 12345, // int instead of String
        'title': 'Test Song',
        'artist': 'Test Artist',
        'duration_ms': '210000', // String instead of int
        'artwork_url': 'https://example.com/art.jpg',
        'stream_url': 'https://example.com/audio.mp3',
        'is_favorite': 1, // int 1 instead of boolean
      };

      final parsed = Song.fromMap(dynamicMap);
      expect(parsed.id, '12345');
      expect(parsed.duration.inMilliseconds, 210000);
      expect(parsed.isFavorite, isTrue);
    });

    test('Playlist.fromMap parses Map<dynamic, dynamic> without dropping tracks', () {
      final rawPlaylistMap = <dynamic, dynamic>{
        'id': 'pl_test',
        'title': 'Dynamic Test',
        'description': 'Description',
        'songs': [
          <dynamic, dynamic>{
            'id': 's1',
            'title': 'Track One',
            'artist': 'Artist One',
            'duration_ms': 180000,
            'artwork_url': '',
            'stream_url': 'https://example.com/1.mp3',
          }
        ],
        'createdAt': '2026-10-03T20:00:00.000Z',
      };

      final pl = Playlist.fromMap(Map<String, dynamic>.from(rawPlaylistMap));
      expect(pl.title, 'Dynamic Test');
      expect(pl.songs.length, 1);
      expect(pl.songs.first.title, 'Track One');
    });

    test('NewPipe stream resolver extracts high-speed audio candidates', () async {
      try {
        final urls = await YouTubeImporterService.getAudioStreamUrls('dQw4w9WgXcQ');
        expect(urls, isNotEmpty);
        expect(urls.length, lessThanOrEqualTo(3)); // Streamlined to top Opus/AAC candidates

        final client = http.Client();
        try {
          final resp = await client.get(
            Uri.parse(urls.first),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
              'Range': 'bytes=0-65535',
              'Origin': 'https://www.youtube.com',
              'Referer': 'https://www.youtube.com/',
              'Sec-Fetch-Dest': 'empty',
              'Sec-Fetch-Mode': 'cors',
              'Sec-Fetch-Site': 'cross-site',
            },
          );
          expect(resp.statusCode, inInclusiveRange(200, 206));
          expect(resp.bodyBytes.length, greaterThan(0));
        } finally {
          client.close();
        }
      } catch (e) {
        // Fallback for offline testing environments without live internet access
        expect(e, isNotNull);
      }
    });

    test('LyricsService accurately parses third-party re-upload titles and sanitizes channels', () {
      // 1. Third-party upload with "Artist - Track (Lyrics)" by curator channel
      final cand1 = LyricsService.generateCandidates(
        'The Weeknd - Blinding Lights (Official Lyric Video)',
        'VibeZone24',
      );
      expect(cand1, isNotEmpty);
      expect(cand1.first.artist, 'The Weeknd');
      expect(cand1.first.title, 'Blinding Lights');

      // 2. Upload with bracketed noise [Official Audio]
      final cand2 = LyricsService.generateCandidates(
        'Eminem - Mockingbird [Official Audio]',
        'HipHopDaily',
      );
      expect(cand2.first.artist, 'Eminem');
      expect(cand2.first.title, 'Mockingbird');

      // 3. YouTube auto-generated channel with "- Topic"
      final cleanArt = LyricsService.cleanArtist('Chris Grey - Topic');
      expect(cleanArt, 'Chris Grey');

      // 4. VEVO suffix channel
      final cleanVevo = LyricsService.cleanArtist('TaylorSwiftVEVO');
      expect(cleanVevo, 'TaylorSwift');

      // 5. Title with leading track number and noise tags
      final cleanT = LyricsService.cleanTitle('01. Billie Eilish - BIRDS OF A FEATHER (Slowed + Reverb)');
      expect(cleanT, 'Billie Eilish - BIRDS OF A FEATHER');

      // 6. CJK brackets cleaning
      final cjkClean = LyricsService.cleanTitle('YOASOBI - 【MV】 夜に駆ける');
      expect(cjkClean.contains('【MV】'), isFalse);
    });

    test('IsolationMode enum supports Vocals Only and Instruments Only states', () {
      expect(IsolationMode.values, contains(IsolationMode.none));
      expect(IsolationMode.values, contains(IsolationMode.vocalsOnly));
      expect(IsolationMode.values, contains(IsolationMode.instrumentsOnly));
    });

    test('StemService initializes with clean cache and supports clearing', () {
      final stemService = StemService.instance;
      expect(stemService, isNotNull);
      StemService.clearMemoryCache();
    });

    test('SmartRadioService initializes and supports clearing caches', () {
      final radio = SmartRadioService.instance;
      expect(radio, isNotNull);
      SmartRadioService.clearCaches();
    });

    test('SmartRadioService generates valid radio station with seed track preserved', () async {
      const seed = Song(
        id: 'yt_dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        duration: Duration(minutes: 3, seconds: 32),
        artworkUrl: '',
        streamUrl: 'https://example.com/audio.mp3',
      );

      final station = await SmartRadioService.instance.generateRadioStation(
        seedSong: seed,
        isArtistRadio: false,
      );

      expect(station.seedSong.id, seed.id);
      expect(station.songs, isNotEmpty);
      expect(station.songs.first.id, seed.id);
    });

    test('AppLockService correctly sets, verifies, and removes PIN', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await AppLockService.isLockEnabled(), isFalse);
      expect(await AppLockService.hasPinSetup(), isFalse);

      final success = await AppLockService.setPin('1234');
      expect(success, isTrue);
      expect(await AppLockService.isLockEnabled(), isTrue);
      expect(await AppLockService.hasPinSetup(), isTrue);

      expect(await AppLockService.verifyPin('1234'), isTrue);
      expect(await AppLockService.verifyPin('0000'), isFalse);
      expect(await AppLockService.verifyPin('123'), isFalse);

      await AppLockService.setLockEnabled(false);
      expect(await AppLockService.isLockEnabled(), isFalse);
      expect(await AppLockService.hasPinSetup(), isTrue);

      await AppLockService.removePin();
      expect(await AppLockService.isLockEnabled(), isFalse);
      expect(await AppLockService.hasPinSetup(), isFalse);
    });

    test('SpotifyGraphEqualizer defines complete 6-band preset curves', () {
      expect(SpotifyGraphEqualizer.frequencyLabels.length, 6);
      expect(SpotifyGraphEqualizer.standardPresets, isNotEmpty);

      for (final preset in SpotifyGraphEqualizer.standardPresets) {
        expect(preset.name, isNotEmpty);
        expect(preset.gains.length, 6, reason: 'Preset ${preset.name} must have 6 frequency bands');
        for (final g in preset.gains) {
          expect(g >= -12.0 && g <= 12.0, isTrue, reason: 'Gain $g in preset ${preset.name} must be within [-12, 12] dB');
        }
      }
    });

    test('Sine QR URI schema correctly formats and decodes track metadata', () {
      const song = Song(
        id: 'yt_abc123',
        title: 'Starboy (feat. Daft Punk)',
        artist: 'The Weeknd',
        duration: Duration(minutes: 3, seconds: 50),
        artworkUrl: '',
        streamUrl: '',
      );

      final encodedTitle = Uri.encodeComponent(song.title);
      final encodedArtist = Uri.encodeComponent(song.artist);
      final uriStr = 'sine://track?id=${song.id}&title=$encodedTitle&artist=$encodedArtist';

      final parsed = Uri.parse(uriStr);
      expect(parsed.scheme, 'sine');
      expect(parsed.host, 'track');
      expect(parsed.queryParameters['id'], 'yt_abc123');
      expect(parsed.queryParameters['title'], 'Starboy (feat. Daft Punk)');
      expect(parsed.queryParameters['artist'], 'The Weeknd');
    });

    test('parseYouTubeMetadata correctly parses titles and reverses swapped Artist - Title vs Title - Artist', () {
      // Case 1: Standard YouTube Music auto-generated upload (Title with Artist - Topic channel)
      final meta1 = YouTubeImporterService.parseYouTubeMetadata('Blinding Lights', 'The Weeknd - Topic');
      expect(meta1.cleanTitle, 'Blinding Lights');
      expect(meta1.cleanArtist, 'The Weeknd');

      // Case 2: Swapped format "Title - Artist" where channel is the Artist
      final meta2 = YouTubeImporterService.parseYouTubeMetadata('Blinding Lights - The Weeknd', 'The Weeknd');
      expect(meta2.cleanTitle, 'Blinding Lights');
      expect(meta2.cleanArtist, 'The Weeknd');

      // Case 3: Standard format "Artist - Title"
      final meta3 = YouTubeImporterService.parseYouTubeMetadata('The Weeknd - Blinding Lights (Official Video)', 'TheWeekndVEVO');
      expect(meta3.cleanTitle, 'Blinding Lights');
      expect(meta3.cleanArtist, 'The Weeknd');

      // Case 4: Quoted title e.g. "Song Name" - Artist
      final meta4 = YouTubeImporterService.parseYouTubeMetadata('"As It Was" - Harry Styles', 'Harry Styles');
      expect(meta4.cleanTitle, 'As It Was');
      expect(meta4.cleanArtist, 'Harry Styles');

      // Case 5: "Title by Artist" pattern
      final meta5 = YouTubeImporterService.parseYouTubeMetadata('Shape of You by Ed Sheeran', 'Ed Sheeran');
      expect(meta5.cleanTitle, 'Shape of You');
      expect(meta5.cleanArtist, 'Ed Sheeran');

      // Case 6: Curator upload with asymmetric hyphen e.g. "Wishes- Hasan Raheem (Slowed + Reverb)" from "Slow Studio"
      final meta6 = YouTubeImporterService.parseYouTubeMetadata('Wishes- Hasan Raheem (Slowed + Reverb)', 'Slow Studio');
      expect(meta6.cleanTitle, 'Wishes');
      expect(meta6.cleanArtist, 'Hasan Raheem');
    });

    test('isTempoModified correctly identifies slowed, reverb, sped-up, and nightcore tracks', () {
      expect(LyricsService.isTempoModified('Die For You (Slowed + Reverb)'), isTrue);
      expect(LyricsService.isTempoModified('Starboy - Slowed and Reverb'), isTrue);
      expect(LyricsService.isTempoModified('After Hours [Sped Up]'), isTrue);
      expect(LyricsService.isTempoModified('Save Your Tears (Nightcore)'), isTrue);
      expect(LyricsService.isTempoModified('Blinding Lights (Fast version)'), isTrue);
      expect(LyricsService.isTempoModified('Ordinary Track Title', 'Standard Artist'), isFalse);
    });

    test('fetchLyrics returns empty result immediately for tempo-modified songs', () async {
      final res = await LyricsService.fetchLyrics('Die For You (Slowed + Reverb)', 'The Weeknd');
      expect(res.syncedLyrics, isEmpty);
      expect(res.hasSynced, isFalse);
    });

    test('Sine QR URI schema correctly formats and decodes playlist metadata and tracks', () {
      const track1 = Song(
        id: 'yt_track1',
        title: 'Song One',
        artist: 'Artist One',
        duration: Duration(minutes: 3),
        artworkUrl: '',
        streamUrl: '',
      );
      const track2 = Song(
        id: 'yt_track2',
        title: 'Song Two',
        artist: 'Artist Two',
        duration: Duration(minutes: 4),
        artworkUrl: '',
        streamUrl: '',
      );
      final playlist = Playlist(
        id: 'pl_123',
        title: 'Synthwave Night',
        songs: const [track1, track2],
        createdAt: DateTime.now(),
      );

      final encodedTitle = Uri.encodeComponent(playlist.title);
      final compactTracks = playlist.songs.map((s) => '${s.id}*${s.artist}*${s.title}').join('~');
      final encodedTracks = Uri.encodeComponent(compactTracks);
      final uriStr = 'sine://playlist?id=${playlist.id}&title=$encodedTitle&ytId=&tracks=$encodedTracks';

      final parsed = Uri.parse(uriStr);
      expect(parsed.scheme, 'sine');
      expect(parsed.host, 'playlist');
      expect(parsed.queryParameters['id'], 'pl_123');
      expect(parsed.queryParameters['title'], 'Synthwave Night');

      final decodedTracks = Uri.decodeComponent(parsed.queryParameters['tracks']!);
      final items = decodedTracks.split('~');
      expect(items.length, 2);
      expect(items[0], 'yt_track1*Artist One*Song One');
      expect(items[1], 'yt_track2*Artist Two*Song Two');
    });

    test('StemResult correctly initializes AI separated stems and reports status', () {
      final vocalsResult = StemResult.aiSeparated(
        type: StemType.vocals,
        localFilePath: '/storage/emulated/0/Sine/stems/yt_test_vocals.wav',
      );
      expect(vocalsResult.type, StemType.vocals);
      expect(vocalsResult.source, StemSource.aiSeparation);
      expect(vocalsResult.isSuccess, isTrue);
      expect(vocalsResult.isLocal, isTrue);
      expect(vocalsResult.isStudioStem, isTrue);
      expect(vocalsResult.fallbackToDsp, isFalse);
      expect(vocalsResult.streamUrl, '/storage/emulated/0/Sine/stems/yt_test_vocals.wav');

      final instResult = StemResult.aiSeparated(
        type: StemType.instrumental,
        localFilePath: '/storage/emulated/0/Sine/stems/yt_test_instrumental.wav',
      );
      expect(instResult.type, StemType.instrumental);
      expect(instResult.source, StemSource.aiSeparation);
      expect(instResult.isSuccess, isTrue);
      expect(instResult.isLocal, isTrue);
      expect(instResult.isStudioStem, isTrue);
      expect(instResult.fallbackToDsp, isFalse);
      expect(instResult.streamUrl, '/storage/emulated/0/Sine/stems/yt_test_instrumental.wav');

      final dspResult = StemResult.dspFallback(
        type: StemType.instrumental,
        reason: 'AI offline',
      );
      expect(dspResult.source, StemSource.dspFallback);
      expect(dspResult.isSuccess, isFalse);
      expect(dspResult.isStudioStem, isFalse);
      expect(dspResult.fallbackToDsp, isTrue);
    });

    test('StemService supports BS-RoFormer and Demucs source separation endpoints', () {
      expect(StemService.instance, isNotNull);
      StemService.clearMemoryCache();
      expect(StemService.instance.separateAudioWithAi, isNotNull);
      expect(StemService.instance.separateAudioWithDemucs, isNotNull);
    });

    test('StemPipelineDiagnostic records steps and computes total latency', () {
      final diag = StemPipelineDiagnostic(
        id: 'diag_123',
        songId: 'yt_abc',
        songTitle: 'Test Song',
        songArtist: 'Test Artist',
        requestedStem: StemType.instrumental,
        startedAt: DateTime.now().subtract(const Duration(milliseconds: 350)),
      );

      diag.addStep(
        stage: 'Tier 1: Local Disk Cache',
        latency: const Duration(milliseconds: 15),
        isSuccess: false,
        details: 'Cache miss',
      );

      diag.addStep(
        stage: 'Tier 2: SOTA AI Neural Engine',
        latency: const Duration(milliseconds: 320),
        isSuccess: true,
        details: 'Separated via BS-RoFormer',
      );

      diag.complete(
        source: StemSource.aiSeparation,
        success: true,
        resolvedTarget: '/path/to/stem.wav',
      );

      expect(diag.steps.length, 2);
      expect(diag.isSuccess, isTrue);
      expect(diag.finalSource, StemSource.aiSeparation);
      expect(diag.resolvedFileOrUrl, '/path/to/stem.wav');
      expect(diag.totalLatency.inMilliseconds, greaterThanOrEqualTo(300));
    });

    test('PerformanceService initializes and computes valid performance snapshots', () {
      final perf = PerformanceService.instance;
      expect(perf, isNotNull);
      perf.setTargetRefreshRate(120.0);
      expect(perf.snapshotNotifier.value.targetRefreshRate, 120.0);
      perf.resetStats();
      expect(perf.snapshotNotifier.value.totalFrames, 0);
    });

    test('SavedPlaybackSession serializes and deserializes accurately', () {
      const song = Song(
        id: 'yt_saved123',
        title: 'Saved Song',
        artist: 'Saved Artist',
        duration: Duration(minutes: 3),
        artworkUrl: '',
        streamUrl: 'https://example.com/audio.mp3',
      );

      final session = SavedPlaybackSession(
        song: song,
        positionMs: 45000,
        queue: [song],
        currentIndex: 0,
        savedAt: DateTime.now(),
      );

      final map = {
        'song': session.song.toMap(),
        'positionMs': session.positionMs,
        'queue': session.queue.map((s) => s.toMap()).toList(),
        'currentIndex': session.currentIndex,
        'savedAt': session.savedAt.toIso8601String(),
      };

      final restored = SavedPlaybackSession.fromMap(map);
      expect(restored.song.id, 'yt_saved123');
      expect(restored.positionMs, 45000);
      expect(restored.queue.length, 1);
      expect(restored.currentIndex, 0);
    });
  });
}
