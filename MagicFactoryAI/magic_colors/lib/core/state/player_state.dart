// =============================================================================
// Magic Colors · core/state/player_state.dart
// =============================================================================
//
// Player economy + entitlements. Backed by a single Hive `Box<dynamic>`
// so the data survives crashes without a server round-trip. Acts as the
// authoritative source for:
//   • `coins`, `gems`               — virtual currency balances.
//   • `isPremium`, `premiumExpiresAt` — subscription state.
//   • `ownedWorldIds`               — which worlds are unblocked.
//   • `avatarId`                    — current avatar skin.
//   • `streakDays`, `lastStreakDate` — daily-streak retention counter.
//
// M2.3 — PALETTE v2 ADDITIONS
//   • `recentColorIds`     — MRU list (front = most-recent), capacity 8.
//   • `favoriteColorIds`   — Set-as-List of favorited palette indexes.
//   • `unlockedColorIds`   — Set-as-List of tier-1 colors unlocked via
//                            coins OR stars (premium colors stay in a
//                            separate gate — `player.isPremium`).
//
// Validation rules:
//   • `spendCoins` / `spendGems` refuse negative balances and return
//     `false` so calling code can show a "Not enough coins" toast.
//   • `isPremium` is derived (active subscription OR expiry in the future).
//   • `recordStreak` advances the streak iff the previous day was
//     yesterday, otherwise resets to 1.
//   • `unlockColorWithCoins` / `unlockColorWithStars` refuse when the
//     player cannot afford the cost; both delegate to the underlying
//     [spendCoins]/[grantWorldStars] writer so audit logs match.
// =============================================================================

// ignore_for_file: unnecessary_brace_in_string_interps
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../data/hive_keys.dart';
import '../utils/logger.dart';

/// M2.4 — the two ParentGate flavours. [math] always goes through the
/// 3-tries math challenge. [hold] is the carry-over shortcut for adults
/// who have already proven themselves once.
enum ParentGateKind { math, hold }

// ── Hive key constants ───────────────────────────────────────────────────
// All keys live in `core/data/hive_keys.dart` so writers and readers share
// one literal and a rename can never desync PlayerState from any future
// subscriber (AchievementService telemetry, QA exports, migration code,
// persistence round-trip tests). The prepend is for readability only.
const String _kCoinsKey = 'player.coins';
const String _kGemsKey = 'player.gems';
const String _kPremiumKey = 'player.isPremium';
const String _kPremiumExpiryKey = 'player.premiumExpiresAt';
const String _kOwnedWorldsKey = 'player.ownedWorldIds';
const String _kAvatarKey = 'player.avatarId';
const String _kWorldStarsKey = hiveKeyWorldStars;
const String _kUnlockedAchievementIdsKey = hiveKeyUnlockedAchievementIds;
const String _kStreakDaysKey = hiveKeyStreakDays;
const String _kLastStreakDateKey = hiveKeyLastStreakDate;
// M2.3 — Palette v2 persistence.
const String _kRecentColorIdsKey = hiveKeyRecentColorIds;
const String _kFavoriteColorIdsKey = hiveKeyFavoriteColorIds;
const String _kUnlockedColorIdsKey = hiveKeyUnlockedColorIds;
// M2.4 — ParentGate persistence.
const String _kParentGateMathOkKey = hiveKeyParentGateMathOk;
const String _kParentGateLastFailureAtKey = hiveKeyParentGateLastFailureAt;
// Sprint 5 — Shop ownership persistence. Keys live in
// core/data/hive_keys.dart so a rename can never desync the writer
// (PlayerState) from the reader (UnlockService).
const String _kOwnedPalettePackIdsKey = hiveKeyOwnedPalettePackIds;
const String _kOwnedBrushIdsKey = hiveKeyOwnedBrushIds;
const String _kOwnedGradientIdsKey = hiveKeyOwnedGradientIds;
// Sprint 6 — World Progression persistence. Same convention: keys
// live in core/data/hive_keys.dart so a rename can never desync
// the writer (PlayerState) from the reader
// (FirstUnlockService / CompletionRewardService / world_detail
// progress section).
const String _kCelebratedWorldIdsKey = hiveKeyCelebratedWorldIds;
const String _kClaimedWorldRewardIdsKey = hiveKeyClaimedWorldRewardIds;

// =============================================================================
//  PlayerState — ChangeNotifier.
// =============================================================================

final class PlayerState extends ChangeNotifier {
  PlayerState._bound(this._box) {
    _hydrate();
  }

  PlayerState._empty() : _box = null {
    _hydrate();
  }

  /// Opens the underlying Hive box and constructs the [PlayerState]. The
  /// caller is responsible for awaiting `Hive.openBox<dynamic>('player')`.
  /// This is the production path — pop the box before app start.
  factory PlayerState.fromBox(Box<dynamic> box) => PlayerState._bound(box);

