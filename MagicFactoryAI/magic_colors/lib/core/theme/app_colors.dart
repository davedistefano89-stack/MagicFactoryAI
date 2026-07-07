// =============================================================================
// Magic Colors · core/theme/app_colors.dart
// =============================================================================
//
// Frozen color palette. Every widget pulls its colors from here — no widget
// ever calls `Color(0xFF...)` directly. Values mirror §3-§6 of
// docs/design_system/02_COLOR_SYSTEM.md (v1.0 baseline, Creative Director
// sign-off required to change).
//
// Layout conventions used in this file:
//   Tier 1 — Brand Identity (Magic Pink · Magic Purple · Sunshine Yellow · Sky Cyan)
//   Tier 2 — Experience Palette
//            Light: sky/clouds/bubblegum/lagoon/lavender + ink/smoke
//            Night: night-sky stops + moonbeam + galactic pink/purple
//   Tier 3 — Reward Palette (Coin/Gem/Star/Heart + halo glows)
//   Tier 4 — Functional Palette (success · warning · info · error · link)
//
// NOTE: this file must NOT import Material widgets. It is the bottom of the
// visual-stack dependency graph and is imported by every other theme file.
// =============================================================================

import 'package:flutter/painting.dart' show Color;

// =============================================================================
//  Tier 1 — Brand Identity.
// =============================================================================

/// The canonical Magic Colors logo + primary CTA color. Sun-bright pink,
/// never cold. AA-verified contrast on deep ink (5.74:1).
const Color kMagicPink = Color(0xFFFF4F9A);

/// Secondary CTA, premium buttons. AA-verified contrast on white (7.18:1).
const Color kMagicPurple = Color(0xFF7A55D9);

/// Highlight + reward background. Decorative-only — fail AA on white text
/// (1.51:1), so never paint type on yellow without a deep-ink outline.
const Color kSunshineYellow = Color(0xFFFFC93C);

/// Sky cyan — cool-context primary CTA. Pairs with deep-ink text in cool
/// sub-themes.
const Color kSkyCyan = Color(0xFF3FC9FF);

/// Static facade for the magic_colors brand palette.
abstract final class AppColors {
  const AppColors._();

  // ── Tier 1 — Brand ────────────────────────────────────────────────────
  /// Logo + primary CTA. Magic Pink.
  static const Color magicPink = kMagicPink;

  /// Secondary CTA + premium buttons. Magic Purple.
  static const Color magicPurple = kMagicPurple;

  /// Decorative highlight + reward surfaces. Sunshine Yellow.
  static const Color sunshineYellow = kSunshineYellow;

  /// Cool-context primary CTA. Sky Cyan.
  static const Color skyCyan = kSkyCyan;

  // ── Tier 2 — Experience · Light ─────────────────────────────────────
  /// Sky top stop on the default animated sky gradient.
  static const Color skyTop = Color(0xFFA6E8FF);

  /// Sky bottom stop on the default animated sky gradient.
  static const Color skyBottom = Color(0xFFFCE4FF);

  /// Pure white cloud body.
  static const Color cloudWhite = Color(0xFFFFFFFF);

  /// Soft surface for cards and the "bubblegum cloud" decoration behind
  /// daily-event copy.
  static const Color bubblegum = Color(0xFFFFB6E1);

  /// Achievement / success surfaces (fresh, calming green).
  static const Color mintLeaf = Color(0xFF7AE3C0);

  /// Warm accent — sun, food, dragon fire, etc.
  static const Color tangerine = Color(0xFFFF7F5C);

  /// Water-themed worlds, secondary calm accent.
  static const Color lagoon = Color(0xFF4ECDC4);

  /// Soft pastel surface, used inside night-mode hints.
  static const Color lavender = Color(0xFFC4B0FF);

  /// Default text color on light surfaces. Tested AA on every Tier-1 + 2
  /// background.
  static const Color deepInk = Color(0xFF0F1226);

  /// Secondary text color on light surfaces (captions, metadata).
  static const Color smoke = Color(0xFF6B6E80);

  // ── Tier 2 — Experience · Night ─────────────────────────────────────
  /// Night-sky gradient top stop.
  static const Color skyTopNight = Color(0xFF1B1E5C);

  /// Night-sky gradient middle stop.
  static const Color skyMidNight = Color(0xFF3C2D7C);

  /// Night-sky gradient bottom stop. Same hex as deepInk so foreground
  /// text colour is constant across light + dark surfaces.
  static const Color skyBottomNight = Color(0xFF0F1226);

  /// Star + firefly hue on night backgrounds.
  static const Color starGold = Color(0xFFFFD96B);

  /// Moon outline + mascot outline glow on night backgrounds.
  static const Color moonbeam = Color(0xFFF2F0FF);

  /// Night-mode primary CTA.
  static const Color galacticPink = Color(0xFFFF7AB6);

