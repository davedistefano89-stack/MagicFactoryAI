// =============================================================================
// Magic Colors · test/unit/coloring/bucket_fill_pixel_ratio_test.dart
// =============================================================================
//
// M2.2 PRODUCTION — Tablet support: validates the devicePixelRatio
// conversion at commit time. The boundary snapshot produces an
// IMAGE-space canvas; the controller converts back to LOGICAL
// pixelRatio-aware coordinates so the painter can scale the cached
// Picture at replay.
//
// These tests don't snapshot a real RepaintBoundary (no widget tree
// in unit tests); instead they synthesise an image-space buffer at
// varying pixelRatio and verify the FillRegion.origin / width /
// height conversion math is correct.
// =============================================================================

import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/fill/scanline_filler.dart';

void main() {
  group('PixelRatio mapping at commit', () {
    FloodFillGuard unrestricted() => const FloodFillGuard(
          hardMaxPixels: 1000 * 1000 * 1000,
        );

    test('dpr=1.0 keeps origin == image-bounds origin', () {
      final r = floodFill(
        pixels: _white(8, 8),
        width: 8,
        height: 8,
        targetColor: 0xFFFFFFFF,
        seedX: 4,
        seedY: 4,
        guard: unrestricted(),
      );
      expect(r, isNotNull);
      final m = _bridgeFromImage(r!, 1.0);
      expect(m.origin.dx, 0.0);
      expect(m.origin.dy, 0.0);
      expect(m.width, 8);
      expect(m.height, 8);
      expect(m.pixelRatio, 1.0);
      expect(m.imageBounds, r.bounds);
    });

    test('dpr=2.0 maps origin/width/height by half', () {
      final r = floodFill(
        pixels: _white(16, 16),
        width: 16,
        height: 16,
        targetColor: 0xFFFFFFFF,
        seedX: 8,
        seedY: 8,
        guard: unrestricted(),
      );
      expect(r, isNotNull);
      final m = _bridgeFromImage(r!, 2.0);
      expect(m.origin.dx, 0.0);
      expect(m.origin.dy, 0.0);
      expect(m.width, 8);
      expect(m.height, 8);
      expect(m.pixelRatio, 2.0);
      expect(m.imageBounds, const Rect.fromLTWH(0, 0, 16.0, 16.0));
    });

    test('dpr=3.0 maps origin/width/height by third; span preservation', () {
      final r = floodFill(
        pixels: _white(30, 30),
        width: 30,
        height: 30,
        targetColor: 0xFFFFFFFF,
        seedX: 15,
        seedY: 15,
        guard: unrestricted(),
      );
      expect(r, isNotNull);
      final m = _bridgeFromImage(r!, 3.0);
      expect(m.pixelRatio, 3.0);
      // 30 / 3 = 10 logical pixels.
      expect(m.width, 10);
      expect(m.height, 10);
      // Spans stay in IMAGE coords (untouched by the logical map).
      expect(m.spans.length, r.spans.length);
      expect(m.spans.first.row, 0);
      expect(m.spans.first.xStart, 0);
    });

    test('zero dpr falls back to 1.0 safely', () {
      final r = floodFill(
        pixels: _white(8, 8),
        width: 8,
        height: 8,
        targetColor: 0xFFFFFFFF,
        seedX: 4,
        seedY: 4,
        guard: unrestricted(),
      );
      expect(r, isNotNull);
      final m = _bridgeFromImage(r!, 0.0);
      expect(m.pixelRatio, 1.0);
      expect(m.origin.dx, 0.0);
      expect(m.origin.dy, 0.0);
    });

    test('large image: 200x200 region at dpr=1 returns clean conversion', () {
      final r = floodFill(
        pixels: _white(200, 200),
        width: 200,
        height: 200,
        targetColor: 0xFFFFFFFF,
        seedX: 100,
        seedY: 100,
        guard: unrestricted(),
      );
      expect(r, isNotNull);
      final m = _bridgeFromImage(r!, 1.0);
      expect(m.pixelCount, 200 * 200);
      expect(m.width, 200);
      expect(m.height, 200);
    });

    test('origin alignment: BFS result with non-zero bounds maps', () {
      // 16x16 buffer with a 4-px black border so the BFS visits only
      // the 14x14 inner region.
      final pixels = _white(16, 16);
      for (int y = 0; y < 16; y++) {
        for (int x = 0; x < 16; x++) {
          if (x == 0 || x == 15 || y == 0 || y == 15) {
            _setPixel(pixels, 16, x, y, 0x00, 0x00, 0x00);
          }
        }
      }
      final r = floodFill(
        pixels: pixels,
        width: 16,
        height: 16,
        targetColor: 0xFFFFFFFF,
        seedX: 8,
        seedY: 8,
        guard: unrestricted(),
      );
      expect(r, isNotNull);
      expect(r!.bounds, const Rect.fromLTWH(1, 1, 14, 14));
      final m = _bridgeFromImage(r, 2.0);
      expect(m.origin.dx, 0.5);
      expect(m.origin.dy, 0.5);
      expect(m.width, 7); // 14/2 = 7
      expect(m.height, 7);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────────────────

class _LogicalMap {
  _LogicalMap({
    required this.origin,
    required this.width,
    required this.height,
    required this.pixelCount,
    required this.pixelRatio,
    required this.imageBounds,
    required this.spans,
  });

  final Offset origin;
  final int width;
  final int height;
  final int pixelCount;
  final double pixelRatio;
  final Rect imageBounds;
  final List<FillSpan> spans;
}

/// Mirrors the controller-side conversion commit-time so we can
/// assert the math directly.
_LogicalMap _bridgeFromImage(FloodFillResult result, double pixelRatio) {
  final double dpr = pixelRatio <= 0 ? 1.0 : pixelRatio;
  final Offset logicalOrigin = Offset(
    result.bounds.left / dpr,
    result.bounds.top / dpr,
  );
  // M2.2 PRODUCTION — bridge the BFS's TIGHT bounds, not the image's
  // full dimensions. The controller's commitFillRegion uses
  // result.bounds when computing logicalWidth / logicalHeight so a
  // fill that doesn't span the entire image resolves to the spill's
  // footprint in logical pixels, not the canvas's full raster.
  final int logicalWidth = (result.bounds.width / dpr).ceil();
  final int logicalHeight = (result.bounds.height / dpr).ceil();
  return _LogicalMap(
    origin: logicalOrigin,
    width: logicalWidth,
    height: logicalHeight,
    pixelCount: result.pixelCount,
    pixelRatio: dpr,
    imageBounds: result.bounds,
    spans: result.spans,
  );
}

List<int> _white(int w, int h) {
  final pixels = List<int>.filled(w * h * 4, 0xFF);
  // Set RGB = 0xFF, alpha = 0xFF (opaque white).
  for (int i = 0; i < w * h; i++) {
    final j = i * 4;
    pixels[j + 0] = 0xFF;
    pixels[j + 1] = 0xFF;
    pixels[j + 2] = 0xFF;
    pixels[j + 3] = 0xFF;
  }
  return pixels;
}

void _setPixel(List<int> buffer, int w, int x, int y, int r, int g, int b) {
  final j = (y * w + x) * 4;
  buffer[j + 0] = r & 0xFF;
  buffer[j + 1] = g & 0xFF;
  buffer[j + 2] = b & 0xFF;
  buffer[j + 3] = 0xFF;
}
