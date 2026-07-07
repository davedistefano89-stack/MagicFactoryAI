// =============================================================================
// Magic Colors · features/coloring/widgets/drawing_complete_overlay.dart
// =============================================================================
//
// M2.4 — Success overlay shown when the player completes a drawing.
// Renders a celebration card (title + subtitle + reward pill row +
// 'Awesome!' primary CTA + 'Share' secondary CTA + a confetti ring).
//
// Visual contract mirrors the M2.2 RewardPopUp but is purpose-built
// for the drawing-complete flow: the title copy is celebration-flavored,
// the reward pills display the awarded coins/gem deltas, and the
// 'Awesome!' button ack's the overlay via the [onDone] callback.
//
// Usage:
//   `showDialog<void>(context: ctx, builder: (_) => DrawingCompleteOverlay(...))`
// =============================================================================

import 'package:flutter/material.dart';

import 'package:magic_colors/core/design/design_tokens.dart';
import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_shape.dart'
    show AppCorner, AppElevation;
import 'package:magic_colors/core/theme/app_typography.dart';
import 'package:magic_colors/core/widgets/confetti_burst.dart';
import 'package:magic_colors/core/widgets/primary_button.dart';
import 'package:magic_colors/core/widgets/secondary_button.dart'
    show SecondaryButton;

class DrawingCompleteOverlay extends StatelessWidget {
  const DrawingCompleteOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    this.coinDelta = 0,
    this.gemDelta = 0,
    this.seed,
    required this.onDone,
  });

  final String title;
  final String subtitle;
  final int coinDelta;
  final int gemDelta;
  final int? seed;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 24.0,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(40.0)),
      ),
      backgroundColor: AppColors.cloudWhite,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Confetti ring (decoration only).
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiBurst(
                seed: seed,
                count: 24,
                minDistance: 120.0,
                maxDistance: 180.0,
              ),
            ),
          ),
          // Foreground content.
          Padding(
            padding: AppSpacing.cardPaddingGenerous,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppSpacing.vGapSm,
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLg,
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  AppSpacing.vGapSm,
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.smoke,
                    ),
                  ),
                ],
                if (coinDelta > 0 || gemDelta > 0) ...<Widget>[
                  AppSpacing.vGapLg,
                  _RewardRow(
                    coinDelta: coinDelta,
                    gemDelta: gemDelta,
                  ),
                ],
                AppSpacing.vGapXl,
                PrimaryButton(
                  label: 'Awesome!',
                  fullWidth: true,
                  onPressed: onDone,
                ),
                AppSpacing.vGapSm,
                SecondaryButton(
                  label: 'Share',
                  fullWidth: true,
                  leading: Icons.ios_share_rounded,
                  onPressed: () {
                    // M2.4 — share flow is reserved; tap is a no-op
                    // tap-haptic so QA sees a satisfying response.
                  },
                ),
                AppSpacing.vGapSm,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.coinDelta,
    required this.gemDelta,
  });

  final int coinDelta;
  final int gemDelta;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (coinDelta > 0)
          _RewardPill(
            delta: coinDelta,
            fill: AppColors.coinGold,
            textColor: AppColors.deepInk,
          ),
        if (coinDelta > 0 && gemDelta > 0) AppSpacing.hGapMd,
        if (gemDelta > 0)
          _RewardPill(
            delta: gemDelta,
            fill: AppColors.gemRoyal,
            textColor: AppColors.cloudWhite,
          ),
      ],
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({
    required this.delta,
    required this.fill,
    required this.textColor,
  });

  final int delta;
  final Color fill;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppCorner.brMd,
        boxShadow: AppElevation.z1,
      ),
      child: Text(
        '+$delta',
        style: AppTypography.numericCompact.copyWith(color: textColor),
      ),
    );
  }
}
