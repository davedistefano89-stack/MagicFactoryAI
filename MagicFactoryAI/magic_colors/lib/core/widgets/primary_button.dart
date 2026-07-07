// =============================================================================
// Magic Colors · core/widgets/primary_button.dart
// =============================================================================
//
// The workhorse CTA. PLAY NOW, "Drawing start", "Confirm reward" — every
// full-importance action is a [PrimaryButton].
//
// Design contract (mirrors docs/design_system/04_UI_COMPONENTS.md §3):
//   ▸ Background: AppGradients.playNow (pink → purple diagonal).
//   ▸ Text:       AppTypography.bigButton / buttonMd / buttonSm (size-driven).
//   ▸ Padding:    AppSpacing.lg vertical × AppSpacing.xl horizontal edges
//                 (jumbo), 16/24 (medium), 8/16 (small).
//   ▸ Corners:    AppCorner.brLg (jumbo + medium) / AppCorner.brMd (small).
//   ▸ Elevation:  AppElevation.glowPink when at rest, AppElevation.z2 when
//                 pressed (computed via AnimatedContainer).
//   ▸ Disabled:   AppColors.smoke × 30 % fill, smoke text, no glow.
//
// State-aware behaviour:
//   • Tap feedback uses an AnimationController on AppCurves.buttonBounce
//     for a 1.0 → 0.96 → 1.0 scale wobble wired to InkResponse.
//   • Light haptic on tap (`Haptics.light()`) when onPressed is non-null.
//
// Three sizes:
//   • PrimaryButtonSize.jumbo   — Play-NOW scale.
//   • PrimaryButtonSize.medium  — default modal-confirm style.
//   • PrimaryButtonSize.small   — compact inline-confirm.
// =============================================================================

import 'package:flutter/material.dart';

import '../design/design_tokens.dart' show AppSpacing, AppDuration, AppCurves;
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_shape.dart';
import '../theme/app_typography.dart';
import '../utils/haptics.dart';

/// Sizing option for a [PrimaryButton].
enum PrimaryButtonSize {
  /// Full-screen PLAY NOW. Tight 540 ms hero transitions. bigButton type.
  jumbo,

  /// Modal confirm / Rewards confirm. 22 pt buttonMd type. Default size.
  medium,

  /// Inline confirm chip. buttonSm type. 36 dp height.
  small,
}

// =============================================================================
//  PrimaryButton — gradient-filled CTA.
// =============================================================================

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.fullWidth = false,
    this.size = PrimaryButtonSize.medium,
    this.gradient,
  });

  /// Visible button label. Required.
  final String label;

  /// Tap callback. `null` paints the disabled variant.
  final VoidCallback? onPressed;

  /// Optional leading icon drawn before the label inside a 24 dp box.
  final IconData? leading;

  /// When true, the button fills the parent's width contract.
  final bool fullWidth;

  /// Size variant. See [PrimaryButtonSize].
  final PrimaryButtonSize size;

  /// Gradient override. Defaults to [AppGradients.playNow] (pink → purple).
  final LinearGradient? gradient;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: AppDuration.fast,
    reverseDuration: AppDuration.fast,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(parent: _press, curve: AppCurves.buttonBounce));

  bool get _enabled => widget.onPressed != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!_enabled) {
      return;
    }
    Haptics.light();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final enabled = _enabled;
    final height = switch (size) {
      PrimaryButtonSize.jumbo => 72.0,
      PrimaryButtonSize.medium => 56.0,
      PrimaryButtonSize.small => 40.0,
    };
    final edgeInsets = switch (size) {
      PrimaryButtonSize.jumbo => const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.md,
        ),
      PrimaryButtonSize.medium => const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
      PrimaryButtonSize.small => const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
    };
    final textStyle = switch (size) {
      PrimaryButtonSize.jumbo => AppTypography.bigButton(),
      PrimaryButtonSize.medium => AppTypography.buttonMd,
      PrimaryButtonSize.small => AppTypography.buttonSm,
    };
    final borderRadius =
        (size == PrimaryButtonSize.small) ? AppCorner.brMd : AppCorner.brLg;
    final fill = enabled ? (widget.gradient ?? AppGradients.playNow) : null;
    final fillColor = enabled ? null : AppColors.smoke.withValues(alpha: 0.30);
    final labelColor = enabled ? AppColors.cloudWhite : AppColors.smoke;

    final body = AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.buttonBounce,
      height: height,
      width: widget.fullWidth ? double.infinity : null,
      padding: edgeInsets,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: fill,
        color: fillColor,
        borderRadius: borderRadius,
        boxShadow: enabled ? AppElevation.glowPink : const <BoxShadow>[],
      ),
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (widget.leading != null) ...<Widget>[
            Icon(widget.leading, size: 24.0, color: labelColor),
            AppSpacing.hGapSm,
          ],
          Flexible(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: textStyle.copyWith(color: labelColor),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTapDown: enabled ? (_) => _press.forward() : null,
          onTapCancel: enabled ? () => _press.reverse() : null,
          onTapUp: enabled ? (_) => _press.reverse() : null,
          onTap: enabled ? _handleTap : null,
          child: body,
        ),
      ),
    );
  }
}
