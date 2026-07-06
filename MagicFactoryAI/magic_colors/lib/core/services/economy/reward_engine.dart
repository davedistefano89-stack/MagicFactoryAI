// =============================================================================
// Magic Colors · lib/core/services/economy/reward_engine.dart
// =============================================================================
//
// Pure-function reward computation. Lives in `core/services/economy/`
// because it composes the data objects in `core/domain/economy/` but
// has no Flutter dependency and no I/O — testable in isolation.
//
// CONSUMERS
//   • HomeController `onClaimDailyReward` →
//       RewardEngine.computeDailyChestReward(player.streakDays)
//   • ColoringController `_flush()` →
//       RewardEngine.computeDrawingReward(starsEarned, worldId: …)
//
// CURVES (v1.0)
//   Daily chest — flattened for ages 3-8; gems appear by Day 2, never
//   expiring to "infinite farming". Capped at Day 7; Day 8+ reuses the
//   Day-7 reward so a streak beyond a week still feels rewarding but
//   doesn't compound further.
//
//   Drawing completion — banded by star quality (1/2/3). Zero draws
//   earn nothing; the eligibility check (below) decides whether the
//   player has even hit the minimum threshold for a reward.
//
//   Eligibility — more than 2 distinct colors AND total duration > 15
//   seconds. Deliberately does NOT use stroke count: a 4-year-old can
//   scribble a single 600-point path and bypass a stroke count gate,
//   so the gate uses instantaneous quality signals instead.
// =============================================================================

import '../../domain/economy/reward.dart';
import '../../utils/logger.dart' show logger;

/// Pure-function façade for every reward the game can dispense. Marked
/// `abstract final` (sealed-by-construction) so neither tests nor
/// screens extend or mock it — be a free function with the same name.
abstract final class RewardEngine {
  RewardEngine._();

  // ── Daily chest reward curve (1..7) ─────────────────────────────────────
  /// Coin amounts indexed by streak day. Index 0 is unused so the curve
  /// reads `coins[day]` with `day ∈ [1, 7]`.
  static const List<int> _kChestCoins = <int>[
    /* 0 */ 0,
    /* 1 */ 15,
    /* 2 */ 25,
    /* 3 */ 40,
    /* 4 */ 60,
    /* 5 */ 80,
    /* 6 */ 100,
    /* 7 */ 150,
  ];

  /// Gem amounts indexed by streak day. Gems ship with the chest from
  /// Day 1 so young players hit the gem currency on the very first day
  /// — and never wait a week to feel the "magical" currency.
  static const List<int> _kChestGems = <int>[
    /* 0 */ 0,
    /* 1 */ 1,
    /* 2 */ 1,
    /* 3 */ 2,
    /* 4 */ 2,
    /* 5 */ 3,
    /* 6 */ 4,
    /* 7 */ 5,
  ];

  /// Last day of the curve; longer streaks clamp to this so the
  /// rewards never farm beyond the natural cap.
  static const int _kChestCapDay = 7;

  /// Computes the daily chest reward for the supplied streak day.
  /// Throws [ArgumentError] if [streakDays] is non-positive.
  static CompositeReward computeDailyChestReward(int streakDays) {
    if (streakDays < 1) {
      throw ArgumentError.value(
        streakDays,
        'streakDays',
        'streakDays must be ≥ 1; the engine never mints an empty chest',
      );
    }
    final int day = streakDays > _kChestCapDay ? _kChestCapDay : streakDays;
    final int coins = _kChestCoins[day];
    final int gems = _kChestGems[day];
    final String reason = 'daily_chest.day_$day';
    logger.info(
      'RewardEngine.computeDailyChestReward(streak=$streakDays) → '
      'day=$day coins=$coins gems=$gems',
    );
    return CompositeReward(
      reason: reason,
      children: <Reward>[
        if (coins > 0) CoinReward(reason: reason, amount: coins),
        if (gems > 0) GemReward(reason: reason, amount: gems),
      ],
    );
  }

