// =============================================================================
// Magic Colors · features/coloring/widgets/coloring_canvas.dart
// =============================================================================
//
// M2.2 — Interactive painting surface with pinch zoom, 2-finger pan,
// and bucket-fill tap routing.
//
// PAINTER DATA FLOW
// -----------------
//   • `Transform` (parent)                   — applies the ViewTransform
//                                               matrix (scale + translation).
//   • `RepaintBoundary` (key)                — isolates the painter +
//                                               gives the fill-tool
//                                               pipeline a snapshot root
//                                               for `toImage` reads.
//   • `Listener` (raw PointerEvents)         — accepts every pointer
//                                               down/move/up/cancel.
//                                               Routes to either:
//                                                 - paint (single finger
//                                                   for non-fill brushes),
//                                                 - pinch (two fingers),
//                                                 - FILL (single tap for
//                                                   BrushType.fill).
//   • `CustomPaint` (M21 painter)            — paints committed commands
//                                               (DrawStroke + FillRegion)
//                                               via BrushPainter.paintCommand.
//                                               Repaints on either the
//                                               active-stroke notifier OR
//                                               the FillAnimator (via
//                                               Listenable.merge) so a
//                                               fade-in tick repaints the
//                                               committed region alpha.
//
// POINTER ROUTING (state machine)
//   • idle      — no fingers down. New pointerDown → paint | fill.
//   • painting  — exactly one pointer is the "paint pointer". Second
//                 pointer commits the active stroke cleanly, then
//                 transitions to pinching.
//   • pinching  — two fingers. Pointer 3+ is ignored. Counts under 2
//                 → idle (no auto-resume).
//   • fill      — non-Duration mode. pointerDown commits a fill
//                 synchronously (via controller.fillTap). pointerMove
//                 + pointerUp are ignored for fill.
//
// M2.2 FILL ROUTING
//   On pointerDown with BrushType.fill:
//     1. Capture the RepaintBoundary root → renderObject.
//     2. Call `boundary.toImage()` (returns Future<ui.Image>).
//     3. Read the bytes via `image.toByteData(ImageByteFormat.rawRgba)`.
//     4. Convert seedPos from canvas-space to image-space.
//     5. Call `controller.fillTap(pixels, w, h, seedX, seedY)`.
//   The controller's commitFillRegion runs the BFS + commits the
//   FillRegion. The FillAnimator kicks the fade-in on commit.
// =============================================================================

import 'dart:async';
import 'dart:ui' as ui show Image, Picture;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'package:magic_colors/core/state/settings_state.dart';
import 'package:magic_colors/core/utils/logger.dart';
import 'package:magic_colors/features/coloring/coloring_controller.dart';
import 'package:magic_colors/features/coloring/domain/drawing_stroke.dart';
import 'package:magic_colors/features/coloring/domain/enums.dart';
import 'package:magic_colors/features/coloring/domain/paint_command.dart';
import 'package:magic_colors/features/coloring/fill/bucket_fill_consts.dart';
import 'package:magic_colors/features/coloring/fill/fill_animator.dart';
import 'package:magic_colors/features/coloring/painting/brush_painter.dart';
import 'package:magic_colors/features/coloring/painting/fill_picture_cache.dart';
import 'package:magic_colors/features/coloring/painting/sparkle_trail.dart';
import 'package:magic_colors/features/coloring/painting/stroke_picture_cache.dart';
import 'package:magic_colors/features/coloring/painting/stroke_smoother.dart';
import 'package:magic_colors/features/coloring/state/view_transform_controller.dart';

// ── Tuning constants ────────────────────────────────────────────────────

const double _kTemplateGlyphAlpha = 0.10;
const double _kTemplateGlyphCapFraction = 0.55;

enum _GestureMode { idle, painting, pinching, fill }

class ColoringCanvas extends StatefulWidget {
  const ColoringCanvas({
    super.key,
    required this.controller,
    required this.color,
    required this.isDarkSurface,
  });

  final ColoringController controller;
  final Color color;
  final bool isDarkSurface;

