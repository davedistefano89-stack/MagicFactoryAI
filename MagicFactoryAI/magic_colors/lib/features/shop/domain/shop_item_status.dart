// =============================================================================
// Magic Colors · features/shop/domain/shop_item_status.dart
// =============================================================================
//
// Sprint 5 — the per-item render status the [ShopItemCard] branches on.
// Computed at render time from (isOwned, isPremium, isNew, isOnSale,
// canAfford) so the model is always derived — never persisted.
//
// PURE DART — no Flutter, no I/O.
// =============================================================================

/// Render-time status for a single Shop card. Closed enum so the
/// `switch` in [ShopItemCard] is exhaustive.
enum ShopItemStatus {
  /// Player already owns the item. CTA is disabled; card shows the
  /// OWNED badge.
  owned,

  /// Item is in the catalog but the player lacks the prerequisite
  /// (currency, stars, world completion). CTA is disabled; card
  /// shows the price in a dimmed chip.
  locked,

  /// Player can buy. CTA is the BUY button.
  buy,

  /// Premium-only item (subscription required). CTA is the UPGRADE
  /// button.
  premium,

  /// Newly-added since the player's last visit. Floats the NEW badge.
  /// Orthogonal to [ShopItemStatus.owned] (a fresh item the player
  /// already owns is BOTH `new` AND `owned`).
  newItem,

  /// On sale — temporary price drop. Floats the SALE badge.
  sale;
}
