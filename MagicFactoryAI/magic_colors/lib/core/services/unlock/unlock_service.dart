// =============================================================================
// Magic Colors · core/services/unlock/unlock_service.dart
// =============================================================================
//
// Sprint 5 — single owner of the unlock pipeline. Every Shop card
// tap routes through here so the canAfford / spend / grant sequence
// lives in exactly one place. Mirrors the [RewardEngine] pattern
// (abstract final, static methods, pure-Dart) so it composes with
// [PlayerState] without an extra Provider.
//
// PIPELINE (for a non-premium item)
//   1. canAfford(player, item) — pure predicate. Used by the card
//      to render the BUY vs LOCKED CTA.
//   2. unlock(player, item) — spends the currency and grants
//      ownership. Returns a [UnlockResult] so the caller can show
//      a toast / haptic / analytics event without parsing the
//      PlayerState logs.
//
// PIPELINE (for a Premium item)
//   1. status(player, item) — flips to `premium` when the player
//      lacks an active subscription.
//   2. unlockPremium(player, item) — returns true iff the player
//      already has Premium. The Shop card uses the boolean to
//      decide between the UPGRADE CTA and the OWNED badge.
//
// OWNERSHIP MODEL
//   • Palette pack / brush / gradient → PlayerState.owned*Ids set.
//   • Premium world → PlayerState.isPremium (gated by subscription).
//   • Currency pack → consumable; no ownership set; the unlock
//     grants the currency directly.
// =============================================================================

import '../../state/player_state.dart';
import '../../../features/shop/domain/shop_currency.dart';
import '../../../features/shop/domain/shop_item.dart';
import '../../../features/shop/domain/shop_item_kind.dart';
import '../../../features/shop/domain/shop_item_status.dart';

/// Outcome of a single [UnlockService.unlock] call. The Shop renders
/// one of 4 paths off this enum: `unlocked` advances the card to the
/// OWNED state, `alreadyOwned` is a quiet no-op, `insufficientFunds`
/// surfaces the "Not enough X" toast, and `premiumRequired` routes
/// to the Premium upsell.
enum UnlockResult {
  /// Spend + grant both succeeded. The Shop card flips to OWNED.
  unlocked,

  /// Item is already owned. Quiet no-op (no toast, no haptic).
  alreadyOwned,

  /// Player lacks the required currency. Caller shows the
  /// "Not enough X" toast.
  insufficientFunds,

  /// Item is Premium-only and the player lacks an active
  /// subscription. Caller routes to the Premium upsell.
  premiumRequired,
}

/// Centralized unlock façade. Marked `abstract final` (sealed-by-
/// construction) so neither tests nor screens extend it. Be a free
/// function with the same name.
abstract final class UnlockService {
  UnlockService._();

  /// True iff the player can afford to buy [item] RIGHT NOW. The
  /// predicate is side-effect-free; the Shop card calls this on
  /// every rebuild to flip the CTA between BUY and LOCKED.
  static bool canAfford(PlayerState player, ShopItem item) {
    if (item.isPremium) return false;
    switch (item.currency) {
      case ShopCurrency.coins:
        return player.canAffordCoins(item.price);
      case ShopCurrency.gems:
        return player.canAffordGems(item.price);
      case ShopCurrency.stars:
        return _hasEnoughStars(player, item);
    }
  }

  /// True iff the player already owns [item]. For Premium items,
  /// "owns" means the player has an active subscription.
  static bool owns(PlayerState player, ShopItem item) {
    switch (item.kind) {
      case ShopItemKind.palettePack:
        return player.ownsPalettePack(item.id);
      case ShopItemKind.brush:
        return player.ownsBrush(item.id);
      case ShopItemKind.gradient:
        return player.ownsGradient(item.id);
      case ShopItemKind.premiumWorld:
        return player.isPremium;
      case ShopItemKind.currencyPack:
        // Currency packs are consumable — "owns" is always false.
        return false;
    }
  }

  /// Computes the render-time status of [item] for [player]. Used by
  /// the ShopItemCard to pick the CTA + badge. Status derivation
  /// is the single source of truth; the card never re-derives it.
  static ShopItemStatus computeStatus(PlayerState player, ShopItem item) {
    if (owns(player, item)) return ShopItemStatus.owned;
    if (item.isPremium) {
      return player.isPremium
          ? ShopItemStatus.owned
          : ShopItemStatus.premium;
    }
    if (item.isNew) return ShopItemStatus.newItem;
    if (item.isOnSale) return ShopItemStatus.sale;
    if (canAfford(player, item)) return ShopItemStatus.buy;
    return ShopItemStatus.locked;
  }

