// =============================================================================
// Magic Colors · tests/unit/coloring/parent_gate_flow_test.dart
// =============================================================================
//
// M2.4 — focused unit tests for the ParentGate surface. Validates:
//   • default state — mathNotOk + failureLocked=false → kind = math
//   • math success → kind = hold
//   • failure records stamp + keeps kind = math for 24 h
//   • hold success is a no-op reservation (won't crash, no-op writes)
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/data/hive_keys.dart';
import 'package:magic_colors/core/state/player_state.dart';
import 'package:hive/hive.dart';

void main() {
  group('ParentGate state machine', () {
    late Box<dynamic> box;

    setUp(() async {
      Hive.init('./.hive_parent_gate_test');
      box = await Hive.openBox<dynamic>('parent_gate_test');
      await box.clear();
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('parent_gate_test');
    });

    test('default state selects math challenge', () {
      final PlayerState p = PlayerState.fromBox(box);
      expect(p.parentGateMathOk, isFalse);
      expect(p.parentGateFailureLocked, isFalse);
      expect(p.parentGateKind(), ParentGateKind.math);
      p.dispose();
    });

    test('math success flips kind to hold', () {
      final PlayerState p = PlayerState.fromBox(box);
      p.recordParentGateMathSuccess();
      expect(p.parentGateMathOk, isTrue);
      expect(p.parentGateLastFailureAt, isNull);
      expect(p.parentGateKind(), ParentGateKind.hold);
      p.dispose();
    });

    test('math failure locks gate for 24 h and reverts to math', () {
      final PlayerState p = PlayerState.fromBox(box);
      p.recordParentGateMathSuccess(); // first pass
      expect(p.parentGateKind(), ParentGateKind.hold);
      p.recordParentGateMathFailure();
      expect(p.parentGateMathOk, isFalse);
      expect(p.parentGateLastFailureAt, isNotNull);
      expect(p.parentGateFailureLocked, isTrue);
      expect(p.parentGateKind(), ParentGateKind.math);
      p.dispose();
    });

    test('hold-success is idempotent on math state', () {
      final PlayerState p = PlayerState.fromBox(box);
      p.recordParentGateHoldSuccess();
      expect(p.parentGateMathOk, isFalse);
      expect(p.parentGateKind(), ParentGateKind.math);
      p.dispose();
    });

    test('math success persists across PlayerState instances', () {
      final PlayerState p1 = PlayerState.fromBox(box);
      p1.recordParentGateMathSuccess();
      p1.dispose();
      final PlayerState p2 = PlayerState.fromBox(box);
      expect(p2.parentGateMathOk, isTrue);
      expect(p2.parentGateKind(), ParentGateKind.hold);
      p2.dispose();
    });

    test('failure stamp persists across PlayerState instances', () {
      final PlayerState p1 = PlayerState.fromBox(box);
      p1.recordParentGateMathFailure();
      p1.dispose();
      final PlayerState p2 = PlayerState.fromBox(box);
      expect(p2.parentGateMathOk, isFalse);
      expect(p2.parentGateLastFailureAt, isNotNull);
      expect(p2.parentGateFailureLocked, isTrue);
      p2.dispose();
    });

    test('math success after failure clears the lock', () {
      final PlayerState p = PlayerState.fromBox(box);
      p.recordParentGateMathFailure();
      expect(p.parentGateFailureLocked, isTrue);
      p.recordParentGateMathSuccess();
      expect(p.parentGateFailureLocked, isFalse);
      expect(p.parentGateMathOk, isTrue);
      p.dispose();
    });
  });

  // Sanity check — the hive_keys constants exist and match.
  group('hive_keys M2.4', () {
    test('ParentGate keys exist', () {
      expect(hiveKeyParentGateMathOk, 'player.parentGateMathOk');
      expect(
        hiveKeyParentGateLastFailureAt,
        'player.parentGateLastFailureAt',
      );
    });
  });
}
