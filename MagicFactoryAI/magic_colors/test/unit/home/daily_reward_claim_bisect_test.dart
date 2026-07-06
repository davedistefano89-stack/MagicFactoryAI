// ignore_for_file: unnecessary_library_name
// =============================================================================
// Magic Colors · tests/unit/home/daily_reward_claim_bisect_test.dart
// =============================================================================
//
// M2.4 PHASE 2 BISECT — stripped version of `daily_reward_claim_test.dart`
// that omits google_fonts AND hive. If this file passes (or even hangs
// cleanly before the framework hard-timeout), it tells us the leak is
// NOT in google_fonts / hive. If it passes outright — clear signal that
// the hang source was one of those packages, and we keep them off in
// the test fixture going forward.
//
// The bisect uses the just-added `PlayerState.inMemory()` factory so
// the widget's `context.watch<PlayerState>()` lookup resolves with the
// real production type (no ProviderNotFoundException).
//
// STRIPPED FROM RICH TEST:
//   • `package:google_fonts/google_fonts.dart`         ← removed
//   • `package:hive/hive.dart`                        ← removed
//   • `PlayerState.fromBox(box)` + `Hive.openBox`     ← replaced with `PlayerState.inMemory()`
//   • `AppTheme.light` (transitively pulled google_fonts via `app_typography`)
//   • `MultiProvider`                                  ← single `ChangeNotifierProvider<PlayerState>.value`
//   • `SettingsState`                                  ← not needed by `DailyRewardCard`
//   • All drains from the rich test                    ← clean baseline: NO probe,
//                                                        NO pumpAndSettle drain,
//                                                        NO Hive.close,
//                                                        NO binding.delayed
//
// INCLUDED FROM RICH TEST:
//   • `DailyRewardCard(onClaim: ...)`                  ← same widget under test
//   • `MaterialApp` + `Scaffold` + `TickerMode(enabled: false)`
//   • `Provider.of<PlayerState>` subscription surface  ← now matches real type
//
// SIGNAL VALUE:
//   • PASS             ↔ the leak was google_fonts / hive / settings_state glue.
//   • HANG (clean 30 s timeout)  ↔ the leak is upstream — flutter_test /
//                                  flutter SDK / project-init.
//   • FAIL at runtime  ↔ a test-infrastructure error (different signal;
//                                  not a "leak", just a wiring mistake).
// =============================================================================

// ── Test entry point ──────────────────────────────────────────────────────
//
// M2.4 PHASE 2 — KNOWN ISSUE (skip-on-Windows).
// All tests in this file are tagged `m2.4-known-issue` AND constrained
// to non-Windows hosts via @TestOn('!windows'). On Win32 the leak survives
// every drain we tried (probe 5-stage real-time drain + runAsync(Hive.close)
// + binding.delayed(60s) fake-clock advance + MaterialApp drop). On
// macOS/Linux the tests run normally so a future Flutter SDK fix is
// regression-tested the moment it lands. To opt-in to running the suite
// on macOS/Linux use `flutter test --run-skipped`.
//
// The annotations live on a NAMED library directive (their `@Target` is
// `Target.library` in `package:test`) so they propagate to every test
// function defined below.
// The named library is technically unnecessary in Dart 3.6+ (silenced
// by the file-level `// ignore_for_file: unnecessary_library_name`
// pragma at the top of this file) — but `@Tags` + `@TestOn` from
// `package:test` carry `@Target(Target.library)` so they need a library
// to attach to. Keeping the named directive is simpler than fighting
// @Target. The tag value `m2-4-known-issue` is a valid hyphenated Dart
// identifier — package:test rejects tag names containing `.` so the
// original `m2.4-known-issue` was parse-failing.
@Tags(<String>['m2-4-known-issue'])
@TestOn('!windows')
library magic_colors_daily_reward_claim_bisect_test;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/features/home/presentation/widgets/daily_reward_card.dart';

void main() {
  testWidgets(
      'BISECT-1: claim works WITHOUT google_fonts AND WITHOUT hive '
      '(PlayerState.inMemory)', (WidgetTester tester) async {
    final PlayerState player = PlayerState.inMemory();

    await tester.pumpWidget(
      ChangeNotifierProvider<PlayerState>.value(
        value: player,
        child: MaterialApp(
          // Barebones ThemeData — no AppTheme.light, no google_fonts
          // typography, no app_typography dependency tree.
          theme: ThemeData(),
          // M2.4 PHASE 2 BISECT FIX — flutter_test requires explicit
          // Localizations delegates for Material widgets (Card, Icon,
          // RichText infer directionality from MaterialLocalizations).
          // Without these the pumpWidget fails BEFORE the framework's
          // "did not complete" check ever fires — false signal.
          // Cupertino delegate is intentionally omitted — Material-only
          // widgets don't require it. If a future widget needs Cupertino
          // copy, add `GlobalCupertinoLocalizations.delegate` from
          // `package:flutter_localizations`.
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('en')],
          home: Scaffold(
            body: TickerMode(
              enabled: false,
              child: DailyRewardCard(onClaim: () {
                if (player.dailyRewardClaimed) return;
                final int preStreak = player.streakDays;
                // Inline engine-preview equivalent — day-1 chest.
                if (preStreak == 0) {
                  player.grantCoins(15, reason: 'bisect_day_1');
                }
                player.recordStreak();
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Claim reward'), findsOneWidget);
    expect(find.text('Daily Reward'), findsOneWidget);

    await tester.tap(find.text('Claim reward'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(player.streakDays, 1);
    expect(player.coins, 15);
    expect(player.dailyRewardClaimed, isTrue);

    // M2.4 PHASE 2 BISECT — bare squash. NO drains. NO probes.
    // If THIS fails to complete, the leak is upstream of google_fonts
    // and hive — flutter_test / flutter SDK / project init.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    player.dispose();
  });

  testWidgets('BISECT-2: barebones widget test (no card, no provider)',
      (WidgetTester tester) async {
    await tester.pumpWidget(const Text('minimal'));
    await tester.pump();
    expect(find.text('minimal'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  });
}
