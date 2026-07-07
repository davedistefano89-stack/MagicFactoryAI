// =============================================================================
// Magic Colors · core/services/analytics_service.dart
// =============================================================================
//
// Offline-first analytics stub. Every method is a `const no-op` so the
// AOT binary stays tiny and so the app never phones home without explicit
// user consent (Sophia, age 4, should not have her drawing sessions
// forwarded to a server anywhere).
//
// Wiring points (Sprint 6 / M6):
//   ▸ RevenueCat → tracks real-money purchases → analytics_service.trackPurchase
//   ▸ Crashlytics / Sentry → fatal & non-fatal errors → analytics_service.trackError
//   ▸ Mixpanel / Amplitude → product analytics → analytics_service.trackEvent
//   ▸ Custom retention funnel → analytics_service.setUserProperty
//
// Until those wires land, this class is a pure-const facade that the rest
// of the codebase can call without conditional `if (analytics != null)`
// noise at every call site.
// =============================================================================

import '../utils/logger.dart';

// =============================================================================
//  AnalyticsService — offline-first no-op stub.
// =============================================================================

final class AnalyticsService {
  const AnalyticsService._();

  /// Default singleton-style instance. Used by widgets that don't
  /// override the service via Provider.
  static const AnalyticsService instance = AnalyticsService._();

  // ── Session / lifecycle ───────────────────────────────────────────────
  /// Marks app session start. Called once on Home-shell presentation.
  void trackSessionStart() {
    // No-op in v1.0; the stub logs the call so dev-time QA can confirm
    // call sites are wired correctly.
    logger.debug('AnalyticsService.trackSessionStart [no-op]');
  }

  /// Marks app session end. Called when the process is suspended.
  void trackSessionEnd({required Duration duration}) {
    logger.debug('AnalyticsService.trackSessionEnd($duration) [no-op]');
  }

  // ── Generic events ─────────────────────────────────────────────────────
  /// Tracks a domain event (e.g. "drawing_completed", "world_unlocked").
  /// [properties] is an optional attribute bag — values must be small
  /// primitives (String / num / bool) and serialisable.
  void trackEvent(String name, [Map<String, Object?>? properties]) {
    logger.debug('AnalyticsService.trackEvent($name) [no-op]');
  }

  // ── Screen views ───────────────────────────────────────────────────────
  /// Tracks a screen view. The router calls this in `_build`
  /// (`AppRouter.router` will subscribe to `GoRouter.routeInformationProvider`).
  void trackScreenView(String screenName, [Map<String, Object?>? properties]) {
    logger.debug('AnalyticsService.trackScreenView($screenName) [no-op]');
  }

  // ── In-app purchases ───────────────────────────────────────────────────
  /// Tracks a successful real-money purchase. The RevenueCat integration
  /// is wired in Sprint 6; until then the stub accepts the call but
  /// silently drops the data.
  void trackPurchase({
    required String productId,
    required double price,
    String? currency,
    Map<String, Object?>? properties,
  }) {
    logger.debug(
      'AnalyticsService.trackPurchase($productId @ $price $currency) [no-op]',
    );
  }

  // ── Errors ────────────────────────────────────────────────────────────
  /// Tracks a non-fatal error captured by the widget tree's error builder.
  void trackError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) {
    logger.debug('AnalyticsService.trackError($error) [no-op]');
  }

  // ── User properties ────────────────────────────────────────────────────
  /// Sets a user-scoped property (e.g. "playerLevel = 7",
  /// "preferredLanguage = 'en'"). Properties are merged, not replaced.
  void setUserProperty(String key, Object? value) {
    logger.debug('AnalyticsService.setUserProperty($key=$value) [no-op]');
  }

  // ── Identifier management ─────────────────────────────────────────────
  void identifyUser(String userId) {
    logger.debug('AnalyticsService.identifyUser($userId) [no-op]');
  }

  void resetUser() {
    logger.debug('AnalyticsService.resetUser [no-op]');
  }

  // ── Maintenance ───────────────────────────────────────────────────────
  /// Flushes any batched events upstream. Called on `aboutToQuit` and
  /// before any process-shutdown sequence. Idempotent.
  Future<void> flush() async {
    logger.debug('AnalyticsService.flush [no-op]');
  }
}
