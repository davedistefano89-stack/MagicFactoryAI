// =============================================================================
// Magic Colors · test/unit/routing/shell_tap_to_root_test.dart
// =============================================================================
//
// Phase-2 integration test for the M2.4 tap-to-root semantics — covers
// what the Phase-1 helper test (shell_tab_helpers_test.dart) deliberately
// stopped short of observing: the StatefulNavigationShell's *state* in
// response to the `selectShellTab` + `goShellTab` pair across subroute
// depth.
//
// ── Phase 1 vs Phase 2 (the deliberate split) ──────────────────────────────
// Phase 1 mounted a STUB shell (a button-only widget for each branch) and
// verified the helper pair's API contract — `nav.selectTab` invoked,
// `sound.play(bigTap)` invoked, `shell.goBranch(index, initialLocation)`
// invoked with the right args. NO subroutes, NO state observation.
//
// Phase 2 mounts a REAL GoRouter with a `/worlds/:id` subroute and
// observes the post-tap location via `router.routerDelegate.
// currentConfiguration.uri.path`. This is the user-visible effect of
// tap-to-root semantics: the worlds INNER STACK pops back to `/worlds`
// on a same-tab tap, and is restored on a worlds→gallery→worlds
// round-trip. Phase 1's API contract becomes a Phase-2 behavioural
// guarantee.
//
// ── Two contracts locked in here ───────────────────────────────────────────
//   1. Tap-to-root (same-tab from a branch child):
//      `/worlds/dragons` (sub-stack top) →
//      `selectShellTab(HomeTab.worlds); goShellTab(HomeTab.worlds);` →
//      `routerDelegate.currentConfiguration.uri.path == '/worlds'`.
//      This is what `initialLocation: true` purchases for the user: a
//      child route is popped without leaving the branch.
//
//   2. Inner-stack preservation (cross-tab round-trip):
//      `/worlds/dragons` → tap gallery → `/gallery` → tap worlds →
//      `routerDelegate.currentConfiguration.uri.path == '/worlds/dragons'`.
//      This is what `initialLocation: false` purchases for the user:
//      the worlds sub-stack survives a detour through gallery.
//
// ── Why real SoundService.preload (without asserting on it) ────────────────
// `selectShellTab(worlds)` reads `<SoundService>` from the Provider tree
// and (on cross-tab) calls `play(MagicSound.bigTap)`. The helper crashes
// if no `SoundService` is in scope. We mount a real `SoundService.preload()`
// so the helper pair completes; we do NOT assert on the audioplayers
// channel — that contract is Phase 1's concern. The channel mock is
// installed identically to keep the harness consistent across phases.
//
// ── Provider-type caveat (no, we are NOT ChangeNotifierProvider) ───────────
// `NavigationState extends ChangeNotifier`. `Provider.value` avoids
// subscribing (the test doesn't depend on notifyListeners propagation);
// `ChangeNotifierProvider` would, but its listener / disposal plumbing is
// unnecessary overhead here.
//
// ── Why every screen hosts the same tap-* buttons ──────────────────────────
// Each `_BranchScreen` renders the full triad (tap-home / tap-worlds /
// tap-gallery) so the test can fire the canonical helper pair regardless
// of which screen is on-stage. The IndexedStack mounts ALL branch
// screens in the widget tree (visible: the active branch; off-stage but
// still built: the other two), so identical "tap-worlds" buttons exist
// in three siblings. Every test MUST scope its find via the unique
// surface label (`find.descendant(of: find.text('label:...'), matching:
// find.text('tap-...'))`) to disambiguate — bare `find.text('tap-worlds')`
// would match three widgets and `tester.tap` would throw a StateError.
//
// ── Skip-on-Windows (M2.4 PHASE 2 — KNOWN ISSUE) ────────────────────────────
// Same defensive posture as the other M2.4 routing tests: `@TestOn('!windows')`
// keeps the Win32 dev box from blocking on the framework-side dispose hang.
// macOS/Linux CI runs the file normally. Doc header in
// `daily_reward_claim_test.dart` §"M2.4 PHASE 2 — KNOWN ISSUE" is the
// canonical reference; this file matches its `@Tags(['m2-4-known-issue'])`
// + named-library directive pattern.
// =============================================================================

