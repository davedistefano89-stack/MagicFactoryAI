// =============================================================================
// Magic Colors · test/unit/economy/reward_engine_test.dart
// =============================================================================
//
// Pure-function unit tests for [RewardEngine]. NO Hive, NO Flutter widgets
// — runs in `flutter test` (which extends `package:test/test.dart`) so
// the assertions align with the standard Flutter test harness.
//
// ORGANIZATION
//   • Daily chest curve (1..7, capped at 7).
//   • Drawing reward thresholds (stars 0..3 + boundary errors).
//   • Eligibility gate (duration × distinct-colour count, no stroke count).
//   • Star-quality derivation (mid/long/borderline cases).
//
// INVARIANTS BEING VERIFIED
//   • Streak below 1 never produces a chest.
//   • Day 7 == Day 8+ == Day 99 (cap).
//   • Stars out of range throws, never silently rounds.
//   • Zero-duration or below-eligible-color drawings never earn a reward.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/domain/economy/reward.dart';
import 'package:magic_colors/core/services/economy/reward_engine.dart';

void main() {
  group('RewardEngine.computeDailyChestReward', () {
    test('throws ArgumentError when streakDays < 1', () {
      expect(
        () => RewardEngine.computeDailyChestReward(0),
        throwsArgumentError,
      );
      expect(
        () => RewardEngine.computeDailyChestReward(-3),
        throwsArgumentError,
      );
    });

    test('Day 1 yields 15 coins + 1 gem', () {
      final CompositeReward reward = RewardEngine.computeDailyChestReward(1);
      final int coins = reward.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      final int gems = reward.children
          .whereType<GemReward>()
          .fold<int>(0, (int a, GemReward b) => a + b.amount);
      expect(coins, 15);
      expect(gems, 1);
      expect(reward.reason, 'daily_chest.day_1');
    });

    test('Day 5 yields 80 coins + 3 gems', () {
      final CompositeReward reward = RewardEngine.computeDailyChestReward(5);
      final int coins = reward.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      final int gems = reward.children
          .whereType<GemReward>()
          .fold<int>(0, (int a, GemReward b) => a + b.amount);
      expect(coins, 80);
      expect(gems, 3);
    });

    test('Day 7 yields 150 coins + 5 gems (the cap reward)', () {
      final CompositeReward reward = RewardEngine.computeDailyChestReward(7);
      final int coins = reward.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      final int gems = reward.children
          .whereType<GemReward>()
          .fold<int>(0, (int a, GemReward b) => a + b.amount);
      expect(coins, 150);
      expect(gems, 5);
    });

    test('Day 99 caps to the Day 7 reward', () {
      final CompositeReward longStreak =
          RewardEngine.computeDailyChestReward(99);
      final CompositeReward day7 = RewardEngine.computeDailyChestReward(7);
      final int longCoins = longStreak.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      final int day7Coins = day7.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      expect(longCoins, day7Coins);
    });

    test('Empty CompositeReward.isEmpty is true when no children', () {
      const CompositeReward empty = CompositeReward(
        reason: 'noop',
        children: <Reward>[],
      );
      expect(empty.isEmpty, true);
    });
  });

  group('RewardEngine.computeDrawingReward', () {
    test('throws on stars < 0', () {
      expect(
        () => RewardEngine.computeDrawingReward(
          -1,
          worldId: 'unicorn_valley',
        ),
        throwsArgumentError,
      );
    });

    test('throws on stars > 3', () {
      expect(
        () => RewardEngine.computeDrawingReward(
          4,
          worldId: 'unicorn_valley',
        ),
        throwsArgumentError,
      );
    });

    test('Stars 0 yields an empty composite (eligibility did not pass)', () {
      final CompositeReward reward = RewardEngine.computeDrawingReward(
        0,
        worldId: 'unicorn_valley',
      );
      expect(reward.isEmpty, true);
    });

    test('Stars 1 yields 5 coins and no gems', () {
      final CompositeReward reward = RewardEngine.computeDrawingReward(
        1,
        worldId: 'unicorn_valley',
      );
      final int coins = reward.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      final int gems = reward.children
          .whereType<GemReward>()
          .fold<int>(0, (int a, GemReward b) => a + b.amount);
      expect(coins, 5);
      expect(gems, 0);
    });

    test('Stars 2 yields 15 coins + 1 gem', () {
      final CompositeReward reward = RewardEngine.computeDrawingReward(
        2,
        worldId: 'unicorn_valley',
      );
      final int coins = reward.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      final int gems = reward.children
          .whereType<GemReward>()
          .fold<int>(0, (int a, GemReward b) => a + b.amount);
      expect(coins, 15);
      expect(gems, 1);
    });

    test('Stars 3 yields 50 coins + 2 gems', () {
      final CompositeReward reward = RewardEngine.computeDrawingReward(
        3,
        worldId: 'unicorn_valley',
      );
      final int coins = reward.children
          .whereType<CoinReward>()
          .fold<int>(0, (int a, CoinReward b) => a + b.amount);
      final int gems = reward.children
          .whereType<GemReward>()
          .fold<int>(0, (int a, GemReward b) => a + b.amount);
      expect(coins, 50);
      expect(gems, 2);
    });

    test('Reason is world-scoped for analytics', () {
      final CompositeReward reward = RewardEngine.computeDrawingReward(
        2,
        worldId: 'animal_forest',
      );
      expect(reward.reason, 'drawing.completed.animal_forest');
    });
  });

  group('RewardEngine.isCompletionEligible', () {
    test('Reject when distinctColorCount is at most 2', () {
      expect(
        RewardEngine.isCompletionEligible(
          distinctColorCount: 2,
          duration: const Duration(seconds: 30),
        ),
        false,
      );
    });

    test('Reject when duration is at most 15 seconds', () {
      expect(
        RewardEngine.isCompletionEligible(
          distinctColorCount: 5,
          duration: const Duration(seconds: 15),
        ),
        false,
      );
    });

    test('Accept when both gates pass', () {
      expect(
        RewardEngine.isCompletionEligible(
          distinctColorCount: 3,
          duration: const Duration(seconds: 16),
        ),
        true,
      );
    });

    test('Reject single-colour drawings even after 5 minutes', () {
      expect(
        RewardEngine.isCompletionEligible(
          distinctColorCount: 1,
          duration: const Duration(minutes: 5),
        ),
        false,
      );
    });
  });

  group('RewardEngine.starsFromSignals', () {
    test('Returns 0 stars for sub-gate duration', () {
      final int stars = RewardEngine.starsFromSignals(
        duration: const Duration(seconds: 5),
        distinctColorCount: 8,
        strokeCount: 12,
      );
      expect(stars, 0);
    });

    test('Returns 0 stars when distinct-colour count is 1', () {
      final int stars = RewardEngine.starsFromSignals(
        duration: const Duration(seconds: 60),
        distinctColorCount: 1,
        strokeCount: 5,
      );
      expect(stars, 0);
    });

    test('Returns 1 star for borderline paint', () {
      final int stars = RewardEngine.starsFromSignals(
        duration: const Duration(seconds: 30),
        distinctColorCount: 3,
        strokeCount: 2,
      );
      expect(stars, 1);
    });

    test('Returns 3 stars for the genuine-completion signal', () {
      final int stars = RewardEngine.starsFromSignals(
        duration: const Duration(minutes: 3),
        distinctColorCount: 8,
        strokeCount: 12,
      );
      expect(stars, 3);
    });
  });
}
