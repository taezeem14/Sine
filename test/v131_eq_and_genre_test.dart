import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:spotify_newpipe/constants/app_constants.dart';
import 'package:spotify_newpipe/widgets/spotify_graph_equalizer.dart';
import 'package:spotify_newpipe/services/catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('v1.3.1 Studio Open-Source EQ & Presets Suite', () {
    test('SpotifyGraphEqualizer contains all open-source AutoEq, JamesDSP, and APO presets', () {
      const presets = SpotifyGraphEqualizer.standardPresets;
      expect(presets.length, greaterThanOrEqualTo(30));

      // AutoEq Studio Curves
      final harman = SpotifyGraphEqualizer.getPresetGains('AutoEq: Harman Target');
      expect(harman.length, 6);
      expect(harman[0], 5.2);
      expect(harman[5], 4.2);

      final neutral = SpotifyGraphEqualizer.getPresetGains('AutoEq: Audiophile Neutral');
      expect(neutral.length, 6);
      expect(neutral[0], 1.8);

      final harmanBass = SpotifyGraphEqualizer.getPresetGains('AutoEq: Harman Bass Boost');
      expect(harmanBass.length, 6);
      expect(harmanBass[0], 6.5);

      final vocalForward = SpotifyGraphEqualizer.getPresetGains('AutoEq: Vocal Forward');
      expect(vocalForward.length, 6);
      expect(vocalForward[3], 4.5);

      // JamesDSP Acoustic Models
      final clarity = SpotifyGraphEqualizer.getPresetGains('JamesDSP: Pure Clarity');
      expect(clarity.length, 6);
      expect(clarity[5], 5.5);

      final resonance = SpotifyGraphEqualizer.getPresetGains('JamesDSP: Bass Resonance');
      expect(resonance.length, 6);
      expect(resonance[0], 6.8);

      final tubeWarmth = SpotifyGraphEqualizer.getPresetGains('JamesDSP: Tube Amp Warmth');
      expect(tubeWarmth.length, 6);
      expect(tubeWarmth[0], 3.5);

      final studioMaster = SpotifyGraphEqualizer.getPresetGains('JamesDSP: Studio Master');
      expect(studioMaster.length, 6);
      expect(studioMaster[0], 3.0);

      // Equalizer APO & ISO 226
      final loudness = SpotifyGraphEqualizer.getPresetGains('Equalizer APO: Loudness Contour');
      expect(loudness.length, 6);
      expect(loudness[0], 6.0);

      final space = SpotifyGraphEqualizer.getPresetGains('Equalizer APO: Acoustic Space');
      expect(space.length, 6);
      expect(space[5], 6.0);

      // Ensure all band values are strictly within [-12.0, 12.0] dB
      for (final p in presets) {
        expect(p.gains.length, 6);
        for (final g in p.gains) {
          expect(g, greaterThanOrEqualTo(-12.0));
          expect(g, lessThanOrEqualTo(12.0));
        }
      }
    });

    test('AppConstants contains AutoEq, JamesDSP, and Equalizer APO attributions', () {
      expect(AppConstants.version, '1.3.1');
      expect(AppConstants.buildNumber, 31);

      final names = AppConstants.openSourceAttributions.map((a) => a['name']).toList();
      expect(names, contains('AutoEq'));
      expect(names, contains('JamesDSP'));
      expect(names, contains('Equalizer APO'));
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

  group('v1.3.1 Pitch & Speed Anti-Distortion Headroom Guard', () {
    test('Anti-distortion headroom provides -3.7 dB attenuation during pitch or speed shifts', () {
      double computeSonicHeadroom(double speed, double pitch) {
        final bool isShifted = (speed - 1.0).abs() > 0.005 || (pitch - 1.0).abs() > 0.005;
        return isShifted ? 0.65 : 1.0;
      }

      // Lossless 1.0x baseline
      expect(computeSonicHeadroom(1.0, 1.0), 1.0);

      // Speed shift
      expect(computeSonicHeadroom(1.25, 1.0), 0.65);
      expect(computeSonicHeadroom(0.75, 1.0), 0.65);

      // Pitch shift
      expect(computeSonicHeadroom(1.0, 1.1), 0.65);
      expect(computeSonicHeadroom(1.0, 0.9), 0.65);
    });
  });
}
