// =============================================================================
// Magic Colors · features/coloring/widgets/parent_gate_sheet.dart
// =============================================================================
//
// M2.4 — ParentGate modal. Routes between two flavours based on the
// attached PlayerState's [parentGateKind]:
//
//   • math         — show a 1-digit + 1-digit addition problem with a
//                    numeric input. 3 tries; failure → recordMathFailure
//                    on the PlayerState (locks for 24 h).
//   • hold         — show a 3-second long-press button. Release before
//                    3 s → abort. Completion → recordHoldSuccess.
//
// On success the sheet pops with `true`; on dismiss with `false`.
//
// Maths-challenge arithmetic is intentionally simple (single-digit
// addition only) so a 4-year-old child can NOT solve it without
// outside help. This is the kid-resistant surface that gates the
// Premium colour upsell — COPPA-aligned pattern.
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/core/theme/app_colors.dart';
import 'package:magic_colors/core/theme/app_shape.dart';
import 'package:magic_colors/core/theme/app_typography.dart';
import 'package:magic_colors/core/utils/haptics.dart';
import 'package:magic_colors/core/widgets/primary_button.dart';
import 'package:magic_colors/core/widgets/secondary_button.dart'
    show SecondaryButton;

/// Public entry: show the gate as a modal bottom sheet. Returns `true`
/// when the user successfully completed the gate (caller proceeds with
/// the upsell), `false` on cancel. The caller does not need to observe
/// PlayerState directly — the sheet writes persistence + analytics.
Future<bool> showParentGateSheet({
  required BuildContext context,
  required PlayerState player,
}) async {
  final bool? ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cloudWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext ctx) => ParentGateSheet(player: player),
  );
  return ok ?? false;
}

// =============================================================================
//  ParentGateSheet
// =============================================================================

class ParentGateSheet extends StatefulWidget {
  const ParentGateSheet({super.key, required this.player});

  final PlayerState player;

  @override
  State<ParentGateSheet> createState() => _ParentGateSheetState();
}

class _ParentGateSheetState extends State<ParentGateSheet> {
  ParentGateKind _kind = ParentGateKind.math;

  @override
  void initState() {
    super.initState();
    _kind = widget.player.parentGateKind();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _kind == ParentGateKind.math
              ? _MathChallenge(
                  key: const ValueKey<String>('math'),
                  onSuccess: _onMathSuccess,
                  onCancel: () => Navigator.of(context).pop(false),
                  onLocked: () {
                    widget.player.recordParentGateMathFailure();
                    Navigator.of(context).pop(false);
                  },
                )
              : _HoldToConfirm(
                  key: const ValueKey<String>('hold'),
                  onSuccess: _onHoldSuccess,
                  onCancel: () => Navigator.of(context).pop(false),
                ),
        ),
      ),
    );
  }

  void _onMathSuccess() {
    widget.player.recordParentGateMathSuccess();
    Haptics.medium();
    Navigator.of(context).pop(true);
  }

  void _onHoldSuccess() {
    widget.player.recordParentGateHoldSuccess();
    Haptics.medium();
    Navigator.of(context).pop(true);
  }
}

// =============================================================================
//  Math challenge branch.
// =============================================================================

class _MathChallenge extends StatefulWidget {
  const _MathChallenge({
    super.key,
    required this.onSuccess,
    required this.onCancel,
    required this.onLocked,
  });

  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final VoidCallback onLocked;

  @override
  State<_MathChallenge> createState() => _MathChallengeState();
}

class _MathChallengeState extends State<_MathChallenge> {
  static const int _kMaxTries = 3;

  /// Deterministic-ish. Not crypto — but the kid-resistant surface
  /// doesn't need crypto (see docs/design_system/14 § COPPA).
  final math.Random _rng = math.Random(DateTime.now().millisecondsSinceEpoch);

  late final int _a = 1 + _rng.nextInt(9); // 1..9
  late final int _b = 1 + _rng.nextInt(9); // 1..9
  late final int _answer = _a + _b;

  final TextEditingController _textCtrl = TextEditingController();
  int _triesLeft = _kMaxTries;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final int? guess = int.tryParse(_textCtrl.text.trim());
    if (guess == null) {
      setState(() => _error = 'Please type a number.');
      return;
    }
    if (guess == _answer) {
      widget.onSuccess();
      return;
    }
    final int tries = _triesLeft - 1;
    setState(() {
      _triesLeft = tries;
      _error = tries <= 0
          ? 'Locked — try again later.'
          : (guess > _answer ? 'Too high.' : 'Too low.');
    });
    Haptics.light();
    if (tries <= 0) {
      widget.onLocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('math-body'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Are you a grown-up?',
          textAlign: TextAlign.center,
          style: AppTypography.titleLg,
        ),
        const SizedBox(height: 8),
        Text(
          'How much is $_a + $_b?',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLg.copyWith(color: AppColors.smoke),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _textCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: AppTypography.numericCounter.copyWith(
            color: AppColors.deepInk,
          ),
          decoration: InputDecoration(
            hintText: '?',
            hintStyle: AppTypography.numericCounter.copyWith(
              color: AppColors.smoke,
            ),
            errorText: _error,
            filled: true,
            fillColor: AppColors.skyTouchedWhite,
            border: const OutlineInputBorder(
              borderRadius: AppCorner.brMd,
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Text(
          'Tries left: $_triesLeft',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(color: AppColors.smoke),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Continue',
          fullWidth: true,
          onPressed: _submit,
        ),
        const SizedBox(height: 8),
        SecondaryButton(
          label: 'Cancel',
          fullWidth: true,
          leading: Icons.close_rounded,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }
}

// =============================================================================
//  Hold-to-confirm branch.
// =============================================================================

class _HoldToConfirm extends StatefulWidget {
  const _HoldToConfirm({
    super.key,
    required this.onSuccess,
    required this.onCancel,
  });

  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  State<_HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<_HoldToConfirm>
    with SingleTickerProviderStateMixin {
  static const Duration _kHoldDuration = Duration(seconds: 3);

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _kHoldDuration,
  );

  void _onTapDown(TapDownDetails _) {
    _ctrl.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails _) {
    if (_ctrl.value >= 1.0) {
      widget.onSuccess();
    } else {
      _ctrl.reverse();
    }
  }

  void _onTapCancel() {
    _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('hold-body'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Are you a grown-up?',
          textAlign: TextAlign.center,
          style: AppTypography.titleLg,
        ),
        const SizedBox(height: 8),
        Text(
          'Press and hold the button for 3 seconds.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLg.copyWith(color: AppColors.smoke),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedBuilder(
                animation: _ctrl,
                builder: (BuildContext context, Widget? _) {
                  return Container(
                    height: 56.0,
                    decoration: BoxDecoration(
                      color: AppColors.cloudWhite,
                      borderRadius: AppCorner.brMd,
                      border: Border.all(color: AppColors.magicPurple),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _ctrl.value,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.magicPurple,
                            borderRadius: AppCorner.brMd,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Text(
                'Hold to confirm',
                style: AppTypography.buttonMd.copyWith(
                  color: AppColors.deepInk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SecondaryButton(
          label: 'Cancel',
          fullWidth: true,
          leading: Icons.close_rounded,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }
}