  /// M2.4 PHASE 2 — constructs a [PlayerState] that does NOT touch any
  /// `Box`. All read helpers fall back to their type defaults (in-memory
  /// mode), all `_persist` calls become no-ops. Enables widget tests that
  /// need the full [PlayerState] observable surface without paying the
  /// cost of bringing up Hive's background isolate.
  ///
  /// Production callers MUST use [PlayerState.fromBox] — this factory
  /// exists ONLY so widget tests on Win32 can bypass the fake-async
  /// zone hang we hit when Hive.openBox + isolate teardown races
  /// flutter_test's "did not complete" check.
  ///
  /// The `@visibleForTesting` annotation enforces that contract at
  /// compile time — any production caller that reaches for `.inMemory()`
  /// gets a static analyzer error rather than a runtime bug.
  @visibleForTesting
  factory PlayerState.inMemory() => PlayerState._empty();

  /// Nullable so [PlayerState.inMemory] can construct without a Box.
  /// Read helpers null-check `_box ??` and return type defaults; the
  /// [_persist] helper uses `_box?.put(...)` (no-op when null).
  final Box<dynamic>? _box;

  // ── Defaults ──────────────────────────────────────────────────────────
  static const int _defaultCoins = 0;
  static const int _defaultGems = 5;
  static const String _defaultAvatar = 'avatar_default';
  static const int _defaultStreak = 0;
  static const Set<String> _starterWorlds = <String>{'unicorn'};

  /// M2.3 recent MRU capacity. Exposed as a static const so the writer
  /// and the UI agree on the visible row count.
  static const int kRecentMruCapacity = 8;

  /// M2.4 — duration during which a failed math-challenge keeps the
  /// ParentGate locked. After this window the user may reattempt.
  static const Duration parentGateFailLockout = Duration(hours: 24);

  // ── Public read model ──────────────────────────────────────────────────
  int _coins = _defaultCoins;
  int _gems = _defaultGems;
  bool _isPremium = false;
  DateTime? _premiumExpiresAt;
  Set<String> _ownedWorldIds = <String>{..._starterWorlds};
  String _avatarId = _defaultAvatar;
  int _streakDays = _defaultStreak;
  DateTime? _lastStreakDate;

  /// Per-world earned stars (0..3 each). Lazily hydrated from Hive as a
  /// `Map<String, int>`; falls back to an empty map if schema-drift or
  /// box corruption makes the entry unreadable. Stars are the unlock
  /// currency across worlds and the quality metric per drawing.
  Map<String, int> _worldStars = const <String, int>{};

  /// Set of achievement ids that have been granted at least once.
  /// Persisted as a `List<String>` (Hive has no Set adapter natively);
  /// on read we rebuild the Set. Anything that fails to cast returns
  /// an empty set so the PlayerState can never crash cold-start.
  Set<String> _unlockedAchievementIds = const <String>{};

  // ── M2.3 — Palette v2 state ────────────────────────────────────────────
  /// Recent colours MRU. Most-recent at the front (index 0). Capped at
  /// [kRecentMruCapacity]. Persisted as a `List<int>` of palette
  /// indexes for cheap O(1) sibling lookups.
  List<int> _recentColorIds = <int>[];

  /// Player-favourited palette indexes. Persisted as a `List<int>` —
  /// semantically a Set; the writer deduplicates on insert.
  List<int> _favoriteColorIds = <int>[];

  /// Indexes of tier-1 colours the player has unlocked (via coins or
  /// stars). Persisted as a `List<int>`.
  List<int> _unlockedColorIds = <int>[];

  // ── Sprint 5 — Shop ownership state ──────────────────────────────────────
  /// Palette pack ids the player has bought from the Shop. Backed by
  /// Hive so ownership survives crashes. The Shop card uses this set
  /// to render the OWNED status badge.
  Set<String> _ownedPalettePackIds = const <String>{};

  /// Brush ids the player has bought from the Shop. Same persistence
  /// contract as the palette-pack set.
  Set<String> _ownedBrushIds = const <String>{};

  /// Gradient ids the player has bought from the Shop. Same
  /// persistence contract as the palette-pack set.
  Set<String> _ownedGradientIds = const <String>{};

  /// M2.4 — ParentGate math-challenge accept flag. True once the user
  /// has successfully solved the math challenge; flips back to false
  /// after a failed attempt. Persisted as `bool`.
  bool _parentGateMathOk = false;

  /// M2.4 — last ParentGate math-challenge failure stamp. When set,
  /// the gate is locked for [parentGateFailLockout] from this time.
  /// `null` when there has never been a failure.
  DateTime? _parentGateLastFailureAt;

  // ── Sprint 6 — World Progression state ──────────────────────────────────
  /// World ids whose "NEW" celebration the player has dismissed.
  /// Backed by Hive so the celebration is genuinely one-shot across
  /// sessions. The World Map uses this set to drop the "NEW" badge
  /// from islands whose dialog has been seen.
  Set<String> _celebratedWorldIds = const <String>{};

