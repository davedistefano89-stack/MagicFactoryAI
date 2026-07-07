// =============================================================================
// Magic Colors · features/shop/domain/shop_item.dart
// =============================================================================
//
// Sprint 5 — single uniform model for every Shop catalog row. The
// five section renders (Worlds / Palettes / Brushes / Gradients /
// Premium Packs) all read [ShopItem] so the [ShopItemCard] widget
// never has to switch on item type.
//
// FIELDS
//   • id            — stable identifier (e.g. `palette_pack_rainbow`).
//                     Used by PlayerState.owned*Ids sets for ownership
//                     and by analytics dashboards for retention.
//   • kind          — discriminator (see [ShopItemKind]).
//   • title         — short player-facing label (1-3 words).
//   • description   — 1-line copy used by the card subtitle slot.
//   • icon          — emoji glyph rendered in the card hero slot.
//   • price         — cost in the smallest unit of [currency] (an
//                     integer, never a string — the UI formats).
//   • currency      — coins / gems / stars.
//   • rarity        — drives the badge background colour.
//   • isPremium     — true for subscription-only items. Overrides
//                     [price]/[currency] (those are zero for premium
//                     items).
//   • isNew         — surfaces the NEW badge. Re-evaluated on every
//                     rebuild; no persistence required.
//   • isOnSale      — surfaces the SALE badge. Same transient model.
//   • requiredStars — minimum earned-stars in [requiredWorld] before
//                     the card becomes buyable. Ignored when
//                     [requiredWorld] is null.
//   • requiredWorld — worldId whose stars gate the unlock. Null for
//                     items that don't have a world gate.
// =============================================================================

import 'package:flutter/foundation.dart';

import 'shop_currency.dart';
import 'shop_item_kind.dart';
import 'shop_rarity.dart';

@immutable
class ShopItem {
  const ShopItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.icon,
    required this.price,
    required this.currency,
    required this.rarity,
    this.isPremium = false,
    this.isNew = false,
    this.isOnSale = false,
    this.requiredStars = 0,
    this.requiredWorld,
  });

  /// Stable identifier. Used as the ownership key in PlayerState's
  /// per-kind owned-id sets and as the analytics event id.
  final String id;

  /// Discriminator (see [ShopItemKind]).
  final ShopItemKind kind;

  /// Short player-facing label (1-3 words).
  final String title;

  /// 1-line subtitle used by [ShopItemCard].
  final String description;

  /// Emoji glyph rendered in the card hero slot.
  final String icon;

  /// Cost in the smallest unit of [currency]. Zero for premium items.
  final int price;

  /// Coins / Gems / Stars.
  final ShopCurrency currency;

  /// Visual rarity tier. Drives the badge background colour.
  final ShopRarity rarity;

  /// True for subscription-only items. Overrides the BUY CTA with
  /// an UPGRADE CTA and the price chip with the PREMIUM badge.
  final bool isPremium;

  /// Floats the NEW badge when true. Re-evaluated per-rebuild.
  final bool isNew;

  /// Floats the SALE badge when true. Re-evaluated per-rebuild.
  final bool isOnSale;

  /// Minimum earned-stars in [requiredWorld] before the card becomes
  /// buyable. Ignored when [requiredWorld] is null.
  final int requiredStars;

  /// World id whose stars gate the unlock. Null for ungated items.
  final String? requiredWorld;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShopItem &&
        other.id == id &&
        other.kind == kind &&
        other.title == title &&
        other.description == description &&
        other.icon == icon &&
        other.price == price &&
        other.currency == currency &&
        other.rarity == rarity &&
        other.isPremium == isPremium &&
        other.isNew == isNew &&
        other.isOnSale == isOnSale &&
        other.requiredStars == requiredStars &&
        other.requiredWorld == requiredWorld;
  }

  @override
  int get hashCode => Object.hash(
        id,
        kind,
        title,
        description,
        icon,
        price,
        currency,
        rarity,
        isPremium,
        isNew,
        isOnSale,
        requiredStars,
        requiredWorld,
      );
}
