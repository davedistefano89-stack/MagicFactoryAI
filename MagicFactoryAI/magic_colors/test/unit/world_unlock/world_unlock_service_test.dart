// =============================================================================
// Magic Colors · test/unit/world_unlock/world_unlock_service_test.dart
// =============================================================================
//
// Sprint 6 — unit tests for the World Unlock Progression system:
// WorldUnlockService + CompletionRewardService + FirstUnlockService.
// All three services are pure-Dart and compose with `PlayerState`
// so the tests use `PlayerState.inMemory()` (the @visibleForTesting
// seam added in M2.4) to avoid paying the cost of bringing up Hive.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:magic_colors/core/domain/world/world_status.dart';
import 'package:magic_colors/core/services/world_unlock/completion_reward_service.dart';
import 'package:magic_colors/core/services/world_unlock/first_unlock_service.dart';
import 'package:magic_colors/core/services/world_unlock/world_unlock_service.dart';
import 'package:magic_colors/core/state/player_state.dart';

/// Test seam for `PlayerState` economy + world state. Uses
/// `setEconomyForTest` (Sprint 5) for coins/gems and the new
/// `markWorldCelebrated` / `claimWorldCompletionReward` for the
/// Sprint 6 fields.
PlayerState _newPlayer({
  int coins = 0,
  int gems = 0,
  bool isPremium = false,
  Map<String, int> worldStars = const <String, int>{},
  Set<String> ownedWorlds = const <String>{},
  Set<String> celebratedWorlds = const <String>{},
  Set<String> claimedRewards = const <String>{},
}) {
  final PlayerState player = PlayerState.inMemory();
  player.setEconomyForTest(coins: coins, gems: gems);
  if (isPremium) player.setPremium(true);
  worldStars.forEach(player.grantWorldStars);
  ownedWorlds.forEach(player.unlockWorld);
  celebratedWorlds.forEach(player.markWorldCelebrated);
  claimedRewards.forEach(player.claimWorldCompletionReward);
  return player;
}

WorldRef _ref(String id, {bool premium = false, int starsForUnlock = 0}) {
  return (
    id: id,
    isPremiumWorld: premium,
    starsForUnlock: starsForUnlock,
  );
}

