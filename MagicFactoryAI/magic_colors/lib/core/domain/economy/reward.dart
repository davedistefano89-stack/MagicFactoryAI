// =============================================================================
// Magic Colors · lib/core/domain/economy/reward.dart
// =============================================================================
//
// Sealed-class hierarchy for every reward the game can dispense. Living in
// `core/domain/economy/` so the type is reachable from BOTH the engine that
// *computes* rewards (`reward_engine.dart`) AND the surfaces that *render*
// them (reward popup, achievements grid). Dart 3 sealed-class pattern
// matching lets callers exhaustively branch without a `default:` arm; the
// compiler enforces exhaustive coverage on every change.
//
// MUTATION POLICY
//   Each leaf type has a `grantTo(PlayerState)` that delegates to the
//   matching `grantCoins` / `grantGems` / `grantWorldStars` mutator. The
//   PlayerState mutators are themselves idempotent and persistence-aware,
//   so the Reward tree stays declarative: "what to grant" rather than
//   "how to grant".
//
// DESIGN RATIONALE
//   • Why a sealed class instead of `class Reward { int coins; int gems; }`?
//     Lets the UI render *different* celebration animations per leaf
//     (CoinReward → coin rain; GemReward → gem sparkle; StarReward →
//     star-meter refill) without ever inspecting optional null fields.
//   • Why a `CompositeReward` instead of `Reward + List<Reward> children`?
//     Lets the daily chest emit `[CoinReward, GemReward]` and the
//     achievements screen traverse it to format a "12 coins + 3 gems"
//     line from a single tree walk instead of two parallel lists.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import '../../state/player_state.dart';

/// Sealed base type for every reward the Engine can dispense. The
/// `reason` string is a stable analytics-friendly identifier (e.g.
/// `"daily_chest.day_3"`, `"drawing.completed.unicorn_valley"`).
///
/// Subclasses MUST be `immutable`; never expose setters.
@immutable
sealed class Reward {
  const Reward({required this.reason});

  /// Stable identifier rooted in the event-bus taxonomy.
  ///    `event.daily_chest.*`, `event.drawing.*`, `event.achievement.*`.
  final String reason;

  /// Applies this reward to [player]. Idempotent against zero values —
  /// a `CoinReward(0)` is a no-op rather than an error.
  void grantTo(PlayerState player);
}

/// Awards coins. Pure data — doesn't compute or transform amounts.
@immutable
class CoinReward extends Reward {
  const CoinReward({required super.reason, required this.amount});

  final int amount;

  @override
  void grantTo(PlayerState player) {
    if (amount > 0) {
      player.grantCoins(amount, reason: reason);
    }
  }
}

/// Awards gems. Pure data — doesn't compute or transform amounts.
@immutable
class GemReward extends Reward {
  const GemReward({required super.reason, required this.amount});

  final int amount;

  @override
  void grantTo(PlayerState player) {
    if (amount > 0) {
      player.grantGems(amount, reason: reason);
    }
  }
}

/// Awards stars to a specific world. Stars are the quality metric per
/// drawing (0..3) and the unlock currency across worlds.
@immutable
class StarReward extends Reward {
  const StarReward({
    required super.reason,
    required this.worldId,
    required this.amount,
  });

  final String worldId;
  final int amount;

  @override
  void grantTo(PlayerState player) {
    if (amount > 0) {
      player.grantWorldStars(worldId, amount, reason: reason);
    }
  }
}

/// Combines several rewards into a single atomic grant. The children are
/// applied in order; an exception in any child (e.g. disk write failure)
/// does NOT roll back earlier children — gameplay events are
/// idempotent at the PlayerState level so a partial grant is recoverable.
@immutable
class CompositeReward extends Reward {
  const CompositeReward({
    required super.reason,
    required this.children,
  });

  final List<Reward> children;

  @override
  void grantTo(PlayerState player) {
    for (final Reward reward in children) {
      reward.grantTo(player);
    }
  }

  /// True iff [children] is empty. Useful for no-op tests where the
  /// engine can return an empty composite cheaply instead of throwing.
  bool get isEmpty => children.isEmpty;
}

// ============================================================================
//  M2.4 — RewardTotalDelta extensions.
//
//  [ColoringController._evaluateRewardEligibility] needs to snapshot the
//  awarded coin + gem totals so the [DrawingCompleteOverlay] can render
//  the reward pill row without re-walking the tree. These extensions walk
//  the sealed reward tree (composite nodes included) and sum amounts by
//  type. Star rewards contribute 0 coins + 0 gems so they are ignored.
// ============================================================================

extension RewardTotalDelta on Reward {
  /// Total coin amount across the entire reward tree. Reads [amount]
  /// on every [CoinReward] encountered; recursive on [CompositeReward].
  int get totalCoinDelta {
    final Reward self = this;
    if (self is CoinReward) return self.amount;
    if (self is GemReward) return 0;
    if (self is StarReward) return 0;
    if (self is CompositeReward) {
      int sum = 0;
      for (final Reward child in self.children) {
        sum += child.totalCoinDelta;
      }
      return sum;
    }
    return 0;
  }

  /// Total gem amount across the entire reward tree. Mirrors
  /// [totalCoinDelta]'s shape; recursive over composite nodes.
  int get totalGemDelta {
    final Reward self = this;
    if (self is CoinReward) return 0;
    if (self is GemReward) return self.amount;
    if (self is StarReward) return 0;
    if (self is CompositeReward) {
      int sum = 0;
      for (final Reward child in self.children) {
        sum += child.totalGemDelta;
      }
      return sum;
    }
    return 0;
  }
}
