// =============================================================================
// Magic Colors · features/coloring/coloring_controller.dart
// =============================================================================
//
// The single ChangeNotifier that holds the active canvas state for one
// drawing session. Scoped per-screen via `ChangeNotifierProvider(create:)`
// so each open drawing has its own controller.
//
// STATE MACHINE
// -------------
//   • _commands        — append-only List<PaintCommand> (sealed union:
//                        DrawStroke | FillRegion). This is the single
//                        redo-stack source for M2+.
//   • _redoStack       — commands popped off `_commands` by undo().
//                        Cleared on every new commit (standard editor
//                        mental model).
//   • _activeStrokeNotifier — ValueNotifier<PaintCommand?> for the
//                        in-progress stroke while the user's finger is
//                        down. Fill-region taps commit synchronously.
//   • fillAnimator     — Drives the 240 ms fade-in for newly-committed
//                        FillRegion commands.
//   • gradientPair     — current Fill gradient (M2.3, Fill-only).
//   • isGradientActive — flag the painter reads to decide between
//                        single-colour and two-stop gradient shading.
//
// M2.3 INTEGRATIONS WITH PLAYERSTATE
// ----------------------------------
//   • rememberSelectedColor(index) — pushes the palette index onto the
//                        player's recent-colours MRU.
//   • toggleFavoriteColor(index)   — proxies PlayerState.toggleFavorite.
//   • tryUnlockColorWithCoins      — proxies PlayerState.unlockColorWithCoins.
//   • tryUnlockColorWithStars      — proxies PlayerState.unlockColorWithStars.
//
// REACTIVITY SCOPE
// ----------------
//   • Brush colour / size / type changes → notifyListeners (toolbar rebuilds).
//   • Commands added / undone → notifyListeners (canvas rebuilds).
//   • _activeStrokeNotifier.value changes → CustomPaint repaint only.
//   • FillAnimator fade ticks → canvas rebuilds via a ListenableBuilder.
//
// PERSISTENCE
// ----------
//   • _saveTimer — debounce 2 s after the last commit; flushed on
//     forceSave(). Writes through [ColoringRepository.save].
// =============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/scheduler.dart' show TickerProvider;
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
import 'domain/fill_region.dart' show newFillRegionId;
import 'domain/gradient_pair.dart';
import 'domain/paint_command.dart';
import 'fill/bucket_fill_consts.dart';
import 'fill/scanline_filler.dart'
    show
        FloodFillReport,
        FloodFillRejection,
        FloodFillGuard,
        FloodFillResult,
        floodFillReport;
import 'fill/fill_animator.dart';
import 'painting/fill_picture_cache.dart';
import 'painting/sparkle_trail.dart';
import 'painting/stroke_picture_cache.dart';

// ── Tuning constants ──────────────────────────────────────────────────

