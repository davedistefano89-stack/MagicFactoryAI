// =============================================================================
// Magic Colors · features/worlds/presentation/pages/world_detail_screen.dart
// =============================================================================
//
// Production destination for the `/worlds/:id` route. The AppRouter's
// world-detail subroute passes the resolved `worldId` (read off
// `state.pathParameters['id']` inside the router builder) into this
// widget; we look it up in a file-private `const` catalog and render
// the matching detail page.
//
// State matrix (mirrors `_IslandViewModel.resolve` inside world_map_screen.dart
// so the two surfaces agree on locked / premium-gated / unlocked semantics):
//
//   ▸ unlocked          — player owns this world OR has an active
//                         subscription AND their earned-stars pass the
//                         unlock threshold. CTA = Start Coloring
//                         → context.goColoring(worldId).
//   ▸ premium-gated     — `world.isPremiumWorld` is true but
//                         `PlayerState.isPremium` is false. CTA = See
//                         Plans → context.goPremium().
//   ▸ locked            — star threshold not yet reached (free-tier
//                         gates). CTA = dimmed "Earn N stars to unlock".
//
// The `WorldData` and `_kWorldCatalog` duplicates the world_map_screen.dart
// roster on purpose for v1.0 — keeping the single-file router-fix delivery
// tight. Sprint-4 will lift both into a shared `core/data/world_catalog.dart`
// so this file imports `WorldData` + `_kWorldCatalog` by name.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart' show AppSpacing;
import '../../../../core/routing/app_router.dart' show GoRouterContextX;
import '../../../../core/routing/app_routes.dart' show HomeTab;
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/world_unlock/completion_reward_service.dart';
import '../../../../core/services/world_unlock/world_unlock_service.dart';
import '../../../../core/domain/world/world_status.dart';
import '../../../../core/state/navigation_state.dart';
import '../../../../core/state/player_state.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/logger.dart' show logger;
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/magic_card.dart';
import '../../../../core/widgets/parent_gate.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/world_progress_catalog.dart';

// ── Frozen tuning constants ──────────────────────────────────────────────────

/// Maximum readable width on tablet / desktop. Mirrors the home shell's
/// `_kMaxReadableWidth` so the world-detail page lines up with the prose
/// column the rest of the app already uses.
const double _kMaxReadableWidth = 720.0;

/// Width at which the layout transitions from full-bleed to max-width clamp.
const double _kWidthBreakpoint = 600.0;

/// Big illustration glyph fontSize inside the hero card.
const double _kHeroGlyphSize = 96.0;

/// Sub-title `bodyXl` color reserved for the hero's "Locked" copy.
const double _kLockedGlyphAlpha = 0.55;

/// Pill horizontal padding — matches world_map_screen.dart's
/// `_kDifficultyChipHPadding`.
const double _kPillHorizontalPadding = 10.0;

/// Pill vertical padding — matches world_map_screen.dart's
/// `_kDifficultyChipVPadding`.
const double _kPillVerticalPadding = 3.0;

/// Pill glyph fontSize — matches world_map_screen.dart's `_kPillGlyphSize`.
const double _kPillGlyphSize = 14.0;

/// Fat star-meter fontSize inside `_StarsBigReadout`.
const double _kBigStarGlyphSize = 32.0;

/// Fat completion-meter width — the bar's max width in dp.
const double _kBigMeterWidth = 96.0;

/// Fat completion-meter height — matches `_kMeterHeight` convention.
const double _kBigMeterHeight = 6.0;

/// Sparkle fallback glyph used in the not-found hero.
const double _kNotFoundGlyphSize = 64.0;

/// Default start-coloring drawing id when the world doesn't yet expose a
/// per-world drawing template list. Mirrors the constant inside the home
/// shell so the two surfaces share the same fallback drawingId.
const String _kDefaultDrawingId = 'draw-now';

const String _kSemanticsRootLabel = 'World detail';
const String _kNotFoundLabel = 'Unknown world';

/// Star meter glyph (mirrors world_map_screen.dart's _kStarGlyph).
const String _kStarGlyph = '⭐';

const String _kLockGlyph = '🔒';

const String _kGemGlyph = '💎';

