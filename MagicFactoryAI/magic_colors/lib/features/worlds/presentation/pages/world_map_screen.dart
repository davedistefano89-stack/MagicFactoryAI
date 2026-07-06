// =============================================================================
// Magic Colors · features/worlds/presentation/pages/world_map_screen.dart
// =============================================================================
//
// The Sprint-3 World Map. A magical landscape that turns the world's catalog
// into a horizontally drifting archipelago of large, rounded, breathing
// islands — every world card sits inside a [MagicCard] (so the design
// system stays the single source of truth for radii, padding, elevation
// and corner shimmer), connected visually by the [AnimatedBackground]'s
// sparkle field, and surfaced in tightly-tuned accessibility bands:
//
//   ▸ Phone portrait (< 600 dp)        → 2-col cascade
//   ▸ Phone landscape / tablet portrait → 3-col grid
//   ▸ Tablet landscape & larger         → 4-col grid
//
// All motion collapses gracefully when `SettingsState.reduceMotion` is
// true (parent-toggle for over-stimulated kids). Cloud drift pauses,
// floating islands stop swaying, the rainbow border around Premium worlds
// stops rotating, and the [OutlinePulse] for newly-unlocked worlds
// collapses to a static 2 dp hairline (its built-in path).
//
// No magic numbers leak — every layout / motion / opacity value lives at
// file scope as a `_k*` constant or is sourced from
// `core/design/design_tokens.dart`. No new colors, no new shim files, no
// re-implemented MagicCard / PrimaryButton / OutlinePulse primitives.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart'
    show AppSpacing, AppDuration;
import '../../../../core/routing/app_router.dart' show GoRouterContextX;
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/world_unlock/first_unlock_service.dart';
import '../../../../core/state/navigation_state.dart';
import '../../../../core/state/player_state.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/animated_background.dart';
import '../../../../core/widgets/magic_card.dart';
import '../../../../core/widgets/outline_pulse.dart';
import '../widgets/first_unlock_dialog.dart';

// ── Frozen tuning constants ──────────────────────────────────────────────────

/// Master float period — one cycle of the global "ocean" sway that drives
/// every island's sin-wave offset/scale. Tuned so the lowest visible
/// island appears to breathe roughly once a second after the sin curve
/// squeezes the period. Long enough to feel meditative, not lazy.
const Duration _kFloatPeriod = Duration(milliseconds: 4200);

/// Cloud drift period — one full west-to-east crossing loop. Long enough
/// the eye never sees the wrap.
const Duration _kCloudPeriod = Duration(milliseconds: 28000);

/// Rainbow shimmer period — one full rotation of the sweep gradient
/// around a Premium island's border. Slow enough to read as "shimmer",
/// not "strobe".
const Duration _kShimmerPeriod = Duration(milliseconds: 6000);

/// Per-island vertical drift amplitude (dp). Tuned to a third of the
/// standard card padding so the wobble reads as "magic" instead of
/// "loose".
const double _kFloatAmplitudeDp = 3.0;

/// Per-island scale amplitude (delta on top of 1.0). 1.00 → 1.03 sweep.
const double _kFloatScaleAmplitude = 0.03;

/// Rainbow underlay thickness around Premium tiles. 3 dp reads as a
/// glowing border without stealing real estate from the card.
const double _kRainbowBorderWidth = 3.0;

/// Star glyph size inside the 3-star meter.
const double _kStarGlyphSize = 22.0;

/// Difficulty chip vertical padding. Tight, inline-pill style.
const double _kDifficultyChipVPadding = 3.0;

/// Difficulty chip horizontal padding. Matches AppSpacing.sm / 2.
const double _kDifficultyChipHPadding = 10.0;

/// Reduced-motion glyph alpha for locked-out difficulty pills.
const double _kLockedGlyphAlpha = 0.45;

/// Outline pulse period for newly-unlocked focus rings. Reuses
/// OutlinePulse's default AppDuration.slow but is passed explicitly so
/// later redesigns don't rip the cadence out.
const Duration _kFocusPulsePeriod = AppDuration.slow;

/// Maximum number of cloud puffs painted across the visible sky band.
const int _kCloudCount = 5;

/// AppBreakpoints switchover widths (logical px) — duplicated locally to
/// avoid coupling this page to `AppBreakpoints` constants living in the
/// Foundation design_tokens.dart. Mirrors AppBreakpoints.{compact,medium,
/// expanded} without a hard cross-package import.
const double _kPhonePortraitBreakpoint = 600.0;
const double _kTabletPortraitBreakpoint = 840.0;

// ── Inline-magic-number hoisting ─────────────────────────────────────────────
//
// Lifted out of the body so the lint family around `magic_number` stays
// quiet on this file. Each token is named after the visual feature it
// controls, not the architecture-wide numbering style, so a future
// redesign reads "raise _kCloudBandFraction" rather than "edit 0.18".

/// Cloud puff base alpha. Tuned so the band reads as "soft clouds" and
/// not "fog" against the skyDefault gradient.
const double _kCloudAlpha = 0.65;

/// Lower bound of the cloud-radius fraction (relative to screenW).
const double _kCloudRadiusMinFrac = 0.06;

/// Per-cloud radius jitter fraction added on top of [_kCloudRadiusMinFrac].
const double _kCloudRadiusJitterFrac = 0.04;

/// Top-of-screen band height as a fraction of the viewport. Clouds drift
/// in this band so the lower 80 % stays clear for island cards.
const double _kCloudBandFraction = 0.18;

/// Drift multiplier — clouds travel `1.6× screenW` per loop so the wrap
/// point never lands inside the visible viewport.
const double _kCloudDriftMultiplier = 1.6;

/// Left-pad fraction so a freshly-wrapped cloud spawns just past the
/// left edge instead of mid-screen.
const double _kCloudLeftPadFraction = 0.3;

/// MaskFilter blur sigma for the cloud puff painter. Larger = softer.
const double _kCloudBlurSigma = 24.0;

/// Sparkle-emoji fontSize painted into the header right side.
const double _kSparkleGlyphSize = 28.0;

/// Big illustration glyph fontSize inside each island's [_IslandBody].
const double _kIllustrationGlyphSize = 62.0;

/// Lock / Premium pill glyph fontSize.
const double _kPillGlyphSize = 14.0;

/// Track + fill bar height of the [_CompletionMeter].
const double _kMeterHeight = 6.0;

/// Per-island phase-step divisor in the floating sin-wave. Larger =
/// looser stagger across the catalog.
const double _kFloatPhaseStep = 17.0;

/// Star-reward glyph used inside the 3-star meter.
const String _kStarGlyph = '⭐';

/// Premium banner pill glyph (gem-cluster).
const String _kPremiumGlyph = '💎';

/// Lock badge glyph.
const String _kLockGlyph = '🔒';

/// Semantics label fragments.
const String _kSemanticsRootLabel = 'Worlds map';
const String _kUnlockedFragment = 'unlocked';
const String _kLockedFragment = 'locked';
const String _kPremiumGateFragment = 'premium-only';

// =============================================================================
//  WorldDifficulty — design-time catalogue of difficulty tiers.
// =============================================================================

/// Difficulty tier rendered as a tiny inline chip beside the world title.
enum WorldDifficulty { easy, medium, hard }

// =============================================================================
//  CompletionState — Sprint 4b — 4-state lifecycle for each island.
// =============================================================================

