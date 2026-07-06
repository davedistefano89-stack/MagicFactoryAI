// =============================================================================
// Magic Colors · features/coloring/domain/paint_command.dart
// =============================================================================
//
// M2.2 PRODUCTION — Sealed union over every paintable command. The
// drawing model previously kept a parallel `strokes: List<DrawingStroke>`
// plus would have needed a parallel `fills: List<FillRegion>` — undo/redo
// semantics would shatter. Instead we unify the redo stack under a
// single [PaintCommand] sealed hierarchy: one command == one undoable
// entry.
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
//   serialised via a manual adapter (`coloring_adapters.dart`).
//   FillRegion is now span-based (a [List<FillSpan>]) — at most
//   `(width × height) / 80` spans for typical connected fills, vs.
//   `width × height / 4` bytes for the legacy RGBA8888 mask.
//
// M2.2 PRODUCTION — MEMORY MODEL
//   FillRegion stores [spans] as the canonical representation. An
//   optional [legacyMask] field is supported for forward-compat
//   hydrates of drawings saved before M2.2 production, and is
//   immediately converted to spans on first access. The controller's
//   pre-bake path never instantiates a legacyMask — the BFS produces
//   spans directly.
// =============================================================================

import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart' show immutable;

import 'drawing_stroke.dart';
import '../fill/scanline_filler.dart' show FillSpan, FloodFillResult;

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

/// M2.2 PRODUCTION — A flood-fill region carved from a tap + scanline-
/// BFS. Stores a [List<FillSpan>] (horizontal runs of visited pixels)
/// as the canonical shape. The painter pre-bakes spans into a
/// `ui.Picture` on commit and replays the cached Picture on every
/// subsequent frame, multiplied by the FillAnimator's fade-in alpha.
///
/// Legacy backwards-compat: the [legacyMask] field is populated for
/// hydrates from drawings saved before M2.2 production. New fills
/// never use it; the BFS produces spans directly.
@immutable
final class FillRegion extends PaintCommand {
  /// Convenience: build a FillRegion from a [FloodFillResult] that
  /// the controller already converted via `result.spans`.
  ///
  /// [logicalOrigin] and [logicalWidth] / [logicalHeight] are the
  /// LOGICAL canvas-space equivalents of `result.bounds` divided by
  /// [pixelRatio]. The controller computes these after the image
  /// snapshot.
  factory FillRegion.fromSpans({
    required String id,
    required int colorValue,
    required FloodFillResult result,
    required Offset logicalOrigin,
    required int logicalWidth,
    required int logicalHeight,
    required double pixelRatio,
    required DateTime timestamp,
  }) {
    return FillRegion(
      id: id,
      colorValue: colorValue,
      width: logicalWidth,
      height: logicalHeight,
      origin: logicalOrigin,
      imageBounds: result.bounds,
      spans: List<FillSpan>.unmodifiable(result.spans),
      timestamp: timestamp,
      pixelRatio: pixelRatio,
      softEdgeTriggered: result.softEdgeTriggered,
    );
  }

  /// Backwards-compat factory — given a legacy RGBA8888 mask,
  /// decompose into spans. Uses O(width × height) time, but only on
  /// hydrate; the resulting FillRegion's hot path is unchanged.
  factory FillRegion.fromMask({
    required String id,
    required int colorValue,
    required List<int> mask,
    required int width,
    required int height,
    required Offset origin,
    required Rect imageBounds,
    required double pixelRatio,
    required DateTime timestamp,
    bool softEdgeTriggered = false,
  }) {
    final List<FillSpan> spans = _spansFromMask(mask, width, height);
    return FillRegion(
      id: id,
      colorValue: colorValue,
      width: width,
      height: height,
      origin: origin,
      imageBounds: imageBounds,
      spans: spans,
      timestamp: timestamp,
      pixelRatio: pixelRatio,
      softEdgeTriggered: softEdgeTriggered,
      legacyMask: List<int>.unmodifiable(mask),
    );
  }
  const FillRegion({
    required this.id,
    required this.colorValue,
    required this.width,
    required this.height,
    required this.origin,
    required this.imageBounds,
    required this.spans,
    required this.timestamp,
    required this.pixelRatio,
    this.softEdgeTriggered = false,
    this.legacyMask,
  });

