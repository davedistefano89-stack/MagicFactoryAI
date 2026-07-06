// ignore_for_file: unnecessary_library_name
// =============================================================================
// Magic Colors · tests/unit/_probe/m2_4_phase2_probe_test.dart
// =============================================================================
//
// M2.4 PHASE 2 — SDK-LEVEL LEAK PROBES.
//
// Background
// ----------
// `daily_reward_claim_test.dart` reports `[E] … did not complete` at the
// 30 s flutter_test hard timeout despite every reachable drain probe
// (transientCallbacks=0, GoogleFonts.pendingFonts(), 5 s real-time
// runAsync, 60 s binding.delayed fake-clock advance, full MaterialApp
// drop, Hive isolate close). The leak therefore lives in a dimension
// none of those drains cover.
//
// Purpose
// -------
// This file isolates ONE suspect Flutter SDK API per `testWidgets`
// block so the next agent (or the upstream flutter/flutter ticket
// assignee) can run the probe set on macOS / Linux and immediately
// pinpoint the suspect. Output convention:
//   ▸ Each probe prints `[probe-X] <stage>` lines via `// ignore:
//     avoid_print` so the CI log tells us at which stage each probe
//     got stuck (if any).
//   ▸ Each probe ends with the same probe-X END stamp.
//
// Tagging
// -------
// All probes are tagged `m2.4-known-issue` AND constrained to non-Win32
// hosts via @TestOn('!windows'). On Win32 the file is skipped outright.
// On Mac/Linux CI opt in via `flutter test --run-skipped`.
//
// Signal Map
// ----------
//   PROBE-A hangs         → flutter_test framework baseline broken.
//   PROBE-B hangs but A→C pass → fake-async real-time drain broken.
//   PROBE-C hangs but A,B,D,E pass → google_fonts pendingFonts broken.
//   PROBE-D hangs but A,B,C,E pass → binding.delayed fake-clock broken.
//   PROBE-E hangs but A-D pass → hive isolate teardown broken.
//   All pass                          → leak was in our widget plumbing
//                                       (DailyRewardCard lineage), not
//                                       the framework.
// =============================================================================