  /// World ids whose completion reward has been claimed at least
  /// once. Backed by Hive so the claim is idempotent across
  /// sessions. CompletionRewardService refuses to grant twice.
  Set<String> _claimedWorldRewardIds = const <String>{};

  int get coins => _coins;
  int get gems => _gems;

  /// `true` if either `_isPremium` is true AND the expiry is in the future.
  /// Once the subscription lapses, [isPremium] flips back to `false`
  /// automatically on the next read.
  bool get isPremium {
    if (!_isPremium) {
      return false;
    }
    final expiry = _premiumExpiresAt;
    return expiry == null || expiry.isAfter(DateTime.now());
  }

  DateTime? get premiumExpiresAt => _premiumExpiresAt;
  Set<String> get ownedWorldIds => Set<String>.unmodifiable(_ownedWorldIds);
  String get avatarId => _avatarId;
  int get streakDays => _streakDays;
  DateTime? get lastStreakDate => _lastStreakDate;

  /// Read-only view of the per-world earned stars. Returns an
  /// unmodifiable map so callers cannot accidentally mutate the live
  /// state-for-grant. Use [getWorldStars] for single-world reads.
  Map<String, int> get worldStars => Map<String, int>.unmodifiable(_worldStars);

  /// Returns the earned-stars count for [worldId], defaulting to 0
  /// when the world has never been played.
  int getWorldStars(String worldId) => _worldStars[worldId] ?? 0;

  /// Read-only view of the unlocked achievement-id set.
  Set<String> get unlockedAchievementIds =>
      Set<String>.unmodifiable(_unlockedAchievementIds);

  // ── M2.3 — Palette v2 read ─────────────────────────────────────────────
  /// Read-only view of the recent-colours MRU. Most-recent at index 0.
  List<int> get recentColorIds => List<int>.unmodifiable(_recentColorIds);

  /// Read-only view of the favourite colour indexes.
  List<int> get favoriteColorIds => List<int>.unmodifiable(_favoriteColorIds);

  /// Read-only view of the unlocked tier-1 colour indexes.
  List<int> get unlockedColorIds => List<int>.unmodifiable(_unlockedColorIds);

  // ── Sprint 5 — Shop ownership read ───────────────────────────────────────
  /// Read-only view of the owned palette-pack ids (set by the Shop
  /// card tap → UnlockService).
  Set<String> get ownedPalettePackIds =>
      Set<String>.unmodifiable(_ownedPalettePackIds);

  /// Read-only view of the owned brush ids.
  Set<String> get ownedBrushIds => Set<String>.unmodifiable(_ownedBrushIds);

  /// Read-only view of the owned gradient ids.
  Set<String> get ownedGradientIds =>
      Set<String>.unmodifiable(_ownedGradientIds);

  // ── Sprint 6 — World Progression read ──────────────────────────────────
  /// Read-only view of the celebrated-world-id set.
  Set<String> get celebratedWorldIds =>
      Set<String>.unmodifiable(_celebratedWorldIds);

  /// Read-only view of the claimed-world-reward-id set.
  Set<String> get claimedWorldRewardIds =>
      Set<String>.unmodifiable(_claimedWorldRewardIds);

  /// True iff the player has celebrated [worldId] (the "NEW" toast
  /// has been dismissed at least once).
  bool hasCelebratedWorld(String worldId) =>
      _celebratedWorldIds.contains(worldId);

  /// True iff the completion reward for [worldId] has been claimed.
  bool hasClaimedWorldReward(String worldId) =>
      _claimedWorldRewardIds.contains(worldId);

  // ── M2.4 — ParentGate read ──────────────────────────────────────────
  /// True iff the user has successfully completed a math challenge
  /// at least once AND has not failed one since.
  bool get parentGateMathOk => _parentGateMathOk;

  /// Last ParentGate math challenge failure stamp (or null).
  DateTime? get parentGateLastFailureAt => _parentGateLastFailureAt;

  /// M2.4 — true iff the user is still within the 24h lockout window
  /// after a failure. While locked, even math-OK users must re-pass
  /// the math challenge before unlocking premium colours.
  bool get parentGateFailureLocked {
    final DateTime? fail = _parentGateLastFailureAt;
    if (fail == null) return false;
    return DateTime.now().difference(fail) < PlayerState.parentGateFailLockout;
  }

  /// M2.4 — true iff the daily chest has already been claimed today.
  /// Synchronous derivation off [_lastStreakDate] (set every time
  /// [recordStreak] runs, which is the very first call inside
  /// [HomeController.onClaimDailyReward]). Avoids a separate Hive key —
  /// the streak system already records the day-of-claim.
  bool get dailyRewardClaimed {
    final DateTime? last = _lastStreakDate;
    if (last == null) return false;
    final DateTime now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }

  /// M2.4 — picks the gate flavour the UI should render.
  /// • `math` — first ever unlock OR a recent failure within lockout.
  /// • `hold` — math already accepted AND outside the lockout.
  ParentGateKind parentGateKind() {
    if (!_parentGateMathOk) return ParentGateKind.math;
    if (parentGateFailureLocked) return ParentGateKind.math;
    return ParentGateKind.hold;
  }

