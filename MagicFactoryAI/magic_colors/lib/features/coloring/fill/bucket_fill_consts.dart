// =============================================================================
// Magic Colors · features/coloring/fill/bucket_fill_consts.dart
// =============================================================================
//
// M2.2 PRODUCTION — Tuning constants for the bucket-fill pipeline.
// Lives in `features/coloring/fill/` (next to [scanline_filler] and
// [fill_animator]) so they travel together; surfaced as a single
// `abstract final` so widgets + tests can reference them without
// dragging each other's import surface.
//
// WHAT LIVES HERE
//   • Anti-leak thresholds (defaults handled by [FloodFillGuard]).
//   • Pulse-train selection (how multiple consecutive fills stack).
//   • Soft-edge policy (when the painter renders the half-alpha halo).
//   • Cache sizing for FillPictureCache.
//   • Sparkle fill-burst sizing.
//
// NONE of these are mutable at runtime. They migrate via codebase
// search-only — change them here once, recompile, ship.
// =============================================================================

/// M2.2 PRODUCTION — tuning surface for the bucket-fill pipeline.
abstract final class BucketFillConsts {
  const BucketFillConsts._();

  // ── Anti-leak ─────────────────────────────────────────────────────────
  /// Hard upper bound on the number of pixels that one tap can colour
  /// before the BFS terminates regardless of remaining visits. The
  /// SoftMax via `maxFraction × total` is the first line of defence;
  /// this number is the safety net for iPad Pro captures. 4 M pixels
  /// ≈ 1.3-second render budget on a Pixel 6 emulator for a 0.66-second
  /// SPA (single paint attack) budget. A higher number is a hard
  /// regression on tap-to-result latency.
  static const int hardMaxFillPixels = 4 * 1000 * 1000;

  /// Fraction of total pixels that's a "background tap". A tap
  /// that would colour 70 % of the canvas is overwhelmingly likely
  /// to be a misclick on the negative space; politely refuse.
  static const double maxFillFraction = 0.70;

  /// Below this pixel count, refuse the fill (single-tap noise).
  /// 8 pixels is ~ a 2x2 stroke endpoint's bounding box.
  static const int minFillPixels = 8;

  // ── Edge detection ────────────────────────────────────────────────────
  /// Per-channel delta allowed for the strict match. Default 8 to
  /// handle JPG/PNG decode fuzz. Setting to 0 forces strict equality.
  static const int defaultTolerancePerChannel = 8;

  /// Wider delta for the soft-edge pass. Picks up anti-aliasing
  /// pixels that fail the strict tolerance but are visually
  /// adjacent.
  static const int defaultSoftEdgeTolerance = 24;

  // ── FillPictureCache ──────────────────────────────────────────────────
  /// Maximum number of fill Pictures cached simultaneously. At a
  /// maximum 12 fills per kid drawing × ≈120 KB Picture each = 1.4 MB
  /// peak. Generous enough for a complete level, tight enough that
  /// Memory-pressure triggers are welcome.
  static const int maxCachedFillPictures = 24;

  // ── Sparkle fill-burst ────────────────────────────────────────────────
  /// Number of particles in the radial burst on a successful fill.
  /// Six is the existing end-stroke liftBurst pattern; tests confirm
  /// it reads as a "PoP!" burst without crowding the canvas.
  static const int fillBurstParticleCount = 6;

  /// Maximum trail particle count (FIFO eviction). Same cap as
  /// end-stroke bursts — keeps the floor manageable for kids.
  static const int maxSparkleParticles = 18;

  // ── Child-friendly timing ─────────────────────────────────────────────
  /// Initial alpha snap (0..1) for the first 60 ms after commit.
  /// Reads as "the colour slammed into place" before the elegant
  /// ease-out takes over.
  static const double fillFlashAlpha = 0.65;

  /// Initial alpha snap window length. The painter OR's this onto
  /// the FillAnimator progress for the first 80 ms; after that it
  /// contributes 0. Widened from 60 → 80 ms so the kid tap reads as
  /// "the colour slammed into place" rather than a smooth fade.
  static const int fillFlashMs = 80;
}
