// =============================================================================
// Magic Colors · features/coloring/coloring_controller.dart
// =============================================================================
//
// The single ChangeNotifier that holds the active canvas state for one
// drawing session. Scoped per-screen via `ChangeNotifierProvider(create:)`
// so each open drawing has its own controller — there is no global
// canvas state.
//
// STATE MACHINE
// -------------
//   • `_drawing`       — top-level drawing metadata (id, name, worldId…)
//   • `_strokes`       — append-only list of DrawingStroke; canvas's
//                        committed state. Mutations are O(1):
//                          - endStroke(): append
//                          - undo(): pop + push to _redoStack
//                          - redo(): pop _redoStack + push
//                          - clear(): empty the list (redoStack NOT touched)
//   • `_redoStack`     — DrawingStrokes that were popped by undo(). Cleared
//                        on any new stroke (so a user can't undo into a
//                        branch and then draw another stroke — that's the
//                        standard editor mental model).
//   • `_activeStrokeNotifier` — ValueNotifier<DrawingStroke?> for the
//                        in-progress stroke while the user's finger is
//                        down. Passed to `CustomPaint(repaint:)` so the
//                        canvas repaints at 60 fps WITHOUT recreating the
//                        outer widget tree.
//
// REACTIVITY SCOPE
// ----------------
//   • Brush colour / size / type changes → notifyListeners (toolbar rebuilds)
//   • `_strokes` / `_redoStack` changes → notifyListeners (canvas rebuilds)
//   • `_activeStrokeNotifier.value` changes → CustomPaint repaint only,
//     no widget rebuild.
//
// PERSISTENCE
// -----------
//   • `_saveTimer` — debounce 2 s after the last stroke ends; flushed on
//     `forceSave()`. Always written through [ColoringRepository.save]
//     so the wired observable stays consistent.
// =============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show HapticFeedback;

import 'package:hive/hive.dart' show Box;

import 'package:magic_colors/core/domain/economy/reward.dart';
import 'package:magic_colors/core/services/economy/reward_engine.dart';
import 'package:magic_colors/core/services/sound_service.dart'
    show MagicSound, SoundService;
import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/core/utils/logger.dart';

import 'data/coloring_repository.dart';
import 'data/palette_catalog.dart';
import 'domain/drawing.dart';
import 'domain/drawing_stroke.dart';
import 'domain/enums.dart';


// ── Tuning constants ─────────────────────────────────────────────────────

/// Debounce window for the auto-save. Tuned for a 4-year-old: plenty
/// long enough to swallow a 5-stroke flourish as one disk write, plenty
/// short enough that a swipe-out-without-saving loses at most ~2 s.
const Duration _kAutoSaveDebounce = Duration(seconds: 2);

/// Maximum strokes held in the redo stack. Bound this so a brain-dead
/// "undo spam" on a 4-year-old's tablet doesn't run the app out of RAM.
const int _kMaxRedoStackDepth = 50;


/// Per-session canvas controller. Constructed by `ColoringScreen` via
/// `ChangeNotifierProvider(create: (_) => ColoringController(...))`.
class ColoringController extends ChangeNotifier {
  ColoringController({
    required this.box,
    required this.sound,
    required this.drawingId,
    required this.worldId,
    required this.templateGlyph,
    required this.drawingName,
    this.player,
  })  : _drawing = ColoringRepository.findById(box, drawingId) ??
            Drawing.fresh(
              id: drawingId,
              worldId: worldId,
              templateGlyph: templateGlyph,
              name: drawingName,
              paletteRevision: PaletteCatalog.revision,
            ),
        // Seed the live stroke list from the already-resolved drawing —
        // a second repo call would just touch the same box entry.
        _strokes = <DrawingStroke>[
          ...(ColoringRepository.findById(box, drawingId)?.strokes ??
              const <DrawingStroke>[]),
        ],
        _name = drawingName,
        _activeStrokeNotifier =
            ValueNotifier<DrawingStroke?>(null);

