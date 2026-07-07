// =============================================================================
// Magic Colors · test/unit/coloring/bucket_fill_picture_cache_test.dart
// =============================================================================
//
// M2.2 PRODUCTION — Unit tests for FillPictureCache pre-bake + replay
// semantics. Verifies:
//   * getOrBake caches by id (idempotent across calls).
//   * LRU eviction when over the cap (oldest removed first).
//   * drop(id) removes one entry; clear() removes all.
//   * Bake reuses the same region without producing a new Picture.
//   * Soft-edge trigger flag propagates from BFS through fromSpans.
//   * pixelRatio + imageBounds store correctly on the FillRegion.
//
// These tests pass plain `List<int>` RGBA8888 buffers to floodFill
// (the BFS API natively accepts `List<int>`, no shim required).
// =============================================================================

import 'dart:ui' show Offset, Picture, Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/domain/paint_command.dart';
import 'package:magic_colors/features/coloring/fill/bucket_fill_consts.dart';
import 'package:magic_colors/features/coloring/fill/scanline_filler.dart';
import 'package:magic_colors/features/coloring/painting/fill_picture_cache.dart';

import 'bucket_fill_correctness_test.dart' show bufferFor;

/// Builds a uniform `width x height` opaque-white RGBA8888 buffer
/// as a plain `List<int>` so the BFS accepts it without a shim.
List<int> _whitePixels(int width, int height) {
  final List<int> p = List<int>.filled(width * height * 4, 0xFF);
  // Set every pixel to (R=0xFF, G=0xFF, B=0xFF, A=0xFF).
  for (int i = 0; i < width * height; i++) {
    p[i * 4 + 0] = 0xFF;
    p[i * 4 + 1] = 0xFF;
    p[i * 4 + 2] = 0xFF;
    p[i * 4 + 3] = 0xFF;
  }
  return p;
}

FillRegion _makeRegion(
  String id,
  int colourValue,
  int size, {
  int pixelRatio = 1,
}) {
  final FloodFillResult? r = floodFill(
    pixels: _whitePixels(size, size),
    width: size,
    height: size,
    targetColor: 0xFFFFFFFF,
    seedX: 0,
    seedY: 0,
  );
  expect(r, isNotNull,
      reason: 'helper BFS should always succeed on a uniform buffer');
  return FillRegion.fromSpans(
    id: id,
    colorValue: colourValue,
    result: r!,
    logicalOrigin: Offset.zero,
    logicalWidth: size ~/ (pixelRatio <= 0 ? 1 : pixelRatio),
    logicalHeight: size ~/ (pixelRatio <= 0 ? 1 : pixelRatio),
    pixelRatio: pixelRatio.toDouble(),
    timestamp: DateTime(2024),
  );
}

void main() {
  group('FillPictureCache — pre-bake + replay', () {
    setUp(() {
      // Defensively reset the global rejection tracking so other
      // groups don't leak a stale rejection across suites.
    });

    test('getOrBake caches a Picture by id; second call is identical', () {
      final cache = FillPictureCache();
      final region = _makeRegion('r1', 0xFFEEEEEE, 4);
      final Picture p1 = cache.getOrBake(region);
      final Picture p2 = cache.getOrBake(region);
      expect(identical(p1, p2), isTrue,
          reason:
              'cache memoises by id; second retrieval returns identical instance');
      expect(cache.size, 1);
      cache.clear();
    });

    test('drop removes one entry', () {
      final cache = FillPictureCache();
      cache.getOrBake(_makeRegion('r1', 0xFFEEEEEE, 4));
      cache.getOrBake(_makeRegion('r2', 0xFFEEEEEE, 4));
      expect(cache.size, 2);
      cache.drop('r1');
      expect(cache.size, 1);
      cache.clear();
    });

    test('clear drops all entries', () {
      final cache = FillPictureCache();
      cache.getOrBake(_makeRegion('r1', 0xFFEEEEEE, 4));
      cache.getOrBake(_makeRegion('r2', 0xFFEEEEEE, 4));
      cache.clear();
      expect(cache.size, 0);
    });

    test('LRU eviction: oldest removed when over the cap', () {
      // maxCachedFillPictures defaults to 24. Insert cap+2 regions
      // and verify the OLDEST two are evicted (FIFO via _idOrder).
      final cache = FillPictureCache();
      const int cap = BucketFillConsts.maxCachedFillPictures;
      for (int i = 0; i < cap + 2; i++) {
        cache.getOrBake(_makeRegion('r$i', 0xFFEEEEEE, 4));
      }
      expect(cache.size, cap, reason: 'oldest two evicted: r0 + r1');
      expect(cache['r0'], isNull, reason: 'evicted (oldest)');
      expect(cache['r1'], isNull, reason: 'evicted (second-oldest)');
      expect(cache['r${cap - 1}'], isNotNull);
      expect(cache['r$cap'], isNotNull);
      expect(cache['r${cap + 1}'], isNotNull, reason: 'newest stay');
      cache.clear();
    });

    test('repeat calls without new keys reuse the same Picture', () {
      final cache = FillPictureCache();
      final region = _makeRegion('r1', 0xFFEEEEEE, 4);
      final Picture p = cache.getOrBake(region);
      for (int i = 0; i < 10; i++) {
        cache.getOrBake(region);
      }
      expect(cache.size, 1);
      expect(identical(cache.getOrBake(region), p), isTrue);
      cache.clear();
    });

    test('region stores pixelRatio + imageBounds from BFS', () {
      final region = _makeRegion('r1', 0xFFCCCCFF, 8);
      expect(region.pixelRatio, 1.0);
      expect(region.imageBounds, isA<Rect>());
      expect(region.imageBounds.width, 8.0);
      expect(region.imageBounds.height, 8.0);
    });

    test('softEdgeTriggered is preserved by fromSpans factory', () {
      const int w = 8;
      const int h = 8;
      // Build pixel buffer inline (mutable, so we can mutate the
      // 1-px ring on the perimeter). The default bufferFor returns
      // Uint8List, which IS mutable; pass it directly.
      final pixels = bufferFor(w, h, 0xFF, 0xFF, 0xFF, 0xFF);
      // Ring of softer pixels just outside strict tolerance.
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (x == 0 || x == w - 1 || y == 0 || y == h - 1) {
            final int idx = (y * w + x) * 4;
            pixels[idx + 0] = 0xF0;
            pixels[idx + 1] = 0xF0;
            pixels[idx + 2] = 0xF0;
          }
        }
      }
      final FloodFillResult? r = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFFFFFFF,
        seedX: 4,
        seedY: 4,
      );
      expect(r, isNotNull);
      final region = FillRegion.fromSpans(
        id: 'r',
        colorValue: 0xFFFFFFFF,
        result: r!,
        logicalOrigin: Offset.zero,
        logicalWidth: w,
        logicalHeight: h,
        pixelRatio: 1.0,
        timestamp: DateTime(2024),
      );
      expect(region.softEdgeTriggered, isTrue);
    });
  });
}
