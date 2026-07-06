// =============================================================================
// Magic Colors · core/state/navigation_state.dart
// =============================================================================
//
// Ephemeral navigation state. NOT persisted — does not survive process
// death. The router is the source of truth for actual route transitions;
// this notifier is the in-memory mirror in case a widget needs to read or
// react to the active tab without going through `GoRouterState`.
//
// Fields:
//   • currentTab        — the active bottom-nav branch (use [HomeTab])
//   • splashComplete    — flips true once Splash finishes its
//                         pre-amble; the App shell swaps Home in.
//   • sessionStartedAt  — wall-clock when the App shell became visible.
//                         Used by Sentry / instrumentation to compute
//                         "time to interactive".
//   • transactionCount  — increments each time [selectTab] is called.
//                         Cheap debounce heuristic for analytics.
//   • currentWorldId    — Sprint 4b — id of the world the kid is
//                         currently inside (drill-down / coloring).
//                         Drives the "you are here" highlight on the
//                         world map and the ContinueBanner sync. Null
//                         when the kid hasn't opened a world yet this
//                         session.
//   • galleryFilterWorldId — Sprint 4b — when set, the Gallery filters
//                         drawings to this worldId. Cleared when the
//                         kid clears the filter chip or leaves the
//                         Gallery without an active filter.
//
// Pure Dart (no Hive, no SharedPreferences, no Material widgets).
// =============================================================================

import 'package:flutter/foundation.dart';

import '../routing/app_routes.dart' show HomeTab;
import '../utils/logger.dart';

// =============================================================================
//  NavigationState — ChangeNotifier.
// =============================================================================

final class NavigationState extends ChangeNotifier {
  NavigationState._() {
    logger.info('NavigationState constructed');
  }

  /// Default factory. The notifier has no external dependencies so the
  /// constructor is trivially callable.
  factory NavigationState() = NavigationState._;

  // ── Defaults ──────────────────────────────────────────────────────────
  static const HomeTab _defaultTab = HomeTab.home;

  // ── Public read model ──────────────────────────────────────────────────
  HomeTab _currentTab = _defaultTab;
  bool _splashComplete = false;
  DateTime? _sessionStartedAt;
  int _transactionCount = 0;
  String? _currentWorldId;
  String? _galleryFilterWorldId;

  /// Currently-selected bottom-nav branch.
  HomeTab get currentTab => _currentTab;

  /// Whether the splash screen's pre-amble has finished. The App shell
  /// watches this to swap Splash for Home.
  bool get splashComplete => _splashComplete;

  /// Wall-clock time of the most recent App-shell presentation. Null until
  /// [markSplashComplete] runs for the first time.
  DateTime? get sessionStartedAt => _sessionStartedAt;

  /// Number of tab-switch transactions since the App shell presented.
  /// Used as a cheap debounce counter for instrumentation.
  int get transactionCount => _transactionCount;

  /// Sprint 4b — the worldId the kid is currently inside (world detail
  /// screen or coloring). Drives the "you are here" highlight on the
  /// world map and the ContinueBanner sync. Null on fresh install
  /// until the kid opens a world for the first time.
  String? get currentWorldId => _currentWorldId;

  /// Sprint 4b — when set, the Gallery filters drawings to this
  /// worldId. Cleared when the kid clears the filter chip or leaves
  /// the Gallery without an active filter.
  String? get galleryFilterWorldId => _galleryFilterWorldId;

  // ── Mutators ─────────────────────────────────────────────────────────
  /// Switches the active bottom-nav branch. Idempotent for the same tab.
  void selectTab(HomeTab tab) {
    if (_currentTab == tab) {
      return;
    }
    _currentTab = tab;
    _transactionCount = _transactionCount + 1;
    logger.info('NavigationState.selectTab = $tab (#$_transactionCount)');
    notifyListeners();
  }

  /// Called by the Splash screen once the asset preload has finished and
  /// the splash animation has run to completion. Captures
  /// [_sessionStartedAt] on first call.
  void markSplashComplete() {
    if (_splashComplete) {
      return;
    }
    _splashComplete = true;
    _sessionStartedAt ??= DateTime.now();
    logger.info('NavigationState.markSplashComplete');
    notifyListeners();
  }

  /// Re-runs the splash transition (used by deep-link recovery or by the
  /// "Sign out" parents-area flow).
  void replaySplash() {
    _splashComplete = false;
    _sessionStartedAt = null;
    logger.info('NavigationState.replaySplash');
    notifyListeners();
  }

  /// Hard reset to the first-run tab + fresh session counters.
  void reset() {
    _currentTab = _defaultTab;
    _splashComplete = false;
    _sessionStartedAt = null;
    _transactionCount = 0;
    _currentWorldId = null;
    _galleryFilterWorldId = null;
    logger.info('NavigationState.reset');
    notifyListeners();
  }

  // ── Sprint 4b — current world + gallery filter ───────────────────────

  /// Sprint 4b — stamps [worldId] as the world the kid is currently
  /// inside. Idempotent for the same id. A null [worldId] clears the
  /// stamp (use when the kid pops back to the world map root). The
  /// world map's `_WorldIsland` reads this value to render the
  /// "you are here" highlight + the `_ContinueBanner` reads it to
  /// override the best-stars resume target.
  ///
  /// M3 contract: calls [notifyListeners] on every state-changing
  /// invocation (including the null-clear path). The world map's
  /// `_WorldMapScreenState.build` watches this notifier, so dropping
  /// the notify would freeze the "you are here" highlight until some
  /// other `notifyListeners` (e.g. a tab switch) coincidentally fired.
  void setCurrentWorldId(String? worldId) {
    if (_currentWorldId == worldId) {
      return;
    }
    _currentWorldId = worldId;
    logger.info('NavigationState.setCurrentWorldId = $worldId');
    notifyListeners();
  }

  /// Sprint 4b — sets the gallery filter. Idempotent for the same id;
  /// passing null clears the filter. The Gallery reads this on every
  /// load and on every notify so a clear-filter chip on the Gallery
  /// header round-trips back through the state.
  ///
  /// M3 contract: calls [notifyListeners] on every state-changing
  /// invocation (including the null-clear path). The Gallery's
  /// `didChangeDependencies` re-reads the notifier, so dropping the
  /// notify would leave the filter banner visible until the kid
  /// navigated away and back.
  void setGalleryFilterWorldId(String? worldId) {
    if (_galleryFilterWorldId == worldId) {
      return;
    }
    _galleryFilterWorldId = worldId;
    logger.info('NavigationState.setGalleryFilterWorldId = $worldId');
    notifyListeners();
  }
}