  @override
  State<ColoringCanvas> createState() => _ColoringCanvasState();
}

class _ColoringCanvasState extends State<ColoringCanvas> {
  final Set<int> _activePointers = <int>{};
  final Map<int, Offset> _pointerPositions = <int, Offset>{};

  int? _paintPointer;

  Offset? _pinchLastCentroid;
  double? _pinchLastDistance;

  /// M2.2 — GlobalKey to the inner RepaintBoundary. Used by the
  /// fill-tap pipeline to snapshot the canvas's currently painted
  /// content into a ui.Image.
  final GlobalKey _paintBoundaryKey = GlobalKey(debugLabel: 'paintBoundary');

  _GestureMode _mode = _GestureMode.idle;

  // ── Pointer handlers ────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
    _activePointers.add(event.pointer);

    // M2.2 — fill brush short-circuits to a tap-only flow.
    if (widget.controller.brushType == BrushType.fill) {
      if (_mode != _GestureMode.idle) {
        return; // ignore taps mid-paint or mid-pinch
      }
      _mode = _GestureMode.fill;
      unawaited(_handleFillTap(event.localPosition));
      return;
    }

    if (_mode == _GestureMode.idle && _activePointers.length == 1) {
      _mode = _GestureMode.painting;
      _paintPointer = event.pointer;
      widget.controller.beginStroke(event.localPosition);
      return;
    }
    if (_mode == _GestureMode.painting && _activePointers.length == 2) {
      widget.controller.endStroke();
      _paintPointer = null;
      _mode = _GestureMode.pinching;
      _capturePinchBaseline();
      return;
    }
    // 3+ fingers or pinch-mid-flight arrival → ignored.
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointerPositions[event.pointer] = event.position;
    if (_mode == _GestureMode.fill) {
      return; // fill is tap-only
    }
    if (_mode == _GestureMode.painting && event.pointer == _paintPointer) {
      widget.controller.updateStroke(event.localPosition);
      return;
    }
    if (_mode == _GestureMode.pinching && _activePointers.length == 2) {
      _applyPinch();
      return;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    _pointerPositions.remove(event.pointer);
    if (_mode == _GestureMode.fill) {
      _mode = _GestureMode.idle;
      return;
    }
    if (_mode == _GestureMode.painting && event.pointer == _paintPointer) {
      _paintPointer = null;
      _mode = _GestureMode.idle;
      widget.controller.endStroke();
      return;
    }
    if (_mode == _GestureMode.pinching && _activePointers.length < 2) {
      _mode = _GestureMode.idle;
      _pinchLastCentroid = null;
      _pinchLastDistance = null;
      return;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _pointerPositions.remove(event.pointer);
    if (_mode == _GestureMode.fill) {
      _mode = _GestureMode.idle;
      return;
    }
    if (_mode == _GestureMode.painting && event.pointer == _paintPointer) {
      _paintPointer = null;
      _mode = _GestureMode.idle;
      widget.controller.endStroke();
      return;
    }
    if (_mode == _GestureMode.pinching && _activePointers.length < 2) {
      _mode = _GestureMode.idle;
      _pinchLastCentroid = null;
      _pinchLastDistance = null;
      return;
    }
  }

  // ── Fill-tap pipeline (M2.2 PRODUCTION) ─────────────────────────────

  /// Snapshots the inner RepaintBoundary to a ui.Image, extracts the
  /// RGBA8888 bytes, and forwards them to
  /// [ColoringController.commitFillRegion].
  ///
  /// Tablet support: the snapshot uses [MediaQuery.devicePixelRatioOf]
  /// so a tap on an iPad Pro @ 3x maps to the exact image pixel rather
  /// than the 1x under-sized default. The controller stores the
  /// devicePixelRatio on the FillRegion so the painter can scale the
  /// cached Picture during replay.
  Future<void> _handleFillTap(Offset localPosition) async {
    final RenderRepaintBoundary? boundary = _paintBoundaryKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      logger.warn(
        'ColoringCanvas._handleFillTap: paintBoundary not attached',
      );
      return;
    }
    // M2.2 PRODUCTION — honour the actual devicePixelRatio (iPad Pro
    // @ 3x, Galaxy Tab @ 2x, etc.). Without this the seed coords map
    // to the wrong image pixel and the BFS misses the tapped region
    // on high-DPI tablets.
    final double pixelRatio = MediaQuery.devicePixelRatioOf(context);
    // Pipe reduceMotion to the controller so commitFillRegion can
    // short-circuit the fade-in.
    widget.controller.setFillReducedMotion(
      context.read<SettingsState>().reduceMotion,
    );
    // Image dimensions = boundary.size × pixelRatio.
    final ui.Image image = await boundary.toImage(
      pixelRatio: pixelRatio,
    );
    try {
      final ByteData? byteData = await image.toByteData();
      if (byteData == null) {
        logger.warn('ColoringCanvas._handleFillTap: byteData is null');
        return;
      }
      // Convert Uint8List → List<int> for the controller API.
      final List<int> pixels = byteData.buffer.asUint8List();

      // Convert LOGICAL (canvas) seed coords to IMAGE coords by
      // multiplying by pixelRatio. The BFS operates in IMAGE space.
      final double seedX = localPosition.dx * pixelRatio;
      final double seedY = localPosition.dy * pixelRatio;
      widget.controller.commitFillRegion(
        pixels: pixels,
        width: image.width,
        height: image.height,
        seedX: seedX.clamp(0, image.width - 1).toDouble(),
        seedY: seedY.clamp(0, image.height - 1).toDouble(),
        pixelRatio: pixelRatio,
      );
    } finally {
      image.dispose();
    }
  }