/// Sprint 4b — explicit state enum so the island render can branch on
/// the lifecycle stage instead of recomputing it from booleans
/// (`unlocked` + `isCurrent` + `isCompleted`) at every call site.
///   • locked     — not yet reachable (premium-gated or star-gated).
///   • available  — unlocked, but not the current world and not complete.
///   • current    — the kid is inside this world right now (the world
///                  map renders an OutlinePulse + tinted border here).
///   • completed  — all 3 stars earned; renders a trophy badge and
///                  drops the difficulty chip in favour of a "DONE" pill.
enum CompletionState { locked, available, current, completed }

// =============================================================================
//  WorldData — frozen catalog entry. All allocations are `const` so the
//  page never re-allocates the world list across rebuilds.
// =============================================================================

/// Catalog row for a single world. Marked `@immutable` so callers can
/// safely compare two [WorldData] instances by value when the eventual
/// server-driven catalog lands and we need to detect drift.
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

  /// Stable id (kebab-case slug). Used as the URL path parameter for
  /// `/worlds/:id`.
  final String id;

  /// Player-facing display name.
  final String title;

  /// Emoji illustration placeholder. Real artwork ships in Sprint-4.
  final String glyph;

  /// Difficulty tier. Drives the inline difficulty chip + future
  /// star-curve tuning.
  final WorldDifficulty difficulty;

  /// True for Premium-gated worlds. When false, the world unlocks at the
  /// star threshold (or remains free).
  final bool isPremiumWorld;

  /// Stars required to unlock this world (per `PlayerState.streakDays *
  /// derivation`). Inclusive — at exactly N stars, the world unlocks.
  /// Premium worlds ignore this field (they only require
  /// `PlayerState.isPremium`).
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
//  _kWorldCatalog — top-level `const` so the list is allocated once at
//  app start. Reordering is a literal edit-and-rebuild.
// =============================================================================

/// The canonical 10-world Sprint-3 roster. Each row's `starsForUnlock`
/// is calibrated against the v1.0 mock star pool of 0…3 (see
/// [_resolveEarnedStars]).
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

/// Total catalog length — referenced by `assert`s and the responsive
/// `_resolveColumns` calculations so we never paint an empty map or an
/// off-by-one grid artifact.
const int _kWorldCatalogLength = 10;

// =============================================================================
//  WorldMapScreen — the production `/worlds` branch destination.
// =============================================================================

