// =============================================================================
// Magic Colors · features/settings/presentation/settings_screen.dart
// =============================================================================
//
// The Settings page (full-screen overlay). Dual-purpose: child-facing
// preferences (sound, haptics, language) on top, and the Parent Area
// (screen-time limits, analytics opt-out, account management) below a
// PIN gate at the bottom.
//
//   ▸ Sound toggle     — mute/unmute all SFX.
//   ▸ Haptics toggle   — enable/disable vibration feedback.
//   ▸ Music toggle     — background music on/off.
//   ▸ Language picker  — 🇬🇧 🇮🇹 🇫🇷 🇩🇪 🇪🇸 (Sprint 3).
//   ▸ Parent Area      — 🔒 PIN-gated section (Sprint 3).
//   ▸ About            — version + build info.
//
// DESIGN TOKENS
//   Colour palette, spacing, and typography strictly follow the
//   `AppColors` / `AppSpacing` / `AppTypography` token catalogue.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/state/settings_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/animated_background.dart';
import '../../../core/widgets/magic_card.dart';
import '../../../core/widgets/parent_gate.dart';

// ── Tuning constants ──────────────────────────────────────────────────

const String _kSemanticsLabel = 'Settings screen';

const String _kAppVersion = '1.0.0 (build 42)';

// =============================================================================
//  SettingsScreen — the public widget.
// =============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// M2.4 — true once the ParentGate math challenge (or hold shortcut)
  /// has been passed this session. Unlocks the parent-only settings
  /// section (screen time, analytics, account). Resets on dispose.
  bool _parentGatePassed = false;

  @override
  Widget build(BuildContext context) {
    final SettingsState settings = context.watch<SettingsState>();

    return AnimatedBackground(
      child: SafeArea(
        child: Semantics(
          label: _kSemanticsLabel,
          container: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Header ──────────────────────────────────────
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('⚙️ Settings', style: AppTypography.titleLg),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.smoke),
                    ),
                  ],
                ),
                AppSpacing.vGapLg,

                // ── Sound & haptics ─────────────────────────────
                Text('🎵 Sound & Feedback', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                _ToggleRow(
                  icon: '🔊',
                  label: 'Sound Effects',
                  value: settings.soundOn,
                  onChanged: settings.setSoundOn,
                ),
                _ToggleRow(
                  icon: '📳',
                  label: 'Haptic Feedback',
                  value: settings.hapticsOn,
                  onChanged: settings.setHapticsOn,
                ),
                _ToggleRow(
                  icon: '🎶',
                  label: 'Background Music',
                  value: settings.musicOn,
                  onChanged: settings.setMusicOn,
                ),
                AppSpacing.vGapLg,

                // ── Display ─────────────────────────────────────
                Text('🖥️ Display', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                _ToggleRow(
                  icon: '✨',
                  label: 'Reduced Motion',
                  value: settings.reduceMotion,
                  onChanged: settings.setReduceMotion,
                ),
                AppSpacing.vGapLg,

                // ── Language ────────────────────────────────────
                Text('🌐 Language', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                _LanguageCard(
                    currentLocale: settings.locale?.languageCode ?? 'en'),
                AppSpacing.vGapLg,

                // ── Parent Area ─────────────────────────────────
                Text('👨‍👩‍👧 Parent Area', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                _ParentGateCard(onTap: () => _onParentGate(context)),
                AppSpacing.vGapLg,

                // M2.4 — parent-only settings revealed after gate pass.
                if (_parentGatePassed) ...<Widget>[
                  Text('⏱️ Screen Time', style: AppTypography.titleSm),
                  AppSpacing.vGapMd,
                  const _InfoCard(
                    icon: '⏰',
                    label: 'Daily Limit',
                    value: 'Coming in Sprint 3',
                  ),
                  AppSpacing.vGapLg,
                  Text('📊 Analytics', style: AppTypography.titleSm),
                  AppSpacing.vGapMd,
                  const _InfoCard(
                    icon: '📈',
                    label: 'Usage Analytics',
                    value: 'Opt-out in Sprint 3',
                  ),
                  AppSpacing.vGapLg,
                  Text('👤 Account', style: AppTypography.titleSm),
                  AppSpacing.vGapMd,
                  const _InfoCard(
                    icon: '👶',
                    label: 'Child Profile',
                    value: 'Manage in Sprint 3',
                  ),
                  AppSpacing.vGapLg,
                ],

                // ── About ───────────────────────────────────────
                Text('ℹ️ About', style: AppTypography.titleSm),
                AppSpacing.vGapMd,
                const _AboutCard(),
                AppSpacing.vGapXl,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onParentGate(BuildContext context) async {
    AnalyticsService.instance.trackEvent('settings_parent_gate_tapped');
    Haptics.medium();
    final bool? passed = await showParentGate(context);
    if (passed == true && mounted) {
      setState(() => _parentGatePassed = true);
      Haptics.success();
    }
  }
}

// =============================================================================
//  Widgets.
// =============================================================================

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: MagicCard(
        skin: MagicCardSkin.tinted,
        borderRadius: AppCorner.brMd,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.md,
        ),
        borderColor: AppColors.hairlineLight,
        child: Row(
          children: <Widget>[
            Text(icon, style: const TextStyle(fontSize: 24)),
            AppSpacing.hGapMd,
            Expanded(child: Text(label, style: AppTypography.bodyMedium)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.magicPurple,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.currentLocale});

  final String currentLocale;

  static const List<Map<String, String>> _languages = <Map<String, String>>[
    {'code': 'en', 'flag': '🇬🇧', 'name': 'English'},
    {'code': 'it', 'flag': '🇮🇹', 'name': 'Italiano'},
    {'code': 'fr', 'flag': '🇫🇷', 'name': 'Français'},
    {'code': 'de', 'flag': '🇩🇪', 'name': 'Deutsch'},
    {'code': 'es', 'flag': '🇪🇸', 'name': 'Español'},
  ];

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.brMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.hairlineLight,
      child: Column(
        children: _languages.map((lang) {
          final bool isSelected = lang['code'] == currentLocale;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Material(
              color: isSelected
                  ? AppColors.magicPurple.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: AppCorner.brSm,
              child: InkWell(
                borderRadius: AppCorner.brSm,
                onTap: () {
                  Haptics.selection();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '🌐 Language switching ships in Sprint 3',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Text(
                          lang['name']!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isSelected
                                ? AppColors.magicPurple
                                : AppColors.deepInk,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.magicPurple,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ParentGateCard extends StatelessWidget {
  const _ParentGateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MagicCard(
        skin: MagicCardSkin.tinted,
        borderRadius: AppCorner.brMd,
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: AppColors.magicPurple.withValues(alpha: 0.2),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.magicPurple.withValues(alpha: 0.1),
                borderRadius: AppCorner.brSm,
              ),
              child: const Center(
                child: Text('🔒', style: TextStyle(fontSize: 24)),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                'Screen Time, Analytics & Account',
                style: AppTypography.bodyMedium,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.smoke),
          ],
        ),
      ),
    );
  }
}

/// M2.4 — read-only info card for parent settings placeholders.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.brMd,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      borderColor: AppColors.hairlineLight,
      child: Row(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 24)),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(label, style: AppTypography.bodyMedium),
          ),
          Text(
            value,
            style: AppTypography.caption(color: AppColors.smoke),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      skin: MagicCardSkin.tinted,
      borderRadius: AppCorner.brMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: AppColors.hairlineLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🪄', style: TextStyle(fontSize: 24)),
              AppSpacing.hGapSm,
              Text('Magic Colors', style: AppTypography.titleSm),
            ],
          ),
          AppSpacing.vGapSm,
          Text(
            _kAppVersion,
            style: AppTypography.caption(),
          ),
          AppSpacing.vGapSm,
          Text(
            'Made with ❤️ for kids aged 3–8.\nNo ads, no trackers, no dark patterns.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.smoke,
            ),
          ),
        ],
      ),
    );
  }
}
