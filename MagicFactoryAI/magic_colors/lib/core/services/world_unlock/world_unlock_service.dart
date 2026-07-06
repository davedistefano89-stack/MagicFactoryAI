// =============================================================================
// Magic Colors · core/services/world_unlock/world_unlock_service.dart
// =============================================================================
//
// Sprint 6 — single owner of the world unlock pipeline. Centralizes
// the can-unlock / owns-world / lifecycle-status logic so the
// `_IslandViewModel.resolve` in `world_map_screen.dart` and any
// future surface (the new WorldProgressSection on world_detail,
// the FirstUnlock dialog trigger, the Shop premium card) all read
// from the SAME source of truth.
//
// Mirrors the [UnlockService] pattern (abstract final, static
// methods, pure-Dart) so it composes with [PlayerState] without an
// extra Provider.
//
// API SURFACE
//   ownsWorld(worldId, isPremiumWorld, starsForUnlock, player) → bool
//   canAfford(...) → bool
//   computeStatus(..., currentWorldId?) → WorldStatus
//   computeProgress(..., currentWorldId?) → WorldProgress
//
// The service does NOT import the feature-layer `WorldData` — it
// takes the 3 fields it actually needs as named parameters so the
// existing `WorldData` (defined in `world_map_screen.dart` and
// duplicated in `world_detail_screen.dart`) can be passed in
// without a service→feature import cycle.
// =============================================================================

import '../../domain/world/world_completion_reward.dart';
import '../../domain/world/world_progress.dart';
import '../../domain/world/world_status.dart';
import '../../state/player_state.dart';
import '../../../features/worlds/data/world_progress_catalog.dart';

/// World unlock / progression façade. Marked `abstract final`
/// (sealed-by-construction) so neither tests nor screens extend it.
abstract final class WorldUnlockService {
  WorldUnlockService._();

  /// True iff [player] can enter a world with [worldId] right now.
  /// Mirrors the inline check in `_IslandViewModel.resolve`:
  ///   `!premiumGate && starsReached`
  /// The "stars" gate is `PlayerState.getWorldStars(worldId) >=
  /// starsForUnlock`. The "premium" gate is
  /// `isPremiumWorld && !player.isPremium`.
  static bool ownsWorld(
    String worldId, {
    required bool isPremiumWorld,
    required int starsForUnlock,
    required PlayerState player,
  }) {
    if (isPremiumWorld && !player.isPremium) {
      return false;
    }
    return player.getWorldStars(worldId) >= starsForUnlock;
  }

  /// True iff the player can afford (in stars) to reach the next
  /// star on the world. Returns false when the world is already
  /// maxed-out (3 stars) or premium-gated (no star path). Currently
  /// informational only — the World Map does not display a "you
  /// can almost unlock" badge. Reserved for the future
  /// ContinueBanner hint.
  static bool canAfford(
    String worldId, {
    required bool isPremiumWorld,
    required int starsForUnlock,
    required PlayerState player,
  }) {
    if (isPremiumWorld && !player.isPremium) return false;
    return player.getWorldStars(worldId) >= starsForUnlock;
  }

  /// Computes the 4-state lifecycle status of the world for
  /// [player]. Honors [currentWorldId] so the `current` state can
  /// be marked (the island matching the kid's current world gets
  /// the "you are here" highlight + HERE pill).
  ///
  /// Mirrors `_IslandViewModel.resolve` byte-for-byte so the
  /// World Map island render and this service stay in lock-step.
  static WorldStatus computeStatus(
    String worldId, {
    required bool isPremiumWorld,
    required int starsForUnlock,
    required PlayerState player,
    String? currentWorldId,
  }) {
    final bool unlocked = ownsWorld(
      worldId,
      isPremiumWorld: isPremiumWorld,
      starsForUnlock: starsForUnlock,
      player: player,
    );
    if (!unlocked) return WorldStatus.locked;
    final int stars = player.getWorldStars(worldId).clamp(0, 3);
    final bool isCurrent = currentWorldId == worldId;
    if (isCurrent) return WorldStatus.current;
    if (stars >= 3) return WorldStatus.completed;
    return WorldStatus.available;
  }

  /// Composes a [WorldProgress] for the world by reading every
  /// dependent PlayerState field. Pure read — does not mutate.
  static WorldProgress computeProgress(
    String worldId, {
    required bool isPremiumWorld,
    required int starsForUnlock,
    required PlayerState player,
    String? currentWorldId,
  }) {
    final int stars = player.getWorldStars(worldId).clamp(0, 3);
    final int totalLevels = totalLevelsFor(worldId);
    final int completedLevels = stars; // 1:1 with stars (v1.0 design).
    // `clamp` on a `num` returns `num`; the explicit `.toInt()`
    // keeps the call-site type clean and avoids a static analyzer
    // error at the call site.
    final int pct = totalLevels == 0
        ? 0
        : (completedLevels * 100 / totalLevels).toInt().clamp(0, 100);
    final WorldStatus status = computeStatus(
      worldId,
      isPremiumWorld: isPremiumWorld,
      starsForUnlock: starsForUnlock,
      player: player,
      currentWorldId: currentWorldId,
    );
    final WorldCompletionReward? reward = rewardFor(worldId);
    return WorldProgress(
      worldId: worldId,
      totalLevels: totalLevels,
      completedLevels: completedLevels,
      earnedStars: stars,
      completionPct: pct,
      status: status,
      isCelebrated: player.celebratedWorldIds.contains(worldId),
      isRewardClaimed: player.claimedWorldRewardIds.contains(worldId),
      rewardCoins: reward?.coins ?? 0,
      rewardGems: reward?.gems ?? 0,
      nextWorldId: reward?.unlocksNextWorldId,
      achievementId: reward?.achievementId,
    );
  }
}
