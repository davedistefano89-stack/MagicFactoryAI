// =============================================================================
// Magic Colors · features/worlds/presentation/widgets/first_unlock_dialog.dart
// =============================================================================
//
// Sprint 6 — celebration dialog rendered when the player enters a
// world for the first time. One-shot per world (the
// PlayerState.celebratedWorldIds set is the gate).
//
// UX
//   • Full-bleed dialog with a tinted scrim.
//   • Big world glyph + "Welcome to [World]!" headline.
//   • [ConfettiBurst] ring fades in over 1.2 s.
//   • Single primary CTA "Awesome!" dismisses the dialog AND marks
//     the world as celebrated (so the same world never re-triggers).
//
// Reuses the existing `MagicCard`, `PrimaryButton`, `ConfettiBurst`,
// and `AppGradients` so the dialog stays inside the design system.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/world_unlock/first_unlock_service.dart';
import '../../../../core/state/player_state.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_shape.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/confetti_burst.dart';
import '../../../../core/widgets/magic_card.dart';
import '../../../../core/widgets/primary_button.dart';

/// Convenience entry point — shows the celebration for [worldId] if
/// the player has not yet seen it. Returns the [Future] that
/// completes when the dialog is dismissed (true if the celebration
/// was shown, false if the player had already seen it).
Future<bool> showFirstUnlockDialog(
  BuildContext context, {
  required String worldId,
  required String worldTitle,
  required String worldGlyph,
}) async {
  final PlayerState player = context.read<PlayerState>();
  if (!FirstUnlockService.isUncelebrated(player, worldId)) {
    return false;
  }
  AnalyticsService.instance.trackEvent(
    'world_first_unlock_shown',
    <String, Object?>{'id': worldId},
  );
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext ctx) => _FirstUnlockDialog(
      worldId: worldId,
      worldTitle: worldTitle,
      worldGlyph: worldGlyph,
    ),
  );
  return true;
}

class _FirstUnlockDialog extends StatelessWidget {
  const _FirstUnlockDialog({
    required this.worldId,
    required this.worldTitle,
    required this.worldGlyph,
  });

  final String worldId;
  final String worldTitle;
  final String worldGlyph;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              // The dialog card. The confetti sits ABOVE the card
              // (overflow = visible) so the ring spreads beyond the
              // rounded silhouette.
              _buildCard(context),
              // Confetti ring — only mounts when motion is enabled.
              if (!_reduceMotion(context))
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ConfettiBurst(
                      seed: 0xC0FFEE,
                      count: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _reduceMotion(BuildContext context) {
    return context.read<SettingsState>().reduceMotion;
  }

  Widget _buildCard(BuildContext context) {
    final PlayerState player = context.read<PlayerState>();
    return MagicCard(
      skin: MagicCardSkin.accent,
      elevation: AppElevation.z3,
      borderColor: AppColors.tangerine,
      borderRadius: AppCorner.brLg,
      padding: AppSpacing.cardPaddingGenerous,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Small "NEW" eyebrow chip.
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.tangerine,
                borderRadius: AppCorner.brSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'NEW',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.cloudWhite,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.vGapLg,
          // Big illustration glyph.
          Center(
            child: Text(
              worldGlyph,
              style: const TextStyle(fontSize: 84),
            ),
          ),
          AppSpacing.vGapMd,
          Text(
            'You unlocked $worldTitle!',
            textAlign: TextAlign.center,
            style: AppTypography.titleLg.copyWith(
              color: AppColors.deepInk,
            ),
          ),
          AppSpacing.vGapSm,
          Text(
            'A whole new world is ready to colour. Earn 3 stars '
            'to claim a special reward.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.smoke,
            ),
          ),
          AppSpacing.vGapLg,
          PrimaryButton(
            label: 'Awesome!',
            fullWidth: true,
            gradient: AppGradients.playNow,
            onPressed: () {
              Haptics.success();
              FirstUnlockService.markCelebrated(player, worldId);
              AnalyticsService.instance.trackEvent(
                'world_first_unlock_dismissed',
                <String, Object?>{'id': worldId},
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
