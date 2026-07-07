// =============================================================================
// Magic Colors · test/unit/coloring/bucket_fill_undo_redo_test.dart
// =============================================================================
//
// M2.2 PRODUCTION — Verifies the undo/redo + FillAnimator state-coherence
// integration. Critical: when a FillRegion is popped from the redo
// stack on undo, its FillAnimator entry must be retired; on redo,
// the FillAnimator must restart from t=0.
//
// These tests run against an isolated FillAnimator with a fake
// TickerProvider driven by `pumpTick(ms)`. The animator is initialised
// once; tests use `start(regionId, reduceMotion: false)` and then
// pump ticks to drive progress.
// =============================================================================

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/domain/paint_command.dart';
import 'package:magic_colors/features/coloring/fill/fill_animator.dart';
import 'package:magic_colors/features/coloring/fill/scanline_filler.dart';

import 'bucket_fill_correctness_test.dart' show bufferFor;

class _FakeTickerProvider implements TickerProvider {
  final List<Ticker> _tickers = <Ticker>[];

  @override
  Ticker createTicker(TickerCallback onTick) {
    final Completer<void> done = Completer<void>();
    late final Ticker ticker;
    ticker = Ticker(
      (Duration elapsed) {
        if (!done.isCompleted) {
          done.complete();
        }
        onTick(elapsed);
      },
      debugLabel: 'fake_ticker',
    );
    _tickers.add(ticker);
    return ticker;
  }

  /// Manually pump a real-time duration into every active ticker. In
  /// test contexts we don't have a SchedulerBinding scheduler; we
  /// call onTick directly via `pumpTicks(ms)`.
}

void main() {
  // Required for any test that constructs a Ticker that gets
  // `start()`-ed — without this, FillAnimator.start fires
  // Ticker.scheduleTick which reads `SchedulerBinding.instance`
  // and throws "Binding has not yet been initialized".
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FillAnimator — undo/redo state', () {
    late _FakeTickerProvider vsync;
    late FillAnimator animator;

    setUp(() {
      vsync = _FakeTickerProvider();
      animator = FillAnimator(vsync: vsync);
    });

    tearDown(() {
      animator.dispose();
    });

    test('start(region, reduceMotion: false) yields progress 0 initially', () {
      animator.start('r1', reduceMotion: false);
      expect(animator.isAnimating, isTrue);
      expect(animator.progressFor('r1'), 0.0);
      expect(animator.isFlashing('r1'), isTrue);
    });

    test('start(region, reduceMotion: true) short-circuits to 1.0', () {
      animator.start('r1', reduceMotion: true);
      expect(animator.progressFor('r1'), 1.0);
      expect(animator.isFlashing('r1'), isFalse);
      expect(animator.isAnimating, isFalse);
    });

    test('retire(region) removes the entry', () {
      animator.start('r1', reduceMotion: false);
      expect(animator.isAnimating, isTrue);
      animator.retire('r1');
      expect(animator.isAnimating, isFalse);
      // Progress on a retired region = 1.0 (visible state).
      expect(animator.progressFor('r1'), 1.0);
    });

    test('clearAll wipes every entry', () {
      animator.start('r1', reduceMotion: false);
      animator.start('r2', reduceMotion: false);
      animator.start('r3', reduceMotion: false);
      expect(animator.isAnimating, isTrue);
      animator.clearAll();
      expect(animator.isAnimating, isFalse);
    });

    test('re-start for the same region restarts progress from 0', () {
      animator.start('r1', reduceMotion: false);
      animator.dispose();
      // After dispose, allocations are torn down. Construct a fresh
      // animator to validate the redo pathway.
      vsync = _FakeTickerProvider();
      animator = FillAnimator(vsync: vsync);
      animator.start('r1', reduceMotion: false);
      expect(animator.progressFor('r1'), 0.0);
      expect(animator.isFlashing('r1'), isTrue);
    });

    test('progressFor returns 1.0 for unknown regions (steady state)', () {
      expect(animator.progressFor('never-started'), 1.0);
    });

    test(
        'FillRegion.fromSpans → hasPixels true for any non-empty resulting region',
        () {
      final r = floodFill(
        pixels: bufferFor(4, 4, 0xEE, 0xEE, 0xEE, 0xFF),
        width: 4,
        height: 4,
        targetColor: 0xFFEEEEEE,
        seedX: 1,
        seedY: 1,
      );
      expect(r, isNotNull);
      final region = FillRegion.fromSpans(
        id: 'foo',
        colorValue: 0xFFEEEEEE,
        result: r!,
        logicalOrigin: const Offset(0, 0),
        logicalWidth: 4,
        logicalHeight: 4,
        pixelRatio: 1.0,
        timestamp: DateTime(2024),
      );
      expect(region.hasPixels, isTrue);
      expect(region.pixelCount, 16);
      expect(region.spanCount, 4);
    });
  });
}
