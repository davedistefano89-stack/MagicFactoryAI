// SparkleField — N sparkles twinkling randomly across the screen.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SparkleField extends StatefulWidget {
  const SparkleField({
    super.key,
    this.seed = 7,
    this.density = 36,
  });

  final int seed;
  final int density;

  @override
  State<SparkleField> createState() => _SparkleFieldState();
}

class _SparkleFieldState extends State<SparkleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    final math.Random rng = math.Random(widget.seed);
    _sparkles = List<_Sparkle>.generate(widget.density, (int i) {
      return _Sparkle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 1.4 + rng.nextDouble() * 2.6,
        phase: rng.nextDouble(),
        speed: 0.5 + rng.nextDouble() * 1.4,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext context, Widget? _) {
        return CustomPaint(
          painter: _SparklePainter(sparkles: _sparkles, t: _ctrl.value),
        );
      },
    );
  }
}

class _Sparkle {
  _Sparkle({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.speed,
  });
  final double x;
  final double y;
  final double radius;
  final double phase;
  final double speed;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.sparkles, required this.t});
  final List<_Sparkle> sparkles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (final _Sparkle s in sparkles) {
      final double phase = (s.phase + t * s.speed) % 1.0;
      final double opacity = 0.4 + 0.6 * math.sin(phase * math.pi * 2).abs();
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
      if (s.radius > 2.4 && opacity > 0.85) {
        final Offset c = Offset(s.x * size.width, s.y * size.height);
        final double length = s.radius * 4;
        final Paint line = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.7)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c + Offset(-length, 0), c + Offset(length, 0), line);
        canvas.drawLine(c + Offset(0, -length), c + Offset(0, length), line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}
