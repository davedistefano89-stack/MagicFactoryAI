// =============================================================================
// Magic Colors · core/widgets/secondary_button.dart
// =============================================================================
//
// The secondary CTA. "Maybe later", "Show me another", Parents Area
// actions — every less-important action is a [SecondaryButton].
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §4):
//   ▸ Background: AppColors.cloudWhite (light) / AppColors.skyBottomNight
//                 (dark) — i.e. transparent over the parent surface.
//   ▸ Border:     2 dp AppColors.tangerine (light) / AppColors.sunshineYellow
//                 (dark).
//   ▸ Text:       AppTypography.buttonMd in AppColors.deepInk / AppColors.moonbeam.
//   ▸ Corners:    AppCorner.brMd.
//   ▸ Padding:    AppSpacing.md × AppSpacing.lg.
//   ▸ Elevation:  AppElevation.softChip at rest, none when pressed.
//   ▸ Disabled:   smoke hairline border, ink-on-paper disabled text.
//
// Tap feedback is the same scale wobble as [PrimaryButton] but with
// [Haptics.selection()] (lighter).
// =============================================================================

import 'package:flutter/material.dart';

import '../design/design_tokens.dart' show AppSpacing, AppDuration, AppCurves;
import '../theme/app_colors.dart';
import '../theme/app_shape.dart';
import '../theme/app_typography.dart';
import '../utils/haptics.dart';

// =============================================================================
//  SecondaryButton — outlined secondary CTA.
// =============================================================================

class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.fullWidth = false,
  });

  /// Visible label. Required.
  final String label;

  /// Tap callback. `null` paints the disabled variant.
  final VoidCallback? onPressed;

  /// Optional leading icon (24 dp, sits in a 8 dp right gutter).
  final IconData? leading;

  /// When true, the button fills the parent's width contract.
  final bool fullWidth;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: AppDuration.fast,
    reverseDuration: AppDuration.fast,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 0.97,
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
    Haptics.selection();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = enabled
        ? (isDark ? AppColors.sunshineYellow : AppColors.tangerine)
        : AppColors.smoke.withValues(alpha: 0.40);
    final labelColor = enabled
        ? (isDark ? AppColors.moonbeam : AppColors.deepInk)
        : AppColors.smoke;
    final fillColor =
        enabled ? Colors.transparent : AppColors.smoke.withValues(alpha: 0.10);

    final body = AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.buttonBounce,
      height: 48.0,
      width: widget.fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: AppCorner.brMd,
        border: Border.all(color: borderColor, width: 2.0),
        boxShadow: enabled ? AppElevation.softChip : const <BoxShadow>[],
      ),
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (widget.leading != null) ...<Widget>[
            Icon(widget.leading, size: 20.0, color: labelColor),
            AppSpacing.hGapSm,
          ],
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: AppTypography.buttonMd.copyWith(color: labelColor),
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
