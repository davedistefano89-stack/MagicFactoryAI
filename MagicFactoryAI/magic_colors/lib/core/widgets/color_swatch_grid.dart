// =============================================================================
// Magic Colors · core/widgets/color_swatch_grid.dart
// =============================================================================
//
// The colour-switcher widget used by the Coloring feature (canvas tool
// tray) and by Parents Area (avatar wardrobe). Lays out a fixed grid of
// swatch circles; the currently-selected swatch grows a 4 dp Magic-Pink
// outline ring and a 1.06× scale-up.
//
// M2.3 OVERLAYS
// -------------
// Each tile now accepts three optional overlay states:
//
//   • overlay = ColorSwatchOverlay.locked ━ small lock icon + flat
//     colour underneath. Tap fires [onLockedTap] (M2.3 controller
//     route → "spend 100 coins or 3 stars" modal).
//   • overlay = ColorSwatchOverlay.premium ━ crown overlay + sparkle
//     halo. Tap fires [onPremiumTap] (M2.3 controller route → upsell
//     → ParentGate → Parents Area).
//   • overlay = ColorSwatchOverlay.favorited ━ small filled star in
//     the corner. Always tap-selectable.
//
// Without an overlay the tile reads as tier-0 (free) and tap fires
// [onSelect] (M0 behaviour preserved).
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §9):
//   ▸ Layout:     N columns × ceil(palette.length / N) rows, 16 dp
//                 inter-cell spacing.
//   ▸ Swatch:     Filled circle (0 = transparent fill renders as a
//                 colourless "eraser" glyph).
//   ▸ Selected:   4 dp AppColors.magicPink outline ring + 1.06× scale.
//   ▸ Tap:        Haptics.selection() + onSelect(index).
// =============================================================================

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../theme/app_colors.dart';
import '../theme/app_shape.dart';
import '../utils/haptics.dart';


/// Tile overlay state. Set when a swatch sits in a tier-1 (locked)
/// or tier-2 (premium) bucket. Favorited is purely decorative.
enum ColorSwatchOverlay { none, locked, premium, favorited }


/// Maximum ticks a single swatch button stays in its scaled-up state
/// after the user releases their tap. Drives the [AnimatedContainer]
/// transition.
const Duration _kSwatchTapInDuration = AppDuration.fast;


class ColorSwatchGrid extends StatelessWidget {
  const ColorSwatchGrid({
    super.key,
    required this.colors,
    required this.selectedIndex,
    required this.onSelect,
    this.columns = 4,
    this.swatchSize = 48.0,
    this.overlays = const <ColorSwatchOverlay>[],
    this.onLockedTap,
    this.onPremiumTap,
    this.favoritedIndexes = const <int>{},
  });

  /// Palette. `Color(0x00000000)` is the "eraser" position (rendered with
  /// a diagonal striped fill so the user sees the slot).
  final List<Color> colors;

  /// Currently-selected index. `null` paints no selection indicator.
  final int? selectedIndex;

  /// Tap callback. Receives the row's index in [colors] (NOT the grid
  /// row-major column-index).
  final ValueChanged<int> onSelect;

  /// Number of columns. The widget auto-detects the row count.
  final int columns;

  /// Swatch diameter in dp. Default 48 dp (matches Material 3 touch
  /// target for the eraser tool).
  final double swatchSize;

  /// M2.3 — list of overlay states (one entry per swatch position).
  /// Indexes that don't have an overlay (`ColorSwatchOverlay.none`)
  /// are tier-0 (free) and tap normally.
  final List<ColorSwatchOverlay> overlays;

  /// M2.3 — lock-unlock tap callback (signature: (paletteIndex, costCoins,
  /// costStars)). Caller's responsibility to show the spend modal.
  final void Function(int paletteIndex, int costCoins, int costStars)?
      onLockedTap;

  /// M2.3 — premium upsell tap callback.
  final void Function(int paletteIndex)? onPremiumTap;

  /// M2.3 — set of palette indexes that are user-favorited. Drives a
  /// small filled star in the corner of the swatch.
  final Set<int> favoritedIndexes;

