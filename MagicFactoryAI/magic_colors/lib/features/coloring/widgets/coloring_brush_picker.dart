// =============================================================================
// Magic Colors · features/coloring/widgets/coloring_brush_picker.dart
// =============================================================================
//
// Two-column picker rendered above the swatch grid:
//   • Left chip-strip: 5 brush kinds (round, marker, crayon, sparkle,
//     eraser) as Material 3 ChoiceChips.
//   • Right size slider: 4..64 dp range with a live-round preview dot.
//
// Both halves push state through [ColoringController] methods. The
// selected chip and preview repaint on every `controller` notify.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:magic_colors/core/design/design_tokens.dart';
import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_shape.dart' as shape_lib;
import 'package:magic_colors/core/theme/app_typography.dart';
import 'package:magic_colors/core/utils/haptics.dart';
// M2.4 — InkSparkle splash factory is exposed through
// package:flutter/material.dart as a static getter.

import 'package:magic_colors/features/coloring/coloring_controller.dart';
import 'package:magic_colors/features/coloring/domain/enums.dart';

/// Brush-type labels. Mirrors [BrushType] in declaration order.
/// M2.2 appends `BrushType.fill` (6 entries). M2.3 appends `pencil`
/// (7 entries total).
const List<String> _kBrushLabels = <String>[
  'Round',
  'Marker',
  'Crayon',
  'Sparkle',
  'Eraser',
  'Fill',
  'Pencil',
];

class ColoringBrushPicker extends StatelessWidget {
  const ColoringBrushPicker({
    super.key,
    required this.controller,
  });

  final ColoringController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _BrushTypeRow(
              selectedIndex: controller.brushTypeIndex,
              onSelect: (int i) {
                Haptics.selection();
                controller.setBrushType(BrushType.values[i]);
              },
            ),
            AppSpacing.vGapSm,
            _BrushSizeRow(
              sizeDp: controller.brushSize,
              color: controller.selectedColor,
              onChanged: controller.setBrushSize,
            ),
          ],
        );
      },
    );
  }
}

class _BrushTypeRow extends StatelessWidget {
  const _BrushTypeRow({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Wrap chips in a Wrap so a future brush kind just drops into the
    // list without a scroll mechanic; saves 1 ListView.builder pass on
    // each repaint.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (int i = 0; i < _kBrushLabels.length; i++)
          ChoiceChip(
            selected: i == selectedIndex,
            label: Text(_kBrushLabels[i]),
            labelStyle: AppTypography.labelMd.copyWith(
              color:
                  i == selectedIndex ? AppColors.cloudWhite : AppColors.deepInk,
            ),
            selectedColor: AppColors.magicPurple,
            backgroundColor: AppColors.cloudWhite,
            // M2.4 — unified splash tint is handled at the theme
            // level (see AppTheme.elevatedButtonTheme / chipTheme).
            // ChoiceChip without an explicit splashFactory falls
            // back to the Material InkSparkle preset.
            shape: RoundedRectangleBorder(
              borderRadius: shape_lib.AppCorner.brMd,
              side: BorderSide(
                color: i == selectedIndex
                    ? AppColors.magicPurple
                    : AppColors.hairlineLight,
                width: i == selectedIndex ? 2.0 : 1.0,
              ),
            ),
            onSelected: (_) => onSelect(i),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _BrushSizeRow extends StatelessWidget {
  const _BrushSizeRow({
    required this.sizeDp,
    required this.color,
    required this.onChanged,
  });

  final double sizeDp;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          _BrushSizePreview(size: sizeDp, color: color),
          AppSpacing.hGapMd,
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 12.0,
                  pressedElevation: 3.0,
                ),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 18.0),
              ),
              child: Slider(
                min: 4.0,
                max: 64.0,
                value: sizeDp,
                onChanged: onChanged,
              ),
            ),
          ),
          AppSpacing.hGapSm,
          SizedBox(
            width: 32.0,
            child: Text(
              sizeDp.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: AppTypography.bodySm.copyWith(color: AppColors.smoke),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrushSizePreview extends StatelessWidget {
  const _BrushSizePreview({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double clamped = size.clamp(8.0, 36.0);
    return SizedBox(
      width: 36.0,
      height: 36.0,
      child: Center(
        child: Container(
          width: clamped,
          height: clamped,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: shape_lib.AppElevation.softChip,
          ),
        ),
      ),
    );
  }
}
