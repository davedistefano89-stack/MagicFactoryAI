// =============================================================================
// Magic Colors · test/unit/coloring/gradient_pair_test.dart
// =============================================================================
//
// Unit tests for GradientPair.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/domain/gradient_pair.dart';

void main() {
  group('GradientPair.single', () {
    test('isTwoStop is false on a disabled single-colour pair', () {
      const p = GradientPair.single(0xFFFF0000);

      expect(p.enabled, isFalse);
      expect(p.isTwoStop, isFalse);
      expect(p.topColorValue, 0xFFFF0000);
      expect(p.bottomColorValue, 0xFFFF0000);
    });

    test('topColor + bottomColor return live Color instances', () {
      const p = GradientPair.single(0xFF00FF00);

      expect(p.topColor.r, 0);
      expect(p.topColor.g, 1.0);
      expect(p.topColor.b, 0);
      expect(p.topColor.a, 1.0);

      expect(p.bottomColor.r, 0);
      expect(p.bottomColor.g, 1.0);
      expect(p.bottomColor.b, 0);
      expect(p.bottomColor.a, 1.0);
    });
  });

  group('GradientPair.two', () {
    test('isTwoStop is true when two distinct colours', () {
      const p = GradientPair.two(
        0xFFFF0000,
        0xFF0000FF,
      );

      expect(p.enabled, isTrue);
      expect(p.isTwoStop, isTrue);
      expect(p.topColorValue, 0xFFFF0000);
      expect(p.bottomColorValue, 0xFF0000FF);
    });

    test('isTwoStop is false when the two colours match', () {
      const p = GradientPair.two(
        0xFFFF0000,
        0xFFFF0000,
      );

      expect(p.enabled, isTrue);
      expect(p.isTwoStop, isFalse);
    });
  });

  group('GradientPair.defaultPair', () {
    test('is a two-stop pair referencing palette colours', () {
      final p = GradientPair.defaultPair();

      expect(p.enabled, isTrue);
      expect(p.isTwoStop, isTrue);
      expect(p.topColorValue, isNot(equals(p.bottomColorValue)));
    });
  });

  group('GradientPair equality + hashCode', () {
    test('two pairs with identical stops compare equal', () {
      const a = GradientPair.two(
        0xFFAABBCC,
        0xFFDDEEFF,
      );

      const b = GradientPair.two(
        0xFFAABBCC,
        0xFFDDEEFF,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('pairs differing in the enabled flag are not equal', () {
      const a = GradientPair.single(0xFFAABBCC);
      const b = GradientPair.two(
        0xFFAABBCC,
        0xFFAABBCC,
      );

      expect(a, isNot(equals(b)));
    });

    test('pairs differing in stops are not equal', () {
      const a = GradientPair.two(
        0xFFAABBCC,
        0xFF112233,
      );

      const b = GradientPair.two(
        0xFFAABBCC,
        0xFF445566,
      );

      expect(a, isNot(equals(b)));
    });
  });
}
