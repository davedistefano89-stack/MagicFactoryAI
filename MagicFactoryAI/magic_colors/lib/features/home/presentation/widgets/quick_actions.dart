// =============================================================================
// Magic Colors · features/home/presentation/widgets/quick_actions.dart
// =============================================================================
//
// The 6-tile action grid that lives at the bottom of the Home screen
// (Collection · Worlds · Rewards · Shop · Parents · Premium). Each tile is
// a [MagicCard] that wraps a glyph + label pair, dispatches through a
// caller-supplied [VoidCallback], and renders a small PRO chip in the
// top-right corner when [QuickActionSpec.isPremiumTile] is true.
//
// This widget is intentionally Foundation-only: it does NOT touch
// `Provider`, `GoRouter`, or `NavigationState`. All routing is the job of
// the parent (the screen layer wires the [QuickActionSpec.onTap] for each
// tile). That keeps `quick_actions.dart` trivially testable + reuse-safe on
// World-picker and Settings screens.
//
// Responsive layout:
//   • Phone portrait (or compact+medium breakpoint) → 3 columns × 2 rows.
//   • Phone landscape, tablet, or expanded →     6 columns × 1 row.
//
// Public API surface:
//   • `class QuickActions extends StatelessWidget`  — the grid itself.
//   • `@immutable class QuickActionSpec`            — per-tile data class.
//
// Both are exported; everything below is file-private (underscore-prefixed).
// =============================================================================

import 'package:flutter/material.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/magic_card.dart';

// ── Frozen tuning constants ──────────────────────────────────────────────────

/// Exactly six destinations. Promoting from const-eval so a rebuild of
/// any Home screen that feeds the grid will fail loudly if a slot is
/// forgotten.
const int _kActionCount = 6;

/// How many columns render on phone portrait / compact viewports.
const int _kPortraitColumns = 3;

/// How many columns render on landscape phone / medium+ expanded.
const int _kLandscapeColumns = 6;

/// Emoji glyph rendered at the top of each tile.
const double _kGlyphFontSize = 40.0;

/// PRO chip font size (lands inside the corner pill).
const double _kProChipFontSize = 10.0;

/// Padding inside the PRO chip on a small label.
const EdgeInsets _kProChipPadding = EdgeInsets.symmetric(
  horizontal: 7.0,
  vertical: 2.5,
);

/// Pixel inset from the top-right corner of the tile.
const EdgeInsets _kProChipInset = EdgeInsets.only(top: 8.0, right: 8.0);

/// Outer ring around the PRO chip.
const double _kProChipBorderWidth = 1.5;

/// Inter-glyph vertical hairline between emoji and label.
const SizedBox _kGlyphLabelGap = SizedBox(height: AppSpacing.xs);

/// Minimum tile side length, enforced so the touch target never falls
/// below the project's 48 dp accessibility floor on very-narrow sub-compact
/// viewports.
const double _kMinTileSide = 48.0;

const Color _kProChipFill = AppColors.magicPurple;
const Color _kProChipBorder = AppColors.cloudWhite;
const Color _kProChipText = AppColors.cloudWhite;
const double _kProChipLetterSpacing = 0.6;
const String _kProChipLabel = 'PRO';
const double _kProChipRadius = AppRadius.pill;

/// =============================================================================
///  QuickActionSpec — per-tile data class.
/// =============================================================================

/// Immutable spec for a single tile in [QuickActions]. Host screens
/// construct one [QuickActionSpec] per destination and pass the list to
/// the grid. Routers / providers are intentionally out of scope — see
/// the file-level doc-comment for the rationale.
@immutable
class QuickActionSpec {
  const QuickActionSpec({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.semanticLabel,
    this.isPremiumTile = false,
  });

  /// Tile label. e.g. "Collection", "Worlds", "Premium". Required.
  final String label;

  /// Emoji glyph rendered above the label. e.g. "🎨", "🌍", "👑".
  final String glyph;

  /// Tap callback. The host supplies this and is responsible for the
  /// actual navigation. May be invoked any number of times per render.
  final VoidCallback onTap;

  /// Optional screen-reader override. Defaults to [label] when null.
  final String? semanticLabel;

  /// When `true` the tile paints with [MagicCardSkin.accent] and renders
  /// a small "PRO" chip in the corner.
  final bool isPremiumTile;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is QuickActionSpec &&
        other.label == label &&
        other.glyph == glyph &&
        other.semanticLabel == semanticLabel &&
        other.isPremiumTile == isPremiumTile;
  }

  @override
  int get hashCode => Object.hash(label, glyph, semanticLabel, isPremiumTile);
}

