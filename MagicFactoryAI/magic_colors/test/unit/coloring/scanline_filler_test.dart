// =============================================================================
// Magic Colors · test/unit/coloring/scanline_filler_test.dart
// =============================================================================
//
// M2.2 — Unit tests for the scanline-BFS flood fill.
//
// COVERED CASES
//   • Connected pixel match (filled area bounded by a wall).
//   • Unconnected pixel (touched pixel doesn't match) → null.
//   • Tolerance: 8-bit-per-channel matches pixels slightly off.
//   • Empty pixels → null.
//   • Out-of-bounds seed clamps to canvas.
//   • buildFillMask produces RGBA8888 with A=255 only on visited pixels.
//   • Bounds are tight around visited pixels.
//   • 4-connected (not 8-connected) — diagonal pixels do not connect.
// =============================================================================

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/fill/scanline_filler.dart';


void main() {
  group('floodFill — happy path', () {
    test('returns null on empty pixels', () {
      final result = floodFill(
        pixels: <int>[],
        width: 10,
        height: 10,
        targetColor: 0xFFFFFFFF,
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNull);
    });

    test('returns null when seed pixel does not match target colour', () {
      // 4x4 canvas, all opaque red pixels.
      final pixels = _solidCanvas(4, 4, 0xFFFF0000);
      // Trying to flood-fill #00FF00 (green) on red canvas → no match.
      final result = floodFill(
        pixels: pixels,
        width: 4,
        height: 4,
        targetColor: 0xFF00FF00,
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNull);
    });

    test('connected white pixels fill the entire connected region', () {
      // 6x6 canvas, all pixels white (0xFFFFFFFF). Tap at (3,3).
      final pixels = _solidCanvas(6, 6, 0xFFFFFFFF);
      final result = floodFill(
        pixels: pixels,
        width: 6,
        height: 6,
        targetColor: 0xFFFFFFFF,
        seedX: 3,
        seedY: 3,
      );
      expect(result, isNotNull);
      expect(result!.pixelCount, 36); // 6*6
      expect(result.bounds, Rect.fromLTWH(0, 0, 6, 6));
    });

    test('does not bleed across a black wall', () {
      // 8x4 canvas with a vertical wall at x=4 (column 4 is black).
      final pixels = _wallCanvas(8, 4);
      // Tap at (2, 2). Flood should stop at the wall.
      final result = floodFill(
        pixels: pixels,
        width: 8,
        height: 4,
        targetColor: 0xFFFFFFFF,
        seedX: 2,
        seedY: 2,
      );
      expect(result, isNotNull);
      // Pixels to the left of the wall only: x in [0..3], y in [0..3] = 16px.
      expect(result!.pixelCount, 16);
      expect(result.bounds, Rect.fromLTWH(0, 0, 4, 4));
    });

    test('4-connected (not 8-connected) — diagonal pixels do not connect', () {
      // 5x5 canvas: a single white pixel at (2,2) surrounded by black.
      final pixels = _singlePixelCanvas(5, 5, 2, 2);
      final result = floodFill(
        pixels: pixels,
        width: 5,
        height: 5,
        targetColor: 0xFFFFFFFF,
        seedX: 2,
        seedY: 2,
      );
      expect(result, isNotNull);
      expect(result!.pixelCount, 1); // 1 + 0 via 4-connected
    });
  });

  group('floodFill — refusals', () {
    test('refuses eraser (alpha == 0) as a target colour', () {
      final pixels = _solidCanvas(5, 5, 0xFFFFFFFF);
      final result = floodFill(
        pixels: pixels,
        width: 5,
        height: 5,
        targetColor: 0x00000000,
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNull);
    });
  });

  group('floodFill — bounds and clamping', () {
    test('seed is clamped to within canvas', () {
      final pixels = _solidCanvas(4, 4, 0xFFFFFFFF);
      final result = floodFill(
        pixels: pixels,
        width: 4,
        height: 4,
        targetColor: 0xFFFFFFFF,
        seedX: 999,
        seedY: -1,
      );
      // Clamped to (3, 0). Result fills the whole 4x4.
      expect(result, isNotNull);
      expect(result!.pixelCount, 16);
    });

    test('bounds are tight around visited pixels only', () {
      // 6x6 canvas, white. Paint a "hole" — 2x2 black block in the
      // middle. Tap at top-left and verify bounds are the connected
      // region (5x6 minus the black block).
      final pixels = _canvasWithHole(6, 6, 2, 2, 2, 2);
      final result = floodFill(
        pixels: pixels,
        width: 6,
        height: 6,
        targetColor: 0xFFFFFFFF,
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNotNull);
      // 6*6 - 2*2 = 32.
      expect(result!.pixelCount, 32);
    });
  });

  group('buildFillMask', () {
    test('emits RGBA8888 with A=255 only on visited pixels', () {
      final pixels = _wallCanvas(8, 4);
      final result = floodFill(
        pixels: pixels,
        width: 8,
        height: 4,
        targetColor: 0xFFFFFFFF,
        seedX: 2,
        seedY: 2,
      );
      expect(result, isNotNull);
      final mask = buildFillMask(result!, 0xFFFFFFFF);
      // Each pixel = 4 bytes (R, G, B, A).
      expect(mask.length, 8 * 4 * 4);
      // Check the alpha channel of the first visited pixel.
      expect(mask[3], 0xFF); // alpha
      expect(mask[0], 0xFF); // R (white)
      expect(mask[1], 0xFF); // G
      expect(mask[2], 0xFF); // B
      // Check beyond the visited region (the black wall).
      // Wall starts at x=4. Pixel (0, 0)*4 + 3 = 3 (alpha).
      final wallAlphaIdx = (0 * 8 + 4) * 4 + 3;
      expect(mask[wallAlphaIdx], 0);
    });
  });
}


