// =============================================================================
// Magic Colors · core/widgets/mascot_avatar.dart
// =============================================================================
//
// The mascot glance — Sophia's unicorn sidekick "Mira" by default. A
// circular face that breathes in/out (slow scale 0.96 ↔ 1.04) and lets
// mood-driven backdrops communicate which mode the mascot is in.
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §12):
//   ▸ Shape:     Circle, AppGradients.avatarRing 4 dp border.
//   ▸ Fill:      Mood-driven gradient (see `_resolveFill`).
//   ▸ Breathing: scale 0.96 ↔ 1.04 on AppDuration.mascotBreath (1600 ms)
//                with AppCurves.mascotBreath (easeInOut).
//   ▸ Glyph:     🦄 emoji — single-tone and matches the unicode stance in
//                the brief.
//   ▸ Interaction: when [onTap] is set the avatar pulses on tap + emits a
//                  medium haptic.
// =============================================================================

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shape.dart';
import '../utils/haptics.dart';

/// Mood preset for [MascotAvatar].
enum MascotMood {
  /// Default resting — pastel sky-blue interior.
  happy,

  /// Lower-saturation mint — used after a long play session.
  sleepy,

  /// Pink/coral interior with extra-strong bounce click feedback.
  excited,

  /// Rainbow gradient — used during the "welcome back" reward popup.
  celebrate,
}

// =============================================================================
//  MascotAvatar — breathing circular mascot glance.
// =============================================================================

class MascotAvatar extends StatefulWidget {
  const MascotAvatar({
    super.key,
    this.size = 96.0,
    this.mood = MascotMood.happy,
    this.breathing = true,
    this.onTap,
    this.label = 'Mira the unicorn',
  });

  /// Diameter in dp. Defaults to 96 dp (used by the Home greeting card).
  final double size;

  /// Mood preset. Drives the interior fill + optional bounce on tap.
  final MascotMood mood;

  /// When true (default), the avatar breathes on AppDuration.mascotBreath
  /// with AppCurves.mascotBreath.
  final bool breathing;

  /// Tap handler. When non-null, the avatar emits a medium haptic + bounces.
  final VoidCallback? onTap;

  /// Semantic label for screen readers. Default "Mira the unicorn".
  final String label;

  @override
  State<MascotAvatar> createState() => _MascotAvatarState();
}

class _MascotAvatarState extends State<MascotAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: AppDuration.mascotBreath,
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant MascotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breathing != widget.breathing) {
      if (widget.breathing) {
        _breath.repeat(reverse: true);
      } else {
        _breath.stop();
        _breath.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) {
      return;
    }
    Haptics.medium();
    widget.onTap?.call();
  }

  LinearGradient _resolveFill() {
    switch (widget.mood) {
      case MascotMood.happy:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.skyTop,
            AppColors.cloudWhite,
          ],
          stops: <double>[0.0, 1.0],
        );
      case MascotMood.sleepy:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.mintLeaf.withValues(alpha: 0.40),
            AppColors.lavender.withValues(alpha: 0.50),
          ],
          stops: const <double>[0.0, 1.0],
        );
      case MascotMood.excited:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.bubblegum,
            AppColors.tangerine,
          ],
          stops: <double>[0.0, 1.0],
        );
      case MascotMood.celebrate:
        return AppGradients.rainbowTilted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final fill = _resolveFill();
    const scaleCurve = AppCurves.mascotBreath;

    return Semantics(
      label: widget.label,
      button: widget.onTap != null,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final z = widget.breathing ? _breath.value : 0.0;
          final scale = 0.96 + (0.08 * scaleCurve.transform(z));
          return Transform.scale(scale: scale, child: child);
        },
        child: GestureDetector(
          onTap: widget.onTap == null ? null : _handleTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: fill,
              border: Border.all(
                color: AppColors.cloudWhite,
                width: 4.0,
              ),
              boxShadow: AppElevation.softChip,
            ),
            alignment: Alignment.center,
            child: const Text('🦄', style: TextStyle(fontSize: 56.0)),
          ),
        ),
      ),
    );
  }
}