/// Default description strip when a world has no curated copy. Sprint-4
/// will replace this with a per-world description string.
const String _kDefaultDescription =
    'Tap Start to begin colouring. Earn three stars to unlock chest '
    'rewards.';

// =============================================================================
//  WorldDifficulty — mirrored from world_map_screen.dart for now.
// =============================================================================

enum WorldDifficulty { easy, medium, hard }

// =============================================================================
//  WorldData — mirrored from world_map_screen.dart for now.
// =============================================================================

/// Catalog row for a single world. See world_map_screen.dart for the
/// canonical definition; the Sprint-4 catalog lift will replace this
/// in-place with an import from `core/data/world_catalog.dart`.
@immutable
class WorldData {
  const WorldData({
    required this.id,
    required this.title,
    required this.glyph,
    required this.difficulty,
    required this.isPremiumWorld,
    required this.starsForUnlock,
  });

  final String id;
  final String title;
  final String glyph;
  final WorldDifficulty difficulty;
  final bool isPremiumWorld;
  final int starsForUnlock;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WorldData &&
        other.id == id &&
        other.title == title &&
        other.glyph == glyph &&
        other.difficulty == difficulty &&
        other.isPremiumWorld == isPremiumWorld &&
        other.starsForUnlock == starsForUnlock;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        glyph,
        difficulty,
        isPremiumWorld,
        starsForUnlock,
      );
}

// =============================================================================
//  _kWorldCatalog — file-private `const`. Mirrors world_map_screen.dart.
// =============================================================================

const List<WorldData> _kWorldCatalog = <WorldData>[
  WorldData(
    id: 'princess_kingdom',
    title: 'Princess Kingdom',
    glyph: '👑',
    difficulty: WorldDifficulty.easy,
    isPremiumWorld: false,
    starsForUnlock: 0,
  ),
  WorldData(
    id: 'unicorn_valley',
    title: 'Unicorn Valley',
    glyph: '🦄',
    difficulty: WorldDifficulty.easy,
    isPremiumWorld: false,
    starsForUnlock: 0,
  ),
  WorldData(
    id: 'animal_forest',
    title: 'Animal Forest',
    glyph: '🦒',
    difficulty: WorldDifficulty.medium,
    isPremiumWorld: false,
    starsForUnlock: 1,
  ),
  WorldData(
    id: 'dinosaur_island',
    title: 'Dinosaur Island',
    glyph: '🦖',
    difficulty: WorldDifficulty.medium,
    isPremiumWorld: false,
    starsForUnlock: 1,
  ),
  WorldData(
    id: 'dragon_mountain',
    title: 'Dragon Mountain',
    glyph: '🐉',
    difficulty: WorldDifficulty.hard,
    isPremiumWorld: false,
    starsForUnlock: 2,
  ),
  WorldData(
    id: 'mermaid_ocean',
    title: 'Mermaid Ocean',
    glyph: '🧜',
    difficulty: WorldDifficulty.medium,
    isPremiumWorld: false,
    starsForUnlock: 2,
  ),
  WorldData(
    id: 'space_planet',
    title: 'Space Planet',
    glyph: '🚀',
    difficulty: WorldDifficulty.hard,
    isPremiumWorld: false,
    starsForUnlock: 3,
  ),
  WorldData(
    id: 'christmas_village',
    title: 'Christmas Village',
    glyph: '🎄',
    difficulty: WorldDifficulty.easy,
    isPremiumWorld: true,
    starsForUnlock: 0,
  ),
  WorldData(
    id: 'halloween_world',
    title: 'Halloween World',
    glyph: '🎃',
    difficulty: WorldDifficulty.hard,
    isPremiumWorld: true,
    starsForUnlock: 0,
  ),
  WorldData(
    id: 'fantasy_land',
    title: 'Fantasy Land',
    glyph: '🧚',
    difficulty: WorldDifficulty.hard,
    isPremiumWorld: true,
    starsForUnlock: 0,
  ),
];

