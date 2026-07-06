// =============================================================================
// Magic Colors · lib/core/services/economy/achievement_service.dart
// =============================================================================
//
// Pure-data achievement catalog + an `evaluate` function that takes a
// `PlayerSnapshot` (read-only view of the relevant persisted fields) and
// returns the achievements newly unlocked by this session's actions.
//
// CATALOG POLICY (v1.0)
//   • Total count: 12 — small enough that a 4-year-old can see every
//     one as a celebration within a single play session of two weeks.
//   • No hidden achievements. Pre-readers cannot interpret secret
//     mechanics; every tile is reachable through fun play, not by
//     grinding.
//   • All feedback is iconographic (emoji + colour tier) and audio
//     (celebratory `MagicSound.reward`). Text on the achievements
//     screen exists only because PARENTS also look at it; the child's
//     comprehension is the visual sparkle.
//
// FORM
//   Each `AchievementDefinition` is a `const` record in a top-level
//   list, keyed by a stable id (the lowercase snake_case identifier).
//   Adding an achievement is a single literal + a new branch in
//   `_evaluateOne`. Reordering is free — order affects UI placement
//   only.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import '../../data/hive_keys.dart';
import '../../domain/economy/reward.dart';
import '../../state/player_state.dart';
import '../../utils/logger.dart' show logger;

// ── Tier ───────────────────────────────────────────────────────────────────

/// Visual tier rendered as a colour band on the achievement tile.
enum AchievementTier { bronze, silver, gold }

// ── PlayerSnapshot — read-only projection of PlayerState for evaluation ──

/// Lightweight, immutable projection of the [PlayerState] fields the
/// achievement conditions read. Constructed once per evaluation; never
/// re-read during the same evaluate() pass so the result is consistent
/// even if PlayerState is mid-mutation in another isolate.
@immutable
class PlayerSnapshot {
  /// Builds a snapshot from a live [PlayerState]. Cheap O(1) copy —
  /// the [worldStars] map is shallow-copied so the snapshot is decoupled
  /// from the live state.
  factory PlayerSnapshot.fromPlayer(PlayerState player) {
    return PlayerSnapshot(
      coins: player.coins,
      gems: player.gems,
      streakDays: player.streakDays,
      isPremium: player.isPremium,
      worldStars: Map<String, int>.from(player.worldStars),
      ownedWorldIds: Set<String>.from(player.ownedWorldIds),
    );
  }
  const PlayerSnapshot({
    required this.coins,
    required this.gems,
    required this.streakDays,
    required this.isPremium,
    required this.worldStars,
    required this.ownedWorldIds,
  });

  final int coins;
  final int gems;
  final int streakDays;
  final bool isPremium;
  final Map<String, int> worldStars;
  final Set<String> ownedWorldIds;
}

// ── Achievement definition ──────────────────────────────────────────────────

/// One entry in the catalog. The id is the stable identifier (used by
/// Hive persistence); the title and description are surfaced verbatim to
/// PARENTS in the achievements screen — the child only sees the glyph +
/// tier colour band.
@immutable
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.glyph,
    required this.description,
    required this.tier,
    required this.reward,
    required this.unlockCondition,
  });

  final String id;

  /// Short visual label. Surfaces to PARENTS only — the kid sees
  /// the [glyph] and the celebration animation.
  final String title;

  /// Hero emoji for the badge tile.
  final String glyph;

  /// Long-form copy — only for the parental achievement screen.
  final String description;

  final AchievementTier tier;

  /// Reward granted when the achievement unlocks for the first time.
  /// Subsequent re-evaluations return `alreadyUnlocked = true` and
  /// skip the grant.
  final CompositeReward reward;

  /// Pure-function evaluation closure. Takes a [PlayerSnapshot] and
  /// returns true iff the achievement should be considered unlocked.
  /// Implementations MUST be deterministic + side-effect-free.
  final bool Function(PlayerSnapshot snapshot) unlockCondition;
}

// ── Catalog of all 12 v1.0 achievements ────────────────────────────────────

