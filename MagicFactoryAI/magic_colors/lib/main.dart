// =============================================================================
// Magic Colors · lib/main.dart
// =============================================================================
//
// Application bootstrap. Order matters:
//
//   1. `WidgetsFlutterBinding.ensureInitialized()` — required because we
//      `await` before `runApp`.
//   2. Lock orientation preferences.
//   3. Bootstrap the three persistent services (Hive boxes, pref keys,
//      audio pools). Storage MUST come before state construction.
//   4. Construct the 4 ChangeNotifiers from those services.
//   5. Stamp the build flavour + record the cold-start session.
//   6. Hand the assembled services + state to `MagicColorsApp`.
//
// Anything that depends on an in-memory service (e.g. NavState) is built
// after step 3; everything that depends on a persistent service is built
// after step 4 — keeping the dependency graph linear and obvious.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:magic_colors/app.dart';
import 'package:magic_colors/core/services/analytics_service.dart';
import 'package:magic_colors/core/services/preferences_service.dart';
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/services/storage_service.dart';
import 'package:magic_colors/core/state/app_state.dart';
import 'package:magic_colors/core/state/navigation_state.dart';
import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/core/state/settings_state.dart';
import 'package:magic_colors/core/theme/app_theme.dart' show AppTheme;
import 'package:magic_colors/core/utils/logger.dart';

/// Build-time flavour. Wired via `--dart-define=FLAVOUR=staging`.
///
/// `production` is the default so a missing dart-define falls back to
/// production chrome (no debug banner, no fake paywall, no dev-only menu).
const String _kBuildFlavour = String.fromEnvironment(
  'FLAVOUR',
  defaultValue: 'production',
);

/// Application entry point.
///
/// Async because [StorageService]/[PreferencesService]/[SoundService] each
/// perform native-side IO before the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.info('main() → bootstrap start');

  // ── 1. Orientation lock ────────────────────────────────────────────────
  // Phones lock to portrait; the responsive layer detects a tablet and
  // lifts this restriction on screen-size-class `medium` +. Here we
  // simply allow landscape so the chrome doesn't break mid-fold.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ── 2. Bootstrap three core services in a deterministic order ───────
  // Storage first (Hive) — AppState + PlayerState await opened boxes.
  // Preferences + Sound can run sequentially after.
  final StorageService storage = await StorageService.bootstrap();
  final PreferencesService prefs = await PreferencesService.load();
  final SoundService sound = await SoundService.preload();
  logger.info('main() → 3 core services ready');

  // ── 3. Construct the 4 ChangeNotifiers ───────────────────────────────
  final AppState appState = AppState.fromBox(storage.appBox);
  final SettingsState settingsState = SettingsState.fromPrefs(prefs.raw);
  final PlayerState playerState = PlayerState.fromBox(storage.playerBox);
  final NavigationState navigationState = NavigationState();
  logger.info('main() → 4 ChangeNotifiers constructed');

  // ── 4. Stamp cold-start bookkeeping ───────────────────────────────────
  appState.setBuildFlavour(_kBuildFlavour);
  appState.recordSession();
  logger.info('main() → flavour=$_kBuildFlavour, session++');

  // ── 5. Default system UI overlay style ────────────────────────────────
  // The AppBarTheme takes over as soon as the first frame paints, so this
  // initial value only shows during the very first cold-start frame.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);

  // ── 6. Analytics ──────────────────────────────────────────────────────
  // Stubbed today; real impl lands in M5 (RevenueCat + Sentry surface).
  AnalyticsService.instance.trackSessionStart();

  // ── 7. Hand off to the root widget ─────────────────────────────────────
  logger.info('main() → runApp(MagicColorsApp)');
  runApp(MagicColorsApp(
    storage: storage,
    prefs: prefs,
    sound: sound,
    appState: appState,
    settingsState: settingsState,
    playerState: playerState,
    navigationState: navigationState,
  ));
}
