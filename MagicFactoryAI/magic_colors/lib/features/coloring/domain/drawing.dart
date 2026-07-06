// =============================================================================
// Magic Colors · features/coloring/domain/drawing.dart
// =============================================================================
//
// Top-level document persisted in the `drawings` Hive Box<dynamic>.
// All field indices MUST stay stable across releases — bumping an index
// silently deserialises the wrong field on older data.
//
// FIELD WIRING (@HiveField)
//   0  id              — stable uuid for the drawing (also Hive key)
//   1  worldId         — slug of the world this drawing belongs to
//   2  templateGlyph   — large emoji that anchors the page (Unicorn, etc.)
//   3  name            — human-readable title (defaults to "Untitled")
//   4  createdAt       — DateTime at first save
//   5  updatedAt       — DateTime at last save
//   6  LEGACY strokes  — append-only DrawingStroke list. Retained for
//                        backward-compat hydrate; new writes go to
//                        field 9 `commands`. The ad-hoc serializer reads
//                        `commands` when present, falls back to wrapping
//                        `strokes` otherwise.
//   7  paletteRevision — bumps when palette_catalog changes; lets
//                        older drawings fall back gracefully
//   8  isDraft         — true while the screen is open; flipped to false
//                        when the user exits clean
//   9  commands        — M2.2 sealed union (List<PaintCommand>) of every
//                        paintable entry: drawing strokes + flood fills.
//                        Nullable: pre-M2.2 drawings have null. Hydrate
//                        via `commandsFromStrokes(legacy)`.
//
// MIGRATION POLICY (M2.2)
//   On read: if `commands != null` → use as-is. Otherwise derive
//   `commands = strokes.map(DrawStroke.new).toList()` so M0/M1
//   drawings remain playable in M2.2 without an explicit migration
//   pass. On next save the controller writes back with `commands`,
//   locking in the migration.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import 'drawing_stroke.dart';
import 'paint_command.dart';

/// Immutable snapshot of one in-progress or saved drawing.
@immutable
class Drawing {
  /// Empty-drawing factory used when the user lands on `/coloring/:id`
  /// and the repo doesn't find an existing drawing for that id.
  ///
  /// [id] is the URL-supplied id passed by the controller — keeping it as
  /// a parameter (rather than minting a new one) ensures that a reload of
  /// the same URL hits the same box entry.
  factory Drawing.fresh({
    required String id,
    required String worldId,
    required String templateGlyph,
    required String name,
    required int paletteRevision,
  }) {
    final DateTime now = DateTime.now();
    return Drawing(
      id: id,
      worldId: worldId,
      templateGlyph: templateGlyph,
      name: name,
      createdAt: now,
      updatedAt: now,
      paletteRevision: paletteRevision,
      isDraft: true,
      commands: const <PaintCommand>[],
    );
  }
  const Drawing({
    required this.id,
    required this.worldId,
    required this.templateGlyph,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.paletteRevision,
    required this.isDraft,
    this.strokes = const <DrawingStroke>[],
    this.commands,
  });

  /// Stable uuid — also used as the Hive box key (`box.put(id, drawing)`).
  final String id;

  /// World slug (e.g. `unicorn_valley`). Keeps the gallery grouping
  /// stable across renames — we group by slug, not by display title.
  final String worldId;

  /// Anchoring emoji drawn faintly behind the user's strokes on the
  /// canvas (e.g. 🦄 for unicorn_valley). Empty string for a blank
  /// gallery drawing.
  final String templateGlyph;

  /// Player-facing name. Default: "Untitled". Edited in the top bar.
  final String name;

  /// First-save timestamp. Never mutated afterwards.
  final DateTime createdAt;

  /// Touched on every save. Drives the "last edited 5 min ago" chip.
  final DateTime updatedAt;

  /// LEGACY M0/M1 field. Retained for backward-compat. New writes
  /// route through [commands] (HiveField 9). Read via [legacyStrokes].
  final List<DrawingStroke> strokes;

  /// M2.2 sealed union over every paintable command. Nullable so
  /// pre-M2.2 drawings hydrate cleanly. Read via [effectiveCommands].
  final List<PaintCommand>? commands;

  /// Palette revision stamp. Lets older drawings fall back to a
  /// default palette when the live one moves ahead of it.
  final int paletteRevision;

  /// True until the screen is dismissed cleanly. Lets an explicit "save
  /// on exit" flow distinguish in-flight edits from committed ones.
  final bool isDraft;

  /// Deprecated stroke-count read for callers that pre-date M2.2.
  /// M2.2 callers should use [effectiveCommands].length instead.
  int get strokeCount => strokes.length;

  /// Returns the list of commands to render + undo against. If
  /// [commands] is null (legacy drawing) the legacy [strokes] are
  /// wrapped into [DrawStroke] commands on the fly. The wrapped list
  /// is NOT cached — callers needing cache should hydrate once with
  /// [hydrate].
  List<PaintCommand> get effectiveCommands {
    if (commands != null) {
      return commands!;
    }
    return commandsFromStrokes(strokes);
  }

  /// Returns a copy with selected fields replaced. Used by
  /// `ColoringController` after each save.
  Drawing copyWith({
    List<DrawingStroke>? strokes,
    List<PaintCommand>? commands,
    String? name,
    DateTime? updatedAt,
    bool? isDraft,
  }) {
    return Drawing(
      id: id,
      worldId: worldId,
      templateGlyph: templateGlyph,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      strokes: strokes ?? this.strokes,
      commands: commands ?? this.commands,
      paletteRevision: paletteRevision,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  /// Forces the [commands] list to materialise if it isn't yet. Wraps
  /// [strokes] into [DrawStroke]s on first call and returns a new
  /// Drawing instance with [commands] populated. Subsequent calls
  /// return the drawing unchanged.
  Drawing hydrate() {
    if (commands != null) {
      return this;
    }
    if (strokes.isEmpty) {
      return copyWith(commands: const <PaintCommand>[]);
    }
    return copyWith(commands: commandsFromStrokes(strokes));
  }
}

/// Wraps a legacy [strokes] list into a uniform [DrawStroke] command
/// list. M2.2 undo/redo operates on this list directly.
List<PaintCommand> commandsFromStrokes(List<DrawingStroke> strokes) {
  if (strokes.isEmpty) return const <PaintCommand>[];
  return List<PaintCommand>.unmodifiable(
    strokes.map(DrawStroke.new),
  );
}