  // ── Convenience predicates ───────────────────────────────────────────
  bool ownsWorld(String worldId) => _ownedWorldIds.contains(worldId);
  bool canAffordCoins(int cost) => _coins >= cost;
  bool canAffordGems(int cost) => _gems >= cost;

  // Sprint 5 — Shop ownership predicates. Cheap O(1) lookups so the
  // Shop card status can be derived per-rebuild without thrashing the
  // map.
  bool ownsPalettePack(String packId) =>
      _ownedPalettePackIds.contains(packId);
  bool ownsBrush(String brushId) => _ownedBrushIds.contains(brushId);
  bool ownsGradient(String gradientId) =>
      _ownedGradientIds.contains(gradientId);

  // ── Currency mutators ─────────────────────────────────────────────────
  /// Adds `amount` coins. Negative values are ignored. Idempotent for
  /// amount == 0.
  void grantCoins(int amount, {String reason = 'unspecified'}) {
    if (amount <= 0) {
      return;
    }
    _coins = _coins + amount;
    _persist(_kCoinsKey, _coins);
    logger.info('PlayerState.grantCoins +$amount (reason=$reason) → $_coins');
    notifyListeners();
  }

  /// Attempts to spend `amount` coins. Returns `false` (without mutating)
  /// if the player cannot afford it.
  bool spendCoins(int amount, {String reason = 'unspecified'}) {
    if (amount <= 0) {
      return false;
    }
    if (_coins < amount) {
      logger.warn(
        'PlayerState.spendCoins refused: need=$amount have=$_coins',
      );
      return false;
    }
    _coins = _coins - amount;
    _persist(_kCoinsKey, _coins);
    logger.info('PlayerState.spendCoins -$amount (reason=$reason) → $_coins');
    notifyListeners();
    return true;
  }

  void grantGems(int amount, {String reason = 'unspecified'}) {
    if (amount <= 0) {
      return;
    }
    _gems = _gems + amount;
    _persist(_kGemsKey, _gems);
    logger.info('PlayerState.grantGems +$amount (reason=$reason) → $_gems');
    notifyListeners();
  }

  bool spendGems(int amount, {String reason = 'unspecified'}) {
    if (amount <= 0) {
      return false;
    }
    if (_gems < amount) {
      logger.warn('PlayerState.spendGems refused: need=$amount have=$_gems');
      return false;
    }
    _gems = _gems - amount;
    _persist(_kGemsKey, _gems);
    logger.info('PlayerState.spendGems -$amount (reason=$reason) → $_gems');
    notifyListeners();
    return true;
  }

  // ── Entitlement mutators ─────────────────────────────────────────────
  /// Records a successful Premium purchase (or restore). When [expiresAt]
  /// is null, the subscription is treated as lifetime.
  void setPremium(bool value, {DateTime? expiresAt}) {
    _isPremium = value;
    _premiumExpiresAt = expiresAt;
    _persist(_kPremiumKey, value);
    _persist(_kPremiumExpiryKey, expiresAt);
    logger.info('PlayerState.setPremium = $value expires=$expiresAt');
    notifyListeners();
  }

  /// Adds `worldId` to the owned-worlds set. Idempotent.
  void unlockWorld(String worldId) {
    if (_ownedWorldIds.contains(worldId)) {
      return;
    }
    _ownedWorldIds = <String>{..._ownedWorldIds, worldId};
    _persistList(_kOwnedWorldsKey, _ownedWorldIds.toList());
    logger.info('PlayerState.unlockWorld($worldId)');
    notifyListeners();
  }

  void setAvatar(String avatarId) {
    if (_avatarId == avatarId) {
      return;
    }
    _avatarId = avatarId;
    _persist(_kAvatarKey, avatarId);
    notifyListeners();
  }

  // ── Streak mutators ──────────────────────────────────────────────────
  /// Increments the daily streak iff the user opened the app today AND
  /// the last streak date was yesterday. Otherwise resets to 1.
  ///
  /// Edge cases handled (stable across regression tests):
  ///   • First-ever session → streak = 1.
  ///   • Same calendar day twice → idempotent (no double-counting).
  ///   • Next calendar day → streak += 1.
  ///   • Gap of 2+ days OR clock rollback → streak resets to 1.
  ///   • DST and timezone shifts → unaffected: `_lastStreakDate`
  ///     stores a pure calendar date (no time-of-day), so two calls
  ///     23 hours apart with DST between them still register as
  ///     "next day". Two calls 25 hours apart with DST between them
  ///     still register as "same day then next day".
  ///
  /// [now] is exposed for tests so the streak math can be verified
  /// across calendar boundaries without freezing the wall clock.
  /// Production callers MUST omit [now]; the doc-comment above is the
  /// sole guard — there is no annotation because putting
  /// `@visibleForTesting` on the whole method would also block the
  /// legitimate production call (splash/boot) that never passes [now].
  /// Tests MUST pass a fixed `DateTime`.
  ///
  /// Returns the new streak value.
  int recordStreak({DateTime? now}) {
    return _recordStreakAt(now ?? DateTime.now());
  }

