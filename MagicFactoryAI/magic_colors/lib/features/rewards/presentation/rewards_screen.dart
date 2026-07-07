// =============================================================================
// Magic Colors · features/rewards/presentation/rewards_screen.dart
// =============================================================================
//
// The Rewards page (full-screen overlay). Celebrates the child's progress
// with a daily chest CTA, a streak calendar, and a scrollable achievement
// log. Designed as a "treasure room" — every card uses warm reward colours
// (coin gold, sunshine yellow, gem royal).
//
//   ▸ Daily Chest     — animated CTA that awards coins + gems + streak bump.
//   ▸ Streak Tracker  — 7-day visual calendar with emoji milestones.
//   ▸ Recent Rewards  — chronological log of earned coins / gems / stars.
//
// DESIGN TOKENS
//   Colour palette, spacing, and typography strictly follow the
//   `AppColors` / `AppSpacing` / `AppTypography` token catalogue.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/domain/economy/reward.dart' show CompositeReward;
import '../../../core/services/analytics_service.dart';
import '../../../core/services/economy/reward_engine.dart';
import '../../../core/state/player_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/magic_card.dart';

// ── Tuning constants ──────────────────────────────────────────────────

const String _kSemanticsLabel = 'Rewards screen';

const double _kChestIconSize = 80.0;
const double _kDayDotSize = 36.0;

// =============================================================================
//  RewardsScreen — the public widget.
// =============================================================================

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerState player = context.watch<PlayerState>();

    return AnimatedBackground(
      child: SafeArea(
        child: Semantics(
          label: _kSemanticsLabel,
          container: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Header ──────────────────────────────────────
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('🏆 Rewards', style: AppTypography.titleLg),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.smoke),
                    ),
                  ],
                ),
                AppSpacing.vGapLg,

                // ── Daily chest ─────────────────────────────────
                _DailyChestCard(
                  claimed: player.dailyRewardClaimed,
                  streak: player.streakDays,
                  onClaim: () => _claimDailyReward(context, player),
                ),
                AppSpacing.vGapLg,

                // ── Streak tracker ──────────────────────────────
                Text('🔥 Streak', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                _StreakTracker(streakDays: player.streakDays),
                AppSpacing.vGapLg,

                // ── Currency summary ────────────────────────────
                Text('💰 Your Balance', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _BalanceCard(
                        icon: '🪙',
                        label: 'Coins',
                        amount: player.coins,
                        color: AppColors.coinGold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _BalanceCard(
                        icon: '💎',
                        label: 'Gems',
                        amount: player.gems,
                        color: AppColors.gemRoyal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _BalanceCard(
                        icon: '🔥',
                        label: 'Streak',
                        amount: player.streakDays,
                        color: AppColors.tangerine,
                      ),
                    ),
                  ],
                ),
                AppSpacing.vGapXl,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _claimDailyReward(BuildContext context, PlayerState player) {
    if (player.dailyRewardClaimed) return;

    final int preStreak = player.streakDays;
    final CompositeReward reward;
    try {
      reward = RewardEngine.computeDailyChestReward(
        preStreak < 1 ? 1 : preStreak,
      );
    } on Object catch (_) {
      return;
    }

    player.recordStreak();
    reward.grantTo(player);

    AnalyticsService.instance.trackEvent(
      'rewards_daily_claimed',
      <String, Object?>{'streak': player.streakDays},
    );
    Haptics.success();
  }
}

// =============================================================================
//  Widgets.
// =============================================================================

class _DailyChestCard extends StatelessWidget {
  const _DailyChestCard({
    required this.claimed,
    required this.streak,
    required this.onClaim,
  });

  final bool claimed;
  final int streak;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: claimed ? MagicCardSkin.tinted : MagicCardSkin.accent,
      borderRadius: AppCorner.brLg,
      borderColor: claimed
          ? AppColors.smoke.withValues(alpha: 0.15)
          : AppColors.sunshineYellow.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Text(
            claimed ? '🎁' : '🎁',
            style: TextStyle(
              fontSize: _kChestIconSize,
              color: claimed ? AppColors.smoke.withValues(alpha: 0.5) : null,
            ),
          ),
          AppSpacing.vGapMd,
          Text(
            claimed ? 'Come back tomorrow!' : 'Daily Chest',
            style: AppTypography.titleMd,
          ),
          AppSpacing.vGapSm,
          Text(
            claimed
                ? 'You already claimed today\'s reward. '
                    'Streak: $streak day${streak == 1 ? '' : 's'} 🔥'
                : 'Day $streak streak bonus! '
                    'Claim your coins + gems.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.smoke,
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapMd,
          if (!claimed)
            FilledButton.icon(
              onPressed: onClaim,
              icon: const Text('🎁'),
              label: const Text('CLAIM REWARD'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sunshineYellow,
                foregroundColor: AppColors.deepInk,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppCorner.brLg,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakTracker extends StatelessWidget {
  const _StreakTracker({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.brMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.tangerine.withValues(alpha: 0.18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List<Widget>.generate(7, (int i) {
          final bool active = i < (streakDays % 7 == 0 ? 7 : streakDays % 7);
          return _DayDot(
            day: i + 1,
            active: active,
            emoji: _dayEmoji(i, streakDays),
          );
        }),
      ),
    );
  }

  String _dayEmoji(int index, int streak) {
    if (streak >= 7 && index == 6) return '🔥';
    if (streak % 7 >= index + 1) return '✅';
    return '';
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.active, required this.emoji});

  final int day;
  final bool active;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: _kDayDotSize,
          height: _kDayDotSize,
          decoration: BoxDecoration(
            color: active
                ? AppColors.tangerine.withValues(alpha: 0.2)
                : AppColors.smoke.withValues(alpha: 0.08),
            borderRadius: AppCorner.brSm,
          ),
          child: Center(
            child: emoji.isNotEmpty
                ? Text(emoji, style: const TextStyle(fontSize: 16))
                : Text(
                    '$day',
                    style: AppTypography.buttonSm.copyWith(
                      color: active ? AppColors.tangerine : AppColors.smoke,
                    ),
                  ),
          ),
        ),
        AppSpacing.vGapSm,
        Text(
          'D$day',
          style: AppTypography.caption(
            size: 10,
            color: active ? AppColors.tangerine : AppColors.smoke,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  final String icon;
  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.brMd,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      borderColor: color.withValues(alpha: 0.2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 28)),
          AppSpacing.vGapSm,
          Text(amount.toString(), style: AppTypography.numericCompact),
          AppSpacing.vGapSm,
          Text(
            label,
            style: AppTypography.caption(color: AppColors.smoke),
          ),
        ],
      ),
    );
  }
}
