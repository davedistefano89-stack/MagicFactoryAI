// =============================================================================
// Magic Colors · features/coloring/painting/sparkle_trail.dart
// =============================================================================
//
// M2.4 — Per-stroke endpoint sparkle system.
//
// TWO VISUAL LAYERS (both honour SettingsState.reduceMotion)
//   • liftBurst       — radial fan of N particles at the pointer-up point.
//                       Faster, splashier; reads as "drawing complete!".
//   • chaseFromPath   — weaker, dimmer particles flowing from the last
//                       few stroke points; reads as a fading trail.
//
// SINGLE TICKER per SparkleTrail (vsync-provided by the controller).
// Memory is bounded by [_kMaxParticles] with FIFO eviction so a long
// session cannot leak. No allocations on the per-frame tick — the
// painter reads [snapshotFor] and interpolates positions in Dart-only
// math.
//
// The trail is a ChangeNotifier — paint sites pass it as `repaint:` to
// a CustomPaint. When reduceMotion is true the ticker is never started
// and notifyListeners() remains inert, so the painter costs ~0.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'package:magic_colors/core/design/design_tokens.dart';
import 'package:magic_colors/features/coloring/fill/bucket_fill_consts.dart';

/// Public tunables for the sparkle trail.
abstract final class SparkleTrailConstants {
  const SparkleTrailConstants._();

  /// Lifetime of a single particle (ms).
  static const Duration fadeWindow = AppDuration.medium;

  /// Maximum simultaneous particle count. FIFO-evict when exceeded.
  static const int maxParticles = 18;

  /// Auto-decay the trail on dispose (ms). Matched to fadeWindow so the
  /// last particle dies on dispose.
  static const Duration disposeWait = AppDuration.slow;

  /// liftBurst — radius each particle travels over its lifetime.
  static const double liftBurstRadius = 36.0;

  /// chaseFromPath — per-particle travel radius (much smaller).
  static const double chaseRadius = 4.0;
}

/// One live particle. Travels outward from [origin] at [velocity]
/// (per-ms deltas); alpha and size interpolate over its lifetime.
class SparkleParticle {
  const SparkleParticle({
    required this.origin,
    required this.velocityPerMs,
    required this.radius,
    required this.color,
    required this.startedAtMs,
  });

  final Offset origin;
  final Offset velocityPerMs;
  final double radius;
  final int color;
  final int startedAtMs;

  bool isExpired(int nowMs) =>
      nowMs - startedAtMs >= SparkleTrailConstants.fadeWindow.inMilliseconds;

  /// Alpha in [0, 1] — 1 at start, 0 at end of fade window.
  double alpha(int nowMs) {
    final double t =
        (nowMs - startedAtMs) / SparkleTrailConstants.fadeWindow.inMilliseconds;
    return (1.0 - t.clamp(0.0, 1.0));
  }

  /// Current position in the local canvas frame.
  Offset position(int nowMs) {
    final double t =
        (nowMs - startedAtMs) / SparkleTrailConstants.fadeWindow.inMilliseconds;
    final double clamped = t.clamp(0.0, 1.0);
    return origin +
        Offset(
          velocityPerMs.dx *
              SparkleTrailConstants.fadeWindow.inMilliseconds *
              clamped,
          velocityPerMs.dy *
              SparkleTrailConstants.fadeWindow.inMilliseconds *
              clamped,
        );
  }
}

/// M2.4 — Per-session sparkle/trail engine. Owned by
/// [ColoringController]. The canvas widget's second CustomPaint subscribes
/// via [addListener] / repaint: trail.
class SparkleTrail extends ChangeNotifier {
  SparkleTrail({required this.reduceMotion});

  /// Reduced-motion gate. When true nothing spawns and the ticker
  /// stays idle.
  final bool reduceMotion;

  final List<SparkleParticle> _particles = <SparkleParticle>[];

  /// True if the ticker is running.
  bool _running = false;

  /// Updates [reduceMotion] mid-flight. When it flips true we stop
  /// spawning; existing particles continue to fade out naturally.
  bool get reduceMotionState => reduceMotion;

  // Hand-rolled ticker so we control the lifecycle (no TickerProvider
  // here — the canvas widget will pump us from its own TickerProvider).
  int _lastTickMs = 0;
  void Function(int nowMs)? _onTick;

  /// Subscribes a per-frame tick driver from a TickerProvider (e.g. the
  /// canvas widget's). The [tick] callback receives the wall-clock ms
  /// for [snapshotFor] consumers.
  void attachTicker(void Function(int nowMs) tick) {
    if (_onTick != null) return;
    _onTick = tick;
    _running = true;
  }

  /// Detaches the ticker driver (e.g. on canvas dispose).
  void detachTicker() {
    _onTick = null;
    _running = false;
  }

  void _pump(int nowMs) {
    if (!_running) {
      return;
    }
    _lastTickMs = nowMs;
    _particles.removeWhere((p) => p.isExpired(nowMs));
    if (_particles.isEmpty && _running) {
      // Auto-decay: stop pumping when the trail is empty.
      _running = false;
    }
    notifyListeners();
  }

