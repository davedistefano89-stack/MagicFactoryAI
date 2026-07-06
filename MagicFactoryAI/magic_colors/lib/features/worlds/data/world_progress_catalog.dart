// =============================================================================
// Magic Colors · lib/features/worlds/data/world_progress_catalog.dart
// =============================================================================
//
// Sprint 6 — parallel catalog that adds level count + completion
// reward data to the existing WorldData roster. The original
// `WorldData` + `_kWorldCatalog` is intentionally duplicated in
// `world_map_screen.dart` and `world_detail_screen.dart` (a Sprint-4
// catalog lift is the planned refactor; Sprint 6 doesn't want to
// expand that surface). This parallel catalog lives alongside the
// existing roster so the new logic can key off the same world ids
// without forcing the existing render path to grow new fields.
//
// KEYED-BY-WORLD-ID
//   The lookups in this file (`rewardFor`, `totalLevelsFor`, etc.)
//   walk the const list once at call time. With 10 entries the cost
//   is trivial — a Map<id, …> allocation would not pay back its
//   own teardown cost.
// =============================================================================

import '../../../core/domain/world/world_completion_reward.dart';

// ── Total levels per world ────────────────────────────────────────────────

/// Number of levels in [worldId]. v1.0: every world has 3 levels so
/// the v1.0 star ceiling (3 stars) maps 1:1 to the v1.0 level count.
/// Stored as a const Map for O(1) lookup; future per-world tuning
/// (e.g. harder worlds having 5 levels) becomes a literal edit.
const Map<String, int> _kTotalLevelsByWorld = <String, int>{
  'princess_kingdom': 3,
  'unicorn_valley': 3,
  'animal_forest': 3,
  'dinosaur_island': 3,
  'dragon_mountain': 3,
  'mermaid_ocean': 3,
  'space_planet': 3,
  'christmas_village': 3,
  'halloween_world': 3,
  'fantasy_land': 3,
};

/// Returns the total number of levels in [worldId]. Falls back to 3
/// (the v1.0 design ceiling) when the world isn't in the catalog —
/// a future-proofing guard against a corrupted catalog or a new
/// world not yet wired up.
int totalLevelsFor(String worldId) =>
    _kTotalLevelsByWorld[worldId] ?? 3;

// ── Completion rewards ────────────────────────────────────────────────────

/// Free-tier chain auto-unlocks: completing unicorn_valley opens
/// animal_forest, etc. Premium worlds (christmas_village,
/// halloween_world, fantasy_land) are not in the auto-chain — they
/// require an active subscription. The default for each row is
/// "unlocksNextWorldId = the next free-tier world" so the chain
/// progresses naturally.
const List<WorldCompletionReward> _kWorldCompletionRewards =
    <WorldCompletionReward>[
  // ── Starter worlds (auto-unlocked) ───────────────────────────────────
  WorldCompletionReward(
    worldId: 'princess_kingdom',
    coins: 30,
    gems: 1,
    achievementId: 'first_world_completed',
    unlocksNextWorldId: null, // parallel starter, not chained.
  ),
  WorldCompletionReward(
    worldId: 'unicorn_valley',
    coins: 30,
    gems: 1,
    achievementId: 'first_world_completed',
    unlocksNextWorldId: 'animal_forest',
  ),
  // ── Free-tier chain (star-gated) ────────────────────────────────────
  WorldCompletionReward(
    worldId: 'animal_forest',
    coins: 50,
    gems: 1,
    unlocksNextWorldId: 'dinosaur_island',
  ),
  WorldCompletionReward(
    worldId: 'dinosaur_island',
    coins: 60,
    gems: 1,
    unlocksNextWorldId: 'dragon_mountain',
  ),
  WorldCompletionReward(
    worldId: 'dragon_mountain',
    coins: 80,
    gems: 2,
    achievementId: 'dragon_slayer',
    unlocksNextWorldId: 'mermaid_ocean',
  ),
  WorldCompletionReward(
    worldId: 'mermaid_ocean',
    coins: 70,
    gems: 1,
    unlocksNextWorldId: 'space_planet',
  ),
  WorldCompletionReward(
    worldId: 'space_planet',
    coins: 100,
    gems: 2,
    achievementId: 'all_worlds_completed',
    unlocksNextWorldId: null, // end of free chain.
  ),
  // ── Premium worlds (subscription-gated, no auto-chain) ──────────────
  WorldCompletionReward(
    worldId: 'christmas_village',
    coins: 40,
    gems: 1,
    unlocksNextWorldId: null,
  ),
  WorldCompletionReward(
    worldId: 'halloween_world',
    coins: 50,
    gems: 1,
    unlocksNextWorldId: null,
  ),
  WorldCompletionReward(
    worldId: 'fantasy_land',
    coins: 60,
    gems: 2,
    unlocksNextWorldId: null,
  ),
];

/// Returns the completion reward for [worldId] or null when the
/// world has no defined reward.
WorldCompletionReward? rewardFor(String worldId) {
  for (final WorldCompletionReward r in _kWorldCompletionRewards) {
    if (r.worldId == worldId) {
      return r;
    }
  }
  return null;
}

/// True iff [worldId] has a completion reward defined. Convenience
/// over `rewardFor(worldId) != null` so call sites read top-down.
bool hasReward(String worldId) => rewardFor(worldId) != null;
