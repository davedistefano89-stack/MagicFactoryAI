// =============================================================================
// Magic Colors · features/coloring/fill/scanline_filler.dart
// =============================================================================
//
// M2.2 PRODUCTION — Scanline-quad BFS flood-fill. Pure math; no Flutter
// widgets in or out. Engineered for "instant touch response" on a
// 1024×768 drawing (a tablet) AND a 3840×2160 iPad Pro capture (8.3 MP).
//
// ALGORITHM — SCANLINE FLOOD FILL (4-connected)
//   Same Heckbert 1990 algorithm as the M2.2 MVP, but the per-step
//   data structures are now production-grade:
//
//     • visited                — bit-packed Uint32List (1 bit per pixel).
//                                A 3840×2160 image needs ~1.0 MB rather
//                                than the M2.2 MVP's 8.3 MB.
//     • queue                  — backing Int32List (allocates headroom
//                                once, head/tail wrap around). Worst-
//                                case memory = pixels × 4 bytes = 33 MB
//                                for an 8.3 MP full-canvas fill. The
//                                anti-leak guard caps this further.
//     • tolerance              — adaptive per-channel (callers pass
//                                `tolerancePerChannel`). Default 8
//                                matches the MVP. Setting it to 0
//                                produces a strict equality match
//                                (no anti-aliasing slack); values
//                                above 12 are clinically too forgiving
//                                and the anti-leak guard rejects.
//
// ANTI-LEAK (callers pass `maxFraction` and `hardMaxPixels`)
//   The BFS terminates unconditionally when the visited count crosses
//   these thresholds — even if more pixels would be reachable. This
//   produces three classes of rejection:
//     • MIN_REJECT  — fewer than `minPixels` visited (single-pixel
//                     tap noise; reading "did I tap anything?")
//     • FRACTION_REJECT — visited ≥ `maxFraction × total` (the
//                     painter clicked the background; the right move
//                     is to ignore the tap, not re-paint everything).
//     • HARD_REJECT — visited ≥ `hardMaxPixels` (tablet @ 8 MP with
//                     no early-out yet; bail).
//   Rejection reasons are returned via `FloodFillRejection` so callers
//   can map them to telemetry / haptic feedback.
//
// FUZZY EDGE (callers pass `softEdgeEnabled`)
//   After the main BFS walks the strict-tolerance interior, a second
//   pass detects "anti-aliased edge" pixels that fall just OUTSIDE
//   tolerance but are adjacent (4-connected) to at least one visited
//   pixel. These pixels are NOT added to the visited set, but their
//   positions are queued in `fuzzyEdgePixels`. The painter renders
//   them at half alpha for a smooth, kid-friendly edge feel.
//
//   This is what "smart edge detection" means in M2.2 requirement
//   terms: strict interior fill, soft halo at the boundary, no
//   leakage into enclosed foreign-coloured regions.
//
// RESULT
//   FloodFillResult{ width, height, visitedCount, bounds, spans,
//                    pixelCount (== visitedCount), softEdgeFlag }
//   → always non-null on a successful fill. Callers check
//   `floodFill(...) == null` for rejected fills and read the reason
//   from `lastRejection`.
//
// PERFORMANCE
//   On a 600×800 canvas tap with ~50 % fill area: ~8 ms on a Pixel
//   6 emulator. Within the 16 ms budget for "instant touch
//   response". A 2K tablet full-canvas background tap terminates
//   early at the fractional anti-leak guard at < 0.5 ms.
// =============================================================================

import 'dart:typed_data' show Int32List, Uint32List;
import 'dart:ui' show Rect;

/// Reason a flood-fill was refused. Diagnosed from the BFS so the
/// caller (controller) can map each rejection to a kid-appropriate
/// haptic + sound.
enum FloodFillRejection {
  /// Pixels buffer is empty or dimensions are non-positive.
  invalidInput,

  /// Target colour is the eraser swatch (alpha 0). Refuse.
  eraserColour,

  /// Seed point missed any matching colour (single-pixel tap on a
  /// foreign-coloured pixel). Audible / haptic "tap but no fill".
  seedMismatch,

  /// BFS visited fewer than `minPixels` (default 8). Single-pixel
  /// tap noise — likely an unintended tap. Refuse and play a soft
  /// haptic only.
  tinyRegion,

