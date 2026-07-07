// SplashMascot — small avatar ringed with a rainbow gradient circle with
// a pulsing halo. Re-uses the shared `MascotWidget` from `core/widgets/`.

import 'package:flutter/material.dart';

import '../../../core/widgets/mascot.dart';

class SplashMascot extends StatefulWidget {
  const SplashMascot({super.key, required this.size, required this.pulse});

  final double size;
  final AnimationController pulse;

  @override
  State<SplashMascot> createState() => _SplashMascotState();
}

class _SplashMascotState extends State<SplashMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _halo;

  @override
  void initState() {
    super.initState();
    _halo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[widget.pulse, _halo]),
      builder: (BuildContext context, Widget? _) {
        return SizedBox(
          width: widget.size + 24,
          height: widget.size + 24,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: widget.size + 24,
                height: widget.size + 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFFFF6B6B),
                      Color(0xFFFFA94D),
                      Color(0xFFFFD93D),
                      Color(0xFF6BCB77),
                      Color(0xFF4D96FF),
                      Color(0xFFC780FA),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.55),
                      blurRadius: 12 + 14 * _halo.value,
                      spreadRadius: 2 + 4 * _halo.value,
                    ),
                  ],
                ),
              ),
              MascotWidget(size: widget.size),
            ],
          ),
        );
      },
    );
  }
}