  int _rowsFor(int count) {
    if (count <= 0) return 0;
    return ((count + columns - 1) ~/ columns);
  }

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }
    final rows = _rowsFor(colors.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var r = 0; r < rows; r++) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (var c = 0; c < columns; c++)
                _swatchSlot(context, r * columns + c),
            ],
          ),
          if (r < rows - 1) AppSpacing.vGapMd,
        ],
      ],
    );
  }

  Widget _swatchSlot(BuildContext context, int index) {
    if (index >= colors.length) {
      return SizedBox(width: swatchSize, height: swatchSize);
    }
    final color = colors[index];
    final selected = index == selectedIndex;
    final ColorSwatchOverlay overlay =
        index < overlays.length ? overlays[index] : ColorSwatchOverlay.none;
    final bool favorited = favoritedIndexes.contains(index);
    return _SwatchTile(
      color: color,
      selected: selected,
      size: swatchSize,
      overlay: overlay,
      favorited: favorited,
      onTap: () {
        Haptics.selection();
        switch (overlay) {
          case ColorSwatchOverlay.none:
          case ColorSwatchOverlay.favorited:
            onSelect(index);
          case ColorSwatchOverlay.locked:
            // The actual cost values are looked up by the controller;
            // this widget only forwards the index. Wired co-stars live
            // on PaletteCatalog (indexing → cost pair).
            final int costCoins = _costCoinsFor(index);
            final int costStars = _costStarsFor(index);
            onLockedTap?.call(index, costCoins, costStars);
          case ColorSwatchOverlay.premium:
            onPremiumTap?.call(index);
        }
      },
    );
  }

  // Local cost lookups. The widget deliberately keeps this thin — the
  // canonical values live in PaletteCatalog so a future tweak doesn't
  // require editing two files in lock-step.
  int _costCoinsFor(int _) => 0;
  int _costStarsFor(int _) => 0;
}


// =============================================================================
//  _SwatchTile — single filled-circle button (M2.3 with overlays).
// =============================================================================

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({
    required this.color,
    required this.selected,
    required this.size,
    required this.overlay,
    required this.favorited,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final double size;
  final ColorSwatchOverlay overlay;
  final bool favorited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _kSwatchTapInDuration,
          curve: AppCurves.buttonBounce,
          width: size,
          height: size,
          transform: Matrix4.identity()..scale(selected ? 1.06 : 1.0),
          transformAlignment: Alignment.center,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.alpha == 0 ? AppColors.skyTouchedWhite : color,
            border: Border.all(
              color: selected
                  ? AppColors.magicPink
                  : AppColors.smoke.withValues(alpha: 0.30),
              width: selected ? 4.0 : 2.0,
            ),
            boxShadow: selected ? AppElevation.softChip : const <BoxShadow>[],
          ),
          child: _swatchGlyph(context),
        ),
      ),
    );
  }

  String _semanticLabel() {
    switch (overlay) {
      case ColorSwatchOverlay.locked:
        return 'Locked color swatch';
      case ColorSwatchOverlay.premium:
        return 'Premium color swatch';
      case ColorSwatchOverlay.favorited:
      case ColorSwatchOverlay.none:
        return 'Color swatch';
    }
  }

  Widget? _swatchGlyph(BuildContext context) {
    if (color.alpha == 0) {
      return Icon(
        Icons.cleaning_services_rounded,
        size: size * 0.45,
        color: AppColors.deepInk,
      );
    }
    if (overlay == ColorSwatchOverlay.locked) {
      return Icon(
        Icons.lock_rounded,
        size: size * 0.40,
        color: AppColors.deepInk.withValues(alpha: 0.85),
      );
    }
    if (overlay == ColorSwatchOverlay.premium) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            Icons.workspace_premium_rounded,
            size: size * 0.55,
            color: AppColors.sunshineYellow,
          ),
          Icon(
            Icons.star_rounded,
            size: size * 0.30,
            color: AppColors.deepInk,
          ),
        ],
      );
    }
    if (favorited) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.only(right: size * 0.10, top: size * 0.10),
          child: Icon(
            Icons.star_rounded,
            size: size * 0.28,
            color: AppColors.magicPink,
          ),
        ),
      );
    }
    return null;
  }
}
