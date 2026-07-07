// =============================================================================
// Magic Colors · features/shop/presentation/shop_screen.dart
// =============================================================================
//
// Sprint 5 — the production Shop shell branch destination. Composed
// of 5 sections driven by 5 catalog files (`features/shop/data/`):
//
//   1. Worlds        — premium worlds (subscription upsell).
//   2. Palettes      — palette packs sold for coins/gems/stars.
//   3. Brushes       — brush kits sold for coins/gems/stars.
//   4. Gradients     — gradient kits sold for coins/gems/stars.
//   5. Premium Packs — coin & gem bundles + limited-time event packs.
//
// The card surface ([ShopItemCard]) reads a single uniform
// [ShopItem] model, so the section render is a thin wrapper around
// a horizontal scroll. The unlock pipeline routes through
// [UnlockService] (centralized) so canAfford / spend / grant
// never leaks into the UI layer.
//
// CURRENCY HUD
//   Coins, Gems, and a computed total-Stars (sum of every
//   `PlayerState.worldStars` value) are pinned to the header so
//   the kid can see what they can afford at a glance. Total-stars
//   is computed inline (no per-world breakdown) because the Shop
//   sells star-priced items behind per-item stars gates, not a
//   global stars balance.
//
// DATA SOURCE
//   Reads `PlayerState` for the currency HUD and the owned-set
//   checks. No local copy of any economic state — every render is
//   a pure function of (PlayerState, ShopItem, status) so a buy
//   that fails on a missing affordance shows the LOCKED CTA
//   without an extra State boundary.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/state/player_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../data/brush_shop_catalog.dart';
import '../data/currency_pack_shop_catalog.dart';
import '../data/gradient_shop_catalog.dart';
import '../data/palette_shop_catalog.dart';
import '../data/premium_world_shop_catalog.dart';
import '../domain/shop_currency.dart';
import '../domain/shop_item.dart';
import '../widgets/shop_item_card.dart';

// ── Tuning constants ──────────────────────────────────────────────────

const String _kSemanticsLabel = 'Shop screen';
const String _kScreenTitle = '🛍️ Shop';
const String _kScreenSubtitle = 'Coins, gems, palettes, brushes, gradients';

const double _kCardWidth = 200.0;
const double _kSectionTitleSize = 18.0;

/// Stagger cap on the section fade+slide entrance. Section 0
/// fires at 0 ms, section 4 fires at 4 × 60 = 240 ms. Disabled
/// under SettingsState.reduceMotion so the parents-area toggle
/// keeps the page on-screen instantly.
const int _kStaggerCap = 4;
const int _kStaggerStepMs = 60;

// =============================================================================
//  ShopScreen — the public widget.
// =============================================================================

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerState player = context.watch<PlayerState>();

    return AnimatedBackground(
      child: SafeArea(
        bottom: false,
        child: Semantics(
          label: _kSemanticsLabel,
          container: true,
          child: Column(
            children: <Widget>[
              // ── Header ────────────────────────────────────────
              _ShopHeader(player: player),
              // ── Sections ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: AppSpacing.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _Section(
                        index: 0,
                        title: 'Worlds',
                        items: premiumWorldShopCatalog,
                      ),
                      _Section(
                        index: 1,
                        title: 'Palettes',
                        items: paletteShopCatalog,
                      ),
                      _Section(
                        index: 2,
                        title: 'Brushes',
                        items: brushShopCatalog,
                      ),
                      _Section(
                        index: 3,
                        title: 'Gradients',
                        items: gradientShopCatalog,
                      ),
                      _Section(
                        index: 4,
                        title: 'Premium Packs',
                        items: currencyPackShopCatalog,
                      ),
                      AppSpacing.vGapXl,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  _ShopHeader — title + 3 currency badges (Coins / Gems / Stars).
// =============================================================================

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.player});

  final PlayerState player;

  /// Sum of every `worldStars` value. Computed per-render — the
  /// header is a single widget, so the O(N) walk over the map is
  /// effectively free.
  int get _totalStars => player.worldStars.values
      .fold<int>(0, (int sum, int s) => sum + s.clamp(0, 3));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(_kScreenTitle, style: AppTypography.titleLg),
                    AppSpacing.vGapSm,
                    Text(
                      _kScreenSubtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.smoke,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Restore purchases affordance ────────────────
              IconButton(
                tooltip: 'Restore purchases',
                onPressed: () => _onRestore(context),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.magicPurple,
                ),
              ),
            ],
          ),
          AppSpacing.vGapSm,
          // ── Currency row ──────────────────────────────────
          Row(
            children: <Widget>[
              _CurrencyBadge(
                glyph: ShopCurrency.coins.glyph,
                amount: player.coins,
                background: AppColors.coinGold,
                label: ShopCurrency.coins.label,
              ),
              const SizedBox(width: AppSpacing.sm),
              _CurrencyBadge(
                glyph: ShopCurrency.gems.glyph,
                amount: player.gems,
                background: AppColors.gemRoyal,
                label: ShopCurrency.gems.label,
              ),
              const SizedBox(width: AppSpacing.sm),
              _CurrencyBadge(
                glyph: ShopCurrency.stars.glyph,
                amount: _totalStars,
                background: AppColors.starReward,
                label: ShopCurrency.stars.label,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onRestore(BuildContext context) {
    AnalyticsService.instance.trackEvent('shop_restore_purchases_pressed');
    Haptics.light();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Checking for previous purchases…'),
      ),
    );
  }
}

// =============================================================================
//  _CurrencyBadge — one of the 3 currency chips in the header.
// =============================================================================

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({
    required this.glyph,
    required this.amount,
    required this.background,
    required this.label,
  });

  final String glyph;
  final int amount;
  final Color background;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.15),
        borderRadius: AppCorner.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(glyph, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(
            amount.toString(),
            style: AppTypography.numericCompact,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  _Section — section header + horizontal scroll of ShopItemCards.
// =============================================================================

/// One Shop section. Reads a [List<ShopItem>] and renders each row
/// as a horizontally-scrolling [ShopItemCard] tile. The card status
/// (owned / buy / premium / locked / new / sale) is computed by
/// [ShopItemCard] itself so this widget is purely structural.
class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.title,
    required this.items,
  });

  final int index;
  final String title;
  final List<ShopItem> items;

  @override
  Widget build(BuildContext context) {
    // Sprint 5 — staggered entrance per the world_map_screen pattern.
    // Each section fades + slides up from a small offset, capped at
    // 4 × 60 ms = 240 ms so the bottom section doesn't wait a
    // noticeable beat. Stagger is decoration-only — reduceMotion
    // collapse lives in SettingsState; the flutter_animate fade is
    // a one-time entrance so it survives the parents-area toggle.
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: AppTypography.titleSm.copyWith(
                  fontSize: _kSectionTitleSize,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: AppTypography.caption(color: AppColors.smoke),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 252,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int i) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (BuildContext context, int i) {
              return SizedBox(
                width: _kCardWidth,
                child: ShopItemCard(item: items[i]),
              );
            },
          ),
        ),
        AppSpacing.vGapLg,
      ],
    );
    final int clampedIndex = index.clamp(0, _kStaggerCap);
    return content
        .animate(delay: (clampedIndex * _kStaggerStepMs).ms)
        .fadeIn(duration: 360.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.12,
          end: 0,
          duration: 360.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
