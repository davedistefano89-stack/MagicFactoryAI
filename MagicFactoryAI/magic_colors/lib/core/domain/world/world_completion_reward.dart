// =============================================================================
// Magic Colors · lib/core/domain/world/world_completion_reward.dart
// =============================================================================
//
// Sprint 6 — value object describing what a player earns when they
// finish a world. The catalog assigns one `WorldCompletionReward`
// per world; `CompletionRewardService.grantCompletion` applies it
// through the existing PlayerState mutators + AchievementService.
//
// Immutable so the model can be cached and shared across rebuilds
// without defensive copies. The catalog (a const List) is the
// canonical source of truth.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

/// Catalog row describing what the player earns when they fully
/// complete a world (i.e. earned all 3 stars in it).
@immutable
class WorldCompletionReward {
  const WorldCompletionReward({
    required this.worldId,
    required this.coins,
    required this.gems,
    this.achievementId,
    this.unlocksNextWorldId,
  });

  /// Catalog id of the world this reward belongs to. Keyed by
  /// `WorldData.id` so the service can do a Map lookup.
  final String worldId;

  /// Coin grant on completion. Zero is a no-op (no confusing
  /// "+0" tip) — see the mutator policy in
  /// `core/domain/economy/reward.dart`.
  final int coins;

  /// Gem grant on completion. Same no-zero-tip policy as [coins].
  final int gems;

  /// Optional achievement id. When non-null,
  /// `CompletionRewardService.grantCompletion` will additionally
  /// call `PlayerState.unlockAchievement(this.achievementId)` after
  /// granting the coins/gems. Idempotent — re-claims are no-ops.
  final String? achievementId;

  /// Optional next-world id. When non-null, the completion
  /// service will additionally call
  /// `PlayerState.unlockWorld(this.unlocksNextWorldId)` so the
  /// player auto-unlocks the next world on completion. The default
  /// free-world chain (unicorn → animal → dinosaur → dragon →
  /// mermaid → space) is wired here.
  final String? unlocksNextWorldId;

  /// True iff any of the reward channels (coins, gems, achievement,
  /// next-world) is defined. A no-op reward (all defaults) is
  /// silently dropped at the service layer.
  bool get hasAnyReward =>
      coins > 0 || gems > 0 || achievementId != null || unlocksNextWorldId != null;
}
