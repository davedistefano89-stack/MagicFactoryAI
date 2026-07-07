// =============================================================================
// Magic Colors · features/home/presentation/widgets/event_banner.dart
// =============================================================================
//
// Daily Event banner — a large rounded MagicCard (accent skin) anchored
// at the bottom of the Home screen. Composes the MagicCard Foundation
// widget, a self-contained _AnimatedBadge pulse, a central illustration
// placeholder with an orbiting _SparkleRingPainter, an animated reward
// chest, and a full-width PrimaryButton PLAY NOW.
//
// Honours [SettingsState.reduceMotion]: every AnimationController pauses
// and snaps to its resting frame when reduceMotion is true; children
// fall back to a static layout. PLAY NOW taps fire analytics +
// a medium haptic before invoking [onPlayPressed].
//
// Public API: `const EventBanner({...})`. All helpers are file-private
// (no exports beyond `EventBanner`).
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/magic_card.dart';
import '../../../../core/widgets/primary_button.dart';

// ── Frozen tuning constants ──────────────────────────────────────────────────

const int _kDefaultCoinReward = 100;
const int _kDefaultGemReward = 20;

const double _kIllustrationDiameter = 96.0;
const double _kIllustrationStack = 168.0;
const double _kBadgeDiameter = 44.0;
const double _kChestDiameter = 36.0;
const double _kSparkleDiameter = 6.0;
const int _kSparkleCount = 6;

const double _kGlyphHaloAlpha = 0.18;
const double _kSparkleRingRadiusFactor = 0.42;
const double _kSparkleBaseAlpha = 0.40;
const double _kSparkleAlphaRange = 0.60;
const double _kHaloBorderWidth = 4.0;
// Used as the divide-by-two for `size.shortestSide / 2` centring in
// `_SparkleRingPainter`; misnaming it as a card-elevation factor would
// suggest intent the code does not back.
const double _kCenterDivisor = 2.0;
const double _kBadgeFontSize = 12.0;
const double _kBreathScaleMax = 1.02;
const double _kBadgeScaleMax = 1.18;
const double _kChestScaleMax = 1.10;

const double _kStarGlyphSize = 18.0;
const double _kEmojiGlyphSize = 56.0;
const double _kChestGlyphSize = 20.0;
const double _kGlyphIconSize = 14.0;
const double _kGlyphHaloSize = 24.0;
const double _kAllCapsTracking = 1.2;

const String _kDefaultEventLabel = 'Daily Event';
const String _kDefaultBadgeLabel = 'NEW';
const String _kDefaultEmoji = '🧜';
const String _kPlayNowLabel = 'PLAY NOW';

const String _kCoinGlyph = '🪙';
const String _kGemGlyph = '💎';
const String _kStarGlyph = '⭐';
const String _kChestGlyph = '🎁';
const String _kCoinsLabel = 'Coins';
const String _kGemsLabel = 'Gems';

// =============================================================================
//  EventBanner — public widget.
// =============================================================================

class EventBanner extends StatefulWidget {
  const EventBanner({
    super.key,
    required this.title,
    this.subtitle = "Complete today's drawing and earn extra rewards.",
    this.coinReward = _kDefaultCoinReward,
    this.gemReward = _kDefaultGemReward,
    this.emoji = _kDefaultEmoji,
    this.label = _kDefaultEventLabel,
    this.badgeLabel = _kDefaultBadgeLabel,
    this.onTap,
    this.onPlayPressed,
  });

  final String title;
  final String subtitle;
  final int coinReward;
  final int gemReward;
  final String emoji;
  final String label;
  final String badgeLabel;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPressed;

  @override
  State<EventBanner> createState() => _EventBannerState();
}

