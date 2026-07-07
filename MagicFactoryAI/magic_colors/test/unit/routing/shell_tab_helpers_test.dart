// =============================================================================
// Magic Colors · test/unit/routing/shell_tab_helpers_test.dart
// =============================================================================
//
// Locks in the M2.4 shell-tab pipeline (`selectShellTab` + `goShellTab` on
// the GoRouterContextX extension in core/routing/app_router.dart) so any
// future refactor that breaks the contract lights up this test instead of
// shipping a silent regression.
//
// ── Two observable contracts (per turn) ────────────────────────────────────
//   1. NavigationState mirror — `selectShellTab(tab)` flips
//      `nav.currentTab` to `tab` on cross-tab transitions; same-tab taps
//      MUST early-out silently so `nav.currentTab` is unchanged.
//   2. MagicSound.bigTap play — `selectShellTab` fires `sound.play(bigTap)`
//      on cross-tab transitions; same-tab taps MUST early-out silently.
//      We observe via the audioplayers MethodChannel's "start"/"resume"
//      call counter filtered for `audio/sfx/big_tap.ogg`.
//
// ── Why nav + audio (not shell.current_index) ──────────────────────────────
// `goShellTab` reads `StatefulNavigationShell.currentIndex` and writes
// `shell.goBranch(...)`. Asserting the index via go_router's nested
// router internals is fragile across SDK versions and re-introduces
// the M2.4 PHASE 2 framework-side dispose hang on Win32. The nav +
// audio contracts cover the SAME two design decisions the user
// mandated (`selectShellTab`'s early-out fires silently on same-tab,
// fires visibly on cross-tab) without coupling to go_router internals.
// The shell-level "tap-to-root" assertion lives in a separate
// integration test (see followup recommendations).
//
// ── Why a real GoRouter (not a stub) ───────────────────────────────────────
// `StatefulNavigationShell`'s public constructor requires a
// `shellRouteContext` + `GoRouter router` + `containerBuilder` triple
// (verified in go_router 14.8.1, lib/src/route.dart line ~1108) — cannot
// be constructed standalone for unit stubbing. The cleanest mini app is
// a 3-leaf StatefulShellRoute.indexedStack + a `MaterialApp.router`
// mount. Three `HomeTab.values[0..2]` give us the surface we need
// for cross-tab and same-tab assertions without scrolling through
// every branch.
//
// ── Why not mocktail fakes (M2.4 PHASE 1 PIVOT) ────────────────────────────
// The mocktail-followup plan was to replace this real-GoRouter harness
// with `extends Mock implements SoundService/NavigationState` mocks.
// Dart 3.4 lifts `final class` semantics to restrict BOTH `extends` and
// `implements` from outside the declaring library — confirmed by
// `flutter analyze`: every `class X extends Mock implements <final>`
// raises `invalid_use_of_type_outside_library`. Same restriction blocks
// `class X implements <final>` (without extends Mock). Phase 1 was
// therefore pivoted BACK to the real-service harness; the audio-channel
// spy preserves the bigTap observation. A future toolchain upgrade that
// loosens final-class sealing (or a refactor of `SoundService` /
// `NavigationState` to expose a public interface that mocktail can
// target) unlocks the mocktail refactor.
//
// ── Skip-on-Windows (M2.4 PHASE 2 — KNOWN ISSUE) ────────────────────────────
// Same defensive posture as `magic_colors/test/unit/home/daily_reward_claim_
// test.dart`: `@TestOn('!windows')` keeps the Win32 dev box from
// blocking on the framework-side dispose hang. macOS/Linux CI runs the
// file normally so a future Flutter SDK fix is regression-checked
// automatically. Doc header in `daily_reward_claim_test.dart` §"M2.4
// PHASE 2 — KNOWN ISSUE" is the canonical reference; this file
// mirrors the `@Tags(['m2-4-known-issue'])` + named library directive
// (Tags + TestOn attach via `Target.library` so a named library is
// required).
// =============================================================================

@Tags(<String>['m2-4-known-issue'])
@TestOn('!windows')
// ignore_for_file: unnecessary_library_name
library magic_colors_shell_tab_helpers_test;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:magic_colors/core/routing/app_router.dart'
    show GoRouterContextX;
import 'package:magic_colors/core/routing/app_routes.dart'
    show AppRoutes, HomeTab;
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/state/navigation_state.dart';

// ── Channel-level spy for bigTap ───────────────────────────────────────────

/// audioplayers' SFX pool calls the `xyz.luan/audioplayers` MethodChannel
/// with `start` / `resume` Methods when a pool entry triggers a sound.
/// The arguments map carries the AssetSource (e.g.
/// `{'source': 'audio/sfx/big_tap.ogg', ...}`). We count those calls so
/// the test can assert "`selectShellTab` invited bigTap on cross-tab, was
/// silent on same-tab".
const MethodChannel _kAudioChannel = MethodChannel('xyz.luan/audioplayers');

/// Counted by the global channel mock handler. Reset to 0 in each `setUp`.
int bigTapChannelCalls = 0;

void _incrementBigTapIfMatches(MethodCall call) {
  if (call.method != 'start' && call.method != 'resume') return;
  final Object? args = call.arguments;
  if (args is! Map) return;
  final Object? source = args['source'];
  if (source is String && source.contains('big_tap.ogg')) {
    bigTapChannelCalls++;
  }
}

