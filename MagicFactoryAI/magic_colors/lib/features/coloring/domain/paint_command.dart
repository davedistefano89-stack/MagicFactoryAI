// =============================================================================
// Magic Colors · features/coloring/domain/paint_command.dart
// =============================================================================
//
// M2.2 — Sealed union over every paintable command. The drawing model
// previously kept a parallel `strokes: List<DrawingStroke>` plus would
// have needed a parallel `fills: List<FillRegion>` — undo/redo semantics
// would shatter. Instead we unify the redo stack under a single
// [PaintCommand] sealed hierarchy: one command == one undoable entry.
//
// WHY A SEALED HIERARCHY (not parallel lists)
//   • Undo/Redo stack becomes a homogeneous `List<PaintCommand>`
//     rather than two parallel `List<DrawingStroke>` + `List<FillRegion>`
//     stacks. Single entry-pop / entry-push.
//   • Pattern-matching across the union catches new command kinds at
//     compile time. Adding a M2.5 eraser-as-fill adds a new subclass
//     and every non-exhaustive switch becomes a hard error.
//   • The picture cache is now keyed by command.id across both kinds.
//
// HIVE SERIALISATION
//   Commands are persisted as `@HiveField 9` on [Drawing]. The list is
//   serialised as `[DrawStroke | FillRegion for c in commands]` via a
//   pending manual adapter (`coloring_adapters.dart`). Until that
//   adapter lands, hydrate-time forward-compat wraps legacy `strokes`
//   entries into `DrawStroke` instances on read.
// =============================================================================

import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart' show immutable;

import 'drawing_stroke.dart';


/// Sealed union over every command the user can commit to the canvas.
/// The painter dispatches on `kind` (or via pattern matching) to the
/// matching brush handler.
@immutable
sealed class PaintCommand {
  const PaintCommand();

  /// Stable uuid (also used by the picture cache as a key).
  String get id;

  /// Wall-clock at commit-time. Used by tests, undo-redo, and future
  /// analytics.
  DateTime get timestamp;

  /// ARGB packed int (Color.value). Painter reads this directly.
  int get colorValue;

  /// Tight bounds enclosing the command's visible footprint (in canvas
  /// coords). The picture cache translates by this anchor when
  /// stamping the pre-baked ui.Picture onto the live canvas.
  Rect get bounds;
}


/// A user-drawn stroke. Wraps the existing [DrawingStroke] verbatim — the
/// list of points and brush data is unchanged.
final class DrawStroke extends PaintCommand {
  const DrawStroke(this.stroke);

  final DrawingStroke stroke;

  @override
  String get id => stroke.id;

  @override
  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(
        stroke.timestampMs,
      );

  @override
  int get colorValue => stroke.colorValue;

  @override
  Rect get bounds => _boundsFromStroke(stroke);
}


/// A flood-fill region carved from a tap + scanline-BFS. Stores a
/// RGBA8888 bitmask (4 bytes/pixel) of the fill shape so the painter
/// can blit it directly without re-running the BFS.
final class FillRegion extends PaintCommand {
  const FillRegion({
    required this.id,
    required this.colorValue,
    required this.mask,
    required this.width,
    required this.height,
    required this.origin,
    required this.timestamp,
  });

  /// Stable uuid (also picture-cache key).
  @override
  final String id;

  /// ARGB packed int of the fill colour (matches the controller's
  /// selected swatch at commit-time).
  @override
  final int colorValue;

  /// RGBA8888 mask — 4 bytes per pixel. Byte order: R, G, B, A per
  /// pixel. A == 0 means "preserve underlying canvas"; A == 255 means
  /// "draw this colour here".
  final List<int> mask;

  /// Mask width in pixels (= `mask.length / 4 / height`).
  final int width;

  /// Mask height in pixels.
  final int height;

  /// Top-left corner of the mask in canvas-space (the painter
  /// translates by this anchor before drawing).
  final Offset origin;

  /// Wall-clock at commit-time.
  @override
  final DateTime timestamp;

  /// Total mask byte length. Equal to `width * height * 4`.
  int get byteLength => mask.length;

  @override
  Rect get bounds => Rect.fromLTWH(
        origin.dx,
        origin.dy,
        width.toDouble(),
        height.toDouble(),
      );

  /// Returns true when this region actually has at least one filled
  /// pixel (A == 255). A 0×0 region signals "the BFS visited nothing"
  /// and the controller refuses to commit it.
  bool get hasPixels {
    if (mask.isEmpty) {
      return false;
    }
    for (int i = 3; i < mask.length; i += 4) {
      if (mask[i] != 0) {
        return true;
      }
    }
    return false;
  }
}


/// Builds the tightest bounding Rect around a [DrawingStroke]'s
/// sampled points. Used as the cache key anchoring for DrawStroke
/// pictures. Padded by the stroke's brush size so caps/bleeds don't
/// clip the recording bounds.
Rect _boundsFromStroke(DrawingStroke stroke) {
  if (stroke.pointCount == 0) {
    return Rect.zero;
  }
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
    return Rect.zero;
  }
  final double pad = stroke.brushSize * 1.5 + 8.0;
  return Rect.fromLTRB(
    minX - pad,
    minY - pad,
    maxX + pad,
    maxY + pad,
  );
}