const Duration _kAutoSaveDebounce = Duration(seconds: 2);
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
    required this.vsync,
    this.player,
  })  : _drawing = (ColoringRepository.findById(box, drawingId) ??
                Drawing.fresh(
                  id: drawingId,
                  worldId: worldId,
                  templateGlyph: templateGlyph,
                  name: drawingName,
                  paletteRevision: PaletteCatalog.revision,
                ))
            .hydrate(),
        _commands = <PaintCommand>[
          ...(ColoringRepository.findById(box, drawingId)
                  ?.hydrate()
                  .effectiveCommands ??
              const <PaintCommand>[]),
        ],
        _name = drawingName,
        _activeStrokeNotifier = ValueNotifier<PaintCommand?>(null),
        fillAnimator = FillAnimator(vsync: vsync);

  final Box<dynamic> box;
  final SoundService sound;
  final String drawingId;
  final String worldId;
  final String templateGlyph;
  final String drawingName;
  final TickerProvider vsync;

  /// Current drawing metadata + committed commands (snapshot).
  Drawing _drawing;

  /// Append-only command list — the canonical canvas state.
  final List<PaintCommand> _commands;

  /// Commands popped off _commands by undo().
  final List<PaintCommand> _redoStack = <PaintCommand>[];

  /// Live in-progress command (only DrawStroke at runtime; fill
  /// commands commit synchronously on tap).
  final ValueNotifier<PaintCommand?> _activeStrokeNotifier;

  /// Brush state — drives toolbar + crosshair preview.
  Color _selectedColor =
      PaletteCatalog.colors[PaletteCatalog.defaultSelectedColorIndex];
  double _brushSize = PaletteCatalog.defaultBrushSize;
  BrushType _brushType = BrushType.values[PaletteCatalog.defaultBrushTypeIndex
      .clamp(0, BrushType.values.length - 1)];
  String _name; // initialised in the constructor initializer list

  Timer? _saveTimer;
  bool _isDirty = false;

  final PlayerState? player;

  /// Fade-in driver for newly-committed FillRegion commands.
  final FillAnimator fillAnimator;

  DateTime? _sessionStart;
  final Set<int> _usedColorsThisSession = <int>{};
  bool _rewardGrantedThisSession = false;

  /// M2.1 — pre-baked Pictures of committed DrawStrokes. Strokes are
  /// immutable, so a colour change does NOT clear the cache — only
  /// `clear()` and `undo()` drop entries.
  ///
  /// M2.4 — the canvas painter replays cached Pictures for all
  /// committed DrawStrokes; [endStroke] pre-bakes here at commit time
  /// so the next frame's replay is O(1).
  final StrokePictureCache pictureCache = StrokePictureCache();

  /// M2.2 PRODUCTION — pre-baked Pictures of committed FillRegions.
  /// Replaces the old live row-by-row paintFillRegion path. Painter
  /// replays each FillRegion via `canvas.drawPicture(pic)` after
  /// `canvas.scale(pixelRatio)` + `canvas.translate(origin)`.
  final FillPictureCache fillPictureCache = FillPictureCache();

  /// M2.4 — per-session sparkle trail engine. Honours a reduceMotion
  /// flag kept in sync with [SettingsState.reduceMotion] (constructor
  /// time + lazy updates only — changing the flag mid-stroke does NOT
  /// materialise trail particles retroactively).
  SparkleTrail? _sparkleTrail;

  /// Read-side accessor. The canvas widget subscribes its second
  /// CustomPaint to this ChangeNotifier when the widget is mounted.
  SparkleTrail get sparkleTrail =>
      _sparkleTrail ??= SparkleTrail(reduceMotion: false);

  /// M2.4 — flips the trail between reduced-motion flavours. The
  /// canvas widget watches [SettingsState] and forwards the result.
  void setSparkleReducedMotion(bool value) {
    _sparkleTrail?.dispose();
    _sparkleTrail = SparkleTrail(reduceMotion: value);
  }

  /// M2.4 — true once a drawing-complete reward has been granted
  /// this session. The screen reads this on each notify to decide
  /// whether to pop the success overlay.
  bool _hasUnacknowledgedReward = false;

  /// M2.4 — read-side gate the [ColoringScreen] watches.
  bool get hasUnacknowledgedReward => _hasUnacknowledgedReward;

  /// M2.4 — coin delta awarded by the most-recent drawing-complete
  /// reward. Read by [DrawingCompleteOverlay] to populate the pill row.
  int lastRewardCoinDelta = 0;

  /// M2.4 — gem delta awarded by the most-recent drawing-complete
  /// reward.
  int lastRewardGemDelta = 0;

  /// M2.4 — call after [DrawingCompleteOverlay.onDone] to clear the
  /// unacknowledged flag so the screen stops asking for it.
  void acknowledgeReward() {
    if (!_hasUnacknowledgedReward) return;
    _hasUnacknowledgedReward = false;
    notifyListeners();
  }

  /// M2.3 — gradient pair used by the Fill tool. Default-disabled;
  /// [setGradientEnabled] flips the painter's path between single
  /// colour and two-stop shader.
  GradientPair _gradientPair = GradientPair.single(
    PaletteCatalog.colorValueAt(PaletteCatalog.defaultSelectedColorIndex),
  );

  // ── Public read model ─────────────────────────────────────────────

  Drawing get drawing => _drawing;

  /// Read-only view of the commands list. Always returns a fresh
  /// UnmodifiableListView so consumers cannot accidentally mutate the
  /// live state.
  List<PaintCommand> get commands => List<PaintCommand>.unmodifiable(_commands);

  int get commandCount => _commands.length;

  /// DEPRECATED — M2.2 callers should use [commands].length. Kept
  /// so out-of-tree widgets that reference `strokeCount` still
  /// compile (returns 0).
  int get strokeCount => _commands.length;

  bool get canUndo => _commands.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get canClear => _commands.isNotEmpty || _redoStack.isNotEmpty;

  Color get selectedColor => _selectedColor;
  int get selectedColorIndex => PaletteCatalog.colors
      .indexOf(_selectedColor)
      .clamp(0, PaletteCatalog.colors.length - 1);
  double get brushSize => _brushSize;
  BrushType get brushType => _brushType;
  int get brushTypeIndex => _brushType.index;
  String get name => _name;
  bool get isDirty => _isDirty;

  /// M2.3 — read-side projection of the gradient pair. Painter reads.
  GradientPair get gradientPair => _gradientPair;
  bool get isGradientActive => _gradientPair.isTwoStop;

  ValueListenable<PaintCommand?> get activeStrokeListenable =>
      _activeStrokeNotifier;

  // ── Stroke lifecycle ─────────────────────────────────────────────

  void beginStroke(Offset localPosition) {
    unawaited(HapticFeedback.lightImpact());
    _sessionStart ??= DateTime.now();
    // ignore: deprecated_member_use
    _usedColorsThisSession.add(_selectedColor.value);
    _activeStrokeNotifier.value = DrawStroke(
      DrawingStroke.empty(
        // ignore: deprecated_member_use
        colorValue: _selectedColor.value,
        brushSize: _brushSize,
        brushType: _brushType,
        textureSeed: math.Random().nextInt(1 << 30),
      ),
    );
    updateStroke(localPosition);
  }

  void updateStroke(Offset localPosition) {
    final PaintCommand? current = _activeStrokeNotifier.value;
    if (current is! DrawStroke) {
      return;
    }
    final DrawingStroke stroke = current.stroke;
    if (stroke.pointCount > 0) {
      final (double ddx, double ddy) = stroke.pointAt(stroke.pointCount - 1);
      final double dxDelta = localPosition.dx - ddx;
      final double dyDelta = localPosition.dy - ddy;
      final double distance = math.sqrt(dxDelta * dxDelta + dyDelta * dyDelta);
      if (distance < 1.5) {
        return;
      }
    }
    _activeStrokeNotifier.value = DrawStroke(
      stroke.appendPoint(
        localPosition.dx,
        localPosition.dy,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void endStroke() {
    final PaintCommand? completed = _activeStrokeNotifier.value;
    _activeStrokeNotifier.value = null;
    if (completed is! DrawStroke) {
      return;
    }
    final DrawingStroke stroke = completed.stroke;
    if (stroke.pointCount < 2) {
      return;
    }
    _commands.add(completed);
    _redoStack.clear();
    _isDirty = true;
    _scheduleAutoSave();
    unawaited(sound.play(MagicSound.paint));

    // M2.4 — pre-bake the picture immediately so the next frame's
    // paint cycle replays from cache (no path re-traversal).
    try {
      pictureCache.getOrBake(stroke);
    } on Object catch (_) {
      // best-effort: cache failures never block a stroke commit.
    }

    // M2.4 — fire sparkle burst at the lift point + a softer chased
    // fade along the last few stroke points. Both honour reduceMotion.
    final int n = stroke.pointCount;
    if (n >= 2) {
      final (double ex, double ey) = stroke.pointAt(n - 1);
      sparkleTrail.liftBurst(
        Offset(ex, ey),
        color: stroke.colorValue,
        seed: stroke.textureSeed,
      );
      sparkleTrail.chaseFromPath(
        stroke.points,
        color: stroke.colorValue,
        seed: stroke.textureSeed + 1,
      );
    }

    notifyListeners();
  }

  // ── Fill-region lifecycle (M2.2 PRODUCTION) ─────────────────────

  /// Tracks the SETTINGS-level reduceMotion flag. Mirrored here so
  /// [commitFillRegion] can pass it through to [FillAnimator.start]
  /// without re-reading SettingsState each call.
  bool _reduceMotionForFill = false;

  /// M2.2 PRODUCTION — SettingsState watcher pipe. The canvas widget
  /// calls this whenever reduceMotion flips so subsequent fills
  /// short-circuit their fade-in if motion is reduced.
  void setFillReducedMotion(bool value) {
    if (_reduceMotionForFill == value) return;
    _reduceMotionForFill = value;
  }

  /// Tracks the latest rejection from [floodFill]. Cleared on every
  /// successful commit. The screen widget reads this for haptic
  /// routing (a "tap but no fill" soft-pulse feels different from a
  /// background-tap double-pulse).
  FloodFillRejection? lastFillRejection;

  /// Commits a fill region from a tap point on the canvas.
  ///
  /// The [pixels] buffer is interpreted as RGBA8888 (4 bytes/pixel).
  /// [width] × [height] are the IMAGE dimensions (i.e. the snapshot
  /// size); the [seedX] / [seedY] are likewise IMAGE coordinates.
  /// [pixelRatio] is the devicePixelRatio the snapshot was taken at
  /// — we store it on the resulting FillRegion so the painter can
  /// scale-accurately replay the cached Picture.
  ///
  /// Anti-leak guards (per [FloodFillGuard]):
  ///   • tinyRegion        → soft haptic only, no commit
  ///   • backgroundTap     → stronger haptic + no commit
  ///   • hardMaxExceeded   → logger.warn + soft haptic + no commit
  ///
  /// Haptic + sound + sparkle feedback fire on successful commit
  /// only. The fill-fade-in is started after the picture is cached.
  void commitFillRegion({
    required List<int> pixels,
    required int width,
    required int height,
    required double seedX,
    required double seedY,
    required double pixelRatio,
  }) {
    if (_brushType != BrushType.fill) {
      return;
    }
    // ignore: deprecated_member_use
    final int seedColor = _selectedColor.value;

    // ── Build the anti-leak guard honoring the requested tolerance.
    const FloodFillGuard guard = FloodFillGuard(
      minPixels: BucketFillConsts.minFillPixels,
      maxFraction: BucketFillConsts.maxFillFraction,
    ); // Run BFS via the production wrapper that bundles the rejection
    // reason into a FloodFillReport struct (no module-global lastRejection).
    final FloodFillReport report = floodFillReport(
      pixels: pixels,
      width: width,
      height: height,
      targetColor: seedColor,
      seedX: seedX.round(),
      seedY: seedY.round(),
      guard: guard,
    );
    lastFillRejection = report.rejection;
    if (!report.isSuccess) {
      _routeFillRejectionHaptic(report.rejection);
      return;
    }

    final FloodFillResult result = report.result!;

    // ── Build the FillRegion. Convert image coords back to logical
    //    using the supplied pixelRatio so the painter's cached
    //    Picture can be scaled at draw-time.
    //
    //    M2.2 PRODUCTION — bridge the BFS's TIGHT bounds, not the
    //    image's full dimensions. A 1024×768 image whose centre
    //    512×384 was visited should commit a logicalWidth=256 region
    //    at dpr=2, not the full 512. The cached Picture was pre-baked
    //    in IMAGE-space anchored at `imageBounds`, so the painter's
    //    `translate(origin).scale(pixelRatio)` remains correct.
    final double dpr = pixelRatio <= 0 ? 1.0 : pixelRatio;
    final Offset logicalOrigin = Offset(
      result.bounds.left / dpr,
      result.bounds.top / dpr,
    );
    final int logicalWidth = (result.bounds.width / dpr).ceil();
    final int logicalHeight = (result.bounds.height / dpr).ceil();

    final FillRegion region = FillRegion.fromSpans(
      id: newFillRegionId(),
      colorValue: seedColor,
      result: result,
      logicalOrigin: logicalOrigin,
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      pixelRatio: dpr,
      timestamp: DateTime.now(),
    );

    // Pre-bake the picture BEFORE committing to _commands. If the
    // bake throws (rare: uhandled PictureRecorder.dispose in tests),
    // the region is NOT committed — clean rollback. The cache owns
    // its insertion; we look up the same Picture via id at paint time.
    try {
      fillPictureCache.getOrBake(region);
    } on Object catch (error, stack) {
      logger.error(
        'ColoringController.fillPictureCache bake failed '
        'id=${region.id}',
        error: error,
        stackTrace: stack,
      );
      return;
    }

    _commands.add(region);
    _usedColorsThisSession.add(seedColor);
    _redoStack.clear();
    _isDirty = true;
    _scheduleAutoSave();

    fillAnimator.start(
      region.id,
      reduceMotion: _reduceMotionForFill,
    );

    // ── Sparkle fill-burst at the region centroid (logical coords).
    final double centerX = logicalOrigin.dx + (logicalWidth / 2.0);
    final double centerY = logicalOrigin.dy + (logicalHeight / 2.0);
    sparkleTrail.fillBurst(
      Offset(centerX, centerY),
      color: seedColor,
      seed: region.timestamp.microsecondsSinceEpoch,
    );

    unawaited(HapticFeedback.mediumImpact());
    unawaited(sound.play(MagicSound.magicSparkle));
    notifyListeners();
  }

  /// Soft-haptic dispatcher for the various fill-rejection reasons.
  /// Tiny / seed-mismatch → lightImpact. Background-tap / hard-cap →
  /// mediumImpact (kid will feel "nope, try again" rather than
  /// "acceptance").
  void _routeFillRejectionHaptic(FloodFillRejection? reason) {
    if (_reduceMotionForFill) return; // honour user prefs
    switch (reason) {
      case FloodFillRejection.invalidInput:
      case FloodFillRejection.eraserColour:
      case FloodFillRejection.seedMismatch:
      case null:
        return; // silent — these don't reach the user anyway
      case FloodFillRejection.tinyRegion:
      case FloodFillRejection.backgroundTap:
      case FloodFillRejection.hardMaxExceeded:
        unawaited(HapticFeedback.lightImpact());
    }
  }

  /// Cancels the in-progress fade-in for [regionId]. Used when a fill
  /// is undo'd mid-animation.
  void retireFillAnimation(String regionId) {
    fillAnimator.retire(regionId);
  }

  // ── Brush state mutators ─────────────────────────────────────────

  /// Tap-to-select. M2.3 — also pushes the index onto the player MRU
  /// (best-effort: no-op when no PlayerState is wired). Selection
  /// already gated by [ColorAcl.resolve] before this fires.
  void setColorAt(int index) {
    if (index < 0 || index >= PaletteCatalog.colors.length) {
      return;
    }
    final Color next = PaletteCatalog.colors[index];
    if (next == _selectedColor) {
      return;
    }
    _selectedColor = next;
    rememberSelectedColor(index);
    // M2.3 — gradient defaults to single-colour when the user
    // re-selects; if enabled, the picker flips the stops to use
    // this colour on both ends so the picker stays coherent with
    // the active palette index.
    if (_gradientPair.enabled) {
      _gradientPair = GradientPair.topOnly(
        // ignore: deprecated_member_use
        newTop: next.value,
        previous: _gradientPair,
      );
    }
    notifyListeners();
  }

  void setBrushSize(double sizeDp) {
    final double clamped = sizeDp.clamp(4.0, 64.0);
    if (clamped == _brushSize) {
      return;
    }
    _brushSize = clamped;
    notifyListeners();
  }

  void setBrushType(BrushType type) {
    if (type == _brushType) {
      return;
    }
    _brushType = type;
    notifyListeners();
  }

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

  // ── M2.3 — gradient state ────────────────────────────────────────

  /// Enables / disables the gradient pairing. When enabled the painter
  /// paints FillRegions with a `ui.Gradient.linear` over the region
  /// bounds. Drawing strokes ignore the gradient — only Fill uses it.
  void setGradientEnabled(bool enabled) {
    if (enabled == _gradientPair.enabled) {
      return;
    }
    if (enabled) {
      // Seed the pair with the current selected colour on both
      // stops — the next tap on the picker sheet swaps the bottom
      // stop to a different colour.
      // ignore: deprecated_member_use
      final int value = _selectedColor.value;
      _gradientPair =
          GradientPair(topColorValue: value, bottomColorValue: value);
    } else {
      // ignore: deprecated_member_use
      _gradientPair = GradientPair.single(_selectedColor.value);
    }
    notifyListeners();
  }

  /// Updates only the top stop of the active gradient.
  void setGradientTop(int colorValue) {
    _gradientPair = GradientPair(
      topColorValue: colorValue,
      bottomColorValue: _gradientPair.bottomColorValue,
      enabled: _gradientPair.enabled,
    );
    notifyListeners();
  }

  /// Updates only the bottom stop.
  void setGradientBottom(int colorValue) {
    _gradientPair = GradientPair(
      topColorValue: _gradientPair.topColorValue,
      bottomColorValue: colorValue,
      enabled: _gradientPair.enabled,
    );
    notifyListeners();
  }

  // ── M2.3 — PlayerState integration ───────────────────────────────

  /// Pushes [paletteIndex] onto the player's recent-colours MRU. No-op
  /// if [player] is null. Idempotent against duplicates.
  void rememberSelectedColor(int paletteIndex) {
    final PlayerState? p = player;
    if (p == null) {
      return;
    }
    p.addRecentColor(paletteIndex);
  }

  /// Long-press → toggles favorite. Returns the new favorited state.
  bool toggleFavoriteColor(int paletteIndex) {
    final PlayerState? p = player;
    if (p == null) {
      return false;
    }
    return p.toggleFavoriteColor(paletteIndex);
  }

  /// Spend coins to unlock [paletteIndex]. Refused if the player has
  /// no PlayerState wired or cannot afford the cost.
  bool tryUnlockColorWithCoins({
    required int paletteIndex,
    required int cost,
  }) {
    final PlayerState? p = player;
    if (p == null) {
      return false;
    }
    final bool ok = p.unlockColorWithCoins(
      paletteIndex: paletteIndex,
      cost: cost,
    );
    if (ok) {
      playUnlockCelebration();
      // Auto-select the just-unlocked colour so the user keeps
      // painting without an extra tap.
      setColorAt(paletteIndex);
      notifyListeners();
    }
    return ok;
  }

  /// Spend stars in [worldId] to unlock [paletteIndex]. [worldId]
  /// is the worldId string the player is unlocking the colour for
  /// (caller-supplied so the controller can route by world).
  bool tryUnlockColorWithStars({
    required String worldId,
    required int paletteIndex,
    required int cost,
  }) {
    final PlayerState? p = player;
    if (p == null) {
      return false;
    }
    final bool ok = p.unlockColorWithStars(
      worldId: worldId,
      paletteIndex: paletteIndex,
      cost: cost,
    );
    if (ok) {
      playUnlockCelebration();
      setColorAt(paletteIndex);
      notifyListeners();
    }
    return ok;
  }

  /// Plays the lock-unlock feedback (sound + medium haptic).
  Future<void> playUnlockCelebration() async {
    unawaited(HapticFeedback.mediumImpact());
    unawaited(sound.play(MagicSound.magicSparkle));
  }

  // ── Undo / redo / clear ──────────────────────────────────────────

  void undo() {
    if (_commands.isEmpty) return;
    final PaintCommand popped = _commands.removeLast();
    if (popped is DrawStroke) {
      pictureCache.drop(popped.stroke.id);
    }
    if (popped is FillRegion) {
      retireFillAnimation(popped.id);
      fillPictureCache.drop(popped.id);
    }
    if (_redoStack.length >= _kMaxRedoStackDepth) {
      _redoStack.removeAt(0);
    }
    _redoStack.add(popped);
    unawaited(HapticFeedback.selectionClick());
    _isDirty = true;
    _scheduleAutoSave();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final PaintCommand cmd = _redoStack.removeLast();
    _commands.add(cmd);
    if (cmd is FillRegion) {
      try {
        fillPictureCache.getOrBake(cmd);
      } on Object catch (_) {
        // best-effort: cache failure should never block a redo.
      }
      fillAnimator.start(cmd.id, reduceMotion: _reduceMotionForFill);
    }
    unawaited(HapticFeedback.selectionClick());
    _isDirty = true;
    _scheduleAutoSave();
    notifyListeners();
  }

  void clearCanvas() {
    if (_commands.isEmpty && _redoStack.isEmpty) return;
    _commands.clear();
    _redoStack.clear();
    pictureCache.clear();
    fillPictureCache.clear();
    fillAnimator.clearAll();
    _isDirty = true;
    _scheduleAutoSave();
    unawaited(HapticFeedback.mediumImpact());
    notifyListeners();
  }

  // ── Persistence ──────────────────────────────────────────────────

  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_kAutoSaveDebounce, _flush);
  }

  void _flush() {
    _saveTimer = null;
    if (!_isDirty) return;
    _drawing = _drawing.copyWith(
      commands: List<PaintCommand>.unmodifiable(_commands),
      name: _name,
      updatedAt: DateTime.now(),
      isDraft: false,
    );
    final bool ok = ColoringRepository.save(box, _drawing);
    if (ok) {
      _isDirty = false;
      logger.info(
        'ColoringController._flush saved '
        'id=${_drawing.id} commands=${_drawing.effectiveCommands.length}',
      );
      // Sprint 7 — bump the daily-gameplay counters BEFORE the
      // reward-eligibility check. An ineligible drawing (under
      // the 15s / 3-color threshold) still counts as a completed
      // drawing, so the daily "color N drawings" challenge stays
      // reactive. The star delta is computed from the SAME signal
      // snapshot so we don't double-count.
      _recordDailyTracking();
      _evaluateRewardEligibility();
    }
  }

  /// Sprint 7 — bumps the daily-gameplay counters via PlayerState.
  /// Called from [_flush] after a successful save. Idempotent
  /// against the same save (PlayerState.recordDrawingCompletion is
  /// itself idempotent for repeated calls within a single draw,
  /// because the dirty flag is reset after a successful save).
  void _recordDailyTracking() {
    final PlayerState? snapshot = player;
    if (snapshot == null) {
      return;
    }
    snapshot.recordDrawingCompletion();
    // Snapshot the stars BEFORE the reward grant so the counter
    // doesn't accidentally include the coins/gems delta (the
    // drawing reward is currency, not stars).
    final int stars = RewardEngine.starsFromSignals(
      duration: _sessionDuration(),
      distinctColorCount: _usedColorsThisSession.length,
      strokeCount: _commands.length,
    );
    if (stars > 0) {
      snapshot.recordStarEarned(stars);
    }
  }

  /// Wall-clock duration of the current session. Falls back to
  /// "now" when no stroke has fired yet (a fresh open) so the
  /// star derivation never crashes on a cold session.
  Duration _sessionDuration() {
    final DateTime start = _sessionStart ?? DateTime.now();
    return DateTime.now().difference(start);
  }

  // ── M1 — Player Economy integration ────────────────────────────────

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
      strokeCount: _commands.length,
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

    // M2.4 — snapshot + flag the unacknowledged reward so the
    // [DrawingCompleteOverlay] can fire after the auto-save.
    lastRewardCoinDelta = reward.totalCoinDelta;
    lastRewardGemDelta = reward.totalGemDelta;
    _hasUnacknowledgedReward = true;

    logger.info(
      'ColoringController granted drawing reward (world=$worldId '
      'stars=$stars colors=${_usedColorsThisSession.length} '
      'commands=${_commands.length} '
      'duration=${duration.inSeconds}s)',
    );
    notifyListeners();
  }

  void forceSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _flush();
  }

  @override
  void dispose() {
    forceSave();
    _saveTimer?.cancel();
    _activeStrokeNotifier.dispose();
    pictureCache.clear();
    fillPictureCache.clear();
    fillAnimator.dispose();
    _sparkleTrail?.dispose();
    _sparkleTrail = null;
    super.dispose();
  }
}
