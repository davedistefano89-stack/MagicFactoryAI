// =============================================================================
// Magic Colors · features/coloring/painting/brush_painter.dart
// =============================================================================
//
// M2.2 — Single source of truth for "given a Canvas + a PaintCommand
// OR a DrawingStroke, paint one brush stroke OR one fill region".
//
// Used by:
//   • The custom painter in `widgets/coloring_canvas.dart` (renders
//     every PaintCommand in the redo stack once per frame, plus the
//     in-progress active stroke live).
//   • `StrokePictureCache` for committed commands (records the brush
//     ops into a ui.Picture for fast re-raster at any zoom).
//
// M2.2 EXTENSION
//   The new `FillRegion` command paints a row-by-row traced mask
//   directly onto the canvas. The alpha multiplier lets the painter
//   fade-in newly-committed regions via the [FillAnimator].
//
// PAINTING CONTRACT
//   • Caller sets up the canvas (translation, clip, bounds).
//   • Caller chooses `reduceMotion` from SettingsState.
//   • For DrawStroke commands the active dispatch returns the same
//     result for matching brushes as M2.1.
//   • For FillRegion commands rows of opaque (A==255) mask pixels
//     become a filled RowRect at the region's origin. M2.4 polish
//     can swap to a single decoded-image blit.
// =============================================================================

import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Canvas, Offset, Path, Rect;

import 'package:flutter/painting.dart' show
    BlendMode,
    Color,
    Paint,
    PaintingStyle,
    StrokeCap,
    StrokeJoin;

import '../domain/drawing_stroke.dart';
import '../domain/enums.dart';
import '../domain/paint_command.dart';


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

  /// Eraser hard-erase alpha (always 1 — BlendMode.clear paints 0).
  static const double eraserHardAlpha = 1.0;

  /// Crayon width is the user-set size × 0.85 so it reads as a soft
  /// drag rather than a bold line.
  static const double crayonWidthFactor = 0.85;

  /// M2.2 — preview alpha for the on-pointer-down region highlight
  /// (a quick tint of the selected colour over the connected region).
  static const double fillPreviewAlpha = 0.30;

  /// M2.2 — fully-committed fill region alpha at the end of its
  /// fade-in animation.
  static const double fillCommittedAlpha = 1.0;
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
        // M2.2 — fill is a TAP tool dispatched via
        // [paintFillRegion] below. Refusing to paint it via the
        // stroke dispatcher keeps the type-system honest: the
        // canvas state machine routes taps (not drags) through
        // paintFillRegion directly.
        break;
    }
  }

  /// M2.2 — paints a [FillRegion] onto the canvas by tracing the
  /// mask row-by-row and stamping horizontal rects for each visited
  /// run. [alphaMultiplier] lets the caller fade-in: pass `progress`
  /// from the FillAnimator (0..1).
  void paintFillRegion(
    Canvas canvas,
    FillRegion region, {
    required double alphaMultiplier,
  }) {
    if (region.mask.isEmpty || region.width <= 0 || region.height <= 0) {
      return;
    }
    final double alpha = alphaMultiplier.clamp(0.0, 1.0) *
        BrushPaintConstants.fillCommittedAlpha;
    final Paint paint = Paint()
      ..color = Color(region.colorValue).withValues(alpha: alpha)
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;
    canvas.save();
    canvas.translate(region.origin.dx, region.origin.dy);
    _drawMaskRuns(canvas, region, paint);
    canvas.restore();
  }

  /// Dispatches a [PaintCommand] to the matching brush. The active
  /// stroke path uses [paint]; the FillRegion path uses
  /// [paintFillRegion]. The [alphaMultiplier] only applies to the
  /// latter — strokes paint at full opacity.
  void paintCommand(
    Canvas canvas,
    PaintCommand command, {
    required bool reduceMotion,
    required double alphaMultiplier,
  }) {
    switch (command) {
      case final DrawStroke drawStroke:
        paint(canvas, drawStroke.stroke, reduceMotion: reduceMotion);
      case final FillRegion fillRegion:
        paintFillRegion(
          canvas,
          fillRegion,
          alphaMultiplier: alphaMultiplier,
        );
    }
  }


  // ── Helpers: row-by-row mask run stamping ──────────────────────────────

  void _drawMaskRuns(Canvas canvas, FillRegion region, Paint paint) {
    // Walk every row. For each row, compute the contiguous run of
    // visited pixels and stamp a horizontal rect. This is O(area)
    // and yields at most empty rects (skipped), so total ops = sum
    // of run counts across all rows. For a typical fill (< 30 %
    // area) the cost is well under 1 ms on a phone.
    final Uint8List visited = _visitedFromMask(region);
    for (int y = 0; y < region.height; y++) {
      int runStart = -1;
      for (int x = 0; x < region.width; x++) {
        final int idx = y * region.width + x;
        final int visitedByte = visited[idx];
        if (visitedByte != 0) {
          if (runStart < 0) runStart = x;
        } else if (runStart >= 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              runStart.toDouble(),
              y.toDouble(),
              (x - runStart).toDouble(),
              1.0,
            ),
            paint,
          );
          runStart = -1;
        }
      }
      if (runStart >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            runStart.toDouble(),
            y.toDouble(),
            (region.width - runStart).toDouble(),
            1.0,
          ),
          paint,
        );
      }
    }
  }

  /// Decodes the alpha channel of an RGBA8888 mask into a Uint8List
  /// for run-stamping. Returns `region.mask` as-is if the runner was
  /// already a Uint8List-backed structure (test expectation).
  Uint8List _visitedFromMask(FillRegion region) {
    final int size = region.mask.length ~/ 4;
    final Uint8List out = Uint8List(size);
    for (int i = 0; i < size; i++) {
      out[i] = region.mask[i * 4 + 3];
    }
    return out;
  }


  // ── Brush: ROUND ──────────────────────────────────────────────────────
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

  // ── Brush: MARKER ─────────────────────────────────────────────────────
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

  // ── Brush: CRAYON ─────────────────────────────────────────────────────
  void _crayon(Canvas canvas, DrawingStroke stroke) {
    final math.Random rng = math.Random(stroke.textureSeed);
    final Paint base = Paint()
      ..color = Color(stroke.colorValue)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth =
          stroke.brushSize * BrushPaintConstants.crayonWidthFactor
      ..isAntiAlias = true;
    canvas.drawPath(_pathFrom(stroke.points), base);

    final List<double> jittered = <double>[];
    for (int i = 0; i < stroke.pointCount; i++) {
      final (double dx, double dy) = stroke.pointAt(i);
      final double jx = (rng.nextDouble() - 0.5) *
          BrushPaintConstants.crayonJitterMagnitude;
      final double jy = (rng.nextDouble() - 0.5) *
          BrushPaintConstants.crayonJitterMagnitude;
      jittered.add(dx + jx);
      jittered.add(dy + jy);
    }
    canvas.drawPath(_pathFrom(jittered), base);
  }

  // ── Brush: SPARKLE ────────────────────────────────────────────────────
  void _sparkle(
    Canvas canvas,
    DrawingStroke stroke, {
    required bool reduceMotion,
  }) {
    if (stroke.pointCount < 1) {
      return;
    }
    final Color tint = Color(stroke.colorValue);
    final Color highlight = const Color(0xFFFFF6C7);
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

  // ── Brush: ERASER ─────────────────────────────────────────────────────
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
/// [DrawingStroke] to its tight bounding box. Padding in logical px
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