  /// Stable uuid (also picture-cache key).
  @override
  final String id;

  /// ARGB packed int of the fill colour (matches the controller's
  /// selected swatch at commit-time).
  @override
  final int colorValue;

  /// LOGICAL width in pixels. The BFS produced `width × pixelRatio`
  /// IMAGE-width; we round to the nearest logical pixel here so the
  /// painter can scale-accurately.
  final int width;

  /// LOGICAL height in pixels.
  final int height;

  /// Top-left corner of the region in LOGICAL canvas-space. The
  /// painter translates by this anchor before scaling by [pixelRatio]
  /// and replaying the pre-baked Picture.
  final Offset origin;

  /// IMAGE-space tight bounding box around every visited span. The
  /// [FillPictureCache._bake] uses this as the recorder bounds so the
  /// cached Picture knows its full extent.
  final Rect imageBounds;

  /// Sorted horizontal runs of visited pixels, in IMAGE coords
  /// (int image-pixels). The pre-bake is O(spans); the painter
  /// replay is O(1) post-bake.
  final List<FillSpan> spans;

  /// Snapshot devicePixelRatio at the time the boundary was
  /// captured. The painter scale-multiplies the cached Picture by
  /// this factor to render in logical space.
  final double pixelRatio;

  /// Whether the BFS identified anti-aliased boundary pixels just
  /// outside strict tolerance. Painter reads this to render a soft
  /// halo at the region perimeter.
  final bool softEdgeTriggered;

  /// Wall-clock at commit-time.
  @override
  final DateTime timestamp;

  /// Legacy MASK FOR BACKWARDS-COMPAT ONLY — populated when
  /// [coloring_adapters.dart] hydrates a drawing saved under the
  /// M2.2 Alpha storage layout (RGBA8888 mask). New fills always
  /// have this as `null`. NEVER read it on the hot paint path.
  final List<int>? legacyMask;

  /// Total pixel count covered by the spans. O(spans) — cheap enough
  /// to read on every notify.
  int get pixelCount {
    int total = 0;
    for (final FillSpan s in spans) {
      total += s.length;
    }
    return total;
  }

  /// Span count. Useful for memory accounting in tests.
  int get spanCount => spans.length;

  @override
  Rect get bounds => Rect.fromLTWH(
        origin.dx,
        origin.dy,
        width.toDouble(),
        height.toDouble(),
      );

  /// Returns true when this region actually fills at least 1 pixel.
  /// A 0-span region signals "the BFS visited nothing" and the
  /// controller refuses to commit it.
  bool get hasPixels => spans.isNotEmpty && pixelCount > 0;
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

/// Legacy hydration helper — converts an RGBA8888 mask (4 B/px, A
/// channel encodes the fill shape) into the [FillSpan] list.
List<FillSpan> _spansFromMask(List<int> mask, int width, int height) {
  final List<FillSpan> spans = <FillSpan>[];
  for (int y = 0; y < height; y++) {
    int xs = -1;
    for (int x = 0; x < width; x++) {
      final int byteIdx = (y * width + x) * 4 + 3;
      if (byteIdx < mask.length && mask[byteIdx] != 0) {
        if (xs < 0) xs = x;
      } else if (xs >= 0) {
        spans.add(FillSpan(
          row: y,
          xStart: xs,
          xEndInclusive: x - 1,
        ));
        xs = -1;
      }
    }
    if (xs >= 0) {
      spans.add(FillSpan(
        row: y,
        xStart: xs,
        xEndInclusive: width - 1,
      ));
    }
  }
  return spans;
}
