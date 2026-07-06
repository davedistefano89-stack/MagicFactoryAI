// =============================================================================
// Magic Colors · test/unit/state/player_state_streak_test.dart
// =============================================================================
//
// Regression suite for PlayerState.recordStreak. Every documented edge
// case lives here so the streak math cannot silently break on the next
// phone with a different locale, DST schedule, or battery-saver clock
// warp.
//
// TEST ISOLATION
//   Each test gets its own Hive box under a temp directory keyed by
//   `microsecondsSinceEpoch`. `tearDown` closes the box; `tearDownAll`
//   deletes the directory. Production code never sees these artifacts.
//
// TIME-MOCKING
//   recordStreak accepts an optional `now: DateTime?` for tests, so
//   every edge case is verifiable with a fixed DateTime instead of
//   standing in front of a real wall clock. Tests MUST pass `now:`;
//   callers that omit it use `DateTime.now()`.
//
// COVERED CASES
//   ▸ First-ever call → streak = 1, lastStreakDate = today's local-date.
//   ▸ Same calendar day, multiple times → streak unchanged, no notify.
//   ▸ Next calendar day → streak += 1, lastStreakDate updated.
//   ▸ Multi-day streak chain → monotonic increment.
//   ▸ Gap of 2+ days → streak resets to 1.
//   ▸ Clock rollback (manual or auto, diff < 0) → idempotent.
//   ▸ Forward clock drift (diff > 1 day) → reset to 1.
//   ▸ DST spring forward: 23 hours apart still count as next day.
//   ▸ DST fall back: 25 hours apart still count as next day.
//   ▸ Persistence: a fresh PlayerState from the same box picks up the
//     stored streak and continues from it.
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:magic_colors/core/data/hive_keys.dart';
import 'package:magic_colors/core/state/player_state.dart';

/// Compact builder for fresh-state PlayerState tests. Calls into a
/// per-test Hive box so each test starts with empty persistence.
Future<PlayerState> freshPlayer(Box<dynamic> box) async {
  // Box is empty by construction (per-test setUp), so PlayerState
  // hydrates with its default values (coins=0, gems=5, streak=0).
  return PlayerState.fromBox(box);
}

