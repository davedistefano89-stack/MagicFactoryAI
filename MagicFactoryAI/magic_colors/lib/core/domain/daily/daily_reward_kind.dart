// =============================================================================
// Magic Colors · lib/core/domain/daily/daily_reward_kind.dart
// =============================================================================
//
// Sprint 7 — kind of bonus awarded by the daily-reward claim. The
// catalog row pairs a kind with an amount (coins, gems) or an
// itemId (palette, brush, gradient, sticker). The service layer
// branches on this when applying the reward to PlayerState.
// =============================================================================

/// The kind of daily-reward bonus the player earns. Adding a new
/// kind (e.g. a "booster" item in a future Sprint) is a 2-step
/// edit: add the enum value + add the apply branch in
/// `DailyRewardService`.
enum DailyRewardKind {
  /// Coin grant. `amount` is the coin delta.
  coins,

  /// Gem grant. `amount` is the gem delta.
  gems,

  /// Palette-pack ownership grant. `itemId` is the catalog id
  /// (e.g. `"rainbow_sparkle"`). The service delegates to
  /// `PlayerState.grantPalettePack`.
  palette,

  /// Brush ownership grant. Delegates to `PlayerState.grantBrush`.
  brush,

  /// Gradient ownership grant. Delegates to
  /// `PlayerState.grantGradient`.
  gradient,

  /// Sticker ownership grant. Reserved for a future Sprint — the
  /// current PlayerState has no `grantSticker` mutator. v1.0
  /// catalog rows MUST NOT use this kind.
  sticker,
}
