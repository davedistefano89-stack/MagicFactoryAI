// =============================================================================
// Magic Colors · features/coloring/painting/stroke_picture_cache.dart
// =============================================================================
//
// M2.1 — Pre-bake committed DrawingStrokes into [ui.Picture] objects
// keyed by stroke.id. The custom painter draws each stroke via
// `canvas.drawPicture(p)` instead of rebuilding the path geometry on
// every frame. This drops per-frame repaint cost from O(L*N) to O(N)
// once the stroke count exceeds the per-stroke pre-bake overhead.
//
// WHY PRE-BAKE
//   A 4-year-old can paint a 200-stroke drawing in 90 seconds. The M0
//   painter rewrote all paths on every PointerEvent tick — average
//   per-frame cost ~ 30 ms at N=200 → 33 fps, half of the 60 fps
//   target. Pre-baking each commit is O(L) once; subsequent redraws
//   are O(1) per stroke via the cached [ui.Picture].
//
// WHICH STROKES ARE BAKED
//   Committed strokes only. The in-progress active stroke paints live
//   (its geometry finalises at panUp, so a Picture would be a wasted
//   allocation on every PointerMove).
//
// INVALIDATION
//   • drop(strokeId) — one entry, called on undo when a stroke is
//     pushed to the redo stack. The popped stroke is not redrawn;
//     its picture is released.
//   • clear() — all entries + each Picture disposed. Called on
//     `clearCanvas()` and on brush color/size/type change (a stroke
//     pre-baked with one colour appears wrong if the user swaps
//     without re-baking).
// =============================================================================

import 'dart:ui' show Canvas, Picture, PictureRecorder, Rect;

import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:magic_colors/core/utils/logger.dart';

import '../domain/drawing_stroke.dart';
import 'brush_painter.dart';

/// Caches [Picture] recordings keyed by stroke.id. Bound is the live
/// stroke count. Disposing the cache releases every cached Picture.
final class StrokePictureCache {
  final Map<String, Picture> _pictures = <String, Picture>{};
  final BrushPainter _brush = const BrushPainter();

  /// Cached count. Useful for assertion in tests.
  int get size => _pictures.length;

  /// Lifts the cached picture by id. Returns null on miss; the painter
  /// should re-bake before drawing in that case.
  Picture? operator [](String strokeId) => _pictures[strokeId];

  /// Returns the cached picture for [stroke], baking on miss. Idempotent
  /// — repeated calls with the same stroke are O(1).
  Picture getOrBake(DrawingStroke stroke, {bool reduceMotion = false}) {
    final cached = _pictures[stroke.id];
    if (cached != null) {
      return cached;
    }
    return _bake(stroke, reduceMotion);
  }

  Picture _bake(DrawingStroke stroke, bool reduceMotion) {
    final bounds4 = strokeBounds(stroke);
    final Rect bounds = Rect.fromLTRB(
      bounds4.minX,
      bounds4.minY,
      bounds4.maxX,
      bounds4.maxY,
    );
    final recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder, bounds);
    // Bake the stroke as if the recorder originated at (0, 0). The
    // painter translates by bounds.minX/minY at draw-time to anchor
    // the picture at its world coords.
    canvas.translate(-bounds4.minX, -bounds4.minY);
    _brush.paint(canvas, stroke, reduceMotion: reduceMotion);
    final Picture pic = recorder.endRecording();
    _pictures[stroke.id] = pic;
    if (kDebugMode) {
      logger.debug(
        'StrokePictureCache._bake stroke=${stroke.id} '
        'points=${stroke.pointCount} bounds=$bounds',
      );
    }
    return pic;
  }

  /// Drops a single entry. Safe to call for an unknown id (no-op).
  void drop(String strokeId) {
    final pic = _pictures.remove(strokeId);
    if (pic != null) {
      try {
        pic.dispose();
      } on Object catch (error, stack) {
        logger.error(
          'StrokePictureCache.dispose failed stroke=$strokeId',
          error: error,
          stackTrace: stack,
        );
      }
    }
  }

  /// Drops every cached picture. Called when the entire stroke list
  /// has been wiped (clearCanvas) or when the brush rendering
  /// parameters have changed (color/size/type) — the cached Pictures
  /// would render stale.
  void clear() {
    for (final entry in _pictures.entries) {
      try {
        entry.value.dispose();
      } on Object catch (error, stack) {
        logger.error(
          'StrokePictureCache.dispose failed stroke=${entry.key}',
          error: error,
          stackTrace: stack,
        );
      }
    }
    _pictures.clear();
  }
}
