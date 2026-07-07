// =============================================================================
// Magic Colors · features/coloring/painting/fill_picture_cache.dart
// =============================================================================
//
// M2.2 PRODUCTION — Pre-bake committed FillRegions into [ui.Picture]
// objects keyed by region.id. The custom painter replays each
// FillRegion via `canvas.drawPicture(pic)` instead of walking the
// span list every frame. Per-fill cost: O(N spans) ONCE at commit
// time, then O(1) per replay frame.
//
// WHY THIS CACHE EXISTS
//   The M2.2 MVP painted FillRegions live every frame: each frame
//   traversed the span list and emitted one `canvas.drawRect` per
//   span (alpha-multiplied for fade-in). At ~50 spans / typical
//   fill × 60 FPS × 5 fills on a 4-fill drawing, the per-frame
//   cost was ~12 ms — JUST within budget but fragile to the kid
//   re-tapping on the same area. Pre-baking commits are O(N) once
//   and replay is O(1) per frame.
//
// CACHE BOUND
//   BucketFillConsts.maxCachedFillPictures (24). At ~20 KB / Picture
//   (RGBA bitmap for a 1024×768 region) that's ~480 KB peak —
//   well below the per-app budget. LRU eviction on insert when
//   over the cap. Old Pictures are disposed safely.
//
// INVALIDATION
//   • drop(regionId) — single entry, called on undo. Released so
//     the redoStack just holds the abstract FillRegion, not the
//     Picture.
//   • clear() — all entries, called on clearCanvas. Releases every
//     cached Picture.
//
// NEVER OWNED BY StrokePictureCache — they coexist (a canvas
// drawing may have BOTH stroke + fill commands). Keeping them as
// separate caches lets M2.5 swap the fill cache to a smaller,
// region-tied memory arena without touching stroke rendering.
// =============================================================================

import 'dart:ui' show Canvas, Picture, PictureRecorder, Rect;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/painting.dart' show Color, Paint, PaintingStyle;

import 'package:magic_colors/core/utils/logger.dart';

import '../domain/paint_command.dart';
import '../fill/bucket_fill_consts.dart';

/// Caches [Picture] recordings keyed by FillRegion.id. Bounded by
/// [BucketFillConsts.maxCachedFillPictures] (LRU eviction on insert).
final class FillPictureCache {
  /// Insertion order for LRU eviction. Most-recent at the end.
  final List<String> _idOrder = <String>[];

  /// The cached Pictures keyed by region id.
  final Map<String, Picture> _pictures = <String, Picture>{};

  /// Cached count. Exposed for tests + assertion.
  int get size => _pictures.length;

  /// Lifts the cached picture by id without ejecting the LRU order.
  /// Returns null on miss; the painter should re-bake via
  /// [getOrBake] instead of using this directly.
  Picture? operator [](String regionId) => _pictures[regionId];

  /// Returns the cached picture for [region], baking on miss.
  /// Idempotent — repeated calls with the same region are O(1)
  /// after the first.
  ///
  /// The Picture origin (the Region's top-left) is baked as the
  /// recorder's `(0, 0)`. Replay at draw-time via
  /// `canvas.drawPicture(pic, region.origin)` so the painter's
  /// subsequent translations don't disturb the Picture content.
  Picture getOrBake(FillRegion region) {
    final cached = _pictures[region.id];
    if (cached != null) {
      _touch(region.id);
      return cached;
    }
    return _bake(region);
  }

  Picture _bake(FillRegion region) {
    // Bake the Picture in IMAGE-space, anchored at the region's
    // tight imageBounds origin. The painter, when replaying, scales
    // by region.pixelRatio and translates by region.origin (logical)
    // so the resulting drawing aligns with the rest of the canvas.
    final Rect imageBounds = region.imageBounds;
    final recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder, imageBounds);
    canvas.translate(-imageBounds.left, -imageBounds.top);

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false
      ..color = Color(region.colorValue);

    // One drawRect per horizontal run. O(spans) but this is the
    // single bake — never per frame. Spans are in IMAGE coords so
    // each rect is a (1 px tall) horizontal bar.
    for (final span in region.spans) {
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

    if (kDebugMode && region.spans.isNotEmpty) {
      logger.debug(
        'FillPictureCache._bake id=${region.id} '
        'spans=${region.spans.length} pixelCount=${region.pixelCount} '
        'dpr=${region.pixelRatio}',
      );
    }

    final Picture pic = recorder.endRecording();

    // Evict the OLDEST entry if we're over the cap. Maps preserve
    // insertion order in Dart, so we just remove the first key.
    if (_pictures.length >= BucketFillConsts.maxCachedFillPictures) {
      final String? oldest = _idOrder.isNotEmpty ? _idOrder.first : null;
      if (oldest != null) {
        _pictures.remove(oldest);
        _idOrder.removeAt(0);
      }
    }

    _pictures[region.id] = pic;
    _idOrder.add(region.id);
    return pic;
  }

  /// Bumps the LRU position for [regionId] without re-baking.
  void _touch(String regionId) {
    final int idx = _idOrder.indexOf(regionId);
    if (idx >= 0 && idx < _idOrder.length - 1) {
      _idOrder.removeAt(idx);
      _idOrder.add(regionId);
    }
  }

  /// Drops a single entry. Safe to call for an unknown id (no-op).
  void drop(String regionId) {
    final pic = _pictures.remove(regionId);
    _idOrder.remove(regionId);
    if (pic != null) {
      try {
        pic.dispose();
      } on Object catch (error, stack) {
        logger.error(
          'FillPictureCache.dispose failed region=$regionId',
          error: error,
          stackTrace: stack,
        );
      }
    }
  }

  /// Drops every cached picture. Called when the entire canvas has
  /// been wiped (clearCanvas).
  void clear() {
    for (final entry in _pictures.entries) {
      try {
        entry.value.dispose();
      } on Object catch (error, stack) {
        logger.error(
          'FillPictureCache.dispose failed region=${entry.key}',
          error: error,
          stackTrace: stack,
        );
      }
    }
    _pictures.clear();
    _idOrder.clear();
  }
}