// M2.4 PHASE 2 — SDK-LEVEL LEAK PROBES.
//
// @Tags + @TestOn are library-level annotations in `package:test` (their
// `@Target` is `Target.library`). They cannot attach to a function-level
// `main()`; putting them on a NAMED library directive at the top is the
// only legal placement, and it propagates to every test function below.
// The named library is technically unnecessary in Dart 3.6+ (silenced
// by the file-level `// ignore_for_file: unnecessary_library_name`
// pragma at the top of this file) but is required to satisfy the
// @Target(Target.library) constraint. The tag value `m2-4-known-issue`
// is a valid hyphenated Dart identifier — package:test rejects tag
// names containing `.` so the original `m2.4-known-issue` was
// parse-failing.
@Tags(<String>['m2-4-known-issue'])
@TestOn('!windows')
library magic_colors_m2_4_phase2_probe;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() {
    // M2.4 PHASE 2 probe fixture — google_fonts in offline mode
    // mirrors what daily_reward_claim_test.dart uses so the probe is
    // faithful to the production test.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDownAll(() {
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  // ───────────────────────────────────────────────────────────────────────
  // PROBE-A (BASELINE) — pump a single Text widget + pumpAndSettle.
  // If this hangs, the flutter_test framework itself is wedged on Win32.
  // ───────────────────────────────────────────────────────────────────────
  testWidgets('PROBE-A: baseline Text widget + pumpAndSettle',
      (WidgetTester tester) async {
    // ignore: avoid_print
    print('[probe-A] start');
    await tester.pumpWidget(const Text('baseline'));
    await tester.pump();
    expect(find.text('baseline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    // ignore: avoid_print
    print('[probe-A] END');
  });

  // ───────────────────────────────────────────────────────────────────────
  // PROBE-B (RUNASYNC DRAIN) — escape fake-async with a 30 s real-time
  // delay. If this hangs, the test framework is waiting on real-time
  // Future delivery after the testWidgets body returned.
  // ───────────────────────────────────────────────────────────────────────
  testWidgets('PROBE-B: runAsync real-time Future.delayed drain',
      (WidgetTester tester) async {
    // ignore: avoid_print
    print('[probe-B] start');
    await tester.pumpWidget(const Text('probe-b'));
    await tester.pump();
    await tester.runAsync(() async {
      // ignore: avoid_print
      print('[probe-B] runAsync entered');
      await Future<void>.delayed(const Duration(seconds: 30));
      // ignore: avoid_print
      print('[probe-B] 30s real-time elapsed');
    });
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    // ignore: avoid_print
    print('[probe-B] END');
  });

  // ───────────────────────────────────────────────────────────────────────
  // PROBE-C (GOOGLE FONTS) — access a typography token so GoogleFonts
  // resolves + loadFontIfNecessary fires, then await pendingFonts() to
  // drain. If this hangs, the leak is in google_fonts.
  // ───────────────────────────────────────────────────────────────────────
  testWidgets('PROBE-C: google_fonts token access + pendingFonts drain',
      (WidgetTester tester) async {
    // ignore: avoid_print
    print('[probe-C] start');
    await tester.pumpWidget(
      const Text('probe-c', style: TextStyle(fontSize: 14)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      // ignore: avoid_print
      print('[probe-C] runAsync entered');
      // Trigger the google_fonts lookup by reading the family string.
      // The family value is embedded into a `print` so it is observably
      // consumed — no orphan-binding lint needed.
      // ignore: avoid_print
      print(
          '[probe-C] token resolved family=${GoogleFonts.baloo2().fontFamily}');
      await GoogleFonts.pendingFonts();
      // ignore: avoid_print
      print('[probe-C] pendingFonts resolved');
    });
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    // ignore: avoid_print
    print('[probe-C] END');
  });

  // ───────────────────────────────────────────────────────────────────────
  // PROBE-D (BINDING.DELAYED) — fast-forward the FakeAsync clock by 60 s.
  // If this hangs, the leak is a Timer.delayed scheduled for fake-time
  // > the pumpAndSettle ceiling.
  // ───────────────────────────────────────────────────────────────────────
  testWidgets('PROBE-D: tester.binding.delayed(60s) fake-clock advance',
      (WidgetTester tester) async {
    // ignore: avoid_print
    print('[probe-D] start');
    await tester.pumpWidget(const Text('probe-d'));
    await tester.pump();
    await tester.binding.delayed(const Duration(seconds: 60));
    // ignore: avoid_print
    print('[probe-D] binding.delayed returned');
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    // ignore: avoid_print
    print('[probe-D] END');
  });

  // ───────────────────────────────────────────────────────────────────────
  // PROBE-E (HIVE) — open a real Hive box on a tempdir, mutate a key,
  // then close in tearDown. If this hangs, the leak is in the Hive
  // isolate teardown path even under real-time runAsync.
  // ───────────────────────────────────────────────────────────────────────
  testWidgets('PROBE-E: Hive.openBox + Hive.close isolate drain',
      (WidgetTester tester) async {
    // ignore: avoid_print
    print('[probe-E] start');
    final Directory tempDir =
        await Directory.systemTemp.createTemp('m2_4_probe_e_');
    Hive.init(tempDir.path);
    final Box<dynamic> box = await Hive.openBox<dynamic>('m2_4_probe_e');
    await box.put('probe-key', 42);
    expect(box.get('probe-key'), 42);
    // ignore: avoid_print
    print('[probe-E] box opened + key written');

    await tester.runAsync(() async {
      await Hive.close();
      // ignore: avoid_print
      print('[probe-E] Hive.close() returned (real time)');
    });
    if (Hive.isBoxOpen('m2_4_probe_e')) {
      await Hive.deleteBoxFromDisk('m2_4_probe_e');
    }
    try {
      await tempDir.delete(recursive: true);
    } on Object catch (_) {
      // Best-effort cleanup.
    }
    // ignore: avoid_print
    print('[probe-E] END');
  });
}
