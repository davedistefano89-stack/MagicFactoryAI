// =============================================================================
// Magic Colors · features/shop/domain/shop_rarity.dart
// =============================================================================
//
// Sprint 5 — visual rarity tier for a Shop item. Drives the badge
// background colour on [ShopItemCard] so the kid can see at a glance
// whether the pack is "shiny rare" vs "everyday common".
//
// PURE DART — no Flutter, no I/O.
// =============================================================================

/// 4-tier rarity scale. Order is the canonical sort order for the
/// catalog so a `sortedByRarity` helper can rely on `index`.
enum ShopRarity {
  common,
  rare,
  epic,
  legendary;

  /// Glyph drawn on the rarity badge. Matches the existing pill
  /// family (PRO / GEMS / EARN STARS) so the visual language stays
  /// consistent across the app.
  String get badgeGlyph {
    switch (this) {
      case ShopRarity.common:
        return '✨';
      case ShopRarity.rare:
        return '💫';
      case ShopRarity.epic:
        return '🌟';
      case ShopRarity.legendary:
        return '👑';
    }
  }

  /// Uppercase label rendered next to the badge glyph.
  String get label {
    switch (this) {
      case ShopRarity.common:
        return 'COMMON';
      case ShopRarity.rare:
        return 'RARE';
      case ShopRarity.epic:
        return 'EPIC';
      case ShopRarity.legendary:
        return 'LEGENDARY';
    }
  }
}