// =============================================================================
//  _resolveEarnedStars — M3 production star lookup.
//
//  Reads the persistent [PlayerState.worldStars] map (Hive-backed). The
//  `.clamp(0, 3)` guards against any future drift if a corrupted box
//  injects an out-of-range value (the design ceiling per world is 3
//  stars). Byte-identical signature to `world_map_screen.dart`'s helper
//  so a child viewing a given world on the map sees the SAME earned-
//  stars count on the detail page. The eventual Sprint-4 catalog lift
//  into `core/data/world_catalog.dart` will collapse these two file-
//  private helpers into a single shared symbol.
// =============================================================================

int _resolveEarnedStars(WorldData world, PlayerState player) {
  return player.getWorldStars(world.id).clamp(0, 3);
}

// =============================================================================
//  _findWorld — index-free lookup.
// =============================================================================

/// Linear scan over `_kWorldCatalog`. O(10) so the cost is irrelevant; a
/// `Map<int, WorldData>` lookup would allocate a second backing structure
/// for no measurable win.
WorldData? _findWorld(String worldId) {
  for (final WorldData w in _kWorldCatalog) {
    if (w.id == worldId) {
      return w;
    }
  }
  return null;
}

// =============================================================================
//  _Accent — accessibility bucket for the detail CTA.
// =============================================================================

enum _Accent { unlocked, premiumGated, lockedStarGated, unknown }

// =============================================================================
//  WorldDetailScreen — the public widget.
// =============================================================================

class WorldDetailScreen extends StatefulWidget {
  const WorldDetailScreen({super.key, required this.worldId});

  /// URL path parameter injected by the AppRouter builder. Always
  /// non-null at runtime (defaulted to the empty string in the router if
  /// the route ever resolves without a parameter, then quietly redirected
  /// to the "Unknown world" surface).
  final String worldId;

  @override
  State<WorldDetailScreen> createState() => _WorldDetailScreenState();
}

/// Sprint 4b — the screen owns the NavigationState.currentWorldId stamp
/// for its lifetime. `initState` writes the value (deferred one frame
/// so the Provider is mounted); `dispose` clears it so popping back to
/// the map doesn't leave a stale "you are here" highlight on the wrong
/// island. Lives at the screen level (not the _DetailBody) so the
/// not-found body branch also clears the stamp consistently. The
/// NavigationState reference is captured in `didChangeDependencies` so
/// `dispose` can call it without a try/catch over `context` (whose
/// Provider scope is unreliable in dispose).
class _WorldDetailScreenState extends State<WorldDetailScreen> {
  /// Captured in [didChangeDependencies] for use in [dispose].
  /// Nullable because didChangeDependencies may not have fired yet
  /// when dispose runs on a screen that was built but never painted
  /// (rare, but possible on hot-reload).
  NavigationState? _nav;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nav = context.read<NavigationState>();
  }

  @override
  void initState() {
    super.initState();
    // Defer one frame so the Provider is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NavigationState>().setCurrentWorldId(widget.worldId);
    });
  }

  @override
  void dispose() {
    _nav?.setCurrentWorldId(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      gradient: AppGradients.skyDefault,
      child: Semantics(
        label: _kSemanticsRootLabel,
        container: true,
        child: SafeArea(
          // Bottom-nav is rendered by the surrounding `_BranchScaffold`.
          // Don't claim the bottom safe area so the chrome seats flush to
          // the system gesture inset.
          bottom: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxWidth = _resolveMaxWidth(constraints.maxWidth);
              if (maxWidth.isInfinite) {
                return _DetailBody(worldId: widget.worldId);
              }
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints.tightFor(width: maxWidth),
                  child: _DetailBody(worldId: widget.worldId),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static double _resolveMaxWidth(double available) {
    if (available < _kWidthBreakpoint) {
      return double.infinity;
    }
    return _kMaxReadableWidth;
  }
}

// =============================================================================
//  _DetailBody — the actual layout (screen-state aware).
// =============================================================================

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.worldId});

  final String worldId;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();

    // Resolve a not-found world first so the empty-state has the right
    // chrome before we ask for player state.
    final WorldData? found = _findWorld(worldId);
    if (found == null) {
      return const _NotFoundBody();
    }

    final _Accent accent = _resolveAccent(world: found, player: player);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _HeroCard(world: found, accent: accent),
          AppSpacing.vGapLg,
          _Description(world: found, accent: accent),
          AppSpacing.vGapLg,
          _AccentCta(accent: accent, world: found),
          AppSpacing.vGapLg,
          _OutlineStatsRow(world: found, accent: accent, player: player),
          AppSpacing.vGapLg,
          // Sprint 6 — per-world progress section. Always visible
          // (zero-state is fine; locked worlds just show 0/3 levels
          // + the next-goal text). The reward claim CTA only renders
          // when the world is completed AND the reward hasn't been
          // claimed yet.
          _WorldProgressSection(world: found, player: player),
          AppSpacing.vGapLg,
          _GalleryShortcutRow(world: found),
        ],
      ),
    );
  }
}

