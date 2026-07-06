// =============================================================================
// Magic Colors · features/coloring/fill/fill_animator.dart
// =============================================================================
//
// M2.2 PRODUCTION — 60-fps fade-in + initial alpha flash for newly-
// committed fill regions. Each fill gets progress = 0..1 driven by a
// Ticker; the painter reads `progressFor(id)` and multiplies the
// region alpha by `progress`. The first `_kFlashMicroseconds` of the
// timer additionally contribute a half-alpha punch so the user
// immediately sees "the colour slammed into place" before the
// elegant ease-out takes over.
//
// WIDGET USE
//   The [FillAnimator] is owned by the controller once a region
//   commits. The painter obtains the progress via the listenable.
//
// CURVE
//   AppCurves.fillIn (Cubic easeOut) — first-derivative is high at
//   t=0 (snappy initial speed) and falls off as t → 1 (graceful
//   settle). Matches the "PoP!" feel called out in M2.2 production
//   requirements child-friendly animation timing.
//
// FLASH
//   Discrete 0.65 alpha snap for the first 60 ms, multiplied onto
//   the fade-in progress. The painter's paint path OR's the two so
//   the flash reads as a "led zeppelin flashbulb" without fighting
//   the easing curve.
//
// REDUCE-MOTION
//   When [reduceMotion] is true at commit time, the animation is
//   skipped (every region paints at full opacity immediately). The
//   state still records progress = 1 so the painter's
//   "in-progress-region" check returns false and the listenable
//   can be retired early.
// =============================================================================

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/scheduler.dart' show Ticker, TickerProvider;
import 'package:flutter/widgets.dart' show Curves;

import 'package:magic_colors/core/design/design_tokens.dart' show AppDuration;
import 'package:magic_colors/core/utils/logger.dart';
import 'bucket_fill_consts.dart';

/// Owns the per-region fade-in animations. One instance per
/// ColoringController lifecycle. Constructed once.
final class FillAnimator extends ChangeNotifier {
  FillAnimator({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
  }

  /// Animation duration, sourced from the design tokens to keep the
  /// feel consistent with every other "in" transition in the app.
  static const Duration _kAnimationDuration = AppDuration.fillIn;

  /// Flash window microseconds. Inline (not via AppDuration) so it
  /// can be tuned independently of the fade-in.
  static const int _kFlashMicroseconds = BucketFillConsts.fillFlashMs * 1000;

  /// Slim Slack above progress=1.0 — the painter occasionally needs
  /// progress=1.001 to clamp to exactly 1.0 without floating-point
  /// drift on the last frame.
  static const double _kSlack = 0.0001;

  /// Active ticker — pauses when no region needs animating.
  late final Ticker _ticker;

  /// Active region ids + their progress + start times.
  final Map<String, _Entry> _entries = <String, _Entry>{};

  /// Listener firing count, useful for test diagnostics.
  int notifyCount = 0;

  /// M2.2 PRODUCTION — true iff at least one region currently has a
  /// fade-in IN PROGRESS. A reduce-motion short-circuit writes a
  /// completed entry to the map (so `progressFor` and `isFlashing`
  /// still resolve) but that entry is NOT actively animating, so it
  /// does NOT contribute to `isAnimating`. Semantically the flag
  /// means "is the listener firing on tick frames?" — completed
  /// entries never tick.
  bool get isAnimating => _entries.values.any((_Entry e) => !e.completed);

  /// Returns the progress (0..1) for [regionId]. Returns 1.0 when
  /// the animation has completed (or no longer tracked). The painter
  /// reads this every frame.
  ///
  /// M2.2 PRODUCTION — also returns the discrete flash bool. The
  /// painter OR's the flash onto the fade-in alpha for the first
  /// 60 ms after commit.
  double progressFor(String regionId) {
    final entry = _entries[regionId];
    if (entry == null) {
      return 1.0;
    }
    return entry.progress;
  }

  /// True iff the region should render the discrete half-alpha
  /// flash for one extra paint pass. False once the fade-in is its
  /// sole signal. Painter reads this alongside `progressFor`.
  bool isFlashing(String regionId) {
    final entry = _entries[regionId];
    if (entry == null) return false;
    return entry.flashing;
  }

  /// Begins the fade-in for a newly-committed region. [reduceMotion]
  /// toggles the animation off (regions paint at full opacity
  /// immediately). Idempotent: a second call for the same region
  /// restarts the fade-in (M2.4 redo celebration pathway).
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
      // M2.2 PRODUCTION — early-return on completed entries so the
      // reduce-motion short-circuit ([_Entry.completed()] with
      // flashing=false) is never overwritten by a later tick.
      if (e.completed) {
        e.flashing = false;
        return;
      }
      final int deltaMicros = (now - e.startMicros);
      final double t =
          (deltaMicros / _kAnimationDuration.inMicroseconds).clamp(0.0, 1.0);
      final double eased = Curves.easeOutCubic.transform(t);
      e.progress = eased;
      e.flashing = deltaMicros < _kFlashMicroseconds;
      if (eased < 1.0 - _kSlack) {
        any = true;
      } else {
        e.progress = 1.0;
        e.flashing = false;
        e.completed = true;
      }
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
  _Entry({required this.startMicros})
      : progress = 0.0,
        flashing = true,
        completed = false;
  _Entry.completed()
      : startMicros = 0,
        progress = 1.0,
        flashing = false,
        completed = true;

  final int startMicros;
  double progress;
  bool flashing;
  bool completed;
}

/// Lightweight stub that logs when the animator is initialised — useful
/// in dev for timing-recording sessions.
void debugLogAnimatorStartup() {
  logger.debug('FillAnimator constructed');
}
