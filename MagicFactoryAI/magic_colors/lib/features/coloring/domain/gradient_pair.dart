// =============================================================================
// Magic Colors · features/coloring/domain/gradient_pair.dart
// =============================================================================
//
// M2.3 — 2-stop linear gradient value object used by the Bucket-Fill
// tool. Lives in `domain/` because it has no UI dependency; the
// painter reads it to instantiate a `ui.Gradient.linear` shader at
// commit-time.
//
// GRADIENT DIRECTION (initial MVP)
// -------------------------------
//   Always top → bottom within the FillRegion's bounding box. A
//   direction picker is deliberately deferred to M2.4 polish so the
//   brief "Gradient preparation" ships a kid-friendly vanilla mode
//   without overloading the picker.
//
// ACTIVE STATE
// -----------
//   The controller toggles between {OFF} (single colour) and
//   {ON: pair(a, b)}. When OFF, every commit behaves exactly like
//   M2.2 (single ALPHA-multiplied colour). When ON, the painter
//   instantiates `ui.Gradient.linear(top → bottom)` at the region's
//   bounds and applies that as the Paint shader.
//
// HIVE PERSISTENCE
// ----------------
//   Not persisted as a part of the region — gradients are a
//   session-only affordance. Persistence ships in M2.4 after we
//   collect telemetry on how often kids reach for it.
// =============================================================================

import 'package:flutter/painting.dart' show Color;
import 'package:flutter/foundation.dart' show immutable;

import '../data/palette_catalog.dart';

/// Immutable 2-colour gradient. Disabled by default — `enabled=false`
/// means "paint with single colour b" so the controller API stays
/// trivially backwards-compatible with the M2.2 fill flow.
@immutable
final class GradientPair {
  /// Convenience: returns a disabled pair from any single ARGB int.
  const GradientPair.single(int value)
      : topColorValue = value,
        bottomColorValue = value,
        enabled = false;

  /// Convenience: returns a 2-stop pair from two ARGB ints.
  const GradientPair.two(int a, int b)
      : topColorValue = a,
        bottomColorValue = b,
        enabled = true;

  /// Convenience: returns a 2-stop pair with the top stop swapped
  /// for [newTop] while preserving the bottom stop from [previous].
  /// Used by the controller when the user re-selects a colour
  /// while gradient mode is enabled — keeps the bottom stop sticky
  /// so the picker doesn't reset both stops on every tap.
  // Not const — previous.bottomColorValue and previous.enabled
  // are runtime values, not compile-time constants.
  GradientPair.topOnly({
    required int newTop,
    required GradientPair previous,
  })  : topColorValue = newTop,
        bottomColorValue = previous.bottomColorValue,
        enabled = previous.enabled;

  const GradientPair({
    required this.topColorValue,
    required this.bottomColorValue,
    this.enabled = true,
  });

  /// Disables the gradient — the painter reads `b` only. Kept in
  /// the type so the controller can flip the toggle without losing
  /// the user's last colour picks.
  const GradientPair.disabled({
    required int single,
  })  : topColorValue = single,
        bottomColorValue = single,
        enabled = false;

  /// ARGB packed int (`Color.value`) for the top stop.
  final int topColorValue;

  /// ARGB packed int for the bottom stop.
  final int bottomColorValue;

  /// False ⇒ render as single-colour fill using [bottomColorValue].
  final bool enabled;

  GradientPair.defaultPair()
      : topColorValue =
            PaletteCatalog.colors[14].value, // ignore: deprecated_member_use
        bottomColorValue =
            PaletteCatalog.colors[5].value, // ignore: deprecated_member_use
        enabled = true;

  /// True iff the two colour stops differ (or the toggle is on).
  /// Painter callers use this to short-circuit single-colour draws.
  bool get isTwoStop => enabled && topColorValue != bottomColorValue;

  /// Returns the live [Color] for the top stop — handy for the
  /// picker chevron markers.
  Color get topColor => Color(topColorValue);

  /// Returns the live [Color] for the bottom stop.
  Color get bottomColor => Color(bottomColorValue);

  @override
  bool operator ==(Object other) {
    if (other is! GradientPair) {
      return false;
    }
    return other.topColorValue == topColorValue &&
        other.bottomColorValue == bottomColorValue &&
        other.enabled == enabled;
  }

  @override
  int get hashCode => Object.hash(topColorValue, bottomColorValue, enabled);
}