  /// Internal form of [recordStreak] with the wall-clock parameter
  /// namespaced to a single field. Kept private to keep the boundary
  /// between "production call site" and "test call site" explicit.
  int _recordStreakAt(DateTime now) {
    // Strip the time component to compare calendar days independently of
    // wall-clock quirks (DST, timezone changes, clock drift during a
    // flight mode). Using local-year/month/day is intentional — the
    // user perceives a "day" in the local sense, not UTC.
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? previous = _lastStreakDate;

    if (previous == null) {
      _streakDays = 1;
    } else {
      final DateTime prevDay = DateTime(
        previous.year,
        previous.month,
        previous.day,
      );
      final int diff = today.difference(prevDay).inDays;
      if (diff <= 0) {
        // Same calendar day (diff == 0) — idempotent.
        // OR clock rolled backwards (diff < 0) — treat as "today".
        // Returning early keeps the persisted timestamp anchored on
        // the LAST observation so a future legitimate tick still
        // increments.
        return _streakDays;
      } else if (diff == 1) {
        _streakDays = _streakDays + 1;
      } else {
        // Gap of 2+ days (or forward clock drift) → reset to 1.
        _streakDays = 1;
      }
    }

    _lastStreakDate = today;
    _persist(_kStreakDaysKey, _streakDays);
    _persist(_kLastStreakDateKey, _lastStreakDate);
    logger.info('PlayerState.recordStreak → $_streakDays');
    notifyListeners();
    return _streakDays;
  }

  /// Awards [delta] stars to [worldId] (clamped to 3 per world so the
  /// quality metric never inflates past the game-design ceiling). Idempotent
  /// against non-positive deltas. Persisted as `Map<String, int>` so adding
  /// new worlds to the catalog needs no schema migration.
  void grantWorldStars(String worldId, int delta,
      {String reason = 'unspecified'}) {
    if (delta == 0) {
      return;
    }
    final int current = _worldStars[worldId] ?? 0;
    final int next = (current + delta).clamp(0, 3);
    if (next == current) {
      return; // Cap reached (only relevant when delta would go past 3).
    }
    _worldStars = <String, int>{
      ..._worldStars,
      worldId: next,
    };
    _persistMap(_kWorldStarsKey, _worldStars);
    logger.info(
      'PlayerState.grantWorldStars ${delta >= 0 ? "+" : ""}${next - current} '
      'for $worldId → $next (reason=$reason)',
    );
    notifyListeners();
  }

  /// Permanently marks [achievementId] as unlocked. Returns true iff the
  /// achievement was NEWLY added (idempotent across multiple save ticks).
  /// Caller is responsible for granting the matching reward before / after
  /// this call — this method only persists the "seen it" flag.
  bool unlockAchievement(String achievementId,
      {String reason = 'unspecified'}) {
    if (achievementId.isEmpty) {
      return false;
    }
    if (_unlockedAchievementIds.contains(achievementId)) {
      return false;
    }
    _unlockedAchievementIds = <String>{
      ..._unlockedAchievementIds,
      achievementId,
    };
    _persistList(_kUnlockedAchievementIdsKey, _unlockedAchievementIds.toList());
    logger.info(
      'PlayerState.unlockAchievement ${achievementId} (reason=$reason)',
    );
    notifyListeners();
    return true;
  }

  // ── M2.3 — Palette v2 mutators ────────────────────────────────────────

  /// Appends [paletteIndex] to the front of the recent-colours MRU.
  /// De-duplicates against any prior occurrence so the user sees one
  /// MRU slot per colour, then truncates to [kRecentMruCapacity].
  /// Negative indexes are ignored (defensive — controllers should
  /// already clamp).
  void addRecentColor(int paletteIndex) {
    if (paletteIndex < 0) {
      return;
    }
    _recentColorIds = <int>[
      paletteIndex,
      ..._recentColorIds.where((int i) => i != paletteIndex),
    ];
    if (_recentColorIds.length > kRecentMruCapacity) {
      _recentColorIds = _recentColorIds.sublist(0, kRecentMruCapacity);
    }
    _persist(_kRecentColorIdsKey, _recentColorIds);
    notifyListeners();
  }

  /// Idempotent favourite toggle. Returns true iff the colour is now
  /// favourited (false when removed). Mirrors the player's long-press
  /// on a swatch.
  bool toggleFavoriteColor(int paletteIndex) {
    if (paletteIndex < 0) {
      return false;
    }
    final bool nowFavorited;
    if (_favoriteColorIds.contains(paletteIndex)) {
      _favoriteColorIds =
          _favoriteColorIds.where((int i) => i != paletteIndex).toList();
      nowFavorited = false;
    } else {
      _favoriteColorIds = <int>[..._favoriteColorIds, paletteIndex];
      nowFavorited = true;
    }
    _persist(_kFavoriteColorIdsKey, _favoriteColorIds);
    notifyListeners();
    return nowFavorited;
  }

