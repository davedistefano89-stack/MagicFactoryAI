// =============================================================================
// Magic Colors · tests/unit/coloring/picture_cache_wiring_test.dart
// =============================================================================
//
// M2.4 — minimal smoke test that verifies the new sparkle-trail
// surface compiles, instantiates, and respects disable-on-call-site
// patterns. The actual paint pipeline is exercised by widget tests
// (canvas is wrapping a CustomPaint which requires a binding).
//
// We test the controller surface here so a future regression in
// the trail integration is caught before `flutter test` reaches the
// widget layer.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/painting/sparkle_trail.dart';

void main() {
  group('SparkleTrail engine surface', () {
    test('clear instance is disposable', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      trail.dispose();
      expect(trail.debugParticles, isEmpty);
    });

    test('reduceMotion is set at construction time (immutable)', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      expect(trail.reduceMotion, isFalse);
      const Offset at = Offset(8.0, 8.0);
      trail.liftBurst(at, color: 0xFFFFFFFF);
      expect(trail.debugParticles, isNotEmpty);
      trail.dispose();
    });

    test('reduceMotion flip refuses spawn paths', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: true);
      const Offset at = Offset(8.0, 8.0);
      trail.liftBurst(at, color: 0xFFFFFFFF);
      trail.chaseFromPath(<double>[0, 0, 4, 4, 8, 8], color: 0xFFFFFFFF);
      expect(trail.debugParticles, isEmpty);
    });
  });
}