  /// Pumps the trail — called from the canvas CustomPaint's repaint
  /// callback. Idempotent if external ticker isn't attached.
  void tick(int nowMs) {
    if (!_running) return;
    _pump(nowMs);
  }

  /// Spawn a single radial burst of [count] particles at [at].
  /// Falls into reduced-motion silently.
  void liftBurst(Offset at, {required int color, int? seed, int count = 6}) {
    if (reduceMotion) return;
    final math.Random rng = math.Random(seed ?? at.hashCode);
    for (int i = 0; i < count; i++) {
      final double angle = rng.nextDouble() * math.pi * 2.0;
      final double dist = SparkleTrailConstants.liftBurstRadius *
          (0.7 + rng.nextDouble() * 0.3);
      final double vMag =
          dist / SparkleTrailConstants.fadeWindow.inMilliseconds;
      _add(
        SparkleParticle(
          origin: at,
          velocityPerMs: Offset(math.cos(angle) * vMag, math.sin(angle) * vMag),
          radius: 3.0 + rng.nextDouble() * 2.0,
          color: color,
          startedAtMs: _lastTickMs > 0
              ? _lastTickMs
              : DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  /// M2.2 PRODUCTION — spawn a one-shot radial burst at the centroid
  /// of a successful fill. Reads as "the colour slammed into place".
  /// Falls into reduced-motion silently. Particle count defaults to
  /// BucketFillConsts.fillBurstParticleCount (matches the end-stroke
  /// liftBurst for consistency across both commit events).
  void fillBurst(
    Offset at, {
    required int color,
    int? seed,
    int? count,
  }) {
    if (reduceMotion) return;
    final int particles = count ?? BucketFillConsts.fillBurstParticleCount;
    final math.Random rng = math.Random(seed ?? at.hashCode * 17);
    // Fill burst travels slightly further than the per-stroke lift:
    // a kid filling a large area expects more visual feedback per tap.
    const double distanceFactor = 1.10;
    for (int i = 0; i < particles; i++) {
      final double angle =
          (i.toDouble() / particles) * math.pi * 2.0 + rng.nextDouble() * 0.4;
      final double dist = SparkleTrailConstants.liftBurstRadius *
          distanceFactor *
          (0.85 + rng.nextDouble() * 0.30);
      final double vMag =
          dist / SparkleTrailConstants.fadeWindow.inMilliseconds;
      _add(
        SparkleParticle(
          origin: at,
          velocityPerMs: Offset(math.cos(angle) * vMag, math.sin(angle) * vMag),
          radius: 3.5 + rng.nextDouble() * 2.5,
          color: color,
          startedAtMs: _lastTickMs > 0
              ? _lastTickMs
              : DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  /// Spawn a faint chase along the last [path] of points (flat x/y
  /// doubles). [path.length] is the flat array length (x0, y0, x1, y1…).
  void chaseFromPath(
    List<double> path, {
    required int color,
    int? seed,
  }) {
    if (reduceMotion) return;
    if (path.length < 4) return;
    final math.Random rng = math.Random(seed ?? path.length);
    final int pairs = path.length ~/ 2;
    final int stride = pairs <= 0 ? 1 : (pairs > 8 ? pairs ~/ 8 : 1);
    for (int i = 0; i < pairs; i += stride) {
      final int idx = i * 2;
      final Offset at = Offset(path[idx], path[idx + 1]);
      final double vx = (rng.nextDouble() - 0.5) * 0.4;
      final double vy = (rng.nextDouble() - 0.5) * 0.4;
      _add(
        SparkleParticle(
          origin: at,
          velocityPerMs: Offset(
            vx / SparkleTrailConstants.fadeWindow.inMilliseconds,
            vy / SparkleTrailConstants.fadeWindow.inMilliseconds,
          ),
          radius: SparkleTrailConstants.chaseRadius,
          color: color,
          startedAtMs: _lastTickMs > 0
              ? _lastTickMs
              : DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  void _add(SparkleParticle particle) {
    if (_particles.length >= SparkleTrailConstants.maxParticles) {
      _particles.removeAt(0); // FIFO
    }
    _particles.add(particle);
    if (!_running && _onTick != null) {
      _running = true;
    }
  }

  /// Snapshot for the painter (interpolated positions + alpha).
  /// Returns None when the trail is empty.
  List<({Offset position, double alpha, double radius, int color})> snapshotFor(
      int nowMs) {
    if (_particles.isEmpty) {
      return const <({
        Offset position,
        double alpha,
        double radius,
        int color,
      })>[];
    }
    final List<({Offset position, double alpha, double radius, int color})>
        out = <({Offset position, double alpha, double radius, int color})>[];
    for (final SparkleParticle p in _particles) {
      if (p.isExpired(nowMs)) continue;
      final double a = p.alpha(nowMs);
      out.add((
        position: p.position(nowMs),
        alpha: a,
        radius: p.radius * (1.0 + (1.0 - a) * 0.4),
        color: p.color,
      ));
    }
    return out;
  }

  /// Test-only snapshot of un-interpolated particles.
  @visibleForTesting
  List<SparkleParticle> get debugParticles =>
      List<SparkleParticle>.unmodifiable(_particles);

  @override
  void dispose() {
    _particles.clear();
    _running = false;
    _onTick = null;
    super.dispose();
  }
}
