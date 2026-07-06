// =============================================================================
// Magic Colors · test/unit/coloring/view_transform_controller_test.dart
// =============================================================================
//
// M2.1 — Unit tests for [ViewTransformController].
//
// Each test exercises a single invariant:
//   • Identity round-trip
//   • Scale-floor + scale-ceiling clamp
//   • Scale-around-focal math (world point under fingers stays pinned)
//   • Pan-clamp math (slack ≤ 1.0; at least 25 % remains visible)
//   • setCanvasSize re-clamps stale translations
//   • Notify idempotency (no spurious notifications on no-op mutators)
//
// The matrix under test is computed in dart:ui's Matrix4 space; the
// tests do not assert against the matrix itself — only on the three
// exposed scalars (scale, translation.dx, translation.dy). The matrix
// gets a smoke test for non-degeneracy (no NaNs, all entries finite).
// =============================================================================

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/state/view_transform_controller.dart';

// Tight, named-clamp bound re-exported from the config so tests below
// can read it without recomputing the math.
const double _kSlack = ViewTransformConfig.panSlack;

void main() {
  // M3 — TestWidgetsFlutterBinding initialised so the scale-clamp
  // no-op notify tests below can call HapticFeedback.lightImpact()
  // via ViewTransformController.scaleAroundFocalPoint without
  // tripping "Binding has not yet been initialized" on
  // ServicesBinding.instance. Standard Flutter test-harness wiring.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewTransformController — defaults', () {
    test('starts at identity with zero canvas size', () {
      final c = ViewTransformController();
      expect(c.scale, 1.0);
      expect(c.translation, Offset.zero);
      expect(c.isIdentity, true);
      expect(c.canvasSize, Size.zero);
    });

    test('matrix is identity (translate + scale 1) when at rest', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      final m = c.matrix;
      expect(m.entry(0, 0), closeTo(1.0, 1e-9));
      expect(m.entry(1, 1), closeTo(1.0, 1e-9));
      expect(m.entry(0, 3), closeTo(0.0, 1e-9));
      expect(m.entry(1, 3), closeTo(0.0, 1e-9));
    });
  });

  group('ViewTransformController — scaleAroundFocalPoint', () {
    test('clamps to minScale (0.5x)', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.scaleAroundFocalPoint(
          factor: 0.01, focalPointScreen: const Offset(400, 300));
      expect(c.scale, ViewTransformConfig.minScale);
    });

    test('clamps to maxScale (4.0x)', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.scaleAroundFocalPoint(
          factor: 99.0, focalPointScreen: const Offset(400, 300));
      expect(c.scale, ViewTransformConfig.maxScale);
    });

    test('keeps the world point under the focal pinned across the scale change',
        () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      // At identity, world point (300, 200) is at screen (300, 200).
      const Offset focal = Offset(300, 200);
      c.scaleAroundFocalPoint(factor: 2.0, focalPointScreen: focal);
      // World point under focal pre-scale: (300 - 0) / 1 = 300, 200.
      // Post-scale re-anchor: tx = 300 - 300 * 2 = -300.
      expect(c.scale, 2.0);
      expect(c.translation.dx, closeTo(-300.0, 1e-6));
      expect(c.translation.dy, closeTo(-200.0, 1e-6));
    });

    test('serialises into a finite matrix after a pinch step', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.scaleAroundFocalPoint(
          factor: 2.5, focalPointScreen: const Offset(400, 300));
      final m = c.matrix;
      // All 16 entries finite.
      for (int cIdx = 0; cIdx < 4; cIdx++) {
        for (int rIdx = 0; rIdx < 4; rIdx++) {
          expect(m.entry(cIdx, rIdx).isFinite, true,
              reason: 'matrix[$cIdx][$rIdx] is not finite');
        }
      }
      // Top-left 2x2 should hold the scale.
      expect(m.entry(0, 0), closeTo(2.5, 1e-6));
      expect(m.entry(1, 1), closeTo(2.5, 1e-6));
    });
  });

  group('ViewTransformController — pan clamping', () {
    test('pan inside bounds is allowed', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.pan(const Offset(50, -30));
      expect(c.translation, const Offset(50, -30));
    });

    test('pan way past bounds clamps to the slack window', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.pan(const Offset(1000000, 1000000));
      const double scaledW = 800 * 1.0;
      const double scaledH = 600 * 1.0;
      expect(c.translation.dx, closeTo(scaledW * (1.0 - _kSlack), 1e-6));
      expect(c.translation.dy, closeTo(scaledH * (1.0 - _kSlack), 1e-6));
    });

    test('negative pan clamps to the negative slack window', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.pan(const Offset(-1000000, -1000000));
      const double scaledW = 800 * 1.0;
      const double scaledH = 600 * 1.0;
      expect(c.translation.dx, closeTo(-scaledW * _kSlack, 1e-6));
      expect(c.translation.dy, closeTo(-scaledH * _kSlack, 1e-6));
    });

    test('zero pan is a no-op (does not notify)', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      var notifyCount = 0;
      c.addListener(() => notifyCount++);
      c.pan(Offset.zero);
      expect(notifyCount, 0);
    });
  });

  group('ViewTransformController — setCanvasSize', () {
    test('clamps existing translation to the new bounds', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      // Push way past bounds; controller clamps to slack.
      c.pan(const Offset(1000000, 1000000));
      // Shrink the canvas to (100, 100) → bounds shrink, translation is
      // clamped to scaledW * (1 - slack) = 100 * 0.25 = 25.
      c.setCanvasSize(const Size(100, 100));
      expect(c.translation.dx, closeTo(25.0, 1e-6));
      expect(c.translation.dy, closeTo(25.0, 1e-6));
    });

    test('does not notify when the new size equals the old size', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      var notifyCount = 0;
      c.addListener(() => notifyCount++);
      c.setCanvasSize(const Size(800, 600));
      expect(notifyCount, 0);
    });
  });

  group('ViewTransformController — resetView', () {
    test('restores identity', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.scaleAroundFocalPoint(
          factor: 2.0, focalPointScreen: const Offset(400, 300));
      c.pan(const Offset(10, 10));
      c.resetView();
      expect(c.scale, 1.0);
      expect(c.translation, Offset.zero);
      expect(c.isIdentity, true);
    });

    test('does not notify when already at identity', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      var notifyCount = 0;
      c.addListener(() => notifyCount++);
      c.resetView();
      expect(notifyCount, 0);
    });
  });

  group('ViewTransformController — no-op scale notifies nothing', () {
    test('scaling past the ceiling after reaching max does not notify', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.scaleAroundFocalPoint(
        factor: 99.0,
        focalPointScreen: const Offset(400, 300),
      );
      var notifyCount = 0;
      c.addListener(() => notifyCount++);
      // Already at maxScale. A further scale must no-op.
      c.scaleAroundFocalPoint(
        factor: 99.0,
        focalPointScreen: const Offset(400, 300),
      );
      expect(notifyCount, 0);
    });

    test('scaling under the floor after reaching min does not notify', () {
      final c = ViewTransformController(canvasSize: const Size(800, 600));
      c.scaleAroundFocalPoint(
        factor: 0.001,
        focalPointScreen: const Offset(400, 300),
      );
      var notifyCount = 0;
      c.addListener(() => notifyCount++);
      c.scaleAroundFocalPoint(
        factor: 0.001,
        focalPointScreen: const Offset(400, 300),
      );
      expect(notifyCount, 0);
    });
  });
}
