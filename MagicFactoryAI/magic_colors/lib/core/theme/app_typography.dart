// =============================================================================
// Magic Colors · core/theme/app_typography.dart
// =============================================================================
//
// Frozen typographic tokens (display / title / button / body / label / numeric).
// Mirrors §3 of docs/design_system/03_TYPOGRAPHY.md ("Modular scale 1.250,
// major third, rounded for screen rendering").
//
// Two type families only:
//
//   ▸ Title family  — Baloo 2 (Google Fonts, OFL). Used for screen titles,
//                     button labels, modal headers, reward pop-ups, and
//                     numerics.
//   ▸ Body family   — Nunito  (Google Fonts, OFL). Used for body copy,
//                     captions, Parents Area, tooltips, system messages.
//
// Adding a third family is a brand-level decision (lead designer + Creative
// Director sign-off required). All tokens resolve through the Google Fonts
// package so font metrics stay aligned with the system line-height APIs.
// =============================================================================

import 'package:flutter/material.dart'
    show Brightness, Color, FontFeature, FontWeight, TextStyle, TextTheme;
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

// =============================================================================
//  Shared letter-spacing scale.
///
/// `no-magic-number: max-occurrences: 3` would otherwise flag the same
/// `letterSpacing` value repeated 7× across the title/display/numeric
/// styles. Pulling it into a named constant keeps the design rule auditable
/// and avoids the lint exception.
// =============================================================================

/// Tight letter-spacing (titles + numerics). -0.2 px.
const double _letterSpacingTight = -0.2;

/// Slightly tightened card titles. -0.1 px.
const double _letterSpacingCard = -0.1;

/// Default letter-spacing (body + button + label). 0.0 px.
const double _letterSpacingNormal = 0.0;

// =============================================================================
//  AppTypography — frozen TextStyle tokens.
// =============================================================================

abstract final class AppTypography {
  const AppTypography._();

