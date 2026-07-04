// =============================================================================
// Magic Colors · core/design/design_tokens.dart
// =============================================================================
//
// Single source of truth for every layout- and motion-level token in the app.
// Lives in `core/design/` rather than `core/theme/` so it can be imported
// without dragging in the Material 3 ThemeData + GoogleFonts surfaces the
// theme layer pulls in.
//
// Contents (in this file):
//   ▸ AppSpacing       — 7-step geometric scale (4/8/16/24/32/48/64).
//   ▸ AppDuration      — fast / medium / slow + named semantic presets
//                        (splash hold, toast auto-dismiss, page transition).
//   ▸ AppElevation     — Material-3-style z0/z1/z2/z3 catalogue of constant
//                        BoxShadow lists. Widgets apply elevation tokens
//                        as `boxShadow: AppElevation.zN` decorations.
//   ▸ AppCurves        — Cubic / Curve catalogue mapped 1:1 to
//                        docs/design_system/08_ANIMATION_GUIDE.md.
//   ▸ AppBreakpoints   — Material 3 breakpoint widths (compact / medium /
//                        expanded / large / extraLarge).
//   ▸ AppResponsive    — Sugar helpers that read MediaQuery.sizeOf(context)
//                        and return a breakpoint enum + scale factor.
//
// Convention: ALL tokens are `static const` (Material 3cachable, tree-shakable).
// Tokens that *must* be context-aware (e.g. AppResponsive.isCompact) live as
// static methods over BuildContext rather than class-level constants.
// =============================================================================

import 'package:flutter/material.dart' show
    BoxShadow,
    BuildContext,
    Color,
    Curves,
    Duration,
    EdgeInsets,
    MediaQuery,
    Offset,
    Radius,
    SizedBox,
    Curve,
    Cubic;


// =============================================================================
//  AppSpacing — 7-step scale (geometric, ratio ≈ 1.6).
// =============================================================================

abstract final class AppSpacing {
  const AppSpacing._();

  /// 4 dp — icon-to-label, tight inline. Halo around glyphs.
  static const double xs = 4.0;

  /// 8 dp — pill-to-pill, chip-to-chip. Default micro gap.
  static const double sm = 8.0;

  /// 16 dp — card content padding, default list-row gap.
  static const double md = 16.0;

  /// 24 dp — section gap, card-to-card breathing room.
  static const double lg = 24.0;

  /// 32 dp — page horizontal padding (mobile), screen-frame inset.
  static const double xl = 32.0;

  /// 48 dp — hero separation, top-of-PLAY-NOW breathing.
  static const double xxl = 48.0;

  /// 64 dp — between two utterly unrelated CTAs (Splash → Home breath).
  static const double xxxl = 64.0;


  // ── Semantic helpers ────────────────────────────────────────────────────
  /// Default screen-frame horizontal padding (matches the AppBar gesture
  /// inset on iPad + Android tablet side bezels).
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: lg,
  );

  /// Tight card padding (image fills edge-to-edge, label sits in the corner).
  static const EdgeInsets cardPaddingTight = EdgeInsets.all(sm);

  /// Generous card padding (used by the Reward Pop-Up card body).
  static const EdgeInsets cardPaddingGenerous = EdgeInsets.all(lg);


  // ── SizedBox gap builders ──────────────────────────────────────────────
  /// Vertical 8 dp gap for Column children.
  static const SizedBox vGapSm = SizedBox(height: sm);

  /// Vertical 16 dp gap.
  static const SizedBox vGapMd = SizedBox(height: md);

  /// Vertical 24 dp gap.
  static const SizedBox vGapLg = SizedBox(height: lg);

  /// Vertical 32 dp gap.
  static const SizedBox vGapXl = SizedBox(height: xl);

  /// Horizontal 8 dp gap for Row children.
  static const SizedBox hGapSm = SizedBox(width: sm);

  /// Horizontal 16 dp gap.
  static const SizedBox hGapMd = SizedBox(width: md);

  /// Horizontal 24 dp gap.
  static const SizedBox hGapLg = SizedBox(width: lg);

  /// Horizontal 32 dp gap.
  static const SizedBox hGapXl = SizedBox(width: xl);
}


// =============================================================================
//  AppDuration — animation timing presets.
// =============================================================================

