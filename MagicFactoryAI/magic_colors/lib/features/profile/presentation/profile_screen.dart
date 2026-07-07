// =============================================================================
// Magic Colors · features/profile/presentation/profile_screen.dart
// =============================================================================
//
// The Profile shell branch destination. Shows the child's avatar, colouring
// stats (drawings completed, worlds unlocked, streak), and a compact
// achievement gallery.
//
//   ▸ Avatar card     — mascot + child name + edit button.
//   ▸ Stats row       — 3 stat cards (drawings, worlds, streak).
//   ▸ Achievements    — scrollable grid of earned badges.
//
// DESIGN TOKENS
//   Colour palette, spacing, and typography strictly follow the
//   `AppColors` / `AppSpacing` / `AppTypography` token catalogue.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/routing/app_router.dart' show GoRouterContextX;
import '../../../core/services/analytics_service.dart';
import '../../../core/state/player_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/magic_card.dart';
import '../../../core/widgets/mascot_avatar.dart';
import '../../../core/widgets/parent_gate.dart';

// ── Tuning constants ──────────────────────────────────────────────────

const String _kSemanticsLabel = 'Profile screen';
const double _kBadgeSize = 64.0;

// =============================================================================
//  ProfileScreen — the public widget.
// =============================================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerState player = context.watch<PlayerState>();

    return AnimatedBackground(
      child: SafeArea(
        bottom: false,
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
                Text('👤 Profile', style: AppTypography.titleLg),
                AppSpacing.vGapLg,

                // ── Avatar card ─────────────────────────────────
                _AvatarCard(
                  player: player,
                  onEditTap: () => _onSettingsTap(context),
                ),
                AppSpacing.vGapLg,

                // ── Stats row ───────────────────────────────────
                _StatsRow(player: player),
                AppSpacing.vGapLg,

                // ── Achievements ────────────────────────────────
                Text('🏆 Achievements', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                const _AchievementGrid(),
                AppSpacing.vGapLg,

                // ── Quick links ─────────────────────────────────
                Text('⚙️ Quick Links', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                _QuickLink(
                  icon: '🔔',
                  label: 'Notifications & Rewards',
                  onTap: () {
                    Haptics.light();
                    context.goRewards();
                  },
                ),
                _QuickLink(
                  icon: '👑',
                  label: 'Magic Premium',
                  onTap: () => _onPremiumTap(context),
                ),
                _QuickLink(
                  icon: '👨‍👩‍👧',
                  label: 'Parents Area',
                  onTap: () => _onParentsTap(context),
                ),
                AppSpacing.vGapXl,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSettingsTap(BuildContext context) {
    AnalyticsService.instance.trackEvent('profile_settings_tapped');
    Haptics.light();
    context.goSettings();
  }

  /// M2.4 — gate the Parents Area behind the ParentGate maths challenge.
  void _onParentsTap(BuildContext context) {
    AnalyticsService.instance.trackEvent('profile_parents_tapped');
    Haptics.medium();
    showParentGate(context).then((bool? passed) {
      if (passed == true && context.mounted) {
        context.goSettings();
      }
    });
  }

  /// M2.4 — gate the Premium link behind the ParentGate.
  void _onPremiumTap(BuildContext context) {
    AnalyticsService.instance.trackEvent('profile_premium_tapped');
    Haptics.medium();
    showParentGate(context).then((bool? passed) {
      if (passed == true && context.mounted) {
        context.goPremium();
      }
    });
  }
}

// =============================================================================
//  Widgets.
// =============================================================================

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.player, required this.onEditTap});

  final PlayerState player;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.brLg,
      borderColor: AppColors.magicPurple.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: <Widget>[
          const MascotAvatar(),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Magic Artist', style: AppTypography.titleSm),
                AppSpacing.vGapSm,
                Text(
                  'Level ${(player.streakDays ~/ 3) + 1} • '
                  '${player.streakDays}-day streak! 🔥',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.smoke,
                  ),
                ),
                AppSpacing.vGapSm,
                Row(
                  children: <Widget>[
                    _MiniBadge(icon: '🪙', value: player.coins.toString()),
                    const SizedBox(width: AppSpacing.md),
                    _MiniBadge(icon: '💎', value: player.gems.toString()),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditTap,
            icon: const Icon(Icons.edit, color: AppColors.magicPurple),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.value});

  final String icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cloudWhite,
        borderRadius: AppCorner.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(value, style: AppTypography.buttonSm),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: _StatCard(
            icon: '🎨',
            label: 'Drawings',
            value: '—',
            color: AppColors.magicPink,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: '🌍',
            label: 'Worlds',
            value: player.ownedWorldIds.length.toString(),
            color: AppColors.skyCyan,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: '🔥',
            label: 'Streak',
            value: '${player.streakDays}d',
            color: AppColors.tangerine,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
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
          Text(icon, style: const TextStyle(fontSize: 32)),
          AppSpacing.vGapSm,
          Text(value, style: AppTypography.numericCompact),
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

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid();

  static const List<_Badge> _badges = <_Badge>[
    _Badge(icon: '🎨', label: 'First Drawing', unlocked: true),
    _Badge(icon: '🔥', label: '3-Day Streak', unlocked: true),
    _Badge(icon: '🌍', label: 'World Explorer', unlocked: true),
    _Badge(icon: '🖼', label: 'Gallery Filled', unlocked: false),
    _Badge(icon: '👑', label: 'Premium Star', unlocked: false),
    _Badge(icon: '💎', label: 'Gem Hoarder', unlocked: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _badges.map((b) => _AchievementBadge(badge: b)).toList(),
    );
  }
}

class _Badge {
  const _Badge({
    required this.icon,
    required this.label,
    required this.unlocked,
  });

  final String icon;
  final String label;
  final bool unlocked;
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: _kBadgeSize,
          height: _kBadgeSize,
          decoration: BoxDecoration(
            color: badge.unlocked
                ? AppColors.sunshineYellow.withValues(alpha: 0.2)
                : AppColors.smoke.withValues(alpha: 0.1),
            borderRadius: AppCorner.brSm,
            border: Border.all(
              color: badge.unlocked
                  ? AppColors.sunshineYellow.withValues(alpha: 0.4)
                  : AppColors.smoke.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: badge.unlocked ? 1.0 : 0.35,
              child: Text(badge.icon, style: const TextStyle(fontSize: 28)),
            ),
          ),
        ),
        AppSpacing.vGapSm,
        Text(
          badge.label,
          style: AppTypography.caption(
            size: 10,
            color: badge.unlocked ? AppColors.deepInk : AppColors.smoke,
          ),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppCorner.brMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 24)),
                AppSpacing.hGapMd,
                Expanded(child: Text(label, style: AppTypography.bodyMedium)),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.smoke,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
