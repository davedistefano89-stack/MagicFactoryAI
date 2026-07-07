// =============================================================================
// Magic Colors · core/routing/app_routes.dart
// =============================================================================
//
// Single source of truth for every URL the app can land on. The router
// (app_router.dart) reads its tables from here; analytics + telemetry read
// the AppRouteName enum from here. Anything that needs a URL or a route
// name goes through AppRoutes — magic strings live nowhere else.
//
// IMPORTANT: keep this file's surface tiny and portable (no Flutter widgets,
// no colors). It is imported by `main.dart`, `app.dart`, and the tests.
// =============================================================================

import 'package:flutter/foundation.dart';

// =============================================================================
//  AppRoutes — String paths consumed by GoRouter.
// =============================================================================

/// Frozen strings consumed by `GoRouter`. Treat the constants as if each
/// was a database column name: changing the value of an existing constant
/// is a breaking change for deep-links, push-notifications, and the App
/// Store analytics baseline. Add new destinations; never rename old ones.
@immutable
class AppRoutes {
  const AppRoutes._();

  // ── Top-level (no bottom-nav shell) ────────────────────────────────────
  /// The only entry-point when the process starts. Mostly used while
  /// `SoundService.preload` is still draining on cold start.
  static const String splash = '/';

  /// Drawing screen, pushed as a full-screen page over the shell.
  static const String coloring = '/coloring/:id';

  /// Achievement + daily chest + streak screen.
  static const String rewards = '/rewards';

  /// Subscription description + Paywall. Premium gate lives here.
  static const String premium = '/premium';

  /// Preferences + Parents Area (PIN-gated).
  static const String settings = '/settings';

  // ── Bottom-nav shell branch roots (must live under `/<tab>`) ───────────
  /// Home tab — first thing the child sees after the splash.
  static const String home = '/home';

  /// Worlds tab — pick a magical land to colour in.
  static const String worlds = '/worlds';

  /// World detail is a subroute of `/worlds`, kept inside the same branch
  /// so the bottom-nav persists when the child drills into a world.
  static const String worldDetail = '/worlds/:id';

  /// Gallery tab — saved drawings + templates.
  static const String gallery = '/gallery';

  /// Drawing detail drill-down. Subroute of [gallery] — the bottom-nav
  /// chrome stays visible while the child inspects a drawing's history
  /// (timeline, colours used, badges earned). Mirrors the
  /// `/worlds/:id` branch pattern so the routing surface stays uniform.
  static const String galleryDetail = '/gallery/:id';

  /// Shop tab — coin & gem packs + limited events.
  static const String shop = '/shop';

  /// Profile — avatar, owned worlds, language.
  static const String profile = '/profile';

  // ── Builders for parameterized URLs ────────────────────────────────────
  /// Substance-safe URL builder — interpolates the drawing id into the
  /// "/coloring/:id" pattern. Sanitising is left to the caller; this helper
  /// is intentionally pure-string and side-effect free.
  static String coloringFor(String drawingId) =>
      '/coloring/${Uri.encodeComponent(drawingId)}';

  /// Same pattern for the world-detail subroute.
  static String worldDetailFor(String worldId) =>
      '/worlds/${Uri.encodeComponent(worldId)}';

  /// Same pattern for the gallery-detail subroute. Sanitising is
  /// left to the caller — this helper is intentionally pure-string
  /// and side-effect free so it composes with `context.go(...)`.
  static String galleryDetailFor(String drawingId) =>
      '/gallery/${Uri.encodeComponent(drawingId)}';

  // ── Helpers ────────────────────────────────────────────────────────────
  /// True iff the supplied location is one of the bottom-nav branch roots
  /// (i.e. the shell shouls display its chrome). Subroutes inherit the
  /// shell from their parent branch, so this is the only check needed.
  static bool isShellRoot(String location) {
    return location == home ||
        location == worlds ||
        location == gallery ||
        location == shop ||
        location == profile;
  }

