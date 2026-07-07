// =============================================================================
// Magic Colors · tests/unit/coloring/sparkle_trail_test.dart
// =============================================================================
//
// M2.4 — focused unit tests for the sparkle-trail particle engine.
// Validates:
//   • reduceMotion gates EVERY spawn path.
//   • FIFO eviction caps memory at SparkleTrailConstants.maxParticles.
//   • snapshotFor returns sane alpha + position interpolation values
//     inside the fade window, AND suppresses expired particles.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/painting/sparkle_trail.dart';

void main() {
  group('SparkleTrail', () {
    const Offset kOrigin = Offset(12.0, 34.0);
    const Offset kVelocity = Offset(0.164, -0.164); // 36px / 220ms ish

    test('reduceMotion gates ALL spawn paths', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: true);
      trail.liftBurst(kOrigin, color: 0xFFFFFFFF);
      trail.chaseFromPath(<double>[0, 0, 4, 4], color: 0xFFFFFFFF);
      expect(trail.debugParticles, isEmpty);
    });

    test('liftBurst spawns 6 particles at the same origin', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      trail.liftBurst(kOrigin, color: 0xFFFFFFFF, seed: 42);
      expect(trail.debugParticles.length, 6);
      for (final SparkleParticle p in trail.debugParticles) {
        expect(p.origin, kOrigin);
      }
    });

    test('chaseFromPath emits particles (≤8 by stride)', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      // 16 points → 8 pairs → at most 8.
      final List<double> path = <double>[
        for (int i = 0; i < 16; i++) i.toDouble(),
      ];
      trail.chaseFromPath(path, color: 0xFFFFFFFF, seed: 7);
      expect(trail.debugParticles.length, lessThanOrEqualTo(8));
      expect(trail.debugParticles.length, greaterThan(0));
    });

    test('chaseFromPath ignores too-short paths', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      trail.chaseFromPath(<double>[0, 0], color: 0xFFFFFFFF);
      expect(trail.debugParticles, isEmpty);
    });

    test('particles are FIFO-evicted after exceeding cap', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      for (int i = 0; i < 8; i++) {
        trail.liftBurst(
          kOrigin,
          color: 0xFF000000 + i,
          seed: i,
        );
      }
      expect(
        trail.debugParticles.length,
        SparkleTrailConstants.maxParticles,
      );
    });

    test('snapshotFor returns deterministic empty when no particles', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      expect(trail.snapshotFor(0), isEmpty);
    });

    test('alpha + position interpolation obeys the fade window', () {
      const SparkleParticle p = SparkleParticle(
        origin: kOrigin,
        velocityPerMs: kVelocity,
        radius: 4.0,
        color: 0xFFFFFFFF,
        startedAtMs: 1000,
      );
      expect(p.alpha(1000), 1.0); // start
      expect(p.alpha(1110), closeTo(0.5, 0.01)); // mid
      expect(p.alpha(1220), 0.0); // end
      expect(p.isExpired(1220), isTrue);
      expect(p.isExpired(1219), isFalse);
    });

    test('tick(after-fade) removes expired particles', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      trail.attachTicker((_) {});
      trail.liftBurst(kOrigin, color: 0xFFFFFFFF, seed: 1);
      expect(trail.debugParticles.length, greaterThan(0));
      trail.tick(
        DateTime.now().millisecondsSinceEpoch +
            (SparkleTrailConstants.fadeWindow.inMilliseconds * 2),
      );
      expect(trail.debugParticles, isEmpty);
    });

    test('dispose halts the engine and clears state', () {
      final SparkleTrail trail = SparkleTrail(reduceMotion: false);
      trail.liftBurst(kOrigin, color: 0xFFFFFFFF);
      expect(trail.debugParticles, isNotEmpty);
      trail.dispose();
      expect(trail.debugParticles, isEmpty);
    });
  });
}
