// =============================================================================
// Magic Colors · lib/core/data/hive_keys.dart
// =============================================================================
//
// Single source of truth for every Hive box key the app reads/writes
// during the M1 (Player Economy & Reward Engine) flow. Concentrating
// the literal strings here means a rename can never silently desync
// the writer (PlayerState) from any future reader (AchievementService
// during a cross-DB migration, or a QA telemetry export).
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