  /// Spend coins to unlock a tier-1 colour. Refuses if the cost exceeds
  /// the player's balance. Returns true on success.
  bool unlockColorWithCoins({
    required int paletteIndex,
    required int cost,
  }) {
    if (paletteIndex < 0 || cost <= 0) {
      return false;
    }
    if (_unlockedColorIds.contains(paletteIndex)) {
      return true; // idempotent success.
    }
    if (_coins < cost) {
      logger.warn(
        'PlayerState.unlockColorWithCoins refused: '
        'need=$cost have=$_coins for index=$paletteIndex',
      );
      return false;
    }
    _coins = _coins - cost;
    _persist(_kCoinsKey, _coins);
    _unlockedColorIds = <int>[..._unlockedColorIds, paletteIndex];
    _persist(_kUnlockedColorIdsKey, _unlockedColorIds);
    logger.info(
      'PlayerState.unlockColorWithCoins -$cost → '
      'unlockedColorIds=$_unlockedColorIds.length',
    );
    notifyListeners();
    return true;
  }

  /// Spend stars in [worldId] to unlock a tier-1 colour. Refuses if the
  /// cost exceeds that world's earned stars. Returns true on success.
  bool unlockColorWithStars({
    required String worldId,
    required int paletteIndex,
    required int cost,
  }) {
    if (paletteIndex < 0 || cost <= 0) {
      return false;
    }
    if (_unlockedColorIds.contains(paletteIndex)) {
      return true; // idempotent success.
    }
    final int current = getWorldStars(worldId);
    if (current < cost) {
      logger.warn(
        'PlayerState.unlockColorWithStars refused: '
        'need=$cost have=$current world=$worldId index=$paletteIndex',
      );
      return false;
    }
    grantWorldStars(worldId, -cost, reason: 'color-unlock');
    _unlockedColorIds = <int>[..._unlockedColorIds, paletteIndex];
    _persist(_kUnlockedColorIdsKey, _unlockedColorIds);
    logger.info(
      'PlayerState.unlockColorWithStars -$cost world=$worldId → '
      'unlockedColorIds=$_unlockedColorIds.length',
    );
    notifyListeners();
    return true;
  }

  // ── Internals ─────────────────────────────────────────────────────────
  void _hydrate() {
    _coins = _readOrDefault<int>(_kCoinsKey, _defaultCoins);
    _gems = _readOrDefault<int>(_kGemsKey, _defaultGems);
    _isPremium = _readOrDefault<bool>(_kPremiumKey, false);
    _premiumExpiresAt = _readOrNull<DateTime>(_kPremiumExpiryKey);
    _ownedWorldIds = _readOwnedWorlds();
    _avatarId = _readOrDefault<String>(_kAvatarKey, _defaultAvatar);
    _streakDays = _readOrDefault<int>(_kStreakDaysKey, _defaultStreak);
    _lastStreakDate = _readOrNull<DateTime>(_kLastStreakDateKey);
    _worldStars = _readMapOrEmpty<String, int>(_kWorldStarsKey);
    _unlockedAchievementIds = _readIdSet(_kUnlockedAchievementIdsKey);

    // M2.3 hydrate — 3 new lists. All idempotent on cast failure.
    _recentColorIds = _readIntListOrEmpty(_kRecentColorIdsKey);
    _favoriteColorIds = _readIntListOrEmpty(_kFavoriteColorIdsKey);
    _unlockedColorIds = _readIntListOrEmpty(_kUnlockedColorIdsKey);

    // M2.4 hydrate — ParentGate. Both entries are fault-tolerant.
    _parentGateMathOk = _readOrDefault<bool>(_kParentGateMathOkKey, false);
    _parentGateLastFailureAt =
        _readOrNull<DateTime>(_kParentGateLastFailureAtKey);

    // Sprint 5 hydrate — 3 Shop ownership sets. Same fault-tolerant
    // contract as `_unlockedAchievementIds` (rebuild from a List on
    // cast failure).
    _ownedPalettePackIds = _readIdSet(_kOwnedPalettePackIdsKey);
    _ownedBrushIds = _readIdSet(_kOwnedBrushIdsKey);
    _ownedGradientIds = _readIdSet(_kOwnedGradientIdsKey);

    // Sprint 6 hydrate — 2 World Progression sets. Same fault-
    // tolerant contract. Both default to empty so a corrupted box
    // cannot trigger a spurious celebration or re-grant a reward.
    _celebratedWorldIds = _readIdSet(_kCelebratedWorldIdsKey);
    _claimedWorldRewardIds = _readIdSet(_kClaimedWorldRewardIdsKey);
  }

  // ── M2.4 — ParentGate mutators ───────────────────────────────────────

