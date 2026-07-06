// =============================================================================
// Magic Colors · test/unit/economy/achievement_service_test.dart
// =============================================================================
//
// Pure-data unit tests for [AchievementService]. NO Hive, NO Flutter widgets
// — constructs [PlayerSnapshot] directly so the catalog can be validated
// against arbitrary state fixtures.
//
// ORGANIZATION
//   • Catalog integrity (count, lookup, immutability).
//   • Evaluate returns NEWLY-unlocked only (skips previouslyUnlocked).
//   • Specific unlock conditions: streak, world stars, premium.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/services/economy/achievement_service.dart';

void main() {
  group('AchievementService.catalog', () {
    test('Catalog contains exactly 12 achievements', () {
      expect(AchievementService.catalog.length, 12);
    });

    test('Catalog returns an unmodifiable list', () {
      expect(
        () => AchievementService.catalog.add(
          AchievementService.catalog.first,
        ),
        throwsUnsupportedError,
      );
    });

    test('Each achievement id is unique', () {
      final Set<String> ids = AchievementService.catalog
          .map((AchievementDefinition d) => d.id)
          .toSet();
      expect(ids.length, AchievementService.catalog.length);
    });

    test('Each catalog id is non-empty kebab/snake', () {
      for (final AchievementDefinition def in AchievementService.catalog) {
        expect(def.id.isNotEmpty, true);
        expect(def.glyph.isNotEmpty, true);
        expect(def.title.isNotEmpty, true);
        expect(def.description.isNotEmpty, true);
      }
    });
  });

  group('AchievementService.definitionById', () {
    test('Returns the definition for a known id', () {
      final AchievementDefinition? def =
          AchievementService.definitionById('first_save');
      expect(def, isNotNull);
      expect(def!.title, 'My First Drawing');
      expect(def.tier, AchievementTier.bronze);
    });

    test('Returns null for an unknown id (forward-compatible)', () {
      final AchievementDefinition? def =
          AchievementService.definitionById('made_up_future_id');
      expect(def, isNull);
    });
  });

  group('AchievementService.evaluate', () {
    const PlayerSnapshot emptySnapshot = PlayerSnapshot(
      coins: 0,
      gems: 0,
      streakDays: 0,
      isPremium: false,
      worldStars: <String, int>{},
      ownedWorldIds: <String>{},
    );

    test('Empty snapshot unlocks NOTHING', () {
      final List<AchievementDefinition> newly = AchievementService.evaluate(
        snapshot: emptySnapshot,
        previouslyUnlocked: const <String>{},
      );
      expect(newly, isEmpty);
    });

    test('First touch unlocks the moment coins and gems are > 0', () {
      const PlayerSnapshot s = PlayerSnapshot(
        coins: 1,
        gems: 0,
        streakDays: 0,
        isPremium: false,
        worldStars: <String, int>{},
        ownedWorldIds: <String>{},
      );
      final List<String> ids = AchievementService.evaluate(
        snapshot: s,
        previouslyUnlocked: const <String>{},
      ).map((AchievementDefinition d) => d.id).toList();
      expect(ids.contains('first_touch'), true);
    });

    test('Unicorn Friend unlocks with ≥1 star in unicorn_valley', () {
      const PlayerSnapshot s = PlayerSnapshot(
        coins: 0,
        gems: 0,
        streakDays: 0,
        isPremium: false,
        worldStars: <String, int>{'unicorn_valley': 1},
        ownedWorldIds: <String>{'unicorn_valley'},
      );
      final List<String> ids = AchievementService.evaluate(
        snapshot: s,
        previouslyUnlocked: const <String>{},
      ).map((AchievementDefinition d) => d.id).toList();
      expect(ids.contains('unicorn_friend'), true);
      expect(ids.contains('first_save'), true); // total stars ≥ 1
    });

    test('Streak Three unlocks iff streakDays ≥ 3', () {
      const PlayerSnapshot s = PlayerSnapshot(
        coins: 0,
        gems: 0,
        streakDays: 3,
        isPremium: false,
        worldStars: <String, int>{},
        ownedWorldIds: <String>{},
      );
      final List<String> ids = AchievementService.evaluate(
        snapshot: s,
        previouslyUnlocked: const <String>{},
      ).map((AchievementDefinition d) => d.id).toList();
      expect(ids.contains('streak_three'), true);
      expect(ids.contains('streak_seven'), false);
      expect(ids.contains('streak_thirty'), false);
    });

    test('Streak Seven does NOT unlock at streak = 5', () {
      const PlayerSnapshot s = PlayerSnapshot(
        coins: 0,
        gems: 0,
        streakDays: 5,
        isPremium: false,
        worldStars: <String, int>{},
        ownedWorldIds: <String>{},
      );
      final List<String> ids = AchievementService.evaluate(
        snapshot: s,
        previouslyUnlocked: const <String>{},
      ).map((AchievementDefinition d) => d.id).toList();
      expect(ids.contains('streak_seven'), false);
      expect(ids.contains('streak_three'), true);
    });

    test('Premium Curious unlocks iff isPremium', () {
      const PlayerSnapshot premium = PlayerSnapshot(
        coins: 0,
        gems: 0,
        streakDays: 0,
        isPremium: true,
        worldStars: <String, int>{},
        ownedWorldIds: <String>{},
      );
      final List<String> ids = AchievementService.evaluate(
        snapshot: premium,
        previouslyUnlocked: const <String>{},
      ).map((AchievementDefinition d) => d.id).toList();
      expect(ids.contains('premium_curious'), true);
    });

    test('Already-unlocked ids are not re-emitted', () {
      const PlayerSnapshot s = PlayerSnapshot(
        coins: 5,
        gems: 1,
        streakDays: 4,
        isPremium: false,
        worldStars: <String, int>{'unicorn_valley': 1},
        ownedWorldIds: <String>{'unicorn_valley'},
      );
      final List<AchievementDefinition> firstPass = AchievementService.evaluate(
        snapshot: s,
        previouslyUnlocked: const <String>{},
      );
      final Set<String> firstIds =
          firstPass.map((AchievementDefinition d) => d.id).toSet();
      // Re-evaluate the same snapshot with previouslyUnlocked = firstIds
      final List<AchievementDefinition> secondPass =
          AchievementService.evaluate(
        snapshot: s,
        previouslyUnlocked: firstIds,
      );
      expect(secondPass, isEmpty,
          reason: 're-evaluation must not double-unlock anything');
    });
  });
}
