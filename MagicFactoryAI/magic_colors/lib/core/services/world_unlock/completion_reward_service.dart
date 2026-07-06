// =============================================================================
// Magic Colors · core/services/world_unlock/completion_reward_service.dart
// =============================================================================
//
// Sprint 6 — awards the completion reward for a world. Single owner
// of the auto-unlock + achievement hook so the UI never composes
// these side effects inline.
//
// PIPELINE
//   1. Idempotency check — refused if the world is already in
//      PlayerState.claimedWorldRewardIds.
//   2. Apply the coins + gems via PlayerState mutators.
//   3. Optionally auto-unlock the next world (catalog row's
//      `unlocksNextWorldId`).
//   4. Mark the world as claimed in PlayerState so the next call
//      is a no-op.
//   5. Optionally unlock the achievement (catalog row's
//      `achievementId`).
//
// The "mark as claimed" call happens BEFORE the achievement
// unlock so an exception in the achievement path still leaves the
// reward applied. The idempotency invariant ("you can't claim
// twice") is the more important guarantee.
// =============================================================================

import '../../../core/domain/world/world_completion_reward.dart';
import '../../state/player_state.dart';
import '../../../features/worlds/data/world_progress_catalog.dart';

/// Outcome of a single [CompletionRewardService.grantCompletion]
/// call. Mirrors the [UnlockResult] enum from Sprint 5 so the UI
/// can branch on the same shape.
enum CompletionRewardResult {
  /// Reward was applied (coins/gems + maybe next world + maybe
  /// achievement). Caller shows the celebration animation.
  granted,

  /// The reward was already claimed in a previous session; the
  /// service refused to grant it again. Quiet no-op.
  alreadyClaimed,

  /// The world has no completion reward defined in the catalog.
  /// The UI should not have called this for a world with no
  /// reward; this branch exists as a defensive guard.
  noRewardDefined,
}

abstract final class CompletionRewardService {
  CompletionRewardService._();

  /// Awards the completion reward for [worldId] to [player].
  /// Idempotent — a second call for the same world returns
  /// [CompletionRewardResult.alreadyClaimed] without mutating.
  static CompletionRewardResult grantCompletion({
    required String worldId,
    required PlayerState player,
  }) {
    final WorldCompletionReward? reward = rewardFor(worldId);
    if (reward == null) {
      return CompletionRewardResult.noRewardDefined;
    }
    if (player.claimedWorldRewardIds.contains(worldId)) {
      return CompletionRewardResult.alreadyClaimed;
    }
    _grantTo(reward, player);
    return CompletionRewardResult.granted;
  }

  /// True iff [worldId]'s completion reward has already been
  /// claimed. Convenience predicate so the UI can swap the
  /// "Claim" CTA for a "Claimed" badge without re-walking the
  /// set.
  static bool isClaimed(PlayerState player, String worldId) {
    return player.claimedWorldRewardIds.contains(worldId);
  }

  /// True iff [worldId] has a completion reward defined in the
  /// catalog. Mirrors `rewardFor(worldId) != null`.
  static bool hasReward(String worldId) => rewardFor(worldId) != null;

  // ── Internals ──────────────────────────────────────────────────────────

  static void _grantTo(
    WorldCompletionReward reward,
    PlayerState player,
  ) {
    // 1. Coins + gems → existing PlayerState mutators.
    if (reward.coins > 0) {
      player.grantCoins(
        reward.coins,
        reason: 'world_completion.${reward.worldId}',
      );
    }
    if (reward.gems > 0) {
      player.grantGems(
        reward.gems,
        reason: 'world_completion.${reward.worldId}',
      );
    }

    // 2. Auto-unlock the next world (if defined in the catalog).
    final String? nextId = reward.unlocksNextWorldId;
    if (nextId != null && !player.ownedWorldIds.contains(nextId)) {
      player.unlockWorld(nextId);
    }

    // 3. Mark as claimed BEFORE the achievement call so an
    // exception in the achievement path still leaves the reward
    // applied. The idempotency invariant ("you can't claim twice")
    // is the more important guarantee here.
    player.claimWorldCompletionReward(reward.worldId);

    // 4. Optional achievement hook.
    final String? achievementId = reward.achievementId;
    if (achievementId != null) {
      player.unlockAchievement(
        achievementId,
        reason: 'world_completion.${reward.worldId}',
      );
    }
  }
}
