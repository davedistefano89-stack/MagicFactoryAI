// =============================================================================
// Magic Colors · core/widgets/currency_hud.dart
// =============================================================================
//
// The currency heads-up display. Sits at the top of Home, Worlds, and Shop
// to remind the player how many coins + gems they have on hand. Watches
// [PlayerState] via Provider — the counter auto-updates whenever a
// `+5 coins` or `+1 gem` reward is granted.
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §7):
//   ▸ Layout:     Two chips (coin, gem) horizontally, 8 dp gap between
//                 them. Both chips live inside a single transparent pill.
//   ▸ Coin chip:  AppColors.coinGold fill, AppColors.deepInk type, coin
//                 halo glow at 8 dp blur.
//   ▸ Gem chip:   AppColors.gemRoyal fill, AppColors.cloudWhite type, gem
//                 halo glow at 8 dp blur.
//   ▸ Type:       AppTypography.numericCounter (28 / 800 Baloo 2,
//                 tabular figures).
//   ▸ Heights:    48 dp. Padding: AppSpacing.sm horizontal.
//   ▸ Visibility: When the player owns 0 of a currency AND [hideZero] is
//                 true (default), the chip is hidden — keeps the chrome
//                 unobtrusive for new installs.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import '../state/player_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_shape.dart';
import '../theme/app_typography.dart';

// =============================================================================
//  CurrencyHUD — provider-aware coin + gem chip.
// =============================================================================

class CurrencyHUD extends StatelessWidget {
  const CurrencyHUD({
    super.key,
    this.hideZero = true,
    this.compact = false,
  });

  /// When true (default), a currency chip with a count of 0 is removed
  /// from the row. Used during onboarding so the chrome doesn't add noise.
  final bool hideZero;

  /// When true, switches to a 36 dp tall compact variant. Used inside
  /// shop cards where vertical space is at a premium.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final coins = player.coins;
    final gems = player.gems;

    final chips = <Widget>[
      if (!hideZero || coins > 0)
        _CurrencyChip(
          label: '$coins',
          fillColor: AppColors.coinGold,
          textColor: AppColors.deepInk,
          glow: AppElevation.glowYellow,
          compact: compact,
        ),
      if (coins > 0 && (!hideZero || gems > 0)) AppSpacing.hGapSm,
      if (!hideZero || gems > 0)
        _CurrencyChip(
          label: '$gems',
          fillColor: AppColors.gemRoyal,
          textColor: AppColors.cloudWhite,
          glow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.gemHalo,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          compact: compact,
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }
}

// =============================================================================
//  _CurrencyChip — internal pill widget.
// =============================================================================

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.fillColor,
    required this.textColor,
    required this.glow,
    required this.compact,
  });

  final String label;
  final Color fillColor;
  final Color textColor;
  final List<BoxShadow> glow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 36.0 : 48.0;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: AppCorner.brMd,
        boxShadow: glow,
      ),
      child: Text(
        label,
        style: AppTypography.numericCounter.copyWith(
          color: textColor,
          fontSize: compact ? 22.0 : 28.0,
        ),
      ),
    );
  }
}
