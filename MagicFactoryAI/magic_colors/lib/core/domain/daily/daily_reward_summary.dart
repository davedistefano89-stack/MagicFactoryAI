// =============================================================================
// Magic Colors · lib/core/domain/daily/daily_reward_summary.dart
// =============================================================================
//
// Sprint 7 — composed daily-reward snapshot. Bundles the coin + gem
// grant (from the existing `RewardEngine.computeDailyChestReward`)
// with the optional item row (from the new daily-rewards catalog).
// The service builds this once per claim so the UI + analytics
// can render the full bundle from a single value object.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import 'daily_reward_entry.dart';

@immutable
class DailyRewardSummary {
  const DailyRewardSummary({
    required this.streakDay,
    required this.coins,
    required this.gems,
    required this.item,
  });

  /// The clamped streak day (1..7) the reward maps to.
  final int streakDay;

  /// Coin grant (from RewardEngine).
  final int coins;

  /// Gem grant (from RewardEngine).
  final int gems;

  /// Optional item row (palette / brush / gradient). `null` for
  /// pure-currency reward days.
  final DailyRewardEntry? item;

  /// True iff any channel (coins, gems, item) has a positive
  /// grant. A "Day 1" reward is always truthy.
  bool get hasAnyReward => coins > 0 || gems > 0 || item != null;
}