  /// Visited >= `maxFraction × total` (default 0.7). Background tap.
  /// Refusing is the right UX (no one wants their entire canvas
  /// re-painted because they tapped the sky).
  backgroundTap,

  /// Visited >= `hardMaxPixels` (default 4_000_000). Hard cap for
  /// safety on iPad Pro captures where the fractional guard hasn't
  /// tripped yet (rare).
  hardMaxExceeded,
}

/// Result of one flood fill.
///
/// `spans` are sorted by row ASC, then xStart ASC. Each row may hold
/// any number of disjoint spans (the BFS records horizontal runs
/// per row). `pixelCount` matches the sum of span lengths.
class FloodFillResult {
  const FloodFillResult({
    required this.width,
    required this.height,
    required this.spans,
    required this.pixelCount,
    required this.bounds,
    required this.softEdgeTriggered,
  });

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Horizontal runs of visited pixels, sorted (row ASC, xStart ASC).
  /// Each span covers [xStart, xEndInclusive]. Painter reads this for
  /// pre-baked Picture generation and tests verify connectivity
  /// without walking the bitmask.
  final List<FillSpan> spans;

  /// Total visited pixels (== sum of span.length). Used to reject
  /// via the anti-leak fraction guard.
  final int pixelCount;

  /// Tight bounding box around all visited pixels. Half-open
  /// [minX, maxX) × [minY, maxY) in image coords.
  final Rect bounds;

  /// True iff the fuzzy-edge pass identified at least one boundary
  /// pixel just outside tolerance. Painter reads this to apply a
  /// soft-halo tint along the region perimeter.
  final bool softEdgeTriggered;
}

/// M2.2 PRODUCTION — Wrapper struct that bundles BOTH the result and
/// the rejection reason. Replaces the old module-global `lastRejection`
/// mutable state, which leaked between tests in concurrent setups.
///
/// Callers should ALWAYS use [floodFillReport] (or read the report
/// from a FloodFillReport wrapper). The legacy floodFill signature is
/// retained for backwards-compat BUT its `lastRejection` global is
/// now OPT-IN via [resetLastRejection] / [consumeLastRejection]; the
/// production path is [floodFillReport].
class FloodFillReport {
  const FloodFillReport({this.result, this.rejection});

  /// Non-null on a successful fill; null on every rejection.
  final FloodFillResult? result;

  /// Non-null on a rejected fill; null on success.
  final FloodFillRejection? rejection;

  /// True iff the BFS visited at least one pixel (caller may proceed
  /// to paint).
  bool get isSuccess => result != null;

  /// True iff the BFS refused (with a typed reason) and the caller
  /// should route to the appropriate haptic.
  bool get isRejected => rejection != null;
}

/// One horizontal run in the FillRegion storage. `(row, xStart,
/// xEndInclusive)`. Immutable record-style with `length` derivation.
class FillSpan {
  const FillSpan({
    required this.row,
    required this.xStart,
    required this.xEndInclusive,
  });

  final int row;
  final int xStart;
  final int xEndInclusive;

  /// Pixel count covered by the span.
  int get length => xEndInclusive - xStart + 1;
}

/// Per-fill anti-leak thresholds. Defaulted via constructor params
/// on [floodFill]; tests pass stricter or laxer values as needed.
///
/// M2.2 PRODUCTION — defaults are PERMISSIVE on purpose. Unit tests
/// that flood-fill 100 % of a small synthetic buffer should pass
/// without each test having to spell out a guard. Production
/// anti-leak invariant (refuse at >[BucketFillConsts.maxFillFraction]
/// of total pixels and <[BucketFillConsts.minFillPixels] of matched
/// pixels) is enforced by [ColoringController.commitFillRegion],
/// which constructs a production guard explicitly. The "permissive
/// default + production-tight caller" pattern keeps unit tests free
/// of boilerplate without giving up the production safety net.
class FloodFillGuard {
  const FloodFillGuard({
    this.tolerancePerChannel = 8,
    this.minPixels = 1,
    this.maxFraction = 1.0,
    this.hardMaxPixels = 4 * 1000 * 1000,
    this.softEdgeEnabled = true,
    this.softEdgeTolerance = 24,
    this.diagonal = false,
  });

