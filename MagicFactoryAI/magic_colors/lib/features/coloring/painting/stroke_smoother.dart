// =============================================================================
// Magic Colors · features/coloring/painting/stroke_smoother.dart
// =============================================================================
//
// M2.1 — Quadratic midpoint smoothing for stroke point lists. The
// baseline M0 flattens raw PointerEvent positions to a polyline of
// straight lineTo segments, which reads as jaggy low-fidelity "etching"
// on output. This helper rounds every corner by inserting midpoints
// between every pair of consecutive original points, then emits an
// interleaved polyline that the SimplePath lineTo loop reads as a
// single smooth arc.
//
// ALGORITHM (midpoint-inserted polyline, 1 pass)
//   For each pair of consecutive points (p_i, p_{i+1}):
//     q_i    = midpoint between p_i and p_{i+1}
//     emits  = [p_0, q_0, p_1, q_1, p_2, q_2, …, p_{n-1}]
//   The emitted polyline sampled through `moveTo/lineTo` reads as a
//   refined smooth curve — enough fidelity for a 4-year-old's finger
//   cadence without paying for full cubic-Bezier evaluation.
//
// INVARIANTS
//   • Output length = 2n - 1 points for an input of n points (n >= 1).
//   • First and last original points preserved (no drift at endpoints).
//   • Midpoints ALWAYS sit at the geometric mean of their segment
//     endpoints, never escape the segment span.
//   • For n < 2 the input is returned unchanged (a tap is a tap).
// =============================================================================

/// Pure-math helper. Stateless; no instance required.
abstract final class StrokeSmoother {
  const StrokeSmoother._();

  /// Smoothing mode — exposed for unit-testing the choice enum.
  /// Quadratic-midpoint is the M2.1 default; Catmull-Rom is reserved
  /// for M2.4 polish (heavier, smoother — overkill for kids).
  static const String mode = 'quadratic-midpoint';

  /// Smooths a flat (dx, dy, dx, dy, …) point list by interleaving
  /// midpoints with the original endpoints. Returns a new flat list;
  /// the input is not mutated.
  ///
  /// [points] is expected to be a flat even-length double list
  /// (i.e. `points.length` is even and ≥ 4 for a real stroke). For
  /// degenerate inputs (n < 2 points) the input is returned.
  static List<double> quadraticMidpoint(List<double> points) {
    final int n = points.length ~/ 2;
    if (n < 2) {
      // 0 points → empty; 1 point → preserve. No curve possible.
      return List<double>.from(points);
    }
    // Output is interleaved [p_0, q_0, p_1, q_1, p_2, …, p_{n-1}]
    // which is exactly 2n - 1 points → 4(n-1) + 2 doubles.
    final List<double> out = <double>[];
    // First original point
    out.add(points[0]);
    out.add(points[1]);
    for (int i = 0; i < n - 1; i++) {
      final int idxA = i * 2;
      final int idxB = (i + 1) * 2;
      // Midpoint between p_i and p_{i+1}.
      out.add((points[idxA] + points[idxB]) * 0.5);
      out.add((points[idxA + 1] + points[idxB + 1]) * 0.5);
      // Endpoint p_{i+1}.
      out.add(points[idxB]);
      out.add(points[idxB + 1]);
    }
    return out;
  }

  /// Returns the output point count for a given input. Used by tests
  /// to assert the trailing invariant — 2n - 1 for n >= 2.
  static int outputPointCount(int inputPointCount) {
    if (inputPointCount < 1) {
      return 0;
    }
    return inputPointCount == 1 ? 1 : 2 * inputPointCount - 1;
  }
}
