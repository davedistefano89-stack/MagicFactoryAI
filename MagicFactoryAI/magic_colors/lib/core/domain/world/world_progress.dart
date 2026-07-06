// =============================================================================
// Magic Colors · lib/core/domain/world/world_progress.dart
// =============================================================================
//
// Sprint 6 — per-world derived state model. Bundles the lifetime
// progression snapshot for one world (completion %, stars, current
// status, reward availability) so the UI can render a "progress
// section" without re-walking PlayerState.
//
// The data is composed in [WorldUnlockService.computeProgress] by
// pulling from `PlayerState.worldStars`, `PlayerState.ownedWorldIds`,
// `PlayerState.celebratedWorldIds`, and `PlayerState.claimedWorldRewardIds`.
// All fields are immutable so the model is safe to memoize per build.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import 'world_status.dart';

/// Per-world progression snapshot. Pure data — no Flutter imports.
@immutable
class WorldProgress {
  const WorldProgress({
    required this.worldId,
    required this.totalLevels,
    required this.completedLevels,
    required this.earnedStars,
    required this.completionPct,
    required this.status,
    required this.isCelebrated,
    required this.isRewardClaimed,
    required this.rewardCoins,
    required this.rewardGems,
    required this.nextWorldId,
    required this.achievementId,
  });

  /// Catalog id (kebab/snake) the catalog assigns.
  final String worldId;

  /// Total levels in the world. Sprint 6 derives this from the
  /// [WorldProgressCatalog] (constant 3 per world). Stored on the
  /// model so the UI doesn't need to import the catalog separately.
  final int totalLevels;

  /// Completed levels for this world. Currently derived from
  /// `PlayerState.worldStars[worldId]` so the model is a pure
  /// projection of persistent state.
  final int completedLevels;

  /// Earned stars for this world (0..3 clamped at PlayerState level).
  final int earnedStars;

  /// Completion percentage on a 0..100 scale. Computed off
  /// `completedLevels / totalLevels` — at max stars (== max levels)
  /// this is 100.
  final int completionPct;

  /// Lifecycle status (locked / available / current / completed).
  final WorldStatus status;

  /// True once the player has dismissed the FirstUnlockDialog for
  /// this world. The World Map uses this to drop the "NEW" badge.
  final bool isCelebrated;

  /// True once the player has tapped the "Claim reward" button.
  /// CompletionRewardService is idempotent on this flag.
  final bool isRewardClaimed;

  /// Reward coin amount on completion (from the catalog). Zero when
  /// the world has no defined reward.
  final int rewardCoins;

  /// Reward gem amount on completion (from the catalog). Zero when
  /// the world has no defined reward.
  final int rewardGems;

  /// Catalog id of the world that auto-unlocks when this one is
  /// completed. `null` for end-of-chain worlds (e.g. fantasy_land).
  final String? nextWorldId;

  /// Achievement id granted when the player completes this world.
  /// `null` for worlds that don't define an achievement hook.
  final String? achievementId;

  /// True iff a reward is defined (either coin or gem > 0).
  bool get hasReward => rewardCoins > 0 || rewardGems > 0;

  /// True iff the player is at the "completed and ready to claim"
  /// state — owns the world, finished all 3 levels, hasn't claimed
  /// yet.
  bool get isRewardReady => status == WorldStatus.completed && !isRewardClaimed;
}