/// Captured into a free function so the `_DetailBody.build` method reads
/// top-down without nested ternary chains.
_Accent _resolveAccent(
    {required WorldData world, required PlayerState player}) {
  if (world.isPremiumWorld && !player.isPremium) {
    return _Accent.premiumGated;
  }
  // M3 production — earned stars come straight from the persistent
  // PlayerState.worldStars map. The same helper is used by
  // world_map_screen.dart's `_IslandViewModel.resolve` so the two
  // surfaces never drift on the stars readout. The eventual Sprint-4
  // catalog lift into `core/data/world_catalog.dart` will collapse
  // these two file-private helpers into a single shared symbol.
  final int stableStars = _resolveEarnedStars(world, player);
  if (stableStars < world.starsForUnlock) {
    return _Accent.lockedStarGated;
  }
  return _Accent.unlocked;
}

// =============================================================================
//  _HeroCard — the big illustration + title + difficulty chip.
// =============================================================================

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.world, required this.accent});

  final WorldData world;
  final _Accent accent;

  bool get _dimmed => accent != _Accent.unlocked;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: accent == _Accent.unlocked
          ? MagicCardSkin.accent
          : MagicCardSkin.tinted,
      padding: AppSpacing.cardPaddingGenerous,
      borderColor: accent == _Accent.unlocked ? AppColors.magicPurple : null,
      borderRadius: AppCorner.brLg,
      elevation: accent == _Accent.unlocked
          ? AppElevation.elevation2
          : AppElevation.elevation1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _DifficultyChip(difficulty: world.difficulty),
              if (accent == _Accent.premiumGated) const _PremiumGatedPill(),
              if (accent == _Accent.lockedStarGated) const _LockedStarsPill(),
              if (accent == _Accent.unlocked && world.isPremiumWorld)
                const _PremiumBadge(),
            ],
          ),
          AppSpacing.vGapMd,
          Text(
            _dimmed ? _kLockGlyph : world.glyph,
            style: TextStyle(
              fontSize: _kHeroGlyphSize,
              color: _dimmed
                  ? AppColors.deepInk.withValues(alpha: _kLockedGlyphAlpha)
                  : null,
            ),
          ),
          AppSpacing.vGapMd,
          Text(
            world.title,
            textAlign: TextAlign.center,
            style: AppTypography.titleLg.copyWith(
              color: _dimmed
                  ? AppColors.deepInk.withValues(alpha: _kLockedGlyphAlpha)
                  : AppColors.deepInk,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _DifficultyChip — copy of world_map_screen.dart's chip widget.
// =============================================================================

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});

  final WorldDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final String label = switch (difficulty) {
      WorldDifficulty.easy => 'Easy',
      WorldDifficulty.medium => 'Medium',
      WorldDifficulty.hard => 'Hard',
    };
    final Color textColor = switch (difficulty) {
      WorldDifficulty.easy => AppColors.success,
      WorldDifficulty.medium => AppColors.warning,
      WorldDifficulty.hard => AppColors.tangerine,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kPillHorizontalPadding,
        vertical: _kPillVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.cloudWhite.withValues(alpha: 0.85),
        borderRadius: AppCorner.brSm,
        border: Border.all(color: textColor),
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(color: textColor),
      ),
    );
  }
}

// =============================================================================
//  _PremiumGatedPill — small "GEMS" pill; mirrors world_map_screen.dart's pill.
// =============================================================================

