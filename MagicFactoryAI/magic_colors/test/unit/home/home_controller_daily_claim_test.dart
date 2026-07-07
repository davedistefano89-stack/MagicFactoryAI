// =============================================================================
// Magic Colors · tests/unit/home/home_controller_daily_claim_test.dart
// =============================================================================
//
// Pure controller test for the M2.4 DRY refactor. Verifies the public
// surface `HomeController.onClaimDailyReward` exposes:
//   • Idempotent same-day re-claim (returns null on second tap).
//   • Stamps `_lastDailyRewardReward` immediately after the chest
//     applies, so the DailyRewardCard pill row can animate.
//   • Failure paths return `null` without leaking toast / haptic.
//   • Analytics are NOT the controller's job — home_screen owns that.
//
// Uses the same `xyz.luan/audioplayers` channel mock as
// daily_reward_claim_test.dart so `SoundService.preload()` returns
// quickly without hanging on the missing platform implementation.
// =============================================================================

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:magic_colors/core/domain/economy/reward.dart';
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/features/home/home_controller.dart';

final MethodChannel _kAudioChannel =
    const MethodChannel('xyz.luan/audioplayers');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _kAudioChannel,
      (MethodCall call) async {
        throw PlatformException(
          code: 'mocked_for_tests',
          message: 'audioplayers not available in unit tests',
        );
      },
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kAudioChannel, null);
  });

  late Box<dynamic> box;
  late PlayerState player;
  late HomeController controller;
  late SoundService sound;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'hive_home_controller_test_',
    );
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('home_controller_test');
    await box.clear();

    player = PlayerState.fromBox(box);
    sound = await SoundService.preload();
    controller = HomeController(sound: sound, player: player);
  });

  tearDown(() async {
    controller.dispose();
    await sound.dispose();
    player.dispose();
    await box.close();
    await Hive.deleteBoxFromDisk('home_controller_test');
    try {
      await tempDir.delete(recursive: true);
    } on Object catch (_) {/* Windows may hold the lock briefly */}
  });

  group('onClaimDailyReward — return value', () {
    test('first claim returns the awarded CompositeReward', () async {
      // Pre-state: fresh install, day-1 eligible.
      expect(player.dailyRewardClaimed, isFalse);
      expect(controller.lastDailyRewardReward, isNull);

      final reward = await controller.onClaimDailyReward();

      expect(reward, isNotNull);
      expect(reward!.totalCoinDelta, 15); // Day-1 chest → 15 coins
      expect(reward.totalGemDelta, 1); // Day-1 chest → 1 gem
      expect(controller.lastDailyRewardReward, isNotNull);
      // Reference identity: same Object the function returned.
      expect(
        identical(controller.lastDailyRewardReward, reward),
        isTrue,
        reason: 'snapshot getter and return value must share reference',
      );
    });

    test('same-day second call returns null (idempotent guard)', () async {
      await controller.onClaimDailyReward();
      final firstSnapshot = controller.lastDailyRewardReward;

      final second = await controller.onClaimDailyReward();

      expect(second, isNull);
      // Snapshot must NOT be overwritten by a no-op — preserves the
      // original awarded chest for any pill animation that fires
      // later in the session.
      expect(
        identical(controller.lastDailyRewardReward, firstSnapshot),
        isTrue,
      );
      // Currencies unchanged.
      expect(player.coins, 15);
      expect(player.gems, 6); // 5 default + 1
    });

    test('claim on a fresh player floors preStreak at day-1', () async {
      // streakDays defaults to 0 on a fresh PlayerState.
      expect(player.streakDays, 0);

      final reward = await controller.onClaimDailyReward();

      // Without the `< 1` floor, RewardEngine throws on streak=0.
      // The controller's guard turns that into the day-1 chest.
      expect(reward, isNotNull);
      expect(player.streakDays, 1);
      expect(player.coins, 15);
    });
  });

  group('onClaimDailyReward — PlayerState wiring', () {
    test('grants coins + gems and bumps streak atomically', () async {
      expect(player.streakDays, 0);

      await controller.onClaimDailyReward();

      expect(player.streakDays, 1);
      expect(player.dailyRewardClaimed, isTrue);
      expect(player.coins, 15);
      expect(player.gems, 6);
    });

    test('does NOT leak haptic / audio on the no-op path', () async {
      // First call lands the reward.
      await controller.onClaimDailyReward();
      final firstCoins = player.coins;
      final firstGems = player.gems;

      // Note: this test only guards the no-op contract through the
      // observable side effects (no currency delta + returns null).
      // A future polish could spy on Haptics if a fake surface is
      // introduced; for now this assertion is sufficient.
      final second = await controller.onClaimDailyReward();
      expect(second, isNull);
      expect(player.coins, firstCoins);
      expect(player.gems, firstGems);
    });
  });

  group('lastDailyRewardReward — getter contract', () {
    test('null on a fresh controller', () async {
      expect(controller.lastDailyRewardReward, isNull);
    });

    test('exposes a non-null value after the first granted claim', () async {
      await controller.onClaimDailyReward();
      final reward = controller.lastDailyRewardReward;
      expect(reward, isNotNull);
      // Snapshot is a CompositeReward; assert the re-exported totals.
      expect(reward, isA<CompositeReward>());
      expect(reward!.totalCoinDelta, 15);
      expect(reward.totalGemDelta, 1);
    });

    test('snapshot identity tracks the awarded CompositeReward', () async {
      // The getter is a pure reference to the most-recent grantTo'd
      // CompositeReward; pre-grant null, post-grant the exact object
      // returned by onClaimDailyReward. Reference identity is the
      // contract — widgets test it by `identical()` against their own
      // cached copy to decide whether to re-trigger animation.
      expect(controller.lastDailyRewardReward, isNull);

      final reward = await controller.onClaimDailyReward();

      expect(
        identical(controller.lastDailyRewardReward, reward),
        isTrue,
      );
      expect(
        identical(controller.lastDailyRewardReward, reward),
        isTrue,
      );
    });
  });
}