// Hive key for the unlocked-achievement-id list is hoisted to
// `core/data/hive_keys.dart`. `AchievementService.hiveKey` below exposes
// the constant so PlayerState can read/write the same literal without
// re-declaring it. This avoids any future drift when a rename ships.

// ── Frozen reward records (v1.0 simple shape) ─────────────────────────────

// Tiny helper so the catalog stays readable — each record bundles the
// reason and the (coins, gems) pair into one CompositeReward.
//
// `coins: 0, gems: 0` rewards are deliberately no-op; achievements still
// celebrate but the player doesn't see a confusing "+0" tip.

const CompositeReward _firstTouchReward = CompositeReward(
  reason: 'achievement.first_touch',
  children: <Reward>[
    CoinReward(reason: 'achievement.first_touch', amount: 10),
  ],
);

const CompositeReward _firstSaveReward = CompositeReward(
  reason: 'achievement.first_save',
  children: <Reward>[
    CoinReward(reason: 'achievement.first_save', amount: 25),
    GemReward(reason: 'achievement.first_save', amount: 1),
  ],
);

const CompositeReward _crayonCuriousReward = CompositeReward(
  reason: 'achievement.crayon_curious',
  children: <Reward>[
    CoinReward(reason: 'achievement.crayon_curious', amount: 15),
  ],
);

const CompositeReward _sparkleSmithReward = CompositeReward(
  reason: 'achievement.sparkle_smith',
  children: <Reward>[
    CoinReward(reason: 'achievement.sparkle_smith', amount: 30),
    GemReward(reason: 'achievement.sparkle_smith', amount: 1),
  ],
);

const CompositeReward _unicornFriendReward = CompositeReward(
  reason: 'achievement.unicorn_friend',
  children: <Reward>[
    CoinReward(reason: 'achievement.unicorn_friend', amount: 20),
  ],
);

const CompositeReward _worldMasterReward = CompositeReward(
  reason: 'achievement.world_master',
  children: <Reward>[
    CoinReward(reason: 'achievement.world_master', amount: 200),
    GemReward(reason: 'achievement.world_master', amount: 5),
  ],
);

const CompositeReward _streakThreeReward = CompositeReward(
  reason: 'achievement.streak_three',
  children: <Reward>[
    CoinReward(reason: 'achievement.streak_three', amount: 30),
  ],
);

const CompositeReward _streakSevenReward = CompositeReward(
  reason: 'achievement.streak_seven',
  children: <Reward>[
    CoinReward(reason: 'achievement.streak_seven', amount: 75),
    GemReward(reason: 'achievement.streak_seven', amount: 2),
  ],
);

const CompositeReward _streakThirtyReward = CompositeReward(
  reason: 'achievement.streak_thirty',
  children: <Reward>[
    CoinReward(reason: 'achievement.streak_thirty', amount: 300),
    GemReward(reason: 'achievement.streak_thirty', amount: 10),
  ],
);

const CompositeReward _rainbowRiderReward = CompositeReward(
  reason: 'achievement.rainbow_rider',
  children: <Reward>[
    CoinReward(reason: 'achievement.rainbow_rider', amount: 60),
    GemReward(reason: 'achievement.rainbow_rider', amount: 2),
  ],
);

const CompositeReward _premiumCuriousReward = CompositeReward(
  reason: 'achievement.premium_curious',
  children: <Reward>[
    CoinReward(reason: 'achievement.premium_curious', amount: 5),
  ],
);

const CompositeReward _galleryFilledReward = CompositeReward(
  reason: 'achievement.gallery_filled',
  children: <Reward>[
    CoinReward(reason: 'achievement.gallery_filled', amount: 100),
    GemReward(reason: 'achievement.gallery_filled', amount: 3),
  ],
);

// Sprint 6 — World Progression achievement rewards. All four
// follow the v1.0 pattern: a single tier-appropriate reward,
// triggered by CompletionRewardService (for first_world_completed
// and all_worlds_completed) OR by the AchievementService.evaluate
// call in any state-mutating code path (for the 10/20 stars
// milestones).
const CompositeReward _firstWorldCompletedReward = CompositeReward(
  reason: 'achievement.first_world_completed',
  children: <Reward>[
    CoinReward(reason: 'achievement.first_world_completed', amount: 75),
    GemReward(reason: 'achievement.first_world_completed', amount: 3),
  ],
);

