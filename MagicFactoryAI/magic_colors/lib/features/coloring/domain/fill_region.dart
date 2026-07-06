// =============================================================================
// Magic Colors · features/coloring/domain/fill_region.dart
// =============================================================================
//
// M2.2 — Factory helpers and lightweight payload constructors for
// [FillRegion]. The heavy lifting (BFS, mask storage) lives in
// `features/coloring/fill/scanline_filler.dart`. This file holds the
// uuid + canonical constructors so tests plus the controller can build
// well-formed regions without re-implementing the same boilerplate.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

/// Cheap uuid-v4-ish generator — same approach as Drawing/Stroke so
/// the format stays consistent across domain types.
String newFillRegionId() {
  final int nowMs = DateTime.now().microsecondsSinceEpoch;
  return 'f_${nowMs.toRadixString(16)}_${(nowMs * 31).toRadixString(16)}';
}

/// Lightweight view-only struct for callers (tests, telemetry) that
/// want to inspect a fill region's footprint without parsing the mask.
///
/// Prefer the [FillRegion] sealed-class form (`paint_command.dart`)
/// when persisting or commanding.
@immutable
class FillRegionSummary {
  const FillRegionSummary({
    required this.id,
    required this.colorValue,
    required this.filledPixelCount,
    required this.boundsWidth,
    required this.boundsHeight,
  });

  final String id;
  final int colorValue;
  final int filledPixelCount;
  final int boundsWidth;
  final int boundsHeight;
}