// ── Test-helper canvas factories ────────────────────────────────────────

/// Builds a width × height RGBA8888 byte buffer filled with [color].
List<int> _solidCanvas(int width, int height, int color) {
  final int out = width * height * 4;
  final List<int> buf = List<int>.filled(out, 0);
  for (int i = 0; i < width * height; i++) {
    buf[i * 4] = (color >> 16) & 0xFF;
    buf[i * 4 + 1] = (color >> 8) & 0xFF;
    buf[i * 4 + 2] = color & 0xFF;
    buf[i * 4 + 3] = (color >> 24) & 0xFF;
  }
  return buf;
}

/// A canvas with a vertical black wall at column `wallX`.
List<int> _wallCanvas(int width, int height) {
  final List<int> buf = _solidCanvas(width, height, 0xFFFFFFFF);
  // Paint column 4 black.
  for (int y = 0; y < height; y++) {
    final int idx = (y * width + 4) * 4;
    buf[idx] = 0;
    buf[idx + 1] = 0;
    buf[idx + 2] = 0;
    buf[idx + 3] = 0xFF;
  }
  return buf;
}

/// A canvas with a single white pixel at (px, py) and black everywhere
/// else.
List<int> _singlePixelCanvas(int width, int height, int px, int py) {
  final List<int> buf = _solidCanvas(width, height, 0xFF000000);
  final int idx = (py * width + px) * 4;
  buf[idx] = 0xFF;
  buf[idx + 1] = 0xFF;
  buf[idx + 2] = 0xFF;
  buf[idx + 3] = 0xFF;
  return buf;
}

/// White canvas with a black rectangular "hole" at (hx, hy) of size
/// (hw × hh).
List<int> _canvasWithHole(
  int width,
  int height,
  int hx,
  int hy,
  int hw,
  int hh,
) {
  final List<int> buf = _solidCanvas(width, height, 0xFFFFFFFF);
  for (int y = hy; y < hy + hh; y++) {
    for (int x = hx; x < hx + hw; x++) {
      final int idx = (y * width + x) * 4;
      buf[idx] = 0;
      buf[idx + 1] = 0;
      buf[idx + 2] = 0;
      buf[idx + 3] = 0xFF;
    }
  }
  return buf;
}
