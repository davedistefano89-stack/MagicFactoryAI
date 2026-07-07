// =============================================================================
// Magic Colors · test/unit/theme/theme_tokens_test.dart
// =============================================================================
//
// M2.3 PRODUCTION — Regression test pinning the splash-screen's
// gradient palette tokens. The splash routes through:
//
//   • AppGradients.rainbowStops (light-mode 7-stop rainbow),
//   • AppColors.skyTopNight / skyMidNight / skyBottomNight
//     (dark-mode 3-stop night sky),
//
// so the test asserts the EXACT composition + ordering. Any rename
// or reordering of these tokens silently re-skins the splash; this
// test catches it at the commit gate.
// =============================================================================

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_gradients.dart';

void main() {
  group('Splash palette tokens', () {
    test('light-mode rainbow has 7 stops in canonical rainbow order', () {
      expect(AppGradients.rainbowStops.length, 7);
      // Token-identity pins: a future palette reshuffle that keeps
      // the symbol names but reorders the tokens gets caught here.
      expect(AppGradients.rainbowStops[0], AppColors.magicPink);
      expect(AppGradients.rainbowStops[1], AppColors.tangerine);
      expect(AppGradients.rainbowStops[2], AppColors.sunshineYellow);
      expect(AppGradients.rainbowStops[3], AppColors.mintLeaf);
      expect(AppGradients.rainbowStops[4], AppColors.lagoon);
      expect(AppGradients.rainbowStops[5], AppColors.skyCyan);
      expect(AppGradients.rainbowStops[6], AppColors.magicPurple);

      // Hex-level pin for the canonical Magic Pink so a silent
      // re-skin that keeps `magicPink` as a symbol but darkens /
      // lightens the actual hex value is also caught at the gate.
      expect(AppColors.magicPink, const Color(0xFFFF4F9A),
          reason: 'magicPink hex pin fails a silent re-skin.');
    });

    test('dark-mode night-sky palette is 3 named stops, bottom is ink', () {
      const List<Color> expected = <Color>[
        AppColors.skyTopNight,
        AppColors.skyMidNight,
        AppColors.skyBottomNight,
      ];
      // All 3 stops are opaque (component accessor `.a` returns
      // double 0..1 — avoids the deprecated `.alpha` getter).
      for (final Color c in expected) {
        expect(c.a, closeTo(1.0, 1e-6),
            reason: 'night-sky stops are fully opaque');
        expect(c.computeLuminance(), lessThan(0.20),
            reason: 'night-sky stops should be deep, not pale');
      }
      // M2.3 PRODUCTION — `skyBottomNight` deliberately collapses
      // all the way to deepInk (#0F1226), so it has the lowest
      // luminance of the three. We do NOT pin a strict ordering
      // between `skyTopNight` and `skyMidNight` because the
      // gradient is tuned for visual style — mid can be a touch
      // brighter than top in the luminometric sense, the design
      // intent is "all three feel like deep night".
      expect(
        expected[2].computeLuminance(),
        lessThan(expected[0].computeLuminance()),
        reason: 'skyBottomNight must be darker than skyTopNight',
      );
      expect(
        expected[2].computeLuminance(),
        lessThan(expected[1].computeLuminance()),
        reason: 'skyBottomNight must be darker than skyMidNight',
      );
      // Hex pin: deepInk is the splash's bottom stop's colour value.
      expect(AppColors.skyBottomNight, AppColors.deepInk,
          reason: 'skyBottomNight collapses to the ink token');
    });

    test(
        'splash gradient tokens are reachable from app_gradients.dart '
        '(no missing getters)', () {
      // Sanity: AppGradients.rainbow references the same stops as
      // AppGradients.rainbowStops. SplashScreen uses the list directly.
      expect(AppGradients.rainbow.colors.length, 7);
      for (int i = 0; i < 7; i++) {
        expect(AppGradients.rainbow.colors[i], AppGradients.rainbowStops[i]);
      }
      // And the tilted variant used by the Reward pop-up card
      // preserves the same start/end ordering so the rainbow chrome
      // stays consistent across the two surfaces.
      expect(AppGradients.rainbowTilted.colors.length, 7);
      for (int i = 0; i < 7; i++) {
        expect(
          AppGradients.rainbowTilted.colors[i],
          AppGradients.rainbowStops[i],
        );
      }
    });
  });
}
