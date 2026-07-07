// =============================================================================
// Magic Colors · core/theme/app_shape.dart
// =============================================================================
//
// Frozen shape + elevation tokens. Mirrors §1 of
// docs/design_system/04_UI_COMPONENTS.md ("Design Tokens — top of the
// component tree"). Every surface (Card / Button / Chip / Pill / BottomNav)
// composes these values; no widget ever inlines a numeric `BorderRadius`,
// `BoxShadow`, or `ShapeBorder`.
//
// Hierarchy of tokens:
//   ▸ raw radius constants (numbers)
//   ▸ derived `BorderRadius` constants (brXs/brSm/brMd/brLg)
//   ▸ derived `ShapeBorder` constants (cardShape, chipShape, buttonShapeLg)
//   ▸ BoxShadow elevations (elevation1/2, softChip, glowPink, glowYellow)
//   ▸ padding / duration helpers (used inside design_tokens.dart later)
// =============================================================================

import 'package:flutter/painting.dart'
    show BorderRadius, BoxShadow, Color, Offset, Radius, RoundedRectangleBorder;
import 'package:flutter/widgets.dart' show OutlinedBorder;

// M2.3 PRODUCTION — widget-layer alias. The widget layer references
// `AppShape` as a general shape token (used in Container,
// DecoratedBox, OutlineButton callbacks). Route the alias to the
// canonical `AppShapeBorder` so every legacy reference resolves to
// the same ShapeBorder catalogue. New code should import
// `AppShapeBorder` directly.
typedef AppShape = AppShapeBorder;

// =============================================================================
//  Radius tokens — the canonical paddle outline.
// =============================================================================

abstract final class AppRadius {
  const AppRadius._();

  /// 6 dp — used by tiny tags and meter fills.
  static const double xs = 6.0;

  /// 12 dp — used by chips and pill labels.
  static const double sm = 12.0;

  /// 20 dp — used by small cards + secondary buttons.
  static const double md = 20.0;

  /// 28 dp — used by CTAs, large cards, the magic card itself.
  static const double lg = 28.0;

  /// 40 dp — used by jumbo Reward Pop-Ups and figure-8 reward chest bubbles.
  static const double xl = 40.0;

  /// 999 dp — pill-shaped containers (button → almost-at-endless curve).
  static const double pill = 999.0;
}

// =============================================================================
//  BorderRadius tokens.
// =============================================================================

abstract final class AppCorner {
  const AppCorner._();

  /// `BorderRadius.circular(xs)` — tags, meter fills.
  static const BorderRadius brXs =
      BorderRadius.all(Radius.circular(AppRadius.xs));

  /// `BorderRadius.circular(sm)` — chips, pills.
  static const BorderRadius brSm =
      BorderRadius.all(Radius.circular(AppRadius.sm));

  /// `BorderRadius.circular(md)` — small cards, secondary buttons.
  static const BorderRadius brMd =
      BorderRadius.all(Radius.circular(AppRadius.md));

  /// `BorderRadius.circular(lg)` — CTAs, large cards.
  static const BorderRadius brLg =
      BorderRadius.all(Radius.circular(AppRadius.lg));

  /// `BorderRadius.circular(xl)` — Reward Pop-Up, jumbo surfaces.
  static const BorderRadius brXl =
      BorderRadius.all(Radius.circular(AppRadius.xl));

  /// Stadium / pill button corner (top + bottom curved to 999 px).
  static const BorderRadius pill =
      BorderRadius.all(Radius.circular(AppRadius.pill));
}

// =============================================================================
//  BoxShadow elevations.
// =============================================================================

/// Frozen dropShadow tokens. Composed by Material's `_elevationShader`
/// automatically, but exposed here so non-Material widgets (CustomPaint,
/// DecoratedBox, container shells) can apply the same look.
abstract final class AppElevation {
  const AppElevation._();