  /// Night-mode secondary CTA.
  static const Color cosmicPurple = Color(0xFFA88BFF);

  // ── Tier 3 — Reward Palette ──────────────────────────────────────────
  /// Coin glyph. The ONLY legitimate use is inside the coin widget.
  static const Color coinGold = Color(0xFFFFD147);

  /// Gem glyph. Royal Blue. Restricted to the gem widget.
  static const Color gemRoyal = Color(0xFF3D7BFF);

  /// Star-reward glyph (white-gold).
  static const Color starReward = Color(0xFFFFF6C7);

  /// Heart glyph (life / streak). Coral.
  static const Color heartCoral = Color(0xFFFF6B6B);

  /// Glow halos — surround their matching glyph at 8 dp blur. These are
  /// alpha-multiplied so they sit visibly atop any background while still
  /// feeling "soft".
  static const Color coinHalo = Color(0x8CFFE97F); // rgba(255,233,127,0.55)
  static const Color gemHalo = Color(0x8C8CB4FF); // rgba(140,180,255,0.55)
  static const Color starHalo = Color(0xB3FFFAC8); // rgba(255,250,200,0.70)
  static const Color heartHalo = Color(0x99FFB4B4); // rgba(255,180,180,0.60)

  // ── Tier 4 — Functional ──────────────────────────────────────────────
  /// Confirmation, unlock, parent-safe.
  static const Color success = Color(0xFF3DD68C);

  /// Gentle reminders, never punitive.
  static const Color warning = Color(0xFFFFB23F);

  /// Tooltips, hints, neutral info.
  static const Color info = Color(0xFF5BB8FF);

  /// Error — Parents Area ONLY for input validation. Never shown to kids.
  static const Color error = Color(0xFFFF6B6B);

  /// Hyperlinks (Parents Area only).
  static const Color link = Color(0xFF7A55D9);

  // ── Misc utility colours ─────────────────────────────────────────────
  /// Sky-touched white. Default scaffold background in light mode. Slight
  /// cool tint prevents the eye-fatigue a pure white background produces.
  static const Color skyTouchedWhite = Color(0xFFFAFBFF);

  /// 1 dp hairline that respects dark/light mode. 10 % deep ink alpha.
  static const Color hairlineLight = Color(0x1A0F1226);

  /// 1 dp hairline on dark surfaces. 10 % moonbeam alpha.
  static const Color hairlineDark = Color(0x1AF2F0FF);

  // ── M2.3 PRODUCTION — widget-layer aliases ─────────────────────────────
  //
  // Many widgets in features/home/widgets/ and magic_card / mascot /
  // animated_background predate the Tier 1/2 palette consolidation and
  // still reference legacy names like `rainbowRed`, `primaryPink`,
  // `textDark`, `notificationBubble`, etc. These static aliases route
  // every legacy reference back to the canonical Tier 1/2 token so the
  // design system stays single-source-of-truth; new code should reach
  // for the canonical Tier 1/2 token directly.

  // ── Rainbow register (the 6 most-popular stops in the rainbow gradient)
  static const Color rainbowRed = magicPink;
  static const Color rainbowOrange = tangerine;
  static const Color rainbowYellow = sunshineYellow;
  static const Color rainbowGreen = mintLeaf;
  static const Color rainbowBlue = skyCyan;
  static const Color rainbowPurple = magicPurple;

  // ── Tier-1 widget-layer aliases (legacy "primary*" prefix)
  static const Color primaryPink = magicPink;
  static const Color primaryPurple = magicPurple;
  static const Color accentYellow = sunshineYellow;

  // ── Reward palette variants
  static const Color gemPink = heartCoral;
  static const Color gemPinkShade = heartHalo;
  static const Color coinGoldShade = coinHalo;

  // ── Text + surface conveniences
  static const Color textDark = deepInk;
  static const Color textMid = smoke;
  static const Color shadowSoft = hairlineLight;
  static const Color notificationBubble = error;
}

// =============================================================================
//  Public top-level shortcuts — surface used by widgets that have to drag a
//  color into a const constructor (BoxDecoration, Padding decoration, ...).
// =============================================================================

/// Top-level alias for `AppColors.magicPink`.
///
/// Why this exists: `const BoxDecoration(color: AppColors.magicPink)` will
/// compile; `const BoxDecoration(color: kMagicPink)` makes the same call
/// site shorter by 12 characters when pasted across the codebase, which
/// matters because every PrimaryButton / SecondaryButton decoration block
/// references these tokens four or five times.
const Color magicPink = kMagicPink;

/// Top-level alias for `AppColors.magicPurple`.
const Color magicPurple = kMagicPurple;

/// Top-level alias for `AppColors.sunshineYellow`.
const Color sunshineYellow = kSunshineYellow;

/// Top-level alias for `AppColors.skyCyan`.
const Color skyCyan = kSkyCyan;
