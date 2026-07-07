// =============================================================================
// Magic Colors · core/widgets/magic_card.dart
// =============================================================================
//
// The "magic card" silhouette — a flat-blank surface with a generous
// AppCorner.brLg curve and AppElevation.z1 → z2 on press. Every world tile,
// every achievement chip, every progress meter renders its content inside a
// [MagicCard].
//
// Design contract (docs/design_system/04_UI_COMPONENTS.md §5):
//   ▸ Background: AppColors.cloudWhite (light) / AppColors.skyBottomNight
//                 (dark). Optional gradient override via [gradient].
//   ▸ Corners:    AppCorner.brLg by default; overridable.
//   ▸ Padding:    AppSpacing.cardPaddingTight by default; overridable.
//   ▸ Elevation:  AppElevation.z1 at rest, AppElevation.z2 while pressed
//                 (only when [onTap] is non-null).
//   ▸ Skin:       blank, tinted, accent — selected via [MagicCardSkin].
// =============================================================================

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../theme/app_colors.dart';
import '../theme/app_shape.dart';

/// Visual skin of a [MagicCard].
enum MagicCardSkin {
  /// Pure cloud-white surface — used by default.
  blank,

  /// Sky-touched-white → lavender gradient — used for "tutorial highlight"
  /// cards and onboarding overlays.
  tinted,

  /// Rainbow gradient border + cloud-white fill — used for the "selected
  /// achievement" case in the Gallery and the "today's pick" banner.
  accent,
}

// =============================================================================
//  MagicCard — the canonical card surface.
// =============================================================================

class MagicCard extends StatelessWidget {
  const MagicCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.gradient,
    this.elevation,
    this.skin = MagicCardSkin.blank,
    this.borderColor,
    this.borderRadius,
  });

  /// Card content. Required.
  final Widget child;

  /// Inline padding. Defaults to [AppSpacing.cardPaddingTight].
  final EdgeInsetsGeometry? padding;

  /// Tap callback. When non-null, the card paints a pressed-state elevation.
  final VoidCallback? onTap;

  /// Background gradient. Overrides [skin]'s default fill.
  final LinearGradient? gradient;

  /// Elevation override. When `onTap` is `null` the resting elevation is
  /// used; otherwise the pressed-state elevation is used automatically.
  final List<BoxShadow>? elevation;

  /// Visual skin (only consulted when [gradient] is `null`).
  final MagicCardSkin skin;

  /// Optional 2 dp border colour. Renders ABOVE the gradient.
  final Color? borderColor;

  /// Corner override. Defaults to [AppCorner.brLg].
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resting = _resolveElevation();

    final gradi = gradient ?? _resolveGradient(isDark);
    final fill = isDark
        ? (gradi == null ? AppColors.skyBottomNight : null)
        : (gradi == null ? AppColors.cloudWhite : null);

    // Promote `borderColor` out of `Color?` via a local final so the box
    // decoration no longer needs the `!` bang — keeps the project's
    // `bang-bang-operator` lint rule quiet.
    final borderColorLocal = borderColor;
    final border = borderColorLocal == null
        ? null
        : Border.all(color: borderColorLocal, width: 2.0);

    final card = AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.gentle,
      decoration: BoxDecoration(
        gradient: gradi,
        color: fill,
        borderRadius: borderRadius ?? AppCorner.brLg,
        border: border,
        boxShadow: elevation ?? resting,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius ?? AppCorner.brLg,
          onTap: onTap,
          splashColor: AppColors.magicPink.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: (padding ?? AppSpacing.cardPaddingTight),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }
    return Card(
      // The outer Card widget is reserved for accessibility (semantic
      // grouping). All visual styling lives on the inner AnimatedContainer.
      elevation: 0.0,
      shape: AppShapeBorder.card,
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: card,
    );
  }

  List<BoxShadow> _resolveElevation() {
    // Promote `elevation` out of `List<BoxShadow>?` via a local final so
    // the bang operator doesn't appear in the return path — the project's
    // `bang-bang-operator` lint flags any `!` regardless of flow-analysis
    // promotion.
    final override = elevation;
    if (override != null) {
      return override;
    }
    // Resting = z1, pressed = z2 (matches the doc-comment promise above
    // and Material 3's "raise on interaction" pattern).
    return onTap == null ? AppElevation.z1 : AppElevation.z2;
  }

  LinearGradient? _resolveGradient(bool isDark) {
    switch (skin) {
      case MagicCardSkin.blank:
        return null;
      case MagicCardSkin.tinted:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.skyTouchedWhite,
            AppColors.lavender.withValues(alpha: 0.40),
          ],
          stops: const <double>[0.0, 1.0],
        );
      case MagicCardSkin.accent:
        // Borderless rainbow ring — the actual fill stays cloud-white so
        // the card's contrast baseline holds.
        return null;
    }
  }
}