abstract final class AppDuration {
  const AppDuration._();

  // ── Layered speed presets ─────────────────────────────────────────────
  /// 80 ms — micro-interactions: scale on tap, ripple, instant taps.
  static const Duration fast = Duration(milliseconds: 80);

  /// 220 ms — page transitions, modal rises, focus changes.
  static const Duration medium = Duration(milliseconds: 220);

  /// 320 ms — emphasis transitions: world unlock, mascot celebrate.
  static const Duration slow = Duration(milliseconds: 320);

  /// 540 ms — hero transitions: PLAY NOW scale-up, splash logo inflate.
  static const Duration hero = Duration(milliseconds: 540);


  // ── Named semantic presets ────────────────────────────────────────────
  /// Hold time on the Splash screen before swapping to Home.
  static const Duration splashHold = Duration(milliseconds: 2400);

  /// Auto-dismiss time for toast / achievement cards.
  static const Duration toastAutoDismiss = Duration(milliseconds: 2400);

  /// Daily chest breath animation (slow inhale + exhale).
  static const Duration chestBreath = Duration(milliseconds: 1800);

  /// Mascot breathing cycle.
  static const Duration mascotBreath = Duration(milliseconds: 1600);

  /// Reward pop-up confetti decay.
  static const Duration confettiDecay = Duration(milliseconds: 2400);

  /// Idle notification bubble bounce.
  static const Duration bubbleBounce = Duration(milliseconds: 320);

  /// Rainbow shimmer cycle (Premium button hover).
  static const Duration rainbowShimmer = Duration(milliseconds: 3000);
}


// =============================================================================
//  AppElevation — Material-3-style z0/z1/z2/z3 catalogue.
// =============================================================================

abstract final class AppElevation {
  const AppElevation._();

  /// z0 — no shadow (used by flat surfaces, e.g. NavigationBar background).
  static const List<BoxShadow> z0 = <BoxShadow>[];

  /// z1 — light resting shadow (8 dp blur, 4 dp offset, 20 % ink).
  /// Used by Cards at rest.
  static const List<BoxShadow> z1 = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000), // 20 % ink
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// z2 — raised shadow (12 dp + 4 dp two-layer stack, 20 % ink dominant).
  /// Used by primary CTAs and Reward Pop-Up cards.
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
//  AppCurves — animation easing catalogue.
// =============================================================================

abstract final class AppCurves {
  const AppCurves._();

  // ── Generic easing ────────────────────────────────────────────────────
  /// Default "enter" easing — fast start, ease into place.
  static const Curve enter = Cubic(0.20, 0.00, 0.20, 1.00);

  /// Default "exit" easing — slow start, accelerate away.
  static const Curve exit = Cubic(0.40, 0.00, 1.00, 1.00);

  /// Material 3 standard easing.
  static const Curve standard = Cubic(0.20, 0.00, 0.00, 1.00);

  /// Emphasised easing — hero transitions, world unlock.
  static const Curve emphasized = Cubic(0.20, 0.00, 0.00, 1.00);

  /// Gentle easing — soft taps, mascot breathing, calm chips.
  static const Curve gentle = Cubic(0.20, 0.00, 0.20, 1.00);

  /// Linear — continuous loops, rainbow shimmer, cloud drift.
  static const Curve linear = Cubic(0.00, 0.00, 1.00, 1.00);


  // ── Domain-specific wrappers (mapped to docs/design_system/08 §3) ─────
  /// Button bounce — used by every Primary / Secondary tap feedback.
  static const Curve buttonBounce = Curves.easeOutQuad;

  /// Mascot breathing — slow inhale / exhale cycle (matches AppDuration.mascotBreath).
  static const Curve mascotBreath = Curves.easeInOut;

  /// Sparkles entrance — particle emergence curve.
  static const Curve sparkle = Curves.easeOutCubic;

  /// Confetti gravity envelope.
  static const Curve confetti = Curves.linear;

  /// Reward explosion — bouncy priming for the chest opening.
  static const Curve rewardExplosion = Curves.elasticOut;

  /// Loading bar indeterminate sweep.
  static const Curve loadingSweep = Curves.easeInOut;

