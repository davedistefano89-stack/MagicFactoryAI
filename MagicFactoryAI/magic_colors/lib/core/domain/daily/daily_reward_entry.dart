// =============================================================================
// Magic Colors · lib/core/domain/daily/daily_reward_entry.dart
// =============================================================================
//
// Sprint 7 — single daily-reward row for a given streak day. The
// catalog is a `List<DailyRewardEntry>` keyed by [day] (1..7) so
// the service can do an O(1) lookup. Immutable so the catalog
// can be `const`.
// =============================================================================

import 'package:flutter/foundation.dart' show immutable;

import 'daily_reward_kind.dart';

@immutable
class DailyRewardEntry {
  const DailyRewardEntry({
    required this.day,
    required this.kind,
    required this.amount,
    required this.itemId,
    required this.glyph,
    required this.label,
  });

  /// Streak day this row maps to (1..7). The lookup in
  /// `DailyRewardService` clamps the streak to 1..7 and indexes
  /// directly.
  final int day;

  /// What kind of reward to grant.
  final DailyRewardKind kind;

  /// For [DailyRewardKind.coins] / [DailyRewardKind.gems] — the
  /// grant amount. For item kinds — unused (the catalog id is in
  /// [itemId]).
  final int amount;

  /// For item kinds — the catalog id (palette pack, brush,
  /// gradient, future sticker). For currency kinds — the empty
  /// string.
  final String itemId;

  /// Glyph rendered in the daily-reward dialog title pill.
  final String glyph;

  /// Human-readable label rendered next to the glyph ("50 coins",
  /// "Rainbow Sparkle palette"). The service surfaces this verbatim
  /// to the UI.
  final String label;
}