  /// True iff the supplied location is the gallery-detail subroute.
  /// Used by the bottom nav to keep the Gallery tab highlighted even
  /// when the active branch child is a drill-down (avoids the chrome
  /// "blinking off" while the child inspects a drawing).
  static bool isGalleryDetail(String location) {
    if (location == gallery) return false;
    return location.startsWith('$gallery/');
  }

  /// True iff the location is the splash entry-point. The app controller
  /// calls `goSplash()` whenever it wants to surface a hard reset.
  static bool isSplash(String location) => location == splash;
}

// =============================================================================
//  AppRouteName — enum used by analytics + push-notification landing pages.
// =============================================================================

/// Never sort or serialise this enum without a migration plan: the
/// Dart enum index *is* the analytics event id and changing the order
/// will silently rewrite history. Always add new entries at the end.
enum AppRouteName {
  splash,
  home,
  worlds,
  worldDetail,
  gallery,
  galleryDetail,
  coloring,
  rewards,
  shop,
  premium,
  profile,
  settings,
}

/// Lets you write `AppRouteName.home.path` instead of a two-step lookup,
/// and exposes the lowercase kebab-case identifier used by analytics.
extension AppRouteNameX on AppRouteName {
  /// Returns the matching path from [AppRoutes].
  String get path {
    switch (this) {
      case AppRouteName.splash:
        return AppRoutes.splash;
      case AppRouteName.home:
        return AppRoutes.home;
      case AppRouteName.worlds:
        return AppRoutes.worlds;
      case AppRouteName.worldDetail:
        return AppRoutes.worldDetail;
      case AppRouteName.gallery:
        return AppRoutes.gallery;
      case AppRouteName.galleryDetail:
        return AppRoutes.galleryDetail;
      case AppRouteName.coloring:
        return AppRoutes.coloring;
      case AppRouteName.rewards:
        return AppRoutes.rewards;
      case AppRouteName.shop:
        return AppRoutes.shop;
      case AppRouteName.premium:
        return AppRoutes.premium;
      case AppRouteName.profile:
        return AppRoutes.profile;
      case AppRouteName.settings:
        return AppRoutes.settings;
    }
  }

  /// Lowercase identifier — used by analytics dashboards and the deep-link
  /// `meta` table. Stable across releases.
  String get analyticsId {
    return switch (this) {
      AppRouteName.splash => 'splash',
      AppRouteName.home => 'home',
      AppRouteName.worlds => 'worlds',
      AppRouteName.worldDetail => 'world_detail',
      AppRouteName.gallery => 'gallery',
      AppRouteName.galleryDetail => 'gallery_detail',
      AppRouteName.coloring => 'coloring',
      AppRouteName.rewards => 'rewards',
      AppRouteName.shop => 'shop',
      AppRouteName.premium => 'premium',
      AppRouteName.profile => 'profile',
      AppRouteName.settings => 'settings',
    };
  }
}

// =============================================================================
//  HomeTab — enum that drives the bottom-nav shell.
// =============================================================================

/// Bottom-nav tabs in their visual order (left-to-right). The index of
/// each entry is the position in `StatefulShellRoute.indexedStack`; do
/// not reorder existing entries without updating the analytics baseline.
enum HomeTab {
  home,
  worlds,
  gallery,
  shop,
  profile;

  /// Convenience: the matching branch root path.
  String get path {
    switch (this) {
      case HomeTab.home:
        return AppRoutes.home;
      case HomeTab.worlds:
        return AppRoutes.worlds;
      case HomeTab.gallery:
        return AppRoutes.gallery;
      case HomeTab.shop:
        return AppRoutes.shop;
      case HomeTab.profile:
        return AppRoutes.profile;
    }
  }

  /// Convenience: the matching [AppRouteName] (used by analytics).
  AppRouteName get routeName {
    switch (this) {
      case HomeTab.home:
        return AppRouteName.home;
      case HomeTab.worlds:
        return AppRouteName.worlds;
      case HomeTab.gallery:
        return AppRouteName.gallery;
      case HomeTab.shop:
        return AppRouteName.shop;
      case HomeTab.profile:
        return AppRouteName.profile;
    }
  }
}
