// =============================================================================
// Magic Colors · features/coloring/painting/brush_painter.dart
// =============================================================================
//
// M2.1 — Single source of truth for "given a Canvas + a DrawingStroke,
// paint one brush stroke". Used by:
//   • The custom painter in `widgets/coloring_canvas.dart` (one stroke
//     per call when rendering the in-progress active stroke).
//   • `StrokePictureCache` (records the brush op bundle into a ui.Picture
//     for later O(1) re-raster).
//
// By factoring the brush dispatch into one helper we eliminate the
// duplicated code-paths that the M0 canvas painter vs the picture
// cache would otherwise duplicate 5×.
//
// PAINTING CONTRACT
//   • Caller is responsible for setting up the canvas (translation,
//     clip, bounds). The helper paints at the stroke's natural coords.
//   • Caller chooses `reduceMotion` from SettingsState.
//   • Eraser uses BlendMode.clear; expects the canvas to have a
//     non-transparent surface beneath so the clear reveals the
//     background.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Path;

import 'package:flutter/painting.dart' show
    BlendMode,
    Color,
    Paint,
    PaintingStyle,
    StrokeCap,
    StrokeJoin;

import 'package:magic_colors/core/utils/logger.dart';

import '../domain/drawing_stroke.dart';
import '../domain/enums.dart';


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
}


/// Brush-paint utility. Naming uses `class` not `abstract final class`
/// because callers need instance methods on a Canvas instance — the
/// stateless-helper pattern doesn't compose well when the static call
/// chain mixes with class-instance fields.
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
    }
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

    // Off-axis jittered pass — adds grain without using ImageShader.
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

/// Bridge from the brush to the live canvas painter. Exposed as a
/// top-level for symmetry with the existing `drawPath` API.
Path pathFrom(List<double> flat) {
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

/// Strips a [DrawingStroke] to its tight bounding box. Padding in
/// logical px ensures stroke-cap + sparkle stamp + bleed pass do not
/// clip the picture bounds. Returned as a record so callers can use
/// `b.minX`, `b.maxY` ergonomically.
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
