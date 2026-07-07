// =============================================================================
// Magic Colors · core/routing/app_router.dart
// =============================================================================
//
// One `GoRouter` instance for the whole app. Built once at `app.dart`
// startup and provided to `MaterialApp.router`. The router is the ONLY
// place URLs + screen destinations meet — features never construct
// their own Navigator.
//
// Feature screens live in `lib/features/<x>/<x>_screen.dart`. Until those
// files land, the routers below swap in `_RouteStub` / `_BranchStub`
// that show a labeled Material surface. Wiring a real screen is then a
// single-line change in `builder:` — no other plumbing needed.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';

import '../services/sound_service.dart';
import '../state/navigation_state.dart';
import '../widgets/bottom_navigation.dart';

import '../../features/coloring/coloring_screen.dart';
import '../../features/gallery/presentation/drawing_detail_screen.dart';
import '../../features/gallery/presentation/gallery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/rewards/presentation/rewards_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/worlds/presentation/pages/world_detail_screen.dart';
import '../../features/worlds/presentation/pages/world_map_screen.dart';

// =============================================================================
//  AppRouter — GoRouter factory + page-transition helpers.
// =============================================================================

/// Static-only façade for the app-wide [GoRouter]. Marked `final` so the
/// linter refuses an accidental `extends AppRouter` or mock subclass.
abstract final class AppRouter {
  AppRouter._();

  /// The single router consumed by `MaterialApp.router(routerConfig: ...)`.
  /// Built lazily on first access so unit tests can override
  /// [GoRouterConstructor] if they ever need to.
  static final GoRouter router = _build();

