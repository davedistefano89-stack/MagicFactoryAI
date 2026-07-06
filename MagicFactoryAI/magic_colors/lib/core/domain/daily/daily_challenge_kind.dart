// =============================================================================
// Magic Colors · lib/core/domain/daily/daily_challenge_kind.dart
// =============================================================================
//
// Sprint 7 — kind of daily challenge. Drives the [DailyChallengeService]
// progress derivation — each kind reads a different slice of
// PlayerState. Adding a new challenge kind is a 3-step edit:
//   1. add the enum value here
//   2. add a progress branch in DailyChallengeService
//   3. add a catalog row in daily_challenges_catalog.dart
// =============================================================================

/// The shape of the player's progress the challenge tracks. v1.0
/// covers 3 kinds that can be derived from the existing PlayerState
/// (drawings, stars, worlds). New kinds ship via a catalog row +
/// service branch; no PlayerState schema change required.
enum DailyChallengeKind {
  /// "Colora N disegni oggi" — `player.drawingsCompletedToday >= N`.
  colorDrawings,

  /// "Ottieni N stelle oggi" — `player.starsEarnedToday >= N`.
  earnStars,

  /// "Completa un mondo oggi" — at least one world reached 3 stars
  /// today (heuristic: total stars earned today >= 3 in a single
  /// world). Approximated by checking if `starsEarnedToday >= 3`
  /// AND any world has 3 stars in `worldStars`.
  completeWorld,

  /// Reserved for future "apri la Home / visita la Gallery" style
  /// challenges. No catalog row ships in v1.0 — the enum value is
  /// here so a future Sprint can wire it without a breaking change.
  playMascot,
}
