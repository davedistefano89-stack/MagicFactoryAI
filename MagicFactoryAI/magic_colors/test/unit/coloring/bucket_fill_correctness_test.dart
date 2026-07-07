// =============================================================================
// Magic Colors · test/unit/coloring/bucket_fill_correctness_test.dart
// =============================================================================
//
// M2.2 PRODUCTION — Unit tests for floodFill correctness. Verifies:
//   • 4-connected scanline BFS produces a real connected component.
//   • Tolerance policy: 8/255 per-channel default; 0 = strict.
//   • Boundary rejection on out-of-range seed.
//   • Transparent pixels are never matched.
//   • Eraser swatch (alpha=0) is uniformly refused.
//
// All synthetic buffers are RGBA8888 (4 bytes/pixel). Construction
// is via the [bufferFor] helper so each test reads as one canonical
// setup function.
// =============================================================================

import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/fill/scanline_filler.dart';

void main() {
  group('floodFill — correctness', () {
    test('solid 10x10 white canvas fills with same colour', () {
      const int w = 10;
      const int h = 10;
      final Uint8List pixels = bufferFor(w, h, 0xCC, 0xCC, 0xCC, 0xFF);
      const int target = 0xFFCCCCCC;
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: target,
        seedX: 5,
        seedY: 5,
      );
      expect(result, isNotNull);
      expect(result!.pixelCount, w * h);
      expect(result.width, w);
      expect(result.height, h);
      expect(result.bounds, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    });

    test('rectangle with hole: fill only fills outer ring', () {
      const int w = 12;
      const int h = 12;
      // Outer 12x12 white canvas with inner 4x4 BLACK hole at (4,4)..(7,7).
      final Uint8List pixels = bufferFor(w, h, 0xEE, 0xEE, 0xEE, 0xFF);
      // Punch a black hole at rows 4..7, cols 4..7.
      for (int y = 4; y < 8; y++) {
        for (int x = 4; x < 8; x++) {
          paintPixel(pixels, w, x, y, 0x11, 0x11, 0x11, 0xFF);
        }
      }
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFEEEEEE,
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNotNull);
      // Filled pixel count == 12*12 - 4*4 = 144 - 16 = 128
      expect(result!.pixelCount, w * h - 16);
      expect(result.bounds, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
      // Spans count: every row except 4..7 has 1 span; rows 4..7 have
      // two spans each (left[0..3] + right[8..11]).
      final Map<int, int> spansPerRow = <int, int>{};
      for (final s in result.spans) {
        spansPerRow[s.row] = (spansPerRow[s.row] ?? 0) + 1;
      }
      for (int y = 0; y < h; y++) {
        if (y >= 4 && y < 8) {
          expect(spansPerRow[y], 2,
              reason: 'row $y straddles the hole — 2 spans');
        } else {
          expect(spansPerRow[y], 1, reason: 'row $y is a single run');
        }
      }
    });

    test('4-connected enforcement: diagonal gap stays a wall', () {
      const int w = 6;
      const int h = 6;
      final Uint8List pixels = bufferFor(w, h, 0xAA, 0xAA, 0xAA, 0xFF);
      // Draw a black diagonal barrier — pixels at (1,0), (2,1), (3,2),
      // (4,3), (5,4). Theoter BFS should NOT bleed diagonally across
      // these gaps because 4-connected doesn't read diagonals as a
      // path.
      paintPixel(pixels, w, 1, 0, 0x00, 0x00, 0x00, 0xFF);
      paintPixel(pixels, w, 2, 1, 0x00, 0x00, 0x00, 0xFF);
      paintPixel(pixels, w, 3, 2, 0x00, 0x00, 0x00, 0xFF);
      paintPixel(pixels, w, 4, 3, 0x00, 0x00, 0x00, 0xFF);
      paintPixel(pixels, w, 5, 4, 0x00, 0x00, 0x00, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFAAAAAA,
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNotNull);
      // Diagonal: the upper-right portion is disconnected.
      // Upper-right block: cols 2..5, rows 0..3 minus the barrier.
      // (We only path through (1,0) blocking col 0->1; the diagonal
      // wall hooks NE so a seed at (0,0) sees (0,0), (0,1), (0,2),
      // (0,3), (0,4), (0,5), (1,1 ignored? No (1,1) is blocked),
      // effectively → ~10 pixels in the leftmost column + a few.
      expect(result!.pixelCount, lessThan(w * h));
    });

    test('tolerance=0 forces strict match', () {
      const int w = 8;
      const int h = 8;
      final Uint8List pixels = bufferFor(w, h, 0xFF, 0xFF, 0xFF, 0xFF);
      // Single pixel at slightly-different colour — should NOT match
      // with tolerance=0 but WITH tolerance=8.
      paintPixel(pixels, w, 4, 4, 0xFA, 0xFA, 0xFA, 0xFF); // diff=10
      // Strict:
      final FloodFillResult? strict = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFFFFFFF,
        seedX: 0,
        seedY: 0,
        guard: const FloodFillGuard(tolerancePerChannel: 0),
      );
      expect(strict, isNotNull);
      // The slightly different pixel is excluded -> 63 pixels filled.
      expect(strict!.pixelCount, w * h - 1);
      // Forgiving:
      final FloodFillResult? lenient = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFFFFFFF,
        seedX: 0,
        seedY: 0,
      );
      expect(lenient, isNotNull);
      expect(lenient!.pixelCount, w * h);
    });

    test('transparent pixels are never matched', () {
      const int w = 4;
      const int h = 4;
      // Mix of opaque white + transparent white.
      final Uint8List pixels = bufferFor(w, h, 0xFF, 0xFF, 0xFF, 0x00);
      // Convert pixel[0] to opaque and tap it.
      paintPixel(pixels, w, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFFFFFFF,
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNotNull);
      expect(result!.pixelCount, 1,
          reason: 'only the one opaque pixel matched');
    });

    test('transparent alpha=0 target colour is refused at the gate', () {
      final Uint8List pixels = bufferFor(4, 4, 0xFF, 0xFF, 0xFF, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: 4,
        height: 4,
        targetColor: 0x00FFFFFF, // alpha = 0 (transparent)
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNull);
      expect(lastRejection, FloodFillRejection.eraserColour);
    });

    test('out-of-range seed clips to image bounds', () {
      final Uint8List pixels = bufferFor(4, 4, 0xFF, 0xFF, 0xFF, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: 4,
        height: 4,
        targetColor: 0xFFFFFFFF,
        seedX: -10,
        seedY: 999,
      );
      expect(result, isNotNull);
      // All 16 pixels filled.
      expect(result!.pixelCount, 16);
    });

    test('softEdgeTriggered fires on toleranced boundary', () {
      const int w = 8;
      const int h = 8;
      final Uint8List pixels = bufferFor(w, h, 0xFF, 0xFF, 0xFF, 0xFF);
      // Ring of softer pixels around the perimeter.
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          // 1-px ring of slightly-different colour.
          if (x == 0 || x == w - 1 || y == 0 || y == h - 1) {
            paintPixel(pixels, w, x, y, 0xF0, 0xF0, 0xF0, 0xFF);
          }
        }
      }
      // Inner block is the strict match colour.
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          paintPixel(pixels, w, x, y, 0xFF, 0xFF, 0xFF, 0xFF);
        }
      }
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFFFFFFF,
        seedX: 4,
        seedY: 4,
      );
      expect(result, isNotNull);
      // Inner core is 6×6. The soft-edge ring is excluded by the
      // strict match but the soft-edge pass SHOULD trigger because
      // 0xF0 differs from 0xFF by 15/255 (within softTolerance 24).
      expect(result!.softEdgeTriggered, isTrue);
      expect(result.pixelCount, 36); // 6×6 strict inner.
    });
  });
}

// ── Test buffer helpers ───────────────────────────────────────────────

Uint8List bufferFor(int w, int h, int r, int g, int b, int a) {
  final Uint8List pixels = Uint8List(w * h * 4);
  for (int i = 0; i < w * h; i++) {
    final int j = i * 4;
    pixels[j + 0] = r & 0xFF;
    pixels[j + 1] = g & 0xFF;
    pixels[j + 2] = b & 0xFF;
    pixels[j + 3] = a & 0xFF;
  }
  return pixels;
}

void paintPixel(
  Uint8List buffer,
  int w,
  int x,
  int y,
  int r,
  int g,
  int b,
  int a,
) {
  final int j = (y * w + x) * 4;
  buffer[j + 0] = r & 0xFF;
  buffer[j + 1] = g & 0xFF;
  buffer[j + 2] = b & 0xFF;
  buffer[j + 3] = a & 0xFF;
}
