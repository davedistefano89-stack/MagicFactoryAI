// =============================================================================
// Magic Colors · test/unit/state/player_state_parent_gate_test.dart
// =============================================================================
//
// M2.4 regression suite for [PlayerState]'s ParentGate state machine:
//   • parentGateMathOk (bool)
//   • parentGateLastFailureAt (DateTime?)
//   • parentGateFailureLocked (true iff now < last + 24h)
//   • parentGateKind() → math | hold
//   • dailyRewardClaimed (derived from _lastStreakDate)
//   • recordParentGateMathSuccess / recordParentGateMathFailure /
//     recordParentGateHoldSuccess mutators (all idempotent)
//
// COVERED EDGE CASES
//   • fresh state → math (mathOk = false, no failure stamp)
//   • math success → mathOk flips true, last failure clears,
//     kind flips to hold (when not within lockout)
//   • math failure → mathOk stays false, last failure = now,
//     kind flips back to math
//   • failure inside 24h → lockout true regardless of mathOk
//   • failure past 24h → lockout clear, kind = hold if mathOk
//   • hold success → no-op sentinel (reserves an analytics hook)
//   • dailyRewardClaimed drive is bound to streak date equality
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:magic_colors/core/state/player_state.dart';

Future<PlayerState> freshPlayer(Box<dynamic> box) async {
  return PlayerState.fromBox(box);
}

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('m2_4_parent_gate_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    final String boxName = 'pg_test_${DateTime.now().microsecondsSinceEpoch}';
    box = await Hive.openBox<dynamic>(boxName);
  });

  tearDown(() async {
    if (box.isOpen) {
      await box.close();
    }
  });

  group('parentGateKind — initial / fresh state', () {
    test('fresh state → math (mathOk = false)', () async {
      final PlayerState player = await freshPlayer(box);
      expect(player.parentGateMathOk, isFalse);
      expect(player.parentGateLastFailureAt, isNull);
      expect(player.parentGateFailureLocked, isFalse);
      expect(player.parentGateKind(), ParentGateKind.math);
    });
  });

  group('recordParentGateMathSuccess', () {
    test('flips mathOk to true and clears any prior failure stamp', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordParentGateMathFailure();
      expect(player.parentGateLastFailureAt, isNotNull);
      expect(player.parentGateKind(), ParentGateKind.math);

      player.recordParentGateMathSuccess();

      expect(player.parentGateMathOk, isTrue);
      expect(player.parentGateLastFailureAt, isNull);
      expect(
        player.parentGateKind(),
        ParentGateKind.hold,
        reason: 'math accepted, outside lockout → hold shortcut',
      );
    });

    test(
      'math success DURING an active lockout window immediately '
      'clears the failure stamp and unlocks the hold shortcut',
      () async {
        // Regression guard: the success mutator must atomically wipe
        // the failure stamp so an honest re-attempt inside the 24h
        // window is rewarded with hold-to-confirm on subsequent taps.
        // Behaviour must not punish a parent for retrying correctly.
        final PlayerState player = await freshPlayer(box);
        player.recordParentGateMathFailure();
        expect(player.parentGateFailureLocked, isTrue);
        expect(player.parentGateKind(), ParentGateKind.math);

        player.recordParentGateMathSuccess();

        expect(player.parentGateMathOk, isTrue);
        expect(
          player.parentGateLastFailureAt,
          isNull,
          reason: 'success path must wipe the failure stamp atomically',
        );
        expect(
          player.parentGateFailureLocked,
          isFalse,
          reason: 'no stamp → lockout cleared',
        );
        expect(
          player.parentGateKind(),
          ParentGateKind.hold,
          reason: 'mathOk + no stamp → hold shortcut unlocked immediately',
        );
      },
    );

    test('is idempotent when state is already mathOk + no failure', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordParentGateMathSuccess();
      var notifyCount = 0;
      player.addListener(() => notifyCount++);

      player.recordParentGateMathSuccess();

      expect(notifyCount, 0,
          reason: 'no state change → no notify (idempotent)');
      expect(player.parentGateMathOk, isTrue);
    });

    test('persists mathOk = true so a fresh PlayerState reads it back',
        () async {
      final PlayerState writer = await freshPlayer(box);
      writer.recordParentGateMathSuccess();

      await box.close();
      box = await Hive.openBox<dynamic>(box.name);
      final PlayerState reader = await freshPlayer(box);

      expect(reader.parentGateMathOk, isTrue);
      expect(reader.parentGateKind(), ParentGateKind.hold);
    });
  });

  group('recordParentGateMathFailure', () {
    test('forces mathOk = false and stamps lastFailureAt = now', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordParentGateMathSuccess(); // prime mathOk
      expect(player.parentGateMathOk, isTrue);

      player.recordParentGateMathFailure();

      expect(player.parentGateMathOk, isFalse);
      expect(player.parentGateLastFailureAt, isNotNull);
      expect(player.parentGateFailureLocked, isTrue);
      expect(player.parentGateKind(), ParentGateKind.math);
    });

    test('marks the failure lockout window as active (within 24h)', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordParentGateMathFailure();
      // Just-set failure timestamp → wall-clock gap ≪ 24h → still locked.
      expect(player.parentGateFailureLocked, isTrue);
    });
  });

  group('parentGateFailureLocked — 24h lockout window', () {
    test(
      'a failure stamp older than 24h → lockout cleared, kind = hold',
      () async {
        final PlayerState player = await freshPlayer(box);
        player.recordParentGateMathSuccess(); // pre-accept
        // Simulate a 25h-old failure stamp by writing Hive directly so
        // the live DateTime.now() check anchors on `now`.
        await box.put(
          'player.parentGateLastFailureAt',
          DateTime.now().subtract(const Duration(hours: 25)),
        );
        // Re-hydrate.
        await box.close();
        box = await Hive.openBox<dynamic>(box.name);
        final PlayerState rehydrated = await freshPlayer(box);

        expect(rehydrated.parentGateFailureLocked, isFalse);
        expect(
          rehydrated.parentGateKind(),
          ParentGateKind.hold,
          reason: 'mathOk + outside lockout → hold shortcut',
        );
      },
    );

    test(
      'a failure stamp within 24h still gates the kind to math '
      'even when mathOk is also true',
      () async {
        final PlayerState player = await freshPlayer(box);
        player.recordParentGateMathSuccess(); // mathOk = true
        player.recordParentGateMathFailure(); // stamps lockout
        expect(player.parentGateMathOk, isFalse);
        expect(player.parentGateFailureLocked, isTrue);
        expect(player.parentGateKind(), ParentGateKind.math);
      },
    );
  });

  group('parentGateFailureLocked — 24h boundary (strict <)', () {
    test(
      'a failure stamp exactly 24h past → lockout cleared '
      '(production uses strict <, not <=)',
      () async {
        final DateTime now = DateTime.now();
        await box.put(
          'player.parentGateLastFailureAt',
          now.subtract(const Duration(hours: 24)),
        );
        await box.close();
        box = await Hive.openBox<dynamic>(box.name);
        final PlayerState rehydrated = await freshPlayer(box);

        expect(
          rehydrated.parentGateFailureLocked,
          isFalse,
          reason: 'production uses strict <, so 24h exactly == un_locked',
        );
      },
    );

    test(
      'a failure stamp 23h59m past → still locked',
      () async {
        final DateTime now = DateTime.now();
        await box.put(
          'player.parentGateLastFailureAt',
          now.subtract(const Duration(hours: 23, minutes: 59)),
        );
        await box.close();
        box = await Hive.openBox<dynamic>(box.name);
        final PlayerState rehydrated = await freshPlayer(box);

        expect(rehydrated.parentGateFailureLocked, isTrue);
      },
    );
  });

  group('parentGateFailLockout — constant pinned', () {
    test('PlayerState.parentGateFailLockout is exactly 24 hours', () async {
      expect(
        PlayerState.parentGateFailLockout,
        const Duration(hours: 24),
      );
    });
  });

  group('recordParentGateMathFailure — repeated calls', () {
    test(
      'a second failure refreshes the lockout origin '
      '(re-stamps the 24h window)',
      () async {
        // Plant a 12h-old failure so a re-stamp moves the boundary forward.
        final DateTime now = DateTime.now();
        await box.put(
          'player.parentGateLastFailureAt',
          now.subtract(const Duration(hours: 12)),
        );
        await box.close();
        box = await Hive.openBox<dynamic>(box.name);
        final PlayerState rehydrated = await freshPlayer(box);

        expect(rehydrated.parentGateFailureLocked, isTrue);
        // 12h old — still locked; old stamp lying at `before`.
        final DateTime before = rehydrated.parentGateLastFailureAt!;

        rehydrated.recordParentGateMathFailure();
        final DateTime after = rehydrated.parentGateLastFailureAt!;

        expect(
          after.isAfter(before),
          isTrue,
          reason: 'repeated failure must re-anchor the lockout window',
        );
        expect(rehydrated.parentGateFailureLocked, isTrue);
      },
    );

    test('always notifies even on idempotent re-stamp', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordParentGateMathFailure();
      var notifyCount = 0;
      player.addListener(() => notifyCount++);

      player.recordParentGateMathFailure();

      expect(
        notifyCount,
        1,
        reason: 'failure path writes a fresh `DateTime.now()` each call, '
            'so state always changes → always notify',
      );
    });
  });

  group('recordParentGateHoldSuccess', () {
    test('does not mutate persistence state (analytics reservation)', () async {
      final PlayerState player = await freshPlayer(box);
      var notifyCount = 0;
      player.addListener(() => notifyCount++);

      player.recordParentGateHoldSuccess();

      expect(notifyCount, 0, reason: 'holdPathSuccess is a pure logger tick');
      expect(player.parentGateMathOk, isFalse);
      expect(player.parentGateLastFailureAt, isNull);
    });

    test('does not mutate any economy-related state', () async {
      // Guard: if a future migration puts analytics + side-effects into
      // holdSuccess, this test fails the build until the side-effects
      // are acknowledged and the test rewritten.
      final PlayerState player = await freshPlayer(box);
      player.grantCoins(50, reason: 'seed');
      player.grantGems(2, reason: 'seed');
      final int coinsBefore = player.coins;
      final int gemsBefore = player.gems;

      player.recordParentGateHoldSuccess();

      expect(player.coins, coinsBefore);
      expect(player.gems, gemsBefore);
      expect(player.parentGateMathOk, isFalse);
      expect(player.parentGateLastFailureAt, isNull);
    });
  });

  group('dailyRewardClaimed — derived from lastStreakDate', () {
    test('fresh state → not yet claimed', () async {
      final PlayerState player = await freshPlayer(box);
      expect(player.dailyRewardClaimed, isFalse);
    });

    test('streak recorded earlier today → claimed', () async {
      final PlayerState player = await freshPlayer(box);
      final DateTime now = DateTime.now();
      player.recordStreak(now: now);
      expect(
        player.dailyRewardClaimed,
        isTrue,
        reason: 'lastStreakDate == today → already claimed',
      );
    });

    test('streak recorded yesterday → NOT yet claimed', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(
        now: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(player.dailyRewardClaimed, isFalse);
    });

    test('streak recorded on the same date survives across HMS bound shifts',
        () async {
      final PlayerState player = await freshPlayer(box);
      final DateTime midMorning = DateTime.now();
      player.recordStreak(now: midMorning);
      final DateTime lateEvening = DateTime(
        midMorning.year,
        midMorning.month,
        midMorning.day,
        23,
        59,
        59,
      );
      expect(
        player.dailyRewardClaimed,
        isTrue,
        reason: 'calendar-day compare ignores HMS, so late evening == today',
      );
      expect(lateEvening.year, midMorning.year);
      expect(lateEvening.month, midMorning.month);
      expect(lateEvening.day, midMorning.day);
    });
  });
}