// ── Test fixture widget tree ───────────────────────────────────────────────

/// One button per branch. Tap → `context.selectShellTab(tab)` then
/// `context.goShellTab(tab)` (the canonical pairing from
/// `BottomNavigation._onTap` + `HomeScreen._trackAndShell`).
class _ShellFiringButton extends StatelessWidget {
  const _ShellFiringButton({required this.tab, required this.label});

  final HomeTab tab;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Run both halves of the pipeline. selectShellTab's same-tab
        // early-out is the contract we test.
        context.selectShellTab(tab);
        context.goShellTab(tab);
      },
      child: Text(label),
    );
  }
}

GoRouter _buildMinimalShellRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        branches: <StatefulShellBranch>[
          // Branch 0 · Home ────────────────────────────────────────
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (_, __) => const _ShellFiringButton(
                  tab: HomeTab.home,
                  label: 'fire-home',
                ),
              ),
            ],
          ),
          // Branch 1 · Worlds ───────────────────────────────────────
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.worlds,
                builder: (_, __) => const _ShellFiringButton(
                  tab: HomeTab.worlds,
                  label: 'fire-worlds',
                ),
              ),
            ],
          ),
          // Branch 2 · Gallery ──────────────────────────────────────
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.gallery,
                builder: (_, __) => const _ShellFiringButton(
                  tab: HomeTab.gallery,
                  label: 'fire-gallery',
                ),
              ),
            ],
          ),
        ],
        builder: (
          BuildContext ctx,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) {
          // The shell + the canonical providers land in the same tree so
          // the button's `context.read(...)` inside `onPressed` resolves
          // to the SAME instances created in `setUp`.
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

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // The audio channel handler MUST be installed BEFORE SoundService
    // preload runs — otherwise the pool's internal `start` call races
    // against our spy and we under-count (or hit MissingPluginException
    // depending on the framework's channel-resolution order).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kAudioChannel, (MethodCall call) async {
      _incrementBigTapIfMatches(call);
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
    router = _buildMinimalShellRouter();
    bigTapChannelCalls = 0;
  });

  tearDown(() async {
    nav.dispose();
    await sound.dispose();
    router.dispose();
  });

  /// Mounts a `MaterialApp.router` whose routing tree exposes
  /// `provider<NavigationState>` + `provider<SoundService>` (with our
  /// test instances) to every descendant — then awaits pumpAndSettle so
  /// the framework's transition + post-frame queue drains. The
  /// `Scaffold(body: shell)` Inside the StatefulShellRoute builder
  /// renders the home branch's `_ShellFiringButton` for `fire-home`.
  Future<void> pumpTestApp(WidgetTester tester) async {
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

  testWidgets(
    'cross-tab tap (home → worlds): nav.currentTab flips + bigTap fires '
    'exactly once on the audio channel',
    (WidgetTester tester) async {
      await pumpTestApp(tester);
      expect(nav.currentTab, HomeTab.home);

      await tester.tap(find.text('fire-worlds'));
      await tester.pumpAndSettle();

      expect(nav.currentTab, HomeTab.worlds);
      expect(bigTapChannelCalls, 1);
    },
  );

  testWidgets(
    'same-tab tap (worlds → worlds): nav.currentTab unchanged + '
    'bigTap silent — selectShellTab early-out fires',
    (WidgetTester tester) async {
      await pumpTestApp(tester);

      // First tap is cross-tab (home → worlds) so nav actually moves.
      await tester.tap(find.text('fire-worlds'));
      await tester.pumpAndSettle();
      // Snapshot baseline AFTER the cross-tab boot — second tap is
      // now a same-tab event.
      final int bigTapAfterBoot = bigTapChannelCalls;
      expect(bigTapAfterBoot, 1,
          reason: 'boot tap must show the cross-tab baseline count');

      // Same-tab tap.
      await tester.tap(find.text('fire-worlds'));
      await tester.pumpAndSettle();

      expect(
        nav.currentTab,
        HomeTab.worlds,
        reason: 'same-tab tap must NOT change nav.currentTab',
      );
      expect(
        bigTapChannelCalls - bigTapAfterBoot,
        0,
        reason: 'selectShellTab must suppress the bigTap cue on same-tab '
            '(audio stays silent — visual pop-to-root still survives via '
            'goShellTab).',
      );
    },
  );

  testWidgets(
    'cross-tab tap (worlds → gallery): nav.currentTab flips + bigTap fires '
    'exactly once on the audio channel',
    (WidgetTester tester) async {
      await pumpTestApp(tester);

      // Boot onto worlds.
      await tester.tap(find.text('fire-worlds'));
      await tester.pumpAndSettle();
      expect(nav.currentTab, HomeTab.worlds);

      // Snapshot baseline right before the worlds→gallery tap.
      final int bigTapBeforeGallery = bigTapChannelCalls;

      await tester.tap(find.text('fire-gallery'));
      await tester.pumpAndSettle();

      expect(nav.currentTab, HomeTab.gallery);
      expect(
        bigTapChannelCalls - bigTapBeforeGallery,
        1,
        reason: 'cross-tab (worlds → gallery) must fire bigTap once',
      );
    },
  );
}