class _EventBannerState extends State<EventBanner>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: AppDuration.chestBreath,
  );
  late final Animation<double> _breathScale = Tween<double>(
    begin: 1.0,
    end: _kBreathScaleMax,
  ).animate(CurvedAnimation(parent: _breath, curve: AppCurves.gentle));

  late final AnimationController _badgePulse = AnimationController(
    vsync: this,
    duration: AppDuration.bubbleBounce,
  );
  late final Animation<double> _badgeScale = Tween<double>(
    begin: 1.0,
    end: _kBadgeScaleMax,
  ).animate(CurvedAnimation(parent: _badgePulse, curve: AppCurves.sparkle));

  late final AnimationController _chestBounce = AnimationController(
    vsync: this,
    duration: AppDuration.bubbleBounce,
  );
  late final Animation<double> _chestScale = Tween<double>(
    begin: 1.0,
    end: _kChestScaleMax,
  ).animate(
    CurvedAnimation(parent: _chestBounce, curve: AppCurves.rewardExplosion),
  );

  late final AnimationController _sparkle = AnimationController(
    vsync: this,
    duration: AppDuration.rainbowShimmer,
  );

  bool _breathActive = false;
  bool _badgeActive = false;
  bool _chestActive = false;
  bool _sparkleActive = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // Sparkle starts immediately so the first frame isn't empty even if
    // the SettingsState hasn't been resolved yet (rare but possible when
    // banner rendered during splash).
    _startSparkle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = context.watch<SettingsState>().reduceMotion;
    if (reduceMotion == _reduceMotion) {
      return;
    }
    _reduceMotion = reduceMotion;
    _syncAllControllers();
  }

  void _syncAllControllers() {
    if (_reduceMotion) {
      _stopAll();
    } else {
      _startAll();
    }
  }

  void _startAll() {
    if (!_breathActive) {
      _breath.repeat(reverse: true);
      _breathActive = true;
    }
    if (!_badgeActive) {
      _badgePulse.repeat(reverse: true);
      _badgeActive = true;
    }
    if (!_chestActive) {
      _chestBounce.repeat(reverse: true);
      _chestActive = true;
    }
    _startSparkle();
  }

  void _startSparkle() {
    if (!_sparkleActive) {
      _sparkle.repeat();
      _sparkleActive = true;
    }
  }

  void _stopAll() {
    if (_breathActive) {
      _breath.stop();
      _breath.value = 0.0;
      _breathActive = false;
    }
    if (_badgeActive) {
      _badgePulse.stop();
      _badgePulse.value = 0.0;
      _badgeActive = false;
    }
    if (_chestActive) {
      _chestBounce.stop();
      _chestBounce.value = 0.0;
      _chestActive = false;
    }
    if (_sparkleActive) {
      _sparkle.stop();
      _sparkle.value = 0.0;
      _sparkleActive = false;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _badgePulse.dispose();
    _chestBounce.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  void _handlePlayTap() {
    AnalyticsService.instance.trackEvent('home_event_play_pressed');
    Haptics.medium();
    widget.onPlayPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final starColor = isDark ? AppColors.moonbeam : AppColors.deepInk;

    return Semantics(
      label: 'Daily Event: ${widget.title}',
      button: widget.onTap != null,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final scale = _reduceMotion ? 1.0 : _breathScale.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: MagicCard(
          onTap: widget.onTap,
          skin: MagicCardSkin.accent,
          padding: const EdgeInsets.all(AppSpacing.lg),
          elevation: _reduceMotion ? AppElevation.z2 : AppElevation.z3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _kStarGlyph,
                        style: TextStyle(
                          fontSize: _kStarGlyphSize,
                          color: starColor,
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Text(
                        widget.label.toUpperCase(),
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.magicPurple,
                          letterSpacing: _kAllCapsTracking,
                        ),
                      ),
                    ],
                  ),
                  _AnimatedBadge(
                    label: widget.badgeLabel,
                    controller: _badgePulse,
                    animation: _badgeScale,
                    reduceMotion: _reduceMotion,
                  ),
                ],
              ),
              AppSpacing.vGapMd,
              _EventIllustration(
                emoji: widget.emoji,
                controller: _sparkle,
                reduceMotion: _reduceMotion,
              ),
              AppSpacing.vGapMd,
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTypography.titleMd,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.smoke,
                ),
              ),
              AppSpacing.vGapMd,
              _RewardRow(
                coinReward: widget.coinReward,
                gemReward: widget.gemReward,
                chestAnimation: _chestScale,
                reduceMotion: _reduceMotion,
              ),
              AppSpacing.vGapMd,
              Semantics(
                button: true,
                label: 'Play event: ${widget.title}',
                child: PrimaryButton(
                  label: _kPlayNowLabel,
                  onPressed:
                      widget.onPlayPressed == null ? null : _handlePlayTap,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  _RewardRow — coin + gem chips + animated chest icon.
// =============================================================================

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.coinReward,
    required this.gemReward,
    required this.chestAnimation,
    required this.reduceMotion,
  });

  final int coinReward;
  final int gemReward;
  final Animation<double> chestAnimation;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _RewardChip(
          glyph: _kCoinGlyph,
          glyphColor: AppColors.coinGold,
          count: coinReward,
          label: _kCoinsLabel,
        ),
        _RewardChip(
          glyph: _kGemGlyph,
          glyphColor: AppColors.gemRoyal,
          count: gemReward,
          label: _kGemsLabel,
        ),
        _ChestIcon(
          animation: chestAnimation,
          reduceMotion: reduceMotion,
        ),
      ],
    );
  }
}