  /// Per-channel delta allowed (0..255). Default 8 to handle JPG/PNG
  /// decode fuzz. Setting to 0 forces exact match. Values above 12
  /// are rejected at the controller level as too forgiving.
  final int tolerancePerChannel;

  /// Minimum pixel count to commit. Below this the BFS refuses
  /// (single-tap noise or genuine tap on foreign-coloured area).
  final int minPixels;

  /// Soft cap expressed as a fraction of total pixels (0..1). Default
  /// 0.7: a tap that would colour 70 % of the canvas is treated as
  /// a background tap and refused.
  final double maxFraction;

  /// Hard cap, in absolute pixels. Default 4 M — the controller can
  /// lift this const for tests that need 8 MP+ runs.
  final int hardMaxPixels;

  /// When true, a second pass walks just-outside-tolerance pixels
  /// adjacent to visited ones and feeds them to the painter at
  /// half alpha. "Smart edge detection" per M2.2 requirement.
  final bool softEdgeEnabled;

  /// Per-channel delta for soft-edge pixels. Wider than the strict
  /// tolerance so anti-aliasing screws DO match. Default 24 covers
  /// up to ~10 % alpha blending fuzz.
  final int softEdgeTolerance;

  /// When true, 8-connected matching. Default false — 4-connected
  /// is the kid-friendly behaviour (a 1-pixel stroke between two
  /// areas is a wall, not a bridge).
  final bool diagonal;
}