@Tags(<String>['m2-4-known-issue'])
@TestOn('!windows')
// ignore_for_file: unnecessary_library_name
library magic_colors_shell_tap_to_root_test;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:magic_colors/core/routing/app_router.dart'
    show GoRouterContextX;
import 'package:magic_colors/core/routing/app_routes.dart'
    show AppRouteName, AppRoutes, HomeTab;
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/state/navigation_state.dart';

// ── Channel mock (audio harness, mirrors Phase 1) ──────────────────────────

/// Installed before `SoundService.preload()` runs, otherwise the audio
/// pool's `start` call races with TestWidgetsFlutterBinding's binary
/// messenger and we'd hit `MissingPluginException`.
const MethodChannel _kAudioChannel = MethodChannel('xyz.luan/audioplayers');

// ── Test fixture widget tree ───────────────────────────────────────────────

/// Renders a centered label + an optional drill button (used by the
/// worlds-root screen to push deeper into the worlds inner stack) +
/// the three tap-buttons (one per shell tab). The tap buttons run the
/// canonical `selectShellTab + goShellTab` pair the same way
/// BottomNavigation does, so the test exercises the SAME code path the
/// user would in production.
class _BranchScreen extends StatelessWidget {
  const _BranchScreen({
    required this.label,
    this.drillChild,
  });

  final String label;

  /// When non-null, renders an extra `push-<drillChild>` button that
  /// fires `GoRouter.of(context).go('/worlds/<drillChild>')`. The
  /// worlds-root screen sets this so the test can drill into the
  /// worlds inner stack to verify the tap-to-root contract; every
  /// other screen leaves it null.
  final String? drillChild;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Surface label — unique per branch route. Tests scope
            // their `find.text('tap-*')` via this label to
            // disambiguate from identical buttons on sibling screens.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('label:$label'),
            ),
            if (drillChild != null)
              ElevatedButton(
                onPressed: () {
                  GoRouter.of(context)
                      .go(AppRoutes.worldDetailFor(drillChild!));
                },
                child: Text('push-$drillChild'),
              ),
            for (final HomeTab tab
                in HomeTab.values.where((HomeTab t) => t.index <= 2))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  onPressed: () {
                    // Same canonical pair BottomNavigation._onTap runs.
                    context.selectShellTab(tab);
                    context.goShellTab(tab);
                  },
                  child: Text('tap-${tab.name}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.worlds,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        branches: <StatefulShellBranch>[
          // Branch 0 · Home ──────────────────────────────────────────
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const _BranchScreen(label: 'home'),
              ),
            ],
          ),
          // Branch 1 · Worlds + /:id subroute (drill-child) ──────────
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.worlds,
                builder: (_, __) => const _BranchScreen(
                  label: 'worlds-root',
                  drillChild: 'dragons',
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':id',
                    name: AppRouteName.worldDetail.name,
                    builder: (_, GoRouterState state) => _BranchScreen(
                      label: 'worlds-child:${state.pathParameters['id']}',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2 · Gallery ───────────────────────────────────────
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.gallery,
                builder: (_, __) => const _BranchScreen(label: 'gallery'),
              ),
            ],
          ),
        ],
        builder: (
          BuildContext ctx,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) {
          // Mirrors the production `_BranchScaffold` in
          // `app_router.dart`: publish `shell` + the canonical providers
          // into the same tree.
          return MultiProvider(
            providers: [
              Provider<StatefulNavigationShell>.value(value: shell),
              Provider<NavigationState>.value(
                  value: ctx.read<NavigationState>()),
              Provider<SoundService>.value(value: ctx.read<SoundService>()),
            ],
            child: Scaffold(body: shell),
          );
        },
      ),
    ],
  );
}

