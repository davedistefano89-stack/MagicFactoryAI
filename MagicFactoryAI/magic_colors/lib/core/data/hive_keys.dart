// =============================================================================
// Magic Colors · lib/core/data/hive_keys.dart
// =============================================================================
//
// Single source of truth for every Hive box key the app reads/writes.
// Concentrating the literal strings here means a rename can never
// silently desync the writer (PlayerState) from any future reader.
//
// ADDING A NEW KEY: append it below with `const String …` and a brief
// doc comment naming the producer and any consumer. Keys MUST be
// kebab-case stable identifiers — they ship in player save files.
// =============================================================================

/// Key for the per-world earned-stars Map. Producer: PlayerState.
///   `Map<String, int>` where keys are `WorldData.id` (kebab/snake).
const String hiveKeyWorldStars = 'player.worldStars';

/// Key for the unlocked achievement-id set. Producer: PlayerState;
/// referenced by AchievementService via the `hiveKey` accessor below.
///   `List<String>` (Hive 2 has no Set adapter) of stable ids.
const String hiveKeyUnlockedAchievementIds = 'player.unlockedAchievementIds';

/// Key for the daily-streak integer counter. Producer + reader: PlayerState.
///   `int` (>= 0). Resets to 1 on first-ever launch and after any gap > 1 day.
const String hiveKeyStreakDays = 'player.streakDays';

/// Key for the last-streak DateTime stamp. Producer + reader: PlayerState.
///   `DateTime?` — serialized with `_box.put`. Stripped to a calendar-date
///   (year/month/day) on write so DST and timezone shifts cannot poison
///   the streak comparison.
const String hiveKeyLastStreakDate = 'player.lastStreakDate';

// ── M2.3 Palette v2 keys ───────────────────────────────────────────────

/// Key for the most-recently-used colour ids. Producer: PlayerState
/// (FIFO list, capped at [_kRecentMruCapacity] = 8 entries).
///   `List<int>` of ARGB packed ints (Color.value).
const String hiveKeyRecentColorIds = 'player.recentColorIds';

/// Key for the player-favourited colour ids. Producer: PlayerState.
///   `List<String>` of palette-stable ids (kebab/snake). Hive 2 has no
///   Set adapter; the writer/reader treat it as a Set semantically.
const String hiveKeyFavoriteColorIds = 'player.favoriteColorIds';

/// Key for the unlocked colour ids. Producer: PlayerState — set when
/// the player spends coins (or stars via `spendWorldStarCurrency`) to
/// unlock a tier-1 colour that ships locked by default.
///   `List<String>` of palette-stable ids, same encoding as [
///   hiveKeyFavoriteColorIds].
const String hiveKeyUnlockedColorIds = 'player.unlockedColorIds';

/// Capacity of the recent-colours MRU list. The canonical value lives
/// on `PlayerState.kRecentMruCapacity` so the writer/reader surface
/// stays next to the mutators that read it. This file keeps the
/// pointer comment for grep-findability.
/// (No constant declared here — kept as a comment to avoid an
/// otherwise unused-element lint.)

// ── M2.4 ParentGate keys ───────────────────────────────────────────────

/// Key for the ParentGate math-challenge accept flag. Producer +
/// reader: PlayerState. `bool`. Default false — first Premium tap
/// triggers the math challenge; success flips this to true and
/// subsequent unlocks use the hold-to-confirm shortcut.
const String hiveKeyParentGateMathOk = 'player.parentGateMathOk';

/// Key for the last ParentGate math-challenge failure timestamp.
/// Producer + reader: PlayerState. `DateTime?`. Set on failure; the
/// gate remains locked until 24 h after this stamp.
const String hiveKeyParentGateLastFailureAt = 'player.parentGateLastFailureAt';

// ── Sprint 5 Shop ownership keys ─────────────────────────────────

/// Key for the owned palette-pack ids. Producer: PlayerState
/// (`grantPalettePack` / `ownedPalettePackIds`). Consumed by
/// `UnlockService.owns` to flip the Shop card to OWNED.
///   `List<String>` of stable ids (kebab/snake). Set semantics.
const String hiveKeyOwnedPalettePackIds = 'player.ownedPalettePackIds';

/// Key for the owned brush ids. Producer: PlayerState
/// (`grantBrush` / `ownedBrushIds`). Consumed by `UnlockService.owns`.
///   `List<String>` of stable ids. Set semantics.
const String hiveKeyOwnedBrushIds = 'player.ownedBrushIds';

/// Key for the owned gradient ids. Producer: PlayerState
/// (`grantGradient` / `ownedGradientIds`). Consumed by
/// `UnlockService.owns`.   `List<String>` of stable ids.
const String hiveKeyOwnedGradientIds = 'player.ownedGradientIds';

// ── Sprint 6 World Progression keys ─────────────────────────────────────

/// Key for the celebrated-world-id set. Producer: PlayerState
/// (`markWorldCelebrated` / `celebratedWorldIds`). Consumed by
/// `FirstUnlockService` to skip worlds whose "NEW" toast has
/// already been dismissed.   `List<String>` of stable ids (kebab).
/// Set semantics.
const String hiveKeyCelebratedWorldIds = 'player.celebratedWorldIds';

/// Key for the claimed-world-reward-id set. Producer: PlayerState
/// (`claimWorldCompletionReward` / `claimedWorldRewardIds`).
/// Consumed by `CompletionRewardService` to make the claim
/// idempotent.   `List<String>` of stable ids (kebab). Set semantics.
const String hiveKeyClaimedWorldRewardIds = 'player.claimedWorldRewardIds';
