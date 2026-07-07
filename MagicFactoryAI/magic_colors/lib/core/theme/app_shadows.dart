// =============================================================================
// Magic Colors · core/theme/app_shadows.dart
// =============================================================================
//
// Frozen layered drop-shadow tokens. Composed by Container / DecoratedBox
// shells that need a Material-3-style lift without inheriting the
// Material elevation shader.
//
// Conventions:
//   ▸ All fields are `static const List<BoxShadow>` (Material 3 friendly).
//   ▸ Hex colours are paired so the "tier" reads as: soft (20 % violet),
//     medium (27 % violet + thin white highlight), deep (40 % deep
//     violet), playButton (40 % pink + 20 % yellow).
//   ▸ Reach for [AppElevation.softChip] / [.glowPink] / etc. for the more
//     semantic single-layer shadows; AppShadows.drops are layered stacks.
// =============================================================================

import 'package:flutter/painting.dart' show BoxShadow, Color, Offset;

/// Layered drop-shadow catalogue. Use `boxShadow: AppShadows.medium` etc.
abstract final class AppShadows {
  const AppShadows._();

  /// 20 % violet resting shadow — single 18 dp blur underlay. Used by
  /// cards at rest and the CurrencyHUD's pill containers.
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x337A55D9), // 20 % magicPurple
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  /// 27 % violet + thin white highlight — two-layer stack used by the
  /// PLAY NOW halo scoreboard + premium acet.
  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(
      color: Color(0x447A55D9), // 27 % magicPurple
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x33FFFFFF), // 20 % white highlight (top edge)
      offset: Offset(0, -2),
    ),
  ];

  /// 40 % deep violet — heavy drop for card-stack headers and the Magic
  /// Card accent skin.
  static const List<BoxShadow> deep = <BoxShadow>[
    BoxShadow(
      color: Color(0x664D2A8C), // 40 % deep violet
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];

  /// Pink + yellow halo stack used by `PlayNowButton` as the press-burst
  /// resting shadow layer.
  static const List<BoxShadow> playButton = <BoxShadow>[
    BoxShadow(
      color: Color(0x66FF6F94), // 40 % magicPink underglow
      blurRadius: 36,
      offset: Offset(0, 18),
    ),
    BoxShadow(
      color: Color(0x33FFE16C), // 20 % sunshineYellow halo
      blurRadius: 60,
    ),
  ];
}
