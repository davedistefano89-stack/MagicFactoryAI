// =============================================================================
// Magic Colors · core/services/purchase/fake_purchase_service.dart
// =============================================================================
//
// Sprint 5 — v1.0 [PurchaseService] implementation. Simulates IAP
// success: every `buyItem` call returns `purchased` after a short
// delay (so the Shop can show the loading state during a real flow
// without faking a success that lands synchronously and breaks the
// tap-animation).
//
// OWNERSHIP MODEL
//   • In-memory `Map<String, bool>` keyed by itemId.
//   • `buyItem` flips the map entry to `true` and returns `purchased`.
//   • `restorePurchases` is a no-op (no native receipts to replay).
//   • The map survives for the lifetime of the [FakePurchaseService]
//     instance — typically a process-lifetime Provider in `app.dart`.
//
// REPLACEMENT PATH
//   When the production StoreKit / Google Play Billing integration
//   lands, the swap is a one-liner: change the Provider in `app.dart`
//   to point at the real implementation. Every Shop screen keeps
//   reading the abstract [PurchaseService] type.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'purchase_service.dart';

/// In-memory [PurchaseService] used for v1.0. Simulates IAP success
/// after a small delay so the Shop's tap-animation can run.
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({Duration? simulatedDelay})
      : _simulatedDelay = simulatedDelay ?? const Duration(milliseconds: 300);

  /// Delay before a `buyItem` resolves. Defaults to 300 ms — short
  /// enough to feel snappy in the demo, long enough to let the Shop
  /// card's tap animation play out. Tests can pass a `Duration.zero`
  /// to avoid the await.
  final Duration _simulatedDelay;

  final Map<String, bool> _owned = <String, bool>{};

  @override
  Map<String, bool> get ownedItems => Map<String, bool>.unmodifiable(_owned);

  @override
  Future<PurchaseResult> buyItem({
    required String itemId,
    required int priceCents,
    required String currencyCode,
  }) async {
    // Sprint 5 — log every simulated purchase. Replaces the
    // StoreKit-side receipt logging that the production implementation
    // will own.
    debugPrint(
      'FakePurchaseService.buyItem id=$itemId '
      'price=$priceCents $currencyCode',
    );
    if (_simulatedDelay > Duration.zero) {
      await Future<void>.delayed(_simulatedDelay);
    }
    _owned[itemId] = true;
    return PurchaseResult.purchased;
  }

  @override
  Future<int> restorePurchases() async {
    // No native receipts to replay in the fake implementation.
    return 0;
  }

  @override
  bool isOwned(String itemId) => _owned[itemId] ?? false;

  /// Sprint 5 — test seam. Lets unit tests seed the ownership map
  /// directly (bypassing the simulated delay) so the test surface
  /// stays deterministic.
  @visibleForTesting
  void seedOwnership(Map<String, bool> seed) {
    _owned.addAll(seed);
  }

  /// Sprint 5 — test seam. Resets the ownership map to empty.
  @visibleForTesting
  void reset() {
    _owned.clear();
  }
}
