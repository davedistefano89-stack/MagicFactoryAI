// =============================================================================
// Magic Colors · features/coloring/widgets/coloring_toolbar.dart
// =============================================================================
//
// Top-of-bottom-dock action row: Undo · Redo · Clear. Wraps a Row of three
// `IconButton`s rendered over a subtle `AppCorner.brLg` card so the chrome
// always reads as a single surface.
//
// DISABLED STATES
// ---------------
//   • Undo  disabled when `controller.canUndo` is false (no strokes).
//   • Redo  disabled when `controller.canRedo` is false (empty redo stack).
//   • Clear disabled when `controller.canClear` is false (canvas empty).
//
//   All three icons use 60 % opacity + no shadow at 50 % — Material 3
//   idiomatic for "tap and nothing happens".
// =============================================================================

import 'package:flutter/material.dart';

import 'package:magic_colors/core/design/design_tokens.dart';
import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_shape.dart' as shape_lib;
import 'package:magic_colors/core/utils/haptics.dart';

import 'package:magic_colors/features/coloring/coloring_controller.dart';

// ── Tuning constants ─────────────────────────────────────────────────────

const double _kToolbarButtonSizeDp = 44.0;
const double _kToolbarIconSizeDp = 24.0;
const double _kToolbarCardPaddingDp = 8.0;

class ColoringToolbar extends StatelessWidget {
  const ColoringToolbar({
    super.key,
    required this.controller,
  });

  final ColoringController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final bool canUndo = controller.canUndo;
        final bool canRedo = controller.canRedo;
        final bool canClear = controller.canClear;

        return _ToolbarCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _ToolbarIconButton(
                icon: Icons.undo_rounded,
                label: 'Undo',
                enabled: canUndo,
                color: AppColors.magicPurple,
                onTap: () {
                  Haptics.selection();
                  controller.undo();
                },
              ),
              _ToolbarIconButton(
                icon: Icons.redo_rounded,
                label: 'Redo',
                enabled: canRedo,
                color: AppColors.magicPurple,
                onTap: () {
                  Haptics.selection();
                  controller.redo();
                },
              ),
              _ToolbarIconButton(
                icon: Icons.cleaning_services_rounded,
                label: 'Clear',
                enabled: canClear,
                color: AppColors.tangerine,
                onTap: () {
                  Haptics.warning();
                  _confirmClear(context, controller);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClear(BuildContext context, ColoringController controller) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear drawing?'),
          content: const Text(
              'All your strokes will be removed. You can\'t undo this.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep drawing'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.tangerine),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                controller.clearCanvas();
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }
}

class _ToolbarCard extends StatelessWidget {
  const _ToolbarCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cloudWhite.withValues(alpha: 0.95),
        borderRadius: shape_lib.AppCorner.brLg,
        boxShadow: shape_lib.AppElevation.softChip,
        border: Border.all(color: AppColors.hairlineLight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: _kToolbarCardPaddingDp,
        ),
        child: child,
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color resolved =
        enabled ? color : AppColors.smoke.withValues(alpha: 0.40);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        width: _kToolbarButtonSizeDp,
        height: _kToolbarButtonSizeDp,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, size: _kToolbarIconSizeDp, color: resolved),
          onPressed: enabled ? onTap : null,
        ),
      ),
    );
  }
}