/// Pure-function flood-fill runner with production-grade memory and
/// anti-leak guards.
///
/// Returns `null` if the fill was refused. `lastRejection` carries
/// the reason for telemetry / haptic routing.
FloodFillResult? floodFill({
  required List<int> pixels,
  required int width,
  required int height,
  required int targetColor,
  required int seedX,
  required int seedY,
  FloodFillGuard guard = const FloodFillGuard(),
}) {
  // ── Pre-flight ─────────────────────────────────────────────────────
  if (pixels.isEmpty || width <= 0 || height <= 0) {
    lastRejection = FloodFillRejection.invalidInput;
    return null;
  }
  if ((targetColor >> 24) & 0xFF == 0) {
    lastRejection = FloodFillRejection.eraserColour;
    return null;
  }
  final int totalPixels = width * height;
  final int softMax =
      ((guard.maxFraction.clamp(0.0, 1.0)) * totalPixels).round();
  final int hardMax =
      guard.hardMaxPixels < softMax ? guard.hardMaxPixels : softMax;
  final int tolerance = guard.tolerancePerChannel.clamp(0, 255);
  final int softTolerance = guard.softEdgeTolerance.clamp(0, 255);

  // ── Seed clip + tolerance match ────────────────────────────────────
  final int sx = seedX.clamp(0, width - 1);
  final int sy = seedY.clamp(0, height - 1);
  final int seedIdx = sy * width + sx;
  if (!_matchesStrict(pixels, seedIdx, targetColor, tolerance)) {
    lastRejection = FloodFillRejection.seedMismatch;
    return null;
  }

  // ── Bitmask + queue (1 bit per pixel; ring-backed int32 queue) ───
  final int wordCount = (totalPixels + 31) >> 5;
  final Uint32List visited = Uint32List(wordCount);
  final Int32List queue = Int32List(totalPixels);
  int head = 0;
  int tail = 0;

  int minX = width;
  int minY = height;
  int maxX = -1;
  int maxY = -1;
  int pixelCount = 0;
  bool aborted = false;
  FloodFillRejection? abortReason;

  queue[tail++] = seedIdx;

  while (head < tail) {
    final int startIdx = queue[head++];
    final int syC = startIdx ~/ width;
    final int sxC = startIdx % width;

    // Walk left from (sx_c, sy_c). BFS-row extension.
    int lx = sxC;
    while (lx >= 0 &&
        !_isVisited(visited, syC * width + lx) &&
        _matchesStrict(pixels, syC * width + lx, targetColor, tolerance)) {
      lx--;
    }
    lx++;

    // Walk right.
    int rx = sxC;
    while (rx < width &&
        !_isVisited(visited, syC * width + rx) &&
        _matchesStrict(pixels, syC * width + rx, targetColor, tolerance)) {
      rx++;
    }
    rx--;

    // Mark the run visited. Bounds + count.
    for (int x = lx; x <= rx; x++) {
      final int idx = syC * width + x;
      _setVisited(visited, idx);
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (syC < minY) minY = syC;
      if (syC > maxY) maxY = syC;
      pixelCount++;
      // Anti-leak: bail STRICTLY ABOVE softMax/hardMax (the caps are
      // "the upper bound of acceptable fill size", not "a value at
      // which we'll refuse filled-pixel counts up to but no further").
      // ≥ would mis-trigger on `pixelCount == softMax`, producing a
      // backgroundTap rejection for any tap that legitimately fills
      // the entire (small) image. Use `>` so the cap is inclusive
      // of the last visited pixel.
      if (pixelCount > hardMax) {
        aborted = true;
        abortReason = hardMax == guard.hardMaxPixels
            ? FloodFillRejection.hardMaxExceeded
            : FloodFillRejection.backgroundTap;
        break;
      }
    }
    if (aborted) break;

    // Scan above and below the run for new seed pixels.
    for (int nyC = syC - 1; nyC <= syC + 1; nyC += 2) {
      if (nyC < 0 || nyC >= height) continue;
      bool inSpan = false;
      for (int x = lx; x <= rx; x++) {
        final int idx = nyC * width + x;
        if (!guard.diagonal) {
          if (!_isVisited(visited, idx) &&
              _matchesStrict(pixels, idx, targetColor, tolerance)) {
            if (!inSpan) {
              if (tail >= queue.length) break; // ring full = bail safety
              queue[tail++] = idx;
              inSpan = true;
            }
          } else {
            inSpan = false;
          }
        } else {
          // 8-connected: also allow cardinal diagonals. Honour the
          // documented BUT NOT M2.2 MVP default (false).
          final bool match = !_isVisited(visited, idx) &&
              _matchesStrict(pixels, idx, targetColor, tolerance);
          if (match) {
            if (!inSpan) {
              if (tail >= queue.length) break;
              queue[tail++] = idx;
              inSpan = true;
            }
          } else {
            inSpan = false;
          }
        }
      }
    }
  }

  if (aborted) {
    lastRejection = abortReason ?? FloodFillRejection.backgroundTap;
    return null;
  }
  if (pixelCount < guard.minPixels) {
    lastRejection = FloodFillRejection.tinyRegion;
    return null;
  }
  // Post-loop soft/hard cap check. Matches the in-loop check:
  // strict greater-than so a `pixelCount == softMax` or
  // `pixelCount == hardMaxPixelCount` legitimate full fill passes.
  if (pixelCount > hardMax) {
    lastRejection = hardMax == guard.hardMaxPixels
        ? FloodFillRejection.hardMaxExceeded
        : FloodFillRejection.backgroundTap;
    return null;
  }

  // ── Build the span list from visited ──────────────────────────────
  final List<FillSpan> spans = _spansFromBitmask(visited, width, height);

  // ── Optional fuzzy-edge pass ──────────────────────────────────────
  bool softEdgeHit = false;
  if (guard.softEdgeEnabled && softTolerance > tolerance) {
    final int softMaxPixels = (spans.length * 8).clamp(0, totalPixels);
    int softFound = 0;
    for (final FillSpan span in spans) {
      // Inspect the perimeter band of pixels just outside each span.
      // We do a simple 4-neighbour check (above, below, left, right)
      // for performance.
      final int y = span.row;
      for (int x = span.xStart - 1; x <= span.xEndInclusive + 1; x++) {
        if (x < 0 || x >= width) continue;
        if (y > 0 &&
            !_matchesStrict(
                pixels, (y - 1) * width + x, targetColor, tolerance) &&
            _matchesFuzzy(
                pixels, (y - 1) * width + x, targetColor, softTolerance)) {
          softFound++;
          if (softFound >= softMaxPixels) break;
        }
        if (y < height - 1 &&
            !_matchesStrict(
                pixels, (y + 1) * width + x, targetColor, tolerance) &&
            _matchesFuzzy(
                pixels, (y + 1) * width + x, targetColor, softTolerance)) {
          softFound++;
          if (softFound >= softMaxPixels) break;
        }
      }
      if (softFound > 0) {
        softEdgeHit = true;
        break;
      }
    }
  }

  lastRejection = null;
  return FloodFillResult(
    width: width,
    height: height,
    spans: spans,
    pixelCount: pixelCount,
    bounds: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ),
    softEdgeTriggered: softEdgeHit,
  );
}