  /// M2.4 — record a successful math-challenge answer. Flips the
  /// math-OK flag true and clears any pending failure stamp so the
  /// hold-to-confirm shortcut becomes available immediately.
  void recordParentGateMathSuccess() {
    if (_parentGateMathOk && _parentGateLastFailureAt == null) {
      return;
    }
    _parentGateMathOk = true;
    _parentGateLastFailureAt = null;
    _persist(_kParentGateMathOkKey, _parentGateMathOk);
    _persist(_kParentGateLastFailureAtKey, _parentGateLastFailureAt);
    logger.info('PlayerState.recordParentGateMathSuccess → math-ok');
    notifyListeners();
  }

  /// M2.4 — record a failed math-challenge attempt (caller fires this
  /// after the user has burned the 3 tries). Sets the failure stamp
  /// to now; the math-OK flag stays false so subsequent unlocks still
  /// trigger the challenge.
  void recordParentGateMathFailure() {
    _parentGateMathOk = false;
    _parentGateLastFailureAt = DateTime.now();
    _persist(_kParentGateMathOkKey, _parentGateMathOk);
    _persist(_kParentGateLastFailureAtKey, _parentGateLastFailureAt);
    logger.info('PlayerState.recordParentGateMathFailure → locked 24h');
    notifyListeners();
  }

  /// M2.4 — record a successful hold-to-confirm. Currently a no-op
  /// reservation point so future telemetry (analytics) can hang here.
  void recordParentGateHoldSuccess() {
    logger.info('PlayerState.recordParentGateHoldSuccess → accepted');
  }

  /// Same contract as AppState._readOrDefault — returns [defaultValue] if
  /// the entry is missing or the cast fails (logged), so the provider
  /// never crashes a cold start on a schema-drift. When constructed via
  /// [PlayerState.inMemory] (no box) skips the read and returns the
  /// default directly.
  T _readOrDefault<T>(String key, T defaultValue) {
    final Box<dynamic>? box = _box;
    if (box == null) return defaultValue;
    try {
      return box.get(key, defaultValue: defaultValue) as T;
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._readOrDefault<$T> cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return defaultValue;
    }
  }

