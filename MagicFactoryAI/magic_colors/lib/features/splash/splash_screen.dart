// SplashScreen — animated rainbow gradient + sparkle field + breathing
// mascot + animated logo → smooth fade to Home.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import 'widgets/animated_logo.dart';
import 'widgets/sparkle_field.dart';
import 'widgets/splash_mascot.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _gradientController;
  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        // Transition from the process root INTO the bottom-nav shell
        // for the first time. The StatefulNavigationShell does NOT
        // exist yet — `_BranchScaffold` only mounts when GoRouter
        // resolves the StatefulShellRoute, which this very `go(...)`
        // call is what triggers. So neither `selectShellTab` nor
        // `goShellTab` would resolve here (both would throw
        // `ProviderNotFoundException`). The bare `context.go(
        // AppRoutes.home)` is the canonical boot path: GoRouter
        // constructs the shell on the way in.
        // ignore: shell_branch_nav (out-of-shell bootstrap — the
        // shell doesn't yet exist on cold start; this call is what
        // CAUSES it to mount, so the shell pipeline is unreachable).
        context.go(AppRoutes.home);
      });
    });
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gradientController,
              builder: (BuildContext context, Widget? _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -1 + _gradientController.value * 2,
                        -1,
                      ),
                      end: Alignment(
                        1 - _gradientController.value * 2,
                        1,
                      ),
                      colors: brightness == Brightness.dark
                          ? const <Color>[
                              AppColors.skyTopNight,
                              AppColors.skyMidNight,
                              AppColors.skyBottomNight,
                            ]
                          : AppGradients.rainbowStops,
                    ),
                  ),
                );
              },
            ),
          ),
          const Positioned.fill(
            child: SparkleField(seed: 42),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SplashMascot(
                  size: 140,
                  pulse: _logoController,
                ),
                const SizedBox(height: 24),
                AnimatedLogo(controller: _logoController),
                const SizedBox(height: 12),
                _buildTagline(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (BuildContext context, Widget? _) {
        final double t = _logoController.value;
        final double opacity = t < 0.6 ? 0 : ((t - 0.6) / 0.4).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Text(
            'Tap · Color · Smile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 2.4 + 2 * math.sin(t * math.pi * 2),
            ),
          ),
        );
      },
    );
  }
}