  /// 8 dp blur, 4 dp offset — light-on-light resting state.
  static const List<BoxShadow> elevation1 = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000), // 20 % ink
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// 16 dp + 4 dp two-layer shadow — used by primary CTAs and the
  /// reward-pop-up card. Pairs with a coloured glow in widget builds.
  static const List<BoxShadow> elevation2 = <BoxShadow>[
    BoxShadow(
      color: Color(0x55000000), // 33 % ink
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x33000000), // 20 % ink
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Chips + nav-bar resting shadow (10 % ink, 4 dp blur).
  static const List<BoxShadow> softChip = <BoxShadow>[
    BoxShadow(
      color: Color(0x19000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// Pink glow — primary CTA glow layer (PLAY NOW pulse).
  /// `magicPink` at 31 % alpha, 24 dp blur.
  static const List<BoxShadow> glowPink = <BoxShadow>[
    BoxShadow(
      color: Color(0x50FF4F9A),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];

  /// Yellow glow — used by reward counters and coin-pickup confetti.
  static const List<BoxShadow> glowYellow = <BoxShadow>[
    BoxShadow(
      color: Color(0x50FFC93C),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];

  /// Purple glow — used by Premium button resting + animated states.
  static const List<BoxShadow> glowPurple = <BoxShadow>[
    BoxShadow(
      color: Color(0x507A55D9),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];

  // ── Material 3 z-axis aliases ──────────────────────────────────────────
  //
  // Single-source-of-truth migration: the canonical `AppElevation`
  // previously also lived in `lib/core/design/design_tokens.dart` with
  // Material 3 names (`z0`/`z1`/`z2`/`z3`). That duplication produced
  // 12+ `ambiguous_import` errors during the M2.4 hotfix. The two
  // catalogues are merged here; the design_tokens copy is removed.

  /// z0 — no shadow (used by flat surfaces, e.g. NavigationBar background).
  static const List<BoxShadow> z0 = <BoxShadow>[];

  /// z1 — light resting shadow (8 dp blur, 4 dp offset, 20 % ink).
  /// Aliases [elevation1] for callers that prefer Material 3 names.
  static const List<BoxShadow> z1 = elevation1;

  /// z2 — raised shadow (12 dp + 4 dp two-layer stack, 20 % ink).
  static const List<BoxShadow> z2 = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000), // 20 % ink
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x19000000), // 10 % ink
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  /// z3 — hero shadow (24 dp + 8 dp two-layer, 30 % ink dominant).
  /// Used by the PLAY NOW button + Premium button when hovered.
  static const List<BoxShadow> z3 = <BoxShadow>[
    BoxShadow(
      color: Color(0x4D000000), // 30 % ink
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x33000000), // 20 % ink
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
}

// =============================================================================
//  ShapeBorder tokens.
// =============================================================================

abstract final class AppShapeBorder {
  const AppShapeBorder._();

  /// Standard card silhouette (`radiusLg`).
  static const OutlinedBorder card =
      RoundedRectangleBorder(borderRadius: AppCorner.brLg);

  /// Standard chip silhouette (`radiusSm`).
  static const OutlinedBorder chip =
      RoundedRectangleBorder(borderRadius: AppCorner.brSm);

  /// Standard primary button silhouette (`radiusLg`).
  static const OutlinedBorder buttonLarge =
      RoundedRectangleBorder(borderRadius: AppCorner.brLg);

  /// Secondary button silhouette (`radiusMd`).
  static const OutlinedBorder buttonMedium =
      RoundedRectangleBorder(borderRadius: AppCorner.brMd);

  /// Tertiary chip / pill silhouette (`radiusSm`).
  static const OutlinedBorder buttonSmall =
      RoundedRectangleBorder(borderRadius: AppCorner.brSm);

  /// Reward Pop-Up card silhouette (`radiusXl`).
  static const OutlinedBorder rewardPopup =
      RoundedRectangleBorder(borderRadius: AppCorner.brXl);

  // ── M2.4 hotfix — legacy widget-layer accessors ────────────────────────
  //
  // `AppShape` is typedef'd to `AppShapeBorder` so a legacy widget call
  // site like `AppShape.medium` resolves here. These constants route every
  // legacy reference back to the canonical catalogue while keeping the
  // public name reachable.

  /// Border shorthand for the XL (extra-large) radius — equals
  /// `AppCorner.brXl`. Used by `bottom_nav.dart` as the corner for the
  /// outer container.
  static const BorderRadius borderXL = AppCorner.brXl;

  /// Border shorthand for the pill-shape radius — equals
  /// `AppCorner.pill`. Used by `_RewardChip` and the chest-icon
  /// containers.
  static const BorderRadius borderPill = AppCorner.pill;

  /// M2.4 hotfix — `AppShadows.medium` legacy alias. Layered two-stop
  /// stack (27 % violet + thin white highlight).
  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(
      color: Color(0x447A55D9),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x33FFFFFF),
      offset: Offset(0, -2),
    ),
  ];

  /// M2.4 hotfix — `AppShadows.deep` legacy alias. 40 % deep-violet
  /// heavy drop.
  static const List<BoxShadow> deep = <BoxShadow>[
    BoxShadow(
      color: Color(0x664D2A8C),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];

  // ── M2.3 PRODUCTION — widget-layer convenience accessors ─────────────
  //
  // The legacy widget layer (home/widgets/play_now_button.dart,
  // secondary_button.dart, etc.) predates AppShapeBorder's
  // consolidation and references these legacy names. These
  // static const fields route every legacy reference back to
  // the canonical token catalogue so the design system stays
  // single-source-of-truth.

  /// Border shorthand for the L (large) radius (== brLg).
  static const BorderRadius borderL = AppCorner.brLg;

  /// Radius shorthand for the L (large) radius.
  static const Radius radiusL = Radius.circular(AppRadius.lg);

  /// PLAY NOW button drop-shadow + pink-glow stack.
  static const List<BoxShadow> playButton = <BoxShadow>[
    BoxShadow(
      color: Color(0x33FF4F9A), // 20% magicPink halo
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x50000000), // 31% ink resting shadow
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Soft resting shadow for secondary buttons + chips.
  static const List<BoxShadow> soft = AppElevation.softChip;
}
