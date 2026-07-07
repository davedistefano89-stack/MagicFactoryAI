import 'package:flutter/material.dart';

import '../../../core/theme/app_gradients.dart';

class AnimatedLogo extends StatelessWidget {
  const AnimatedLogo({super.key, required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        final double t = controller.value;
        final double scale = 0.6 + (Curves.easeOutBack.transform(t) * 0.6);
        final double opacity = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale.clamp(0.0, 1.2),
            child: ShaderMask(
              shaderCallback: (Rect rect) =>
                  AppGradients.rainbow.createShader(rect),
              child: const Text(
                'Magic Colors',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
