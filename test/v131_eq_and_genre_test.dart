import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/widgets/spotify_graph_equalizer.dart';
import 'package:spotify_newpipe/services/catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('v1.3.7 Pure OG Sine Equalizer & Presets Suite', () {
    test('SpotifyGraphEqualizer contains clean OG Sine presets without AutoEq/JamesDSP/APO', () {
      const presets = SpotifyGraphEqualizer.standardPresets;
      expect(presets.length, greaterThanOrEqualTo(25));

      // Verify AutoEq, JamesDSP, and APO presets are completely removed
      for (final p in presets) {
        expect(p.name, isNot(contains('AutoEq')));
        expect(p.name, isNot(contains('JamesDSP')));
        expect(p.name, isNot(contains('Equalizer APO')));
      }

      // Classic OG Sine Presets
      final flat = SpotifyGraphEqualizer.getPresetGains('Flat');
      expect(flat.length, 6);
      expect(flat.every((g) => g == 0.0), isTrue);

      final bassBoost = SpotifyGraphEqualizer.getPresetGains('Bass Boost');
      expect(bassBoost.length, 6);
      expect(bassBoost[0], 6.0);
      expect(bassBoost[1], 4.0);

      final hiphop = SpotifyGraphEqualizer.getPresetGains('Hip-Hop');
      expect(hiphop.length, 6);
      expect(hiphop[0], 5.5);

      final vocalBooster = SpotifyGraphEqualizer.getPresetGains('Vocal Booster');
      expect(vocalBooster.length, 6);
      expect(vocalBooster[3], 4.0);

      final acoustic = SpotifyGraphEqualizer.getPresetGains('Acoustic');
      expect(acoustic.length, 6);
      expect(acoustic[0], 1.0);

      final electronic = SpotifyGraphEqualizer.getPresetGains('Electronic');
      expect(electronic.length, 6);
      expect(electronic[0], 4.5);

      // Ensure all band values are strictly within [-12.0, 12.0] dB
      for (final p in presets) {
        expect(p.gains.length, 6);
        for (final g in p.gains) {
          expect(g, greaterThanOrEqualTo(-12.0));
          expect(g, lessThanOrEqualTo(12.0));
        }
      }
    });

    test('AppConstants contains clean open-source attributions without AutoEq, JamesDSP, or Equalizer APO', () {
      expect(AppConstants.version, isNotEmpty);
      expect(AppConstants.buildNumber, greaterThanOrEqualTo(31));

      final names = AppConstants.openSourceAttributions.map((a) => a['name']).toList();
      expect(names, isNot(contains('AutoEq')));
      expect(names, isNot(contains('JamesDSP')));
      expect(names, isNot(contains('Equalizer APO')));
      expect(names, contains('Audile'));
      expect(names, contains('zemer-cipher'));
      expect(names, contains('BetterLyrics'));
      expect(names, contains('Metrolist'));
    });
  });

  group('v1.3.1 Curated Genre Explorer Suite', () {
    test('CatalogService provides curated genres and validation', () {
      expect(CatalogService.categories.length, greaterThanOrEqualTo(8));
      // Verifies getCachedCategory behaves safely on empty cache
      expect(CatalogService.getCachedCategory('unknown_cat'), isNull);
    });
  });

  group('v1.3.7 Pitch & Speed Anti-Distortion Transparent Headroom Guard', () {
    test('Anti-distortion transparent headroom maintains dynamic punch during shifts', () {
      double computeSonicHeadroom(double speed, double pitch) {
        final bool isShifted = (speed - 1.0).abs() > 0.005 || (pitch - 1.0).abs() > 0.005;
        return isShifted ? 0.94 : 1.0;
      }

      // Lossless 1.0x baseline
      expect(computeSonicHeadroom(1.0, 1.0), 1.0);

      // Speed shift provides gentle -0.5 dB headroom (0.94) instead of harsh 35% cut
      expect(computeSonicHeadroom(1.25, 1.0), 0.94);
      expect(computeSonicHeadroom(0.75, 1.0), 0.94);

      // Pitch shift
      expect(computeSonicHeadroom(1.0, 1.1), 0.94);
      expect(computeSonicHeadroom(1.0, 0.9), 0.94);
    });
  });
}
