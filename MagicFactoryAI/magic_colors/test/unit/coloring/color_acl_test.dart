// =============================================================================
// Magic Colors · test/unit/coloring/color_acl_test.dart
// =============================================================================
//
// M2.3 — Unit tests for the ColorAcl predicate layer. Pure functions,
// no Flutter widget binding required.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/data/palette_catalog.dart';
import 'package:magic_colors/features/coloring/domain/color_acl.dart';

void main() {
  group('ColorAcl.isLocked', () {
    test('returns false for tier-0 (free) palette indexes', () {
      expect(
        ColorAcl.isLocked(
          paletteIndex: 0,
          unlockedIndexes: const <int>[],
        ),
        false,
      );
      expect(
        ColorAcl.isLocked(
          paletteIndex: 23,
          unlockedIndexes: const <int>[],
        ),
        false,
      );
    });

    test('returns true for tier-1 (locked) palette index when not yet unlocked',
        () {
      expect(
        ColorAcl.isLocked(
          paletteIndex: 24,
          unlockedIndexes: const <int>[],
        ),
        true,
      );
    });

    test('returns false when tier-1 palette index is in unlockedIndexes', () {
      expect(
        ColorAcl.isLocked(
          paletteIndex: 24,
          unlockedIndexes: const <int>[24],
        ),
        false,
      );
    });

    test(
        'returns false for tier-2 (premium) palette indexes regardless of '
        'unlocked list (premium is gated by subscription, not by the list)',
        () {
      expect(
        ColorAcl.isLocked(
          paletteIndex: 28,
          unlockedIndexes: const <int>[],
        ),
        false,
      );
      expect(
        ColorAcl.isLocked(
          paletteIndex: 28,
          unlockedIndexes: const <int>[28],
        ),
        false,
      );
    });

    test('out-of-bounds indexes return false', () {
      expect(
        ColorAcl.isLocked(
          paletteIndex: -1,
          unlockedIndexes: const <int>[],
        ),
        false,
      );
      expect(
        ColorAcl.isLocked(
          paletteIndex: PaletteCatalog.colors.length + 10,
          unlockedIndexes: const <int>[],
        ),
        false,
      );
    });
  });

  group('ColorAcl.isPremium', () {
    test('true for tier-2 indexes', () {
      for (int i = 0; i < PaletteCatalog.premiumTierCount; i++) {
        expect(
          ColorAcl.isPremium(PaletteCatalog.premiumTierStartIndex + i),
          true,
          reason: 'premium index ${PaletteCatalog.premiumTierStartIndex + i}',
        );
      }
    });

    test('false for tier-0 and tier-1 indexes', () {
      expect(ColorAcl.isPremium(0), false);
      expect(ColorAcl.isPremium(15), false);
      expect(
        ColorAcl.isPremium(PaletteCatalog.lockedTierStartIndex + 1),
        false,
      );
    });
  });

  group('ColorAcl.resolve', () {
    test(
        'returns tier=locked with unlockCostCoins + unlockCostStars for a '
        'locked tier-1 swatch', () {
      final entry = ColorAcl.resolve(
        paletteIndex: 24,
        unlockedIndexes: const <int>[],
        favoriteIndexes: const <int>[],
      );
      expect(entry.tier, ColorTier.locked);
      expect(entry.unlockCostCoins, PaletteCatalog.unlockCostCoinsFor(24));
      expect(entry.unlockCostStars, PaletteCatalog.unlockCostStarsFor(24));
      expect(entry.isLocked, true);
    });

    test(
        'returns tier=premium for a tier-2 swatch regardless of unlock '
        'grants', () {
      final entry = ColorAcl.resolve(
        paletteIndex: 28,
        unlockedIndexes: const <int>[28],
        favoriteIndexes: const <int>[],
      );
      expect(entry.tier, ColorTier.premium);
      expect(entry.unlockCostCoins, 0);
      expect(entry.unlockCostStars, 0);
      expect(entry.isPremium, true);
    });

    test('returns tier=free once the swatch has been unlocked', () {
      final entry = ColorAcl.resolve(
        paletteIndex: 24,
        unlockedIndexes: const <int>[24],
        favoriteIndexes: const <int>[],
      );
      expect(entry.tier, ColorTier.free);
      expect(entry.isFree, true);
      expect(entry.isLocked, false);
    });
  });

  group('ColorAcl.isFavorite + recencyRank', () {
    test('isFavorite honours the favorite set', () {
      expect(
        ColorAcl.isFavorite(
          paletteIndex: 5,
          favoriteIndexes: const <int>[5, 7],
        ),
        true,
      );
      expect(
        ColorAcl.isFavorite(
          paletteIndex: 9,
          favoriteIndexes: const <int>[5, 7],
        ),
        false,
      );
    });

    test('recencyRank returns front-of-list index OR -1 when missing', () {
      expect(
        ColorAcl.recencyRank(
          paletteIndex: 7,
          recentIndexes: const <int>[7, 3, 1],
        ),
        0,
      );
      expect(
        ColorAcl.recencyRank(
          paletteIndex: 3,
          recentIndexes: const <int>[7, 3, 1],
        ),
        1,
      );
      expect(
        ColorAcl.recencyRank(
          paletteIndex: 9,
          recentIndexes: const <int>[7, 3, 1],
        ),
        -1,
      );
    });
  });
}
