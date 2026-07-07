// =============================================================================
// Magic Colors · core/widgets/animated_background.dart
// =============================================================================
//
// The default animated sky underlay used by Home, Worlds, and the Coloring
// canvas's "draw your magic" backdrop. A static [AppGradients.skyDefault]
// gradient sits beneath a hypnotic layer of soft sparkles that drift up
// slowly across the screen. Honours [SettingsState.reduceMotion] so a
// parent-toggle for an over-stimulated kid can pause the loop without
// turning the screen black.
//
// Design contract (docs/design_system/02_COLOR_SYSTEM.md §7 + docs/design_system/08 §5):
//   ▸ Fill:     AppGradients.skyDefault (top→bottom, sky → lilac). NIGHT
//               variant swaps in [AppGradients.skyNight] when the
//               SettingsState.themeMode is `.dark`.
//   ▸ Sparkles: 12 soft circles, opacities 0.4–0.8, sizes 12–28 px.
//                They float up over AppDuration.rainbowShimmer on a
//                staggered offset so the field never reads as a rigid grid.
//   ▸ Pulse:    Each sparkle scales 1.0 ↔ 0.4 on AppCurves.sparkle over
//               AppDuration.medium — independent per sparkle.
//   ▸ Reduced:  AppSpacing 4 px ink-tinted overlay replaces the sparkle
//               field when reduceMotion is true.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import '../state/settings_state.dart';
import '../theme/app_gradients.dart';

// =============================================================================
//  AnimatedBackground — sky-tinted gradient + looping sparkle field.
// =============================================================================

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({
    super.key,
    required this.child,
    this.gradient,
    this.sparkleCount = 12,
    this.seed,
  });

  /// Foreground content laid over the gradient.
  final Widget child;

  /// Gradient override. When `null`, picks [AppGradients.skyDefault] for
  /// light mode and [AppGradients.skyNight] for dark mode.
  final LinearGradient? gradient;

  /// How many drifting sparkles to overlay. Default 12 (designer-tuned).
  final int sparkleCount;

  /// Optional seed so the random sparkle positions are stable across
  /// hot-reloads. Defaults to a constant used by the splash + home.
  final int? seed;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: AppDuration.rainbowShimmer,
  );

  late final List<_SparkleSpec> _sparkles;
  late final math.Random _rng;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(widget.seed ?? 0xCAFEBABE);
    _sparkles = List<_SparkleSpec>.generate(widget.sparkleCount, (_) {
      final size = 12.0 + _rng.nextDouble() * 16.0;
      final opacity = 0.40 + _rng.nextDouble() * 0.40;
      final leftFraction = _rng.nextDouble();
      final phase = _rng.nextDouble();
      final delayMs = _rng.nextInt(2000);
      return _SparkleSpec(
        size: size,
        opacity: opacity,
        leftFraction: leftFraction,
        phase: phase,
        delay: Duration(milliseconds: delayMs),
      );
    });
  }

  // M2.4 hotfix \u2014 mirror of OutlinePulse: defer the field-initializer
  // `..repeat()` to here so the AnimationController honours
  // [SettingsState.reduceMotion]. Without this gate the ticker runs
  // forever even when the visual sparkle field is suppressed in
  // [build], and widget tests on the Home / Coloring surfaces hang
  // at the 30 s fake-async hard timeout. Reading the provider here is
  // safe \u2014 Flutter guarantees `didChangeDependencies` runs once
  // immediately after `initState` and again whenever SettingsState
  // pushes a new value, so live-toggle of reduce motion from the
  // Parents Area pauses / resumes the drift without an app restart.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = context.watch<SettingsState>().reduceMotion;
    if (reduceMotion) {
      if (_drift.isAnimating) {
        _drift.stop();
      }
    } else {
      if (!_drift.isAnimating) {
        _drift.repeat();
      }
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final reduceMotion = settings.reduceMotion;
    final isDark = settings.themeMode == ThemeMode.dark;
    final gradient = widget.gradient ??
        (isDark ? AppGradients.skyNight : AppGradients.skyDefault);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: const SizedBox.expand(),
        ),
        if (!reduceMotion)
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              return CustomPaint(
                painter: _SparkleFieldPainter(
                  progress: _drift.value,
                  sparkles: _sparkles,
                ),
                size: Size.infinite,
              );
            },
          ),
        widget.child,
      ],
    );
  }
}

// =============================================================================
//  _SparkleSpec — pre-computed random coordinates for one sparkle.
// =============================================================================

class _SparkleSpec {
  const _SparkleSpec({
    required this.size,
    required this.opacity,
    required this.leftFraction,
    required this.phase,
    required this.delay,
  });

  final double size;
  final double opacity;
  final double leftFraction;
  final double phase;
  final Duration delay;
}

// =============================================================================
//  _SparkleFieldPainter — CustomPaint that draws the sparkle field.
// =============================================================================

class _SparkleFieldPainter extends CustomPainter {
  _SparkleFieldPainter({
    required this.progress,
    required this.sparkles,
  });

  final double progress;
  final List<_SparkleSpec> sparkles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in sparkles) {
      // Drift vertically across the full screen, looped.
      final phaseProgress =
          (progress + s.phase + (s.delay.inMilliseconds / 3000.0)) % 1.0;
      final dy = size.height * (1.0 - phaseProgress);
      final dx = size.width * s.leftFraction;

      // Opacity ramps in from 0 → s.opacity on the first 20 % then steady.
      final ramp = phaseProgress < 0.20 ? (phaseProgress / 0.20) : 1.0;
      final op = s.opacity * ramp;

      // Pulse on AppDurations.medium (scaled to the global drift length).
      final pulse = 0.4 +
          0.6 *
              (0.5 +
                  0.5 *
                      math.sin(
                          phaseProgress * math.pi * 2.0 + s.phase * math.pi));

      paint.color = const Color(0xFFFFFFFF).withValues(alpha: op * pulse);
      canvas.drawCircle(Offset(dx, dy), s.size * pulse, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleFieldPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
