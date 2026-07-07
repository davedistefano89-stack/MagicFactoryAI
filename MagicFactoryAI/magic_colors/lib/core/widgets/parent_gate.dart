// =============================================================================
// Magic Colors · core/widgets/parent_gate.dart
// =============================================================================
//
// A reusable ParentGate overlay that gate-keeps Premium / Shop / Settings
// flows behind a simple math challenge. Used in compliance with COPPA / GDPR-K
// — the challenge proves a supervising adult is present before any
// purchase or account-management action proceeds.
//
//   ▸ Math challenge  — 2-digit addition/subtraction, 3 tries.
//   ▸ Hold shortcut   — after first success, hold-to-confirm (1.5 s).
//   ▸ 24h lockout     — after 3 failures, gate is locked for 24 h.
//
// STATE
//   Reads + writes [PlayerState] parent gate fields:
//   `parentGateMathOk`, `parentGateLastFailureAt`, and the convenience
//   getters `parentGateFailureLocked` / `parentGateKind()`.
//
// USAGE
//   ```dart
//   final bool? passed = await showParentGate(context);
//   if (passed == true) { /* proceed to premium flow */ }
//   ```
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import '../state/player_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_shape.dart';
import '../theme/app_typography.dart';
import '../utils/haptics.dart';

export '../state/player_state.dart' show ParentGateKind;

// ── Tuning constants ──────────────────────────────────────────────────

const int _kMaxAttempts = 3;
const int _kHoldDurationMs = 1500;
const int _kMaxOperand = 12;

// =============================================================================
//  Public entry-point.
// =============================================================================

/// Shows the ParentGate as a full-screen dialog. Returns `true` if the
/// user passed the challenge, `false` if they dismissed, `null` if the
/// gate is locked.
Future<bool?> showParentGate(BuildContext context) {
  final PlayerState player = context.read<PlayerState>();
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => _ParentGateDialog(player: player),
    ),
  );
}

