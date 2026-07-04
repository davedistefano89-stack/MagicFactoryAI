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

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../data/hive_keys.dart';
import '../utils/logger.dart';


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


// =============================================================================
//  PlayerState — ChangeNotifier.
// =============================================================================

final class PlayerState extends ChangeNotifier {
  PlayerState._(this._box) {
    _hydrate();
  }

  /// Opens the underlying Hive box and constructs the [PlayerState]. The
  /// caller is responsible for awaiting `Hive.openBox<dynamic>('player')`.
  factory PlayerState.fromBox(Box<dynamic> box) => PlayerState._(box);

  final Box<dynamic> _box;

  // ── Defaults ──────────────────────────────────────────────────────────
  static const int _defaultCoins = 0;
  static const int _defaultGems = 5;
  static const String _defaultAvatar = 'avatar_default';
  static const int _defaultStreak = 0;
  static const Set<String> _starterWorlds = <String>{'unicorn'};

  /// M2.3 recent MRU capacity. Exposed as a static const so the writer
  /// and the UI agree on the visible row count.
  static const int kRecentMruCapacity = 8;

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
  Map<String, int> get worldStars =>
      Map<String, int>.unmodifiable(_worldStars);

  /// Returns the earned-stars count for [worldId], defaulting to 0
  /// when the world has never been played.
  int getWorldStars(String worldId) => _worldStars[worldId] ?? 0;

  /// Read-only view of the unlocked achievement-id set.
  Set<String> get unlockedAchievementIds =>
      Set<String>.unmodifiable(_unlockedAchievementIds);

  // ── M2.3 — Palette v2 read ─────────────────────────────────────────────
  /// Read-only view of the recent-colours MRU. Most-recent at index 0.
  List<int> get recentColorIds =>
      List<int>.unmodifiable(_recentColorIds);

  /// Read-only view of the favourite colour indexes.
  List<int> get favoriteColorIds =>
      List<int>.unmodifiable(_favoriteColorIds);

  /// Read-only view of the unlocked tier-1 colour indexes.
  List<int> get unlockedColorIds =>
      List<int>.unmodifiable(_unlockedColorIds);


  // ── Convenience predicates ───────────────────────────────────────────
  bool ownsWorld(String worldId) => _ownedWorldIds.contains(worldId);
  bool canAffordCoins(int cost) => _coins >= cost;
  bool canAffordGems(int cost) => _gems >= cost;


  // ── Currency mutators ─────────────────────────────────────────────────
  /// Adds `amount` coins. Negative values are ignored. Idempotent for
  /// amount == 0.
  void grantCoins(int amount, {String reason = 'unspecified'}) {
    if (amount <= 0) {
      return;
    }
    _coins = _coins + amount;
    _persist(_kCoinsKey, _coins);
    logger.info('PlayerState.grantCoins +$amount (reason=$reason) → ${_coins}');
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
    logger.info('PlayerState.spendCoins -$amount (reason=$reason) → ${_coins}');
    notifyListeners();
    return true;
  }

  void grantGems(int amount, {String reason = 'unspecified'}) {
    if (amount <= 0) {
      return;
    }
    _gems = _gems + amount;
    _persist(_kGemsKey, _gems);
    logger.info('PlayerState.grantGems +$amount (reason=$reason) → ${_gems}');
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
    logger.info('PlayerState.spendGems -$amount (reason=$reason) → ${_gems}');
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
  void grantWorldStars(String worldId, int delta, {String reason = 'unspecified'}) {
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
  bool unlockAchievement(String achievementId, {String reason = 'unspecified'}) {
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
      _favoriteColorIds = _favoriteColorIds
          .where((int i) => i != paletteIndex)
          .toList();
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
      'unlockedColorIds=${_unlockedColorIds.length}',
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
      'unlockedColorIds=${_unlockedColorIds.length}',
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
  }

  /// Same contract as AppState._readOrDefault — returns [defaultValue] if
  /// the entry is missing or the cast fails (logged), so the provider
  /// never crashes a cold start on a schema-drift.
  T _readOrDefault<T>(String key, T defaultValue) {
    try {
      return _box.get(key, defaultValue: defaultValue) as T;
    } on Object catch (error, stack) {
      logger.error(
        'PlayerState._readOrDefault<$T> cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return defaultValue;
    }
  }

  /// Nullable read with cast-failure → null + logger.error.
  T? _readOrNull<T>(String key) {
    try {
      return _box.get(key) as T?;
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
  /// owns at least one world on first launch.
  Set<String> _readOwnedWorlds() {
    try {
      final raw = _box.get(_kOwnedWorldsKey);
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

  /// Reads a Hive entry as `Map<String, int>` (or any typed Map<k,v>).
  /// Falls back to an empty map on schema-drift / cast failure so a
  /// corrupted box cannot crash cold-start. Hive 2 supports maps
  /// natively — no custom adapter required.
  Map<K, V> _readMapOrEmpty<K, V>(String key) {
    try {
      final raw = _box.get(key);
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
  /// achievements flow can re-evaluate from a clean slate.
  Set<String> _readIdSet(String key) {
    try {
      final raw = _box.get(key);
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
  /// cannot crash cold-start.
  List<int> _readIntListOrEmpty(String key) {
    try {
      final raw = _box.get(key);
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

  void _persist(String key, Object? value) {
    try {
      _box.put(key, value);
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

  /// Writes a typed map to the Hive box. Same swallow-and-log policy
  /// as [_persist].
  void _persistMap<K, V>(String key, Map<K, V> values) {
    _persist(key, values);
  }
}