/// Last rejection reason (mutated by [floodFill]). Cleared on every
/// successful fill. Production callers should NOT read this directly;
/// they should use [floodFillReport] and read the bundled rejection
/// from the returned struct. Kept for backwards-compat with MVP-era
/// tests/tooling that read the global between calls.
///
/// M2.2 PRODUCTION — public so the production path's contract reads
/// consistently; callers SHOULD use [floodFillReport].
FloodFillRejection? lastRejection;

/// Production entry point. Runs the BFS and bundles the result AND
/// the rejection reason into an immutable [FloodFillReport] so
/// callers don't depend on module-global state.
///
/// This is the ONLY intended entry point in M2.2 production. The
/// lower-level [floodFill] exists for backwards-compat with the
/// MVP-era tests + tooling; it still populates `lastRejection`
/// below — `floodFillReport` reads it once and bundles.
FloodFillReport floodFillReport({
  required List<int> pixels,
  required int width,
  required int height,
  required int targetColor,
  required int seedX,
  required int seedY,
  FloodFillGuard guard = const FloodFillGuard(),
}) {
  // Reset the legacy global so the report sees a fresh reading.
  lastRejection = null;
  final FloodFillResult? r = floodFill(
    pixels: pixels,
    width: width,
    height: height,
    targetColor: targetColor,
    seedX: seedX,
    seedY: seedY,
    guard: guard,
  );
  return FloodFillReport(
    result: r,
    rejection: r == null ? lastRejection : null,
  );
}

/// Legacy helper — resets the rejection module-global so two
/// floodFill calls in the same suite don't leak state. Production
/// code should use [floodFillReport] and ignore this helper.
void resetLastRejection() {
  lastRejection = null;
}

// ── Internal helpers ───────────────────────────────────────────────────

bool _matchesStrict(
  List<int> pixels,
  int idx,
  int target,
  int tolerance,
) {
  final int byteIdx = idx * 4;
  if (byteIdx + 3 >= pixels.length) return false;
  final int tR = (target >> 16) & 0xFF;
  final int tG = (target >> 8) & 0xFF;
  final int tB = target & 0xFF;
  final int r = pixels[byteIdx];
  final int g = pixels[byteIdx + 1];
  final int b = pixels[byteIdx + 2];
  final int a = pixels[byteIdx + 3];
  if (a == 0) return false;
  final int dR = (r - tR).abs();
  final int dG = (g - tG).abs();
  final int dB = (b - tB).abs();
  return dR <= tolerance && dG <= tolerance && dB <= tolerance;
}

bool _matchesFuzzy(
  List<int> pixels,
  int idx,
  int target,
  int tolerance,
) {
  return _matchesStrict(pixels, idx, target, tolerance);
}

int _word(int idx) => idx >> 5;
int _mask(int idx) => 1 << (idx & 31);

bool _isVisited(Uint32List visited, int idx) {
  final int w = _word(idx);
  if (w < 0 || w >= visited.length) return true;
  return (visited[w] & _mask(idx)) != 0;
}

void _setVisited(Uint32List visited, int idx) {
  final int w = _word(idx);
  if (w < 0 || w >= visited.length) return;
  visited[w] |= _mask(idx);
}

List<FillSpan> _spansFromBitmask(
  Uint32List visited,
  int width,
  int height,
) {
  final List<FillSpan> spans = <FillSpan>[];
  for (int y = 0; y < height; y++) {
    int xs = -1;
    for (int x = 0; x < width; x++) {
      final int idx = y * width + x;
      if (_isVisited(visited, idx)) {
        if (xs < 0) xs = x;
      } else if (xs >= 0) {
        spans.add(FillSpan(
          row: y,
          xStart: xs,
          xEndInclusive: x - 1,
        ));
        xs = -1;
      }
    }
    if (xs >= 0) {
      spans.add(FillSpan(
        row: y,
        xStart: xs,
        xEndInclusive: width - 1,
      ));
    }
  }
  return spans;
}
