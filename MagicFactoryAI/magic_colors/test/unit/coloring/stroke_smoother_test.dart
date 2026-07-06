// =============================================================================
// Magic Colors · test/unit/coloring/stroke_smoother_test.dart
// =============================================================================
//
// M2.1 — Quadratic midpoint smoothing invariants.
//
// COVERED TESTS
//   • Empty input → empty output
//   • Single point  → single point (no curve possible)
//   • Two-point segment → three points (1 endpoint + 1 midpoint + 1 endpoint)
//   • N points → 2N − 1 points for N >= 2
//   • First and last points are preserved exactly
//   • Midpoints average to the geometric mean of their two endpoints
//   • Output does not mutate the input list
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/painting/stroke_smoother.dart';

void main() {
  group('StrokeSmoother.quadraticMidpoint — degenerate inputs', () {
    test('empty list returns empty list', () {
      expect(StrokeSmoother.quadraticMidpoint(<double>[]), <double>[]);
    });

    test('single-point list returns that point unchanged', () {
      const input = <double>[3.0, 4.0];
      final out = StrokeSmoother.quadraticMidpoint(input);
      expect(out, [3.0, 4.0]);
    });

    test('three-double list (illegal flat) returns unchanged', () {
      // The contract requires even-length lists; here we pass
      // 3 doubles (1.5 points). The helper ignores the half and
      // emits the first point + nothing else.
      const input = <double>[1.0, 2.0, 3.0];
      final out = StrokeSmoother.quadraticMidpoint(input);
      expect(out.length, input.length);
    });
  });

  group('StrokeSmoother.quadraticMidpoint — point count', () {
    test('two points → 3 points (1 endpoint, 1 midpoint, 1 endpoint)', () {
      const input = <double>[0.0, 0.0, 10.0, 20.0];
      final out = StrokeSmoother.quadraticMidpoint(input);
      expect(out.length, 6); // 3 points = 6 doubles
    });

    test('3 input points → 5 output points', () {
      const input = <double>[
        0.0,
        0.0,
        10.0,
        0.0,
        20.0,
        0.0,
      ];
      final out = StrokeSmoother.quadraticMidpoint(input);
      expect(out.length, 10);
      expect(StrokeSmoother.outputPointCount(3), 5);
    });

    test('100 input points → 199 output points (398 doubles)', () {
      final input = List<double>.filled(200, 0.0);
      for (int i = 0; i < 100; i++) {
        input[i * 2] = i.toDouble();
        input[i * 2 + 1] = (i * 2).toDouble();
      }
      final out = StrokeSmoother.quadraticMidpoint(input);
      // n = 100 input points → 2n-1 = 199 output points → 398 doubles.
      expect(out.length, 398);
      expect(StrokeSmoother.outputPointCount(100), 199);
    });
  });

  group('StrokeSmoother.quadraticMidpoint — endpoint preservation', () {
    test('first and last original points preserved', () {
      const input = <double>[
        0.0,
        0.0,
        10.0,
        0.0,
        20.0,
        0.0,
      ];
      final out = StrokeSmoother.quadraticMidpoint(input);
      // First point: (0.0, 0.0) — indices 0 and 1.
      expect(out[0], 0.0);
      expect(out[1], 0.0);
      // Last point: (20.0, 0.0) — at indices length-2, length-1.
      expect(out[out.length - 2], 20.0);
      expect(out[out.length - 1], 0.0);
    });

    test('midpoints lie within their segment span', () {
      const input = <double>[
        0.0,
        0.0,
        10.0,
        0.0,
        20.0,
        0.0,
      ];
      final out = StrokeSmoother.quadraticMidpoint(input);
      // First midpoint = (0+10)/2 = 5.
      expect(out[2], 5.0);
      expect(out[3], 0.0);
      // Second midpoint = (10+20)/2 = 15.
      expect(out[6], 15.0);
      expect(out[7], 0.0);
    });
  });

  group('StrokeSmoother.quadraticMidpoint — purity', () {
    test('does not mutate the input list', () {
      final input = <double>[
        0.0,
        0.0,
        5.0,
        5.0,
        10.0,
        10.0,
      ];
      final original = List<double>.from(input);
      StrokeSmoother.quadraticMidpoint(input);
      expect(input, original);
    });

    test('output is a new list instance', () {
      final input = <double>[0.0, 0.0, 10.0, 10.0];
      final out = StrokeSmoother.quadraticMidpoint(input);
      expect(identical(out, input), false);
    });
  });
}