  /// Nullable read with cast-failure → null + logger.error. Returns null
  /// for [PlayerState.inMemory] (no box).
  T? _readOrNull<T>(String key) {
    final Box<dynamic>? box = _box;
    if (box == null) return null;
    try {
      return box.get(key) as T?;
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._readOrNull<$T> cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Reads the owned-worlds set with full type-safety. Hive 2 has no
  /// native Set adapter so we store it as `List<String>` — on read we
  /// rebuild the Set. Any TypeError (corrupted list, non-String entry,
  /// schema-drift) falls back to the starter set so the player always
  /// owns at least one world on first launch. Returns the starter set
  /// for [PlayerState.inMemory].
  Set<String> _readOwnedWorlds() {
    final Box<dynamic>? box = _box;
    if (box == null) return <String>{..._starterWorlds};
    try {
      final raw = box.get(_kOwnedWorldsKey);
      if (raw == null) {
        return <String>{..._starterWorlds};
      }
      return (raw as List).cast<String>().toSet();
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._readOwnedWorlds cast failed',
        error: error,
        stackTrace: stack,
      );
      return <String>{..._starterWorlds};
    }
  }

  /// Reads a Hive entry as `Map<String, int>` (or any typed `Map<k,v>`).
  /// Falls back to an empty map on schema-drift / cast failure so a
  /// corrupted box cannot crash cold-start. Returns an empty map for
  /// [PlayerState.inMemory].
  Map<K, V> _readMapOrEmpty<K, V>(String key) {
    final Box<dynamic>? box = _box;
    if (box == null) return <K, V>{};
    try {
      final raw = box.get(key);
      if (raw == null) {
        return <K, V>{};
      }
      return (raw as Map).cast<K, V>();
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._readMapOrEmpty<$K,$V> cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return <K, V>{};
    }
  }

  /// Reads a Hive entry as `List<String>` and rebuilds an unmodifiable
  /// `Set<String>`. Used for the unlocked-achievement-id list. On
  /// cast failure, swallows + logs and returns an empty set so the
  /// achievements flow can re-evaluate from a clean slate. Returns an
  /// empty set for [PlayerState.inMemory].
  Set<String> _readIdSet(String key) {
    final Box<dynamic>? box = _box;
    if (box == null) return const <String>{};
    try {
      final raw = box.get(key);
      if (raw == null) {
        return const <String>{};
      }
      return (raw as List).cast<String>().toSet();
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._readIdSet cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return const <String>{};
    }
  }

  /// M2.3 — reads a Hive entry as `List<int>`. Cast failure falls back
  /// to an empty list so a corrupted box (eg a user-imported save)
  /// cannot crash cold-start. Returns empty for [PlayerState.inMemory].
  List<int> _readIntListOrEmpty(String key) {
    final Box<dynamic>? box = _box;
    if (box == null) return <int>[];
    try {
      final raw = box.get(key);
      if (raw == null) {
        return <int>[];
      }
      return (raw as List).cast<int>().toList();
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._readIntListOrEmpty cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return <int>[];
    }
  }

  /// No-op when [_box] is null ([PlayerState.inMemory]). In production
  /// hits the box; on any throw we log + swallow so a failing persistence
  /// layer never crashes the observable surfaced (callers already see
  /// the in-memory values mutated).
  void _persist(String key, Object? value) {
    final Box<dynamic>? box = _box;
    if (box == null) return;
    try {
      box.put(key, value);
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._persist failed key=$key',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void _persistList(String key, List<String> values) {
    _persist(key, values);
  }

  // ── Sprint 5 — Shop ownership mutators ───────────────────────────────────

  /// Test seam — sets the economy balances in one call so unit tests
  /// can pin exact values without paying the cost of running a real
  /// earn/spend cycle (the default of 5 gems would otherwise skew
  /// every gem-balance assertion by 5). Production callers MUST use
  /// [grantCoins] / [grantGems]; the `@visibleForTesting` annotation
  /// is the analyzer guard.
  @visibleForTesting
  void setEconomyForTest({int coins = 0, int gems = 0}) {
    _coins = coins;
    _gems = gems;
    _persist(_kCoinsKey, _coins);
    _persist(_kGemsKey, _gems);
    notifyListeners();
  }

  /// Records that the player has bought [packId] from the Shop. Idempotent
  /// (a second call is a no-op). Called by [UnlockService.grantPalettePack]
  /// after the currency deduction succeeds.
  void grantPalettePack(String packId, {String reason = 'shop.palette_pack'}) {
    if (packId.isEmpty) {
      return;
    }
    if (_ownedPalettePackIds.contains(packId)) {
      return;
    }
    _ownedPalettePackIds = <String>{
      ..._ownedPalettePackIds,
      packId,
    };
    _persistList(_kOwnedPalettePackIdsKey, _ownedPalettePackIds.toList());
    logger.info('PlayerState.grantPalettePack($packId reason=$reason)');
    notifyListeners();
  }

  /// Records that the player has bought [brushId] from the Shop.
  /// Idempotent.
  void grantBrush(String brushId, {String reason = 'shop.brush'}) {
    if (brushId.isEmpty) {
      return;
    }
    if (_ownedBrushIds.contains(brushId)) {
      return;
    }
    _ownedBrushIds = <String>{
      ..._ownedBrushIds,
      brushId,
    };
    _persistList(_kOwnedBrushIdsKey, _ownedBrushIds.toList());
    logger.info('PlayerState.grantBrush($brushId reason=$reason)');
    notifyListeners();
  }

  /// Records that the player has bought [gradientId] from the Shop.
  /// Idempotent.
  void grantGradient(String gradientId, {String reason = 'shop.gradient'}) {
    if (gradientId.isEmpty) {
      return;
    }
    if (_ownedGradientIds.contains(gradientId)) {
      return;
    }
    _ownedGradientIds = <String>{
      ..._ownedGradientIds,
      gradientId,
    };
    _persistList(_kOwnedGradientIdsKey, _ownedGradientIds.toList());
    logger.info('PlayerState.grantGradient($gradientId reason=$reason)');
    notifyListeners();
  }

  /// Writes a typed map to the Hive box. Same swallow-and-log policy
  /// as [_persist].
  void _persistMap<K, V>(String key, Map<K, V> values) {
    _persist(key, values);
  }

  // ── Sprint 6 — World Progression mutators ──────────────────────────────

  /// Records that the player has dismissed the "NEW" celebration
  /// for [worldId]. Idempotent — a second call is a no-op. Called
  /// by [FirstUnlockService.markCelebrated] from the dialog's
  /// dismiss path so the same world never re-triggers the toast.
  void markWorldCelebrated(String worldId) {
    if (worldId.isEmpty) return;
    if (_celebratedWorldIds.contains(worldId)) return;
    _celebratedWorldIds = <String>{
      ..._celebratedWorldIds,
      worldId,
    };
    _persistList(_kCelebratedWorldIdsKey, _celebratedWorldIds.toList());
    logger.info('PlayerState.markWorldCelebrated($worldId)');
    notifyListeners();
  }

  /// Records that the player has claimed the completion reward for
  /// [worldId]. Idempotent — a second call is a no-op. Called by
  /// [CompletionRewardService] AFTER the coins/gems + auto-unlock
  /// are applied so the idempotency invariant ("you can't claim
  /// twice") holds even if the reward application throws.
  void claimWorldCompletionReward(String worldId) {
    if (worldId.isEmpty) return;
    if (_claimedWorldRewardIds.contains(worldId)) return;
    _claimedWorldRewardIds = <String>{
      ..._claimedWorldRewardIds,
      worldId,
    };
    _persistList(
      _kClaimedWorldRewardIdsKey,
      _claimedWorldRewardIds.toList(),
    );
    logger.info('PlayerState.claimWorldCompletionReward($worldId)');
    notifyListeners();
  }
}
