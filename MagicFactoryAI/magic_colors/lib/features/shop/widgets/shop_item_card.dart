// =============================================================================
// Magic Colors · features/shop/widgets/shop_item_card.dart
// =============================================================================
//
// Sprint 5 — the single card surface for every Shop section (Worlds /
// Palettes / Brushes / Gradients / Premium Packs). Reads a [ShopItem]
// + a [PlayerState] (via context.watch) and renders one of the 6
// status branches.
//
// LAYOUT
//   ┌──────────────────────────────────────────────┐
//   │                                  [BADGE]    │   ← corner ribbon
//   │   ┌────┐                                       │
//   │   │ 🎨 │   Title                               │
//   │   └────┘   description                          │
//   │            ⭐ 30                               │   ← price chip
//   │           ┌────────────┐                       │
//   │           │  BUY  ↗   │                       │   ← CTA
//   │           └────────────┘                       │
//   └──────────────────────────────────────────────┘
//
// STATUS BRANCHES
//   • owned     — dimmed card, "OWNED" badge, no CTA tap.
//   • locked    — dimmed card, "LOCKED" subtitle, no CTA tap.
//   • buy       — bright card, "BUY" CTA, tap → UnlockService.
//   • premium   — bright card, "UPGRADE" CTA, tap → context.goPremium().
//   • newItem   — bright card + NEW corner ribbon, BUY CTA.
//   • sale      — bright card + SALE corner ribbon, BUY CTA.
//
// BADGE FAMILY
//   • NEW     — sunshineYellow background, tangerine text.
//   • SALE    — tangerine background, cloudWhite text.
//   • OWNED   — success background, cloudWhite text.
//   • PREMIUM — magicPurple background, cloudWhite text.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/routing/app_router.dart' show GoRouterContextX;
import '../../../core/services/analytics_service.dart';
import '../../../core/services/unlock/unlock_service.dart';
import '../../../core/state/player_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/magic_card.dart';
import '../domain/shop_item.dart';
import '../domain/shop_item_status.dart';
import '../domain/shop_rarity.dart';

/// Reusable Shop card. Section renders compose a grid of these
/// without further branching.
class ShopItemCard extends StatelessWidget {
  const ShopItemCard({
    super.key,
    required this.item,
  });

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final PlayerState player = context.watch<PlayerState>();
    final ShopItemStatus status = UnlockService.computeStatus(player, item);
    final bool isInteractive = _isInteractive(status);

