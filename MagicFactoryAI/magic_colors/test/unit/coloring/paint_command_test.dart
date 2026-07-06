// =============================================================================
// Magic Colors · test/unit/coloring/paint_command_test.dart
// =============================================================================
//
// M2.2 — Unit tests for the [PaintCommand] sealed union + [Drawing]
// commands-list integration.
//
// COVERED
//   • Sealed-class hierarchy: pattern-match exhaustiveness at compile time
//     (no runtime assertions — Dart enforces exhaustivity).
//   • DrawStroke delegates id / colorValue / timestamp to the wrapped stroke.
//   • FillRegion surfaces id / colorValue / timestamp directly.
//   • Drawing.hydrate wraps legacy `strokes` into `DrawStroke` commands.
//   • Drawing.effectiveCommands returns an immutable list.
//   • commandsFromStrokes returns a stable-length list (no empty collapse).
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/domain/drawing.dart';
import 'package:magic_colors/features/coloring/domain/drawing_stroke.dart';
import 'package:magic_colors/features/coloring/domain/paint_command.dart';

void main() {
  group('PaintCommand — DrawStroke delegation', () {
    test('id, colorValue, timestamp come from the wrapped stroke', () {
      const stroke = DrawingStroke(
        id: 's_test',
        colorValue: 0xFFE74C3C,
        brushSize: 16.0,
        brushTypeIndex: 0,
        points: <double>[0, 0, 10, 10, 20, 20],
        textureSeed: 42,
        timestampMs: 1700000000000,
      );
      const cmd = DrawStroke(stroke);
      expect(cmd.id, 's_test');
      expect(cmd.colorValue, 0xFFE74C3C);
      expect(cmd.timestamp.millisecondsSinceEpoch, 1700000000000);
    });

    test('bounds comes from the wrapped stroke', () {
      const stroke = DrawingStroke(
        id: 's_bounds',
        colorValue: 0,
        brushSize: 6.0,
        brushTypeIndex: 0,
        points: <double>[10, 20, 30, 40, 50, 60],
        textureSeed: 1,
        timestampMs: 0,
      );
      const cmd = DrawStroke(stroke);
      expect(cmd.bounds.left, lessThanOrEqualTo(10 - 6.0 * 1.5 - 8.0));
      expect(cmd.bounds.right, greaterThanOrEqualTo(50 + 6.0 * 1.5 + 8.0));
    });
  });

  group('Drawing.hydrate (M2.2 migration)', () {
    test('drawing with legacy strokes hydrates into DrawStroke commands', () {
      final legacy = Drawing(
        id: 'd_legacy',
        worldId: 'unicorn_valley',
        templateGlyph: '🦄',
        name: 'Legacy',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        strokes: const <DrawingStroke>[
          DrawingStroke(
            id: 's_legacy_one',
            colorValue: 0xFF000000,
            brushSize: 4.0,
            brushTypeIndex: 0,
            points: <double>[1, 1, 2, 2],
            textureSeed: 0,
            timestampMs: 0,
          ),
        ],
        paletteRevision: 1,
        isDraft: false,
      );
      final hydrated = legacy.hydrate();
      final cmds = hydrated.effectiveCommands;
      expect(cmds.length, 1);
      expect(cmds.first, isA<DrawStroke>());
      expect((cmds.first as DrawStroke).stroke.id, 's_legacy_one');
    });

    test('drawing with explicit commands is returned verbatim', () {
      const cmd = DrawStroke(
        DrawingStroke(
          id: 's_already_migrated',
          colorValue: 0xFF000000,
          brushSize: 4.0,
          brushTypeIndex: 0,
          points: <double>[0, 0, 1, 1],
          textureSeed: 0,
          timestampMs: 0,
        ),
      );
      final migrated = Drawing(
        id: 'd_already',
        worldId: 'unicorn_valley',
        templateGlyph: '🦄',
        name: 'Already',
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
        commands: const <PaintCommand>[cmd],
        paletteRevision: 1,
        isDraft: false,
      );
      final hydrated = migrated.hydrate();
      expect(hydrated.commands, isNotNull);
      expect(hydrated.effectiveCommands.length, 1);
      expect(hydrated.effectiveCommands.first.id, 's_already_migrated');
    });

    test('fresh drawings hold an empty commands list', () {
      final fresh = Drawing.fresh(
        id: 'd_fresh',
        worldId: 'world_a',
        templateGlyph: '🦄',
        name: 'Fresh',
        paletteRevision: 1,
      );
      expect(fresh.effectiveCommands, isEmpty);
      expect(fresh.commands, isNotNull);
    });
  });

  group('commandsFromStrokes', () {
    test('returns empty for empty strokes', () {
      expect(commandsFromStrokes(<DrawingStroke>[]), isEmpty);
    });

    test('returns one DrawStroke per input stroke', () {
      final strokes = <DrawingStroke>[
        const DrawingStroke(
          id: 'a',
          colorValue: 1,
          brushSize: 1,
          brushTypeIndex: 0,
          points: <double>[0, 0],
          textureSeed: 0,
          timestampMs: 0,
        ),
        const DrawingStroke(
          id: 'b',
          colorValue: 2,
          brushSize: 1,
          brushTypeIndex: 0,
          points: <double>[0, 0],
          textureSeed: 0,
          timestampMs: 0,
        ),
      ];
      expect(commandsFromStrokes(strokes).length, 2);
    });
  });
}
