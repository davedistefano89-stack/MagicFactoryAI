// =============================================================================
// Magic Colors · features/coloring/widgets/coloring_canvas.dart
// =============================================================================
//
// M2.1 — Interactive painting surface with pinch zoom + 2-finger pan.
//
// PAINTER DATA FLOW
// -----------------
//   • `Transform` (parent)           — applies the ViewTransform matrix
//                                       (scale + translation). Matrix
//                                       changes trigger a parent rebuild,
//                                       not a Canvas repaint, so the
//                                       RepaintBoundary still isolates
//                                       the painting layer.
//   • `RepaintBoundary`              — isolates 60 fps stroke repaint
//                                       from outer chrome rebuilds.
//   • `Listener` (raw PointerEvents) — accepts every pointer down/move/
//                                       up/cancel. Routes to either the
//                                       paint path (single finger) or the
//                                       view transform path (two fingers).
//   • `CustomPaint` (CustomPainter)  — paints committed strokes from
//                                       the picture cache + the
//                                       in-progress active stroke (live
//                                       path with quadratic midpoint
//                                       smoothing).
//
// POINTER ROUTING (state machine)
//   • idle      — no fingers down. New pointerDown → paint mode.
//   • painting  — exactly one pointer is the "paint pointer". Second
//                 pointer commits the active stroke cleanly, then
//                 transitions to pinching.
//   • pinching  — two fingers. Pointer 3+ is ignored. When the count
//                 drops below 2, return to idle. The remaining
//                 finger does NOT auto-resume painting — the user
//                 must lift all and start fresh (cleaner mental model
//                 for a 4-year-old than a sticky-finger restart).
//
// PAINT COORDINATES
//   The Listener is INSIDE the Transform. So `event.localPosition`
//   is post-transform (canvas coords — what the controller expects).
//   `event.position` is global screen coords (pre-Transform); pinch
//   math uses screen coords so scaling "around the focal" stays
//   intuitive even under heavy zoom.
// =============================================================================

import 'dart:ui' show Offset, Picture;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:magic_colors/core/state/settings_state.dart';
import 'package:magic_colors/core/utils/logger.dart';
import 'package:magic_colors/features/coloring/coloring_controller.dart';
import 'package:magic_colors/features/coloring/domain/drawing_stroke.dart';
import 'package:magic_colors/features/coloring/painting/brush_painter.dart';
import 'package:magic_colors/features/coloring/painting/stroke_picture_cache.dart';
import 'package:magic_colors/features/coloring/painting/stroke_smoother.dart';
import 'package:magic_colors/features/coloring/state/view_transform_controller.dart';


// ── Tuning constants ────────────────────────────────────────────────────

/// Faint background emoji alpha (template glyph).
const double _kTemplateGlyphAlpha = 0.10;

/// Template glyph size cap as a fraction of the canvas's smaller side.
const double _kTemplateGlyphCapFraction = 0.55;


// ── Pointer state-machine enum ──────────────────────────────────────────

/// One of three modes the canvas can be in.
enum _GestureMode { idle, painting, pinching }


