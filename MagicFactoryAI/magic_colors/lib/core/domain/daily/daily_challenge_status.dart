// =============================================================================
// Magic Colors · lib/core/domain/daily/daily_challenge_status.dart
// =============================================================================
//
// Sprint 7 — lifecycle state of a single daily challenge. Mirrors
// the 4-state pattern used by `WorldStatus` (Sprint 6) and
// `ShopItemStatus` (Sprint 5) so the UI can switch on the enum
// without re-deriving booleans.
// =============================================================================

enum DailyChallengeStatus {
  /// Not in the active-today roster (the catalog only surfaces a
  /// subset per day). UI surfaces a locked silhouette.
  locked,

  /// In the active-today roster, target not yet reached. UI
  /// surfaces the progress bar + remaining copy.
  active,

  /// Target reached, reward not yet claimed. UI surfaces a
  /// "Claim" CTA.
  completed,

  /// Reward already claimed (today). UI surfaces a "Claimed"
  /// badge.
  claimed,
}