  final Box<dynamic> box;
  final SoundService sound;
  final String drawingId;
  final String worldId;
  final String templateGlyph;
  final String drawingName;

  /// The current drawing metadata + committed strokes (snapshot).
  Drawing _drawing;

  /// The append-only stroke list. The canonical state of the canvas.
  final List<DrawingStroke> _strokes;

  /// Strokes popped off `_strokes` by undo() — popped back on redo().
  /// Cleared on every new stroke.
  final List<DrawingStroke> _redoStack = <DrawingStroke>[];

  /// Live "I'm currently painting" stroke. Repaints the canvas at 60 fps
  /// via `CustomPaint(repaint: this)` without rebuilding the widget tree.
  final ValueNotifier<DrawingStroke?> _activeStrokeNotifier;

  /// Brush state — drives toolbar + crosshair preview.
  Color _selectedColor =
      PaletteCatalog.colors[PaletteCatalog.defaultSelectedColorIndex];
  double _brushSize = PaletteCatalog.defaultBrushSize;
  BrushType _brushType = BrushType
      .values[PaletteCatalog.defaultBrushTypeIndex.clamp(0, BrushType.values.length - 1)];
  // Non-final: renameDrawing() must rewrite this on every tap-to-edit.
  String _name; // initialised in the constructor initializer list

  /// Debounced disk write.
  Timer? _saveTimer;
  bool _isDirty = false;

  /// Optional PlayerState. When wired (the parent screen passes a real
  /// instance after M1), the controller routes a drawing-completion
  /// reward through [RewardEngine] the first time the in-progress
  /// drawing becomes eligible. `null` during foundation wiring and in
  /// tests — never throws, never double-grants.
  final PlayerState? player;

  /// Wall-clock of the first stroke in this session. `null` before any
  /// paint. Driver of the elapsed-time gate inside
  /// [RewardEngine.isCompletionEligible].
  DateTime? _sessionStart;

  /// Distinct brush colour values (ARGB int) seen across this session.
  /// Inserted in [beginStroke] from the currently-selected colour.
  final Set<int> _usedColorsThisSession = <int>{};

  /// Committed strokes this session. Reset whenever the screen opens a
  /// fresh drawing.
  int _strokeCountThisSession = 0;

  /// True once a completion reward has been granted. Prevents repeat
  /// emission across the auto-save debounce window (otherwise a 30-s
  /// painting would print a reward every 2 seconds).
  bool _rewardGrantedThisSession = false;

  // ── Public read model ─────────────────────────────────────────────────

  Drawing get drawing => _drawing;
  List<DrawingStroke> get strokes => List<DrawingStroke>.unmodifiable(_strokes);
  int get strokeCount => _strokes.length;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get canClear => _strokes.isNotEmpty || _redoStack.isNotEmpty;

  Color get selectedColor => _selectedColor;
  int get selectedColorIndex =>
      PaletteCatalog.colors.indexOf(_selectedColor).clamp(0, PaletteCatalog.colors.length - 1);
  double get brushSize => _brushSize;
  BrushType get brushType => _brushType;
  int get brushTypeIndex => _brushType.index;
  String get name => _name;
  bool get isDirty => _isDirty;

  /// Painter-side hook. Repaints the canvas at every change.
  ValueListenable<DrawingStroke?> get activeStrokeListenable =>
      _activeStrokeNotifier;


  // ── Stroke lifecycle — called by the canvas GestureDetector ──────────

  /// Called on panDown. Mints an empty accumulator and seeds the
  /// texture jitter.
  void beginStroke(Offset localPosition) {
    // Soft tap on every new stroke — even a 4-year-old gets cue feedback.
    unawaited(HapticFeedback.lightImpact());
    _sessionStart ??= DateTime.now();
    _usedColorsThisSession.add(_selectedColor.value);
    _activeStrokeNotifier.value = DrawingStroke.empty(
      colorValue: _selectedColor.value,
      brushSize: _brushSize,
      brushType: _brushType,
      textureSeed: math.Random().nextInt(1 << 30),
    );
    updateStroke(localPosition);
  }

