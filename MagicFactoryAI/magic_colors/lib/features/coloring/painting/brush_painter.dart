// =============================================================================
// Magic Colors · features/coloring/painting/brush_painter.dart
// =============================================================================
//
// M2.2 PRODUCTION - Single source of truth for "given a Canvas + a
// PaintCommand OR a DrawingStroke, paint one brush stroke OR one fill
// region".
//
// M2.3 EXTENSION
//   - Pencil brush dispatch (_pencil) - thin dark line with a faint
//     noise overlay.
//   - FillRegion supports an optional GradientPair.
//
// M2.2 PRODUCTION NOTES
//   - The PRIMARY fill paint path lives in
//     widgets/coloring_canvas.dart / _paintFillRegionCached, which
//     replays cached `ui.Picture`s at O(1) per frame.
//   - `paintFillRegion` here is the FALLBACK path, used by tests and
//     any code path that doesn't have access to a pre-baked Picture.
//     It stamps one canvas.drawRect per FillSpan (in IMAGE coords,
//     after the standard translate+scale+dtranslate to land the
//     region correctly on the painter's logical canvas).
//
// Used by:
//   - widgets/coloring_canvas.dart (every PaintCommand in the redo stack
//     once per frame, plus the in-progress active stroke live).
//   - StrokePictureCache for committed commands (records the brush
//     ops into a ui.Picture for fast re-raster at any zoom).
//
// ============================================================================

import 'dart:math' as math;
import 'dart:ui' show Canvas, Gradient, Offset, Path, Rect;

import 'package:flutter/painting.dart'
    show BlendMode, Color, Paint, PaintingStyle, StrokeCap, StrokeJoin;

import '../domain/drawing_stroke.dart';
import '../domain/enums.dart';
import '../domain/gradient_pair.dart';
import '../domain/paint_command.dart';
import '../fill/scanline_filler.dart' show FillSpan;

/// Tuning constants for brush rendering. Public so tests can reference
/// them; centralised here so the picture baker and the live painter
/// stay byte-identical.
abstract final class BrushPaintConstants {
  const BrushPaintConstants._();

  /// Distance between sparkle stamps (px, on path).
  static const double sparkleStampSpacing = 12.0;

  /// Crayon jitter magnitude (px).
  static const double crayonJitterMagnitude = 1.4;

  /// Marker base alpha (0..1).
  static const double markerBaseAlpha = 0.65;

  /// Eraser hard-erase alpha (always 1 - BlendMode.clear paints 0).
  static const double eraserHardAlpha = 1.0;

  /// Crayon width is the user-set size x 0.85 so it reads as a soft
  /// drag rather than a bold line.
  static const double crayonWidthFactor = 0.85;

  /// M2.2 PRODUCTION - preview alpha for the on-pointer-down region
  /// highlight (a quick tint of the selected colour over the
  /// connected region).
  static const double fillPreviewAlpha = 0.30;

  /// M2.2 PRODUCTION - fully-committed fill region alpha at the end
  /// of its fade-in animation.
  static const double fillCommittedAlpha = 1.0;

  /// M2.3 - pencil jitter magnitude (px).
  static const double pencilJitterMagnitude = 0.65;

  /// M2.3 - second-pass faint seed alpha (multiplied onto a copy of
  /// the stroke).
  static const double pencilSeedAlpha = 0.3;
}

/// Brush-paint utility. Used as both the live painter and the
/// picture-baker's reference implementation.
class BrushPainter {
  const BrushPainter();

  /// Dispatches one stroke to the given canvas. Reads reduceMotion to
  /// honour the OS-level reduced-motion accessibility switch.
  void paint(
    Canvas canvas,
    DrawingStroke stroke, {
    required bool reduceMotion,
  }) {
    if (stroke.pointCount < 2) {
      return;
    }
    switch (stroke.brushType) {
      case BrushType.round:
        _round(canvas, stroke);
      case BrushType.marker:
        _marker(canvas, stroke);
      case BrushType.crayon:
        _crayon(canvas, stroke);
      case BrushType.sparkle:
        _sparkle(canvas, stroke, reduceMotion: reduceMotion);
      case BrushType.eraser:
        _eraser(canvas, stroke);
      case BrushType.fill:
        // M2.2 PRODUCTION - fill is a TAP tool dispatched via
        // [paintFillRegion] below. The painter routes FillRegion
        // through FillPictureCache; this method refuses to handle
        // fill via the stroke dispatcher so the type-system stays
        // honest.
        break;
      case BrushType.pencil:
        _pencil(canvas, stroke);
    }
  }