class _PremiumGatedPill extends StatelessWidget {
  const _PremiumGatedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kPillHorizontalPadding,
        vertical: _kPillVerticalPadding,
      ),
      decoration: const BoxDecoration(
        color: AppColors.magicPurple,
        borderRadius: AppCorner.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            _kLockGlyph,
            style: TextStyle(fontSize: _kPillGlyphSize),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'GEMS',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.cloudWhite,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _LockedStarsPill — earned-stars-not-met pill.
// =============================================================================

class _LockedStarsPill extends StatelessWidget {
  const _LockedStarsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kPillHorizontalPadding,
        vertical: _kPillVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.smoke.withValues(alpha: 0.20),
        borderRadius: AppCorner.brSm,
        border: Border.all(color: AppColors.smoke),
      ),
      child: Text(
        'EARN STARS',
        style: AppTypography.labelMd.copyWith(color: AppColors.smoke),
      ),
    );
  }
}

// =============================================================================
//  _PremiumBadge — small "PRO" pill for active Premium subscriptions.
// =============================================================================

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kPillHorizontalPadding,
        vertical: _kPillVerticalPadding,
      ),
      decoration: const BoxDecoration(
        gradient: AppGradients.playNow,
        borderRadius: AppCorner.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            _kGemGlyph,
            style: TextStyle(fontSize: _kPillGlyphSize),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'PRO',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.cloudWhite,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _Description — copy strip just below the hero.
// =============================================================================

class _Description extends StatelessWidget {
  const _Description({required this.world, required this.accent});

  final WorldData world;
  final _Accent accent;

  @override
  Widget build(BuildContext context) {
    final String copy = switch (accent) {
      _Accent.unlocked => _kDefaultDescription,
      _Accent.premiumGated => 'Premium worlds stretch the rainbow. '
          'Subscribe to colour ${world.title}.',
      _Accent.lockedStarGated => 'Earn ${world.starsForUnlock} more '
          'star${world.starsForUnlock == 1 ? '' : 's'} to open ${world.title}.',
      _Accent.unknown => _kDefaultDescription,
    };
    return Text(
      copy,
      textAlign: TextAlign.center,
      style: AppTypography.bodyXl.copyWith(
        color: accent == _Accent.unlocked ? AppColors.deepInk : AppColors.smoke,
      ),
    );
  }
}

// =============================================================================
//  _AccentCta — the primary action; state-aware label + destination.
// =============================================================================

class _AccentCta extends StatelessWidget {
  const _AccentCta({required this.accent, required this.world});

  final _Accent accent;
  final WorldData world;

  @override
  Widget build(BuildContext context) {
    switch (accent) {
      case _Accent.unlocked:
        return PrimaryButton(
          label: 'Start colouring',
          fullWidth: true,
          size: PrimaryButtonSize.jumbo,
          onPressed: () => _onStartColoring(context),
        );
      case _Accent.premiumGated:
        return PrimaryButton(
          label: 'See plans',
          fullWidth: true,
          gradient: AppGradients.tertiaryCalm,
          onPressed: () => _onSeePlans(context),
        );
      case _Accent.lockedStarGated:
        return PrimaryButton(
          label: 'Earn ${world.starsForUnlock} stars to unlock',
          fullWidth: true,
        );
      case _Accent.unknown:
        return PrimaryButton(
          label: 'Back to world map',
          fullWidth: true,
          onPressed: () => _onBackToMap(context),
        );
    }
  }

  void _onStartColoring(BuildContext context) {
    AnalyticsService.instance.trackEvent(
      'world_start_coloring_pressed',
      <String, Object?>{'id': world.id},
    );
    Haptics.heavy();
    context.goColoring(_kDefaultDrawingId);
  }

  void _onSeePlans(BuildContext context) {
    AnalyticsService.instance.trackEvent(
      'world_premium_see_plans_pressed',
      <String, Object?>{'id': world.id},
    );
    Haptics.medium();
    // M2.4 — gate the Premium upsell behind ParentGate.
    showParentGate(context).then((bool? passed) {
      if (passed == true && context.mounted) {
        context.goPremium();
      }
    });
  }

  void _onBackToMap(BuildContext context) {
    AnalyticsService.instance.trackEvent(
      'world_back_to_map_pressed',
      <String, Object?>{'id': world.id},
    );
    Haptics.selection();
    // We are inside the Worlds branch (this widget sits at /worlds/:id,
    // a subroute of StatefulShellBranch index 1) — adopt the canonical
    // shell-tab pipeline so tap-to-root semantics are honoured.
    // selectShellTab's same-tab early-out fires silently (audio muted);
    // goShellTab pops the worlds back-stack to its root regardless.
    context.selectShellTab(HomeTab.worlds);
    context.goShellTab(HomeTab.worlds);
  }
}

// =============================================================================
//  _OutlineStatsRow — secondary stats strip (stars + completion).
// =============================================================================

class _OutlineStatsRow extends StatelessWidget {
  const _OutlineStatsRow({
    required this.world,
    required this.accent,
    required this.player,
  });

  final WorldData world;
  final _Accent accent;
  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final int earnedStars =
        accent == _Accent.unlocked ? _resolveEarnedStars(world, player) : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _StarsBigReadout(
          earned: earnedStars,
          unlocked: accent == _Accent.unlocked,
        ),
        _CompletionBigReadout(
          pct: accent == _Accent.unlocked
              ? (earnedStars * 100 / 3).round().clamp(0, 100)
              : 0,
        ),
      ],
    );
  }
}

