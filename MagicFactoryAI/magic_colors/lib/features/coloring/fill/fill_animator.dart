// =============================================================================
// Magic Colors · features/coloring/fill/fill_animator.dart
// =============================================================================
//
// M2.2 — 60-fps fade-in for newly-committed fill regions. Each fill
// gets a progress = 0..1 driven by a Ticker; the painter reads the
// progress and multiplies the region alpha by `progress` until the
// fade-in completes (240 ms — matches `AppDuration.fillIn`).
//
// WIDGET USE
//   The [FillAnimator] is owned by the controller once a region
//   commits. The painter obtains the progress via the listenable.
//
// ALPHA CURVE
//   The default curve eases out (cubic-bezier(0.20, 0.00, 0.20, 1.00))
//   so the fill brightens quickly to ~80 % then drifts the last 20 %
//   into place — reads as "PoP!" on a kids' tablet without a slow
//   fade-in that would feel laggy.
//
// REDUCE-MOTION
//   When [reduceMotion] is true at commit time, the animation is
//   skipped (every region paints at full opacity immediately). The
//   state still records progress = 1 so the painter's
//   "in-progress-region" check returns false and we can retire
//   the listenable early.
// =============================================================================

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/scheduler.dart' show Ticker, TickerProvider;
import 'package:flutter/widgets.dart' show Curves;

import 'package:magic_colors/core/design/design_tokens.dart'
    show AppDuration;
import 'package:magic_colors/core/utils/logger.dart';


/// Owns the per-region fade-in animations. One instance per
/// ColoringController lifecycle. Constructed once.
final class FillAnimator extends ChangeNotifier {
  FillAnimator({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
  }

  /// Animation duration, sourced from the design tokens to keep the
  /// feel consistent with every other "in" transition in the app.
  static const Duration _kAnimationDuration = AppDuration.medium;

  /// Active ticker — pauses when no region needs animating.
  late final Ticker _ticker;

  /// Active region ids + their progress in (startTime, targetTime).
  final Map<String, _Entry> _entries = <String, _Entry>{};

  /// Listener firing count, useful for test diagnostics.
  int notifyCount = 0;

  /// True iff at least one region is mid-fade.
  bool get isAnimating => _entries.isNotEmpty;

  /// Returns the progress (0..1) for [regionId]. Returns 1.0 when
  /// the animation has completed (or no longer tracked). The painter
  /// reads this every frame.
  double progressFor(String regionId) {
    final entry = _entries[regionId];
    if (entry == null) {
      return 1.0;
    }
    return entry.progress;
  }

  /// Begins the fade-in for a newly-committed region. [reduceMotion]
  /// toggles the animation off (regions paint at full opacity
  /// immediately). [idempotent]: a second `start(...)` for the same
  /// region restarts the fade-in (useful for M2.4 redo celebrations).
  void start(String regionId, {required bool reduceMotion}) {
    if (reduceMotion) {
      _entries[regionId] = _Entry.completed();
      notifyListeners();
      return;
    }
    _entries[regionId] = _Entry(
      startMicros: DateTime.now().microsecondsSinceEpoch,
    );
    if (!_ticker.isActive) {
      _ticker.start();
    }
    notifyListeners();
  }

  /// Removes a region's animation entry. Called when the region is
  /// removed from the canvas (undo, redo into a prior state, etc.).
  void retire(String regionId) {
    if (_entries.remove(regionId) != null) {
      _maybeStopTicker();
      notifyListeners();
    }
  }

  /// Wipes every tracked entry. Used when the canvas is cleared.
  void clearAll() {
    if (_entries.isEmpty) return;
    _entries.clear();
    _maybeStopTicker();
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final int now = DateTime.now().microsecondsSinceEpoch;
    bool any = false;
    _entries.forEach((String id, _Entry e) {
      if (e.progress >= 1.0) return;
      final int deltaMicros = (now - e.startMicros);
      final double t = (deltaMicros / _kAnimationDuration.inMicroseconds)
          .clamp(0.0, 1.0);
      // Cubic ease-out: 1 - (1-t)^3.
      final double eased = 1 -
          math_max_zero(1 - t) *
              math_max_zero(1 - t) *
              math_max_zero(1 - t);
      e.progress = eased;
      if (eased < 1.0) any = true;
    });
    notifyCount++;
    notifyListeners();
    if (!any) {
      _maybeStopTicker();
    }
  }

  void _maybeStopTicker() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}


/// Internal record of one region's animation state.
class _Entry {
  _Entry({required this.startMicros}) : progress = 0.0;
  _Entry.completed() : startMicros = 0, progress = 1.0;

  final int startMicros;
  double progress;
}


/// Inline helper to keep the file tidy.
double math_max_zero(double v) {
  return v < 0 ? 0 : v;
}

/// Lightweight stub that logs when the animator is initialised — useful
/// in dev for timing-recording sessions.
void debugLogAnimatorStartup() {
  logger.debug('FillAnimator constructed');
}