// =============================================================================
//  _ParentGateDialog
// =============================================================================

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog({required this.player});

  final PlayerState player;

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog>
    with SingleTickerProviderStateMixin {
  late int _a;
  late int _b;
  late int _correct;
  late List<int> _options;
  String _op = '+';
  int _fails = 0;
  bool _submitted = false;

  // ── Hold-to-confirm state.
  late AnimationController _holdController;
  late Animation<double> _holdProgress;

  bool get _useMath => widget.player.parentGateKind() == ParentGateKind.math;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kHoldDurationMs),
    );
    _holdProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _holdController, curve: Curves.linear),
    );
    _generateProblem();
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _generateProblem() {
    final math.Random rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    _a = rng.nextInt(_kMaxOperand) + 1;
    _b = rng.nextInt(_kMaxOperand) + 1;
    final bool add = rng.nextBool();
    _correct = add ? _a + _b : _a - _b;
    _op = add ? '+' : '−';

    // Generate 3 wrong options.
    final Set<int> opts = <int>{_correct};
    while (opts.length < 4) {
      final int offset = rng.nextInt(5) + 1;
      final int fake = rng.nextBool() ? _correct + offset : _correct - offset;
      if (fake >= 0) opts.add(fake);
    }
    _options = opts.toList()..shuffle(rng);
  }

  void _onOptionTap(int value) {
    if (_submitted) return;
    Haptics.selection();
    if (value == _correct) {
      _pass();
    } else {
      _fail();
    }
  }

  void _pass() {
    _submitted = true;
    widget.player.recordParentGateMathSuccess();
    Haptics.success();
    Navigator.of(context).pop(true);
  }

  void _fail() {
    _fails++;
    if (_fails >= _kMaxAttempts) {
      _submitted = true;
      widget.player.recordParentGateMathFailure();
      Haptics.heavy();
      Navigator.of(context).pop(false);
    } else {
      Haptics.warning();
      setState(() => _generateProblem());
    }
  }

  void _dismiss() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepInk.withValues(alpha: 0.85),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('🔒', style: TextStyle(fontSize: 56)),
                AppSpacing.vGapMd,
                Text(
                  'Parent Gate',
                  style: AppTypography.titleLg.copyWith(
                    color: AppColors.cloudWhite,
                  ),
                ),
                AppSpacing.vGapSm,
                Text(
                  'This area is for grown-ups only.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.cloudWhite.withValues(alpha: 0.7),
                  ),
                ),
                AppSpacing.vGapLg,
                if (_useMath) ...<Widget>[
                  _MathChallenge(
                    a: _a,
                    b: _b,
                    operator: _op,
                    options: _options,
                    fails: _fails,
                    maxAttempts: _kMaxAttempts,
                    onTap: _onOptionTap,
                  ),
                ] else
                  _HoldConfirm(
                    holdController: _holdController,
                    holdProgress: _holdProgress,
                    onHoldComplete: _pass,
                  ),
                AppSpacing.vGapXl,
                TextButton(
                  onPressed: _dismiss,
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.cloudWhite.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  _MathChallenge — 2-digit problem + 4 options.
// =============================================================================

class _MathChallenge extends StatelessWidget {
  const _MathChallenge({
    required this.a,
    required this.b,
    required this.operator,
    required this.options,
    required this.fails,
    required this.maxAttempts,
    required this.onTap,
  });

  final int a;
  final int b;
  final String operator;
  final List<int> options;
  final int fails;
  final int maxAttempts;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // ── Problem ─────────────────────────────────────────
        Text(
          '$a $operator $b = ?',
          style: AppTypography.displayLg.copyWith(
            color: AppColors.cloudWhite,
          ),
        ),
        AppSpacing.vGapLg,

        // ── Options grid ─────────────────────────────────────
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          alignment: WrapAlignment.center,
          children: options
              .map((int opt) => SizedBox(
                    width: 100,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: () => onTap(opt),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.cloudWhite.withValues(alpha: 0.12),
                        foregroundColor: AppColors.cloudWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppCorner.brMd,
                        ),
                      ),
                      child: Text(
                        '$opt',
                        style: AppTypography.numericCompact.copyWith(
                          color: AppColors.cloudWhite,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        AppSpacing.vGapMd,

        // ── Attempt counter ───────────────────────────────────
        Text(
          '${maxAttempts - fails} attempt${maxAttempts - fails == 1 ? '' : 's'} remaining',
          style: AppTypography.caption(
            size: 13,
            color: fails > 0
                ? AppColors.tangerine
                : AppColors.cloudWhite.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  _HoldConfirm — press-and-hold shortcut (shown after first math success).
// =============================================================================

class _HoldConfirm extends StatefulWidget {
  const _HoldConfirm({
    required this.holdController,
    required this.holdProgress,
    required this.onHoldComplete,
  });

  final AnimationController holdController;
  final Animation<double> holdProgress;
  final VoidCallback onHoldComplete;

  @override
  State<_HoldConfirm> createState() => _HoldConfirmState();
}

class _HoldConfirmState extends State<_HoldConfirm> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.holdProgress,
      builder: (BuildContext context, Widget? _) {
        final double p = widget.holdProgress.value;
        return Column(
          children: <Widget>[
            Text(
              '👆 Press & hold',
              style: AppTypography.titleMd.copyWith(
                color: AppColors.cloudWhite,
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              'Hold the button for 2 seconds to confirm.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.cloudWhite.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapLg,
            GestureDetector(
              onLongPressStart: (_) {
                widget.holdController.forward();
              },
              onLongPressEnd: (_) {
                widget.holdController.reverse();
              },
              onLongPress: widget.onHoldComplete,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      AppColors.magicPurple.withValues(alpha: 0.15 + p * 0.4),
                  border: Border.all(
                    color:
                        AppColors.magicPurple.withValues(alpha: 0.3 + p * 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('🔓', style: TextStyle(fontSize: 36)),
                      AppSpacing.vGapSm,
                      Text(
                        '${(p * 100).toInt()}%',
                        style: AppTypography.caption(
                          size: 14,
                          color: AppColors.cloudWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
