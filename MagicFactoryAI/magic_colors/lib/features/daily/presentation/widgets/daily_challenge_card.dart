// =============================================================================
// Magic Colors · features/daily/presentation/widgets/daily_challenge_card.dart
// =============================================================================
//
// Sprint 7 — per-day challenges card for the Home. Renders the
// 3 active challenges (selected by [DailyChallengeService.listToday])
// with progress bars, a "Claim" CTA per row (or "Claimed" badge
// once the reward is in), and a "X more to go" caption.
//
// State reactivity
//   The card watches `PlayerState` so the progress bars + CTAs
//   stay in lock-step with the persisted counters (drawings,
//   stars). The card also honours `SettingsState.reduceMotion`
//   via the [ConfettiBurst] dependency.
//
// Routing
//   The card sits between the existing [DailyRewardCard] and the
//   [MascotSection] on the Home so the visual hierarchy is
//   reward → challenges → mascot → play → event → quick actions.
//   Adding the card is a single widget insertion in
//   `_HomeScrollView`; the ContinueBanner-style hero above is
//   untouched per the Sprint-7 brief.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/daily/daily_challenge_service.dart';
import '../../../../core/state/player_state.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/magic_card.dart';
import '../../../../core/widgets/primary_button.dart';

class DailyChallengeCard extends StatelessWidget {
  const DailyChallengeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final List<DailyChallengeProgress> progress =
        DailyChallengeService.snapshotToday(player);
    if (progress.isEmpty) {
      return const SizedBox.shrink();
    }
    final reduceMotion = context.watch<SettingsState>().reduceMotion;

    return MagicCard(
      skin: MagicCardSkin.tinted,
      padding: AppSpacing.cardPaddingGenerous,
      borderRadius: AppCorner.brLg,
      borderColor: AppColors.magicPurple.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Today\u2019s challenges', style: AppTypography.titleSm),
              const Text('⚡', style: TextStyle(fontSize: 22)),
            ],
          ),
          AppSpacing.vGapSm,
          for (int i = 0; i < progress.length; i++) ...<Widget>[
            _ChallengeRow(
              progress: progress[i],
              showConfetti: !reduceMotion && i == 0,
            ),
            if (i < progress.length - 1) AppSpacing.vGapSm,
          ],
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.progress,
    required this.showConfetti,
  });

  final DailyChallengeProgress progress;
  final bool showConfetti;

  void _onClaim(BuildContext context) {
    final player = context.read<PlayerState>();
    Haptics.success();
    final DailyChallengeClaimResult result =
        DailyChallengeService.claim(progress.challenge, player);
    AnalyticsService.instance.trackEvent(
      'daily_challenge_claim_pressed',
      <String, Object?>{'id': progress.challenge.id, 'result': result.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final c = p.challenge;
    final Color borderColor = p.canClaim
        ? AppColors.success.withValues(alpha: 0.55)
        : AppColors.smoke.withValues(alpha: 0.30);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.cloudWhite.withValues(alpha: 0.85),
            borderRadius: AppCorner.brMd,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      c.title,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.deepInk),
                    ),
                  ),
                  if (p.isClaimed) const _ClaimedBadge(),
                ],
              ),
              const SizedBox(height: 2),
              _ProgressBar(fraction: p.fraction),
              const SizedBox(height: 4),
              Text(
                p.isClaimed
                    ? 'Reward collected'
                    : '${p.current} / ${p.target} \u2014 ${c.description}',
                style: AppTypography.caption(color: AppColors.smoke),
              ),
              if (p.canClaim) ...<Widget>[
                AppSpacing.vGapSm,
                PrimaryButton(
                  label: _buildClaimLabel(c.rewardCoins, c.rewardGems),
                  fullWidth: true,
                  size: PrimaryButtonSize.compact,
                  gradient: AppGradients.playNow,
                  onPressed: () => _onClaim(context),
                ),
              ] else if (!p.isClaimed) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  '${p.remaining} more to go',
                  style: AppTypography.caption(color: AppColors.smoke),
                ),
              ],
            ],
          ),
        ),
        if (showConfetti && p.isClaimed)
          const Positioned(
            right: -10,
            top: -10,
            child: IgnorePointer(
              child: ConfettiBurst(seed: 0xDA11A, count: 12),
            ),
          ),
      ],
    );
  }

  String _buildClaimLabel(int coins, int gems) {
    final List<String> parts = <String>[];
    if (coins > 0) parts.add('\uD83E\uDE99 $coins');
    if (gems > 0) parts.add('\uD83D\uDC8E $gems');
    if (parts.isEmpty) return 'Claim';
    return 'Claim ${parts.join(' + ')}';
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${(fraction * 100).round()} percent complete',
      child: Stack(
        children: <Widget>[
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.smoke.withValues(alpha: 0.20),
              borderRadius: AppCorner.brSm,
            ),
          ),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              height: 6,
              decoration: const BoxDecoration(
                gradient: AppGradients.secondaryCta,
                borderRadius: AppCorner.brSm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimedBadge extends StatelessWidget {
  const _ClaimedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.20),
        borderRadius: AppCorner.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('\u2705', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            'Claimed',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.success,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