  /// Called on every panUpdate (60 fps target). Appends a single point.
  /// No notifyListeners — the ValueNotifier is the sole hot-path signal.
  void updateStroke(Offset localPosition) {
    final DrawingStroke? current = _activeStrokeNotifier.value;
    if (current == null) {
      return;
    }
    if (current.pointCount > 0) {
      final (double ddx, double ddy) = current.pointAt(current.pointCount - 1);
      final double dxDelta = localPosition.dx - ddx;
      final double dyDelta = localPosition.dy - ddy;
      final double distance =
          math.sqrt(dxDelta * dxDelta + dyDelta * dyDelta);
      // Tiny jitter under 1.5 px? Skip. Keeps points from chunking
      // when the finger is held still on a phone (60 Hz → 120 Hz noise).
      if (distance < 1.5) {
        return;
      }
    }
    _activeStrokeNotifier.value = current.appendPoint(
      localPosition.dx,
      localPosition.dy,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Called on panUp. Pushes the active stroke into `_strokes`, clears
  /// the redo stack (a new commit invalidates the redo future), plays the
  /// paint cue, and schedules an auto-save.
  void endStroke() {
    final DrawingStroke? completed = _activeStrokeNotifier.value;
    _activeStrokeNotifier.value = null;
    if (completed == null || completed.pointCount < 2) {
      // Tap-only gestures add negligible visual weight; skip noise.
      return;
    }
    _strokes.add(completed);
    _strokeCountThisSession += 1;
    _redoStack.clear();
    _isDirty = true;
    _scheduleAutoSave();
    // Best-effort paint cue — MagicSound.paint is the design-doc
    // canonical brush stroke SFX. Falls back to MagicSound.bigTap if the
    // pool fails to load (logged by SoundService).
    unawaited(sound.play(MagicSound.paint));
    notifyListeners();
  }

  // ── Brush state mutators ─────────────────────────────────────────────

  /// Selects the swatch at [index]. No-op when out of bounds.
  void setColorAt(int index) {
    if (index < 0 || index >= PaletteCatalog.colors.length) {
      return;
    }
    final Color next = PaletteCatalog.colors[index];
    if (next == _selectedColor) {
      return;
    }
    _selectedColor = next;
    notifyListeners();
  }

  /// Updates the brush size. Clamped to [4, 64] logical px.
  void setBrushSize(double sizeDp) {
    final double clamped = sizeDp.clamp(4.0, 64.0);
    if (clamped == _brushSize) {
      return;
    }
    _brushSize = clamped;
    notifyListeners();
  }

  /// Switches the active brush type. No haptic; toolbar already plays one.
  void setBrushType(BrushType type) {
    if (type == _brushType) {
      return;
    }
    _brushType = type;
    notifyListeners();
  }

  /// Updates the player-facing drawing name.
  void renameDrawing(String name) {
    final String trimmed = name.trim().isEmpty ? 'Untitled' : name.trim();
    if (trimmed == _name) {
      return;
    }
    _name = trimmed;
    _drawing = _drawing.copyWith(name: trimmed, updatedAt: DateTime.now());
    _isDirty = true;
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Undo / redo / clear ──────────────────────────────────────────────

  /// Pops the latest stroke and pushes it onto the redo stack.
  void undo() {
    if (_strokes.isEmpty) return;
    final DrawingStroke popped = _strokes.removeLast();
    if (_redoStack.length >= _kMaxRedoStackDepth) {
      _redoStack.removeAt(0); // bound memory
    }
    _redoStack.add(popped);
    unawaited(HapticFeedback.selectionClick());
    _isDirty = true;
    _scheduleAutoSave();
    notifyListeners();
  }

  /// Pops the most recently undone stroke and re-commits it.
  void redo() {
    if (_redoStack.isEmpty) return;
    _strokes.add(_redoStack.removeLast());
    unawaited(HapticFeedback.selectionClick());
    _isDirty = true;
    _scheduleAutoSave();
    notifyListeners();
  }

  /// Wipes the canvas. Redo stack is also cleared (no "undo a clear"
  /// chore for a 4-year-old). Special-case: when nothing was committed,
  /// this is a no-op.
  void clearCanvas() {
    if (_strokes.isEmpty && _redoStack.isEmpty) return;
    _strokes.clear();
    _redoStack.clear();
    _isDirty = true;
    _scheduleAutoSave();
    unawaited(HapticFeedback.mediumImpact());
    notifyListeners();
  }


  // ── Persistence ──────────────────────────────────────────────────────

  /// Coalesced save. Cancels any pending timer, then schedules a fresh
  /// one for `now + _kAutoSaveDebounce`. A 4-year-old finger-flicker
  /// never produces more than one disk write per `debounce` window.
  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_kAutoSaveDebounce, _flush);
  }

  /// Writes the current state to the Hive box. Idempotent — safe to call
  /// more than once per debounce window.
  void _flush() {
    _saveTimer = null;
    if (!_isDirty) return;
    _drawing = _drawing.copyWith(
      strokes: List<DrawingStroke>.unmodifiable(_strokes),
      name: _name,
      updatedAt: DateTime.now(),
      isDraft: false,
    );
    final bool ok = ColoringRepository.save(box, _drawing);
    if (ok) {
      _isDirty = false;
      logger.info('ColoringController._flush saved '
          'id=${_drawing.id} strokes=${_drawing.strokeCount}');
      _evaluateRewardEligibility();
    }
  }

  // ── M1 — Player Economy integration ────────────────────────────────────

  /// M1 (Player Economy) — evaluates drawing completion eligibility
  /// against the latest PlayerState snapshot. Idempotent across the
  /// auto-save debounce window: only fires once per session.
  ///
  /// Eligibility (deliberately NOT stroke-count, which a 4-year-old can
  /// bypass with a single 600-point path):
  ///   • Distinct colour values seen across this session > 2.
  ///   • Wall-clock duration from first stroke > 15 seconds.
  ///
  /// When eligible, derives a 0..3 star rating from (duration × colors
  /// × strokes) and grants the matching reward.
  void _evaluateRewardEligibility() {
    if (_rewardGrantedThisSession) {
      return;
    }
    final DateTime start = _sessionStart ?? DateTime.now();
    final Duration duration = DateTime.now().difference(start);
    final bool eligible = RewardEngine.isCompletionEligible(
      distinctColorCount: _usedColorsThisSession.length,
      duration: duration,
    );
    if (!eligible) {
      return;
    }
    final int stars = RewardEngine.starsFromSignals(
      duration: duration,
      distinctColorCount: _usedColorsThisSession.length,
      strokeCount: _strokeCountThisSession,
    );
    if (stars <= 0) {
      return;
    }
    final PlayerState? playerSnapshot = player;
    if (playerSnapshot == null) {
      return;
    }
    final Reward reward = RewardEngine.computeDrawingReward(
      stars,
      worldId: worldId,
    );
    reward.grantTo(playerSnapshot);
    _rewardGrantedThisSession = true;
    logger.info(
      'ColoringController granted drawing reward (world=$worldId '
      'stars=$stars colors=${_usedColorsThisSession.length} '
      'strokes=$_strokeCountThisSession '
      'duration=${duration.inSeconds}s)',
    );
  }

  /// Forces a synchronous flush. Called from the screen's dispose()
  /// so a swipe-out doesn't lose the last two seconds of work.
  void forceSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _flush();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  void dispose() {
    forceSave();
    _saveTimer?.cancel();
    _activeStrokeNotifier.dispose();
    super.dispose();
  }
}