  /// M2.2 PRODUCTION - paints a FillRegion onto the canvas using the
  /// spans-aware FALLBACK path (no pre-baked Picture available).
  ///
  /// Coordinate transform (matches the cache's pre-bake convention):
  ///   1. translate(region.origin.dx, region.origin.dy)         // logical
  ///   2. scale(region.pixelRatio, region.pixelRatio)           // -> image
  ///   3. translate(-imageBounds.left, -imageBounds.top)        // -> spans
  /// Spans are then drawn in image coords (xStart, row == 1 px tall).
  ///
  /// M2.3 - accept an optional [gradient]; when isTwoStop, every
  /// stamped rect is filled with a ui.Gradient.linear shader mapped
  /// to the region bounds (now in IMAGE coords at this point).
  void paintFillRegion(
    Canvas canvas,
    FillRegion region, {
    required double alphaMultiplier,
    GradientPair? gradient,
  }) {
    if (region.spans.isEmpty || region.width <= 0 || region.height <= 0) {
      return;
    }
    final double alpha = alphaMultiplier.clamp(0.0, 1.0) *
        BrushPaintConstants.fillCommittedAlpha;
    final bool useGradient = gradient != null && gradient.isTwoStop;
    final Paint paint = _paintForFill(
      region: region,
      alpha: alpha,
      gradient: useGradient ? gradient : null,
    );
    canvas.save();
    canvas.translate(region.origin.dx, region.origin.dy);
    canvas.scale(region.pixelRatio, region.pixelRatio);
    canvas.translate(-region.imageBounds.left, -region.imageBounds.top);
    if (useGradient) {
      _drawSpansShader(canvas, region, paint);
    } else {
      _drawSpans(canvas, region, paint);
    }
    canvas.restore();
  }

  /// Dispatches a PaintCommand to the matching brush. The active
  /// stroke path uses [paint]; the FillRegion path uses
  /// [paintFillRegion]. The [alphaMultiplier] only applies to the
  /// latter - strokes paint at full opacity.
  void paintCommand(
    Canvas canvas,
    PaintCommand command, {
    required bool reduceMotion,
    required double alphaMultiplier,
    GradientPair? gradient,
  }) {
    switch (command) {
      case final DrawStroke drawStroke:
        paint(canvas, drawStroke.stroke, reduceMotion: reduceMotion);
      case final FillRegion fillRegion:
        paintFillRegion(
          canvas,
          fillRegion,
          alphaMultiplier: alphaMultiplier,
          gradient: gradient,
        );
    }
  }

  // ── Spans-aware fill helpers (FALLBACK) ───────────────────────────

  Paint _paintForFill({
    required FillRegion region,
    required double alpha,
    GradientPair? gradient,
  }) {
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;
    if (gradient != null) {
      // Bounding rect is in IMAGE coords at this point (canvas was
      // translated+scale+dtranslate before this method is called).
      final Rect bounds = Rect.fromLTWH(
        0,
        0,
        region.imageBounds.width,
        region.imageBounds.height,
      );
      paint.shader = Gradient.linear(
        Offset(bounds.left, bounds.top),
        Offset(bounds.left, bounds.bottom),
        <Color>[
          Color(gradient.topColorValue).withValues(alpha: alpha),
          Color(gradient.bottomColorValue).withValues(alpha: alpha),
        ],
        <double>[0.0, 1.0],
      );
    } else {
      paint.color = Color(region.colorValue).withValues(alpha: alpha);
    }
    return paint;
  }

  void _drawSpans(Canvas canvas, FillRegion region, Paint paint) {
    for (final FillSpan span in region.spans) {
      canvas.drawRect(
        Rect.fromLTRB(
          span.xStart.toDouble(),
          span.row.toDouble(),
          (span.xEndInclusive + 1).toDouble(),
          (span.row + 1).toDouble(),
        ),
        paint,
      );
    }
  }

  void _drawSpansShader(
    Canvas canvas,
    FillRegion region,
    Paint paint,
  ) {
    // M2.3 - identical loop to [_drawSpans]; the gradient shader on
    // [paint] handles per-row shading automatically.
    _drawSpans(canvas, region, paint);
  }

