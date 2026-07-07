// =============================================================================
// Magic Colors · test/unit/shop/unlock_service_test.dart
// =============================================================================
//
// Sprint 5 — unit tests for the centralized unlock pipeline. Covers
// every public surface (canAfford, owns, computeStatus, unlock) for
// each combination of currency + item kind.
//
// TEST HARNESS
//   PlayerState.inMemory() (added in M2.4) lets the test surface
//   skip Hive entirely. Every test creates a fresh player with a
//   known currency balance and a known owned-set, exercises the
//   service, and asserts the resulting PlayerState mutation.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_colors/core/services/purchase/fake_purchase_service.dart';
import 'package:magic_colors/core/services/purchase/purchase_service.dart';
import 'package:magic_colors/core/services/unlock/unlock_service.dart';
import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/features/shop/domain/shop_currency.dart';
import 'package:magic_colors/features/shop/domain/shop_item.dart';
import 'package:magic_colors/features/shop/domain/shop_item_kind.dart';
import 'package:magic_colors/features/shop/domain/shop_item_status.dart';
import 'package:magic_colors/features/shop/domain/shop_rarity.dart';

PlayerState _newPlayer({
  int coins = 0,
  int gems = 0,
  bool isPremium = false,
  Map<String, int> worldStars = const <String, int>{},
  Set<String> ownedPalettePacks = const <String>{},
  Set<String> ownedBrushes = const <String>{},
  Set<String> ownedGradients = const <String>{},
}) {
  final PlayerState player = PlayerState.inMemory();
  // Sprint 5 — set the economy EXACTLY (default is 5 gems which
  // would otherwise skew every gems-balance assertion by 5).
  // `@visibleForTesting` seam is the canonical test-only path; do
  // not switch back to grantCoins/grantGems (those ADD to default).
  player.setEconomyForTest(coins: coins, gems: gems);
  if (isPremium) {
    player.setPremium(true);
  }
  worldStars.forEach(player.grantWorldStars);
  ownedPalettePacks.forEach(player.grantPalettePack);
  ownedBrushes.forEach(player.grantBrush);
  ownedGradients.forEach(player.grantGradient);
  return player;
}

const ShopItem _coinPalette = ShopItem(
  id: 'test_palette',
  kind: ShopItemKind.palettePack,
  title: 'Test Palette',
  description: 'For unit tests.',
  icon: '🎨',
  price: 30,
  currency: ShopCurrency.coins,
  rarity: ShopRarity.common,
);

const ShopItem _gemBrush = ShopItem(
  id: 'test_brush',
  kind: ShopItemKind.brush,
  title: 'Test Brush',
  description: 'For unit tests.',
  icon: '🖌️',
  price: 5,
  currency: ShopCurrency.gems,
  rarity: ShopRarity.rare,
);

const ShopItem _starGradient = ShopItem(
  id: 'test_gradient',
  kind: ShopItemKind.gradient,
  title: 'Test Gradient',
  description: 'For unit tests.',
  icon: '🌊',
  price: 3,
  currency: ShopCurrency.stars,
  rarity: ShopRarity.epic,
  requiredStars: 3,
  requiredWorld: 'unicorn_valley',
);

const ShopItem _premiumWorld = ShopItem(
  id: 'test_premium_world',
  kind: ShopItemKind.premiumWorld,
  title: 'Test Premium World',
  description: 'For unit tests.',
  icon: '🎄',
  price: 0,
  currency: ShopCurrency.gems,
  rarity: ShopRarity.epic,
  isPremium: true,
);

const ShopItem _currencyCoinPack = ShopItem(
  id: 'test_coin_pack',
  kind: ShopItemKind.currencyPack,
  title: 'Test Coin Pack',
  description: 'For unit tests.',
  icon: '🪙',
  price: 100,
  currency: ShopCurrency.coins,
  rarity: ShopRarity.common,
);