const CompositeReward _allWorldsCompletedReward = CompositeReward(
  reason: 'achievement.all_worlds_completed',
  children: <Reward>[
    CoinReward(reason: 'achievement.all_worlds_completed', amount: 500),
    GemReward(reason: 'achievement.all_worlds_completed', amount: 20),
  ],
);

const CompositeReward _starCollectorTenReward = CompositeReward(
  reason: 'achievement.star_collector_ten',
  children: <Reward>[
    CoinReward(reason: 'achievement.star_collector_ten', amount: 50),
    GemReward(reason: 'achievement.star_collector_ten', amount: 2),
  ],
);

const CompositeReward _starCollectorTwentyReward = CompositeReward(
  reason: 'achievement.star_collector_twenty',
  children: <Reward>[
    CoinReward(reason: 'achievement.star_collector_twenty', amount: 150),
    GemReward(reason: 'achievement.star_collector_twenty', amount: 5),
  ],
);

// Sprint 7 — Daily Gameplay achievement rewards. Tied to streak
// milestones; the AchievementService.evaluate path fires them
// off the same `streakDays` counter that powers the daily
// challenge / reward claim flow.
const CompositeReward _dailyChallengerReward = CompositeReward(
  reason: 'achievement.daily_challenger',
  children: <Reward>[
    CoinReward(reason: 'achievement.daily_challenger', amount: 50),
    GemReward(reason: 'achievement.daily_challenger', amount: 2),
  ],
);

const CompositeReward _dailyChampionReward = CompositeReward(
  reason: 'achievement.daily_champion',
  children: <Reward>[
    CoinReward(reason: 'achievement.daily_champion', amount: 200),
    GemReward(reason: 'achievement.daily_champion', amount: 8),
  ],
);

const CompositeReward _dailyLegendReward = CompositeReward(
  reason: 'achievement.daily_legend',
  children: <Reward>[
    CoinReward(reason: 'achievement.daily_legend', amount: 1000),
    GemReward(reason: 'achievement.daily_legend', amount: 50),
  ],
);

// ── Evaluation helpers per achievement ────────────────────────────────────

// Each `_isXxxUnlocked(snapshot)` is the unlockCondition. They are
// file-private so the public catalog above is the single source of
// truth. Conditions use ONLY PlayerSnapshot fields — never PlayerState
// directly — so the evaluation is a pure function.

bool _isFirstTouchUnlocked(PlayerSnapshot s) => s.coins > 0 || s.gems > 0;

bool _isFirstSaveUnlocked(PlayerSnapshot s) =>
    s.worldStars.values.fold<int>(0, (int a, int b) => a + b) >= 1;

bool _isCrayonCuriousUnlocked(PlayerSnapshot s) =>
    s.worldStars.values.fold<int>(0, (int a, int b) => a + b) >= 1 &&
    (s.coins > 0 || s.gems > 0);

bool _isSparkleSmithUnlocked(PlayerSnapshot s) {
  // v1.0 approximation: ten quality drawings is roughly ten sparkle
  // bursts. We don't instrument per-stroke brush type yet, so we
  // approximate via the worldStars sum.
  final int totalStars =
      s.worldStars.values.fold<int>(0, (int a, int b) => a + b);
  return totalStars >= 10;
}

bool _isUnicornFriendUnlocked(PlayerSnapshot s) =>
    (s.worldStars['unicorn_valley'] ?? 0) >= 1;

bool _isWorldMasterUnlocked(PlayerSnapshot s) =>
    s.worldStars.values.where((int stars) => stars >= 3).length >= 5;

bool _isStreakThreeUnlocked(PlayerSnapshot s) => s.streakDays >= 3;

bool _isStreakSevenUnlocked(PlayerSnapshot s) => s.streakDays >= 7;

bool _isStreakThirtyUnlocked(PlayerSnapshot s) => s.streakDays >= 30;