  /// Unlocks [item] for [player] by spending the matching currency
  /// and granting ownership. For Premium items, just checks the
  /// subscription state (no currency spend). For currency packs,
  /// grants the currency directly (no ownership set).
  ///
  /// Returns an [UnlockResult] so the caller can fire the right
  /// toast / haptic / analytics event without parsing logs. Called
  /// from [ShopItemCard] in production; tested in isolation by the
  /// `unlock_service_test.dart` suite.
  static UnlockResult unlock(PlayerState player, ShopItem item) {
    if (item.isPremium) {
      return player.isPremium
          ? UnlockResult.alreadyOwned
          : UnlockResult.premiumRequired;
    }
    if (owns(player, item)) return UnlockResult.alreadyOwned;
    if (item.kind == ShopItemKind.currencyPack) {
      return _unlockCurrencyPack(player, item);
    }
    return _unlockContentItem(player, item);
  }

  // ── Internals ───────────────────────────────────────────────────────

  /// True iff the player has earned at least [ShopItem.requiredStars]
  /// in [ShopItem.requiredWorld]. Returns true for items that don't
  /// have a stars gate.
  static bool _hasEnoughStars(PlayerState player, ShopItem item) {
    final String? worldId = item.requiredWorld;
    if (worldId == null || item.requiredStars <= 0) {
      return true;
    }
    return player.getWorldStars(worldId) >= item.requiredStars;
  }

  /// Spend currency + grant ownership for a non-Premium, non-currency
  /// content item (palette pack, brush, gradient).
  static UnlockResult _unlockContentItem(PlayerState player, ShopItem item) {
    final bool spent;
    switch (item.currency) {
      case ShopCurrency.coins:
        spent = player.spendCoins(
          item.price,
          reason: 'shop.unlock.${item.id}',
        );
        break;
      case ShopCurrency.gems:
        spent = player.spendGems(
          item.price,
          reason: 'shop.unlock.${item.id}',
        );
        break;
      case ShopCurrency.stars:
        if (!_hasEnoughStars(player, item)) {
          return UnlockResult.insufficientFunds;
        }
        // Stars are in-world earned currency, not a global balance.
        // Deduct from the world that the item is gated to.
        final String worldId = item.requiredWorld!;
        player.grantWorldStars(
          worldId,
          -item.requiredStars,
          reason: 'shop.unlock.${item.id}',
        );
        spent = true;
        break;
    }
    if (!spent) return UnlockResult.insufficientFunds;
    _grantOwnership(player, item);
    return UnlockResult.unlocked;
  }

  /// Currency packs are consumable. The "price" field is repurposed
  /// as the amount to grant.
  static UnlockResult _unlockCurrencyPack(
    PlayerState player,
    ShopItem item,
  ) {
    switch (item.currency) {
      case ShopCurrency.coins:
        player.grantCoins(
          item.price,
          reason: 'shop.currency_pack.${item.id}',
        );
        return UnlockResult.unlocked;
      case ShopCurrency.gems:
        player.grantGems(
          item.price,
          reason: 'shop.currency_pack.${item.id}',
        );
        return UnlockResult.unlocked;
      case ShopCurrency.stars:
        // Currency packs cannot grant stars — stars are per-world
        // earned, not purchasable. Treat as a misconfigured item.
        return UnlockResult.insufficientFunds;
    }
  }

  /// Records the ownership of a content item on the [PlayerState].
  /// Switches on [ShopItem.kind] so the per-kind set lives in one
  /// place.
  static void _grantOwnership(PlayerState player, ShopItem item) {
    switch (item.kind) {
      case ShopItemKind.palettePack:
        player.grantPalettePack(item.id);
        break;
      case ShopItemKind.brush:
        player.grantBrush(item.id);
        break;
      case ShopItemKind.gradient:
        player.grantGradient(item.id);
        break;
      case ShopItemKind.premiumWorld:
        // No per-item grant — premium access is gated by
        // PlayerState.isPremium (already verified above).
        break;
      case ShopItemKind.currencyPack:
        // Handled by [_unlockCurrencyPack] — no ownership set.
        break;
    }
  }
}
