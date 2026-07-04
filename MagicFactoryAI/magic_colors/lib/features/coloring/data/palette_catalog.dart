// =============================================================================
// Magic Colors · features/coloring/data/palette_catalog.dart
// =============================================================================
//
// Static palette of 24 kid-friendly paint colors (tier 0), plus M2.3
// adds 4 tier-1 (locked — pay coins or world stars) and 4 tier-2
// (premium — pay subscription). Total 32 entries.
//
// PALETTE REVISION POLICY
// -----------------------
// Anything that adds/removes/reorders the list MUST bump
// [_kPaletteRevision]. Drawings whose stored `paletteRevision`
// doesn't match the live value gracefully fall back to defaults at
// load-time.
//
// M2.3 TIER LAYOUT
// ----------------
//   [0..23] — tier 0 (free). Unchanged from M0.
//   [24..27] — tier 1 (locked).   id <<safe id>>.
//   [28..31] — tier 2 (premium).  id <<safe id>>.
//
// HYBRID UNLOCK PRICING
//   The user chose "coins OR stars". Each locked swatch has both a
//   coin price and a star price exposed through [unlockCostCoinsFor]
//   + [unlockCostStarsFor]. The UI shows both and routes via the
//   matching PlayerState mutator.
// =============================================================================


import 'package:flutter/painting.dart' show Color;

import 'package:magic_colors/core/theme/app_colors.dart';


/// Current palette revision. Bump any time [_kPalette] is mutated.
/// M2.3 bumps 1 → 2 (new tier-1 + tier-2 entries + Pencil brush enum).
const int _kPaletteRevision = 2;


/// Public read surface for the palette catalog.
abstract final class PaletteCatalog {
  const PaletteCatalog._();

  /// Live palette revision. Embedded into every freshly-created
  /// [Drawing] so older drawings know to migrate.
  static int get revision => _kPaletteRevision;

  /// The full 32-colour palette, ordered for the swatch UI.
  ///
  /// Layout: 8 rows × 4 columns. The first row is the "warm" tones
  /// (red/orange/yellow/pink) — those map to the most-used finger paints.
  static const List<Color> colors = _kPalette;

  /// Number of swatch columns rendered by [ColorSwatchGrid].
  static const int columns = 4;

  /// Default size of each swatch button in dp.
  static const double swatchSize = 44.0;

  /// Default brush size in logical pixels (matches a 6-year-old's marker).
  static const double defaultBrushSize = 18.0;

  /// Default brush type for new strokes.
  static const int defaultBrushTypeIndex = 0; // BrushType.round

  /// Index of the swatch that is preselected on a fresh canvas.
  /// M2.3 keeps the M0 default (vibrant magenta, tier 0).
  static const int defaultSelectedColorIndex = 8;

  /// Index where tier-1 (locked) entries begin. Half-open: [24..28).
  static const int lockedTierStartIndex = 24;

  /// Total count of tier-1 entries.
  static const int lockedTierCount = 4;

  /// Index where tier-2 (premium) entries begin. Half-open: [28..32).
  static const int premiumTierStartIndex = 28;

  /// Total count of tier-2 entries.
  static const int premiumTierCount = 4;

  /// Returns the integer ARGB of the swatch at [index], or black if
  /// out-of-bounds. Safe to call from painters.
  static int colorValueAt(int index) {
    if (index < 0 || index >= colors.length) {
      return 0xFF000000;
    }
    return colors[index].value;
  }

  /// Bounds-checked [Color] accessor. Tests use this to avoid
  /// hard-coded index assumptions.
  static Color colorAt(int index) {
    if (index < 0 || index >= colors.length) {
      return const Color(0xFF000000);
    }
    return colors[index];
  }

  /// True iff [index] is in the tier-1 (locked) range.
  static bool isLockedIndex(int index) =>
      index >= lockedTierStartIndex &&
      index < lockedTierStartIndex + lockedTierCount;

  /// True iff [index] is in the tier-2 (premium) range.
  static bool isPremiumIndex(int index) =>
      index >= premiumTierStartIndex &&
      index < premiumTierStartIndex + premiumTierCount;