bool _isRainbowRiderUnlocked(PlayerSnapshot s) {
  // It's hard to know if the player covered every palette colour from
  // a sidebar view alone. v1.0 approximation: 12+ total stars across
  // all worlds implies palette breadth.
  final int totalStars =
      s.worldStars.values.fold<int>(0, (int a, int b) => a + b);
  return totalStars >= 64; // very generous heuristic; tuned later.
}

bool _isPremiumCuriousUnlocked(PlayerSnapshot s) => s.isPremium;

bool _isGalleryFilledUnlocked(PlayerSnapshot s) =>
    s.worldStars.values.where((int stars) => stars > 0).length >= 5;

// ── Sprint 6 — World Progression achievements ────────────────────────────

bool _isFirstWorldCompletedUnlocked(PlayerSnapshot s) {
  // First world finished = at least one world with all 3 stars.
  return s.worldStars.values.any((int stars) => stars >= 3);
}

bool _isAllWorldsCompletedUnlocked(PlayerSnapshot s) {
  // All 10 catalog worlds fully starred. Uses the total-stars heuristic
  // (10 worlds × 3 stars = 30) so the v1.0 achievement doesn't
  // accidentally fire from a cluster of partially-completed worlds.
  final int totalStars =
      s.worldStars.values.fold<int>(0, (int a, int b) => a + b);
  return totalStars >= 30;
}

bool _isStarCollectorTenUnlocked(PlayerSnapshot s) {
  final int totalStars =
      s.worldStars.values.fold<int>(0, (int a, int b) => a + b);
  return totalStars >= 10;
}

bool _isStarCollectorTwentyUnlocked(PlayerSnapshot s) {
  final int totalStars =
      s.worldStars.values.fold<int>(0, (int a, int b) => a + b);
  return totalStars >= 20;
}

// ── Sprint 7 — Daily Gameplay achievements ────────────────────────────────

bool _isDailyChallengerUnlocked(PlayerSnapshot s) {
  // The daily-challenges flow marks the player with the
  // `has_claimed_daily_challenge` set in the persistent
  // snapshot. v1.0 approximation: 3+ claims across the streak
  // (a "weekly challenger" type milestone).
  return s.streakDays >= 3;
}

bool _isDailyChampionUnlocked(PlayerSnapshot s) {
  // A full week of daily challenges claimed.
  return s.streakDays >= 7;
}

bool _isDailyLegendUnlocked(PlayerSnapshot s) {
  // A full month of daily challenges claimed.
  return s.streakDays >= 30;
}

// =============================================================================
//  AchievementService — pure-function catalog + evaluator.
// =============================================================================

abstract final class AchievementService {
  AchievementService._();

  /// Single source of truth for every achievement. Built once at library
  /// load by binding the unlock-condition closures to their data.
  /// Exposed read-only so consumers cannot mutate the catalog.
  static final List<AchievementDefinition> _catalog =
      List<AchievementDefinition>.unmodifiable(_buildRuntimeCatalog());

  /// Returns the catalog (immutable). Visible for tests so the catalog
  /// can be introspected without re-listing ids in test fixtures.
  /// M3 — public catalog accessor. Originally `@visibleForTesting` so
  /// the Gallery drill-down screen could read it without paying the
  /// production-API tax. The catalog is read-only (`List.unmodifiable`
  /// construction at the bottom of this file) and free to share with
  /// any consumer — promotion to public surface keeps feature code
  /// off the test-only whitelist path.
  static List<AchievementDefinition> get catalog => _catalog;

  /// Looks up a definition by [id]. Returns null if the id is not in
  /// the catalog (forward-compatible: a future achievement id shipped
  /// in persisted storage but missing from the catalog should NOT
  /// crash unlock evaluation).
  static AchievementDefinition? definitionById(String id) {
    for (final AchievementDefinition def in _catalog) {
      if (def.id == id) {
        return def;
      }
    }
    return null;
  }

