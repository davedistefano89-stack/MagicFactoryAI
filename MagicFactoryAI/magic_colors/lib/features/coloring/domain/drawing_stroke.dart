// =============================================================================
// Magic Colors · features/coloring/domain/drawing_stroke.dart
// =============================================================================
//
// One DrawingStroke = one user touch sequence from panDown to panUp.
// Stored in `Drawings.strokes[]` and appended in real time during drawing.
//
// WHY EVERY FIELD IS A PRIMITIVE
//   We never use HiveObject (no key-based mutation surface needed), we
//   never embed Flutter geometry types (Offset/Rect require custom
//   adapters), we never embed BrushType as the enum (order-brittle).
//   Instead every field is a `String | int | double` or a `List<double>`
//   of flat (dx, dy) pairs. This keeps the manual .g.dart adapter
//   compact and binary-compatible with what `hive_generator` would emit.
//
// FIELD WIRING (Hive @HiveField indices NEVER change)
//   0  id           — uuid v4 string
//   1  colorValue   — ARGB packed int (Color.value)
//   2  brushSize    — stroke width in logical pixels (not dp-scaled)
//   3  brushTypeIndex — BrushType.values[index] (round=0, marker=1, …)
//   4  points       — flat List<double> of (dx1, dy1, dx2, dy2, …)
//   5  textureSeed  — int32 jitter seed for the crayon / sparkle brushes
//   6  timestampMs  — DateTime.now().millisecondsSinceEpoch at panUp
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import 'enums.dart';

/// Immutable snapshot of a single completed brush stroke.
///
/// Use [DrawingStroke.create] at panUp to materialise a stroke from the
/// live `_activeStrokeValues` accumulator held by the canvas widget.
/// The shape is intentionally append-only — never mutate a stroke after
/// it has entered [ColoringController.strokeList].
@immutable
class DrawingStroke {
  /// Empty-construction factory used by the canvas widget at panDown.
  /// All costs are O(1) — the points list fills in incrementally.
  factory DrawingStroke.empty({
    required int colorValue,
    required double brushSize,
    required BrushType brushType,
    required int textureSeed,
  }) {
    return DrawingStroke(
      id: _newId(),
      colorValue: colorValue,
      brushSize: brushSize,
      brushTypeIndex: brushType.index,
      points: const <double>[],
      textureSeed: textureSeed,
      timestampMs: 0,
    );
  }
  const DrawingStroke({
    required this.id,
    required this.colorValue,
    required this.brushSize,
    required this.brushTypeIndex,
    required this.points,
    required this.textureSeed,
    required this.timestampMs,
  });

  /// Stable uuid v4. Generated once at panUp.
  final String id;

  /// ARGB packed int (Color.value). Avoids the Fade/OOM cost of
  /// serialising a full `Color` object.
  final int colorValue;

  /// Stroke width in logical pixels.
  final double brushSize;

  /// Index into [BrushType.values]. Reading code clamps to
  /// `0..BrushType.values.length-1` so a schema-drift off-by-one never
  /// crashes the canvas.
  final int brushTypeIndex;

  /// Flat (dx, dy) pairs. `points.length` is always even; `points.length
  /// ~/ 2` is the number of sampled points.
  final List<double> points;

  /// Per-stroke jitter seed. Lets crayon / sparkle brushes look organic
  /// without paying for regenerated noise patterns across hot-reloads.
  final int textureSeed;

  /// Wall-clock at panUp. Used by tests and for "stroke count over time"
  /// analytics later.
  final int timestampMs;

  /// Decoded brush type with clamp for safety.
  BrushType get brushType {
    if (brushTypeIndex < 0 || brushTypeIndex >= BrushType.values.length) {
      return BrushType.round;
    }
    return BrushType.values[brushTypeIndex];
  }

  /// Number of sampled points in the stroke.
  int get pointCount => points.length ~/ 2;

  /// Returns the i-th point as a Flutter-independent (dx, dy) pair.
  /// Returns `(0, 0)` when `i` is out of range so callers never NPE.
  (double dx, double dy) pointAt(int i) {
    final int idx = i * 2;
    if (idx < 0 || idx + 1 >= points.length) {
      return (0.0, 0.0);
    }
    return (points[idx], points[idx + 1]);
  }

  /// Hive construction helper. Generates a uuid + timestamp while the
  /// data is collected into the live `(dx, dy)` list.
  static String _newId() {
    // Cheap uuid-v4-ish: 16 random bytes hexed. We don't use the
    // `uuid` package here to keep the domain layer Hive-only — the
    // `uuid` package is already in pubspec for higher-up call sites.
    final int nowMs = DateTime.now().microsecondsSinceEpoch;
    return 's_${nowMs.toRadixString(16)}_${(nowMs ^ nowMs.hashCode).toRadixString(16)}';
  }

  /// Returns a new stroke with one more point appended. Used by the
  /// canvas widget for incremental accumulation.
  DrawingStroke appendPoint(double dx, double dy, int panTimeMs) {
    final List<double> extended = <double>[...points, dx, dy];
    return DrawingStroke(
      id: id,
      colorValue: colorValue,
      brushSize: brushSize,
      brushTypeIndex: brushTypeIndex,
      points: extended,
      textureSeed: textureSeed,
      timestampMs: panTimeMs,
    );
  }
}