  // ── Brush: ROUND ────────────────────────────────────────────────────
  void _round(Canvas canvas, DrawingStroke stroke) {
    final Path path = _pathFrom(stroke.points);
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(stroke.colorValue)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.brushSize
        ..isAntiAlias = true,
    );
  }

  // ── Brush: MARKER ───────────────────────────────────────────────────
  void _marker(Canvas canvas, DrawingStroke stroke) {
    final Path path = _pathFrom(stroke.points);
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(stroke.colorValue).withValues(
          alpha: BrushPaintConstants.markerBaseAlpha,
        )
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..strokeWidth = stroke.brushSize
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(stroke.colorValue).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter
        ..strokeWidth = stroke.brushSize * 1.35
        ..isAntiAlias = true,
    );
  }

  // ── Brush: CRAYON ───────────────────────────────────────────────────
  void _crayon(Canvas canvas, DrawingStroke stroke) {
    final math.Random rng = math.Random(stroke.textureSeed);
    final Paint base = Paint()
      ..color = Color(stroke.colorValue)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.brushSize * BrushPaintConstants.crayonWidthFactor
      ..isAntiAlias = true;
    canvas.drawPath(_pathFrom(stroke.points), base);

    final List<double> jittered = <double>[];
    for (int i = 0; i < stroke.pointCount; i++) {
      final (double dx, double dy) = stroke.pointAt(i);
      final double jx =
          (rng.nextDouble() - 0.5) * BrushPaintConstants.crayonJitterMagnitude;
      final double jy =
          (rng.nextDouble() - 0.5) * BrushPaintConstants.crayonJitterMagnitude;
      jittered.add(dx + jx);
      jittered.add(dy + jy);
    }
    canvas.drawPath(_pathFrom(jittered), base);
  }

  // ── Brush: SPARKLE ──────────────────────────────────────────────────
  void _sparkle(
    Canvas canvas,
    DrawingStroke stroke, {
    required bool reduceMotion,
  }) {
    if (stroke.pointCount < 1) {
      return;
    }
    final Color tint = Color(stroke.colorValue);
    const Color highlight = Color(0xFFFFF6C7);
    final double spacing = reduceMotion
        ? BrushPaintConstants.sparkleStampSpacing * 2.0
        : BrushPaintConstants.sparkleStampSpacing;

    final (double x0, double y0) = stroke.pointAt(0);
    _sparkleStamp(canvas, Offset(x0, y0), tint, highlight, stroke.brushSize);

    double cursorX = x0;
    double cursorY = y0;
    for (int i = 1; i < stroke.pointCount; i++) {
      final (double px, double py) = stroke.pointAt(i);
      final double dx = px - cursorX;
      final double dy = py - cursorY;
      final double dist = math.sqrt(dx * dx + dy * dy);
      if (dist >= spacing) {
        _sparkleStamp(
          canvas,
          Offset(px, py),
          tint,
          highlight,
          stroke.brushSize,
        );
        cursorX = px;
        cursorY = py;
      }
    }
  }

  void _sparkleStamp(
    Canvas canvas,
    Offset at,
    Color tint,
    Color highlight,
    double brushSize,
  ) {
    final double r = brushSize * 0.42;
    canvas.drawCircle(
      at,
      r,
      Paint()..color = tint.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      at.translate(-r * 0.25, -r * 0.25),
      r * 0.35,
      Paint()..color = highlight.withValues(alpha: 0.95),
    );
  }

  // ── Brush: ERASER ───────────────────────────────────────────────────
  void _eraser(Canvas canvas, DrawingStroke stroke) {
    canvas.drawPath(
      _pathFrom(stroke.points),
      Paint()
        ..blendMode = BlendMode.clear
        ..color = const Color(0xFFFFFFFF)
            .withValues(alpha: BrushPaintConstants.eraserHardAlpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.brushSize,
    );
  }

  // ── Brush: PENCIL (M2.3) ───────────────────────────────────────────
  void _pencil(Canvas canvas, DrawingStroke stroke) {
    final math.Random rng = math.Random(stroke.textureSeed);
    final Path jagged = Path();
    final List<double> jittered = <double>[];
    for (int i = 0; i < stroke.pointCount; i++) {
      final (double dx, double dy) = stroke.pointAt(i);
      final double jx =
          (rng.nextDouble() - 0.5) * BrushPaintConstants.pencilJitterMagnitude;
      final double jy =
          (rng.nextDouble() - 0.5) * BrushPaintConstants.pencilJitterMagnitude;
      jittered.add(dx + jx);
      jittered.add(dy + jy);
    }
    final Path path = _pathFrom(stroke.points);
    jagged.addPath(path, Offset.zero);
    canvas.drawPath(
      jagged,
      Paint()
        ..color = Color(stroke.colorValue)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.brushSize * 0.5
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      _pathFrom(jittered),
      Paint()
        ..color = Color(stroke.colorValue)
            .withValues(alpha: BrushPaintConstants.pencilSeedAlpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.brushSize * 0.7
        ..isAntiAlias = true,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  Path _pathFrom(List<double> flat) {
    final Path out = Path();
    if (flat.length < 4) {
      return out;
    }
    out.moveTo(flat[0], flat[1]);
    for (int i = 2; i + 1 < flat.length; i += 2) {
      out.lineTo(flat[i], flat[i + 1]);
    }
    return out;
  }
}

/// Top-level helper kept for parity with brush extraction. Strips a
/// DrawingStroke to its tight bounding box. Padding in logical px
/// ensures stroke-cap + sparkle stamp + bleed pass do not clip
/// the picture bounds.
({
  double minX,
  double minY,
  double maxX,
  double maxY,
}) strokeBounds(DrawingStroke stroke, {double padding = 16.0}) {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = -double.infinity;
  double maxY = -double.infinity;
  for (int i = 0; i < stroke.pointCount; i++) {
    final (double dx, double dy) = stroke.pointAt(i);
    if (dx < minX) minX = dx;
    if (dy < minY) minY = dy;
    if (dx > maxX) maxX = dx;
    if (dy > maxY) maxY = dy;
  }
  if (minX.isInfinite) {
    minX = 0.0;
    minY = 0.0;
    maxX = 0.0;
    maxY = 0.0;
  }
  final double pad = stroke.brushSize + padding;
  return (
    minX: minX - pad,
    minY: minY - pad,
    maxX: maxX + pad,
    maxY: maxY + pad,
  );
}
