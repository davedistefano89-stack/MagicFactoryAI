// =============================================================================
// Magic Colors · features/shop/domain/shop_currency.dart
// =============================================================================
//
// Sprint 5 — the 3 currencies the Shop recognizes. Mirrors the
// PlayerState fields (coins, gems, worldStars) but exposed as a single
// closed enum so catalog rows don't have to agree on string
// spellings ("coins" vs "coin" vs "🪙").
//
// M3 — kept tiny (no I/O, no Flutter). Pure Dart so the model is
// trivially mockable in unit tests.
// =============================================================================

/// Closed enum of every currency the Shop recognizes. Order is the
/// canonical UI sort order (coins → gems → stars) so callers can rely
/// on `index` for stable list placement.
enum ShopCurrency {
  coins,
  gems,
  stars;

  /// Human-readable label used by the [ShopItemCard] when the icon
  /// glyph is too small for a 4-yr-old to read.
  String get label {
    switch (this) {
      case ShopCurrency.coins:
        return 'coins';
      case ShopCurrency.gems:
        return 'gems';
      case ShopCurrency.stars:
        return 'stars';
    }
  }

  /// Glyph used inside the price chip (matches the PlayerState HUD).
  String get glyph {
    switch (this) {
      case ShopCurrency.coins:
        return '🪙';
      case ShopCurrency.gems:
        return '💎';
      case ShopCurrency.stars:
        return '⭐';
    }
  }
}