    return MagicCard(
      skin: _cardSkin(status),
      borderRadius: AppCorner.brLg,
      borderColor: _borderColor(status),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: isInteractive ? () => _onTap(context, status, player) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // ── Body ───────────────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Icon hero
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _iconBackground(status).withValues(alpha: 0.18),
                    borderRadius: AppCorner.brMd,
                  ),
                  child: Text(
                    item.icon,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              AppSpacing.vGapSm,
              // Title
              Text(
                item.title,
                style: AppTypography.titleSm.copyWith(
                  color: _titleColor(status),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              // Description
              Text(
                item.description,
                style: AppTypography.caption(
                  color: AppColors.smoke,
                ).copyWith(
                  color: _descriptionColor(status),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.vGapSm,
              // Price chip
              if (!item.isPremium) _priceChip(status),
              if (item.isPremium) _premiumChip(),
            ],
          ),
          // ── Corner badges ───────────────────────────────────
          if (item.isNew && status != ShopItemStatus.owned)
            const Positioned(
              top: -8,
              right: -8,
              child: _CornerBadge(
                label: 'NEW',
                background: AppColors.sunshineYellow,
                foreground: AppColors.tangerine,
              ),
            ),
          if (item.isOnSale && status != ShopItemStatus.owned)
            const Positioned(
              top: -8,
              right: -8,
              child: _CornerBadge(
                label: 'SALE',
                background: AppColors.tangerine,
                foreground: AppColors.cloudWhite,
              ),
            ),
          if (status == ShopItemStatus.owned)
            const Positioned(
              top: -8,
              right: -8,
              child: _CornerBadge(
                label: 'OWNED',
                background: AppColors.success,
                foreground: AppColors.cloudWhite,
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// True iff the card should accept taps. OWNED / LOCKED cards are
  /// dead taps (the kid can't buy something they already own or
  /// can't afford).
  bool _isInteractive(ShopItemStatus status) {
    switch (status) {
      case ShopItemStatus.owned:
      case ShopItemStatus.locked:
        return false;
      case ShopItemStatus.buy:
      case ShopItemStatus.premium:
      case ShopItemStatus.newItem:
      case ShopItemStatus.sale:
        return true;
    }
  }

  MagicCardSkin _cardSkin(ShopItemStatus status) {
    switch (status) {
      case ShopItemStatus.owned:
      case ShopItemStatus.locked:
        return MagicCardSkin.blank;
      case ShopItemStatus.buy:
      case ShopItemStatus.newItem:
      case ShopItemStatus.sale:
        return MagicCardSkin.tinted;
      case ShopItemStatus.premium:
        return MagicCardSkin.accent;
    }
  }

  Color? _borderColor(ShopItemStatus status) {
    switch (status) {
      case ShopItemStatus.premium:
        return AppColors.magicPurple;
      case ShopItemStatus.locked:
      case ShopItemStatus.owned:
        return AppColors.smoke.withValues(alpha: 0.18);
      case ShopItemStatus.buy:
      case ShopItemStatus.newItem:
      case ShopItemStatus.sale:
        return null;
    }
  }

  Color _iconBackground(ShopItemStatus status) {
    switch (status) {
      case ShopItemStatus.premium:
        return AppColors.magicPurple;
      case ShopItemStatus.owned:
        return AppColors.success;
      case ShopItemStatus.locked:
        return AppColors.smoke;
      case ShopItemStatus.buy:
      case ShopItemStatus.newItem:
      case ShopItemStatus.sale:
        return _rarityColor(item.rarity);
    }
  }

  Color _titleColor(ShopItemStatus status) {
    if (status == ShopItemStatus.locked || status == ShopItemStatus.owned) {
      return AppColors.deepInk.withValues(alpha: 0.45);
    }
    return AppColors.deepInk;
  }

  Color _descriptionColor(ShopItemStatus status) {
    if (status == ShopItemStatus.locked || status == ShopItemStatus.owned) {
      return AppColors.smoke.withValues(alpha: 0.55);
    }
    return AppColors.smoke;
  }

  Widget _priceChip(ShopItemStatus status) {
    final bool dimmed =
        status == ShopItemStatus.locked || status == ShopItemStatus.owned;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: (dimmed
                ? AppColors.smoke
                : _rarityColor(item.rarity))
            .withValues(alpha: 0.15),
        borderRadius: AppCorner.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            item.currency.glyph,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            item.price.toString(),
            style: AppTypography.numericCompact.copyWith(
              color: dimmed ? AppColors.smoke : AppColors.deepInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[AppColors.magicPurple, AppColors.magicPink],
        ),
        borderRadius: AppCorner.brSm,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('👑', style: TextStyle(fontSize: 14)),
          SizedBox(width: 4),
          Text(
            'PREMIUM',
            style: TextStyle(
              color: AppColors.cloudWhite,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(
    BuildContext context,
    ShopItemStatus status,
    PlayerState player,
  ) {
    AnalyticsService.instance.trackEvent(
      'shop_item_tapped',
      <String, Object?>{
        'item_id': item.id,
        'item_kind': item.kind.name,
        'status': status.name,
      },
    );
    Haptics.medium();

    if (status == ShopItemStatus.premium) {
      // Premium upsell — route to the Premium screen, not the
      // in-app purchase flow. The Shop card never spends
      // currency on a Premium item.
      context.goPremium();
      return;
    }

    final UnlockResult result = UnlockService.unlock(player, item);
    _onUnlockResult(context, result);
  }

  void _onUnlockResult(BuildContext context, UnlockResult result) {
    final String message = switch (result) {
      UnlockResult.unlocked => '✨ ${item.title} unlocked!',
      UnlockResult.alreadyOwned => 'You already own ${item.title}.',
      UnlockResult.insufficientFunds =>
        'Not enough ${item.currency.label} for ${item.title}.',
      UnlockResult.premiumRequired => 'Subscribe to unlock ${item.title}.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _rarityColor(ShopRarity rarity) {
    switch (rarity) {
      case ShopRarity.common:
        return AppColors.smoke;
      case ShopRarity.rare:
        return AppColors.lagoon;
      case ShopRarity.epic:
        return AppColors.magicPurple;
      case ShopRarity.legendary:
        return AppColors.magicPink;
    }
  }
}

// =============================================================================
//  _CornerBadge — small pill anchored at the card's top-right corner.
// =============================================================================

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppCorner.brSm,
        boxShadow: AppElevation.softChip,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
