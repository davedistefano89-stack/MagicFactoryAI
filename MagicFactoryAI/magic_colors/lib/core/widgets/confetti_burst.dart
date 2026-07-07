// =============================================================================
// Magic Colors · core/widgets/confetti_burst.dart
// =============================================================================
//
// M2.4 — Stand-alone confetti ring widget extracted from the M2.2
// RewardPopUp. Used by both RewardPopUp (kept as-is) and the new
// DrawingCompleteOverlay. The painter is a public class so any
// consumer that wants foreground-only confetti can wire it directly
// via CustomPaint(painter: ConfettiBurstPainter(...)).
//
// Same mathematical model as the M2.2 in-line painter:
//   • N positions (default 18) at random angles around the centre,
//     distance band [80..140] dp.
//   • Each particle fades alpha 1→0 as the animation forward progresses.
//   • Particle radius shrinks from 10→6 as alpha decays.
//
// Honours [SettingsState.reduceMotion] when wired externally — if
// reduceMotion is true, simply don't mount the widget.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../theme/app_gradients.dart';

/// Immutable descriptor for a single confetti particle. Public so
/// consumers can read the spec layout (e.g. A/B positions for QA).
class ConfettiSpec {
  const ConfettiSpec({
    required this.angle,
    required this.distance,
    required this.color,
  });

  final double angle;
  final double distance;
  final Color color;
}

/// M2.4 — Reusable confetti burst. Fans N particles outward over
/// [duration]; calls [onDecayDone] when the animation completes.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.seed,
    this.count = 18,
    this.duration = AppDuration.confettiDecay,
    this.minDistance = 80.0,
    this.maxDistance = 140.0,
    this.onDecayDone,
  });

  /// Random seed. Stable re-mounts preserve positions.
  final int? seed;

  /// Total particle count.
  final int count;

  /// Total forward animation duration.
  final Duration duration;

  /// Closest a particle orbits the centre (dp).
  final double minDistance;

  /// Farthest a particle orbits the centre (dp).
  final double maxDistance;

  /// Optional completion callback (fires when forward animation reaches
  /// 1.0, NOT on dismiss).
  final VoidCallback? onDecayDone;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener(_onStatus)
        ..forward();
  late final List<ConfettiSpec> _specs = _generateSpecs();

  List<ConfettiSpec> _generateSpecs() {
    final math.Random rng = math.Random(widget.seed ?? 0xBADF00D);
    return List<ConfettiSpec>.generate(widget.count, (_) {
      final double angle = rng.nextDouble() * math.pi * 2.0;
      final double distance = widget.minDistance +
          rng.nextDouble() * (widget.maxDistance - widget.minDistance);
      final Color color = AppGradients
          .rainbowStops[rng.nextInt(AppGradients.rainbowStops.length)];
      return ConfettiSpec(angle: angle, distance: distance, color: color);
    });
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onDecayDone?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          painter: ConfettiBurstPainter(
            progress: _controller.value,
            specs: _specs,
          ),
        );
      },
    );
  }
}

/// M2.4 — Public painter used by [ConfettiBurst]. Reusable for any
/// CustomPaint host that wants the same ring layout.
class ConfettiBurstPainter extends CustomPainter {
  ConfettiBurstPainter({
    required this.progress,
    required this.specs,
  });

  final double progress;
  final List<ConfettiSpec> specs;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Offset centre = Offset(size.width / 2.0, size.height / 2.0);
    for (final ConfettiSpec s in specs) {
      final double r = s.distance * progress;
      final double dx = centre.dx + math.cos(s.angle) * r;
      final double dy = centre.dy + math.sin(s.angle) * r;
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = s.color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(dx, dy),
        6.0 + 4.0 * (1.0 - progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