/// =============================================================================
///  QuickActions — public widget.
/// =============================================================================

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  /// Six [QuickActionSpec] entries. The assertion is debug-only so a
  /// release build never crashes a kid for a missing row.
  final List<QuickActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    assert(
      actions.length == _kActionCount,
      'QuickActions requires exactly $_kActionCount tiles; got ${actions.length}',
    );

    return Semantics(
      label: 'Quick actions',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final columns = _resolveColumns(context);
          const spacing = AppSpacing.sm;
          final tileSide = _resolveTileSide(constraints, columns, spacing);

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              // mainAxisExtent pins each tile's height to the same square
              // length as the grid-derived width, and — crucially — the
              // upstream `_resolveTileSide` clamp ensures nothing below
              // `_kMinTileSide = 48 dp` ever reaches a child. Without this
              // pin, `childAspectRatio` lets Flutter shrink tiles below
              // the touch-target floor on sub-compact viewports.
              mainAxisExtent: tileSide,
            ),
            itemCount: actions.length,
            itemBuilder: (BuildContext context, int index) {
              return _QuickActionTile(spec: actions[index]);
            },
          );
        },
      ),
    );
  }

  /// Picks 6 columns on landscape + expanded breakpoint, 3 otherwise.
  static int _resolveColumns(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isExpanded =
        ResponsiveScale.breakpoint(context) == MagicBreakpoint.expanded;
    return (isLandscape || isExpanded) ? _kLandscapeColumns : _kPortraitColumns;
  }

  /// Computes the tile side from the available width + spacing/column count
  /// and clamps to the project touch-target floor.
  static double _resolveTileSide(
    BoxConstraints constraints,
    int columns,
    double spacing,
  ) {
    final available = constraints.maxWidth;
    if (available <= 0) {
      return _kMinTileSide;
    }
    final slots = columns + 1; // spacing gutters on both ends of each row
    final raw = (available - (spacing * slots)) / columns;
    return raw < _kMinTileSide ? _kMinTileSide : raw;
  }
}

/// =============================================================================
///  _QuickActionTile — file-private tile.
/// =============================================================================

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.spec});

  final QuickActionSpec spec;

  @override
  Widget build(BuildContext context) {
    final isPremium = spec.isPremiumTile;
    // The "skin" picker stays explicit so a future contributor can swap
    // premium visuals (e.g. MagicCardSkin.rainbow) without touching the
    // tile's content layout.
    final skin = isPremium ? MagicCardSkin.accent : MagicCardSkin.tinted;
    // Accent skin renders the cloud-white fill rather than the rainbow
    // gradient the design brief sketches, so we explicitly draw a purple
    // 2 dp ring on the premium tile so it reads as elevated.
    final inlineBorder = isPremium ? _kProChipFill : null;

    return Semantics(
      button: true,
      enabled: true,
      label: spec.semanticLabel ?? spec.label,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          MagicCard(
            onTap: spec.onTap,
            skin: skin,
            borderColor: inlineBorder,
            padding: const EdgeInsets.all(AppSpacing.sm),
            elevation: isPremium ? AppElevation.glowPurple : AppElevation.z1,
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    spec.glyph,
                    style: const TextStyle(fontSize: _kGlyphFontSize),
                  ),
                  _kGlyphLabelGap,
                  Text(
                    spec.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: AppTypography.titleSm,
                  ),
                ],
              ),
            ),
          ),
          if (isPremium)
            Positioned(
              top: _kProChipInset.top,
              right: _kProChipInset.right,
              child: const _ProChip(),
            ),
        ],
      ),
    );
  }
}

/// =============================================================================
///  _ProChip — file-private PRO corner pill.
/// =============================================================================

class _ProChip extends StatelessWidget {
  const _ProChip();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Premium feature',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kProChipFill,
          borderRadius: BorderRadius.circular(_kProChipRadius),
          border: Border.all(
            color: _kProChipBorder,
            width: _kProChipBorderWidth,
          ),
          boxShadow: AppElevation.softChip,
        ),
        child: const Padding(
          padding: _kProChipPadding,
          child: Text(
            _kProChipLabel,
            style: TextStyle(
              fontSize: _kProChipFontSize,
              fontWeight: FontWeight.w800,
              color: _kProChipText,
              letterSpacing: _kProChipLetterSpacing,
            ),
          ),
        ),
      ),
    );
  }
}
