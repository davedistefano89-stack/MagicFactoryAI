// =============================================================================
// Magic Colors · lib/core/domain/daily/daily_challenge_progress.dart
// =============================================================================
//
// Sprint 7 — runtime snapshot of a single daily challenge. The
// `current` value is derived from PlayerState by
// `DailyChallengeService.computeProgress`. The model is immutable
// so it can be cached per-build without defensive copies.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import 'daily_challenge.dart';
import 'daily_challenge_status.dart';

/// Per-challenge progress snapshot. Pure data; the service computes
/// `current` + `status` from PlayerState + the catalog row.
@immutable
class DailyChallengeProgress {
  const DailyChallengeProgress({
    required this.challenge,
    required this.current,
    required this.target,
    required this.status,
  });

  /// The catalog row.
  final DailyChallenge challenge;

  /// Current value (0..target). Clamped at the service layer.
  final int current;

  /// Always equals `challenge.target`. Stored on the snapshot so the
  /// UI can render "current / target" without a second lookup.
  final int target;

  /// Lifecycle status. The UI switches on this enum.
  final DailyChallengeStatus status;

  /// `target - current`, clamped to 0. Convenience for the "X
  /// more to go" caption.
  int get remaining {
    final int delta = target - current;
    return delta < 0 ? 0 : delta;
  }

  /// `current / target` as a 0..1 fraction. Convenience for the
  /// progress meter.
  double get fraction {
    if (target <= 0) return 0.0;
    final double f = current / target;
    if (f < 0.0) return 0.0;
    if (f > 1.0) return 1.0;
    return f;
  }

  /// True iff the player can claim the reward (target reached,
  /// reward not yet claimed).
  bool get canClaim => status == DailyChallengeStatus.completed;

  /// True iff the player has already claimed the reward today.
  bool get isClaimed => status == DailyChallengeStatus.claimed;

  /// True iff the challenge is locked out of today's roster.
  bool get isLocked => status == DailyChallengeStatus.locked;
}
