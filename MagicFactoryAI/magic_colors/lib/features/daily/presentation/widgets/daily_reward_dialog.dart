// =============================================================================
// Magic Colors · features/daily/presentation/widgets/daily_reward_dialog.dart
// =============================================================================
//
// Sprint 7 — celebration dialog for the daily reward. Modal
// rendering with a tinted scrim; the card title announces the
// day-N streak, the pill row surfaces coins + gems + the optional
// item glyph (palette / brush / gradient), and a single
// "Awesome!" CTA dismisses.
//
// DIFFERENCE FROM [RewardPopUp]
//   The [RewardPopUp] widget already exists for "you earned X"
//   moments. The daily-reward dialog adds:
//     • the streak-day headline ("Day 3 streak!"),
//     • an optional item pill (palette/brush/gradient glyph),
//     • a deterministic dialog anchor so the Home / Rewards
//       surfaces can pop it on a specific day.
//
// Reuses the existing design system: MagicCard (tinted skin) +
// AppGradients.playNow on the primary button + the canonical
// typography stack. No new colors, no new theme constants.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/domain/daily/daily_reward_entry.dart';
import '../../../../core/domain/daily/daily_reward_summary.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/magic_card.dart';
import '../../../../core/widgets/primary_button.dart';

/// Convenience entry point — pops the daily-reward dialog for
/// [summary]. Returns the [Future] that completes when the dialog
/// is dismissed. Safe to call with any [DailyRewardSummary]
/// (the dialog renders the empty-state for `coins == 0 && gems == 0
/// && item == null`).
Future<void> showDailyRewardDialog(
  BuildContext context, {
  required DailyRewardSummary summary,
}) async {
  AnalyticsService.instance.trackEvent(
    'daily_reward_dialog_shown',
    <String, Object?>{'day': summary.streakDay},
  );
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext ctx) => _DailyRewardDialog(summary: summary),
  );
}

class _DailyRewardDialog extends StatelessWidget {
  const _DailyRewardDialog({required this.summary});

  final DailyRewardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: MagicCard(
            skin: MagicCardSkin.accent,
            elevation: AppElevation.z3,
            borderColor: AppColors.tangerine,
            borderRadius: AppCorner.brLg,
            padding: AppSpacing.cardPaddingGenerous,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Text(
                    'Day ${summary.streakDay} streak!',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLg,
                  ),
                ),
                AppSpacing.vGapSm,
                Text(
                  'Your daily reward is ready.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.smoke,
                  ),
                ),
                AppSpacing.vGapLg,
                _RewardRow(summary: summary),
                AppSpacing.vGapLg,
                PrimaryButton(
                  label: 'Awesome!',
                  fullWidth: true,
                  gradient: AppGradients.playNow,
                  onPressed: () {
                    Haptics.success();
                    AnalyticsService.instance.trackEvent(
                      'daily_reward_dialog_dismissed',
                      <String, Object?>{'day': summary.streakDay},
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.summary});

  final DailyRewardSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pills = <Widget>[];
    if (summary.coins > 0) {
      pills.add(_Pill(
        glyph: '\uD83E\uDE99',
        amount: summary.coins,
        fill: AppColors.coinGold,
        textColor: AppColors.deepInk,
      ));
    }
    if (summary.gems > 0) {
      if (pills.isNotEmpty) AppSpacing.hGapMd;
      pills.add(_Pill(
        glyph: '\uD83D\uDC8E',
        amount: summary.gems,
        fill: AppColors.gemRoyal,
        textColor: AppColors.cloudWhite,
      ));
    }
    final DailyRewardEntry? item = summary.item;
    if (item != null) {
      if (pills.isNotEmpty) AppSpacing.hGapMd;
      pills.add(_Pill(
        glyph: item.glyph,
        amount: 0,
        fill: AppColors.magicPurple,
        textColor: AppColors.cloudWhite,
        trailingLabel: item.label,
      ));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: pills,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.glyph,
    required this.amount,
    required this.fill,
    required this.textColor,
    this.trailingLabel,
  });

  final String glyph;
  final int amount;
  final Color fill;
  final Color textColor;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final bool hasAmount = amount > 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: hasAmount || trailingLabel == null
            ? AppSpacing.md
            : AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppCorner.brMd,
        boxShadow: AppElevation.softChip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(glyph, style: const TextStyle(fontSize: 22)),
          if (hasAmount) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              '+$amount',
              style: AppTypography.numericCompact.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (trailingLabel != null) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Text(
              trailingLabel!,
              style: AppTypography.labelMd.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
