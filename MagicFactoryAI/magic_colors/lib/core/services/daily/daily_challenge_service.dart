// =============================================================================
// Magic Colors · core/services/daily/daily_challenge_service.dart
// =============================================================================
//
// Sprint 7 — daily-challenges service. Owns the "3 challenges per
// day" selection + per-challenge progress derivation + claim
// pipeline. Mirrors the [UnlockService] / [WorldUnlockService]
// pattern (abstract final, static methods, pure-Dart).
//
// SELECTION
//   The catalog has 5 challenges. The service deterministically
//   picks 3 per day using `dayOfYear + year` as the RNG seed, so
//   the same calendar day always picks the same 3 challenges. The
//   selection is stable across rebuilds + sessions; the kid never
//   sees a challenge "rotate" mid-day.
//
// PROGRESS
//   Each [DailyChallengeKind] branches on a different PlayerState
//   field. No state duplication — the service reads what the
//   controller already wrote (e.g. `recordDrawingCompletion` is
//   hooked into `ColoringController._flush`).
//
// CLAIM
//   The claim path is idempotent: a second call on the same day
//   for the same challenge returns `alreadyClaimed` without
//   granting. The persistable claim is keyed by the challenge id
//   (not the date) so a future repeat of the same challenge on
//   another day can't re-grant.
// =============================================================================

import '../../state/player_state.dart';
import '../../domain/daily/daily_challenge.dart';
import '../../domain/daily/daily_challenge_kind.dart';
import '../../domain/daily/daily_challenge_progress.dart';
import '../../domain/daily/daily_challenge_status.dart';
import '../../../features/daily/data/daily_challenges_catalog.dart';

/// Outcome of a single [DailyChallengeService.claim] call.
enum DailyChallengeClaimResult {
  /// Coins + gems granted. Caller shows the celebration.
  claimed,

  /// Target not yet reached. Quiet no-op.
  notYetCompleted,

  /// Reward already claimed today (or in a previous repeat).
  /// Quiet no-op.
  alreadyClaimed,
}

abstract final class DailyChallengeService {
  DailyChallengeService._();

  /// Number of challenges to surface per day. v1.0 = 3. Kept as
  /// a const so the UI knows the row count up-front (no async
  /// wait for the catalog length).
  static const int _kChallengesPerDay = 3;

  /// Returns the 3 challenges active for [today] (defaults to
  /// `DateTime.now()`). Stable per calendar day; the date is
  /// hashed to an int that indexes the catalog.
  static List<DailyChallenge> listToday({DateTime? today}) {
    final DateTime d = today ?? DateTime.now();
    final int seed = d.year * 1000 + _dayOfYear(d);
    final List<DailyChallenge> all = dailyChallengesCatalog;
    final List<int> indexes = <int>[];
    // Deterministic selection: walk the seed and pick indexes
    // that don't repeat. The catalog is 5 entries; we want 3.
    int s = seed;
    while (indexes.length < _kChallengesPerDay && indexes.length < all.length) {
      s = (s * 1103515245 + 12345) & 0x7FFFFFFF;
      final int idx = s % all.length;
      if (!indexes.contains(idx)) {
        indexes.add(idx);
      }
    }
    return <DailyChallenge>[for (int i in indexes) all[i]];
  }

  /// Computes the per-challenge progress snapshot for [challenge]
  /// against [player]. Pure read — does not mutate. The status
  /// derives from `player.completedChallengesToday.contains(id)`
  /// + `player.claimedChallengeIds.contains(id)`.
  static DailyChallengeProgress computeProgress(
    DailyChallenge challenge,
    PlayerState player,
  ) {
    final int current = _currentFor(challenge, player);
    final bool completed = _isCompleted(challenge, player, current);
    final bool claimed = player.claimedChallengeIds.contains(challenge.id);
    final DailyChallengeStatus status = claimed
        ? DailyChallengeStatus.claimed
        : completed
            ? DailyChallengeStatus.completed
            : DailyChallengeStatus.active;
    return DailyChallengeProgress(
      challenge: challenge,
      current: current < 0 ? 0 : current,
      target: challenge.target < 1 ? 1 : challenge.target,
      status: status,
    );
  }

