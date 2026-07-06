// =============================================================================
// Magic Colors · core/services/world_unlock/first_unlock_service.dart
// =============================================================================
//
// Sprint 6 — first-unlock detection. The World Map asks this
// service at mount time: "is there a world the player owns that
// they haven't celebrated yet?" If yes, the map triggers the
// [FirstUnlockDialog] (a one-shot celebration overlay).
//
// The persistence flag lives on `PlayerState.celebratedWorldIds` so
// the celebration is genuinely one-shot across sessions.
//
// CLEANER SIGNATURE
//   The service takes a `List<WorldRef>` (a record typedef) rather
//   than an abstract class — Dart 3 records give us structural
//   typing for free, so any feature-layer `WorldData` can be
//   converted to a WorldRef in 1 line at the call site. This
//   eliminates the Sprint-5-style "abstract base + adapter" boilerplate.
// =============================================================================

import '../../state/player_state.dart';
import 'world_unlock_service.dart';

/// Lightweight world reference. Dart 3 record so the catalog can
/// pass `(id: w.id, isPremiumWorld: w.isPremiumWorld,
/// starsForUnlock: w.starsForUnlock)` directly without a class
/// adapter.
typedef WorldRef = ({
  String id,
  bool isPremiumWorld,
  int starsForUnlock,
});

/// One-shot celebration façade. Marked `abstract final` so neither
/// tests nor screens extend it.
abstract final class FirstUnlockService {
  FirstUnlockService._();

  /// Returns the entries from [catalog] that the player owns AND
  /// has not yet celebrated. The caller iterates and shows the
  /// [FirstUnlockDialog] in order; the dialog calls
  /// [markCelebrated] when dismissed so the next call returns an
  /// empty list.
  ///
  /// Sorted by catalog order so the celebration flow always
  /// walks the same worlds in the same sequence.
  static List<WorldRef> discoverUncelebrated(
    List<WorldRef> catalog,
    PlayerState player,
  ) {
    final List<WorldRef> uncelebrated = <WorldRef>[];
    for (final WorldRef world in catalog) {
      if (!WorldUnlockService.ownsWorld(
        world.id,
        isPremiumWorld: world.isPremiumWorld,
        starsForUnlock: world.starsForUnlock,
        player: player,
      )) {
        continue;
      }
      if (player.celebratedWorldIds.contains(world.id)) continue;
      uncelebrated.add(world);
    }
    return uncelebrated;
  }

  /// Marks [worldId] as celebrated. Idempotent — a second call
  /// for the same id is a no-op. Should be called by the dialog's
  /// dismiss path so the same world never re-triggers the toast.
  static void markCelebrated(PlayerState player, String worldId) {
    player.markWorldCelebrated(worldId);
  }

  /// True iff [worldId] has not yet been celebrated for [player].
  /// Convenience over `!celebratedWorldIds.contains(worldId)` so
  /// call sites read top-down.
  static bool isUncelebrated(PlayerState player, String worldId) {
    return !player.celebratedWorldIds.contains(worldId);
  }

  /// Diagnostic-only: total count of uncelebrated + owned worlds.
  /// Reserved for the ContinueBanner badge ("N new worlds!") in a
  /// future sprint. Kept in the service so the count can be
  /// memoized without re-walking the catalog.
  static int countUncelebrated(
    List<WorldRef> catalog,
    PlayerState player,
  ) {
    return discoverUncelebrated(catalog, player).length;
  }
}
