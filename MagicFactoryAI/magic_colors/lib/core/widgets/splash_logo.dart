// =============================================================================
// Magic Colors · core/widgets/splash_logo.dart
// =============================================================================
//
// The splash-screen brand mark. Presented for AppDuration.splashHold
// (2400 ms) before the App shell swaps to Home. Renders the
// "Magic Colors" wordmark at displayXxl scale inside a rainbow-gradient
// disk that slowly inflates from 0.6 → 1.0 on mount.
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §13):
//   ▸ Wordmark:  AppTypography.displayXxl (56 / 800 Baloo 2) drawn on
//                top of an AppGradients.rainbow fill.
//   ▸ Disk:      Circular colour-stop boundary that reads as a "Token of
//                Magic" — the brand mark sits inside a 4 dp CloudWhite ring.
//   ▸ Animation: Fade-in 0 → 1 + scale 0.6 → 1.0 over AppDuration.hero
//                (540 ms) on mount. After that, the rainbow sweeps on a
//                3 s AppDuration.rainbowShimmer loop until told to stop.
//   ▸ Reduce:    When SettingsState.reduceMotion is true, the disk and
//                wordmark paint statically with no scale + no shimmer.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart' show AppDuration, AppCurves;
import '../state/settings_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shape.dart' as shape_lib;
import '../theme/app_typography.dart';

// =============================================================================
//  SplashLogo — fade-in rainbow sheen wordmark.
// =============================================================================

class SplashLogo extends StatefulWidget {
  const SplashLogo({
    super.key,
    this.size = 1.0,
    this.label = 'Magic Colors',
    this.duration,
  });

  /// Scale factor. Defaults to 1.0 (fits the standard 360 × 800 design
  /// canvas). Pass 0.8 for "compact" splash layouts (debug builds).
  final double size;

  /// The wordmark text. Defaults to the canonical brand string.
  final String label;

  /// Override for the entry duration. Defaults to [AppDuration.hero]
  /// (540 ms).
  final Duration? duration;

  @override
  State<SplashLogo> createState() => _SplashLogoState();
}

class _SplashLogoState extends State<SplashLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: widget.duration ?? AppDuration.hero,
  );
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: AppDuration.rainbowShimmer,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entry,
    curve: AppCurves.enter,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.6,
    end: widget.size,
  ).animate(CurvedAnimation(parent: _entry, curve: AppCurves.rewardExplosion));

  @override
  void initState() {
    super.initState();
    _entry.forward().whenComplete(() {
      if (mounted) {
        _shimmer.repeat();
      }
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  String _displayLabel(BuildContext context) {
    final reduceMotion = context.watch<SettingsState>().reduceMotion;
    if (reduceMotion) {
      // The user opted out of motion — kill the running shimmer in case it
      // was started before the toggle flipped.
      _shimmer.stop();
      _shimmer.value = 0.0;
    }
    return widget.label;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<SettingsState>().reduceMotion;
    final label = _displayLabel(context);

    return Semantics(
      label: '$label · loading',
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_entry, _shimmer]),
        builder: (context, child) {
          return Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
        child: _SplashDisk(
          label: label,
          shimmerProgress: reduceMotion ? 0.0 : _shimmer.value,
        ),
      ),
    );
  }
}

// =============================================================================
//  _SplashDisk — rainbow disk + wordmark inside a CloudWhite ring.
// =============================================================================

class _SplashDisk extends StatelessWidget {
  const _SplashDisk({
    required this.label,
    required this.shimmerProgress,
  });

  final String label;
  final double shimmerProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280.0,
      height: 280.0,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.rainbowTilted,
        border: Border.all(color: AppColors.cloudWhite, width: 4.0),
        boxShadow: shape_lib.AppElevation.glowPurple,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Shimmer overlay — translates the gradient horizontally.
          ClipOval(
            child: SizedBox(
              width: 280.0,
              height: 280.0,
              child: Transform.translate(
                offset: Offset(shimmerProgress * 280.0 - 140.0, 0.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppGradients.rainbowStops,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.displayXxl.copyWith(
              color: AppColors.cloudWhite,
            ),
          ),
        ],
      ),
    );
  }
}
