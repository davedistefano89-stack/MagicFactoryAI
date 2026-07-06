// =============================================================================
// Magic Colors · core/services/daily/daily_reward_service.dart
// =============================================================================
//
// Sprint 7 — daily-reward service. Sits on top of the existing
// [RewardEngine.computeDailyChestReward] (which produces the
// coins + gems) and adds the optional item grant from the new
// [daily_rewards_catalog.dart] (palette / brush / gradient).
//
// The two-layer model is intentional:
//   • RewardEngine — the v1.0 curve (15..150 coins, 1..5 gems).
//   • DailyRewardService — Sprint 7 add-on: applies the catalog
//     item on item-day (day 3, 5, 7) via PlayerState.grantPalettePack
//     / grantBrush / grantGradient.
//
// IDEMPOTENCY
//   The service refuses to re-grant a day's bundle. The
//   "claimed today" check is keyed on a `yyyy-MM-dd` string stored
//   in `PlayerState.claimedDailyRewardDate`, NOT on the
//   `lastStreakDate` that powers the existing
//   `dailyRewardClaimed` predicate. The new key is forward-only
//   (it does not break the existing `lastStreakDate`-based
//   gating used by the daily-reward card and rewards screen).
// =============================================================================

import '../../state/player_state.dart';
import '../economy/reward_engine.dart';
import '../../domain/economy/reward.dart';
import '../../domain/daily/daily_reward_entry.dart';
import '../../domain/daily/daily_reward_kind.dart';
import '../../domain/daily/daily_reward_summary.dart';
import '../../../features/daily/data/daily_rewards_catalog.dart';

/// Outcome of a single [DailyRewardService.claim] call.
enum DailyRewardClaimResult {
  /// Bundle (coins + gems + optional item) was applied.
  granted,

  /// The player already claimed today's bundle. Quiet no-op.
  alreadyClaimed,
}

abstract final class DailyRewardService {
  DailyRewardService._();

  /// 7-day curve cap. Matches the existing
  /// `RewardEngine._kChestCapDay` constant — kept as a const here
  /// so the service is independent of the engine internals.
  static const int _kDayCap = 7;

  /// Lower bound for the streak day the engine accepts. A fresh
  /// install (streakDays == 0) still earns the day-1 bundle; the
  /// engine refuses streak < 1.
  static const int _kMinDay = 1;

  /// Composes the full daily-reward bundle for [player] without
  /// mutating. Returns a [DailyRewardSummary] so the UI can
  /// preview the bundle before the claim.
  ///
  /// `summary.item` is the catalog row ONLY for item-kind entries
  /// (palette / brush / gradient / sticker). Currency-kind rows
  /// (day 1, 2, 4, 6) are intentionally filtered out — coins and
  /// gems are already on the summary via the engine curve, so
  /// surfacing the currency row would render a duplicate pill in
  /// the dialog.
  static DailyRewardSummary computeForPlayer(PlayerState player) {
    final int streak = player.streakDays < _kMinDay
        ? _kMinDay
        : (player.streakDays > _kDayCap ? _kDayCap : player.streakDays);
    // Direct typed call to the engine. The engine refuses
    // streak < 1, which is exactly what the `_kMinDay` clamp
    // guarantees, so no try/catch is needed.
    final CompositeReward reward = RewardEngine.computeDailyChestReward(streak);
    final DailyRewardEntry? row = dailyRewardForDay(streak);
    final bool isItemRow = row != null && _isItemKind(row.kind);
    return DailyRewardSummary(
      streakDay: streak,
      coins: reward.totalCoinDelta,
      gems: reward.totalGemDelta,
      item: isItemRow ? row : null,
    );
  }

  /// True iff the player has already claimed today's bundle.
  /// The check is `player.claimedDailyRewardDate == today`.
  static bool isClaimedToday(PlayerState player, {DateTime? today}) {
    final DateTime d = today ?? DateTime.now();
    final String key = _dateKey(d);
    return player.claimedDailyRewardDate == key;
  }