// =============================================================================
//  _RewardChip — pill-shaped coin/gem counter.
// =============================================================================

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.glyph,
    required this.glyphColor,
    required this.count,
    required this.label,
  });

  final String glyph;
  final Color glyphColor;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $count',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cloudWhite,
          borderRadius: AppCorner.brMd,
          boxShadow: AppElevation.softChip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: _kGlyphHaloSize,
              height: _kGlyphHaloSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glyphColor.withValues(alpha: _kGlyphHaloAlpha),
              ),
              child: Text(
                glyph,
                style: const TextStyle(fontSize: _kGlyphIconSize),
              ),
            ),
            AppSpacing.hGapSm,
            Text(
              count.toString(),
              style: AppTypography.numericCompact.copyWith(
                color: AppColors.deepInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  _ChestIcon — animated reward chest in the reward row.
// =============================================================================

class _ChestIcon extends StatelessWidget {
  const _ChestIcon({
    required this.animation,
    required this.reduceMotion,
  });

  final Animation<double> animation;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Reward chest',
      child: ScaleTransition(
        scale: reduceMotion
            ? const AlwaysStoppedAnimation<double>(1.0)
            : animation,
        child: const SizedBox(
          width: _kChestDiameter,
          height: _kChestDiameter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.softChip,
              borderRadius: AppCorner.brSm,
              boxShadow: AppElevation.softChip,
            ),
            child: Center(
              child: Text(_kChestGlyph,
                  style: TextStyle(fontSize: _kChestGlyphSize)),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  _AnimatedBadge — top-right pulsing chip.
// =============================================================================

class _AnimatedBadge extends StatelessWidget {
  const _AnimatedBadge({
    required this.label,
    required this.controller,
    required this.animation,
    required this.reduceMotion,
  });

  final String label;
  final AnimationController controller;
  final Animation<double> animation;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    const pill = SizedBox(
      width: _kBadgeDiameter,
      height: _kBadgeDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.playNow,
          boxShadow: AppElevation.glowPink,
        ),
        child: Center(
          child: Text(
            _kDefaultBadgeLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _kBadgeFontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.cloudWhite,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'New event badge',
      child: reduceMotion
          ? pill
          : ScaleTransition(
              scale: animation,
              child: pill,
            ),
    );
  }
}

// =============================================================================
//  _EventIllustration — emoji + orbiting sparkle ring.
// =============================================================================

class _EventIllustration extends StatelessWidget {
  const _EventIllustration({
    required this.emoji,
    required this.controller,
    required this.reduceMotion,
  });

  final String emoji;
  final AnimationController controller;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kIllustrationStack,
      height: _kIllustrationStack,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (!reduceMotion)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SparkleRingPainter(
                      progress: controller.value,
                      color: AppColors.sunshineYellow,
                    ),
                  );
                },
              ),
            ),
          Container(
            width: _kIllustrationDiameter,
            height: _kIllustrationDiameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.skyDefault,
              border: Border.all(
                color: AppColors.cloudWhite,
                width: _kHaloBorderWidth,
              ),
              boxShadow: AppElevation.softChip,
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: _kEmojiGlyphSize),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _SparkleRingPainter — orbits [_kSparkleCount] dots around the centre.
// =============================================================================

class _SparkleRingPainter extends CustomPainter {
  _SparkleRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center =
        Offset(size.width / _kCenterDivisor, size.height / _kCenterDivisor);
    final radius = size.shortestSide * _kSparkleRingRadiusFactor;
    const fullTurn = math.pi * 2;
    for (var i = 0; i < _kSparkleCount; i++) {
      final phase = i / _kSparkleCount;
      final angle = (phase + progress) * fullTurn;
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      final eased = AppCurves.sparkle.transform(phase);
      final opacity = _kSparkleBaseAlpha + _kSparkleAlphaRange * eased;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), _kSparkleDiameter, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
