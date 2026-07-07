// =============================================================================
// Magic Colors · features/home/presentation/widgets/home_header.dart
// =============================================================================
//
// Top sticky strip of the Home screen. Two visual rows:
//
//   ① Brand + balances row  ─ SplashLogo (compact, FittedBox into 64 dp)
//                              on the left, CurrencyHUD (compact: true) on
//                              the right. Pushed apart via
//                              `MainAxisAlignment.spaceBetween`.
//
//   ② Secondary action row  ─ right-aligned Settings / Notifications icon
//                              buttons + a streak badge driven from
//                              [PlayerState.streakDays]. Each icon is a
//                              `Semantics(button: true, …)`-annotated
//                              `InkResponse` so screen readers find them and
//                              haptic-friendly taps land in the project's
//                              accessibility floor.
//
// Both rows sit inside a single `SafeArea(bottom: false)` so the brand mark
// never collides with a notch. Pure Foundation consumer: reads
// [PlayerState] (from Foundation), no Provider wiring of its own beyond what
// [SplashLogo]/[CurrencyHUD] need. Routing for Settings / Notifications is
// deferred to caller-supplied callbacks (no GoRouter / NavigationState
// imports anywhere in this file).
//
// Public API: `class HomeHeader extends StatelessWidget`.
// Helpers (`_HeaderIconButton`, `_StreakBadge`, `_HeaderLogoBox`) and the
// tuning constants are file-private (underscore-prefixed).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/state/player_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/currency_hud.dart';
import '../../../../core/widgets/splash_logo.dart';

// ── Frozen tuning constants ──────────────────────────────────────────────────

/// Header logo draws inside a square this big — SplashLogo's intrinsic
/// 280 × 280 is then FittedBox'd down so it spends no more than [_kHeaderLogoSide]
/// dp horizontally. Keeps the chrome reading as a compact mark rather than
/// a full splash-disc.
const double _kHeaderLogoSide = 64.0;

/// Bottom gap between the brand row and the secondary action row.
const SizedBox _kRowGap = SizedBox(height: AppSpacing.sm);

/// Horizontal gap between Settings / Notif / Streak chip.
const double _kActionGap = AppSpacing.sm;

/// Glyph size inside the header icon buttons.
const double _kIconGlyphSize = 24.0;

/// Ink response radius around header icon buttons (≥ 48 dp tap target).
const double _kIconTouchRadius = 24.0;

/// Flame icon size inside the streak chip.
const double _kStreakFlameSize = 16.0;

/// Counter type-size inside the streak chip.
const double _kStreakCountFontSize = 14.0;

/// Padding around the streak chip.
const EdgeInsets _kStreakChipPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.sm,
  vertical: AppSpacing.xs,
);

/// Horizontal inset applied to the entire strip so brand + chrome never
/// collide with the screen edge or with the right-side gesture handler.
const EdgeInsets _kStripInsets = EdgeInsets.symmetric(
  horizontal: AppSpacing.xl,
  vertical: AppSpacing.md,
);

const String _kStreakLabel = 'Streak';
const String _kSettingsLabel = 'Open settings';
const String _kNotificationsLabel = 'Open notifications';
const Color _kStreakChipFillA = AppColors.sunshineYellow;
const Color _kStreakChipText = AppColors.deepInk;
const Color _kIconGlyphColor = AppColors.deepInk;
const double _kStreakChipLetterSpacing = 0.4;
const double _kZeroStreakDisplayThreshold = 0.0;

/// Disabled-state icon alpha — calibrated to the project's M3 secondary
/// gating pattern (mirrors how primary CTAs paint their disabled state).
const double _kDisabledGlyphAlpha = 0.38;

// =============================================================================
//  HomeHeader — public widget.
// =============================================================================

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    this.onSettingsTap,
    this.onNotificationsTap,
    this.semanticLabel = 'Home header',
  });

  /// Caller-supplied callback for the Settings icon button. `null` paints a
  /// disabled-tinted glyph (deepInk at 38 % alpha) and silences the tap.
  final VoidCallback? onSettingsTap;

  /// Caller-supplied callback for the Notifications icon button.
  final VoidCallback? onNotificationsTap;

  /// Top-level Semantics label applied to the entire strip so TalkBack
  /// groups the chrome as a single landmark.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: _kStripInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildBrandRow(),
              _kRowGap,
              _buildActionRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _HeaderLogoBox(side: _kHeaderLogoSide),
        CurrencyHUD(compact: true, hideZero: false),
      ],
    );
  }

  Widget _buildActionRow() {
    final settingsEnabled = onSettingsTap != null;
    final notifsEnabled = onNotificationsTap != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        _HeaderIconButton(
          icon: Icons.settings_outlined,
          semanticLabel: _kSettingsLabel,
          enabled: settingsEnabled,
          onTap: onSettingsTap,
        ),
        const SizedBox(width: _kActionGap),
        _HeaderIconButton(
          icon: Icons.notifications_outlined,
          semanticLabel: _kNotificationsLabel,
          enabled: notifsEnabled,
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: _kActionGap),
        const _StreakBadge(),
      ],
    );
  }
}

// =============================================================================
//  _HeaderLogoBox — file-private FittedBox wrapper around SplashLogo.
// =============================================================================

/// Fits [SplashLogo] (intrinsic 280 × 280) inside a [_kHeaderLogoSide] dp
/// square, so the brand mark reads as a compact corner mark rather than a
/// fullscreen splash disc. SplashLogo's own fade-in + scale animation is
/// preserved — FittedBox simply re-scales the rasterised output each
/// frame.
class _HeaderLogoBox extends StatelessWidget {
  const _HeaderLogoBox({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: side,
      height: side,
      child: const FittedBox(
        child: SplashLogo(),
      ),
    );
  }
}

// =============================================================================
//  _HeaderIconButton — file-private Material icon tap target.
// =============================================================================

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Disabled glyph runs at [_kDisabledGlyphAlpha] — calibrated to the
    // project's M3 secondary gating pattern (mirrors how primary CTAs
    // paint their disabled state).
    final glyphAlpha = enabled ? 1.0 : _kDisabledGlyphAlpha;
    final glyphColor = _kIconGlyphColor.withValues(alpha: glyphAlpha);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: _kIconTouchRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              icon,
              size: _kIconGlyphSize,
              color: glyphColor,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  _StreakBadge — file-private flame-counter chip.
// =============================================================================

class _StreakBadge extends StatelessWidget {
  const _StreakBadge();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerState>();
    final streakDays = player.streakDays;
    final showStreak = streakDays > _kZeroStreakDisplayThreshold;

    return Semantics(
      label: showStreak
          ? '$_kStreakLabel: $streakDays days'
          : '$_kStreakLabel: no current streak',
      child: Container(
        padding: _kStreakChipPadding,
        decoration: const BoxDecoration(
          // Fire-coloured gradient + softChip glow makes the badge read
          // as a celebratory marker without competing with the PLAY NOW
          // button's hot-pink halo for attention.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _kStreakChipFillA,
              AppColors.tangerine,
            ],
            stops: <double>[0.0, 1.0],
          ),
          borderRadius: AppCorner.brMd,
          boxShadow: AppElevation.softChip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.local_fire_department,
              size: _kStreakFlameSize,
              color: _kStreakChipText,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              streakDays.toString(),
              style: AppTypography.labelMd.copyWith(
                color: _kStreakChipText,
                fontWeight: FontWeight.w800,
                fontSize: _kStreakCountFontSize,
                letterSpacing: _kStreakChipLetterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