// =============================================================================
//  _StarsBigReadout — fat 3-star meter.
// =============================================================================

class _StarsBigReadout extends StatelessWidget {
  const _StarsBigReadout({required this.earned, required this.unlocked});

  final int earned;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$earned of 3 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            Text(
              _kStarGlyph,
              style: TextStyle(
                fontSize: _kBigStarGlyphSize,
                color: _starColor(index: i),
              ),
            ),
            if (i < 2) const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  Color _starColor({required int index}) {
    const Color fill = AppColors.starReward;
    final Color dim = AppColors.smoke.withValues(alpha: _kLockedGlyphAlpha);
    if (!unlocked) {
      return dim;
    }
    return index < earned ? fill : dim;
  }
}

// =============================================================================
//  _CompletionBigReadout — percent label + meter.
// =============================================================================

class _CompletionBigReadout extends StatelessWidget {
  const _CompletionBigReadout({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$pct percent complete',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$pct%',
            style: AppTypography.numericCompact.copyWith(
              color: AppColors.deepInk,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: _kBigMeterWidth,
            child: Stack(
              children: <Widget>[
                Container(
                  height: _kBigMeterHeight,
                  decoration: BoxDecoration(
                    color: AppColors.smoke.withValues(alpha: 0.20),
                    borderRadius: AppCorner.brSm,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: _kBigMeterHeight,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.secondaryCta,
                      borderRadius: AppCorner.brSm,
                      boxShadow: AppElevation.softChip,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _WorldProgressSection — Sprint 6 — per-world progress block:
//  total/completed levels, completion %, available rewards, claim
//  CTA, next goal. Sits between the existing _OutlineStatsRow and
//  the _GalleryShortcutRow so the visual hierarchy is:
//    hero → description → primary CTA → stats → progress → gallery.
//
//  Reward claim is gated by:
//    1. The world is `unlocked` (the player has earned at least
//       `starsForUnlock` stars OR owns a Premium subscription).
//    2. The world is fully completed (3 stars earned).
//    3. The reward hasn't been claimed yet
//       (PlayerState.claimedWorldRewardIds).
//  When all three are true, the section renders a tinted
//  "Claim N coins + N gems" CTA; tapping it routes through
//  CompletionRewardService.grantCompletion which mutates
//  PlayerState and fires the right analytics.
// =============================================================================

class _WorldProgressSection extends StatelessWidget {
  const _WorldProgressSection({required this.world, required this.player});

  final WorldData world;
  final PlayerState player;

  void _onClaim(BuildContext context) {
    AnalyticsService.instance.trackEvent(
      'world_completion_reward_claimed',
      <String, Object?>{'id': world.id},
    );
    Haptics.success();
    final CompletionRewardResult result =
        CompletionRewardService.grantCompletion(
      worldId: world.id,
      player: player,
    );
    logger.info(
      'WorldProgressSection.claim(${world.id}) → $result',
    );
  }

  @override
  Widget build(BuildContext context) {
    final WorldProgressLite progress = WorldProgressLite.from(
      world: world,
      player: player,
    );

    return MagicCard(
      skin: MagicCardSkin.tinted,
      padding: AppSpacing.cardPaddingGenerous,
      borderRadius: AppCorner.brLg,
      borderColor: AppColors.magicPurple.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('Progress', style: AppTypography.titleSm),
          AppSpacing.vGapSm,
          _LevelsRow(
            completed: progress.completedLevels,
            total: progress.totalLevels,
          ),
          AppSpacing.vGapSm,
          _ProgressMeter(pct: progress.completionPct),
          AppSpacing.vGapMd,
          if (progress.hasReward)
            _NextGoalCaption(progress: progress, world: world),
          if (progress.isRewardReady) ...<Widget>[
            AppSpacing.vGapMd,
            PrimaryButton(
              label: progress.claimLabel,
              fullWidth: true,
              gradient: AppGradients.playNow,
              onPressed: () => _onClaim(context),
            ),
          ] else if (progress.isRewardClaimed) ...<Widget>[
            AppSpacing.vGapMd,
            _ClaimedBadge(),
          ],
        ],
      ),
    );
  }
}

/// Lightweight view-model for the progress section. Composed off
/// PlayerState + the catalog row, so the widget stays a pure
/// function of the inputs. Decoupled from the heavier
/// WorldProgress model in `core/domain/world/` so the section can
/// render in the same frame the screen builds.
@immutable
class WorldProgressLite {
  const WorldProgressLite._({
    required this.completedLevels,
    required this.totalLevels,
    required this.completionPct,
    required this.hasReward,
    required this.isRewardReady,
    required this.isRewardClaimed,
    required this.claimLabel,
    required this.nextGoalText,
  });

  factory WorldProgressLite.from({
    required WorldData world,
    required PlayerState player,
  }) {
    final WorldStatus status = WorldUnlockService.computeStatus(
      world.id,
      isPremiumWorld: world.isPremiumWorld,
      starsForUnlock: world.starsForUnlock,
      player: player,
    );
    final int totalLevels = totalLevelsFor(world.id);
    final int completedLevels = player.getWorldStars(world.id).clamp(0, 3);
    final int pct = totalLevels == 0
        ? 0
        : (completedLevels * 100 / totalLevels).toInt().clamp(0, 100);
    final bool hasReward = CompletionRewardService.hasReward(world.id);
    final bool isClaimed = CompletionRewardService.isClaimed(player, world.id);
    final bool isReady = status == WorldStatus.completed && !isClaimed;
    final String claimLabel = _buildClaimLabel(world.id);
    final String nextGoalText = _buildNextGoal(
      world: world,
      status: status,
      completed: completedLevels,
      total: totalLevels,
    );
    return WorldProgressLite._(
      completedLevels: completedLevels,
      totalLevels: totalLevels,
      completionPct: pct,
      hasReward: hasReward,
      isRewardReady: isReady,
      isRewardClaimed: isClaimed,
      claimLabel: claimLabel,
      nextGoalText: nextGoalText,
    );
  }

  final int completedLevels;
  final int totalLevels;
  final int completionPct;
  final bool hasReward;
  final bool isRewardReady;
  final bool isRewardClaimed;
  final String claimLabel;
  final String nextGoalText;

  static String _buildClaimLabel(String worldId) {
    final dynamic r = rewardFor(worldId);
    if (r == null) return 'Claim reward';
    final int coins = (r.coins as int?) ?? 0;
    final int gems = (r.gems as int?) ?? 0;
    final List<String> parts = <String>[];
    if (coins > 0) parts.add('🪙 $coins');
    if (gems > 0) parts.add('💎 $gems');
    if (parts.isEmpty) return 'Claim reward';
    return 'Claim ${parts.join(' + ')}';
  }

  static String _buildNextGoal({
    required WorldData world,
    required WorldStatus status,
    required int completed,
    required int total,
  }) {
    switch (status) {
      case WorldStatus.locked:
        if (world.isPremiumWorld) {
          return 'Next: subscribe to open this world.';
        }
        return 'Next: earn ${world.starsForUnlock} stars to unlock.';
      case WorldStatus.available:
        if (completed >= total) {
          return 'All levels done — claim your reward below!';
        }
        return 'Next: finish ${total - completed} more '
            'level${total - completed == 1 ? '' : 's'} to claim the reward.';
      case WorldStatus.current:
        return 'Currently playing — finish this world to claim the reward.';
      case WorldStatus.completed:
        return 'All levels complete!';
    }
  }
}

class _LevelsRow extends StatelessWidget {
  const _LevelsRow({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          'Levels',
          style: AppTypography.labelMd.copyWith(color: AppColors.smoke),
        ),
        Text(
          '$completed / $total',
          style: AppTypography.titleSm,
        ),
      ],
    );
  }
}

class _ProgressMeter extends StatelessWidget {
  const _ProgressMeter({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$pct percent complete',
      child: Stack(
        children: <Widget>[
          Container(
            height: _kBigMeterHeight,
            decoration: BoxDecoration(
              color: AppColors.smoke.withValues(alpha: 0.20),
              borderRadius: AppCorner.brSm,
            ),
          ),
          FractionallySizedBox(
            widthFactor: (pct / 100).clamp(0.0, 1.0),
            child: Container(
              height: _kBigMeterHeight,
              decoration: const BoxDecoration(
                gradient: AppGradients.secondaryCta,
                borderRadius: AppCorner.brSm,
                boxShadow: AppElevation.softChip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextGoalCaption extends StatelessWidget {
  const _NextGoalCaption({required this.progress, required this.world});

  final WorldProgressLite progress;
  final WorldData world;

  @override
  Widget build(BuildContext context) {
    return Text(
      progress.nextGoalText,
      style: AppTypography.bodyMedium.copyWith(color: AppColors.smoke),
    );
  }
}

class _ClaimedBadge extends StatelessWidget {
  const _ClaimedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.18),
        borderRadius: AppCorner.brSm,
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('✅', style: TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Reward claimed',
            style: AppTypography.titleSm.copyWith(
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _GalleryShortcutRow — Sprint 4b — secondary CTA that opens the
//  Gallery filtered to this world. Sets NavigationState.galleryFilterWorldId
//  so the Gallery honours the filter on first paint, then navigates.
//  Lives below the primary CTA so the "Start colouring" button stays
//  the dominant action.
// =============================================================================

class _GalleryShortcutRow extends StatelessWidget {
  const _GalleryShortcutRow({required this.world});

  final WorldData world;

  void _openGallery(BuildContext context) {
    AnalyticsService.instance.trackEvent(
      'world_gallery_shortcut_pressed',
      <String, Object?>{'id': world.id},
    );
    Haptics.light();
    context.read<NavigationState>().setGalleryFilterWorldId(world.id);
    context.goGallery();
  }

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.blank,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      borderRadius: AppCorner.brLg,
      borderColor: AppColors.magicPurple.withValues(alpha: 0.18),
      onTap: () => _openGallery(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text('🎨', style: TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'My drawings in ${world.title}',
            style: AppTypography.titleSm,
          ),
          const Spacer(),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.magicPurple,
            size: 22,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _NotFoundBody — graceful empty-state when the URL points at an id that
//  isn't in the catalog (deep-link failure, hand-edited URL).
// =============================================================================

class _NotFoundBody extends StatelessWidget {
  const _NotFoundBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🪄', style: TextStyle(fontSize: _kNotFoundGlyphSize)),
            AppSpacing.vGapLg,
            Text(
              _kNotFoundLabel,
              style: AppTypography.titleMd,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapSm,
            Text(
              'Pick another magical land from the world map.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.smoke,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            PrimaryButton(
              label: 'Back to world map',
              fullWidth: true,
              onPressed: () {
                AnalyticsService.instance.trackEvent(
                  'world_not_found_back_pressed',
                );
                Haptics.selection();
                // Same canonical shell-tab pipeline as the _AccentCta
                // path above — we're inside the shell, so the
                // StatefulNavigationShell Provider IS in scope.
                context.selectShellTab(HomeTab.worlds);
                context.goShellTab(HomeTab.worlds);
              },
            ),
          ],
        ),
      ),
    );
  }
}