  // ── Pinch math ──────────────────────────────────────────────────────

  void _capturePinchBaseline() {
    if (_activePointers.length < 2) return;
    final List<Offset> ps = _activePointers
        .map((int id) => _pointerPositions[id])
        .whereType<Offset>()
        .toList();
    if (ps.length < 2) return;
    _pinchLastCentroid = (ps[0] + ps[1]) / 2.0;
    _pinchLastDistance = (ps[1] - ps[0]).distance;
  }

  void _applyPinch() {
    final List<Offset> ps = _activePointers
        .map((int id) => _pointerPositions[id])
        .whereType<Offset>()
        .toList();
    if (ps.length < 2) return;
    final Offset centroid = (ps[0] + ps[1]) / 2.0;
    final double distance = (ps[1] - ps[0]).distance;
    final Offset? prevCentroid = _pinchLastCentroid;
    final double? prevDistance = _pinchLastDistance;
    if (prevCentroid == null || prevDistance == null) {
      _pinchLastCentroid = centroid;
      _pinchLastDistance = distance;
      return;
    }
    final double scaleFactor =
        prevDistance == 0 ? 1.0 : distance / prevDistance;
    final Offset focalDelta = centroid - prevCentroid;
    final ViewTransformController view =
        context.read<ViewTransformController>();
    view.scaleAroundFocalPoint(
      factor: scaleFactor,
      focalPointScreen: centroid,
    );
    view.pan(focalDelta);
    _pinchLastCentroid = centroid;
    _pinchLastDistance = distance;
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final SettingsState settings = context.watch<SettingsState>();
    final ColoringController controller = widget.controller;
    final ViewTransformController view =
        context.watch<ViewTransformController>();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size canvasSize = constraints.biggest;
        view.setCanvasSize(canvasSize);
        // M2.4 — push reduceMotion into the trail; flip is cheap.
        if (controller.sparkleTrail.reduceMotion != settings.reduceMotion) {
          controller.setSparkleReducedMotion(settings.reduceMotion);
        }
        return Transform(
          transform: view.matrix,
          child: Stack(
            children: <Widget>[
              RepaintBoundary(
                key: _paintBoundaryKey,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: CustomPaint(
                    painter: _M21CanvasPainter(
                      commands: controller.commands,
                      pictureCache: controller.pictureCache,
                      fillPictureCache: controller.fillPictureCache,
                      activeStrokeListenable: controller.activeStrokeListenable,
                      templateGlyph: controller.drawing.templateGlyph,
                      reduceMotion: settings.reduceMotion,
                      fillAnimator: controller.fillAnimator,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              // M2.4 — sparkle trail overlay. Sits above the canvas
              // but below any future overlays. The painter reads the
              // trail's interpolated positions on every tick.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SparkleTrailPainter(
                      trail: controller.sparkleTrail,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
//  _M21CanvasPainter — paint logic.
//
//  Committed commands dispatch through the BrushPainter.paintCommand
//  unified dispatcher. DrawStrokes come from the picture cache; FillRegions
//  paint live with row-by-row mask stamping + alpha from FillAnimator.
//  The active (in-progress) stroke paints live with quadratic midpoint
//  smoothing.
// =============================================================================

class _M21CanvasPainter extends CustomPainter {
  _M21CanvasPainter({
    required this.commands,
    required this.pictureCache,
    required this.fillPictureCache,
    required this.activeStrokeListenable,
    required this.templateGlyph,
    required this.reduceMotion,
    required this.fillAnimator,
  }) : super(
          repaint: Listenable.merge(
            <Listenable>[activeStrokeListenable, fillAnimator],
          ),
        );

  final List<PaintCommand> commands;
  final StrokePictureCache pictureCache;
  final FillPictureCache fillPictureCache;
  final ValueListenable<PaintCommand?> activeStrokeListenable;
  final String templateGlyph;
  final bool reduceMotion;
  final FillAnimator fillAnimator;

  static const BrushPainter _brush = BrushPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (templateGlyph.isNotEmpty) {
      _paintTemplate(canvas, size, templateGlyph);
    }

    // ── Layer 2 — committed commands. DrawStroke replays from
    // StrokePictureCache; FillRegion replays from FillPictureCache
    // with a saveLayer for alpha-modulated fade-in.
    for (final PaintCommand c in commands) {
      if (c is DrawStroke) {
        final ui.Picture pic =
            pictureCache.getOrBake(c.stroke, reduceMotion: reduceMotion);
        final bounds4 = strokeBounds(c.stroke);
        canvas.save();
        canvas.translate(bounds4.minX, bounds4.minY);
        canvas.drawPicture(pic);
        canvas.restore();
        continue;
      }
      if (c is FillRegion) {
        _paintFillRegionCached(canvas, c);
        continue;
      }
    }

    // Layer 3 — actively-painting stroke with smoothing.
    final PaintCommand? active = activeStrokeListenable.value;
    if (active is DrawStroke && active.stroke.pointCount >= 2) {
      _paintActiveSmoothed(active.stroke, canvas);
    }
  }

  /// M2.2 PRODUCTION — render a committed [FillRegion] with fade-in.
  ///
  /// Strategy ("Path A" — see code-review decision log in M2.2):
  ///   * During the 240ms fade-in (and the 60ms flash pulse), the
  ///     animation's `finalAlpha < 1.0`. We render the region using
  ///     the live spans-aware path in [BrushPainter.paintFillRegion],
  ///     which applies the alpha directly to the stamp paints. This
  ///     is O(N spans) but only runs for ~14 frames during the
  ///     animation window — the transient CPU cost is acceptable
  ///     and avoids ANY offscreen saveLayer texture per fill per
  ///     frame.
  ///   * Once `finalAlpha >= 1.0` the animation has finished; we
  ///     snap to the cached `ui.Picture` and replay it with a
  ///     zero-cost `drawPicture` — this is the O(1) steady-state.
  ///
  /// Why not `canvas.drawPicture(pic, alphaPaint)`? Skia's
  /// `drawPicture` accepts a hint `Paint`, but the hint's
  /// `color.alpha` is NOT used as a multiplier on the picture's
  /// recorded alphas (only `blendMode` and `colorFilter` are
  /// honoured as transfer hints). Since the cached picture was
  /// recorded at full alpha, the hint paint would have been a
  /// silent no-op, breaking the fade-in.
  void _paintFillRegionCached(Canvas canvas, FillRegion region) {
    final double progress = fillAnimator.progressFor(region.id);
    if (progress <= 0.0) {
      return; // first frame hasn't started yet
    }
    final bool flashing = fillAnimator.isFlashing(region.id);
    final double baseAlpha = progress.clamp(0.0, 1.0);
    final double flashAlpha = flashing ? BucketFillConsts.fillFlashAlpha : 0.0;
    // Combine via max — the flash is a one-shot punch, the fade is
    // the long-tail curve. Reading `max` rather than `+` keeps the
    // region from going over 1.0 alpha while still hitting the
    // flash target on the first frame.
    final double finalAlpha = baseAlpha > flashAlpha ? baseAlpha : flashAlpha;

    if (finalAlpha >= 1.0) {
      // STEADY-STATE — replay the cached `ui.Picture` at full alpha.
      // getOrBake is non-nullable: it returns the cached Picture or
      // bakes a fresh one on miss, so there is no null branch.
      final ui.Picture pic = fillPictureCache.getOrBake(region);
      canvas.save();
      canvas.translate(region.origin.dx, region.origin.dy);
      canvas.scale(region.pixelRatio, region.pixelRatio);
      canvas.drawPicture(pic);
      canvas.restore();
      return;
    }

    // FADE-IN PATH — alpha < 1.0, OR cache miss. Use the
    // spans-aware live path: paint.alpha carries the modulation
    // directly to the framebuffer, no offscreen layer needed.
    _brush.paintFillRegion(
      canvas,
      region,
      alphaMultiplier: finalAlpha,
    );
  }

  @override
  bool shouldRepaint(covariant _M21CanvasPainter old) {
    return old.commands != commands ||
        old.templateGlyph != templateGlyph ||
        old.fillPictureCache != fillPictureCache ||
        old.reduceMotion != reduceMotion;
  }

  // ── Layer helpers ───────────────────────────────────────────────────

  void _paintTemplate(Canvas canvas, Size size, String glyph) {
    final TextSpan span = TextSpan(
      text: glyph,
      style: TextStyle(
        fontSize: size.shortestSide * _kTemplateGlyphCapFraction,
        color: const Color(0xFF0F1226).withValues(alpha: _kTemplateGlyphAlpha),
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final double x = (size.width - tp.width) / 2;
    final double y = (size.height - tp.height) / 2;
    tp.paint(canvas, Offset(x, y));
  }

  void _paintActiveSmoothed(DrawingStroke raw, Canvas canvas) {
    final List<double> smoothed = StrokeSmoother.quadraticMidpoint(raw.points);
    final DrawingStroke faux = DrawingStroke(
      id: raw.id,
      colorValue: raw.colorValue,
      brushSize: raw.brushSize,
      brushTypeIndex: raw.brushTypeIndex,
      points: smoothed,
      textureSeed: raw.textureSeed,
      timestampMs: raw.timestampMs,
    );
    _brush.paint(canvas, faux, reduceMotion: reduceMotion);
  }
}

// =============================================================================
//  _SparkleTrailPainter — paints the active particle list interpolated
//  against the wall-clock. Reads the trail's ChangeNotifier as repaint
//  source so lift bursts + chased fades in lockstep with the controller's
//  endStroke / commitFill events.
// =============================================================================

class _SparkleTrailPainter extends CustomPainter {
  _SparkleTrailPainter({required this.trail}) : super(repaint: trail);

  final SparkleTrail trail;

  @override
  void paint(Canvas canvas, Size size) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    // Pump the trail (it removes expired particles internally) so the
    // next notifyListeners() also throttles when the list goes empty.
    trail.tick(nowMs);
    final List<({Offset position, double alpha, double radius, int color})>
        snapshot = trail.snapshotFor(nowMs);
    if (snapshot.isEmpty) return;
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (final ({Offset position, double alpha, double radius, int color}) p
        in snapshot) {
      paint.color = Color(p.color).withValues(alpha: p.alpha);
      canvas.drawCircle(p.position, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleTrailPainter old) => old.trail != trail;
}
