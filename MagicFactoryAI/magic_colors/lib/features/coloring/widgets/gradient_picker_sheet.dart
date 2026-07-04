// =============================================================================
// Magic Colors · features/coloring/widgets/gradient_picker_sheet.dart
// =============================================================================
//
// M2.3 — Modal sheet for editing the current Fill gradient. Shows two
// colour swatches (top + bottom), reads from the standard palette for
// tap-to-pick, and exposes an "Active" toggle that flips the painter
// between two-stop shading and single-colour fill.
//
// UX SHAPE
// --------
//   ┌────────────────────────────────────┐
//   │   Gradient  [ ON ▢ OFF ]           │
//   │                                    │
//   │   Top:    [●] Gold                  │
//   │   Bottom: [●] Magic Pink            │
//   │                                    │
//   │   [Reset]              [Close]      │
//   └────────────────────────────────────┘
//
// State flow:
//   • Reading-only call sites: controller.gradientPair / .isGradientActive.
//   • Writes route through the controller's setGradientEnabled /
//     setGradientTop / setGradientBottom. The sheet never mutates the
//     controller outside those entry points.
//
// The sheet reuses the standard palette swatch grid so the user
// already knows the tap gesture.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_shape.dart' show AppCorner;
import 'package:magic_colors/core/widgets/color_swatch_grid.dart';

import 'package:magic_colors/features/coloring/coloring_controller.dart';
import 'package:magic_colors/features/coloring/data/palette_catalog.dart';


class GradientPickerSheet extends StatefulWidget {
  const GradientPickerSheet({
    super.key,
    required this.controller,
  });

  final ColoringController controller;

  @override
  State<GradientPickerSheet> createState() => _GradientPickerSheetState();
}


class _GradientPickerSheetState extends State<GradientPickerSheet> {
  bool _pickingTop = true;

  @override
  Widget build(BuildContext context) {
    final ColoringController c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, Widget? _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 4.0),
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: AppColors.smoke.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              _titleRow(c),
              const SizedBox(height: 8.0),
              _preview(c),
              const SizedBox(height: 12.0),
              _activePill(c),
              const SizedBox(height: 12.0),
              _pickingTabs(),
              const SizedBox(height: 8.0),
              _palettePicker(c),
              const SizedBox(height: 12.0),
              _buttonRow(c),
            ],
          ),
        );
      },
    );
  }

  Widget _titleRow(ColoringController c) {
    return Text(
      'Gradient',
      style: const TextStyle(
        color: AppColors.deepInk,
        fontSize: 18.0,
        fontWeight: FontWeight.w700,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _preview(ColoringController c) {
    final int top = c.gradientPair.topColorValue;
    final int bottom = c.gradientPair.bottomColorValue;
    final bool active = c.isGradientActive;
    return Container(
      height: 64.0,
      decoration: BoxDecoration(
        borderRadius: AppCorner.brMd,
        gradient: LinearGradient(
          colors: <Color>[Color(top), Color(bottom)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: active ? AppColors.magicPink : AppColors.hairlineLight,
          width: active ? 3.0 : 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: active
          ? null
          : const Text(
              'Single colour',
              style: TextStyle(
                color: AppColors.cloudWhite,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _activePill(ColoringController c) {
    final bool on = c.isGradientActive;
    return GestureDetector(
      onTap: () => c.setGradientEnabled(!on),
      child: Container(
        height: 36.0,
        decoration: BoxDecoration(
          borderRadius: AppCorner.brMd,
          color: on ? AppColors.magicPurple : AppColors.skyTouchedWhite,
          border: Border.all(
            color: on ? AppColors.magicPurple : AppColors.hairlineLight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          on ? 'Gradient ON' : 'Gradient OFF (single colour)',
          style: TextStyle(
            color: on ? AppColors.cloudWhite : AppColors.deepInk,
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _pickingTabs() {
    return Row(
      children: <Widget>[
        Expanded(child: _tabPill(true, 'Top colour')),
        const SizedBox(width: 8.0),
        Expanded(child: _tabPill(false, 'Bottom colour')),
      ],
    );
  }

  Widget _tabPill(bool forTop, String label) {
    final bool selected = _pickingTop == forTop;
    return GestureDetector(
      onTap: () => setState(() => _pickingTop = forTop),
      child: Container(
        height: 36.0,
        decoration: BoxDecoration(
          borderRadius: AppCorner.brMd,
          color: selected
              ? AppColors.cosmicPurple
              : AppColors.skyTouchedWhite,
          border: Border.all(
            color: selected
                ? AppColors.cosmicPurple
                : AppColors.hairlineLight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.cloudWhite : AppColors.deepInk,
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _palettePicker(ColoringController c) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220.0),
      child: ColorSwatchGrid(
        colors: PaletteCatalog.colors,
        selectedIndex: null, // The sheet doesn't drive selectedColor.
        onSelect: (int idx) {
          final int value = PaletteCatalog.colorValueAt(idx);
          if (_pickingTop) {
            c.setGradientTop(value);
          } else {
            c.setGradientBottom(value);
          }
        },
        columns: PaletteCatalog.columns,
        swatchSize: 36.0,
      ),
    );
  }

  Widget _buttonRow(ColoringController c) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            onPressed: () => c.setGradientEnabled(false),
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