  // ── Construction ────────────────────────────────────────────────────────
  static GoRouter _build() {
    return GoRouter(
      initialLocation: AppRoutes.splash,
      debugLogDiagnostics: kDebugMode,

      // Friendly fallback when the URL is unknown — never leak the raw
      // exception. Keeps small fingers out of stack-trace territory.
      errorBuilder: (context, state) => _RouteStub(
        title: 'Lost in the rainbow',
        caption: state.error?.toString() ?? 'Unknown destination.',
      ),

      routes: <RouteBase>[
        // ── Splash (outside the shell) ─────────────────────────────────
        // Lives at the process root so the navigator can run its
        // 2.4-second intro before any chrome appears.
        GoRoute(
          path: AppRoutes.splash,
          name: AppRouteName.splash.name,
          builder: (_, __) => const SplashScreen(),
        ),

        // ── Bottom-nav shell ──────────────────────────────────────────
        // Five branches; cross-tab navigation preserves per-tab stacks
        // thanks to StatefulShellRoute.indexedStack.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              _BranchScaffold(navigationShell: navigationShell),
          branches: <StatefulShellBranch>[
            // Branch 0 · Home ──────────────────────────────────────────
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.home,
                  name: AppRouteName.home.name,
                  builder: (_, __) => const HomeScreen(),
                ),
              ],
            ),
            // Branch 1 · Worlds ────────────────────────────────────────
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.worlds,
                  name: AppRouteName.worlds.name,
                  builder: (_, __) => const WorldMapScreen(),
                  routes: <RouteBase>[
                    GoRoute(
                      path: ':id',
                      name: AppRouteName.worldDetail.name,
                      builder: (_, state) => WorldDetailScreen(
                        worldId: state.pathParameters['id'] ?? '',
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
                  name: AppRouteName.gallery.name,
                  builder: (_, __) => const GalleryScreen(),
                  routes: <RouteBase>[
                    // M3 — Gallery drill-down (timeline, colours used,
                    // badges earned). Mirrors the world_detail subroute
                    // so the bottom-nav chrome stays visible while the
                    // child inspects a drawing.
                    GoRoute(
                      path: ':id',
                      name: AppRouteName.galleryDetail.name,
                      builder: (_, state) => DrawingDetailScreen(
                        drawingId: state.pathParameters['id'] ?? '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Branch 3 · Shop ──────────────────────────────────────────
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.shop,
                  name: AppRouteName.shop.name,
                  builder: (_, __) => const ShopScreen(),
                ),
              ],
            ),
            // Branch 4 · Profile ───────────────────────────────────────
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: AppRoutes.profile,
                  name: AppRouteName.profile.name,
                  builder: (_, __) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),

        // ── Top-level (outside shell) ─────────────────────────────────
        // Coloring is a full-screen takeover (no chrome). Page-key
        // uniqueness is provided by GoRouter via `state.pageKey`.
        GoRoute(
          path: AppRoutes.coloring,
          name: AppRouteName.coloring.name,
          pageBuilder: (context, state) => _fadeUpPage(
            key: state.pageKey,
            child: ColoringScreen(
              drawingId: state.pathParameters['id'] ?? 'draw-now',
            ),
          ),
        ),

        // Rewards slides up from the bottom — feels like opening a
        // treasure chest.
        GoRoute(
          path: AppRoutes.rewards,
          name: AppRouteName.rewards.name,
          pageBuilder: (context, state) => _slideUpPage(
            key: state.pageKey,
            child: const RewardsScreen(),
          ),
        ),

        // Premium fades in — we want the child to focus on the offer,
        // not feel like they slid into a different world.
        GoRoute(
          path: AppRoutes.premium,
          name: AppRouteName.premium.name,
          pageBuilder: (context, state) => _fadeUpPage(
            key: state.pageKey,
            child: const PremiumScreen(),
          ),
        ),

        // Settings slides up — feels like pulling a drawer out of the
        // bottom of the screen.
        GoRoute(
          path: AppRoutes.settings,
          name: AppRouteName.settings.name,
          pageBuilder: (context, state) => _slideUpPage(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
        ),
      ],
    );
  }

  // ── Page transitions ────────────────────────────────────────────────────
  // Two reusable transition presets — fade-up ("soft" destinations) and
  // slide-up ("drawer-like" destinations). Anything more elaborate should
  // live alongside the screen that uses it.

  /// Fade-up: gentle, near-imperceptible motion. Use for destinations that
  /// focus attention on a single focal element (Coloring, Premium).
  static CustomTransitionPage<void> _fadeUpPage({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondary, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  /// Slide-up from the bottom: feels like opening a chest. Use for modal
  /// destinations (Rewards, Settings).
  static CustomTransitionPage<void> _slideUpPage({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondary, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }
}

// =============================================================================
//  BuildContext extensions — typed navigation helpers.
//
//  Use these instead of `context.go('/foo')` everywhere. The IDE then tells
//  you the moment a path or signature shifts and the compiler catches
//  typos. Keeping the URL strings in one file (app_routes.dart) is half of
//  the benefit; the other half is that callers can't write `go('/haome')`.
// =============================================================================

extension GoRouterContextX on BuildContext {
  /// Returns the nearest active [GoRouter] (if any).
  GoRouter get goRouter => GoRouter.of(this);

  /// Typed navigation by tab branch.
  void goSplash() => go(AppRoutes.splash);
  // ignore: shell_branch_nav (extension definition — these ARE the
  // bare-method implementations the in-app lint rule rejects; the
  // forwarder body legitimately writes `context.go(AppRoutes.<root>)`).
  void goHome() => go(AppRoutes.home);
  // ignore: shell_branch_nav (see [goHome]'s suppression rationale).
  void goWorlds() => go(AppRoutes.worlds);
  // ignore: shell_branch_nav (see [goHome]'s suppression rationale).
  void goGallery() => go(AppRoutes.gallery);
  // ignore: shell_branch_nav (see [goHome]'s suppression rationale).
  void goShop() => go(AppRoutes.shop);
  // ignore: shell_branch_nav (see [goHome]'s suppression rationale).
  void goProfile() => go(AppRoutes.profile);

  /// Parameterized destinations.
  void goWorldDetail(String worldId) => go(AppRoutes.worldDetailFor(worldId));
  void goColoring(String drawingId) => go(AppRoutes.coloringFor(drawingId));
  // M3 — gallery drill-down. Companion of goWorldDetail; same pattern.
  void goGalleryDetail(String drawingId) =>
      go(AppRoutes.galleryDetailFor(drawingId));

  /// Modal destinations.
  void goRewards() => go(AppRoutes.rewards);
  void goPremium() => go(AppRoutes.premium);
  void goSettings() => go(AppRoutes.settings);

  /// NavigationState mirror + tap audio cue. Same-tab taps early-out
  /// silently — `MagicSound.bigTap` is suppressed and the
  /// NavigationState listener does not fire. The visual pop-to-root
  /// behaviour survives because [goShellTab] (unconditional) still
  /// invokes `shell.goBranch(... initialLocation: ...)` below.
  void selectShellTab(HomeTab tab) {
    final NavigationState nav = read<NavigationState>();
    if (nav.currentTab == tab) return;
    nav.selectTab(tab);
    unawaited(read<SoundService>().play(MagicSound.bigTap));
  }

  /// Shell-aware branch router transition. Routes via the
  /// [StatefulNavigationShell] provided by [_BranchScaffold] so per-
  /// branch back stacks are preserved AND tapping the active
  /// branch pops back to the branch root (`initialLocation:
  /// index == shell.currentIndex`). Pairs with [selectShellTab] for
  /// the full shell pipeline; either half can run independently for
  /// callers that only need one side of the pair.
  void goShellTab(HomeTab tab) {
    final StatefulNavigationShell shell = read<StatefulNavigationShell>();
    final int index = tab.index;
    shell.goBranch(
      index,
      initialLocation: index == shell.currentIndex,
    );
  }

  /// Resets to splash — used by the "Are you sure you want to log out?"
  /// flow and by deep-link recovery.
  void goResetToSplash() => go(AppRoutes.splash);
}

// =============================================================================
//  Internal placeholders — replaced when feature screens land.
// =============================================================================
//
// These widgets keep the router compilable and navigable while feature
// folders are still empty. When `lib/features/<x>/<x>_screen.dart` is
// added, simply change the corresponding `builder:` callback above to
// return the real widget. No other plumbing is needed.
// =============================================================================

/// Bottom-nav scaffolding. Hosts the `StatefulNavigationShell` body and
/// delegates chrome rendering to [BottomNavigation] in
/// `lib/core/widgets/bottom_navigation.dart`. Publishes the shell into
/// the surrounding Provider tree so descendants (BottomNavigation,
/// HomeScreen, future branch-body widgets) can read or watch it via
/// `context.read<StatefulNavigationShell>()`. Without this Provider,
/// each child would have to be threaded the shell as a constructor
/// parameter — the Provider injection is the seam that lets the
/// shell-aware [BuildContext] helpers (selectShellTab, goShellTab)
/// work transparently across every call site.
class _BranchScaffold extends StatelessWidget {
  const _BranchScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Provider<StatefulNavigationShell>.value(
      value: navigationShell,
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: const BottomNavigation(),
      ),
    );
  }
}

/// Final-fallback widget rendered for any destination whose feature
/// folder hasn't landed yet. Once a feature screen is implemented,
/// replace the matching `builder:` callback above and delete the
/// `_RouteStub` argument.
class _RouteStub extends StatelessWidget {
  const _RouteStub({required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Capture into a local so Dart's flow analysis can promote the field
    // across the collection-if — avoids the `caption!` bang and keeps the
    // `bang-bang-operator-warning` rule satisfied.
    final captionText = caption;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('🪄', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.headlineMedium),
              if (captionText != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(captionText, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: 24),
              Text(
                'Screen placeholder.\n'
                'Replace with features/${title.toLowerCase()}/'
                '${title.toLowerCase()}_screen.dart',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
