// =============================================================================
// Magic Colors · features/coloring/widgets/coloring_palette.dart
// =============================================================================
//
// M2.3 — The 6×4 swatch grid sits at the bottom of the coloring screen,
// now wrapped in a 3-tab segmented switcher:
//
//   • Standard  — every palette colour (tier 0..2).
//   • Recenti   — the player's MRU list (front = most-recent).
//   • Preferiti — the player's favorited colours.
//
// Rules:
//   • Locked colours (tier 1) show a lock icon. Tap fires
//     [ColoringController.tryUnlockColorWithCoins] (preferred when
//     the player has >= cost coins) OR
//     [ColoringController.tryUnlockColorWithStars]. The exact path
//     is the UI sheet that the chosen affordance feeds into.
//   • Premium colours (tier 2) show a crown overlay. Tap fires
//     [onPremiumTap] → ParentGate → ParentsArea subscription CTA
//     (the actual nav lives outside M2.3 scope).
//   • Recent & Favorite tabs render a smaller grid; empty states show
//     a hint label instead of an empty grid.
//
// The widget stays a thin glue layer over `ColorSwatchGrid` plus the
// M2.3 gradient picker sheet (a modal triggered from a small icon
// button in the tab strip — visible only when the Fill brush is
// selected).
// =============================================================================

import 'package:flutter/material.dart';

import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_shape.dart' show AppCorner;
import 'package:magic_colors/core/widgets/color_swatch_grid.dart';

import 'package:magic_colors/features/coloring/coloring_controller.dart';
import 'package:magic_colors/features/coloring/data/palette_catalog.dart';
import 'package:magic_colors/features/coloring/domain/color_acl.dart';
import 'package:magic_colors/features/coloring/domain/enums.dart';
import 'package:magic_colors/features/coloring/widgets/gradient_picker_sheet.dart';
import 'package:magic_colors/features/coloring/widgets/parent_gate_sheet.dart';

/// M2.3 — Three palette tabs. `segmented` ensures the user never has
/// to guess what tab they're looking at.
enum PaletteTab { standard, recent, favorite }

class ColoringPalette extends StatefulWidget {
  const ColoringPalette({
    super.key,
    required this.controller,
  });

  final ColoringController controller;

  @override
  State<ColoringPalette> createState() => _ColoringPaletteState();
}

class _ColoringPaletteState extends State<ColoringPalette> {
  PaletteTab _active = PaletteTab.standard;

  void _setActive(PaletteTab tab) {
    if (_active == tab) return;
    setState(() => _active = tab);
  }

  // ── Active tab selection ──────────────────────────────────────────

  List<int> _activeIndexes() {
    final ColoringController c = widget.controller;
    final PlayerStateSnapshot? player = _playerSnapshot(c);
    switch (_active) {
      case PaletteTab.standard:
        return List<int>.generate(PaletteCatalog.colors.length, (int i) => i);
      case PaletteTab.recent:
        return List<int>.from(player?.recent ?? const <int>[]);
      case PaletteTab.favorite:
        return List<int>.from(player?.favorite ?? const <int>[]);
    }
  }