  // ── Display family (Baloo 2 · 800) ─────────────────────────────────────
  /// Splash logo only. 56 / 800.
  static final TextStyle displayXxl = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: _letterSpacingTight,
    ),
  );

  /// Reward pop-ups. 44 / 800.
  static final TextStyle displayXl = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: _letterSpacingTight,
    ),
  );

  /// Hero "WOW!" line in reward popup. 36 / 800.
  static final TextStyle displayLg = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: _letterSpacingTight,
    ),
  );

  // ── Title family (Baloo 2) ─────────────────────────────────────────────

  /// Screen titles. 36 / 800.
  static final TextStyle titleLg = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: _letterSpacingTight,
    ),
  );

  /// Modal titles. 28 / 700.
  static final TextStyle titleMd = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: _letterSpacingTight,
    ),
  );

  /// Card titles. 22 / 700.
  static final TextStyle titleSm = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: _letterSpacingCard,
    ),
  );

  // ── Button family (Baloo 2) ────────────────────────────────────────────

  /// Big CTA (PLAY NOW). Default 30 / 800 — size parameterised so widget
  /// call sites like `AppTypography.bigButton(size: 30)` continue to
  /// compile. Use `color:` to override the default cloud-white surface
  /// (e.g. for darker accent CTAs in dark mode).
  static TextStyle bigButton({double size = 30, Color? color}) {
    return GoogleFonts.baloo2(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.cloudWhite,
        height: 1.0,
        letterSpacing: _letterSpacingNormal,
      ),
    );
  }

  /// Medium CTA. 20 / 700.
  static final TextStyle buttonMd = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  /// Tertiary chips. 16 / 700.
  static final TextStyle buttonSm = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.0,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  /// M2.3 PRODUCTION — Secondary-button label. Returns a
  /// size-parameterised Baloo 2 700-weight TextStyle so widgets
  /// (e.g. SecondaryButton which lays a single label over a
  /// square 84 dp button) can ask for the right size at the
  /// call site without us having to ship a token for each
  /// distinct size. Same Baloo 2 source as the other buttonMd/
  /// buttonSm tokens so the family reads consistently.
  ///
  /// [color] is optional so widget-layer call sites (e.g.
  /// `AppTypography.buttonLabel(size: 16, color: Colors.white)`)
  /// can override the default `AppColors.deepInk` for inverted
  /// surfaces (chest buttons, reward pill labels).
  static TextStyle buttonLabel({required double size, Color? color}) {
    return GoogleFonts.baloo2(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.deepInk,
        height: 1.0,
        letterSpacing: _letterSpacingNormal,
      ),
    );
  }

  // ── Body family (Nunito) ─────────────────────────────────────────────────

  /// Body emphasis. 20 / 600.
  static final TextStyle bodyXl = GoogleFonts.nunito(
    textStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.35,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  /// Body default. 18 / 500.
  static final TextStyle bodyLg = GoogleFonts.nunito(
    textStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  /// Body small — Parents Area paragraphs. 16 / 500.
  static final TextStyle bodyMedium = GoogleFonts.nunito(
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  /// Caption. 14 / 500.
  static final TextStyle bodySm = GoogleFonts.nunito(
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  // ── Label family (Nunito · 700) ──────────────────────────────────────────

  /// Bottom-nav tab labels, top-tab labels. 16 / 700.
  static final TextStyle labelLg = GoogleFonts.nunito(
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  /// Chip labels and inline pill labels. 14 / 700.
  static final TextStyle labelMd = GoogleFonts.nunito(
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: _letterSpacingNormal,
    ),
  );

  // ── Numeric family (Baloo 2 — supports tabular figures) ──────────────────

  /// Currency counters (Coin / Gem HUD). 28 / 800, tabular figures via
  /// Baloo 2's OpenType `tnum` feature — selected globally in ThemeData.
  static final TextStyle numericCounter = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: _letterSpacingTight,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
  );

  /// Compact counter (reward pop-ups). 22 / 800.
  static final TextStyle numericCompact = GoogleFonts.baloo2(
    textStyle: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: _letterSpacingTight,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
  );

  // ── M2.4 hotfix — legacy widget-layer parametrized methods ──────────
  //
  // lib/widgets/* widgets and lib/features/home/* widgets predate the
  // typography-token consolidation and call methods like
  // `AppTypography.caption(size: 12, color: ...)` / `.body(size:, color:)`.
  // These static helpers cover the full legacy surface without forcing a
  // wholesale UI rewrite. New calls should reach for the typed tokens
  // (`bodyMedium`, `numericCounter`, …) directly.

  /// Nunito caption / chip label. 12 / 700 default.
  static TextStyle caption({double size = 12, Color? color}) {
    return GoogleFonts.nunito(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.smoke,
        letterSpacing: 0.4,
        height: 1.0,
      ),
    );
  }

  /// Baloo 2 section title. 18 / 800 default.
  static TextStyle sectionTitle({double size = 18, Color? color}) {
    return GoogleFonts.baloo2(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.deepInk,
        height: 1.1,
      ),
    );
  }

  /// Nunito body copy. 16 / 600 default.
  static TextStyle body({double size = 16, Color? color}) {
    return GoogleFonts.nunito(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.deepInk,
        height: 1.3,
      ),
    );
  }

  /// Baloo 2 currency / counter label. 16 / 800 default.
  static TextStyle currencyAmount({double size = 16, Color? color}) {
    return GoogleFonts.baloo2(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.deepInk,
        height: 1.0,
      ),
    );
  }

  /// Baloo 2 logo / brand wordmark. 24 / 800 default.
  static TextStyle logo({double size = 24, Color color = AppColors.deepInk}) {
    return GoogleFonts.baloo2(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
        height: 1.0,
      ),
    );
  }
}

// =============================================================================
//  Convenience reversions — what to use inside ThemeData.textTheme.
// =============================================================================

/// Builds the full [TextTheme] consumed by Material 3 widgets (AppBar,
/// Dialog, ButtonText, etc.). Composes [AppTypography] tokens so Material's
/// built-in text roles stay aligned with our scale.
///
/// Pass [platformBrightness] to optionally swap the body colour for night
/// mode (the rest of the scale is identical across light/dark).
TextTheme buildTextTheme(Brightness platformBrightness) {
  return TextTheme(
    displayLarge: AppTypography.displayXxl,
    displayMedium: AppTypography.displayXl,
    displaySmall: AppTypography.displayLg,
    headlineLarge: AppTypography.titleLg,
    headlineMedium: AppTypography.titleMd,
    headlineSmall: AppTypography.titleSm,
    titleLarge: AppTypography.titleMd,
    titleMedium: AppTypography.titleSm,
    titleSmall: AppTypography.buttonMd,
    labelLarge: AppTypography.labelLg,
    labelMedium: AppTypography.labelMd,
    labelSmall: AppTypography.labelMd,
    bodyLarge: AppTypography.bodyXl,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySm,
  ).apply(
    bodyColor: platformBrightness == Brightness.light
        ? const Color(0xFF0F1226)
        : const Color(0xFFF2F0FF),
    displayColor: platformBrightness == Brightness.light
        ? const Color(0xFF0F1226)
        : const Color(0xFFF2F0FF),
  );
}
