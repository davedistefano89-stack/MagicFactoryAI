// =============================================================================
// Magic Colors · features/home/presentation/home_screen.dart
// =============================================================================
//
// The production Home shell. Composes the six Sprint-2 widgets into a
// vertically stacked, scrollable layout that sits on top of the
// [AnimatedBackground] sky-tinted gradient:
//
//   ▸ HomeHeader        — sticky brand strip with CurrencyHUD + icon
//                         buttons + streak chip.
//   ▸ DailyRewardCard   — focus-pulsed chest CTA driven by PlayerState.
//   ▸ MascotSection     — unicorn hero greeting + sparkle ornament.
//   ▸ PlayButton        — jumbo pink-glow CTA → /coloring/:id.
//   ▸ EventBanner       — accent-skin Daily Event card → /coloring/:id.
//   ▸ QuickActions      — 6-tile grid: gallery · worlds · rewards ·
//                         shop · parents · premium.
//
// Shell routes (Collection · Worlds · Shop) call [NavigationState.selectTab]
// + [BuildContext.goSwitchTab] so the active StatefulShellBranch stays a
// single source of truth. Full-screen routes (Rewards · Parents ·
// Premium) use [BuildContext.go] directly; the same property is asserted
// by every tap and pinned via the BuildContextX extension so call sites
// survive URL-table refactors in `app_routes.dart`.
//
// `LayoutBuilder` clamps the content width on tablet / desktop so reading
// rows never exceed ~ [_kMaxReadableWidth] dp. SingleChildScrollView keeps
// the bottom-nav-friendly breathing room after the QuickActions grid and
// avoids a custom scroll controller in v1.0 (parity with the other
// branch destinations).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/routing/app_router.dart' show GoRouterContextX;
import '../../../core/routing/app_routes.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/parent_gate.dart';
import '../home_controller.dart';
import 'widgets/daily_reward_card.dart';
import 'widgets/event_banner.dart';
import 'widgets/home_header.dart';
import 'widgets/mascot_section.dart';
import 'widgets/play_button.dart';
import 'widgets/quick_actions.dart';
import '../../daily/presentation/widgets/daily_challenge_card.dart';
import '../../daily/presentation/widgets/daily_reward_dialog.dart';

// ── Frozen tuning constants ─────────────────────────────────────────────────

/// Maximum content width on tablet / desktop so reading rows never
/// exceed ~ a comfortable prose column. Mirrors
/// `AppResponsive.maxReadableContentWidth` in design_tokens.dart without
/// a hard cross-package dependency.
const double _kMaxReadableWidth = 720.0;

/// Width at which the layout transitions from full-bleed (phone portrait)
/// to a capped max-width column (tablet portrait+).
const double _kWidthBreakpoint = 600.0;

/// Default id used when wiring the "PLAY NOW" buttons into the coloring
/// canvas. The router resolves it to `/coloring/draw-now`. Real template
/// ids (e.g. `mermaid`, `unicorn`) ship with the world pack in Sprint-3.
const String _kDefaultDrawingId = 'draw-now';

const String _kSemanticsRootLabel = 'Home Screen';

const String _kEventTitle = 'Color the Mermaid';
const String _kEventSubtitle =
    "Today's free coloring page — swim through rainbow coral.";

// =============================================================================
//  HomeScreen — public widget, the Home branch destination.
// =============================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: SafeArea(
        // The bottom-nav is rendered by the surrounding shell's
        // `_BranchScaffold`. Don't claim the bottom safe area here so the
        // nav bar seats flush against the system gesture inset.
        bottom: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return _CenteredContent(
              maxWidth: _resolveMaxWidth(constraints.maxWidth),
              callbacks: _HomeScreenCallbacks.from(context),
            );
          },
        ),
      ),
    );
  }

  /// Picks a max content width per breakpoint so the column never stretches
  /// wider than [_kMaxReadableWidth] on tablets / desktop. Phone portrait
  /// returns [double.infinity] which `_CenteredContent` short-circuits to a
  /// pass-through, avoiding a redundant alignment pass.
  static double _resolveMaxWidth(double available) {
    if (available < _kWidthBreakpoint) {
      return double.infinity;
    }
    return _kMaxReadableWidth;
  }
}