void main() {
  // ── canAfford ─────────────────────────────────────────────────
  group('UnlockService.canAfford', () {
    test('coins: returns true when balance is sufficient', () {
      final PlayerState player = _newPlayer(coins: 50);
      expect(UnlockService.canAfford(player, _coinPalette), isTrue);
    });

    test('coins: returns false when balance is insufficient', () {
      final PlayerState player = _newPlayer(coins: 10);
      expect(UnlockService.canAfford(player, _coinPalette), isFalse);
    });

    test('gems: returns true when balance is sufficient', () {
      final PlayerState player = _newPlayer(gems: 10);
      expect(UnlockService.canAfford(player, _gemBrush), isTrue);
    });

    test('stars: returns true when world has enough earned-stars', () {
      final PlayerState player = _newPlayer(
        worldStars: <String, int>{'unicorn_valley': 3},
      );
      expect(UnlockService.canAfford(player, _starGradient), isTrue);
    });

    test('stars: returns false when world has insufficient stars', () {
      final PlayerState player = _newPlayer(
        worldStars: <String, int>{'unicorn_valley': 1},
      );
      expect(UnlockService.canAfford(player, _starGradient), isFalse);
    });

    test('stars: returns true when item has no world gate', () {
      final PlayerState player = _newPlayer();
      const ShopItem ungated = ShopItem(
        id: 'ungated',
        kind: ShopItemKind.gradient,
        title: 'Ungated',
        description: 'No world gate.',
        icon: '🌊',
        price: 1,
        currency: ShopCurrency.stars,
        rarity: ShopRarity.common,
      );
      expect(UnlockService.canAfford(player, ungated), isTrue);
    });

    test('Premium items: canAfford always returns false', () {
      final PlayerState player = _newPlayer(coins: 9999, isPremium: true);
      expect(UnlockService.canAfford(player, _premiumWorld), isFalse);
    });
  });

  // ── owns ──────────────────────────────────────────────────────
  group('UnlockService.owns', () {
    test('palette pack: returns true after grantPalettePack', () {
      final PlayerState player = _newPlayer(coins: 30);
      player.grantPalettePack('test_palette');
      expect(UnlockService.owns(player, _coinPalette), isTrue);
    });

    test('brush: returns true after grantBrush', () {
      final PlayerState player = _newPlayer(gems: 5);
      player.grantBrush('test_brush');
      expect(UnlockService.owns(player, _gemBrush), isTrue);
    });

    test('gradient: returns true after grantGradient', () {
      final PlayerState player = _newPlayer();
      player.grantGradient('test_gradient');
      expect(UnlockService.owns(player, _starGradient), isTrue);
    });

    test('premium world: returns true when player has subscription', () {
      final PlayerState player = _newPlayer(isPremium: true);
      expect(UnlockService.owns(player, _premiumWorld), isTrue);
    });

    test('premium world: returns false when player lacks subscription', () {
      final PlayerState player = _newPlayer();
      expect(UnlockService.owns(player, _premiumWorld), isFalse);
    });

    test('currency pack: always returns false (consumable)', () {
      final PlayerState player = _newPlayer(coins: 100);
      // No ownership set on currency packs.
      expect(UnlockService.owns(player, _currencyCoinPack), isFalse);
    });
  });

  // ── computeStatus ─────────────────────────────────────────────
  group('UnlockService.computeStatus', () {
    test('owned item → ShopItemStatus.owned', () {
      final PlayerState player = _newPlayer(coins: 30);
      player.grantPalettePack('test_palette');
      expect(
        UnlockService.computeStatus(player, _coinPalette),
        ShopItemStatus.owned,
      );
    });

    test('premium item without subscription → ShopItemStatus.premium', () {
      final PlayerState player = _newPlayer(coins: 9999);
      expect(
        UnlockService.computeStatus(player, _premiumWorld),
        ShopItemStatus.premium,
      );
    });

    test('premium item WITH subscription → ShopItemStatus.owned', () {
      final PlayerState player = _newPlayer(isPremium: true);
      expect(
        UnlockService.computeStatus(player, _premiumWorld),
        ShopItemStatus.owned,
      );
    });

    test('new + affordable → ShopItemStatus.newItem', () {
      const ShopItem newItem = ShopItem(
        id: 'new_item',
        kind: ShopItemKind.brush,
        title: 'New',
        description: 'Fresh off the press.',
        icon: '🆕',
        price: 5,
        currency: ShopCurrency.coins,
        rarity: ShopRarity.common,
        isNew: true,
      );
      final PlayerState player = _newPlayer(coins: 5);
      expect(
        UnlockService.computeStatus(player, newItem),
        ShopItemStatus.newItem,
      );
    });

    test('sale + affordable → ShopItemStatus.sale', () {
      const ShopItem saleItem = ShopItem(
        id: 'sale_item',
        kind: ShopItemKind.brush,
        title: 'Sale',
        description: 'On sale.',
        icon: '🏷️',
        price: 5,
        currency: ShopCurrency.coins,
        rarity: ShopRarity.common,
        isOnSale: true,
      );
      final PlayerState player = _newPlayer(coins: 5);
      expect(
        UnlockService.computeStatus(player, saleItem),
        ShopItemStatus.sale,
      );
    });

    test('affordable non-Premium non-new non-sale → ShopItemStatus.buy', () {
      final PlayerState player = _newPlayer(coins: 30);
      expect(
        UnlockService.computeStatus(player, _coinPalette),
        ShopItemStatus.buy,
      );
    });

    test('unaffordable → ShopItemStatus.locked', () {
      final PlayerState player = _newPlayer(coins: 5);
      expect(
        UnlockService.computeStatus(player, _coinPalette),
        ShopItemStatus.locked,
      );
    });
  });

  // ── unlock (the money shot) ───────────────────────────────────
  group('UnlockService.unlock', () {
    test('coins: spend + grant on first purchase', () {
      final PlayerState player = _newPlayer(coins: 30);
      final UnlockResult result = UnlockService.unlock(player, _coinPalette);
      expect(result, UnlockResult.unlocked);
      expect(player.coins, 0);
      expect(player.ownsPalettePack('test_palette'), isTrue);
    });

    test('coins: insufficient funds returns insufficientFunds', () {
      final PlayerState player = _newPlayer(coins: 10);
      final UnlockResult result = UnlockService.unlock(player, _coinPalette);
      expect(result, UnlockResult.insufficientFunds);
      expect(player.coins, 10);
      expect(player.ownsPalettePack('test_palette'), isFalse);
    });

    test('gems: spend + grant', () {
      final PlayerState player = _newPlayer(gems: 5);
      final UnlockResult result = UnlockService.unlock(player, _gemBrush);
      expect(result, UnlockResult.unlocked);
      expect(player.gems, 0);
      expect(player.ownsBrush('test_brush'), isTrue);
    });

    test('stars: deduct earned-stars + grant gradient', () {
      final PlayerState player = _newPlayer(
        worldStars: <String, int>{'unicorn_valley': 3},
      );
      final UnlockResult result = UnlockService.unlock(player, _starGradient);
      expect(result, UnlockResult.unlocked);
      expect(player.getWorldStars('unicorn_valley'), 0);
      expect(player.ownsGradient('test_gradient'), isTrue);
    });

    test('stars: insufficient stars returns insufficientFunds', () {
      final PlayerState player = _newPlayer(
        worldStars: <String, int>{'unicorn_valley': 1},
      );
      final UnlockResult result = UnlockService.unlock(player, _starGradient);
      expect(result, UnlockResult.insufficientFunds);
      expect(player.getWorldStars('unicorn_valley'), 1);
    });

    test('already owned: returns alreadyOwned, no spend', () {
      final PlayerState player = _newPlayer(coins: 30);
      player.grantPalettePack('test_palette');
      final UnlockResult result = UnlockService.unlock(player, _coinPalette);
      expect(result, UnlockResult.alreadyOwned);
      expect(player.coins, 30);
    });

    test('premium without subscription: returns premiumRequired', () {
      final PlayerState player = _newPlayer(coins: 9999);
      final UnlockResult result = UnlockService.unlock(player, _premiumWorld);
      expect(result, UnlockResult.premiumRequired);
      expect(player.isPremium, isFalse);
    });

    test('premium with subscription: returns alreadyOwned', () {
      final PlayerState player = _newPlayer(isPremium: true);
      final UnlockResult result = UnlockService.unlock(player, _premiumWorld);
      expect(result, UnlockResult.alreadyOwned);
    });

    test('currency pack: grant coins directly (no ownership set)', () {
      final PlayerState player = _newPlayer(coins: 0);
      final UnlockResult result =
          UnlockService.unlock(player, _currencyCoinPack);
      expect(result, UnlockResult.unlocked);
      expect(player.coins, 100);
    });
  });

  // ── FakePurchaseService ───────────────────────────────────────
  group('FakePurchaseService', () {
    test('buyItem returns purchased after the simulated delay', () async {
      final FakePurchaseService service = FakePurchaseService(
        simulatedDelay: Duration.zero,
      );
      final PurchaseResult result = await service.buyItem(
        itemId: 'sku_1',
        priceCents: 199,
        currencyCode: 'EUR',
      );
      expect(result, PurchaseResult.purchased);
      expect(service.isOwned('sku_1'), isTrue);
    });

    test('restorePurchases returns 0 (no native receipts)', () async {
      final FakePurchaseService service = FakePurchaseService(
        simulatedDelay: Duration.zero,
      );
      expect(await service.restorePurchases(), 0);
    });

    test('isOwned returns false for unknown ids', () {
      final FakePurchaseService service = FakePurchaseService(
        simulatedDelay: Duration.zero,
      );
      expect(service.isOwned('nope'), isFalse);
    });

    test('seedOwnership test seam populates the owned map', () {
      final FakePurchaseService service = FakePurchaseService(
        simulatedDelay: Duration.zero,
      );
      service.seedOwnership(<String, bool>{'sku_a': true});
      expect(service.isOwned('sku_a'), isTrue);
      service.reset();
      expect(service.isOwned('sku_a'), isFalse);
    });
  });
}