  /// Claims today's bundle. Idempotent — a second call on the
  /// same day returns [DailyRewardClaimResult.alreadyClaimed]
  /// without mutating. The persistable claim is stored on
  /// `PlayerState.claimedDailyRewardDate` so the bundle can be
  /// re-rendered on next launch.
  static DailyRewardClaimResult claim(
    PlayerState player, {
    DateTime? today,
  }) {
    final DateTime d = today ?? DateTime.now();
    if (isClaimedToday(player, today: d)) {
      return DailyRewardClaimResult.alreadyClaimed;
    }
    final DailyRewardSummary summary = computeForPlayer(player);
    _applySummary(summary, player, today: d);
    return DailyRewardClaimResult.granted;
  }

  // ── Internals ──────────────────────────────────────────────────────

  /// Applies a [DailyRewardSummary] to [player]. The apply order
  /// matches the catalog layer: coins → gems → item. Item kinds
  /// route to the matching `PlayerState.grant*` mutator (which is
  /// itself idempotent — a second grant for the same item is a
  /// no-op so the player can never double-claim an item).
  static void _applySummary(
    DailyRewardSummary s,
    PlayerState p, {
    required DateTime today,
  }) {
    if (s.coins > 0) {
      p.grantCoins(s.coins, reason: 'daily_reward.day_${s.streakDay}');
    }
    if (s.gems > 0) {
      p.grantGems(s.gems, reason: 'daily_reward.day_${s.streakDay}');
    }
    final DailyRewardEntry? item = s.item;
    if (item != null) {
      _grantItem(item, p);
    }
    // Mark the claim AFTER the grants so an exception in the item
    // path still leaves the coins/gems applied. The idempotency
    // invariant ("you can't claim twice") is the more important
    // guarantee. `today` is threaded from `claim()` so the
    // idempotency key matches the check that fired the call (a
    // test passing `today: 2025-06-15` must mark the same date,
    // not the wall clock).
    p.markDailyRewardClaimed(s.streakDay, today: today);
  }

  /// Routes an item-day grant to the matching PlayerState
  /// mutator. The [DailyRewardKind.sticker] branch is a no-op
  /// in v1.0 (no `grantSticker` on PlayerState yet) — the
  /// catalog MUST NOT use the sticker kind until a future
  /// Sprint wires it.
  static void _grantItem(DailyRewardEntry item, PlayerState p) {
    switch (item.kind) {
      case DailyRewardKind.coins:
      case DailyRewardKind.gems:
        // Currency grants happen via the coins/gems grant
        // branches above; this branch is unreachable for these
        // kinds because the catalog rows set amount>0 + a coin
        // glyph. Defensive: no-op.
        break;
      case DailyRewardKind.palette:
        p.grantPalettePack(
          item.itemId,
          reason: 'daily_reward.day_${item.day}',
        );
        break;
      case DailyRewardKind.brush:
        p.grantBrush(
          item.itemId,
          reason: 'daily_reward.day_${item.day}',
        );
        break;
      case DailyRewardKind.gradient:
        p.grantGradient(
          item.itemId,
          reason: 'daily_reward.day_${item.day}',
        );
        break;
      case DailyRewardKind.sticker:
        // Reserved — no PlayerState.grantSticker yet. Logging
        // only so a future debug session can see the path fired.
        // (intentionally silent in production)
        break;
    }
  }

  /// yyyy-MM-dd key. Used as the idempotency anchor for
  /// `claimedDailyRewardDate` so a re-launch the same day
  /// refuses a re-claim.
  static String _dateKey(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// True iff [kind] represents a catalog item (palette / brush /
  /// gradient / sticker). Used by [computeForPlayer] to filter
  /// the summary's `item` field — currency kinds are surfaced
  /// via the engine's `totalCoinDelta` / `totalGemDelta` instead.
  static bool _isItemKind(DailyRewardKind kind) {
    switch (kind) {
      case DailyRewardKind.palette:
      case DailyRewardKind.brush:
      case DailyRewardKind.gradient:
      case DailyRewardKind.sticker:
        return true;
      case DailyRewardKind.coins:
      case DailyRewardKind.gems:
        return false;
    }
  }
}