class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ───────────────────────────────────────────────
  /// Shared "ocean" phase ticker that drives every island's vertical drift
  /// + scale wobble. Single Ticker keeps the choreography perfectly locked.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: _kFloatPeriod,
  )..repeat();

  /// Cloud drift phase ticker. Very long loop so the wrap point is never
  /// observed. Honoured by the reduceMotion early-out in [_buildCloudLayer].
  late final AnimationController _cloud = AnimationController(
    vsync: this,
    duration: _kCloudPeriod,
  )..repeat();

  /// Rainbow-shimmer rotation phase ticker for Premium-world borders.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: _kShimmerPeriod,
  )..repeat();

  @override
  void initState() {
    super.initState();
    // Sprint 6 — trigger the FirstUnlockDialog for the first
    // uncelebrated world the player owns. One-shot per world via
    // PlayerState.celebratedWorldIds, so subsequent visits are
    // silent. Deferred one frame so the Provider is mounted and
    // the screen is laid out before the dialog is presented.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowFirstUnlockDialog();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _cloud.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  /// Sprint 6 — picks the first owned + uncelebrated world and pops
  /// the [FirstUnlockDialog]. Silently no-ops when every owned
  /// world has been celebrated. Catalog is taken from the file-
  /// private [_kWorldCatalog] so the trigger walks the same
  /// world order the map renders.
  void _maybeShowFirstUnlockDialog() {
    final PlayerState player = context.read<PlayerState>();
    final List<WorldRef> refs = <WorldRef>[
      for (final WorldData w in _kWorldCatalog)
        (
          id: w.id,
          isPremiumWorld: w.isPremiumWorld,
          starsForUnlock: w.starsForUnlock,
        ),
    ];
    final List<WorldRef> uncelebrated =
        FirstUnlockService.discoverUncelebrated(refs, player);
    if (uncelebrated.isEmpty) return;
    final WorldRef first = uncelebrated.first;
    final WorldData match = _kWorldCatalog.firstWhere(
      (WorldData w) => w.id == first.id,
      orElse: () => _kWorldCatalog.first,
    );
    showFirstUnlockDialog(
      context,
      worldId: match.id,
      worldTitle: match.title,
      worldGlyph: match.glyph,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final reduceMotion = settings.reduceMotion;
    final player = context.watch<PlayerState>();
    // Sprint 4b — read the current world from NavigationState so the
    // island grid can render the "you are here" highlight and the
    // ContinueBanner can sync the resume target to the kid's actual
    // position. NavigationState is ephemeral (process-lifetime only);
    // that's fine — the current world is a "this session" concept.
    final nav = context.watch<NavigationState>();
    final String? currentWorldId = nav.currentWorldId;

    // Pause every ticker when reduceMotion is true. Restart on flip.
    _syncTickers(reduceMotion);

    final MediaQueryData mq = MediaQuery.of(context);
    final double viewportWidth = mq.size.width;
    final bool isLandscape = mq.orientation == Orientation.landscape;

    final int columns = _resolveColumns(
      viewportWidth: viewportWidth,
      isLandscape: isLandscape,
    );

    return AnimatedBackground(
      gradient: AppGradients.skyDefault,
      child: Semantics(
        label: _kSemanticsRootLabel,
        container: true,
        child: SafeArea(
          // The bottom-nav is rendered by the surrounding shell's
          // `_BranchScaffold`. Don't claim the bottom safe area here so the
          // nav bar seats flush against the system gesture inset.
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (!reduceMotion)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: _CloudLayer(
                      controller: _cloud,
                    ),
                  ),
                ),
              _buildPage(
                columns: columns,
                player: player,
                reduceMotion: reduceMotion,
                currentWorldId: currentWorldId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks the column count per [AppBreakpoints] (delegated to local copy
  /// to avoid coupling this page to design_tokens.dart's constants family).
  ///
  /// Phone portrait (< 600)            → 2 columns.
  /// Phone landscape / tablet portrait → 3 columns.
  /// Tablet landscape or wider         → 4 columns.
  static int _resolveColumns({
    required double viewportWidth,
    required bool isLandscape,
  }) {
    if (viewportWidth < _kPhonePortraitBreakpoint) {
      return 2;
    }
    if (viewportWidth < _kTabletPortraitBreakpoint) {
      return isLandscape ? 4 : 3;
    }
    return 4;
  }

  /// Keeps all three AnimationControllers in lockstep with reduceMotion.
  /// When reduceMotion flips on, every Ticker is stopped. When it flips
  /// off, every Ticker is restarted from value 0 so the choreography
  /// pulses back into place without any visible "snap".
  void _syncTickers(bool reduceMotion) {
    final List<AnimationController> tickers = <AnimationController>[
      _float,
      _cloud,
      _shimmer,
    ];
    for (final AnimationController c in tickers) {
      if (reduceMotion) {
        if (c.isAnimating) {
          c.stop();
        }
      } else {
        if (!c.isAnimating) {
          c.repeat();
        }
      }
    }
  }

  /// The page proper — header row + a scrollable, Repaint-bounded column
  /// of world rows. Hidden from [build] so the AnimationController
  /// resolution stays top-level on the state object.
  Widget _buildPage({
    required int columns,
    required PlayerState player,
    required bool reduceMotion,
    required String? currentWorldId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MapHeader(
          reduceMotion: reduceMotion,
        ),
        _ContinueBanner(
          worldCatalog: _kWorldCatalog,
          player: player,
          currentWorldId: currentWorldId,
        ),
        _WorldLeaderboard(
          worldCatalog: _kWorldCatalog,
          player: player,
          currentWorldId: currentWorldId,
        ),
        Expanded(
          child: _WorldGrid(
            columns: columns,
            worldCatalog: _kWorldCatalog,
            player: player,
            floatController: _float,
            shimmerController: _shimmer,
            reduceMotion: reduceMotion,
            currentWorldId: currentWorldId,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  _MapHeader — top strip. Title + a soft caption.
// =============================================================================

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.reduceMotion});

  /// Honoured to align the breath animation of the title with the cloud
  /// ceiling. The caption glyph sparkles only when motion is enabled.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  'Choose your world',
                  style: AppTypography.titleLg,
                ),
              ),
              if (!reduceMotion)
                const Text(
                  '✨',
                  style: TextStyle(fontSize: _kSparkleGlyphSize),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap an unlocked island to start colouring.\n'
            'Locked islands reveal themselves once you collect stars.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.smoke,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// =============================================================================
//  _ContinueBanner — M3 first slice: featured "continue where you left off"
//  CTA pinned above the world grid. Picks the highest-starred world from
//  `PlayerState.worldStars` and renders it as a luxe-feel accent card; tap
//  drills into the existing `/worlds/:id` detail surface via the canonical
//  `GoRouterContextX.goWorldDetail` helper so the shell-branch pipeline
//  (M2.4) keeps working unchanged. Hidden when no world has earned stars
//  yet (fresh-install path).
// =============================================================================

class _ContinueBanner extends StatelessWidget {
  const _ContinueBanner({
    required this.worldCatalog,
    required this.player,
    required this.currentWorldId,
  });

  final List<WorldData> worldCatalog;
  final PlayerState player;

  /// Sprint 4b — when the kid is currently inside a world, the banner
  /// points at THAT world (so the CTA reads "continue" rather than
  /// "switch"). Null when the kid hasn't opened a world yet this
  /// session; the banner falls back to the best-stars heuristic.
  final String? currentWorldId;

  /// Sprint 4b — picks the resume target. If the kid is currently
  /// inside an UNLOCKED world, the banner anchors to it (so the CTA
  /// reads as "continue where you left off" in the actual current
  /// world, not just the best-stars one). Locked current worlds (e.g.
  /// a premium-gated world where the subscription lapsed) fall
  /// through to the highest-starred world — pointing the banner at a
  /// locked CTA would force the kid into the ParentGate. Falls back
  /// to null if every world has 0 stars (fresh-install or just-
  /// after-reset state).
  WorldData? _pickResumeTarget() {
    if (currentWorldId != null) {
      for (final WorldData w in worldCatalog) {
        if (w.id == currentWorldId && _isWorldUnlocked(w, player)) {
          return w;
        }
      }
    }
    WorldData? best;
    int bestStars = 0;
    for (final WorldData w in worldCatalog) {
      final int stars = player.worldStars[w.id] ?? 0;
      if (stars > bestStars) {
        best = w;
        bestStars = stars;
      }
    }
    return best;
  }

  /// Sprint 4b — gating check that mirrors [_IslandViewModel.resolve]'s
  /// `unlocked` derivation so the banner never points at a world the
  /// kid can't actually enter.
  static bool _isWorldUnlocked(WorldData w, PlayerState p) {
    if (w.isPremiumWorld && !p.isPremium) return false;
    return p.getWorldStars(w.id) >= w.starsForUnlock;
  }

  /// True when the picked target matches the kid's current world.
  /// Drives the "CURRENT" pill that lets the kid know the banner is
  /// pointing at where they are, not at a generic "best-stars" world.
  bool _isCurrentTarget(WorldData target) =>
      currentWorldId != null && currentWorldId == target.id;

  @override
  Widget build(BuildContext context) {
    final WorldData? target = _pickResumeTarget();
    if (target == null) {
      return const SizedBox.shrink();
    }
    final int stars = player.worldStars[target.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: MagicCard(
        skin: MagicCardSkin.accent,
        elevation: AppElevation.elevation2,
        borderColor: AppColors.tangerine,
        borderRadius: AppCorner.brLg,
        padding: AppSpacing.cardPaddingGenerous,
        onTap: () {
          AnalyticsService.instance.trackEvent(
            'worlds_continue_banner_pressed',
            <String, Object?>{'id': target.id, 'stars': stars},
          );
          Haptics.medium();
          context.goWorldDetail(target.id);
        },
        child: Row(
          children: <Widget>[
            Text(
              target.glyph,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Pick up where you left off',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.cloudWhite,
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          target.title,
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.cloudWhite,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isCurrentTarget(target)) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        const _HerePill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < 3; i++) ...<Widget>[
                        Text(
                          i < stars ? '⭐' : '☆',
                          style: const TextStyle(fontSize: 18),
                        ),
                        if (i < 2) const SizedBox(width: AppSpacing.xs),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.cloudWhite,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _WorldLeaderboard — M3 rich-overview section: per-world stars leaderboard
//  with locked/unlocked/premium-gated rows + a total-stars counter pill
//  in the header. Inserted additively between the [_ContinueBanner] hero
//  surface and the existing [_WorldGrid] island cascade.
//
//  RATIONALE
//   • Lets the kid scroll through "how many stars does each world
//     have?" without playing them in any order.
//   • Reuses the canonical [_IslandViewModel.resolve] gating matrix so
//     visual + detail-page status semantics stay in lock-step.
//   • Stars source of truth is [PlayerState.worldStars] (the persistent
//     Hive-backed map). The existing detail screen + island grid still
//     fall back to [_resolveEarnedStars] for v1.0; this leaderboard is
//     a strict-fidelity upgrade on the underlying data surface.
//
//  UX BEHAVIOUR
//   • Sort order: earned-stars DESC, tie-break by catalog index (so the
//     "top stars" line up predictably across runs).
//   • Tap a row → `context.goWorldDetail(world.id)`. Locked + premium-gated
//     rows remain dead taps here so the kid doesn't accidentally fire the
//     ParentGate dialog from a scrolling mistake.
// =============================================================================

class _WorldLeaderboard extends StatelessWidget {
  const _WorldLeaderboard({
    required this.worldCatalog,
    required this.player,
    required this.currentWorldId,
  });

  /// World catalog (typically [_kWorldCatalog]).
  final List<WorldData> worldCatalog;

  /// PlayerState read — owned by the parent [_WorldMapScreenState.build].
  final PlayerState player;

  /// Sprint 4b — the kid's current world, drives the "you are here"
  /// highlight on the leaderboard row matching [currentWorldId].
  final String? currentWorldId;

  /// Bounded height in dp. Sized so the MapHeader + ContinueBanner +
  /// ~3 visible leaderboard rows still leave enough flex space for
  /// [_WorldGrid] to surface at least the first row of islands above the
  /// fold on a 600 dp phone-portrait. Code-review M3 pass flagged the
  /// previous 320 dp ceiling as too tall (it squeezed the grid down to
  /// ~80 dp above-the-fold). The internal ListView bounces so the
  /// remaining entries still scroll into view.
  static const double _kLeaderboardVisibleHeight = 210.0;

  /// Maximum stars the player can earn across [_kWorldCatalogLength]
  /// worlds (3 stars per world). Used by the "X/N stars" pill.
  static int get _maxStars => _kWorldCatalogLength * 3;

  @override
  Widget build(BuildContext context) {
    // Sort the catalog by earned stars DESC; tie-break by catalog index
    // so the leaderboard reads as a stable, predictable ranking.
    final List<WorldData> sorted = <WorldData>[...worldCatalog];
    sorted.sort((WorldData a, WorldData b) {
      final int sa = player.getWorldStars(a.id);
      final int sb = player.getWorldStars(b.id);
      if (sa != sb) {
        return sb.compareTo(sa);
      }
      return worldCatalog.indexOf(a).compareTo(worldCatalog.indexOf(b));
    });

    // Total stars across every world (clamped per-world so a corrupted
    // map can never inflate the running total past the design ceiling).
    final int collectedStars = player.worldStars.values
        .where((int s) => s > 0)
        .fold<int>(0, (int sum, int s) => sum + s.clamp(0, 3));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // M3 polish — inline caption (replaces the standalone
          // `_LeaderboardHeader` widget + its purple pill). The previous
          // pill competed with `_ContinueBanner`'s accent hero at the top
          // of the page; folding the counter into a plain caption text
          // restores a single hero to the page and deletes ~30 LOC.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    'World Leaderboard',
                    style: AppTypography.titleSm,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '⭐ $collectedStars/$_maxStars stars',
                  style: AppTypography.caption(color: AppColors.deepInk),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _kLeaderboardVisibleHeight,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: sorted.length,
              itemBuilder: (BuildContext context, int index) {
                return _LeaderboardRow(
                  world: sorted[index],
                  earnedStars: player.getWorldStars(sorted[index].id),
                  player: player,
                  isCurrent: currentWorldId == sorted[index].id,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _LeaderboardRow — single per-world row with stars meter + status pill.
// =============================================================================

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.world,
    required this.earnedStars,
    required this.player,
    required this.isCurrent,
  });

  final WorldData world;
  final int earnedStars;
  final PlayerState player;

  /// Sprint 4b — true when this row matches the kid's current world.
  /// The leaderboard row gets a tinted left border + "HERE" pill so
  /// the kid sees their position even on the dense list surface.
  final bool isCurrent;

  bool get _isPremiumGate => world.isPremiumWorld && !player.isPremium;

  /// True iff this row should be tappable (jump-to-detail). Matches
  /// [_WorldIsland]'s `onTap: vm.unlocked` rule so the two surfaces
  /// never diverge — locked + premium-gated tiles stay dead taps so the
  /// kid can't accidentally fire the ParentGate dialog from a scroll.
  bool get _tapEnabled =>
      !_isPremiumGate && earnedStars >= world.starsForUnlock;

  /// Sprint 4b — resolve the row's left border colour. The current
  /// world gets a tinted border that reads as a "you are here" pin;
  /// the rest fall back to the original (light or dim) palette.
  Color _rowBorderColor(Color fallback) =>
      isCurrent ? AppColors.magicPink : fallback;

  @override
  Widget build(BuildContext context) {
    final Color rowBg = _tapEnabled
        ? AppColors.cloudWhite.withValues(alpha: 0.85)
        : AppColors.smoke.withValues(alpha: 0.12);
    final Color rowBorder = _rowBorderColor(
      _tapEnabled
          ? AppColors.magicPurple.withValues(alpha: 0.20)
          : AppColors.smoke.withValues(alpha: 0.32),
    );
    final double rowBorderWidth = isCurrent ? 2.5 : 1.0;
    final Color titleColor = _tapEnabled
        ? AppColors.deepInk
        : AppColors.deepInk.withValues(alpha: _kLockedGlyphAlpha);

    // TalkBack/VoiceOver announce: the row title + earned-stars count,
    // plus "locked" when the tap is gated. `InkWell(onTap: null)` would
    // otherwise report itself as not-a-button and lose the lock signal —
    // the inner status pill text is the only other accessible surface and
    // it's brittle to TextOverflow/font-size changes. Mirrors the
    // Semantics wrapper inside `_WorldIsland._buildCell` so screen-reader
    // users get equivalent context here as on the grid.
    return Semantics(
      button: _tapEnabled,
      // M3 a11y — three-arm gate reason so a VoiceOver/TalkBack child
      // hearing "0 of 3 stars, locked" for a Premium-only world doesn't
      // try to grind stars that don't help: the actual reason is the
      // subscription gate, not the star grind.
      label: '${world.title}, $earnedStars of 3 stars'
          '${_tapEnabled ? '' : _isPremiumGate ? ', premium-only' : ', locked'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: AppCorner.brMd,
            border: Border.all(color: rowBorder, width: rowBorderWidth),
          ),
          child: InkWell(
          borderRadius: AppCorner.brMd,
          onTap: _tapEnabled
              ? () {
                  AnalyticsService.instance.trackEvent(
                    'worlds_leaderboard_row_pressed',
                    <String, Object?>{
                      'id': world.id,
                      'stars': earnedStars,
                    },
                  );
                  Haptics.light();
                  context.goWorldDetail(world.id);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  world.glyph,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        world.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: titleColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _MiniStarsRow(
                        earned: earnedStars,
                        unlocked: _tapEnabled,
                      ),
                    ],
                  ),
                ),
                _LeaderboardStatusPill(
                  world: world,
                  isPremiumGate: _isPremiumGate,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

// =============================================================================
//  _MiniStarsRow — compact 3-star meter for a leaderboard row.
// =============================================================================

class _MiniStarsRow extends StatelessWidget {
  const _MiniStarsRow({required this.earned, required this.unlocked});

  final int earned;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          Text(
            i < earned ? '⭐' : '☆',
            style: TextStyle(
              fontSize: _kStarGlyphSize * 0.64,
              color: _starColor(index: i),
            ),
          ),
          if (i < 2) const SizedBox(width: 2),
        ],
      ],
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
//  _LeaderboardStatusPill — right-side status badge. Mirrors the pill
//  family in [_WorldIsland] / world_detail_screen but rendered at the
//  higher density of a list row.
// =============================================================================

class _LeaderboardStatusPill extends StatelessWidget {
  const _LeaderboardStatusPill({
    required this.world,
    required this.isPremiumGate,
  });

  final WorldData world;
  final bool isPremiumGate;

  static const double _kPillMiniFontSize = 11.0;

  @override
  Widget build(BuildContext context) {
    if (isPremiumGate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: const BoxDecoration(
          color: AppColors.magicPurple,
          borderRadius: AppCorner.brSm,
        ),
        child: const Text(
          '🔒 GEMS',
          style: TextStyle(
            fontSize: _kPillMiniFontSize,
            color: AppColors.cloudWhite,
          ),
        ),
      );
    }
    // Premium world + active Premium subscription → PRO badge.
    if (world.isPremiumWorld) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: const BoxDecoration(
          gradient: AppGradients.playNow,
          borderRadius: AppCorner.brSm,
        ),
        child: const Text(
          '💎 PRO',
          style: TextStyle(
            fontSize: _kPillMiniFontSize,
            color: AppColors.cloudWhite,
          ),
        ),
      );
    }
    // Free tier not yet at unlock threshold → EARN STARS pill.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.smoke.withValues(alpha: 0.20),
        borderRadius: AppCorner.brSm,
        border: Border.all(color: AppColors.smoke),
      ),
      child: Text(
        'EARN STARS',
        style: AppTypography.labelMd.copyWith(
          fontSize: _kPillMiniFontSize,
          color: AppColors.smoke,
        ),
      ),
    );
  }
}

// =============================================================================
//  _WorldGrid — paged column of world rows.
// =============================================================================

class _WorldGrid extends StatelessWidget {
  const _WorldGrid({
    required this.columns,
    required this.worldCatalog,
    required this.player,
    required this.floatController,
    required this.shimmerController,
    required this.reduceMotion,
    required this.currentWorldId,
  });

  final int columns;
  final List<WorldData> worldCatalog;
  final PlayerState player;
  final AnimationController floatController;
  final AnimationController shimmerController;
  final bool reduceMotion;

  /// Sprint 4b — the kid's current world. Threaded to every row so the
  /// island that matches gets the "you are here" highlight.
  final String? currentWorldId;

  @override
  Widget build(BuildContext context) {
    final List<List<WorldData>> rows = _chunkRows(worldCatalog, columns);

    return RepaintBoundary(
      child: ListView.builder(
        // iOS-style bounce panning keeps the screen feeling alive for the
        // 4-year-old demographic without an exotic physics.
        physics: const BouncingScrollPhysics(),
        // Bottom padding leaves room for the bottom-nav chrome rendered
        // by the surrounding `_BranchScaffold`.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: rows.length,
        itemBuilder: (BuildContext context, int index) {
          final List<WorldData> row = rows[index];
          return _WorldRow(
            key: ValueKey<int>(index),
            rowIndex: index,
            worlds: row,
            columns: columns,
            player: player,
            floatController: floatController,
            shimmerController: shimmerController,
            reduceMotion: reduceMotion,
            currentWorldId: currentWorldId,
          );
        },
      ),
    );
  }

  /// Splits the catalog into `columns`-wide chunks. The last chunk may be
  /// short; the row wrapper pads with empty cells so every row aligns to
  /// the same column grid.
  static List<List<WorldData>> _chunkRows(
    List<WorldData> catalog,
    int columns,
  ) {
    final List<List<WorldData>> rows = <List<WorldData>>[];
    for (int i = 0; i < catalog.length; i += columns) {
      rows.add(
        <WorldData>[
          for (int j = 0; j < columns; j++)
            (i + j < catalog.length) ? catalog[i + j] : _kEmptyWorldFill,
        ],
      );
    }
    return rows;
  }
}

/// Reused as a row-filler when the catalog count isn't divisible by
/// `columns`. Never rendered (the builder swaps it out for a SizedBox
/// spacer) — kept here so the type signature of the chunked rows stays
/// uniform instead of `List<WorldData?>`.
const WorldData _kEmptyWorldFill = WorldData(
  id: '__empty',
  title: '',
  glyph: '',
  difficulty: WorldDifficulty.easy,
  isPremiumWorld: false,
  starsForUnlock: 0,
);

// =============================================================================
//  _WorldRow — a single row of world islands, evenly spaced.
// =============================================================================

class _WorldRow extends StatelessWidget {
  const _WorldRow({
    super.key,
    required this.rowIndex,
    required this.worlds,
    required this.columns,
    required this.player,
    required this.floatController,
    required this.shimmerController,
    required this.reduceMotion,
    required this.currentWorldId,
  });

  final int rowIndex;
  final List<WorldData> worlds;
  final int columns;
  final PlayerState player;
  final AnimationController floatController;
  final AnimationController shimmerController;
  final bool reduceMotion;

  /// Sprint 4b — the kid's current world. Threaded down to every
  /// island so the matching tile gets the "you are here" highlight.
  final String? currentWorldId;

  @override
  Widget build(BuildContext context) {
    // Sprint 4b — staggered entrance: each row fades + slides up from
    // a small offset. Stagger cap stops the bottom rows from waiting
    // for a noticeable beat. Disabled entirely under reduceMotion so
    // the parents-area toggle keeps the page on-screen instantly.
    final Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          for (int i = 0; i < columns; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: _buildCell(context, index: i),
              ),
            ),
        ],
      ),
    );
    if (reduceMotion) {
      return rowContent;
    }
    final int clampedRow = rowIndex.clamp(0, 4);
    return rowContent
        .animate(delay: (60 * clampedRow).ms)
        .fadeIn(duration: 360.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.12,
          end: 0,
          duration: 360.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildCell(BuildContext context, {required int index}) {
    if (index >= worlds.length) {
      // Defensive — the chunk-fill should keep this branch dead.
      return const SizedBox.shrink();
    }
    final WorldData world = worlds[index];
    if (world.id == _kEmptyWorldFill.id) {
      // Padding slot for an uneven catalog / columns ratio. Keeps every
      // real island aligned to the same fixed-width column track.
      return const SizedBox(
        height: _kIslandTargetHeightDp,
      );
    }
    return _WorldIsland(
      world: world,
      // Each island reads `(rowIndex * columns + index)` as its sin-wave
      // phase offset so neighbouring islands never wobble in lock-step.
      phaseSeed: (rowIndex * _kWorldCatalogLength) + index,
      player: player,
      floatController: floatController,
      shimmerController: shimmerController,
      reduceMotion: reduceMotion,
      currentWorldId: currentWorldId,
    );
  }
}

/// Target on-screen height of one island card in dp. The floating scale
/// (±3 %) keeps the actual rendered height within ±7 dp of this target so
/// the rows stay neatly aligned even mid-sway.
const double _kIslandTargetHeightDp = 268.0;

// =============================================================================
//  _WorldIsland — the rendered tile.
// =============================================================================

class _WorldIsland extends StatelessWidget {
  const _WorldIsland({
    required this.world,
    required this.phaseSeed,
    required this.player,
    required this.floatController,
    required this.shimmerController,
    required this.reduceMotion,
    required this.currentWorldId,
  });

  final WorldData world;
  final int phaseSeed;
  final PlayerState player;
  final AnimationController floatController;
  final AnimationController shimmerController;
  final bool reduceMotion;

  /// Sprint 4b — the kid's current world. Threaded down from
  /// `_WorldRow` so the matching island can render the OutlinePulse
  /// "you are here" highlight + a tinted border.
  final String? currentWorldId;

  @override
  Widget build(BuildContext context) {
    final _IslandViewModel vm = _IslandViewModel.resolve(
      world: world,
      player: player,
      phaseSeed: phaseSeed,
      currentWorldId: currentWorldId,
    );

    final Widget island = SizedBox(
      height: _kIslandTargetHeightDp,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          // Rainbow underlay — drawn under the MagicCard so it bleeds
          // through the card's rounded silhouette.
          if (vm.isPremiumView)
            Positioned.fill(
              child: _RainbowShimmerLayer(
                controller: shimmerController,
                enabled: !reduceMotion,
              ),
            ),
          Positioned.fill(
            child: MagicCard(
              onTap: vm.unlocked ? () => _onIslandTap(context, vm) : null,
              skin: vm.unlocked ? MagicCardSkin.tinted : MagicCardSkin.blank,
              elevation: _islandElevation(vm),
              borderColor: _islandBorderColor(vm),
              borderRadius: AppCorner.brLg,
              padding: AppSpacing.cardPaddingGenerous,
              child: _IslandBody(viewModel: vm),
            ),
          ),
        ],
      ),
    );

    // OutlinePulse: Sprint 4b widened the rule. Raised for FRESHLY-
    // unlocked Premium worlds (v1.0) AND for the kid's current world
    // (new). The two intents don't overlap visually because the
    // current-world pulse uses the magicPink colour (the freshly-
    // unlocked one keeps the magicPurple default). The reduceMotion
    // fast-path inside OutlinePulse collapses both to a static 2 dp
    // hairline when the parents-area toggle is on.
    final bool wantsPulse =
        vm.shouldShowFocusPulse || (vm.isCurrent && !vm.isCompleted);
    if (wantsPulse) {
      return RepaintBoundary(
        child: OutlinePulse(
          periodDuration: _kFocusPulsePeriod,
          color: vm.isCurrent ? AppColors.magicPink : null,
          child: _wrapWithFloat(island),
        ),
      );
    }
    return RepaintBoundary(child: _wrapWithFloat(island));
  }

  /// Wraps [island] in the float AnimatedBuilder so every island's wobble
  /// stays synchronised off the shared master ticker.
  Widget _wrapWithFloat(Widget island) {
    if (reduceMotion) {
      return island;
    }
    return AnimatedBuilder(
      animation: floatController,
      builder: (BuildContext context, Widget? child) {
        // Phase off the rowIndex + colIndex mix so neighbours are out of
        // phase; offset magnitude is bounded by [_kFloatAmplitudeDp] and
        // scale amplitude by [_kFloatScaleAmplitude].
        final double raw = floatController.value + phaseSeed / _kFloatPhaseStep;
        final double t = raw - raw.floorToDouble();
        const double twoPi = math.pi * 2;
        final double phase =
            ((phaseSeed) % _kIslandPhaseModulus) / _kIslandPhaseModulus;
        final double angle = (twoPi * t) + (twoPi * phase);
        final double dy = math.sin(angle) * _kFloatAmplitudeDp;
        final double scale =
            1.0 + (_kFloatScaleAmplitude * math.sin(angle + math.pi / 2));
        return Transform.translate(
          offset: Offset(0.0, dy),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: island,
    );
  }

  void _onIslandTap(BuildContext context, _IslandViewModel vm) {
    AnalyticsService.instance.trackEvent(
      'worlds_tile_pressed',
      <String, Object?>{'id': vm.world.id, 'stars': vm.earnedStars},
    );
    Haptics.light();
    context.goWorldDetail(vm.world.id);
  }

  /// Sprint 4b — picks the MagicCard border color the island render
  /// should apply. The current world gets a tinted border so it stands
  /// out from the unlocked neighbours; completed worlds keep the
  /// MagicCard's default transparent border (the trophy badge is
  /// the signal).
  Color? _islandBorderColor(_IslandViewModel vm) {
    if (vm.unlocked && vm.isPremiumView) return Colors.transparent;
    if (vm.isCurrent) return AppColors.magicPink;
    return null;
  }

  /// Sprint 4b — picks the BoxShadow list for the island MagicCard.
  /// The current world sits one elevation step above the rest so it
  /// reads as "raised" without a distracting scale change. `AppElevation`
  /// exposes `z0`–`z3` (the M3 z-axis aliases — see `app_shape.dart`),
  /// and `z3` is the hero shadow used for the current-world emphasis.
  List<BoxShadow>? _islandElevation(_IslandViewModel vm) {
    if (vm.isCurrent) return AppElevation.z3;
    if (vm.unlocked) return AppElevation.elevation2;
    return AppElevation.elevation1;
  }
}

/// Phase-offset modulus — every island's wobble phase is `phaseSeed % N`,
/// guaranteeing a deterministic, evenly distributed stagger across the
/// catalog. Lower N → islands bunch; higher N → looser wave.
const int _kIslandPhaseModulus = 8;

// =============================================================================
//  _IslandViewModel — per-tile derived state.
// =============================================================================

/// Pre-computed screen-state for one island. Pulled out of [build] so the
/// view's widget tree reads top-down without arithmetic inline. Held in
/// a file-private `@immutable` because the values themselves are tiny.
@immutable
class _IslandViewModel {
  /// Resolves the world + player state into the derived view model.
  ///
  /// Sprint 4b — accepts an optional [currentWorldId] so the model
  /// can mark the island that matches the kid's current world
  /// (`isCurrent == true`) and surface a `completionState` enum
  /// (`locked` / `available` / `current` / `completed`) for the
  /// island render to branch on.
  factory _IslandViewModel.resolve({
    required WorldData world,
    required PlayerState player,
    required int phaseSeed,
    String? currentWorldId,
  }) {
    final bool hasSubscription = player.isPremium;
    final bool premiumGate = world.isPremiumWorld && !hasSubscription;
    final int stableStars = _resolveEarnedStars(world, player);
    final bool starsReached = stableStars >= world.starsForUnlock;
    final bool unlocked = !premiumGate && starsReached;

    final int shownStars = unlocked ? stableStars : 0;
    final int completionPct =
        unlocked ? (shownStars * 100 / 3).round().clamp(0, 100) : 0;

    final bool isPremiumView = world.isPremiumWorld || hasSubscription;
    final bool shouldShowFocusPulse = isPremiumView && unlocked;

    // Sprint 4b — derived state flags the island render branches on.
    final bool isCurrent = unlocked && currentWorldId == world.id;
    final bool isCompleted = unlocked && stableStars >= 3;
    // Sprint 6 — true when the player owns the world AND has not
    // dismissed the FirstUnlockDialog yet. Drives the "NEW" badge
    // on the island card.
    final bool isUncelebrated =
        unlocked && !player.celebratedWorldIds.contains(world.id);
    final String? requirementsText = _resolveRequirementsText(
      unlocked: unlocked,
      premiumGate: premiumGate,
      world: world,
      earnedStars: stableStars,
    );
    final CompletionState completionState = !unlocked
        ? CompletionState.locked
        : isCurrent
            ? CompletionState.current
            : isCompleted
                ? CompletionState.completed
                : CompletionState.available;

    return _IslandViewModel(
      world: world,
      unlocked: unlocked,
      earnedStars: shownStars,
      completionPct: completionPct,
      isPremiumGateLocked: premiumGate,
      isPremiumView: isPremiumView,
      shouldShowFocusPulse: shouldShowFocusPulse,
      isCurrent: isCurrent,
      isCompleted: isCompleted,
      isUncelebrated: isUncelebrated,
      requirementsText: requirementsText,
      completionState: completionState,
    );
  }

  /// Sprint 4b — human-readable copy for the locked-tile overlay.
  /// Returns null when the world is unlocked (no overlay needed).
  /// Premium-gated worlds surface "Premium required" (the parent
  /// already paid the gate, the kid sees a calm "this is Premium");
  /// star-gated worlds surface "Earn N more star(s)".
  static String? _resolveRequirementsText({
    required bool unlocked,
    required bool premiumGate,
    required WorldData world,
    required int earnedStars,
  }) {
    if (unlocked) return null;
    if (premiumGate) {
      return 'Premium required';
    }
    final int remaining = world.starsForUnlock - earnedStars;
    if (remaining <= 0) {
      // Edge: starsReached was true above so this branch is dead, but
      // a guard keeps the string safe if the heuristic ever changes.
      return null;
    }
    return 'Earn $remaining more star${remaining == 1 ? '' : 's'}';
  }

  const _IslandViewModel({
    required this.world,
    required this.unlocked,
    required this.earnedStars,
    required this.completionPct,
    required this.isPremiumGateLocked,
    required this.isPremiumView,
    required this.shouldShowFocusPulse,
    required this.isCurrent,
    required this.isCompleted,
    required this.isUncelebrated,
    required this.requirementsText,
    required this.completionState,
  });

  final WorldData world;

  /// True when the player can tap through to `/worlds/:id`.
  final bool unlocked;

  /// 0…3 — visualised in the 3-star meter.
  final int earnedStars;

  /// 0…100 — rounded completion percentage.
  final int completionPct;

  /// True iff the world is Premium-gated and the player lacks an active
  /// subscription. Drives the "GEMS" pill + lock badge.
  final bool isPremiumGateLocked;

  /// True iff THIS tile shows the rainbow shimmer ring. Equals
  /// `world.isPremiumWorld || player.isPremium` — both Premium worlds
  /// and any world the player has access to via their subscription get
  /// the rainbow treatment so the design system stays consistent.
  final bool isPremiumView;

  /// True iff the tile should be wrapped in an OutlinePulse focus halo.
  /// V1.0 simple rule: freshly-unlocked Premium worlds. Sprint-4 will
  /// replace this with a Hive-backed "just unlocked" event flag.
  final bool shouldShowFocusPulse;

  /// Sprint 4b — true iff this island matches the kid's current world
  /// (the one the world detail or coloring screen is anchored to).
  final bool isCurrent;

  /// Sprint 4b — true iff the world is unlocked AND the player has
  /// earned all 3 stars. Drives the trophy badge + removes the
  /// difficulty chip in favour of a "DONE" pill.
  final bool isCompleted;

  /// Sprint 6 — true iff the world is unlocked AND the player has
  /// not yet dismissed the FirstUnlockDialog. Drives the small
  /// "NEW" badge on the island card top-right corner. Reset to
  /// false once the dialog marks the world as celebrated.
  final bool isUncelebrated;

  /// Sprint 4b — short copy for the locked-tile overlay. Null when
  /// the world is unlocked (no overlay needed). Either "Premium
  /// required" or "Earn N more star(s)".
  final String? requirementsText;

  /// Sprint 4b — explicit 4-state lifecycle so the island render can
  /// branch on the stage instead of recomputing from booleans.
  final CompletionState completionState;
}

/// M3 production — earned-stars lookup for [world].
///
/// Reads the persistent [PlayerState.worldStars] map (Hive-backed). The
/// `.clamp(0, 3)` guards against any future drift if a corrupted box
/// injects an out-of-range value (the design ceiling per world is 3
/// stars). The map + detail surfaces stay in lock-step because both
/// files delegate to this identical signature; the eventual Sprint-4
/// catalog lift into `core/data/world_catalog.dart` will collapse
/// these two file-private helpers into one shared symbol.
int _resolveEarnedStars(WorldData world, PlayerState player) {
  return player.getWorldStars(world.id).clamp(0, 3);
}

// =============================================================================
//  _IslandBody — the inside of the MagicCard.
// =============================================================================

class _IslandBody extends StatelessWidget {
  const _IslandBody({required this.viewModel});

  final _IslandViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final _IslandViewModel vm = viewModel;
    final String title = vm.world.title;
    final String glyph = vm.world.glyph;

    return Semantics(
      button: vm.unlocked,
      label: _islandSemanticsLabel(vm),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (vm.isCompleted)
                const _CompletedBadge()
              else
                _DifficultyChip(difficulty: vm.world.difficulty),
              // Sprint 6 — small "NEW" badge on first-visit islands.
              // Sits BEFORE the Premium / Current badges so the
              // celebratory "NEW" cue is the loudest thing on the
              // tile during the first visit.
              if (vm.isUncelebrated) const _NewBadge(),
              if (vm.isPremiumGateLocked) const _LockBadge(),
              if (vm.isPremiumView && !vm.isPremiumGateLocked)
                const _PremiumBadge(),
              if (vm.isCurrent) const _CurrentBadge(),
            ],
          ),
          Center(
            child: Text(
              vm.unlocked ? glyph : _kLockGlyph,
              style: TextStyle(
                fontSize: _kIllustrationGlyphSize,
                color: vm.unlocked
                    ? null
                    : AppColors.deepInk.withValues(
                        alpha: _kLockedGlyphAlpha,
                      ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: AppTypography.titleSm.copyWith(
                  color: vm.unlocked
                      ? AppColors.deepInk
                      : AppColors.deepInk.withValues(
                          alpha: _kLockedGlyphAlpha,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _StarsRow(
                earned: vm.earnedStars,
                unlocked: vm.unlocked,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (vm.unlocked)
                _CompletionMeter(pct: vm.completionPct)
              else if (vm.requirementsText != null)
                _RequirementsChip(text: vm.requirementsText!),
            ],
          ),
        ],
      ),
    );
  }

  /// Sprint 4b — assembles a screen-reader label that names the
  /// lifecycle stage + the lock reason. Mirrors the same a11y
  /// pattern the v1.0 island used so VoiceOver/TalkBack users
  /// don't lose context.
  String _islandSemanticsLabel(_IslandViewModel vm) {
    final String stage;
    switch (vm.completionState) {
      case CompletionState.current:
        stage = 'current world';
        break;
      case CompletionState.completed:
        stage = 'completed';
        break;
      case CompletionState.available:
        stage = _kUnlockedFragment;
        break;
      case CompletionState.locked:
        stage = _kLockedFragment;
        break;
    }
    return '$stage: ${vm.world.title}, '
        '${vm.unlocked ? vm.earnedStars : 0} of 3 stars, '
        '${vm.completionPct}% complete'
        '${vm.isPremiumGateLocked ? ', $_kPremiumGateFragment' : ''}'
        '${vm.requirementsText != null && !vm.unlocked ? ', ${vm.requirementsText}' : ''}';
  }
}

// =============================================================================
//  _NewBadge — Sprint 6 small "NEW" pill rendered on freshly-unlocked
//  islands. Sits in the top row of the island body so the kid sees
//  the celebratory cue on first visit; disappears the moment the
//  FirstUnlockDialog is dismissed (PlayerState.celebratedWorldIds
//  adds the id). Pill family mirrors _CurrentBadge / _CompletedBadge.
// =============================================================================

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'New world',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kDifficultyChipHPadding,
          vertical: _kDifficultyChipVPadding,
        ),
        decoration: const BoxDecoration(
          color: AppColors.tangerine,
          borderRadius: AppCorner.brSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('✨', style: TextStyle(fontSize: _kPillGlyphSize)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'NEW',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.cloudWhite,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _CurrentBadge — Sprint 4b small "YOU ARE HERE" pill on the island that
//  matches the kid's current world. Mirrors _PremiumBadge / _LockBadge so
//  the pill family stays consistent.
// =============================================================================

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You are here',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kDifficultyChipHPadding,
          vertical: _kDifficultyChipVPadding,
        ),
        decoration: const BoxDecoration(
          color: AppColors.magicPink,
          borderRadius: AppCorner.brSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '📍',
              style: TextStyle(fontSize: _kPillGlyphSize),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'HERE',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.cloudWhite,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _CompletedBadge — Sprint 4b small "DONE" pill on islands where the
//  player has earned all 3 stars. Replaces the difficulty chip in the
//  same slot (the chip becomes noise once the world is finished).
// =============================================================================

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'All 3 stars earned',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kDifficultyChipHPadding,
          vertical: _kDifficultyChipVPadding,
        ),
        decoration: const BoxDecoration(
          gradient: AppGradients.playNow,
          borderRadius: AppCorner.brSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '🏆',
              style: TextStyle(fontSize: _kPillGlyphSize),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'DONE',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.cloudWhite,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _HerePill — Sprint 4b — small "HERE" pill rendered alongside the
//  ContinueBanner title when the banner is pointing at the kid's
//  current world. Also reused by [_LeaderboardRow] to mark the row that
//  matches [currentWorldId]. Mirrors the existing pill family
//  (PRO / EARN STARS / GEMS) so the visual language stays consistent.
// =============================================================================

class _HerePill extends StatelessWidget {
  const _HerePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.magicPink,
        borderRadius: AppCorner.brSm,
      ),
      child: const Text(
        'HERE',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.cloudWhite,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// =============================================================================
//  _RequirementsChip — Sprint 4b small caption rendered in the
//  completion-meter slot when the world is locked. Either
//  "Premium required" or "Earn N more star(s)".
// =============================================================================

class _RequirementsChip extends StatelessWidget {
  const _RequirementsChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.smoke.withValues(alpha: 0.16),
          borderRadius: AppCorner.brSm,
          border: Border.all(
            color: AppColors.smoke.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🔒', style: TextStyle(fontSize: 14)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: AppTypography.caption(color: AppColors.deepInk),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _DifficultyChip — pill-chip for the world difficulty tier.
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
        horizontal: _kDifficultyChipHPadding,
        vertical: _kDifficultyChipVPadding,
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
//  _LockBadge — small padlock glyph for premium-gated worlds.
// =============================================================================

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Premium-only world',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kDifficultyChipHPadding,
          vertical: _kDifficultyChipVPadding,
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
      ),
    );
  }
}

// =============================================================================
//  _PremiumBadge — small "PRO" pill for Premium-accessible worlds.
// =============================================================================

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Premium world',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _kDifficultyChipHPadding,
          vertical: _kDifficultyChipVPadding,
        ),
        decoration: const BoxDecoration(
          gradient: AppGradients.playNow,
          borderRadius: AppCorner.brSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              _kPremiumGlyph,
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
      ),
    );
  }
}

// =============================================================================
//  _StarsRow — 3-star meter.
// =============================================================================

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.earned, required this.unlocked});

  final int earned;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          Text(
            _kStarGlyph,
            style: TextStyle(
              fontSize: _kStarGlyphSize,
              color: _starColor(index: i, unlocked: unlocked),
            ),
          ),
          if (i < 2) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }

  Color _starColor({required int index, required bool unlocked}) {
    const Color fill = AppColors.starReward;
    final Color dim = AppColors.smoke.withValues(alpha: _kLockedGlyphAlpha);
    if (!unlocked) {
      return dim;
    }
    return index < earned ? fill : dim;
  }
}