  /// Magic trail behind cursors on the Coloring canvas.
  static const Curve magicTrail = Curves.easeOut;
}


// =============================================================================
//  AppBreakpoints — Material 3 breakpoint widths (logical px).
// =============================================================================

/// Material 3 breakpoint catalogue. Values are the lower-bound width of a
/// given class, in logical pixels. Devices smaller than [compact] are
/// sub-compact (e.g. smart watches, foldable cover screens).
abstract final class AppBreakpoints {
  const AppBreakpoints._();

  /// Phone portrait — covers 96 % of installs in Magic Colors analytics.
  static const double compact = 600.0;

  /// Small tablet / large phone landscape — iPad mini, Galaxy Tab A.
  static const double medium = 840.0;

  /// Large tablet / small laptop — iPad Pro 11", Tab S8+.
  static const double expanded = 1200.0;

  /// Desktop — small monitors, iPad Pro 12.9" landscape.
  static const double large = 1600.0;

  /// TV + presentation screens.
  static const double extraLarge = 2000.0;
}


// =============================================================================
//  WindowSizeClass — what Material 3 calls the bucket for a given width.
// =============================================================================

/// Bucketed enum equivalent of `MediaQuery.sizeOf(context).width` clamped
/// to the Material 3 [AppBreakpoints] catalogue.
///
/// Devices smaller than [AppBreakpoints.compact] (smart watches, foldable
/// cover screens) map to [WindowSizeClass.subCompact].
enum WindowSizeClass {
  subCompact,
  compact,
  medium,
  expanded,
  large,
  extraLarge,
}


// =============================================================================
//  AppResponsive — sugar over MediaQuery + AppBreakpoints.
// =============================================================================

abstract final class AppResponsive {
  const AppResponsive._();

  /// Maps the available viewport width to a [WindowSizeClass].
  static WindowSizeClass sizeClassOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppBreakpoints.compact) {
      return WindowSizeClass.subCompact;
    }
    if (width < AppBreakpoints.medium) {
      return WindowSizeClass.compact;
    }
    if (width < AppBreakpoints.expanded) {
      return WindowSizeClass.medium;
    }
    if (width < AppBreakpoints.large) {
      return WindowSizeClass.expanded;
    }
    if (width < AppBreakpoints.extraLarge) {
      return WindowSizeClass.large;
    }
    return WindowSizeClass.extraLarge;
  }

  /// True iff the current viewport is a phone (compact or smaller).
  static bool isCompactLike(BuildContext context) {
    final cls = sizeClassOf(context);
    return cls == WindowSizeClass.subCompact ||
        cls == WindowSizeClass.compact;
  }

  /// True iff the current viewport is a tablet or larger.
  static bool isTabletOrLarger(BuildContext context) {
    return !isCompactLike(context);
  }

  /// Scale factor for type + spacing on tablets. Always returns 1.0 on
  /// compact phones; returns 1.15 on medium and up; 1.30 on expanded+.
  /// Mirrors docs/design_system/03_TYPOGRAPHY.md §9 OS-type scale table.
  static double scaleOf(BuildContext context) {
    final cls = sizeClassOf(context);
    switch (cls) {
      case WindowSizeClass.subCompact:
      case WindowSizeClass.compact:
        return 1.0;
      case WindowSizeClass.medium:
        return 1.15;
      case WindowSizeClass.expanded:
      case WindowSizeClass.large:
      case WindowSizeClass.extraLarge:
        return 1.30;
    }
  }

  /// Maximum content width for centred content on tablets / desktop so
  /// reading rows never exceed ~ 720 dp. Used by Pages with prose (Parents
  /// Area + body-content screens).
  static const double maxReadableContentWidth = 720.0;
}


// =============================================================================
//  AppHairline — 1 dp divider stroke.
// =============================================================================

/// Hairline divider used inside Lists + TabBars. The widget layer applies
/// this via `Divider(thickness: AppHairline.thickness, color: ...)`.
abstract final class AppHairline {
  const AppHairline._();

  /// 1 dp thickness.
  static const double thickness = 1.0;

  /// 2 dp thickness (used between major content sections).
  static const double thickThickness = 2.0;

  /// Standard inner radius for a `Radius.circular(0.5)` clip.
  static const Radius innerRadius = Radius.circular(0.5);
}
