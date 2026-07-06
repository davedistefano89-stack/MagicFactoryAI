// =============================================================================
// Magic Colors · features/coloring/state/view_transform_controller.dart
// =============================================================================
//
// M2.1 — Pinch-zoom + 2-finger pan state, owned by [ColoringScreen].
//
// The Painter reads [matrix] on every frame and transforms the canvas
// before each draw call. A child can therefore pinch to draw fine
// detail without losing the page, and 2-finger drag pans around
// without disturbing the 1-finger paint stroke.
//
// RANGES (production-tuned for ages 3–8)
//   • min scale 0.5× — canvas still readable, never gets tiny
//   • max scale 4.0× — single-pixel precision cap; above this
//     paint hits jaggy sub-pixel rendering and kids get frustrated
//   • pan slack   75 % — at least 25 % of the canvas remains on
//     screen at any moment. A pinch-pan can never strand the page.
//
// LIFECYCLE
//   • resetView() restores identity (scale=1.0, translation=origin).
//   • setCanvasSize(Size) re-clamps translation to the new bounds
//     whenever LayoutBuilder fires (rotation, split-screen on tablet).
//
// REACTIVITY
//   • Every mutator fires one notifyListeners(). The painter's
//     [shouldRepaint] compares matrix equivalence so notifications
//     are idempotent — re-broadcasting the same matrix doesn't
//     trigger a redundant widget rebuild.
// =============================================================================

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart' show Matrix4, Offset, Size;

import 'package:magic_colors/core/utils/logger.dart';

/// Tuning constants. Public so tests can assert exact bounds.
abstract final class ViewTransformConfig {
  const ViewTransformConfig._();

  /// Smallest zoom — below this templates become too small to read.
  static const double minScale = 0.5;

  /// Largest zoom — above this strokes look jaggy.
  static const double maxScale = 4.0;

  /// Fraction of the (scaled) canvas that may slide off the leading
  /// edge during pan. 0.0 = strict full-canvas-on-screen (boring),
  /// 1.0 = no constraint (kids can fling the canvas away entirely).
  static const double panSlack = 0.75;
}

/// The view-side transform applied to the painter. Scale around the
/// focal point keeps the world point under the user's fingers pinned
/// to the same screen position across the scale change.
final class ViewTransformController extends ChangeNotifier {
  ViewTransformController({Size canvasSize = Size.zero}) {
    _setCanvasSize(canvasSize);
  }

  Size _canvasSize = Size.zero;
  double _scale = 1.0;
  Offset _translation = Offset.zero;

  /// Playtest polish — latch used so a pinch clamped to the
  /// min / max zoom fires the boundary haptic ONCE per "attempt"
  /// rather than on every move event (which would saturate the
  /// haptic engine and feel like a buzzer stuck on).
  bool _emitClampedHaptic = false;

  // ── Read model ────────────────────────────────────────────────────────
  double get scale => _scale;
  Offset get translation => _translation;
  Size get canvasSize => _canvasSize;

  bool get isIdentity => _scale == 1.0 && _translation == Offset.zero;

  /// Composited matrix, order = scale-around-origin AFTER translate.
  /// Identity-order:  translate → scale → draw-in-canvas-coords.
  /// Order chosen so finger-anchored scaling stays intuitive: the
  /// world point at (translation + scale·point) maps to (point).
  Matrix4 get matrix => Matrix4.identity()
    ..translate(_translation.dx, _translation.dy)
    ..scale(_scale, _scale);

  // ── Mutators ──────────────────────────────────────────────────────────
  /// Updates the canvas size and re-clamps the current translation
  /// to keep it within the new bounds. Safe at every LayoutBuilder pass.
  void setCanvasSize(Size size) {
    if (size == _canvasSize) {
      return;
    }
    _setCanvasSize(size);
    notifyListeners();
  }

  void _setCanvasSize(Size size) {
    _canvasSize = size;
    _translation = _clampTranslation(_translation);
  }

  /// Scale by [factor] anchored at [focalPointScreen]. No-op when
  /// the resulting scale hits min/max bounds — fires ONE light
  /// haptic per "kid zoomed past the limit" so the system feels
  /// responsive instead of silently stalling.
  void scaleAroundFocalPoint({
    required double factor,
    required Offset focalPointScreen,
  }) {
    final double prev = _scale;
    final double next = (prev * factor).clamp(
      ViewTransformConfig.minScale,
      ViewTransformConfig.maxScale,
    );
    if (next == prev) {
      // Clamped — emit ONE boundary haptic, then suppress until
      // the user retreats back into the active zoom range.
      if (!_emitClampedHaptic) {
        unawaited(HapticFeedback.lightImpact());
        _emitClampedHaptic = true;
      }
      return;
    }
    // Real motion happened — re-arm the latch so the next clamp
    // attempt can fire again.
    _emitClampedHaptic = false;
    // World point under the focal — pre-scale.
    final double worldX = (focalPointScreen.dx - _translation.dx) / _scale;
    final double worldY = (focalPointScreen.dy - _translation.dy) / _scale;
    _scale = next;
    // Re-anchor: under the new scale, place the same world point at
    // the same screen point.
    _translation = _clampTranslation(Offset(
      focalPointScreen.dx - worldX * _scale,
      focalPointScreen.dy - worldY * _scale,
    ));
    logger.debug(
      'ViewTransformController.scaleAroundFocalPoint factor=$factor '
      '→ scale=$_scale',
    );
    notifyListeners();
  }

  /// Add [deltaScreen] to the current translation, clamped.
  void pan(Offset deltaScreen) {
    if (deltaScreen == Offset.zero) {
      return;
    }
    final Offset next = _clampTranslation(_translation + deltaScreen);
    if (next == _translation) {
      return;
    }
    _translation = next;
    notifyListeners();
  }

  /// Restores identity. No-op when already at identity so a "tap to
  /// recentre" chord does not generate spurious repaints.
  void resetView() {
    if (isIdentity) {
      return;
    }
    _scale = 1.0;
    _translation = Offset.zero;
    logger.info('ViewTransformController.resetView');
    notifyListeners();
  }

  /// [candidate] = a pre-clamp translation. Returns the in-bounds
  /// translation that keeps ≥ 25 % of the canvas on screen at any
  /// axis. Works on any non-zero canvas size; returns [candidate]
  /// unchanged when size is zero (we let the LayoutBuilder clamp on
  /// the first non-zero pass).
  Offset _clampTranslation(Offset candidate) {
    if (_canvasSize == Size.zero) {
      return candidate;
    }
    const double slack = ViewTransformConfig.panSlack;
    final double scaledW = _canvasSize.width * _scale;
    final double scaledH = _canvasSize.height * _scale;
    final double minX = -scaledW * slack;
    final double minY = -scaledH * slack;
    final double maxX = scaledW * (1.0 - slack);
    final double maxY = scaledH * (1.0 - slack);
    return Offset(
      candidate.dx.clamp(minX, maxX),
      candidate.dy.clamp(minY, maxY),
    );
  }

  @override
  void dispose() {
    logger.info('ViewTransformController.dispose');
    super.dispose();
  }
}
