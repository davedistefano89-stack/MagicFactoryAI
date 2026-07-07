// =============================================================================
// Magic Colors · core/services/purchase/purchase_service.dart
// =============================================================================
//
// Sprint 5 — abstract façade for every in-app purchase the game can
// fire. The v1.0 implementation is `FakePurchaseService` (always
// succeeds) so the Shop UI can ship before the platform IAP plumbing
// (StoreKit / Google Play Billing) is wired. When that lands, the
// swap is a single line in `app.dart` — every screen keeps reading
// the abstract type.
//
// API SHAPE
//   • `buyItem({itemId, priceCents, currencyCode})` — kicks off the
//     platform flow. Returns a `PurchaseResult` so the caller can
//     update the UI (success → grant ownership; failure → toast).
//   • `restorePurchases()` — re-grants the ownership for every
//     product the user has previously bought. Backs the "Restore
//     purchases" button on the Premium screen and the Shop's
//     "Restore" affordance.
//   • `isOwned(itemId)` — synchronous, in-memory ownership check.
//     Backed by the platform store receipts; the fake implementation
//     proxies to a local map.
//
// PER-PRODUCT CATALOGUE
//   The interface is item-id keyed (`String`). The per-item pricing
//   table (real-money prices in cents) lives in the platform-specific
//   implementation, not in Dart, so the production swap is a
//   native-landscape decision, not a code-level one.
// =============================================================================

import 'package:flutter/foundation.dart';

/// Outcome of a single [PurchaseService.buyItem] call. The Shop
/// renders one of 3 paths off this enum: `purchased` advances the
/// ownership state, `cancelled` shows a quiet toast, `failed` shows
/// the standard "Try again" toast.
enum PurchaseResult {
  /// Purchase completed and ownership was granted.
  purchased,

  /// User cancelled mid-flow (e.g. StoreKit "Cancel" tap). Quiet
  /// outcome — no toast.
  cancelled,

  /// Purchase failed for any other reason (network, billing error,
  /// parental controls). Caller surfaces a "Try again" toast.
  failed,
}

/// Abstract façade for in-app purchases. Production implementation
/// is the platform-specific StoreKit / Google Play Billing
/// integration; the v1.0 implementation is [FakePurchaseService].
abstract interface class PurchaseService {
  /// Kicks off a real-money purchase flow. Returns a [Future] so the
  /// Shop can `await` the outcome and update the ownership state
  /// without a second callback path. Implementations are responsible
  /// for ANY side effects (StoreKit sheet, Play Billing dialog).
  Future<PurchaseResult> buyItem({
    required String itemId,
    required int priceCents,
    required String currencyCode,
  });

  /// Re-grants ownership for every product the user has previously
  /// bought. Backs the "Restore purchases" affordance on the Shop
  /// and the Premium screen. Returns the number of items restored
  /// (useful for the toast copy: "Restored 3 items").
  Future<int> restorePurchases();

  /// Synchronous, in-memory ownership check. The fake implementation
  /// backs this with a local `Map<String, bool>`; the production
  /// implementation will back it with the platform store's local
  /// receipt cache. Defaults to `false` for unknown ids.
  @visibleForTesting
  bool isOwned(String itemId);

  /// Synchronous, in-memory ownership map. Used by [FakePurchaseService]
  /// and by tests; the production implementation can either
  /// materialize its own map or proxy to the platform store.
  @visibleForTesting
  Map<String, bool> get ownedItems;
}
