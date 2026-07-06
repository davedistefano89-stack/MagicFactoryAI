// =============================================================================
// Magic Colors · test/unit/state/navigation_state_test.dart
// =============================================================================
//
// Sprint 4b — unit tests for the new [currentWorldId] and
// [galleryFilterWorldId] fields on [NavigationState]. Covers:
//   • Default-null state (fresh NavigationState).
//   • Idempotent set (same id → no notify, no log spam).
//   • null → clears the stamp.
//   • Different ids → fires notifyListeners (verified via a listener
//     counter that observes a clean delta on each change).
//   • reset() wipes both new fields alongside the legacy counters.
//   • setCurrentWorldId + setGalleryFilterWorldId are independent
//     (each fires its own notify, neither leaks into the other).
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/routing/app_routes.dart' show HomeTab;
import 'package:magic_colors/core/state/navigation_state.dart';

void main() {
  group('NavigationState — currentWorldId (Sprint 4b)', () {
    test('starts null on a fresh state', () {
      final nav = NavigationState();
      expect(nav.currentWorldId, isNull);
    });

    test('setCurrentWorldId stores the id', () {
      final nav = NavigationState();
      nav.setCurrentWorldId('unicorn_valley');
      expect(nav.currentWorldId, 'unicorn_valley');
    });

    test('setCurrentWorldId is idempotent (no notify on same id)', () {
      final nav = NavigationState();
      nav.setCurrentWorldId('unicorn_valley');
      var notifyCount = 0;
      nav.addListener(() => notifyCount++);
      nav.setCurrentWorldId('unicorn_valley');
      expect(notifyCount, 0,
          reason: 'no-op set must not notify to avoid wasted rebuilds');
    });

    test('setCurrentWorldId(null) clears the stamp', () {
      final nav = NavigationState()..setCurrentWorldId('unicorn_valley');
      nav.setCurrentWorldId(null);
      expect(nav.currentWorldId, isNull);
    });

    test('setCurrentWorldId fires notifyListeners on change', () {
      final nav = NavigationState();
      var notifyCount = 0;
      nav.addListener(() => notifyCount++);
      nav.setCurrentWorldId('unicorn_valley');
      nav.setCurrentWorldId('dragon_mountain');
      expect(notifyCount, 2);
    });
  });

  group('NavigationState — galleryFilterWorldId (Sprint 4b)', () {
    test('starts null on a fresh state', () {
      final nav = NavigationState();
      expect(nav.galleryFilterWorldId, isNull);
    });

    test('setGalleryFilterWorldId stores the id', () {
      final nav = NavigationState();
      nav.setGalleryFilterWorldId('unicorn_valley');
      expect(nav.galleryFilterWorldId, 'unicorn_valley');
    });

    test('setGalleryFilterWorldId is idempotent (no notify on same id)', () {
      final nav = NavigationState()..setGalleryFilterWorldId('unicorn_valley');
      var notifyCount = 0;
      nav.addListener(() => notifyCount++);
      nav.setGalleryFilterWorldId('unicorn_valley');
      expect(notifyCount, 0);
    });

    test('setGalleryFilterWorldId(null) clears the filter', () {
      final nav = NavigationState()..setGalleryFilterWorldId('unicorn_valley');
      nav.setGalleryFilterWorldId(null);
      expect(nav.galleryFilterWorldId, isNull);
    });

    test('setGalleryFilterWorldId fires notifyListeners on change', () {
      final nav = NavigationState();
      var notifyCount = 0;
      nav.addListener(() => notifyCount++);
      nav.setGalleryFilterWorldId('a');
      nav.setGalleryFilterWorldId('b');
      expect(notifyCount, 2);
    });
  });

  group('NavigationState — field independence', () {
    test('setCurrentWorldId does not affect galleryFilterWorldId', () {
      final nav = NavigationState()..setGalleryFilterWorldId('unicorn_valley');
      nav.setCurrentWorldId('dragon_mountain');
      expect(nav.galleryFilterWorldId, 'unicorn_valley');
      expect(nav.currentWorldId, 'dragon_mountain');
    });

    test('setGalleryFilterWorldId does not affect currentWorldId', () {
      final nav = NavigationState()..setCurrentWorldId('dragon_mountain');
      nav.setGalleryFilterWorldId('unicorn_valley');
      expect(nav.currentWorldId, 'dragon_mountain');
      expect(nav.galleryFilterWorldId, 'unicorn_valley');
    });

    test('reset() wipes both new fields alongside the legacy counters',
        () {
      final nav = NavigationState()
        ..setCurrentWorldId('dragon_mountain')
        ..setGalleryFilterWorldId('unicorn_valley')
        ..selectTab(HomeTab.gallery)
        ..markSplashComplete();
      expect(nav.currentWorldId, isNotNull);
      expect(nav.galleryFilterWorldId, isNotNull);
      nav.reset();
      expect(nav.currentWorldId, isNull);
      expect(nav.galleryFilterWorldId, isNull);
      expect(nav.currentTab, HomeTab.home);
      expect(nav.splashComplete, isFalse);
      expect(nav.sessionStartedAt, isNull);
      expect(nav.transactionCount, 0);
    });
  });
}
