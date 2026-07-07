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
//   • Daily-reward claim → PlayerState.streakDays → RewardEngine → Reward.
//   • Numeric UI state that PlayerState doesn't own yet (per-call busy
//     flags) — kept local because they mutate at gesture-frame rate.
//   • Sound + haptic side effects (delegated to SoundService).
//
// EVERYTHING ELSE (balance, premium, streak, owned worlds, active
// bottom-nav tab) lives elsewhere. Bottom-nav selection lives in
// [NavigationState] — `BottomNavigation` and the home-screen shell
// helpers route every tab change through `NavigationState.selectTab`,
// and the in-shell HUD re-reads `NavigationState.currentTab`. Earlier
// versions of this controller kept a parallel `_currentTab` field, but
// it had no callers and was drifting ownership away from the router.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:magic_colors/core/design/design_tokens.dart' show AppDuration;
import 'package:magic_colors/core/domain/daily/daily_reward_summary.dart';
import 'package:magic_colors/core/domain/economy/reward.dart';
import 'package:magic_colors/core/services/daily/daily_reward_service.dart';
import 'package:magic_colors/core/services/economy/reward_engine.dart';
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/core/utils/haptics.dart';
import 'package:magic_colors/core/utils/logger.dart';

class HomeController extends ChangeNotifier {
  HomeController({required SoundService sound, required PlayerState player})
      : _sound = sound,
        _player = player,
        _playBusy = false;

  final SoundService _sound;
  final PlayerState _player;

  /// Re-entrancy guard for onPlayNow. Prevents duplicate play-button SFX
  /// when a 4-year-old double-taps the giant CTA.
  bool _playBusy;

  /// Snapshot of the most-recent [CompositeReward] granted by
  /// [onClaimDailyReward]. `null` until the first claim in this app run.
  /// Updated atomically alongside the `PlayerState.recordStreak()` so
  /// widgets that watch the controller (e.g. [DailyRewardCard]) can
  /// animate their pill row without re-walking the reward tree.
  CompositeReward? _lastDailyRewardReward;

  /// Read-only view of the most-recent daily chest reward. The card
  /// watches this and animates from 0 → totalCoinDelta / totalGemDelta
  /// whenever a claim fires. Pure getter — never nulls between claims
  /// from outside; only overwritten by the next successful claim.
  CompositeReward? get lastDailyRewardReward => _lastDailyRewardReward;

  bool get playBusy => _playBusy;

  /// Player economy — surfaced straight from PlayerState so the UI
  /// never has a stale view. The widget tree should call these getters
  /// inside a `Consumer<PlayerState>` AND `Consumer<HomeController>` so
  /// the rebuild propagates on either notify.
  int get coins => _player.coins;
  int get gems => _player.gems;
  int get streakDays => _player.streakDays;

  /// M2.4 — surfaced straight from PlayerState so the home shell can
  /// gray out the daily-event card once the chest has been claimed.
  bool get dailyRewardClaimed => _player.dailyRewardClaimed;
  bool get hasUnclaimedDailyReward => !_player.dailyRewardClaimed;

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
  ///
  /// Returns the awarded [CompositeReward] on success, or `null` when
  /// the chest was already claimed today OR the engine threw. Callers
  /// (HomeScreen, RewardsScreen) use the return value to skip analytics
  /// emission on no-op double-taps.
  Future<CompositeReward?> onClaimDailyReward() async {
    // ── Already-claimed guard. Cheap: single Hive read off
    //    PlayerState's cached `_lastStreakDate`.
    if (_player.dailyRewardClaimed) {
      logger.info('HomeController.onClaimDailyReward already claimed');
      return null;
    }

    // Snapshot the streak BEFORE calling recordStreak so the engine
    // sees the value used to claim today's chest. recordStreak returns
    // the new streak value; the player keeps the bumped number on disk.
    // Floor at 1: the engine refuses streak < 1; a brand-new install
    // (streakDays == 0) still earns the day-1 chest. Mirrors the
    // previous home_screen safeguard behaviour.
    final int preStreak = _player.streakDays < 1 ? 1 : _player.streakDays;
    final CompositeReward reward;
    try {
      reward = RewardEngine.computeDailyChestReward(preStreak);
    } on Object catch (error, stack) {
      logger.error(
        'HomeController.onClaimDailyReward engine failed',
        error: error,
        stackTrace: stack,
      );
      return null;
    }

    logger.info('HomeController.onClaimDailyReward streak=$preStreak');

    // Sprint 7 — route the bundle (coins + gems + optional item)
    // through the new service. The service is idempotent on a
    // re-claim the same day (returns alreadyClaimed). The existing
    // `reward.grantTo` line is intentionally REMOVED — the new
    // service is the sole grant path so the player can't be
    // double-credited (coins + gems would otherwise land twice).
    final DailyRewardClaimResult claimResult =
        DailyRewardService.claim(_player, today: DateTime.now());
    if (claimResult == DailyRewardClaimResult.alreadyClaimed) {
      logger.info(
        'HomeController.onClaimDailyReward already claimed (Sprint 7 key)',
      );
      return null;
    }

    // Bump the streak so a same-day re-claim is a no-op and the daily
    // chest UI rotates its label correctly.
    _player.recordStreak();

    // Snapshot before the celebration audio so widgets that watch
    // _lastDailyRewardReward can start the count-up animation in the
    // same frame the audio SFX fires (single notifyListeners at the
    // tail end batches everything).
    _lastDailyRewardReward = reward;

    // Celebration audio + visual cue. MagicSound enum values come from
    // the canonical SoundService (the previous build referenced a
    // non-existent `MagicSound.chestOpen / coinCollect / gemCollect`;
    // those are now mapped to the canonical reward / coin / gem cues).
    unawaited(_sound.play(MagicSound.reward));
    unawaited(_sound.play(MagicSound.coin));
    unawaited(_sound.play(MagicSound.gem));
    Haptics.success();

    notifyListeners();
    return reward;
  }

  // ── Animation coupling ──────────────────────────────────────────────────
  /// Animation duration for any widget that interpolates between the
  //    engine-preview (zero claim fired) and the awarded snapshot.
  //
  /// Exposed as a constant getter so [DailyRewardCard] can reuse the
  /// project-standard medium timing without re-importing design_tokens.
  Duration get pillCountUpDuration => AppDuration.medium;

  // ── Sprint 7 — Daily Reward celebration dialog ────────────────────────
  /// Convenience helper that returns the [DailyRewardSummary] for
  /// the player's CURRENT streak. Used by the home shell to pop
  /// the [DailyRewardDialog] after a successful claim. The
  /// summary bundles the coin + gem grant with the optional item
  /// row (palette / brush / gradient) so the dialog renders a
  /// 3-pill row on item-days.
  DailyRewardSummary dailyRewardSummary() {
    return DailyRewardService.computeForPlayer(_player);
  }
}
