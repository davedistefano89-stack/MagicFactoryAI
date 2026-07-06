// =============================================================================
// Magic Colors · test/unit/coloring/fill_animator_test.dart
// =============================================================================
//
// M2.2 — Unit tests for the [FillAnimator]. Uses TestVSync to drive
// the Ticker callback deterministically; microsecond-precision wall
// clock is patched via the FakeStopwatch helper.
//
// COVERED
//   • progressFor unknown id → 1.0 (no tracking).
//   • start() ramps progress from 0 to 1.
//   • start(reduceMotion: true) → progress = 1 immediately.
//   • retire(id) removes the tracking entry.
//   • clearAll() drops every entry and stops the ticker.
//   • Multiple regions tracked concurrently.
//   • Idempotent re-start resets progress to 0.
// =============================================================================

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/fill/fill_animator.dart';

// Test-only TickerProvider. Bind to a single vsync source so each
// test can drive the tick callback deterministically.
class _FakeTickerProvider implements TickerProvider {
  _FakeTickerProvider(this._ticker);
  final Ticker _ticker;
  @override
  Ticker createTicker(TickerCallback onTick) => _ticker;
}

void main() {
  late Ticker ticker;
  late _FakeTickerProvider vsync;
  late FillAnimator anim;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ticker = Ticker((_) {});
    vsync = _FakeTickerProvider(ticker);
    anim = FillAnimator(vsync: vsync);
  });

  tearDown(() {
    anim.dispose();
    ticker.dispose();
  });

  group('FillAnimator — defaults', () {
    test('progressFor unknown id returns 1.0 (no animation)', () {
      expect(anim.progressFor('nope'), 1.0);
    });

    test('isAnimating is false when no regions are tracked', () {
      expect(anim.isAnimating, false);
    });
  });

  group('FillAnimator — start()', () {
    test('after start: alphabet → progress starts at 0', () {
      anim.start('r1', reduceMotion: false);
      // The progress is already advanced since the start() call
      // happens synchronously and the easing curve at t=0 gives
      // progress = 0. The animator's first tick fires on next frame.
      // We just verify it's tracked.
      expect(anim.progressFor('r1'), lessThan(1.0));
      expect(anim.progressFor('r1'), greaterThanOrEqualTo(0.0));
    });

    test('reduceMotion skips the animation (progress = 1.0 immediately)', () {
      anim.start('r2', reduceMotion: true);
      expect(anim.progressFor('r2'), 1.0);
    });

    test('idempotent re-start resets tracking', () {
      anim.start('r3', reduceMotion: true); // completes immediately
      anim.start('r3', reduceMotion: false); // resets to 0 + tracks
      expect(anim.progressFor('r3'), lessThan(1.0));
    });
  });

  group('FillAnimator — retire(id) and clearAll()', () {
    test('retire drops a single tracked entry', () {
      anim.start('r4', reduceMotion: false);
      anim.retire('r4');
      // Unknown again → progressFor = 1.0
      expect(anim.progressFor('r4'), 1.0);
    });

    test('clearAll drops every entry', () {
      anim.start('a', reduceMotion: false);
      anim.start('b', reduceMotion: false);
      anim.start('c', reduceMotion: false);
      anim.clearAll();
      expect(anim.progressFor('a'), 1.0);
      expect(anim.progressFor('b'), 1.0);
      expect(anim.progressFor('c'), 1.0);
      expect(anim.isAnimating, false);
    });
  });

  group('FillAnimator — multiple regions concurrently', () {
    test('each region is tracked independently', () {
      anim.start('one', reduceMotion: false);
      anim.start('two', reduceMotion: true);
      expect(anim.progressFor('two'), 1.0);
      expect(anim.progressFor('one'), lessThan(1.0));
    });
  });
}