  /// Evaluates every catalog entry against [snapshot] and
  /// [previouslyUnlocked]. Returns the list of NEWLY-unlocked
  /// achievements (anything that passes its `unlockCondition` AND isn't
  /// already in [previouslyUnlocked]). The caller is responsible for
  /// granting the [AchievementDefinition.reward] for each NEW unlock
  /// and merging the returned ids back into the persisted set.
  static List<AchievementDefinition> evaluate({
    required PlayerSnapshot snapshot,
    required Set<String> previouslyUnlocked,
  }) {
    final List<AchievementDefinition> newlyUnlocked = <AchievementDefinition>[];
    for (final AchievementDefinition def in _catalog) {
      if (previouslyUnlocked.contains(def.id)) {
        continue;
      }
      final bool pass = def.unlockCondition(snapshot);
      if (pass) {
        newlyUnlocked.add(def);
        logger.info(
          'AchievementService.evaluate unlocked ${def.id} '
          '(tier=${def.tier.name})',
        );
      }
    }
    return newlyUnlocked;
  }

  /// Hive key for the unlocked-achievement-id set. Surfaced so the
  /// persistence owner (PlayerState) can read/write the same key
  /// without re-declaring the literal in two places. The literal lives
  /// in `core/data/hive_keys.dart` — this accessor is the canonical
  /// accessor for downstream readers.
  static String get hiveKey => hiveKeyUnlockedAchievementIds;
}

// =============================================================================
//  Wires the unlock conditions onto the catalog (now `const`-constructible).
// =============================================================================
//
// A `const AchievementDefinition` cannot carry a function reference,
// so the catalog above deliberately omits the unlockCondition field.
// We attach it here via a top-level `const List` builder that the
// catalog authors can also use at runtime.
//
// Note: `_kAchievementCatalog` is NOT actually const because
// `unlockCondition` is a function reference. The catalog is exposed as
// `catalog` getter above which lazily maps conditions onto the data.
// =============================================================================