// =============================================================================
//  _CenteredContent — width-clamped content frame + scrollable column.
// =============================================================================

/// Combines the responsive max-width clamp with the actual scrollable
/// column stack. Single class so `_HomeScreen.build` stays a one-liner
/// and the layout tree below is a clean read-as-document.
class _CenteredContent extends StatelessWidget {
  const _CenteredContent({required this.maxWidth, required this.callbacks});

  final double maxWidth;
  final _HomeScreenCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final Widget scrollView = _HomeScrollView(callbacks: callbacks);

    if (maxWidth.isInfinite) {
      // Phone portrait — return the scroll view unchanged. No Align /
      // ConstrainedBox indirection so hot-reload rebuilds stay O(1).
      return scrollView;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: maxWidth),
        child: scrollView,
      ),
    );
  }
}

// =============================================================================
//  _HomeScrollView — vertical stack of the six Sprint-2 widgets.
// =============================================================================

class _HomeScrollView extends StatelessWidget {
  const _HomeScrollView({required this.callbacks});

  final _HomeScreenCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _kSemanticsRootLabel,
      container: true,
      child: SingleChildScrollView(
        // iOS-style bounce panning keeps the screen feeling alive for the
        // 4-year-old demographic without installing a custom physics.
        physics: const BouncingScrollPhysics(),
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HomeHeader(
              onSettingsTap: callbacks.openSettings,
              onNotificationsTap: callbacks.openNotifications,
            ),
            AppSpacing.vGapMd,
            DailyRewardCard(onClaim: callbacks.claimDailyReward),
            AppSpacing.vGapMd,
            // Sprint 7 — per-day challenges card. Sits between
            // the daily-reward card and the mascot so the visual
            // hierarchy is reward → challenges → mascot → play.
            // The ContinueBanner (which lives in the World Map)
            // is untouched per the Sprint-7 brief.
            const DailyChallengeCard(),
            AppSpacing.vGapLg,
            const MascotSection(),
            AppSpacing.vGapLg,
            PlayButton(
              label: 'PLAY NOW',
              onPressed: callbacks.openColoring,
            ),
            AppSpacing.vGapLg,
            EventBanner(
              title: _kEventTitle,
              subtitle: _kEventSubtitle,
              onPlayPressed: callbacks.openColoring,
            ),
            AppSpacing.vGapLg,
            QuickActions(
              actions: _bindQuickActions(callbacks),
            ),
            AppSpacing.vGapXl,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _HomeScreenCallbacks — bundle of navigation + analytics wires.
// =============================================================================

/// Captures per-screen callbacks in a single immutable object so the
/// build method reads top-to-bottom without burying each navigation /
/// analytics / haptic step inlined inside the widget tree. The class is
/// private so the public API of [HomeScreen] stays minimal — callers
/// only see the `_HomeScreenCallbacks` factory call.
@immutable
class _HomeScreenCallbacks {
  const _HomeScreenCallbacks({
    required this.openSettings,
    required this.openNotifications,
    required this.claimDailyReward,
    required this.openColoring,
    required this.openRewards,
    required this.openGallery,
    required this.openWorlds,
    required this.openShop,
    required this.openParents,
    required this.openPremium,
    required this.openShellTab,
  });

  /// Build a fresh callbacks bundle from a [BuildContext]. Each member is
  /// a pure `VoidCallback` (or [ValueChanged<HomeTab>]) so the bundle is
  /// independent of the widget tree — re-binding on every rebuild costs
  /// the O(6) tile roster + ~10 closures.
  factory _HomeScreenCallbacks.from(BuildContext context) {
    return _HomeScreenCallbacks(
      openSettings: () => _trackAnd(
        context,
        eventName: 'home_settings_pressed',
        haptic: Haptics.selection,
        act: (BuildContext c) => c.goSettings(),
      ),
      openNotifications: () => _trackAnd(
        context,
        eventName: 'home_notifications_pressed',
        haptic: Haptics.selection,
        act: (BuildContext c) => c.goRewards(),
      ),
      claimDailyReward: () async {
        // Delegate every claim to the controller; the home_screen no
        // longer owns the streak → engine → grant → haptic → snapshot
        // pipeline. Both this file and RewardsScreen were duplicating
        // the same logic; the controller is the single owner now.
        final controller = context.read<HomeController>();
        final reward = await controller.onClaimDailyReward();
        if (reward == null) return; // already-claimed OR engine error
        // Track AFTER the await — the analytics event must reflect a
        // real player action (i.e. a non-null reward). The controller
        // owns haptics + audio; this callback owns the analytics layer
        // because the event name is screen-specific.
        AnalyticsService.instance.trackEvent(
          'home_daily_claimed',
          <String, Object?>{'streak': controller.streakDays},
        );
        // Sprint 7 — pop the celebration dialog after a successful
        // claim. `context.mounted` guards against the home shell
        // being torn down while the controller was awaiting the
        // grant (e.g. quick logout). The summary is computed
        // AFTER the claim so the dialog renders the new bundle
        // (coins + gems + optional item for day 3/5/7).
        if (!context.mounted) return;
        await showDailyRewardDialog(
          context,
          summary: controller.dailyRewardSummary(),
        );
      },
      openColoring: () => _trackAnd(
        context,
        eventName: 'home_play_now_pressed',
        haptic: Haptics.heavy,
        act: (BuildContext c) =>
            c.goColoring(AppRoutes.coloringFor(_kDefaultDrawingId)),
      ),
      openRewards: () => _trackAnd(
        context,
        eventName: 'home_tile_rewards_pressed',
        haptic: Haptics.light,
        act: (BuildContext c) => c.goRewards(),
      ),
      openGallery: () => _trackAndShell(
        context,
        eventName: 'home_tile_collection_pressed',
        tab: HomeTab.gallery,
      ),
      openWorlds: () => _trackAndShell(
        context,
        eventName: 'home_tile_worlds_pressed',
        tab: HomeTab.worlds,
      ),
      openShop: () => _trackAndShell(
        context,
        eventName: 'home_tile_shop_pressed',
        tab: HomeTab.shop,
      ),
      openParents: () {
        AnalyticsService.instance.trackEvent('home_tile_parents_pressed');
        Haptics.medium();
        // M2.4 — gate the Parents Area behind ParentGate.
        showParentGate(context).then((bool? passed) {
          if (passed == true && context.mounted) {
            context.goSettings();
          }
        });
      },
      openPremium: () {
        AnalyticsService.instance.trackEvent('home_tile_premium_pressed');
        Haptics.medium();
        // M2.4 — gate Premium behind ParentGate.
        showParentGate(context).then((bool? passed) {
          if (passed == true && context.mounted) {
            context.goPremium();
          }
        });
      },
      openShellTab: (HomeTab tab) => _trackAndShell(
        context,
        eventName: 'home_select_tab',
        tab: tab,
      ),
    );
  }

  final VoidCallback openSettings;
  final VoidCallback openNotifications;
  final VoidCallback claimDailyReward;
  final VoidCallback openColoring;
  final VoidCallback openRewards;
  final VoidCallback openGallery;
  final VoidCallback openWorlds;
  final VoidCallback openShop;
  final VoidCallback openParents;
  final VoidCallback openPremium;
  final ValueChanged<HomeTab> openShellTab;
}

// =============================================================================
//  Routing pipelines — shared by every tile / CTA.
// =============================================================================

/// Standard "tap" pipeline used by every full-screen-route callback:
/// track → haptic → navigate. Bound once so every call site is a single
/// expression in `_HomeScreenCallbacks.from`.
void _trackAnd(
  BuildContext context, {
  required String eventName,
  required Future<void> Function() haptic,
  required void Function(BuildContext) act,
}) {
  AnalyticsService.instance.trackEvent(eventName);
  // The Future returned by `Haptics.*` is intentionally unawaited —
  // awaiting would block the tap callback for the haptic-engine's
  // millisecond-range workload. Discarding the future is the official
  // Channel Hygiene pattern from docs/design_system/06_HAPTICS.md.
  // ignore: discarded_futures
  haptic();
  act(context);
}

/// Pipeline used by every shell-tab navigation: track + haptic + update
/// the NavigationState mirror + go to the shell branch root in a single
/// transaction. The mirror + router pair is critical: without calling
/// `NavigationState.selectTab`, the rest of the app would still read the
/// stale `_currentTab` even after the visual branch has swapped.
void _trackAndShell(
  BuildContext context, {
  required String eventName,
  required HomeTab tab,
}) {
  AnalyticsService.instance.trackEvent(eventName);
  // ignore: discarded_futures
  Haptics.selection();
  // Bottom-tab switch pipeline — single source of truth lives in
  // core/routing/app_router.dart:
  //   ▸ selectShellTab — NavigationState mirror + MagicSound.bigTap
  //                     (same-tab early-out is silent).
  //   ▸ goShellTab    — StatefulNavigationShell.goBranch preserving
  //                     per-branch stacks + tap-to-root semantics.
  // Tile parity with `_onTap` (core/widgets/bottom_navigation.dart).
  context.selectShellTab(tab);
  context.goShellTab(tab);
}

// =============================================================================
//  _bindQuickActions — canonical spec → callback mapper.
// =============================================================================

/// Single source of truth for the [QuickActions] spec roster. Keeps the
/// labels / glyphs / semantics static so a reorder is a literal
/// edit-and-rebuild, and binds each spec's `onTap` to the matching
/// callback on the supplied [_HomeScreenCallbacks] bundle.
///
/// The `switch (spec.label)` dispatch is label-keyed (rather than
/// index-keyed) so reordering the visual tiles automatically reorders
/// every analytics dashboard. If two tiles ever share a label the
/// reviewer pass will catch the dead branch at the compile site.
List<QuickActionSpec> _bindQuickActions(_HomeScreenCallbacks callbacks) {
  // Label-indexed spec roster — keyed off [_resolveOnTap]'s switch so
  // each label maps deterministically to its callback. Non-const because
  // `QuickActionSpec.onTap` is a `VoidCallback` and can't be const-folded.
  return <QuickActionSpec>[
    QuickActionSpec(
      label: 'Collection',
      glyph: '🎨',
      semanticLabel: 'Open my drawings gallery',
      onTap: _resolveOnTap(callbacks, 'Collection'),
    ),
    QuickActionSpec(
      label: 'Worlds',
      glyph: '🌍',
      semanticLabel: 'Browse magical worlds',
      onTap: _resolveOnTap(callbacks, 'Worlds'),
    ),
    QuickActionSpec(
      label: 'Rewards',
      glyph: '🏆',
      semanticLabel: 'Open rewards',
      onTap: _resolveOnTap(callbacks, 'Rewards'),
    ),
    QuickActionSpec(
      label: 'Shop',
      glyph: '🛍️',
      semanticLabel: 'Open shop',
      onTap: _resolveOnTap(callbacks, 'Shop'),
    ),
    QuickActionSpec(
      label: 'Parents',
      glyph: '👨‍👩‍👧',
      semanticLabel: 'Open parents area',
      onTap: _resolveOnTap(callbacks, 'Parents'),
    ),
    QuickActionSpec(
      label: 'Premium',
      glyph: '👑',
      semanticLabel: 'Open premium subscription',
      isPremiumTile: true,
      onTap: _resolveOnTap(callbacks, 'Premium'),
    ),
  ];
}

/// Map a tile label (`'Collection'` | `'Worlds'` | …) to its tap callback.
/// File-private because the set of valid labels is owned by the bind
/// pass above — adding a tile is a single literal + switch-arm edit.
VoidCallback _resolveOnTap(_HomeScreenCallbacks c, String label) {
  switch (label) {
    case 'Collection':
      return c.openGallery;
    case 'Worlds':
      return c.openWorlds;
    case 'Rewards':
      return c.openRewards;
    case 'Shop':
      return c.openShop;
    case 'Parents':
      return c.openParents;
    case 'Premium':
      return c.openPremium;
    default:
      // Unreachable in production: the const roster above is the only
      // input to `_bindQuickActions`. Keeping the no-op fallback so the
      // `prefer-switch-with-default` lint family stays satisfied without
      // a `// ignore:` comment on every call site.
      return () {};
  }
}