// =============================================================================
//  _CompletionMeter — 0–100 % hairline bar.
// =============================================================================

class _CompletionMeter extends StatelessWidget {
  const _CompletionMeter({required this.pct});

  final int pct;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$pct percent complete',
      child: Stack(
        children: <Widget>[
          // Track
          Container(
            height: _kMeterHeight,
            decoration: BoxDecoration(
              color: AppColors.smoke.withValues(alpha: 0.20),
              borderRadius: AppCorner.brSm,
            ),
          ),
          // Fill
          FractionallySizedBox(
            widthFactor: (pct / 100).clamp(0.0, 1.0),
            child: Container(
              height: _kMeterHeight,
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

// =============================================================================
//  _RainbowShimmerLayer — animated rainbow border underlay.
// =============================================================================

/// Paints a [_kRainbowBorderWidth]-thick rainbow sweep ring around the
/// underneath of a tile. Disabled (no painter on top of the card) when
/// `enabled == false` — the caller (`_WorldIsland`) drops this widget
/// entirely from the Stack tree in that case via the surrounding
/// `if (enabled) …` guard. Honours reduceMotion through that guard.
class _RainbowShimmerLayer extends StatelessWidget {
  const _RainbowShimmerLayer({
    required this.controller,
    required this.enabled,
  });

  final AnimationController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      // Static fallback — paint a single shimmer frame so the border still
      // reads as "Premium" but no animation runs.
      return RepaintBoundary(
        child: CustomPaint(
          painter: _RainbowSweepPainter(progress: 0.5),
        ),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, _) {
          return CustomPaint(
            painter: _RainbowSweepPainter(progress: controller.value),
          );
        },
      ),
    );
  }
}

/// Paints a SweepGradient ring around the card.
class _RainbowSweepPainter extends CustomPainter {
  _RainbowSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const double twoPi = math.pi * 2;
    final double rotation = progress * twoPi;
    final Rect rect = Offset.zero & size;
    final Rect inset = rect.deflate(_kRainbowBorderWidth / 2);

    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kRainbowBorderWidth
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
        colors: const <Color>[
          AppColors.magicPink,
          AppColors.tangerine,
          AppColors.sunshineYellow,
          AppColors.mintLeaf,
          AppColors.lagoon,
          AppColors.skyCyan,
          AppColors.magicPurple,
          AppColors.magicPink,
        ],
        stops: const <double>[
          0.0,
          0.16,
          0.33,
          0.5,
          0.66,
          0.83,
          0.95,
          1.0,
        ],
        transform: GradientRotation(rotation),
      ).createShader(inset);

    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, const Radius.circular(AppRadius.lg)),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RainbowSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// =============================================================================
//  _CloudLayer — soft drifting cloud band painted above the sky but below
//  the world grid. The painter is rendered into a RepaintBoundary so a
//  scroll-driven grid repaint doesn't drag the clouds with it.
// =============================================================================

class _CloudLayer extends StatelessWidget {
  const _CloudLayer({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, _) {
          // WidthFactor spread should be > 1 so the painter draws past
          // the right edge of the viewport; offset wraps so the cloud
          // layer never reveals a hard edge mid-loop.
          return CustomPaint(
            painter: _CloudPainter(progress: controller.value),
          );
        },
      ),
    );
  }
}