  // ── Drawing completion reward (1 / 2 / 3 stars) ─────────────────────────
  /// Coin amounts indexed by drawing star quality (0..3). Index 0
  /// is intentionally 0 (a 0-star save is not a completion — see the
  /// gating logic in [isCompletionEligible]). Constant list lookup
  /// so we never risk a Dart switch fall-through or unassigned-final
  /// diagnostic on adding a new star tier.
  static const List<int> _kDrawingCoins = <int>[
    /* 0 stars, no completion */ 0,
    /* 1 star */ 5,
    /* 2 stars */ 15,
    /* 3 stars */ 50,
  ];

  /// Gem amounts indexed by drawing star quality. 0 stars ⇒ 0 gems
  /// (no reward for an incomplete drawing). Star 2 unlocks the
  /// first gem so young players feel the "gem" currency early.
  static const List<int> _kDrawingGems = <int>[
    /* 0 stars, no completion */ 0,
    /* 1 star */ 0,
    /* 2 stars */ 1,
    /* 3 stars */ 2,
  ];

  /// Computes the reward for completing a drawing with [starsEarned]
  /// in [worldId]. Throws [ArgumentError] if stars are out of range.
  static CompositeReward computeDrawingReward(
    int starsEarned, {
    required String worldId,
  }) {
    if (starsEarned < 0 || starsEarned > 3) {
      throw ArgumentError.value(
        starsEarned,
        'starsEarned',
        'starsEarned must be in 0..3 inclusive',
      );
    }
    final String reason = 'drawing.completed.$worldId';
    final int coins = _kDrawingCoins[starsEarned];
    final int gems = _kDrawingGems[starsEarned];
    logger.info(
      'RewardEngine.computeDrawingReward(world=$worldId '
      'stars=$starsEarned) → coins=$coins gems=$gems',
    );
    return CompositeReward(
      reason: reason,
      children: <Reward>[
        if (coins > 0) CoinReward(reason: reason, amount: coins),
        if (gems > 0) GemReward(reason: reason, amount: gems),
      ],
    );
  }

  // ── Drawing completion eligibility ──────────────────────────────────────
  /// Minimum duration for a save to qualify as a "real" drawing rather
  /// than a 5-second scribble. Tuned for a 4-year-old demo-through to
  /// not bypass the gate.
  static const Duration _kMinDrawingDuration = Duration(seconds: 15);

  /// Minimum distinct-colour count to qualify. Two colours is not
  /// enough to demonstrate skill; three (a primary, a secondary, a
  /// surprise pick) shows intent.
  static const int _kMinDistinctColors = 2;

  /// True iff a drawing meets the minimum threshold for being
  /// reward-eligible. Stroke count is intentionally NOT a gate: a
  /// child can scribble a single 600-point path and bypass a stroke
  /// count gate.
  static bool isCompletionEligible({
    required int distinctColorCount,
    required Duration duration,
  }) {
    return distinctColorCount > _kMinDistinctColors &&
        duration > _kMinDrawingDuration;
  }

  // ── Star-quality derivation from raw signals ─────────────────────────────
  /// Lower bound for a 3-star (true completion) drawing: at least this
  /// much wall-clock time must elapse to "earn" the third star purely
  /// on patient paint time.
  static const Duration _kThreeStarMinDuration = Duration(minutes: 2);

  /// Lower bound for a 2-star drawing.
  static const Duration _kTwoStarMinDuration = Duration(seconds: 45);

  /// Lower bound for a 1-star drawing (the player's first save).
  static const Duration _kOneStarMinDuration = Duration(seconds: 15);

  /// Maps (duration × distinct-colour-count × stroke-count) to a
  /// 0..3 star rating. Pure function — same input, same star output.
  static int starsFromSignals({
    required Duration duration,
    required int distinctColorCount,
    required int strokeCount,
  }) {
    if (duration < _kOneStarMinDuration || distinctColorCount <= 1) {
      return 0;
    }
    if (duration >= _kThreeStarMinDuration &&
        distinctColorCount >= 6 &&
        strokeCount >= 8) {
      return 3;
    }
    if (duration >= _kTwoStarMinDuration &&
        distinctColorCount >= 4 &&
        strokeCount >= 4) {
      return 2;
    }
    return 1;
  }
}