// =============================================================================
//  ColoringCanvas — interactive surface.
// =============================================================================

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
  /// All pointer IDs currently down.
  final Set<int> _activePointers = <int>{};
  // ignore: prefer_collection_declarations, library_private_types_in_public_api
  final Map<int, Offset> _pointerPositions = <int, Offset>{};

  /// The single pointer currently authoring a stroke. Non-null only
  /// in `_GestureMode.painting`.
  int? _paintPointer;

  /// Current pinching state. Last-known centroid + initial pinch
  /// distance captured at the first 2-finger move event so scale
  /// factor = `current / initial` reads as the user's gesture ratio.
  Offset? _pinchLastCentroid;
  double? _pinchLastDistance;

  _GestureMode _mode = _GestureMode.idle;

  @override
  void dispose() {
    logger.debug('ColoringCanvas.dispose');
    super.dispose();
  }


  // ── Pointer handlers ──────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
    _activePointers.add(event.pointer);

    if (_mode == _GestureMode.idle && _activePointers.length == 1) {
      // First finger. Begin a paint stroke.
      _mode = _GestureMode.painting;
      _paintPointer = event.pointer;
      widget.controller.beginStroke(event.localPosition);
      return;
    }

    if (_mode == _GestureMode.painting && _activePointers.length == 2) {
      // Second finger landed mid-paint. Commit the in-flight stroke
      // cleanly (push to _strokes, clear redo) and start pinching.
      widget.controller.endStroke();
      _paintPointer = null;
      _mode = _GestureMode.pinching;
      _capturePinchBaseline();
      return;
    }

    // 3+ fingers, OR pinch-mid-flight arrival → ignored.
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointerPositions[event.pointer] = event.position;

    if (_mode == _GestureMode.painting &&
        event.pointer == _paintPointer) {
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

    if (_mode == _GestureMode.painting &&
        event.pointer == _paintPointer) {
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

    if (_mode == _GestureMode.painting &&
        event.pointer == _paintPointer) {
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


  // ── Pinch math ────────────────────────────────────────────────────────

  /// Captures the first frame of a pinch gesture. Reads the two
  /// current pointer positions and remembers their centroid + spread.
  void _capturePinchBaseline() {
    if (_activePointers.length < 2) {
      return;
    }
    final List<Offset> ps = _activePointers
        .map((int id) => _pointerPositions[id])
        .whereType<Offset>()
        .toList();
    if (ps.length < 2) {
      return;
    }
    _pinchLastCentroid = (ps[0] + ps[1]) / 2.0;
    _pinchLastDistance = (ps[1] - ps[0]).distance;
  }

  /// Reads the current centroid + spread, calls into the view-transform
  /// controller for scale + pan. Updates `_pinchLastCentroid` /
  /// `_pinchLastDistance` so subsequent moves produce *delta-based*
  /// scale ratios.
  void _applyPinch() {
    final List<Offset> ps = _activePointers
        .map((int id) => _pointerPositions[id])
        .whereType<Offset>()
        .toList();
    if (ps.length < 2) {
      return;
    }
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


  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final SettingsState settings = context.watch<SettingsState>();
    final ColoringController controller = widget.controller;
    final ViewTransformController view = context.watch<ViewTransformController>();
    // Ensure the canvas size is current. setCanvasSize re-clamps
    // translation on LayoutBuilder fires; here we feed it the post-
    // Layout viewport.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size canvasSize = constraints.biggest;
        // Re-entrancy safe: setCanvasSize skips notify when unchanged.
        view.setCanvasSize(canvasSize);
        return Transform(
          transform: view.matrix,
          child: RepaintBoundary(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: CustomPaint(
                painter: _M21CanvasPainter(
                  strokes: controller.strokes,
                  pictureCache: controller.pictureCache,
                  activeStrokeListenable: controller.activeStrokeListenable,
                  templateGlyph: controller.drawing.templateGlyph,
                  reduceMotion: settings.reduceMotion,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }
}


// =============================================================================
//  _M21CanvasPainter — paint logic.
//  Committed strokes draw from pre-baked Pictures; the in-progress one
//  draws live with quadratic midpoint smoothing.
// =============================================================================

class _M21CanvasPainter extends CustomPainter {
  _M21CanvasPainter({
    required this.strokes,
    required this.pictureCache,
    required this.activeStrokeListenable,
    required this.templateGlyph,
    required this.reduceMotion,
  }) : super(repaint: activeStrokeListenable);

  final List<DrawingStroke> strokes;
  final StrokePictureCache pictureCache;
  final ValueListenable<DrawingStroke?> activeStrokeListenable;
  final String templateGlyph;
  final bool reduceMotion;

  static const BrushPainter _brush = BrushPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Layer 1 — template glyph (faint background).
    if (templateGlyph.isNotEmpty) {
      _paintTemplate(canvas, size, templateGlyph);
    }

    // Layer 2 — committed strokes from pre-baked Pictures.
    for (final DrawingStroke s in strokes) {
      final Picture pic = pictureCache.getOrBake(
        s,
        reduceMotion: reduceMotion,
      );
      _stampPictureAtStrokeCoords(s, pic, canvas);
    }

    // Layer 3 — in-progress active stroke with smoothing.
    final DrawingStroke? active = activeStrokeListenable.value;
    if (active != null && active.pointCount >= 2) {
      _paintActiveSmoothed(active, canvas);
    }
  }

  @override
  bool shouldRepaint(covariant _M21CanvasPainter old) {
    return old.strokes != strokes ||
        old.templateGlyph != templateGlyph ||
        old.reduceMotion != reduceMotion;
  }


  // ── Layer helpers ─────────────────────────────────────────────────────

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

  /// Plays back the stroke's pre-baked Picture at its world coords.
  /// The bake was performed against the stroke's tight bounds — we
  /// translate to that origin before drawing.
  void _stampPictureAtStrokeCoords(
    DrawingStroke s,
    Picture pic,
    Canvas canvas,
  ) {
    final b = strokeBounds(s);
    canvas.save();
    canvas.translate(b.minX, b.minY);
    canvas.drawPicture(pic);
    canvas.restore();
  }

  /// Active stroke is painted live (its geometry evolves on every
  /// PointerMove). Apply quadratic midpoint smoothing in-place by
  /// materialising a synthetic DrawingStroke with the smoothed points,
  /// then route through the shared BrushPainter. The remaining
  /// DrawingStroke fields (id, colorValue, brushSize, brushTypeIndex,
  /// textureSeed, timestampMs) are preserved verbatim.
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
