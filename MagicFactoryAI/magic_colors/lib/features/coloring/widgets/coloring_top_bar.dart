// =============================================================================
// Magic Colors · features/coloring/widgets/coloring_top_bar.dart
// =============================================================================
//
// Slim top bar for the /coloring/:id screen:
//   • Round back button on the left.
//   • Centered editable title (tap-to-rename).
//   • Right action: chip showing the save state (Saved · Saving · Unsaved).
//
// The title edits via an inline TextField that flips into edit mode on
// tap. Edits route through `controller.renameDrawing` which schedules
// the next auto-save.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_shape.dart';

import 'package:magic_colors/features/coloring/coloring_controller.dart';

// ── Tuning constants ────────────────────────────────────────────────────

const double _kTopBarHeight = 56.0;
const double _kBackButtonSize = 40.0;
const double _kStatusChipFontSize = 12.0;

class ColoringTopBar extends StatefulWidget {
  const ColoringTopBar({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final ColoringController controller;
  final VoidCallback onBack;

  @override
  State<ColoringTopBar> createState() => _ColoringTopBarState();
}

class _ColoringTopBarState extends State<ColoringTopBar> {
  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;
  bool _editing = false;

  /// Last-renamed value mirrored into the edit field. Updated whenever
  /// an external rename (e.g. a future Gallery flow) updates
  /// [ColoringController.name] so the field doesn't go stale while
  /// sitting uncommitted.
  String _lastExternalName = '';

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.controller.name);
    _lastExternalName = widget.controller.name;
    widget.controller.addListener(_onControllerChanged);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Sync: when the controller's name flips externally while the field
  // is NOT being edited, mirror it into the field. We deliberately skip
  // the sync inside the active edit session so the user's keystrokes
  // are never clobbered mid-typing.
  void _onControllerChanged() {
    if (_editing) {
      return;
    }
    final String live = widget.controller.name;
    if (live != _lastExternalName && live != _textCtrl.text) {
      _textCtrl.text = live;
    }
    _lastExternalName = live;
  }

  void _commitEdit() {
    widget.controller.renameDrawing(_textCtrl.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kTopBarHeight,
      child: Row(
        children: <Widget>[
          _BackButton(onTap: widget.onBack),
          Expanded(
            child: _editing
                ? _EditField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    onSubmit: _commitEdit,
                    onCancel: () {
                      setState(() => _editing = false);
                      _textCtrl.text = widget.controller.name;
                    },
                  )
                : _TitleDisplay(
                    label: widget.controller.name,
                    onTap: () => setState(() => _editing = true),
                  ),
          ),
          _SaveStatusChip(isDirty: widget.controller.isDirty),
          const SizedBox(width: 12.0),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        width: _kBackButtonSize,
        height: _kBackButtonSize,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepInk),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _TitleDisplay extends StatelessWidget {
  const _TitleDisplay({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepInk,
            fontWeight: FontWeight.w700,
            fontSize: 18.0,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        style: const TextStyle(
          color: AppColors.deepInk,
          fontWeight: FontWeight.w700,
          fontSize: 18.0,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Name your drawing',
          hintStyle: TextStyle(color: AppColors.smoke),
        ),
      ),
    );
  }
}

class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({required this.isDirty});

  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final String label = isDirty ? 'Saving…' : 'Saved';
    final Color bg = isDirty
        ? AppColors.sunshineYellow.withValues(alpha: 0.30)
        : AppColors.success.withValues(alpha: 0.15);
    final Color fg = isDirty ? AppColors.tangerine : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppCorner.brSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: _kStatusChipFontSize,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