void main() {
  group('WorldUnlockService.ownsWorld', () {
    test('free world with 0 stars unlock threshold is owned from start', () {
      final PlayerState p = _newPlayer();
      expect(
        WorldUnlockService.ownsWorld(
          'unicorn_valley',
          isPremiumWorld: false,
          starsForUnlock: 0,
          player: p,
        ),
        isTrue,
      );
    });

    test('star-gated world not owned when stars < threshold', () {
      final PlayerState p = _newPlayer();
      expect(
        WorldUnlockService.ownsWorld(
          'animal_forest',
          isPremiumWorld: false,
          starsForUnlock: 1,
          player: p,
        ),
        isFalse,
      );
    });

    test('star-gated world owned when stars >= threshold', () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'animal_forest': 1,
      });
      expect(
        WorldUnlockService.ownsWorld(
          'animal_forest',
          isPremiumWorld: false,
          starsForUnlock: 1,
          player: p,
        ),
        isTrue,
      );
    });

    test('premium world blocked without subscription', () {
      final PlayerState p = _newPlayer();
      expect(
        WorldUnlockService.ownsWorld(
          'christmas_village',
          isPremiumWorld: true,
          starsForUnlock: 0,
          player: p,
        ),
        isFalse,
      );
    });

    test('premium world opened with subscription', () {
      final PlayerState p = _newPlayer(isPremium: true);
      expect(
        WorldUnlockService.ownsWorld(
          'christmas_village',
          isPremiumWorld: true,
          starsForUnlock: 0,
          player: p,
        ),
        isTrue,
      );
    });
  });

  group('WorldUnlockService.computeStatus', () {
    test('locked world without enough stars', () {
      final PlayerState p = _newPlayer();
      final WorldStatus s = WorldUnlockService.computeStatus(
        'animal_forest',
        isPremiumWorld: false,
        starsForUnlock: 1,
        player: p,
      );
      expect(s, WorldStatus.locked);
    });

    test('available world owned + not current + not completed', () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'animal_forest': 1,
      });
      final WorldStatus s = WorldUnlockService.computeStatus(
        'animal_forest',
        isPremiumWorld: false,
        starsForUnlock: 1,
        player: p,
      );
      expect(s, WorldStatus.available);
    });

    test('current world wins over completed when currentWorldId matches',
        () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'animal_forest': 3,
      });
      final WorldStatus s = WorldUnlockService.computeStatus(
        'animal_forest',
        isPremiumWorld: false,
        starsForUnlock: 1,
        player: p,
        currentWorldId: 'animal_forest',
      );
      expect(s, WorldStatus.current);
    });

    test('completed world at 3 stars without currentWorldId', () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'animal_forest': 3,
      });
      final WorldStatus s = WorldUnlockService.computeStatus(
        'animal_forest',
        isPremiumWorld: false,
        starsForUnlock: 1,
        player: p,
      );
      expect(s, WorldStatus.completed);
    });
  });

  group('WorldUnlockService.computeProgress', () {
    test('completed world surfaces rewardCoins + rewardGems + nextWorldId',
        () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'unicorn_valley': 3,
      });
      final WorldProgressLite prog = _LiteShim.of(
        WorldUnlockService.computeProgress(
          'unicorn_valley',
          isPremiumWorld: false,
          starsForUnlock: 0,
          player: p,
        ),
      );
      expect(prog.earnedStars, 3);
      expect(prog.completedLevels, 3);
      expect(prog.completionPct, 100);
      expect(prog.status, WorldStatus.completed);
      expect(prog.isRewardClaimed, isFalse);
      expect(prog.rewardCoins, 30);
      expect(prog.rewardGems, 1);
      expect(prog.nextWorldId, 'animal_forest');
      expect(prog.achievementId, 'first_world_completed');
    });

    test('isCelebrated is true once player marks the world', () {
      final PlayerState p = _newPlayer(
        celebratedWorlds: <String>{'unicorn_valley'},
      );
      final WorldProgressLite prog = _LiteShim.of(
        WorldUnlockService.computeProgress(
          'unicorn_valley',
          isPremiumWorld: false,
          starsForUnlock: 0,
          player: p,
        ),
      );
      expect(prog.isCelebrated, isTrue);
    });

    test('isRewardClaimed is true once the player claims', () {
      final PlayerState p = _newPlayer(
        worldStars: <String, int>{'unicorn_valley': 3},
        claimedRewards: <String>{'unicorn_valley'},
      );
      final WorldProgressLite prog = _LiteShim.of(
        WorldUnlockService.computeProgress(
          'unicorn_valley',
          isPremiumWorld: false,
          starsForUnlock: 0,
          player: p,
        ),
      );
      expect(prog.isRewardClaimed, isTrue);
    });
  });

  group('CompletionRewardService.grantCompletion', () {
    test('grants coins + gems from the catalog row', () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'unicorn_valley': 3,
      });
      final CompletionRewardResult r =
          CompletionRewardService.grantCompletion(
        worldId: 'unicorn_valley',
        player: p,
      );
      expect(r, CompletionRewardResult.granted);
      expect(p.coins, 30);
      // setEconomyForTest defaults gems to 0, so the post-claim
      // balance is 0 + 1 (the unicorn_valley reward).
      expect(p.gems, 1);
    });

    test('auto-unlocks the next world in the chain', () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'unicorn_valley': 3,
      });
      CompletionRewardService.grantCompletion(
        worldId: 'unicorn_valley',
        player: p,
      );
      expect(p.ownedWorldIds.contains('animal_forest'), isTrue);
    });

    test('triggers the achievement hook on completion', () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'unicorn_valley': 3,
      });
      CompletionRewardService.grantCompletion(
        worldId: 'unicorn_valley',
        player: p,
      );
      expect(p.unlockedAchievementIds.contains('first_world_completed'),
          isTrue);
    });

    test('idempotent — second call returns alreadyClaimed', () {
      final PlayerState p = _newPlayer(worldStars: <String, int>{
        'unicorn_valley': 3,
      });
      CompletionRewardService.grantCompletion(
        worldId: 'unicorn_valley',
        player: p,
      );
      final int coinsAfterFirst = p.coins;
      final CompletionRewardResult r2 =
          CompletionRewardService.grantCompletion(
        worldId: 'unicorn_valley',
        player: p,
      );
      expect(r2, CompletionRewardResult.alreadyClaimed);
      expect(p.coins, coinsAfterFirst); // no double grant
    });

    test('returns noRewardDefined for unknown worldId', () {
      final PlayerState p = _newPlayer();
      final CompletionRewardResult r =
          CompletionRewardService.grantCompletion(
        worldId: '__unknown__',
        player: p,
      );
      expect(r, CompletionRewardResult.noRewardDefined);
    });
  });

  group('FirstUnlockService', () {
    test('discoverUncelebrated returns owned + uncelebrated only', () {
      final PlayerState p = _newPlayer(
        worldStars: <String, int>{'unicorn_valley': 1},
        celebratedWorlds: <String>{'unicorn_valley'},
      );
      final List<WorldRef> catalog = <WorldRef>[
        _ref('unicorn_valley'),
        _ref('animal_forest', starsForUnlock: 1),
      ];
      final List<WorldRef> uncelebrated =
          FirstUnlockService.discoverUncelebrated(catalog, p);
      expect(uncelebrated, isEmpty); // unicorn celebrated + animal locked
    });

    test('marks world as celebrated, idempotent', () {
      final PlayerState p = _newPlayer();
      FirstUnlockService.markCelebrated(p, 'unicorn_valley');
      FirstUnlockService.markCelebrated(p, 'unicorn_valley'); // no-op
      expect(p.celebratedWorldIds.contains('unicorn_valley'), isTrue);
      expect(p.celebratedWorldIds.length, 1);
    });

    test('isUncelebrated returns false after mark', () {
      final PlayerState p = _newPlayer();
      expect(FirstUnlockService.isUncelebrated(p, 'unicorn_valley'), isTrue);
      FirstUnlockService.markCelebrated(p, 'unicorn_valley');
      expect(FirstUnlockService.isUncelebrated(p, 'unicorn_valley'),
          isFalse);
    });

    test('countUncelebrated returns 0 when fully celebrated', () {
      final PlayerState p = _newPlayer(
        celebratedWorlds: <String>{'unicorn_valley', 'animal_forest'},
      );
      final List<WorldRef> catalog = <WorldRef>[
        _ref('unicorn_valley'),
        _ref('animal_forest', starsForUnlock: 1),
      ];
      final int n = FirstUnlockService.countUncelebrated(catalog, p);
      expect(n, 0);
    });
  });
}

