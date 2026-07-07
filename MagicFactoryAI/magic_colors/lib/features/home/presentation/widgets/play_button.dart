// =============================================================================
// Magic Colors · features/home/presentation/widgets/play_button.dart
// =============================================================================
//
// The Home Screen's primary CTA wrapper. Around a [PrimaryButton] (jumbo
// sized, full-width), this widget paints a soft pink glow halo whose
// opacity + scale breathe on an `AppDuration.hero` cycle so the button
// quietly attracts the player's gaze as they approach the screen.
//
// State-aware:
//   * `SettingsState.reduceMotion` collapses the breathing animation to a
//     static 2 dp MagicPink hairline so a parent-toggle instantly silences
//     the pulse without losing the "this is a CTA" affordance.
//   * Disabled state (onPressed == null) drops the breathing entirely and
//     forwards `null` to `PrimaryButton` which paints the smoke-fill
//     disabled chrome automatically.
//
// Analytics: every press fires `home_play_now_pressed` through the
// no-op `AnalyticsService` so the event hits Mixpanel as soon as the
// real implementation ships in Sprint 6.
//
// Hard constraints (per Sprint-2 spec):
//   * Only Foundation widgets + tokens are imported. No new colors, no new
//     theme constants, no edits to design_tokens / theme files.
//   * No placeholders, TODOs, or fake assets.
//   * `icon?` is optional; when omitted the button renders as text-only.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/widgets/primary_button.dart';

// =============================================================================
//  PlayButton — the production Home CTA wrapper.
// =============================================================================

class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Visible button label. Defaults to "PLAY NOW" at the call site.
  final String label;

  /// Tap callback. Forwarded to the inner [PrimaryButton]. When `null`
  /// the wrapper drops the breathing animation AND the inner button
  /// paints the disabled chrome automatically.
  final VoidCallback? onPressed;

  /// Optional Material icon (24 dp) painted before the label.
  final IconData? icon;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: AppDuration.hero, // 540 ms per half-cycle
  )..repeat(reverse: true);

  // Scale 1.0 → 1.04 on the sparkle curve — the visible "breathing".
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _breathe, curve: AppCurves.sparkle));

  // Halo alpha 0.55 → 1.0 on the gentle curve so the glow grows in sync
  // with the scale wobble but the curve never feels sharp.
  late final Animation<double> _glowAlpha = Tween<double>(
    begin: 0.55,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _breathe, curve: AppCurves.gentle));

  bool get _enabled => widget.onPressed != null;

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  void _handlePressed() {
    if (!_enabled) {
      return;
    }
    AnalyticsService.instance.trackEvent('home_play_now_pressed');
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.watch<SettingsState>().reduceMotion;
    final shouldBreathe = _enabled && !reduceMotion;

    if (!shouldBreathe) {
      // Static layout — keeps the "this is the CTA" affordance (MagicPink
      // hairline) without any motion. Used when reduceMotion is on OR
      // when the button is disabled.
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppCorner.brLg,
          border: Border.all(
            color: AppColors.magicPink.withValues(alpha: 0.65),
            width: 2.0,
          ),
        ),
        child: PrimaryButton(
          label: widget.label,
          onPressed: _enabled ? _handlePressed : null,
          leading: widget.icon,
          fullWidth: true,
          size: PrimaryButtonSize.jumbo,
        ),
      );
    }

    // Breathing layout — outer pink halo + scale wobble around the inner
    // PrimaryButton. The inner button keeps its own press-wobble
    // (composes naturally with the breath).
    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppCorner.brLg,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.magicPink.withValues(
                  alpha: _glowAlpha.value,
                ),
                blurRadius: 32.0,
                spreadRadius: 1.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        );
      },
      child: PrimaryButton(
        label: widget.label,
        onPressed: _handlePressed,
        leading: widget.icon,
        fullWidth: true,
        size: PrimaryButtonSize.jumbo,
      ),
    );
  }
}