  /// Returns the coin cost to unlock [index]. Returns 0 for free /
  /// premium entries so callers can use the value unconditionally.
  static int unlockCostCoinsFor(int index) {
    if (!isLockedIndex(index)) return 0;
    const List<int> _kCoins = <int>[100, 150, 200, 250];
    return _kCoins[index - lockedTierStartIndex];
  }

  /// Returns the star cost to unlock [index]. Returns 0 for free /
  /// premium entries so callers can use the value unconditionally.
  static int unlockCostStarsFor(int index) {
    if (!isLockedIndex(index)) return 0;
    const List<int> _kStars = <int>[1, 2, 3, 5];
    return _kStars[index - lockedTierStartIndex];
  }
}


// =============================================================================
//  Catalog — 32 colors.
// =============================================================================
//
// Layout note: ordering is append-only. NEVER insert a new colour
// between existing entries. Add at the END and bump [_kPaletteRevision]
// ONLY if the visual experience for an existing drawing would change.
// =============================================================================

const List<Color> _kPalette = <Color>[
  // ── Tier 0 — warm reds / pinks (indices 0..3) ─────────────────────
  Color(0xFFE74C3C), // sunset red
  Color(0xFFFF6B6B), // coral
  Color(0xFFFF8FAB), // bubblegum pink
  Color(0xFFFFB6E1), // pastel pink (AppColors.bubblegum)

  // ── Tier 0 — oranges / yellows (indices 4..7) ─────────────────────
  Color(0xFFFF7F5C), // tangerine (AppColors.tangerine)
  Color(0xFFFFD147), // gold (AppColors.coinGold)
  Color(0xFFFFC93C), // sunshine yellow (AppColors.sunshineYellow)
  Color(0xFFFFE082), // pastel yellow

  // ── Tier 0 — greens (indices 8..11) ──────────────────────────────
  Color(0xFF7AE3C0), // mint leaf (AppColors.mintLeaf)
  Color(0xFF3DD68C), // success green (AppColors.success)
  Color(0xFF4ECDC4), // lagoon (AppColors.lagoon)
  Color(0xFF95D5B2), // pastel mint

  // ── Tier 0 — blues (indices 12..15) ──────────────────────────────
  Color(0xFF3FC9FF), // sky cyan (AppColors.skyCyan)
  Color(0xFF5BB8FF), // info blue (AppColors.info)
  Color(0xFF3D7BFF), // gem royal blue (AppColors.gemRoyal)
  Color(0xFFA8DADC), // pastel cyan

  // ── Tier 0 — purples (indices 16..19) ────────────────────────────
  Color(0xFFA88BFF), // cosmic purple (AppColors.cosmicPurple)
  Color(0xFF7A55D9), // magic purple (AppColors.magicPurple)
  Color(0xFFC4B0FF), // lavender (AppColors.lavender)
  Color(0xFFD0BFFF), // pastel lilac

  // ── Tier 0 — neutrals (indices 20..23) ───────────────────────────
  Color(0xFF0F1226), // deep ink (AppColors.deepInk)
  Color(0xFF6B6E80), // smoke (AppColors.smoke)
  Color(0xFFFAFBFF), // sky-touched white (AppColors.skyTouchedWhite)
  Color(0x00000000), // eraser — Color(0) alpha

  // ── Tier 1 — locked (coins OR stars). Indices 24..27. ───────────
  Color(0xFFFF9F1C), // persimmon orange
  Color(0xFFB967FF), // grape violet
  Color(0xFF11C4B7), // pacific teal
  Color(0xFFEE4266), // hibiscus red

  // ── Tier 2 — premium (subscription required). Indices 28..31. ────
  Color(0xFFFFD96B), // star gold (AppColors.starGold)
  Color(0xFFB6FFA1), // dragonfruit green
  Color(0xFFFFAC81), // peach coral
  Color(0xFF8C8CFF), // periwinkle
];

// Keep app_colors import live for tree-shake eligibility checks.
// (Some build pipelines flag unused-strict-import warnings otherwise.)
// ignore: unused_element
const Color _kAnchorAppColors = AppColors.magicPink;
