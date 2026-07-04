// =============================================================================
// Magic Colors · test/unit/coloring/gradient_pair_test.dart
// =============================================================================
//
// M2.3 — Unit tests for the GradientPair value object. Pure Dart, no
// Flutter widget binding required.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/features/coloring/domain/gradient_pair.dart';


void main() {
  group('GradientPair.single', () {
    test('isTwoStop is false on a disabled single-colour pair', () {
      final p = GradientPair.single(0xFFFF0000);
      expect(p.enabled, false);
      expect(p.isTwoStop, false);
      expect(p.topColorValue, 0xFFFF0000);
      expect(p.bottomColorValue, 0xFFFF0000);
    });

    test('topColor + bottomColor return live Color instances', () {
      final p = GradientPair.single(0xFF00FF00);
      expect(p.topColor.value, 0xFF00FF00);
      expect(p.bottomColor.value, 0xFF00FF00);
      expect(p.topColor.green, 0xFF);
      expect(p.topColor.alpha, 0xFF);
    });
  });

  group('GradientPair.two', () {
    test('isTwoStop is true when two distinct colours', () {
      final p = GradientPair.two(0xFFFF0000, 0xFF0000FF);
      expect(p.enabled, true);
      expect(p.isTwoStop, true);
      expect(p.topColorValue, 0xFFFF0000);
      expect(p.bottomColorValue, 0xFF0000FF);
    });

    test('isTwoStop is false when the two colours match', () {
      final p = GradientPair.two(0xFFFF0000, 0xFFFF0000);
      expect(p.enabled, true);
      expect(p.isTwoStop, false);
    });
  });

  group('GradientPair.defaultPair', () {
    test('is a two-stop pair referencing palette colours', () {
      final p = GradientPair.defaultPair;
      expect(p.enabled, true);
      expect(p.isTwoStop, true);
      expect(p.topColorValue, isNot(p.bottomColorValue));
    });
  });

  group('GradientPair equality + hashCode', () {
    test('two pairs with identical stops compare equal', () {
      final a = GradientPair.two(0xFFAABBCC, 0xFFDDEEFF);
      final b = GradientPair.two(0xFFAABBCC, 0xFFDDEEFF);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('pairs differing in the enabled flag are not equal', () {
      final a = GradientPair.single(0xFFAABBCC);
      final b = GradientPair.two(0xFFAABBCC, 0xFFAABBCC);
      expect(a, isNot(equals(b)));
    });

    test('pairs differing in stops are not equal', () {
      final a = GradientPair.two(0xFFAABBCC, 0xFF112233);
      final b = GradientPair.two(0xFFAABBCC, 0xFF445566);
      expect(a, isNot(equals(b)));
    });
  });
}
