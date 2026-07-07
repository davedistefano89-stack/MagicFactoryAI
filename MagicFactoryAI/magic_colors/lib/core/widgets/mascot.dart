// MascotWidget — official Magic Colors pink unicorn mascot.
//
// Custom-painted so the home screen ships zero raster art. Animates a
// subtle "breathing" scale and an occasional eye blink.
//
// Lives in `lib/core/widgets/` so Splash, Home, and future screens all
// share a single primary mascot asset without cross-feature imports.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MascotWidget extends StatefulWidget {
  const MascotWidget({super.key, this.size = 220, this.onLoaded});

  final double size;

  /// Called once after the first frame is painted.
  final VoidCallback? onLoaded;

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _blink;
  bool _firstFrameReported = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_firstFrameReported && widget.onLoaded != null) {
      _firstFrameReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoaded?.call();
      });
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_breath, _blink]),
        builder: (BuildContext context, Widget? _) {
          final double breath =
              1.0 + (math.sin(_breath.value * math.pi * 2) * 0.025);
          final double blinkPhase = _blink.value % 1.0;
          final double blink =
              blinkPhase < 0.04 ? (1 - (blinkPhase / 0.04) * 0.85) : 1.0;
          return Transform.scale(
            scale: breath,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _MascotPainter(blink: blink.clamp(0.15, 1.0)),
            ),
          );
        },
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.blink});
  final double blink;

  static const Color _bodyColor = Color(0xFFFFC8DD);
  static const Color _bodyShade = Color(0xFFEBA1C2);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = math.min(size.width, size.height) / 2 - 4;

    final Paint body = Paint()..color = _bodyColor;
    final Paint shade = Paint()..color = _bodyShade;

    final Paint halo = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.4),
      );
    canvas.drawCircle(Offset(cx, cy), r * 1.4, halo);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.05),
        width: r * 1.85,
        height: r * 1.78,
      ),
      body,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.55),
        width: r * 1.4,
        height: r * 0.55,
      ),
      shade,
    );

    _drawEar(canvas, Offset(cx - r * 0.6, cy - r * 0.7), -0.6, body);
    _drawEar(canvas, Offset(cx + r * 0.6, cy - r * 0.7), 0.6, body);

    _drawMane(canvas, cx, cy, r);
    _drawHorn(canvas, cx, cy - r * 0.7, r * 0.45);

    _drawEye(canvas, Offset(cx - r * 0.4, cy - r * 0.05), r * 0.27);
    _drawEye(canvas, Offset(cx + r * 0.4, cy - r * 0.05), r * 0.27);

    final Paint cheek = Paint()..color = const Color(0xFFFF8CB3);
    canvas.drawCircle(Offset(cx - r * 0.55, cy + r * 0.35), r * 0.13, cheek);
    canvas.drawCircle(Offset(cx + r * 0.55, cy + r * 0.35), r * 0.13, cheek);

    _drawSmile(canvas, cx, cy + r * 0.32, r * 0.55);
    _drawPaintbrush(canvas, Offset(cx + r * 0.45, cy + r * 0.55));
  }

  void _drawEar(Canvas c, Offset root, double tilt, Paint p) {
    final Path path = Path()
      ..moveTo(root.dx, root.dy)
      ..quadraticBezierTo(
        root.dx + 16 * tilt,
        root.dy - 30,
        root.dx + 4 * tilt,
        root.dy - 46,
      )
      ..quadraticBezierTo(
        root.dx - 8 * tilt,
        root.dy - 30,
        root.dx,
        root.dy,
      )
      ..close();
    c.drawPath(path, p);
  }

  void _drawMane(Canvas c, double cx, double cy, double r) {
    const List<Color> maneColors = <Color>[
      AppColors.rainbowRed,
      AppColors.rainbowOrange,
      AppColors.rainbowYellow,
      AppColors.rainbowGreen,
      AppColors.rainbowBlue,
      AppColors.rainbowPurple,
    ];

    for (int i = 0; i < 6; i++) {
      final Color color = maneColors[i % maneColors.length];
      final double startAngle = -math.pi * 0.85 + i * 0.10;
      final Path path = Path()
        ..moveTo(
          cx + math.cos(startAngle) * r * 0.85,
          cy + math.sin(startAngle) * r * 0.85,
        );
      for (double t = 0; t <= 1; t += 0.05) {
        final double angle = startAngle + t * 0.6;
        final double radius = r * (0.9 - t * 0.25);
        final double wobble = math.sin(t * math.pi * 3) * 6;
        final double dx = cx + math.cos(angle) * radius + wobble - r * 0.18;
        final double dy = cy + math.sin(angle) * radius;
        path.lineTo(dx, dy);
      }
      c.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = r * 0.18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawHorn(Canvas c, double cx, double topY, double hornLength) {
    final Rect hornRect = Rect.fromCenter(
      center: Offset(cx, topY + hornLength / 2),
      width: hornLength * 0.5,
      height: hornLength,
    );

    final Shader shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        AppColors.rainbowPurple,
        AppColors.rainbowBlue,
        AppColors.rainbowGreen,
        AppColors.rainbowYellow,
        AppColors.rainbowOrange,
        AppColors.rainbowRed,
      ],
    ).createShader(hornRect);

    c.drawPath(
      Path()
        ..moveTo(cx - hornLength * 0.18, topY + hornLength)
        ..lineTo(cx, topY)
        ..lineTo(cx + hornLength * 0.18, topY + hornLength)
        ..close(),
      Paint()..shader = shader,
    );

    final Paint sparkle = Paint()..color = AppColors.accentYellow;
    c.drawCircle(Offset(cx + hornLength * 0.45, topY - 4), 3, sparkle);
  }

  void _drawEye(Canvas c, Offset center, double radius) {
    final Paint eyeWhite = Paint()..color = Colors.white;
    c.drawCircle(center, radius, eyeWhite);

    final Paint pupil = Paint()..color = AppColors.textDark;
    c.drawCircle(
      center.translate(0, radius * 0.05),
      radius * 0.55 * blink,
      pupil,
    );

    final Paint highlight = Paint()..color = Colors.white;
    c.drawCircle(
      center.translate(-radius * 0.15, -radius * 0.15),
      radius * 0.18,
      highlight,
    );

    if (blink < 1.0) {
      final Paint mask = Paint()..color = _bodyColor;
      c.drawRect(
        Rect.fromCenter(
          center: center.translate(0, radius * 0.55),
          width: radius * 2,
          height: radius * 2,
        ),
        mask,
      );
    }
  }

  void _drawSmile(Canvas c, double cx, double cy, double width) {
    final Path mouth = Path()
      ..moveTo(cx - width * 0.35, cy)
      ..quadraticBezierTo(cx, cy + width * 0.25, cx + width * 0.35, cy);
    c.drawPath(
      mouth,
      Paint()
        ..color = AppColors.textDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.08
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawPaintbrush(Canvas c, Offset root) {
    final Paint handle = Paint()
      ..color = const Color(0xFFB7795B)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    c.drawLine(root, root.translate(34, -34), handle);

    final Paint ferrule = Paint()
      ..color = const Color(0xFFE0C28A)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    c.drawLine(
      root.translate(34, -34),
      root.translate(46, -46),
      ferrule,
    );

    final Rect bristleRect = Rect.fromCenter(
      center: root.translate(56, -56),
      width: 22,
      height: 22,
    );
    c.drawOval(
      bristleRect,
      Paint()
        ..shader = const SweepGradient(colors: <Color>[
          AppColors.rainbowRed,
          AppColors.rainbowOrange,
          AppColors.rainbowYellow,
          AppColors.rainbowGreen,
          AppColors.rainbowBlue,
          AppColors.rainbowPurple,
          AppColors.rainbowRed,
        ]).createShader(bristleRect),
    );

    final Paint spark = Paint()..color = AppColors.gemPink;
    c.drawCircle(root.translate(-6, -6), 4, spark);
    c.drawCircle(root.translate(64, -64), 5, spark);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) => old.blink != blink;
}
