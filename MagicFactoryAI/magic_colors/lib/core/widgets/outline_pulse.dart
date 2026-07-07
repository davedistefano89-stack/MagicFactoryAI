// =============================================================================
// Magic Colors · core/widgets/outline_pulse.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import '../state/settings_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_shape.dart';

class OutlinePulse extends StatefulWidget {
  const OutlinePulse({
    super.key,
    required this.child,
    this.color,
    this.thickness = 4.0,
    this.borderRadius,
    this.periodDuration,
  });

  final Widget child;
  final Color? color;
  final double thickness;
  final BorderRadius? borderRadius;
  final Duration? periodDuration;

  @override
  State<OutlinePulse> createState() => _OutlinePulseState();
}

class _OutlinePulseState extends State<OutlinePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _thicknessAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: widget.periodDuration ?? AppDuration.slow,
    );

    _thicknessAnim = Tween<double>(
      begin: widget.thickness,
      end: widget.thickness * 2,
    ).animate(
      CurvedAnimation(
        parent: _pulse,
        curve: AppCurves.gentle,
      ),
    );

    _opacityAnim = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(
      CurvedAnimation(
        parent: _pulse,
        curve: AppCurves.gentle,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start (or stop) the breathing ticker in lockstep with the global
    // `reduceMotion` preference. Reading SettingsState here is safe
    // — Flutter's widget lifecycle guarantees `didChangeDependencies`
    // is called once immediately after `initState` and again whenever
    // any InheritedWidget this widget depends on (Provider in our
    // case) pushes a new value. The unconditional `..repeat()` we
    // used to schedule in `initState` kept the ticker alive even when
    // `reduceMotion` was true, which left flutter_test waiting on a
    // never-settling controller at end-of-test. Moving the gate here
    // also unlocks a free UX bonus: live-toggling reduce motion from
    // the Parents Area now pauses/resumes the pulse without an app
    // restart.
    final bool reduceMotion = context.watch<SettingsState>().reduceMotion;
    if (reduceMotion) {
      if (_pulse.isAnimating) {
        _pulse.stop();
      }
    } else {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = context.watch<SettingsState>().reduceMotion;

    final Color color = widget.color ?? AppColors.magicPink;
    final BorderRadius radius = widget.borderRadius ?? AppCorner.brLg;

    if (reduceMotion) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: 0.65),
            width: 2,
          ),
          borderRadius: radius,
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: color.withValues(alpha: _opacityAnim.value),
              width: _thicknessAnim.value,
            ),
            borderRadius: radius,
          ),
          child: widget.child,
        );
      },
    );
  }
}
