// =============================================================================
// Magic Colors · features/coloring/domain/enums.dart
// =============================================================================
//
// BrushType — the seven kid-facing brush kinds. Stored as `int` in
// HiveDrawingStroke (`brushTypeIndex`) rather than as the enum directly,
// because enum adapter ordering is brittle when an entry is inserted in
// the middle of the list. The `index` getter is the canonical surface;
// `fromIndex` is the safe reader with a clamp.
//
// M2.3 APPENDED
//   • pencil (index 6) — thin textured line, duplication-resistant
//     faint seed noise gives a hand-drawn pencil feel without
//     expensive per-pixel shaders. Dark ink only.
// =============================================================================

/// The brush kinds. Order matters for storage: NEVER insert a new
/// kind between the existing entries — append at the end and bump the
/// palette revision in `palette_catalog.dart` so older strokes decode
/// gracefully instead of reading a wrong brush.
enum BrushType {
  /// Standard rounded kid brush — solid Paint with strokeCap=round.
  round,

  /// Low-alpha flat-tip brush. Slight overlap suggests marker ink.
  marker,

  /// Rough / textured. Points are jittered; double thin pass for grain.
  crayon,

  /// Distance-paced sparkle particles along the stroke path.
  sparkle,

  /// Clears the underlying pixels (blendMode=clear). Reveals the
  /// AnimatedBackground sitting underneath the canvas.
  eraser,

  /// Smart flood fill — M2.2. Tap a region to spread the selected
  /// colour across all connected pixels of the tapped colour. Treated
  /// as a TAP tool (no drag accumulation) by the canvas state machine.
  fill,

  /// Pencil — M2.3. Thin dark line with random per-point jitter and a
  /// faint noise seed overlay. Matches a real pencil's slight uneven
  /// width. Append-only.
  pencil,
}