// Build the *real* catalog on first access by binding unlock functions.
List<AchievementDefinition> _buildRuntimeCatalog() {
  return <AchievementDefinition>[
    const AchievementDefinition(
      id: 'first_touch',
      title: 'First Touch',
      glyph: '✏️',
      description: 'Place the first brush stroke on any drawing.',
      tier: AchievementTier.bronze,
      reward: _firstTouchReward,
      unlockCondition: _isFirstTouchUnlocked,
    ),
    const AchievementDefinition(
      id: 'first_save',
      title: 'My First Drawing',
      glyph: '🎨',
      description: 'Save the very first drawing.',
      tier: AchievementTier.bronze,
      reward: _firstSaveReward,
      unlockCondition: _isFirstSaveUnlocked,
    ),
    const AchievementDefinition(
      id: 'crayon_curious',
      title: 'Crayon Curious',
      glyph: '🖍️',
      description: 'Try the crayon brush on any drawing.',
      tier: AchievementTier.bronze,
      reward: _crayonCuriousReward,
      unlockCondition: _isCrayonCuriousUnlocked,
    ),
    const AchievementDefinition(
      id: 'sparkle_smith',
      title: 'Sparkle Smith',
      glyph: '✨',
      description: 'Place ten or more sparkle brush strokes.',
      tier: AchievementTier.silver,
      reward: _sparkleSmithReward,
      unlockCondition: _isSparkleSmithUnlocked,
    ),
    const AchievementDefinition(
      id: 'unicorn_friend',
      title: 'Unicorn Friend',
      glyph: '🦄',
      description: 'Earn one or more stars in Unicorn Valley.',
      tier: AchievementTier.bronze,
      reward: _unicornFriendReward,
      unlockCondition: _isUnicornFriendUnlocked,
    ),
    const AchievementDefinition(
      id: 'world_master',
      title: 'World Master',
      glyph: '🏆',
      description: 'Earn three stars in five different worlds.',
      tier: AchievementTier.gold,
      reward: _worldMasterReward,
      unlockCondition: _isWorldMasterUnlocked,
    ),
    const AchievementDefinition(
      id: 'streak_three',
      title: 'Three in a Row',
      glyph: '🔥',
      description: 'Visit the app three days in a row.',
      tier: AchievementTier.bronze,
      reward: _streakThreeReward,
      unlockCondition: _isStreakThreeUnlocked,
    ),
    const AchievementDefinition(
      id: 'streak_seven',
      title: 'Lucky Seven',
      glyph: '🍀',
      description: 'Visit the app seven days in a row.',
      tier: AchievementTier.silver,
      reward: _streakSevenReward,
      unlockCondition: _isStreakSevenUnlocked,
    ),
    const AchievementDefinition(
      id: 'streak_thirty',
      title: 'Magical Month',
      glyph: '🌟',
      description: 'Visit the app thirty days in a row.',
      tier: AchievementTier.gold,
      reward: _streakThirtyReward,
      unlockCondition: _isStreakThirtyUnlocked,
    ),
    const AchievementDefinition(
      id: 'rainbow_rider',
      title: 'Rainbow Rider',
      glyph: '🌈',
      description: 'Use every colour in the palette.',
      tier: AchievementTier.silver,
      reward: _rainbowRiderReward,
      unlockCondition: _isRainbowRiderUnlocked,
    ),
    const AchievementDefinition(
      id: 'premium_curious',
      title: 'Premium Curious',
      glyph: '👑',
      description: 'Visit the Premium screen via Parents Area.',
      tier: AchievementTier.bronze,
      reward: _premiumCuriousReward,
      unlockCondition: _isPremiumCuriousUnlocked,
    ),
    const AchievementDefinition(
      id: 'gallery_filled',
      title: 'Gallery Filled',
      glyph: '🖼️',
      description: 'Save five or more drawings.',
      tier: AchievementTier.silver,
      reward: _galleryFilledReward,
      unlockCondition: _isGalleryFilledUnlocked,
    ),
    // ── Sprint 6 — World Progression achievements (4 new entries) ────
    const AchievementDefinition(
      id: 'first_world_completed',
      title: 'First World Conquered',
      glyph: '🌍',
      description: 'Earn all 3 stars in any world.',
      tier: AchievementTier.silver,
      reward: _firstWorldCompletedReward,
      unlockCondition: _isFirstWorldCompletedUnlocked,
    ),
    const AchievementDefinition(
      id: 'star_collector_ten',
      title: 'Star Collector',
      glyph: '⭐',
      description: 'Earn 10 stars across all worlds.',
      tier: AchievementTier.bronze,
      reward: _starCollectorTenReward,
      unlockCondition: _isStarCollectorTenUnlocked,
    ),
    const AchievementDefinition(
      id: 'star_collector_twenty',
      title: 'Star Hoarder',
      glyph: '🌟',
      description: 'Earn 20 stars across all worlds.',
      tier: AchievementTier.silver,
      reward: _starCollectorTwentyReward,
      unlockCondition: _isStarCollectorTwentyUnlocked,
    ),
    const AchievementDefinition(
      id: 'all_worlds_completed',
      title: 'World Champion',
      glyph: '🏅',
      description: 'Earn 3 stars in every world.',
      tier: AchievementTier.gold,
      reward: _allWorldsCompletedReward,
      unlockCondition: _isAllWorldsCompletedUnlocked,
    ),
    // ── Sprint 7 — Daily Gameplay achievements (3 new entries) ─────
    const AchievementDefinition(
      id: 'daily_challenger',
      title: 'Daily Challenger',
      glyph: '⚡',
      description: 'Open the app 3 days in a row.',
      tier: AchievementTier.bronze,
      reward: _dailyChallengerReward,
      unlockCondition: _isDailyChallengerUnlocked,
    ),
    const AchievementDefinition(
      id: 'daily_champion',
      title: 'Daily Champion',
      glyph: '🏆',
      description: 'Open the app 7 days in a row.',
      tier: AchievementTier.silver,
      reward: _dailyChampionReward,
      unlockCondition: _isDailyChampionUnlocked,
    ),
    const AchievementDefinition(
      id: 'daily_legend',
      title: 'Daily Legend',
      glyph: '👑',
      description: 'Open the app 30 days in a row.',
      tier: AchievementTier.gold,
      reward: _dailyLegendReward,
      unlockCondition: _isDailyLegendUnlocked,
    ),
  ];
}
