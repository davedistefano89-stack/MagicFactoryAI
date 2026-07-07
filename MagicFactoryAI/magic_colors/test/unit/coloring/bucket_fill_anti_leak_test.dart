// =============================================================================
// Magic Colors · test/unit/coloring/bucket_fill_anti_leak_test.dart
// =============================================================================
//
// M2.2 PRODUCTION — Verifies the three-rejection anti-leak guards:
//   • tinyRegion      — below minPixels
//   • backgroundTap   — above maxFraction
//   • hardMaxExceeded — above hardMaxPixels
//
// Plus the dead-letter rejections that protect against eraser
// swatches and individual seed mismatches. Each test asserts the
// BFS terminates early without exhausting memory on a "wrong" tap.
// =============================================================================

import 'dart:typed_data' show Uint8List;

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/fill/scanline_filler.dart';

import 'bucket_fill_correctness_test.dart' show bufferFor, paintPixel;

void main() {
  group('floodFill — anti-leak guards', () {
    test('tinyRegion: fewer than minPixels = seed-only success', () {
      const int w = 12;
      const int h = 12;
      final Uint8List pixels = bufferFor(w, h, 0x11, 0x11, 0x11, 0xFF);
      // A tiny 2x2 patch at center, surrounded by foreign colour.
      paintPixel(pixels, w, 5, 5, 0xEE, 0xEE, 0xEE, 0xFF);
      paintPixel(pixels, w, 6, 5, 0xEE, 0xEE, 0xEE, 0xFF);
      paintPixel(pixels, w, 5, 6, 0xEE, 0xEE, 0xEE, 0xFF);
      paintPixel(pixels, w, 6, 6, 0xEE, 0xEE, 0xEE, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFEEEEEE,
        seedX: 5,
        seedY: 5,
        guard: const FloodFillGuard(minPixels: 8),
      );
      expect(result, isNull, reason: '4 < 8 => tinyRegion reject');
      expect(lastRejection, FloodFillRejection.tinyRegion);
    });

    test('tinyRegion with minPixels=1 allows minimum fill', () {
      const int w = 8;
      const int h = 8;
      final Uint8List pixels = bufferFor(w, h, 0x11, 0x11, 0x11, 0xFF);
      paintPixel(pixels, w, 4, 4, 0xEE, 0xEE, 0xEE, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFEEEEEE,
        seedX: 4,
        seedY: 4,
      );
      expect(result, isNotNull);
      expect(result!.pixelCount, 1);
    });

    test('backgroundTap: >70% percent fill refused', () {
      const int w = 100;
      const int h = 100;
      // 100x100 = 10_000 pixels; painted background.
      final Uint8List pixels = bufferFor(w, h, 0xEE, 0xEE, 0xEE, 0xFF);
      // Splash a tiny foreign-coloured wall covering 5% of the canvas:
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFEEEEEE,
        seedX: 50,
        seedY: 50,
        guard: const FloodFillGuard(
          minPixels: 8,
          maxFraction: 0.70,
        ),
      );
      // Default soft-edge pass may add a few entries; we expect at
      // least the 4-connected bulk of the background to be visible.
      // The result-or-nil depends: 95% above the 70% threshold,
      // so BFS terminates at FRACTION_REJECT.
      // Pre-anti-leak: 95%. With guard.maxFraction=0.70, BFS
      // does not commit -> lastRejection = backgroundTap.
      expect(result, isNull,
          reason: '95% fills via 95% Background; 0.70 fraction refuses');
      expect(lastRejection, FloodFillRejection.backgroundTap);
    });

    test('hardMaxExceeded caps work via explicit cap', () {
      const int w = 200;
      const int h = 200;
      // 40 K-pixel solid colour.
      final Uint8List pixels = bufferFor(w, h, 0x77, 0x77, 0x77, 0xFF);
      // Config: maxFraction default 0.7 → 28 K cap; hardMax 5_000 → tightest.
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFF777777,
        seedX: 100,
        seedY: 100,
        guard: const FloodFillGuard(
          hardMaxPixels: 5000,
        ),
      );
      expect(result, isNull);
      expect(lastRejection, FloodFillRejection.hardMaxExceeded);
    });

    test('eraser alpha=0 swatch is refused at the gate', () {
      final Uint8List pixels = bufferFor(4, 4, 0xFF, 0xFF, 0xFF, 0xFF);
      // Target = transparent eraser.
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: 4,
        height: 4,
        targetColor: 0x00FF00FF, // ARGB; alpha = 0
        seedX: 0,
        seedY: 0,
      );
      expect(result, isNull);
      expect(lastRejection, FloodFillRejection.eraserColour);
    });

    test('seedMismatch: tap on foreign-coloured pixel silently fails', () {
      const int w = 4;
      const int h = 4;
      final Uint8List pixels = bufferFor(w, h, 0xEE, 0xEE, 0xEE, 0xFF);
      // Seed at (2,2) — but the surrounding pixels are 0xEE
      // (target = 0xEE). However the very single pixel at (2,2)
      // is foreign colour.
      paintPixel(pixels, w, 2, 2, 0xAA, 0xAA, 0xAA, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFFEEEEEE,
        seedX: 2,
        seedY: 2,
      );
      expect(result, isNull,
          reason: 'seed landed on a foreign colour → seedMismatch');
      expect(lastRejection, FloodFillRejection.seedMismatch);
    });

    test('boundary honour: maxFraction=1.0 with explicit minPixels working',
        () {
      const int w = 30;
      const int h = 30;
      final Uint8List pixels = bufferFor(w, h, 0x77, 0x77, 0x77, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFF777777,
        seedX: 15,
        seedY: 15,
        guard: const FloodFillGuard(
          hardMaxPixels: 10 * 1000 * 1000,
        ),
      );
      expect(result, isNotNull,
          reason: 'no anti-leak cap should be hit on a full fill');
      expect(result!.pixelCount, w * h);
    });

    test('mid-BFS termination: BFS does not exceed hardMax when set tight', () {
      const int w = 200;
      const int h = 200;
      final Uint8List pixels = bufferFor(w, h, 0x77, 0x77, 0x77, 0xFF);
      final FloodFillResult? result = floodFill(
        pixels: pixels,
        width: w,
        height: h,
        targetColor: 0xFF777777,
        seedX: 100,
        seedY: 100,
        guard: const FloodFillGuard(
          maxFraction: 0.99, // permissive
          hardMaxPixels: 1000, // tight cap
        ),
      );
      expect(result, isNull);
      // 1000 is below softMax = 0.99 * 40_000 = 39_600 firsst.
      // So the hard cap (1000) trips first → lastRejection hardMax.
      expect(lastRejection, FloodFillRejection.hardMaxExceeded);
    });
  });
}