void main() {
  late Directory tempDir;
  late Box<dynamic> box;

  setUpAll(() async {
    // Temp directory for Hive box backing files. Stripped in tearDownAll.
    tempDir = await Directory.systemTemp.createTemp('m1_streak_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    // Per-test isolation: a unique box name prevents `box.put(...)`'s
    // leaking into another test's snapshot.
    final String boxName =
        'streak_test_${DateTime.now().microsecondsSinceEpoch}';
    box = await Hive.openBox<dynamic>(boxName);
  });

  tearDown(() async {
    if (box.isOpen) {
      await box.close();
    }
  });

  group('PlayerState.recordStreak — first-ever call', () {
    test('fresh state → streak = 1 and lastStreakDate is today', () async {
      final PlayerState player = await freshPlayer(box);
      final int result = player.recordStreak(now: DateTime(2026, 7, 1, 9));
      expect(result, 1);
      expect(player.streakDays, 1);
      expect(player.lastStreakDate, DateTime(2026, 7));
    });

    test('first call at end-of-day computes the same calendar day', () async {
      final PlayerState player = await freshPlayer(box);
      final int result = player.recordStreak(
        now: DateTime(2026, 7, 1, 23, 59, 59),
      );
      expect(result, 1);
      expect(player.lastStreakDate, DateTime(2026, 7));
    });
  });

  group('PlayerState.recordStreak — same-day idempotency', () {
    test('two calls the same morning keep streak at 1', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 7, 1, 9));
      final int result = player.recordStreak(now: DateTime(2026, 7, 1, 17, 30));
      expect(result, 1);
      expect(player.streakDays, 1);
    });

    test('two calls the same day do NOT update lastStreakDate', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 7, 1, 9));
      player.recordStreak(now: DateTime(2026, 7, 1, 23, 59));
      expect(player.lastStreakDate, DateTime(2026, 7));
    });
  });

  group('PlayerState.recordStreak — day progression', () {
    test('next calendar day increments streak by 1', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 7, 1, 23));
      final int result = player.recordStreak(now: DateTime(2026, 7, 2, 12));
      expect(result, 2);
      expect(player.streakDays, 2);
      expect(player.lastStreakDate, DateTime(2026, 7, 2));
    });

    test('three consecutive days produce streak = 3', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 7));
      player.recordStreak(now: DateTime(2026, 7, 2));
      final int result = player.recordStreak(now: DateTime(2026, 7, 3));
      expect(result, 3);
      expect(player.lastStreakDate, DateTime(2026, 7, 3));
    });
  });

  group('PlayerState.recordStreak — gaps and clock anomalies', () {
    test('gap of 2 days resets streak to 1', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 7));
      player.recordStreak(now: DateTime(2026, 7, 2));
      // Skip 7/3 entirely.
      final int result = player.recordStreak(now: DateTime(2026, 7, 4));
      expect(result, 1);
      expect(player.lastStreakDate, DateTime(2026, 7, 4));
    });

    test('long gap (7 days) resets streak to 1', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 6));
      player.recordStreak(now: DateTime(2026, 6, 2));
      player.recordStreak(now: DateTime(2026, 6, 3));
      final int result = player.recordStreak(now: DateTime(2026, 6, 10));
      expect(result, 1);
    });

    test('clock rollback (diff < 0) is idempotent — no reset', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 7, 5));
      // Same-day idempotent + BEFORE the stored date (clock rolled back).
      final int result = player.recordStreak(now: DateTime(2026, 7, 3));
      expect(result, 1, reason: 'clock rollback must preserve streak');
      expect(player.streakDays, 1);
      expect(
        player.lastStreakDate,
        DateTime(2026, 7, 5),
        reason: 'lastStreakDate must NOT regress on a rollback',
      );
    });

    test('forward clock drift (diff > 1 day) resets to 1', () async {
      final PlayerState player = await freshPlayer(box);
      player.recordStreak(now: DateTime(2026, 7));
      // User manually set clock to next week — diff = 6 days.
      final int result = player.recordStreak(now: DateTime(2026, 7, 7));
      expect(result, 1);
      expect(player.lastStreakDate, DateTime(2026, 7, 7));
    });
  });

  group('PlayerState.recordStreak — DST transitions', () {
    test(
      'US Spring Forward: 23-hour gap counts as next day',
      () async {
        // US DST 2026 starts 2026-03-08. A player at 2026-03-07 23:30
        // then again at 2026-03-08 22:30 = 23 hours apart, but the
        // calendar-day-strip treats them as next-day. Streak must
        // increment.
        final PlayerState player = await freshPlayer(box);
        player.recordStreak(now: DateTime(2026, 3, 7, 23, 30));
        final int result =
            player.recordStreak(now: DateTime(2026, 3, 8, 22, 30));
        expect(
          result,
          2,
          reason:
              '23h span across spring-forward must register as next calendar day',
        );
      },
    );

    test(
      'US Fall Back: 25-hour gap counts as next day',
      () async {
        // US DST 2026 ends 2026-11-01. A player at 2026-10-31 23:30 then
        // 2026-11-01 22:30 = 25 hours apart, but calendar-day-strip
        // treats them as next-day. Streak must increment.
        final PlayerState player = await freshPlayer(box);
        player.recordStreak(now: DateTime(2026, 10, 31, 23, 30));
        final int result =
            player.recordStreak(now: DateTime(2026, 11, 1, 22, 30));
        expect(
          result,
          2,
          reason:
              '25h span across fall-back must register as next calendar day',
        );
      },
    );

    test(
      'DST stays neutral on partial-day edge: 22h gap counts as next day',
      () async {
        // Conservative check: regardless of DST scheduling, a span >=
        // a "day" by calendar arithmetic increments.
        final PlayerState player = await freshPlayer(box);
        player.recordStreak(now: DateTime(2026, 3, 7, 10));
        final int result = player.recordStreak(now: DateTime(2026, 3, 8, 8));
        expect(result, 2);
      },
    );
  });

  group('PlayerState.recordStreak — Hive persistence round-trip', () {
    test(
      're-constructed PlayerState picks up persisted streak and increments',
      () async {
        // Round-trip: persist a streak via the public API, close,
        // re-open the box, re-construct PlayerState.
        await box.put(hiveKeyLastStreakDate, DateTime(2026, 7, 5));
        await box.put(hiveKeyStreakDays, 5);

        // Re-hydrate by closing and re-opening the box.
        await box.close();
        box = await Hive.openBox<dynamic>(box.name);
        final PlayerState fresh = PlayerState.fromBox(box);
        expect(fresh.streakDays, 5);
        expect(fresh.lastStreakDate, DateTime(2026, 7, 5));

        final int result = fresh.recordStreak(now: DateTime(2026, 7, 6));
        expect(
          result,
          6,
          reason:
              're-hydrated streak (5) + 1 should equal 6 after next-day call',
        );
        expect(fresh.streakDays, 6);
      },
    );

    test(
      'persisted streak is correctly reset to 1 after gap (Day+2)',
      () async {
        await box.put(hiveKeyLastStreakDate, DateTime(2026, 7));
        await box.put(hiveKeyStreakDays, 7);

        await box.close();
        box = await Hive.openBox<dynamic>(box.name);
        final PlayerState fresh = PlayerState.fromBox(box);
        expect(fresh.streakDays, 7);

        // Three-day gap: streak must reset to 1.
        final int result = fresh.recordStreak(now: DateTime(2026, 7, 4));
        expect(result, 1);
        expect(fresh.streakDays, 1);
      },
    );
  });
}
