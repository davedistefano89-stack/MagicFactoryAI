// =============================================================================
// Magic Colors · core/theme/app_theme.dart
// =============================================================================
//
// Single source of truth for the Material 3 ThemeData consumed by
// `MaterialApp.router` in lib/app.dart. Both light and dark variants are
// generated from the magicPurple seed so a single `seedColor: kMagicPurple`
// tweak propagates through the entire ColorScheme.
//
// Conventions enforced here:
//   ▸ `useMaterial3: true` — Material 3 is the only surface widgets see.
//   ▸ Animated text scaling is clamped via TextScaler clamp so the platform
//     accessibility slider cannot break layouts.
//   ▸ Tap targets default to the Material 3 minimum of 48 dp; primary CTAs
//     inherit a custom 56 dp through ElevatedButtonThemeData.
//   ▸ Material's `Card` / `Dialog` / `AppBar` / `NavigationBar` widgets get
//     fully themed — every visible widget in the app reads through this
//     ThemeData; nothing reads raw Material defaults.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'app_colors.dart';
import 'app_shape.dart';
import 'app_typography.dart';

// =============================================================================
//  AppTheme — public surface.
// =============================================================================

abstract final class AppTheme {
  const AppTheme._();

  /// Frozen light theme. Default mode for kids aged 3–8.
  static final ThemeData light = _build(Brightness.light);

  /// Frozen dark theme. Auto-applied between 20:00 and 07:00 (Sunset
  /// window defined in docs/design_system/02_COLOR_SYSTEM.md §4.2).
  static final ThemeData dark = _build(Brightness.dark);

  /// Status-bar + nav-bar overlay styles that match each brightness so the
  /// platform chrome doesn't poke through the magic colours.
  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFFAFBFF),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F1226),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  // ── Builder ─────────────────────────────────────────────────────────────
  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.magicPurple,
      brightness: brightness,
    );

    // Default scaffold background shifts to night-ink in dark mode.
    final scaffoldBg = brightness == Brightness.light
        ? AppColors.skyTouchedWhite
        : AppColors.skyBottomNight;

    final textTheme = buildTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      visualDensity: VisualDensity.standard,
      // Clamp platform text scaler so the OS accessibility slider cannot
      // break layout. Min 0.85, max 1.30 per docs/design_system/03 §9.
      textTheme: textTheme,
      iconTheme: IconThemeData(
        color: brightness == Brightness.light
            ? AppColors.deepInk
            : AppColors.moonbeam,
        size: 24.0,
      ),

      // ── AppBar ──────────────────────────────────────────────────────
      // M2.4 hotfix — Flutter 3.27.4's analyzer refuses `*ThemeData`
      // constructors in some sandboxed SDK setups. Fall back to the
      // long-lived `AppBarTheme(...)` / `CardTheme(...)` / `DialogTheme(...)`
      // forms; both compile identically and produce the same ThemeData.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: brightness == Brightness.light
            ? AppColors.deepInk
            : AppColors.moonbeam,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: AppTypography.titleMd.copyWith(
          color: brightness == Brightness.light
              ? AppColors.deepInk
              : AppColors.moonbeam,
        ),
        systemOverlayStyle:
            brightness == Brightness.light ? lightOverlay : darkOverlay,
      ),

      // ── Card ─────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        elevation: 0,
        color: brightness == Brightness.light
            ? AppColors.cloudWhite
            : AppColors.skyBottomNight,
        margin: EdgeInsets.zero,
        shape: AppShapeBorder.card,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Dialog ───────────────────────────────────────────────────────
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cloudWhite,
        shape: AppShapeBorder.rewardPopup,
        elevation: 16.0,
        titleTextStyle: AppTypography.titleMd.copyWith(
          color: AppColors.deepInk,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.deepInk,
        ),
      ),

      // ── NavigationBar ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? AppColors.cloudWhite.withValues(alpha: 0.95)
            : AppColors.skyBottomNight.withValues(alpha: 0.95),
        indicatorColor: AppColors.magicPink.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final isSelected = states.contains(WidgetState.selected);
          return AppTypography.labelLg.copyWith(
            color: isSelected
                ? AppColors.magicPink
                : (brightness == Brightness.light
                    ? AppColors.smoke
                    : AppColors.lavender),
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 80.0,
      ),

      // ── ElevatedButton ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.magicPink,
          foregroundColor: AppColors.cloudWhite,
          minimumSize: const Size(64.0, 56.0),
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 16.0,
          ),
          shape: AppShapeBorder.buttonLarge,
          textStyle: AppTypography.buttonMd,
          elevation: 0,
        ),
      ),

      // ── IconButton ───────────────────────────────────────────────────
      // M2.4 hotfix — `IconButton.styleFrom`'s `shape` parameter is typed
      // as `OutlinedBorder?`; `RoundedRectangleBorder` is a `ShapeBorder`.
      // Drop the custom shape — Material's default Stadium outline is
      // fine for our 48-dp hit target. Re-enable when Flutter exports a
      // working stadium-or-rounded border alias.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48.0, 48.0),
          padding: const EdgeInsets.all(12.0),
        ),
      ),

      // ── Slider ───────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.magicPurple,
        inactiveTrackColor: AppColors.bubblegum.withValues(alpha: 0.30),
        thumbColor: AppColors.cloudWhite,
        overlayColor: AppColors.magicPurple.withValues(alpha: 0.12),
        trackHeight: 8.0,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 16.0,
        ),
      ),

      // ── ProgressIndicator ────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.magicPurple,
        linearTrackColor: AppColors.bubblegum.withValues(alpha: 0.30),
        circularTrackColor: AppColors.bubblegum.withValues(alpha: 0.30),
      ),

      // ── Divider ──────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: brightness == Brightness.light
            ? AppColors.hairlineLight
            : AppColors.hairlineDark,
        thickness: 1.0,
        space: 0.0,
      ),

      // ── TabBarTrack ──────────────────────────────────────────────────
      // Hotfix: see AppBar block above — use `TabBarTheme(...)` (legacy).
      tabBarTheme: TabBarTheme(
        labelColor: AppColors.magicPink,
        unselectedLabelColor: AppColors.smoke,
        indicatorColor: AppColors.magicPink,
        labelStyle: AppTypography.labelLg,
        unselectedLabelStyle: AppTypography.labelLg,
        dividerColor: brightness == Brightness.light
            ? AppColors.hairlineLight
            : AppColors.hairlineDark,
      ),

      // ── Tooltip ──────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.deepInk,
          borderRadius: AppCorner.brSm,
        ),
        textStyle: AppTypography.bodySm.copyWith(
          color: AppColors.cloudWhite,
        ),
      ),
    );
  }
}

// =============================================================================
//  TextScaler clamp — keeps OS-driven accessibility scaling within a sane
//  range so the app's grid layout never breaks (a 1.30× scaler on every
//  widget would otherwise push PLAY NOW off-screen on a small phone).
// =============================================================================

/// Clamp applied to `MediaQuery.textScalerOf(context)` so the OS slider
/// can grow/shrink our type but never push layouts off-screen.
TextScaler clampedTextScaler(TextScaler scaler) {
  return TextScaler.linear(
    scaler.scale(14.0) / 14.0, // derive the effective ratio
  ).clamp(
    minScaleFactor: 0.85,
    maxScaleFactor: 1.30,
  );
}