/// Returns the canonical path string for the active GoRouter location.
/// `Uri.path` is non-null and always returns the slash-prefixed path;
/// empty string only happens when no match is configured — a state the
/// tests in this file never reach.
String _locationPathOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kAudioChannel, (MethodCall call) async {
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kAudioChannel, null);
  });

  late NavigationState nav;
  late SoundService sound;
  late GoRouter router;

  setUp(() async {
    sound = await SoundService.preload();
    nav = NavigationState();
    router = _buildRouter();
  });

  tearDown(() async {
    nav.dispose();
    await sound.dispose();
    router.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NavigationState>.value(value: nav),
          Provider<SoundService>.value(value: sound),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scopes a `tap-<tabName>` find to the screen identified by
  /// `[screenLabel]`. Without this scope, the same tap-button text
  /// exists in three sibling screens behind IndexedStack and
  /// `tester.tap` throws a StateError on the ambiguous match.
  Finder tapOn(WidgetTester tester, HomeTab tab, String screenLabel) {
    return find.descendant(
      of: find.text('label:$screenLabel'),
      matching: find.text('tap-${tab.name}'),
    );
  }

  testWidgets(
    'same-tab tap (worlds → worlds) from /worlds/dragons pops the inner '
    'stack back to /worlds — tap-to-root semantics',
    (WidgetTester tester) async {
      await pumpApp(tester);
      expect(_locationPathOf(router), AppRoutes.worlds,
          reason: 'test must start on /worlds root');

      // Drill down so the test exercises the inner-stack pop path.
      await tester.tap(find.text('push-dragons'));
      await tester.pumpAndSettle();
      expect(_locationPathOf(router), '/worlds/dragons',
          reason: 'drill-down must put us on /worlds/dragons');

      // Tap the active worlds nav button from /worlds/dragons. The
      // helper pair fires: selectShellTab early-outs on same-tab, but
      // goShellTab unconditionally calls `shell.goBranch(1,
      // initialLocation: true)` which pops the inner stack.
      await tester.tap(tapOn(tester, HomeTab.worlds, 'worlds-child:dragons'));
      await tester.pumpAndSettle();

      expect(_locationPathOf(router), AppRoutes.worlds,
          reason: 'tap-to-root must pop /worlds/dragons back to /worlds');
      // nav.currentTab was HomeTab.worlds before the push (the push
      // does NOT update NavState — it's an in-memory mirror), and
      // remains HomeTab.worlds after the tap because selectShellTab
      // early-outs on same-tab.
      expect(nav.currentTab, HomeTab.worlds);
    },
  );

  testWidgets(
    'cross-tab round-trip (worlds/dragons → gallery → worlds) restores '
    '/worlds/dragons — inner-stack preservation across branches',
    (WidgetTester tester) async {
      await pumpApp(tester);

      // Boot onto the worlds child stack.
      await tester.tap(find.text('push-dragons'));
      await tester.pumpAndSettle();
      expect(_locationPathOf(router), '/worlds/dragons');

      // Cross-tab to gallery from /worlds/dragons. The worlds inner
      // stack (the /dragons child) must be preserved even though we're
      // now showing /gallery.
      await tester.tap(tapOn(tester, HomeTab.gallery, 'worlds-child:dragons'));
      await tester.pumpAndSettle();
      expect(_locationPathOf(router), AppRoutes.gallery,
          reason: 'cross-tab to gallery must land on /gallery');
      expect(nav.currentTab, HomeTab.gallery);

      // Round-trip back to worlds from /gallery (the worlds-child
      // screen is off-stage behind IndexedStack; the tap-worlds button
      // we now hit lives on the gallery screen). `initialLocation:
      // false` should restore the worlds inner stack — location pops
      // back to /worlds/dragons, NOT /worlds.
      await tester.tap(tapOn(tester, HomeTab.worlds, 'gallery'));
      await tester.pumpAndSettle();
      expect(_locationPathOf(router), '/worlds/dragons',
          reason: 'round-trip back to worlds must restore the inner '
              'stack preserved by the gallery detour — initialLocation: '
              'false keeps /worlds/dragons, NOT pop-to-root');
      expect(nav.currentTab, HomeTab.worlds);
    },
  );
}