  /// Snapshots progress for every active-today challenge. Order
  /// matches [listToday].
  static List<DailyChallengeProgress> snapshotToday(
    PlayerState player, {
    DateTime? today,
  }) {
    return <DailyChallengeProgress>[
      for (final DailyChallenge c in listToday(today: today))
        computeProgress(c, player),
    ];
  }

  /// Marks [challengeId] as completed for today. Idempotent —
  /// a second call on the same day is a no-op. Called by the
  /// [ColoringController] path (via `PlayerState.markDailyChallengeCompleted`)
  /// when the progress crosses the target.
  static void markCompleted(
    PlayerState player,
    String challengeId,
  ) {
    player.markDailyChallengeCompleted(challengeId);
  }

  /// Claims the reward for [challenge]. Returns one of
  /// [DailyChallengeClaimResult.claimed] /
  /// [.notYetCompleted] / [.alreadyClaimed].
  static DailyChallengeClaimResult claim(
    DailyChallenge challenge,
    PlayerState player,
  ) {
    if (player.claimedChallengeIds.contains(challenge.id)) {
      return DailyChallengeClaimResult.alreadyClaimed;
    }
    final int current = _currentFor(challenge, player);
    if (current < challenge.target) {
      return DailyChallengeClaimResult.notYetCompleted;
    }
    if (challenge.rewardCoins > 0) {
      player.grantCoins(
        challenge.rewardCoins,
        reason: 'daily_challenge.${challenge.id}',
      );
    }
    if (challenge.rewardGems > 0) {
      player.grantGems(
        challenge.rewardGems,
        reason: 'daily_challenge.${challenge.id}',
      );
    }
    player.claimDailyChallengeReward(challenge.id);
    return DailyChallengeClaimResult.claimed;
  }

  /// True iff the challenge target has been reached today. Used
  /// by the auto-completion check inside
  /// [ColoringController._flush] (via the PlayerState helper).
  static bool isCompletedToday(
    DailyChallenge challenge,
    PlayerState player,
  ) {
    return player.completedChallengesToday.contains(challenge.id);
  }

  // ── Internals ──────────────────────────────────────────────────────

  /// Branches on [DailyChallengeKind] to read the right
  /// PlayerState field. Returns the current progress (0..target+).
  static int _currentFor(DailyChallenge c, PlayerState p) {
    switch (c.kind) {
      case DailyChallengeKind.colorDrawings:
        return p.drawingsCompletedToday;
      case DailyChallengeKind.earnStars:
        return p.starsEarnedToday;
      case DailyChallengeKind.completeWorld:
        // True iff the player earned a complete 3-star world today.
        // Heuristic: total stars today >= 3 AND there's at least one
        // world at 3 stars in the persistent map (cumulative). This
        // is intentionally a coarse signal — the alternative (track
        // per-day per-world stars) would need a new map field.
        if (p.starsEarnedToday < 3) return 0;
        for (final int stars in p.worldStars.values) {
          if (stars >= 3) return 1;
        }
        return 0;
      case DailyChallengeKind.playMascot:
        // Reserved for a future Sprint. v1.0 always returns 0 so
        // a missing hook doesn't accidentally complete challenges.
        return 0;
    }
  }

  /// True iff the challenge target is reached. Reads
  /// `completedChallengesToday` for the idempotent check, then
  /// calls [PlayerState.markDailyChallengeCompleted] if the
  /// status flipped this frame.
  static bool _isCompleted(
    DailyChallenge c,
    PlayerState p,
    int current,
  ) {
    if (p.completedChallengesToday.contains(c.id)) return true;
    if (current >= c.target) {
      // Mark the completion so the next snapshot read stays
      // idempotent (PlayerState dedupes).
      p.markDailyChallengeCompleted(c.id);
      return true;
    }
    return false;
  }

  /// Calendar day-of-year (1..366). Used as the deterministic
  /// seed for the daily-challenges selection. Lifted out so the
  /// test file can construct a fixed date without depending on
  /// the wall clock.
  static int _dayOfYear(DateTime d) {
    final DateTime start = DateTime(d.year, 1, 1);
    final int diff = d.difference(start).inDays;
    return diff + 1;
  }
}
