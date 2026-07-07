// =============================================================================
// Magic Colors · features/shop/domain/shop_item_kind.dart
// =============================================================================
//
// Sprint 5 — discriminator for [ShopItem]. Each kind has its own
// catalog file (palette_pack / brush / gradient / premium_world /
// currency_pack) but the card surface and the unlock pipeline read a
// single uniform model so the UI never has to switch on `id.startsWith`.
//
// PURE DART — no Flutter, no I/O.
// =============================================================================

/// Closed set of every Shop item type. Adding a new item type
/// (e.g. avatar skin) means a new enum entry + a new catalog file +
/// a single switch arm in the unlock pipeline.
enum ShopItemKind {
  palettePack,
  brush,
  gradient,
  premiumWorld,
  currencyPack;
}
