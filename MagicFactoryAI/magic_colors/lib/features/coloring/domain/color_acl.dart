// =============================================================================
// Magic Colors · features/coloring/domain/color_acl.dart
// =============================================================================
//
// M2.3 — Pure palette-ACL predicates. Stays dependency-free (no Flutter
// imports beyond Color, no Hive) so unit tests can exercise every
// branch without binding a WidgetsFlutter binding.
//
// PALETTE ACCESS TIERS
// --------------------
//   • ColorTier.free    — every drawing surfaces these without limits.
//                         Currently maps to PaletteCatalog.colors[0..23].
//   • ColorTier.locked  — ships locked; unlocks via coins OR stars.
//                         `unlockCostCoins` + `unlockCostStars` are
//                         defined in [PaletteCatalog.colorMetaAt] so the
//                         UI can render the "spend 100 coins or 3 stars"
//                         affordance from one source of truth.
//   • ColorTier.premium — requires player.isPremium. Listed in [
//                         PaletteCatalog.premiumIndexes].
//
// HYBRID PRICING RULES
//   The user picked "Coins OR stars" — any of the two unlocks the
//   colour. The UI's "Unlock" affordance mutates PlayerState via
//   [PlayerState.spendCoinsForColor] OR [PlayerState.spendWorldStarsForColor].
//   Either mutator adds the colour's index to
//   `unlockedColorIds` and persists.
// =============================================================================

import 'package:flutter/painting.dart' show Color;

import '../data/palette_catalog.dart';

/// Tier classification for a palette colour. Drives the UI overlay
/// (lock, premium crown) and decides which affordance fires on tap.
enum ColorTier { free, locked, premium }

/// One ACL read-result. Combines a tier classification with the costs
/// the player must pay to lift the lock (locked tier only).
final class ColorAclEntry {
  const ColorAclEntry({
    required this.index,
    required this.color,
    required this.tier,
    required this.unlockCostCoins,
    required this.unlockCostStars,
  });

  /// Position in `PaletteCatalog.colors`. Used as the stable identity
  /// for recent/favorite/unlock persistence (palette is append-only).
  final int index;

  /// The actual ARGB colour. Convenience accessor for the painter.
  final Color color;

  /// Tier classification.
  final ColorTier tier;

  /// Coin cost to unlock (tier=locked only). Defaults 0 for free/premium.
  final int unlockCostCoins;

  /// Star cost to unlock (tier=locked only). Defaults 0 for free/premium.
  final int unlockCostStars;

  bool get isLocked => tier == ColorTier.locked;
  bool get isPremium => tier == ColorTier.premium;
  bool get isFree => tier == ColorTier.free;
}

abstract final class ColorAcl {
  const ColorAcl._();

  /// True iff [paletteIndex] is in the locked range AND not yet unlocked.
  static bool isLocked({
    required int paletteIndex,
    required Iterable<int> unlockedIndexes,
  }) {
    if (paletteIndex < 0 || paletteIndex >= PaletteCatalog.colors.length) {
      return false;
    }
    if (!PaletteCatalog.isLockedIndex(paletteIndex)) {
      return false;
    }
    return !unlockedIndexes.contains(paletteIndex);
  }

  /// True iff the player has unlocked [paletteIndex] via coins or stars.
  /// Always true for free colours; always false for premium colours
  /// (premium colours cannot be unlocked — they require subscription).
  static bool isUnlocked({
    required int paletteIndex,
    required Iterable<int> unlockedIndexes,
  }) {
    if (paletteIndex < 0 || paletteIndex >= PaletteCatalog.colors.length) {
      return false;
    }
    if (PaletteCatalog.isPremiumIndex(paletteIndex)) {
      return false; // premium ≠ unlocked; never returns true here.
    }
    if (!PaletteCatalog.isLockedIndex(paletteIndex)) {
      return true; // free tier — always unlocked.
    }
    return unlockedIndexes.contains(paletteIndex);
  }

  /// True iff [paletteIndex] is tier-2 (premium requires subscription).
  static bool isPremium(int paletteIndex) =>
      PaletteCatalog.isPremiumIndex(paletteIndex);

  /// True iff the player has favourited [paletteIndex].
  static bool isFavorite({
    required int paletteIndex,
    required Iterable<int> favoriteIndexes,
  }) =>
      favoriteIndexes.contains(paletteIndex);

  /// True iff the colour is part of the player's recent MRU.
  /// Strict values include MRU-position; -1 means "not present".
  static int recencyRank({
    required int paletteIndex,
    required List<int> recentIndexes,
  }) =>
      recentIndexes.indexOf(paletteIndex);

  /// Combines every accessor into a single resolve call. UI code
  /// reads from this rather than calling each predicate separately
  /// (saves 5 list scans per frame during swatch rebuilds).
  static ColorAclEntry resolve({
    required int paletteIndex,
    required Iterable<int> unlockedIndexes,
    required Iterable<int> favoriteIndexes,
  }) {
    final Color color = PaletteCatalog.colorAt(paletteIndex);
    if (PaletteCatalog.isPremiumIndex(paletteIndex)) {
      return ColorAclEntry(
        index: paletteIndex,
        color: color,
        tier: ColorTier.premium,
        unlockCostCoins: 0,
        unlockCostStars: 0,
      );
    }
    if (PaletteCatalog.isLockedIndex(paletteIndex) &&
        !unlockedIndexes.contains(paletteIndex)) {
      return ColorAclEntry(
        index: paletteIndex,
        color: color,
        tier: ColorTier.locked,
        unlockCostCoins: PaletteCatalog.unlockCostCoinsFor(paletteIndex),
        unlockCostStars: PaletteCatalog.unlockCostStarsFor(paletteIndex),
      );
    }
    return ColorAclEntry(
      index: paletteIndex,
      color: color,
      tier: ColorTier.free,
      unlockCostCoins: 0,
      unlockCostStars: 0,
    );
  }
}
