// =============================================================================
// Magic Colors · lib/core/domain/daily/daily_challenge.dart
// =============================================================================
//
// Sprint 7 — single daily-challenge descriptor. Pure data; the
// service layer composes the runtime snapshot (progress + status)
// on top of this. Immutable so the catalog can be a const list.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import 'daily_challenge_kind.dart';

/// Stable catalog row describing a daily challenge. The runtime
/// snapshot (current value + status) is computed by
/// `DailyChallengeService.computeProgress`.
@immutable
class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.target,
    required this.rewardCoins,
    required this.rewardGems,
  });

  /// Stable id (kebab). Same id is re-used across days when the
  /// catalog selects the same challenge (the catalog deterministically
  /// picks a subset per day, but re-picks the same challenge can
  /// happen).
  final String id;

  /// Short player-facing title. Used as the card headline.
  final String title;

  /// Supporting copy. Used as the card subline + the "X / N"
  /// caption.
  final String description;

  /// What the challenge tracks. Service branches on this.
  final DailyChallengeKind kind;

  /// How many units must be reached to complete (e.g. 3 drawings,
  /// 5 stars). 1+ — the service clamps to 1 internally.
  final int target;

  /// Coin grant on claim. 0 = no coin grant.
  final int rewardCoins;

  /// Gem grant on claim. 0 = no gem grant.
  final int rewardGems;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyChallenge &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.kind == kind &&
        other.target == target &&
        other.rewardCoins == rewardCoins &&
        other.rewardGems == rewardGems;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        kind,
        target,
        rewardCoins,
        rewardGems,
      );
}