/// Paints [_kCloudCount] soft cloud puffs across the full screen band.
/// Each puff is a horizontal sequence of over-lapping circles drawn with
/// a `MaskFilter.blur` so it reads as a true volumetric cloud, not a
/// mechanical blob.
class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Stable per-cloud seed so the cloud positions don't jitter across
    // rebuilds. The motion itself is driven entirely by [progress].
    final math.Random rng = math.Random(0xC10D5);

    final Paint paint = Paint()
      ..color = AppColors.cloudWhite.withValues(alpha: _kCloudAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _kCloudBlurSigma);

    final double screenW = size.width;
    // Band height ≈ top quarter of the screen — clouds drift overhead
    // without colliding with the island cards.
    final double bandHeight = size.height * _kCloudBandFraction;
    final double drift = progress * screenW * _kCloudDriftMultiplier;

    for (int i = 0; i < _kCloudCount; i++) {
      final double seedLeft = rng.nextDouble();
      final double seedRadius =
          _kCloudRadiusMinFrac + (rng.nextDouble() * _kCloudRadiusJitterFrac);
      final double seedY = rng.nextDouble() * bandHeight;
      // x drifts continuously; modulo back into [0, 1.6 × screenW]
      final double rawX =
          ((seedLeft * screenW * _kCloudDriftMultiplier) + drift) %
              (screenW * _kCloudDriftMultiplier);
      final double x = rawX - screenW * _kCloudLeftPadFraction;
      final double cloudRadius = screenW * seedRadius;
      // Render a horizontal arrangement of overlapping puffs to give the
      // cloud its volume.
      for (int j = 0; j < 5; j++) {
        final double offset = (j - 2) * (cloudRadius * 0.5);
        canvas.drawCircle(
          Offset(x + offset, seedY + (j.isEven ? 0.0 : cloudRadius * 0.08)),
          cloudRadius * (0.85 + (j * 0.05)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
