// =============================================================================
// Magic Colors · core/theme/app_gradients.dart
// =============================================================================
//
// Frozen gradient tokens. Widgets compose these into BoxDecoration,
// ShaderMask, and Material TabBar indicators; no widget inlines a fresh
// `LinearGradient(colors: [...])` call.
//
// Conventions:
//   ▸ Static const fields only — Material 3 cacheable.
//   ▸ `begin`/`end` fixed at construction so designers can argue about
//     gradient direction ONCE.
//   ▸ All chromatic colours come from `app_colors.dart` — never inline
//     `Color(0x…)` here.
// =============================================================================

import 'package:flutter/painting.dart' show Alignment, Color, LinearGradient;

import 'app_colors.dart';

// =============================================================================
//  AppGradients — frozen catalogue.
// =============================================================================

/// Pre-built child-friendly gradients. Used everywhere BoxDecoration or
/// ShaderMask needs a multi-stop fill.
abstract final class AppGradients {
  const AppGradients._();

  /// Sky-to-sunset day palette — the default background fill for Home,
  /// Worlds, and the canvas backdrop.
  static const LinearGradient skyDefault = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.skyTop,
      AppColors.cloudWhite,
      AppColors.skyTouchedWhite,
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  /// Night-sky horizon — auto-swapped when SettingsState.themeMode is dark.
  static const LinearGradient skyNight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.skyTopNight,
      AppColors.skyMidNight,
      AppColors.skyBottomNight,
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  /// Legacy alias for `skyDefault` (kept so widget-layer call sites that
  /// predate the day/night split continue to compile).
  static const LinearGradient sky = skyDefault;

  /// 7-stop rainbow sweep — used by the PLAY NOW button highlight, the
  /// top-bar wordmarks, and the magic-card accent skin. Tokens and
  /// ordering are pinned by test/unit/theme/theme_tokens_test.dart so a
  /// silent re-skin is caught at the commit gate.
  static const LinearGradient rainbow = LinearGradient(
    colors: rainbowStops,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Mirror of [rainbow] rotated to top-right → bottom-left. Used by
  /// [MascotAvatar.celebrate] for avatar fills and reward-popup top-stripe.
  static const LinearGradient rainbowTilted = LinearGradient(
    colors: rainbowStops,
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// Rainow stop list — exposed separately so the Splash screen
  /// (which reads a bare `List<Color>` for its custom-paint sweep)
  /// doesn't need to call `.colors` on the gradient. The 7 entries
  /// walk red → orange → yellow → green → lagoon → sky-cyan → purple.
  static const List<Color> rainbowStops = <Color>[
    AppColors.magicPink, // red
    AppColors.tangerine, // orange
    AppColors.sunshineYellow, // yellow
    AppColors.mintLeaf, // green
    AppColors.lagoon, // teal (extra mid-tone for the 7-stop palette)
    AppColors.skyCyan, // blue
    AppColors.magicPurple, // purple
  ];

  /// PLAY NOW button — 3-stop cotton-candy → sunshine peach wash.
  static const LinearGradient playNow = LinearGradient(
    colors: <Color>[
      Color(0xFFFF8FB4),
      Color(0xFFFFD86E),
      Color(0xFFFFB16E),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Tiny chest / chip body — soft pale cloud-white → lavender wash.
  /// Used by `_ChestIcon` in the Event Banner and reward-row icons.
  static const LinearGradient softChip = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.cloudWhite,
      AppColors.lavender,
    ],
    stops: <double>[0.0, 1.0],
  );

  /// Collection card highlight (M2.0 collector page).
  static const LinearGradient collection = LinearGradient(
    colors: <Color>[Color(0xFFA0E7FF), Color(0xFFFFD1DC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Reward pill / chest reward gradient.
  static const LinearGradient rewards = LinearGradient(
    colors: <Color>[Color(0xFFFFE16C), Color(0xFFFFA94D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Shop world card gradient.
  static const LinearGradient shop = LinearGradient(
    colors: <Color>[Color(0xFFBFAEFF), Color(0xFFFFB7E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Parents Area tile — soft pastel-calm gradient (mint → sky).
  static const LinearGradient parents = LinearGradient(
    colors: <Color>[Color(0xFFC4F0E5), Color(0xFFE7F0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium CTA — deep purple to indigo to mauve.
  static const LinearGradient premium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      AppColors.rainbowPurple,
      AppColors.rainbowBlue,
      AppColors.primaryPurple,
    ],
  );

  /// M2.4 hotfix — Secondary CTA gradient (e.g. world-detail completion
  /// meter fill). Mirrors the [rewards] gradient family so the design
  /// system stays inside the existing 4-stop catalogue; widget-layer
  /// call sites that predate the M2.3 token consolidation reference
  /// `AppGradients.secondaryCta` directly. Tuned to read as a calmer
  /// alternative to the playNow hot-pink ramp.
  static const LinearGradient secondaryCta = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[AppColors.coinGold, AppColors.tangerine],
    stops: <double>[0.0, 1.0],
  );

  /// M2.4 hotfix — Tertiary calm gradient (e.g. world-detail "See
  /// plans" CTA, drawer-style affirmation tiles). Softer than [premium]
  /// so a kid can read the colour difference between "main action" and
  /// "secondary premium upsell". Pairs with `AppColors.lavender`.
  static const LinearGradient tertiaryCalm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.lavender, AppColors.magicPurple],
    stops: <double>[0.0, 1.0],
  );
}