/// Lightweight view-model for tests. Decouples the test from the
/// concrete `WorldProgress` field set so adding new fields to the
/// model doesn't break the test surface.
class WorldProgressLite {
  const WorldProgressLite({
    required this.earnedStars,
    required this.completedLevels,
    required this.completionPct,
    required this.status,
    required this.isCelebrated,
    required this.isRewardClaimed,
    required this.rewardCoins,
    required this.rewardGems,
    required this.nextWorldId,
    required this.achievementId,
  });

  final int earnedStars;
  final int completedLevels;
  final int completionPct;
  final WorldStatus status;
  final bool isCelebrated;
  final bool isRewardClaimed;
  final int rewardCoins;
  final int rewardGems;
  final String? nextWorldId;
  final String? achievementId;
}

class _LiteShim {
  static WorldProgressLite of(dynamic p) {
    return WorldProgressLite(
      earnedStars: p.earnedStars as int,
      completedLevels: p.completedLevels as int,
      completionPct: p.completionPct as int,
      status: p.status as WorldStatus,
      isCelebrated: p.isCelebrated as bool,
      isRewardClaimed: p.isRewardClaimed as bool,
      rewardCoins: p.rewardCoins as int,
      rewardGems: p.rewardGems as int,
      nextWorldId: p.nextWorldId as String?,
      achievementId: p.achievementId as String?,
    );
  }
}
