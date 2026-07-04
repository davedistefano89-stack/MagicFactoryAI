// =============================================================================
// Magic Colors · features/home/home_controller.dart
// =============================================================================
//
// Home-tab state controller. M1 (Player Economy & Reward Engine) replaces
// the v0 parallel state (`_coins`, `_gems` internal) with the canonical
// PlayerState as the single source of truth, and routes the daily-reward
// claim through `RewardEngine.computeDailyChestReward` so the curve lives
// in one place instead of one-tap magic numbers.
//
// RESPONSIBILITIES
//   • Tab state for the bottom-nav shell (`currentTab`).
//   • Daily-reward claim → PlayerState.streakDays → RewardEngine → Reward.
//   • Numeric UI state that PlayerState doesn't own yet (per-call busy
//     flags) — kept local because they mutate at gesture-frame rate.
//   • Sound + haptic side effects (delegated to SoundService).
//
// EVERYTHING ELSE (balance, premium, streak, owned worlds) lives in
// PlayerState. HomeController only MUTATES the per-tap UX state it owns.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:magic_colors/core/domain/economy/reward.dart';
import 'package:magic_colors/core/services/economy/reward_engine.dart';
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/core/utils/logger.dart';
import 'package:magic_colors/features/home/widgets/bottom_nav.dart';

class HomeController extends ChangeNotifier {
  HomeController({required SoundService sound, required PlayerState player})
      : _sound = sound,
        _player = player,
        _currentTab = HomeTab.home,
        _playBusy = false;

  final SoundService _sound;
  final PlayerState _player;

  /// Bottom-nav tab. Owned locally because the shell only renders one
  /// Home root; cross-shell navigation lives in NavigationState.
  HomeTab _currentTab;

  /// Re-entrancy guard for onPlayNow. Prevents duplicate play-button SFX
  /// when a 4-year-old double-taps the giant CTA.
  bool _playBusy;

  HomeTab get currentTab => _currentTab;
  bool get playBusy => _playBusy;

  /// Player economy — surfaced straight from PlayerState so the UI
  /// never has a stale view. The widget tree should call these getters
  /// inside a `Consumer<PlayerState>` AND `Consumer<HomeController>` so
  /// the rebuild propagates on either notify.
  int get coins => _player.coins;
  int get gems => _player.gems;
  int get streakDays => _player.streakDays;

  // ── Bottom-nav ────────────────────────────────────────────────────────
  void setTab(HomeTab tab) {
    if (_currentTab == tab) return;
    _currentTab = tab;
    unawaited(_sound.play(MagicSound.bigTap));
    notifyListeners();
  }


  // ── Play Now CTA ──────────────────────────────────────────────────────
  Future<void> onPlayNow() async {
    if (_playBusy) return;
    _playBusy = true;
    notifyListeners();
    try {
      await _sound.play(MagicSound.magicSparkle);
    } finally {
      _playBusy = false;
      notifyListeners();
    }
  }


  // ── Daily reward claim ────────────────────────────────────────────────
  /// Awards the daily chest computed from the player's current streak.
  /// Routes through RewardEngine so the curve is the SINGLE source of
  /// truth — no `+= 100` magic numbers here.
  Future<void> onClaimDailyReward() async {
    // Snapshot the streak BEFORE calling recordStreak so the engine
    // sees the value used to claim today's chest. recordStreak returns
    // the new streak value; the player keeps the bumped number on disk.
    final int preStreak = _player.streakDays;
    final CompositeReward reward;
    try {
      reward = RewardEngine.computeDailyChestReward(preStreak);
    } on Object catch (error, stack) {
      logger.error(
        'HomeController.onClaimDailyReward engine failed',
        error: error,
        stackTrace: stack,
      );
      return;
    }

    logger.info('HomeController.onClaimDailyReward streak=$preStreak');

    // Bump the streak so a same-day re-claim is a no-op and the daily
    // chest UI rotates its label correctly.
    _player.recordStreak();

    // Apply the reward. CompositeReward.grantTo is idempotent against
    // zero children and against PlayerState's idempotent mutators.
    reward.grantTo(_player);

    // Celebration audio + visual cue. MagicSound enum values come from
    // the canonical SoundService (the previous build referenced a
    // non-existent `MagicSound.chestOpen / coinCollect / gemCollect`;
    // those are now mapped to the canonical reward / coin / gem cues).
    unawaited(_sound.play(MagicSound.reward));
    unawaited(_sound.play(MagicSound.coin));
    unawaited(_sound.play(MagicSound.gem));
  }
}