  // Allows unit tests to pass a synthetic player. The live path goes
  // through the controller via `widget.controller.player`.
  PlayerStateSnapshot? _playerSnapshot(ColoringController c) {
    if (c.player == null) {
      return null;
    }
    return PlayerStateSnapshot.from(c.player!);
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _tabStrip(context),
            const SizedBox(height: 6.0),
            _activeGrid(context),
          ],
        );
      },
    );
  }

  Widget _tabStrip(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // 3-tab segmented switcher.
        ...<Widget>[
          _tabButton(context, PaletteTab.standard, 'Standard'),
          _tabButton(context, PaletteTab.recent, 'Recenti'),
          _tabButton(context, PaletteTab.favorite, 'Preferiti'),
        ],
        // Gradient button — visible only when the Fill brush is active.
        if (widget.controller.brushType == BrushType.fill)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: _gradientButton(context),
          ),
      ],
    );
  }

  Widget _tabButton(BuildContext context, PaletteTab tab, String label) {
    final bool selected = _active == tab;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppCorner.brMd,
            // M2.4 — unified splashColor so every palette surface
            // ripples the same colour (matches the sparkle palette).
            splashColor: AppColors.magicPurple.withValues(alpha: 0.18),
            highlightColor: AppColors.magicPurple.withValues(alpha: 0.08),
            onTap: () => _setActive(tab),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppCorner.brMd,
                color: selected
                    ? AppColors.magicPurple
                    : AppColors.skyTouchedWhite,
                border: Border.all(
                  color: selected
                      ? AppColors.magicPurple
                      : AppColors.hairlineLight,
                  width: selected ? 2.0 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.cloudWhite : AppColors.deepInk,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientButton(BuildContext context) {
    final bool active = widget.controller.isGradientActive;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppCorner.brMd,
        // M2.4 — same splash colour as the tab strip.
        splashColor: AppColors.magicPurple.withValues(alpha: 0.18),
        highlightColor: AppColors.magicPurple.withValues(alpha: 0.08),
        onTap: () => _showGradientSheet(context),
        child: Container(
          width: 44.0,
          height: 44.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: <Color>[
                AppColors.cosmicPurple,
                AppColors.coinGold,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: active ? AppColors.magicPink : AppColors.hairlineLight,
              width: active ? 3.0 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            active ? Icons.gradient_rounded : Icons.gradient_outlined,
            color: AppColors.cloudWhite,
            size: 22.0,
          ),
        ),
      ),
    );
  }

  Future<void> _showGradientSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.skyTouchedWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => GradientPickerSheet(
        controller: widget.controller,
      ),
    );
  }

  Widget _activeGrid(BuildContext context) {
    final ColoringController c = widget.controller;
    final List<int> indexes = _activeIndexes();
    if (indexes.isEmpty) {
      return _emptyState(_active);
    }

    final List<Color> colors = <Color>[
      for (final int i in indexes) PaletteCatalog.colorAt(i),
    ];
    final List<ColorSwatchOverlay> overlays = _overlaysFor(
      indexes,
      c,
    );
    final Set<int> selectedInTab = <int>{
      if (indexes.contains(c.selectedColorIndex)) c.selectedColorIndex,
    };
    final Color? selectedRaw = selectedInTab.isEmpty ? null : c.selectedColor;
    final int? selectedIndexInTab =
        selectedRaw == null ? null : colors.indexOf(selectedRaw);
    final Set<int> favoritedInTab = <int>{
      for (final int i in indexes)
        if ((c.player?.favoriteColorIds ?? const <int>[]).contains(i)) i,
    };
    return ColorSwatchGrid(
      colors: colors,
      selectedIndex: selectedIndexInTab,
      overlays: overlays,
      favoritedIndexes: favoritedInTab,
      swatchSize: PaletteCatalog.swatchSize,
      onSelect: (int idxInTab) {
        final int paletteIndex = indexes[idxInTab];
        c.setColorAt(paletteIndex);
      },
      // M2.4 — long-press → toggle favorite via the controller.
      onLongPress: (int idxInTab) {
        final int paletteIndex = indexes[idxInTab];
        c.toggleFavoriteColor(paletteIndex);
      },
      onLockedTap: _handleLockedTap,
      onPremiumTap: _handlePremiumTap,
    );
  }

  List<ColorSwatchOverlay> _overlaysFor(
    List<int> indexes,
    ColoringController c,
  ) {
    final List<int> unlocked = c.player?.unlockedColorIds ?? const <int>[];
    return <ColorSwatchOverlay>[
      for (final int i in indexes)
        _overlayForPaletteIndex(i, unlocked, c.player?.isPremium ?? false),
    ];
  }

  ColorSwatchOverlay _overlayForPaletteIndex(
    int paletteIndex,
    List<int> unlocked,
    bool isPremium,
  ) {
    if (PaletteCatalog.isPremiumIndex(paletteIndex)) {
      return isPremium ? ColorSwatchOverlay.none : ColorSwatchOverlay.premium;
    }
    return ColorAcl.isLocked(
      paletteIndex: paletteIndex,
      unlockedIndexes: unlocked,
    )
        ? ColorSwatchOverlay.locked
        : ColorSwatchOverlay.none;
  }

  void _handleLockedTap(int paletteIndex, int coins, int stars) {
    final ColoringController c = widget.controller;
    // Auto-pick coins if the player can afford them; fall back to
    // stars if they have enough earned in the active world; else
    // show the insufficient-funds dialog.
    final int balance = c.player?.coins ?? 0;
    final int worldStars = c.player?.getWorldStars(c.worldId) ?? 0;
    final bool canCoins = balance >= coins;
    final bool canStars = worldStars >= stars;
    if (canCoins) {
      c.tryUnlockColorWithCoins(paletteIndex: paletteIndex, cost: coins);
      return;
    }
    if (canStars) {
      c.tryUnlockColorWithStars(
        worldId: c.worldId,
        paletteIndex: paletteIndex,
        cost: stars,
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Colour locked'),
        content: Text(
          'You can unlock this colour with $coins coins OR '
          '$stars stars. Keep painting to earn some!',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePremiumTap(int paletteIndex) async {
    // M2.4 — route through the [ParentGateSheet]. On success the
    // upsell dialog is shown; the subscription flow is reserved for
    // a future release (parent IAP). The user only sees a celebratory
    // dialog acknowledging Premium colours.
    final PlayerStateSnapshot? snapshot = _playerSnapshot(widget.controller);
    if (snapshot == null) {
      // No PlayerState wired — fail-open so QA can still demo the
      // surface. Production wiring always supplies a PlayerState.
      await _showPremiumAckDialog(context, paletteIndex);
      return;
    }
    final Object? rawPlayer = widget.controller.player;
    if (rawPlayer is! PlayerState) {
      await _showPremiumAckDialog(context, paletteIndex);
      return;
    }
    final bool passed = await showParentGateSheet(
      context: context,
      player: rawPlayer,
    );
    if (!passed) return;
    if (!mounted) return;
    await _showPremiumAckDialog(context, paletteIndex);
  }

  Future<void> _showPremiumAckDialog(
    BuildContext context,
    int paletteIndex,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Premium colour activated'),
        content: const Text(
          'Ask a grown-up to upgrade for the full Premium palette. '
          'For now you can paint with the colours you have.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    assert(paletteIndex >= 0);
  }

  Widget _emptyState(PaletteTab tab) {
    final String message = _emptyMessage(tab);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 24.0,
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.smoke,
            fontSize: 14.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _emptyMessage(PaletteTab tab) {
    switch (tab) {
      case PaletteTab.recent:
        return 'No colours used yet — paint something!';
      case PaletteTab.favorite:
        return 'No favourites yet — long-press a swatch to add one.';
      case PaletteTab.standard:
        return '';
    }
  }
}

// =============================================================================
//  PlayerStateSnapshot — read-only projection used by the widget tree.
// =============================================================================

/// Small adapter to keep the widget tests independent of the live
/// PlayerState (no Hive box needed). Production code never constructs
/// this — it's only used by [PlayerState.from] below, which reads from
/// the live controller.
final class PlayerStateSnapshot {
  const PlayerStateSnapshot({
    required this.coins,
    required this.stars,
    required this.isPremium,
    required this.favorite,
    required this.recent,
    required this.unlocked,
  });

  final int coins;
  final int stars;
  final bool isPremium;
  final List<int> favorite;
  final List<int> recent;
  final List<int> unlocked;

  factory PlayerStateSnapshot.from(PlayerState player) {
    return PlayerStateSnapshot(
      coins: player.coins,
      stars: 0, // Not currently surfaced — worldId-specific.
      isPremium: player.isPremium,
      favorite: List<int>.from(player.favoriteColorIds),
      recent: List<int>.from(player.recentColorIds),
      unlocked: List<int>.from(player.unlockedColorIds),
    );
  }
}
