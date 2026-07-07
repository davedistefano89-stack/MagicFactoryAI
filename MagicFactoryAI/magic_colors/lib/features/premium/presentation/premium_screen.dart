// =============================================================================
// Magic Colors · features/premium/presentation/premium_screen.dart
// =============================================================================
//
// The Premium page (full-screen overlay). Showcases the Magic Premium
// subscription benefits in a vertically stacked card layout. Actual
// purchase flows route through the platform store (App Store / Play Store);
// this screen is purely informational + CTA.
//
//   ▸ Hero card        — rainbow gradient, unicorn mascot, price badge.
//   ▸ Feature list     — 4 MagicCards with emoji + title + description.
//   ▸ Subscribe CTA    — large pink gradient button → platform store.
//   ▸ Restore button   — small text link at bottom.
//
// DESIGN TOKENS
//   Colour palette, spacing, and typography strictly follow the
//   `AppColors` / `AppSpacing` / `AppTypography` token catalogue.
// =============================================================================

import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/magic_card.dart';

// ── Tuning constants ──────────────────────────────────────────────────

const String _kSemanticsLabel = 'Premium screen';

const double _kFeatureIconSize = 40.0;

// =============================================================================
//  PremiumScreen — the public widget.
// =============================================================================

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: SafeArea(
        child: Semantics(
          label: _kSemanticsLabel,
          container: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: AppSpacing.pagePadding,
            child: Column(
              children: <Widget>[
                // ── Close button ────────────────────────────────
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.smoke),
                  ),
                ),
                AppSpacing.vGapMd,

                // ── Hero card ───────────────────────────────────
                _HeroCard(onSubscribe: () => _onSubscribe(context)),
                AppSpacing.vGapLg,

                // ── Feature cards ───────────────────────────────
                ..._features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _FeatureCard(feature: f),
                  ),
                ),
                AppSpacing.vGapLg,

                // ── Subscribe button ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _onSubscribe(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.magicPink,
                      foregroundColor: AppColors.cloudWhite,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppCorner.brLg,
                      ),
                    ),
                    child: Text(
                      'SUBSCRIBE NOW — €4.99/month',
                      style: AppTypography.buttonMd.copyWith(
                        color: AppColors.cloudWhite,
                      ),
                    ),
                  ),
                ),
                AppSpacing.vGapMd,

                // ── Restore ─────────────────────────────────────
                TextButton(
                  onPressed: () => _onRestore(context),
                  child: Text(
                    'Restore purchases',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.magicPurple,
                    ),
                  ),
                ),
                AppSpacing.vGapMd,

                // ── Fine print ──────────────────────────────────
                Text(
                  'Subscription renews automatically. Cancel anytime '
                  'in your device settings. No ads, ever — even in the '
                  'free tier.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(size: 11),
                ),
                AppSpacing.vGapXl,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSubscribe(BuildContext context) {
    AnalyticsService.instance.trackEvent('premium_subscribe_tapped');
    Haptics.heavy();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🎉 Store flow will open here (Sprint 3)')),
    );
  }

  void _onRestore(BuildContext context) {
    AnalyticsService.instance.trackEvent('premium_restore_tapped');
    Haptics.light();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Checking for previous purchases…'),
      ),
    );
  }
}

// =============================================================================
//  Data.
// =============================================================================

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final String icon;
  final String title;
  final String description;
}

const List<_Feature> _features = <_Feature>[
  _Feature(
    icon: '🎨',
    title: 'Unlimited Colors',
    description: 'Access every colour in every palette — no locked swatches, '
        'no premium gates while colouring.',
  ),
  _Feature(
    icon: '🌍',
    title: 'All Worlds Unlocked',
    description: 'Explore every magical land from day one. New worlds added '
        'every month at no extra cost.',
  ),
  _Feature(
    icon: '💎',
    title: 'Double Daily Rewards',
    description: 'Earn 2× coins and gems from the daily chest. Your streak '
        'grows twice as fast!',
  ),
  _Feature(
    icon: '🖼',
    title: 'Unlimited Gallery',
    description: 'Save as many drawings as you want — no cap on your '
        'personal art collection.',
  ),
];

// =============================================================================
//  Widgets.
// =============================================================================

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onSubscribe});

  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.accent,
      borderRadius: AppCorner.brLg,
      borderColor: AppColors.magicPurple.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          const Text('🦄', style: TextStyle(fontSize: 72)),
          AppSpacing.vGapMd,
          Text(
            'Magic Premium',
            style: AppTypography.titleLg,
          ),
          AppSpacing.vGapSm,
          Text(
            'Unlock the full rainbow',
            style: AppTypography.bodyXl.copyWith(
              color: AppColors.smoke,
            ),
          ),
          AppSpacing.vGapMd,
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.magicPurple.withValues(alpha: 0.1),
              borderRadius: AppCorner.brSm,
            ),
            child: Text(
              '€4.99 / month',
              style: AppTypography.numericCompact.copyWith(
                color: AppColors.magicPurple,
              ),
            ),
          ),
          AppSpacing.vGapSm,
          Text(
            '7-day free trial • Cancel anytime',
            style: AppTypography.caption(),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.brMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.magicPurple.withValues(alpha: 0.1),
      child: Row(
        children: <Widget>[
          Container(
            width: _kFeatureIconSize + 16,
            height: _kFeatureIconSize + 16,
            decoration: BoxDecoration(
              color: AppColors.magicPurple.withValues(alpha: 0.1),
              borderRadius: AppCorner.brSm,
            ),
            child: Center(
              child: Text(
                feature.icon,
                style: const TextStyle(fontSize: _kFeatureIconSize),
              ),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(feature.title, style: AppTypography.titleSm),
                AppSpacing.vGapSm,
                Text(
                  feature.description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.smoke,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
