// =============================================================================
// Magic Colors · features/home/presentation/widgets/mascot_section.dart
// =============================================================================
//
// The central hero block of the Home screen. Sits between the header
// strip and the PLAY NOW button — its only job is to greet the player,
// breathe the unicorn mascot, and tickle the eye with a small
// breathing-sparkle ornament.
//
// Composes the MascotAvatar Foundation widget, reads PlayerState
// (streakDays / avatarId) and SettingsState (reduceMotion) for variant
// branching + accessibility. No Foundation edits — every token resolves
// from the design system.
//
// Public API:  const MascotSection({super.key}).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/state/player_state.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/mascot_avatar.dart';

// ── Frozen greeting copy ────────────────────────────────────────────────────

/// v1.0 default player-facing name. Will be replaced by a per-avatar
/// catalog lookup once the avatar pack ships (avatarId → displayName).
const String _kPlayerDisplayName = 'Sophia';

/// Default subtitle when [PlayerState.streakDays] is zero (fresh install
/// or streak just reset).
const String _kSubtitleFreshStart = 'Ready for some magic?';

/// ── Tuning tokens (named so the no-magic-numbers lint stays happy) ────────

/// Avatar diameter on the Home hero strip.
const double _kAvatarDiameter = 128.0;

/// Number of dots in the breathing-sparkle ornament.
const int _kSparkleDotCount = 4;

/// Diameter of each sparkle dot.
const double _kSparkleDotDiameter = 10.0;

/// Minimum sparkle scale (0 → 1 cycle, sparkles dip before they peak).
const double _kSparkleMinScale = 0.70;

/// Maximum sparkle scale (peak of the breath).
const double _kSparkleMaxScale = 1.00;

/// Minimum sparkle opacity at the dip.
const double _kSparkleMinAlpha = 0.45;

/// Maximum sparkle opacity at the peak.
const double _kSparkleMaxAlpha = 1.00;

/// Phase offsets for the four-dot wave. 0 = first dot leads, 1 = last.
/// Indexed parallel to [_kSparkleDotCount] above.
const List<double> _kSparklePhaseOffsets = <double>[0.0, 0.25, 0.50, 0.75];

/// Helix of brand colours for the breathing-sparkle row. Length must
/// stay ≤ [_kSparkleDotCount] to avoid a LengthError in the build loop.
const List<Color> _kSparklePalette = <Color>[
  AppColors.magicPink,
  AppColors.sunshineYellow,
  AppColors.skyCyan,
  AppColors.magicPurple,
];

/// Builds "Day N streak — keep the magic going!".
String _streakSubtitle(int streakDays) =>
    'Day $streakDays streak — keep the magic going!';

// =============================================================================
//  MascotSection — Home hero block.
// =============================================================================

class MascotSection extends StatelessWidget {
  const MascotSection({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final settings = context.watch<SettingsState>();
    final reduceMotion = settings.reduceMotion;
    final streakDays = player.streakDays;

    final subtitle =
        streakDays <= 0 ? _kSubtitleFreshStart : _streakSubtitle(streakDays);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MascotAvatar(
          mood: MascotMood.celebrate,
          breathing: !reduceMotion,
          size: _kAvatarDiameter,
          label: '$_kPlayerDisplayName\'s unicorn Mira',
        ),
        AppSpacing.vGapLg,
        Text(
          'Hi $_kPlayerDisplayName!',
          textAlign: TextAlign.center,
          style: AppTypography.titleLg,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyXl.copyWith(
            color: AppColors.smoke,
          ),
        ),
        AppSpacing.vGapMd,
        _SparkleOrnament(reduceMotion: reduceMotion),
      ],
    );
  }
}

// =============================================================================
//  _SparkleOrnament — small row of breathing dots.
// =============================================================================

class _SparkleOrnament extends StatefulWidget {
  const _SparkleOrnament({required this.reduceMotion});

  /// When true the controller is never started; every dot renders static
  /// to honour OS-level "Reduce Motion".
  final bool reduceMotion;

  @override
  State<_SparkleOrnament> createState() => _SparkleOrnamentState();
}

class _SparkleOrnamentState extends State<_SparkleOrnament>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.slow,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _SparkleOrnament oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion == widget.reduceMotion) {
      return;
    }
    if (widget.reduceMotion) {
      _controller.stop();
      _controller.value = 0.0;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var i = 0; i < _kSparkleDotCount; i++) {
      children.add(
        _SparkleDot(
          size: _kSparkleDotDiameter,
          color: _kSparklePalette[i % _kSparklePalette.length],
          phaseOffset: _kSparklePhaseOffsets[i],
          controller: widget.reduceMotion ? null : _controller,
          minScale: _kSparkleMinScale,
          maxScale: _kSparkleMaxScale,
          minAlpha: _kSparkleMinAlpha,
          maxAlpha: _kSparkleMaxAlpha,
        ),
      );
      if (i < _kSparkleDotCount - 1) {
        children.add(AppSpacing.hGapSm);
      }
    }

    return Semantics(
      label: 'Sparkle decoration',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// =============================================================================
//  _SparkleDot — single breathing dot.
// =============================================================================

class _SparkleDot extends StatelessWidget {
  const _SparkleDot({
    required this.size,
    required this.color,
    required this.phaseOffset,
    required this.controller,
    required this.minScale,
    required this.maxScale,
    required this.minAlpha,
    required this.maxAlpha,
  });

  final double size;
  final Color color;
  final double phaseOffset;

  /// When non-null the dot breathes on the shared controller; when null
  /// the dot renders structurally static (reduceMotion path).
  final AnimationController? controller;

  final double minScale;
  final double maxScale;
  final double minAlpha;
  final double maxAlpha;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (BuildContext context, _) {
        // Capture the field into a local final so we avoid any `!` bang
        // operator and the no-bang lint stays happy.
        final c = ctrl;
        final raw = c.value + phaseOffset;
        final t = (raw >= 1.0 ? raw - 1.0 : raw).clamp(0.0, 1.0);
        final eased = AppCurves.sparkle.transform(t);
        final scale = minScale + (maxScale - minScale) * eased;
        final alpha = minAlpha + (maxAlpha - minAlpha) * eased;
        return SizedBox(
          width: size,
          height: size,
          child: Opacity(
            opacity: alpha,
            child: Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
