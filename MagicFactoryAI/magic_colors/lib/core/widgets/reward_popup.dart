// =============================================================================
// Magic Colors · core/widgets/reward_popup.dart
// =============================================================================
//
// The "you earned X" modal card. Triggered whenever a reward is granted
// (drawing complete, world unlock, daily chest open, parent-purchase
// confirmation). The widget renders the celebration chrome — the caller
// decides which surface to drop it into (`Dialog`, `showModalBottomSheet`,
// full-screen overlay).
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §11):
//   ▸ Card:        AppShapeBorder.rewardPopup (40 dp corners).
//   ▸ Fill:        AppColors.cloudWhite.
//   ▸ Title:       AppTypography.displayLg (36 / 800).
//   ▸ Subtitle:    AppTypography.bodyLg in AppColors.smoke.
//   ▸ Reward row:  Two pills (coin / gem) only when their delta > 0 —
//                  clean chrome for non-currency rewards (world unlocks).
//   ▸ CTA:         PrimaryButton 'Awesome!' + SecondaryButton 'Share'.
//   ▸ Confetti:    18 hard-coded positions orbiting the card edge,
//                 AppDuration.confettiDecay — auto-decays on dismiss.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart' show AppDuration, AppSpacing;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shape.dart';
import '../theme/app_typography.dart';
import '../utils/haptics.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

// =============================================================================
//  RewardPopUp — modal celebration card.
// =============================================================================

class RewardPopUp extends StatefulWidget {
  const RewardPopUp({
    super.key,
    required this.title,
    this.subtitle,
    this.coinDelta = 0,
    this.gemDelta = 0,
    this.onDismiss,
    this.seed,
  });

  /// Title — usually "WOW!" / "+5 coins" / "World unlocked!". Required.
  final String title;

  /// Optional supporting copy.
  final String? subtitle;

  /// Coin delta. `0` removes the coin pill from the chrome.
  final int coinDelta;

  /// Gem delta. `0` removes the gem pill from the chrome.
  final int gemDelta;

  /// Optional dismiss callback. Fires after the confetti starts its
  /// reverse animation (so callers see the decay before they're popped).
  final VoidCallback? onDismiss;

  /// Optional confetti seed so the random dot positions are stable across
  /// re-mounts (useful for screenshot diffing in QA).
  final int? seed;

  @override
  State<RewardPopUp> createState() => _RewardPopUpState();
}

class _RewardPopUpState extends State<RewardPopUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: AppDuration.confettiDecay,
  )..forward();

  late final List<_ConfettiSpec> _confettiSpecs;
  late final math.Random _rng;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(widget.seed ?? 0xBADF00D);
    _confettiSpecs = List<_ConfettiSpec>.generate(18, (_) {
      final angle = _rng.nextDouble() * math.pi * 2.0;
      final distance = 80.0 + _rng.nextDouble() * 60.0;
      final color = AppGradients
          .rainbowStops[_rng.nextInt(AppGradients.rainbowStops.length)];
      return _ConfettiSpec(angle: angle, distance: distance, color: color);
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    Haptics.medium();
    _confetti.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 16.0,
      shape: AppShapeBorder.rewardPopup,
      color: AppColors.cloudWhite,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: AppSpacing.cardPaddingGenerous,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Confetti ring (decoration layer).
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _confetti.value,
                        specs: _confettiSpecs,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Content.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AppSpacing.vGapSm,
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLg,
                ),
                if (widget.subtitle != null) ...<Widget>[
                  AppSpacing.vGapSm,
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.smoke,
                    ),
                  ),
                ],
                if (widget.coinDelta > 0 || widget.gemDelta > 0) ...<Widget>[
                  AppSpacing.vGapLg,
                  _RewardRow(
                    coinDelta: widget.coinDelta,
                    gemDelta: widget.gemDelta,
                  ),
                ],
                AppSpacing.vGapXl,
                PrimaryButton(
                  label: 'Awesome!',
                  fullWidth: true,
                  onPressed: _handleDismiss,
                ),
                AppSpacing.vGapSm,
                const SecondaryButton(
                  label: 'Share',
                  fullWidth: true,
                  leading: Icons.ios_share_rounded,
                  onPressed: Haptics.light,
                ),
                AppSpacing.vGapSm,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _ConfettiSpec / _ConfettiPainter — confetti ring rendering.
// =============================================================================

class _ConfettiSpec {
  const _ConfettiSpec({
    required this.angle,
    required this.distance,
    required this.color,
  });

  final double angle;
  final double distance;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.specs,
  });

  final double progress;
  final List<_ConfettiSpec> specs;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final centre = Offset(size.width / 2.0, size.height / 2.0);

    for (final s in specs) {
      final r = s.distance * progress;
      final dx = centre.dx + math.cos(s.angle) * r;
      final dy = centre.dy + math.sin(s.angle) * r;
      final op = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = s.color.withValues(alpha: op);
      canvas.drawCircle(Offset(dx, dy), 6.0 + 4.0 * (1.0 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// =============================================================================
//  _RewardRow — coin + gem pill row, hidden individually when delta = 0.
// =============================================================================

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.coinDelta,
    required this.gemDelta,
  });

  final int coinDelta;
  final int gemDelta;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
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
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: pills,
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
        boxShadow: AppElevation.softChip,
      ),
      child: Text(
        '+$delta',
        style: AppTypography.numericCompact.copyWith(color: textColor),
      ),
    );
  }
}
