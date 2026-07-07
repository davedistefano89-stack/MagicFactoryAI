// =============================================================================
// Magic Colors · core/widgets/bottom_navigation.dart
// =============================================================================
//
// The canonical 5-tab bottom navigation bar. Lives at the bottom of every
// shell branch (Home / Worlds / Gallery / Shop / Profile) — the
// [StatefulNavigationShell] from GoRouter is the parent-supplied
// navigation context.
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §8):
//   ▸ Tabs:      Home, Worlds, Gallery, Shop, Profile (in that order).
//   ▸ Surface:   AppColors.cloudWhite @ 95 % alpha (light) /
//                AppColors.skyBottomNight @ 95 % alpha (dark).
//   ▸ Indicator: AppColors.magicPink @ 18 % alpha pill (Material 3 stock).
//   ▸ Icons:     Material outlined ↔ rounded selected pair per tab. Icons
//                sized 28 dp inside an 80 dp NavigationBar.
//   ▸ Labels:    AppTypography.labelLg, magicPink for selected / smoke
//                for unselected (delegated to AppTheme.navigationBarTheme).
//   ▸ Behavior:  Tap-to-root for the current branch (initialLocation =
//                syncWithIndex); standard navigation otherwise.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../routing/app_router.dart' show GoRouterContextX;
import '../routing/app_routes.dart' show HomeTab;
import '../state/settings_state.dart';
import '../theme/app_colors.dart';

// =============================================================================
//  _NavTabSpec — internal data class for one nav tab.
// =============================================================================

class _NavTabSpec {
  const _NavTabSpec({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

// =============================================================================
//  BottomNavigation — drop-in replacement for the _ShellBottomNav fallback.
// =============================================================================

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({super.key});

  static const List<_NavTabSpec> _specs = <_NavTabSpec>[
    _NavTabSpec(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavTabSpec(
      icon: Icons.public_outlined,
      selectedIcon: Icons.public_rounded,
      label: 'Worlds',
    ),
    _NavTabSpec(
      icon: Icons.collections_bookmark_outlined,
      selectedIcon: Icons.collections_bookmark_rounded,
      label: 'Gallery',
    ),
    _NavTabSpec(
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag_rounded,
      label: 'Shop',
    ),
    _NavTabSpec(
      icon: Icons.face_outlined,
      selectedIcon: Icons.face_retouching_natural_rounded,
      label: 'Profile',
    ),
  ];

  void _onTap(BuildContext context, int index) {
    // Bottom-tab switch — runs the canonical shell pipeline (state
    // mirror + audio + shell-aware branch transition). Single source
    // of truth for each half lives in core/routing/app_router.dart:
    //   ▸ selectShellTab — NavigationState mirror + MagicSound.bigTap
    //                     (same-tab early-out is silent, visual
    //                     pop-to-root still fires via goShellTab).
    //   ▸ goShellTab    — StatefulNavigationShell.goBranch with
    //                     tap-to-root semantics (preserves stacks).
    //
    // HomeTab declaration order (home / worlds / gallery / shop /
    // profile) matches the StatefulShellRoute.indexedStack branches
    // in AppRouter._build — `HomeTab.values[index]` is the canonical
    // mapping, no separate switch table needed. `Material.Navigation
    // Bar.onDestinationSelected` guarantees a valid index per the
    // destinations list, so out-of-range won't occur in practice.
    final HomeTab newTab = HomeTab.values[index];
    context.selectShellTab(newTab);
    context.goShellTab(newTab);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the shell so the indicator pill migrates to the active
    // branch on every navigation event. The shell is provided by
    // `_BranchScaffold` (see core/routing/app_router.dart) once per
    // process via `Provider<StatefulNavigationShell>.value`.
    final shell = context.watch<StatefulNavigationShell>();
    // Watch SettingsState so the chrome re-paints when dark mode flips.
    final settings = context.watch<SettingsState>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final surface = isDark
        ? AppColors.skyBottomNight.withValues(alpha: 0.95)
        : AppColors.cloudWhite.withValues(alpha: 0.95);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.hairlineDark : AppColors.hairlineLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 80.0,
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (int idx) => _onTap(context, idx),
          backgroundColor: Colors.transparent,
          elevation: 0.0,
          destinations: <NavigationDestination>[
            for (final spec in _specs)
              NavigationDestination(
                icon: Icon(spec.icon),
                selectedIcon: Icon(spec.selectedIcon),
                label: spec.label,
              ),
          ],
        ),
      ),
    );
  }
}
