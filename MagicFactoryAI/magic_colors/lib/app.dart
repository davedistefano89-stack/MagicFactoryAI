// =============================================================================
// Magic Colors · lib/app.dart
// =============================================================================
//
// Root widget materialised by `runApp(MagicColorsApp(...))` in lib/main.dart.
//
// Responsibilities:
//   ▸ Wire every Provider the rest of the app reads (services + state).
//   ▸ Materialise MaterialApp.router with the AppTheme.light/dark pair.
//   ▸ Bridge SettingsState.themeMode + .locale into MaterialApp.router
//     without rebuilding the router on every SettingsState notify
//     (Selector scopes the rebuild to actual changes).
//   ▸ Clamp the platform text-scaler so the OS accessibility slider
//     never blows up the layout math (per docs/design_system/03 §9).
//
// Two top-level widgets live here:
//   ▸ [MagicColorsApp] — public root. Accepts the assembled services +
//     state from main() and mounts the Provider tree.
//   ▸ [_MagicColorsAppShell] — private child. Owns MaterialApp.router.
//     Reuses the Provider tree above; reads SettingsState via Selector.
// =============================================================================

import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:magic_colors/core/routing/app_router.dart' show AppRouter;
import 'package:magic_colors/core/services/analytics_service.dart';
import 'package:magic_colors/core/services/preferences_service.dart';
import 'package:magic_colors/core/services/sound_service.dart';
import 'package:magic_colors/core/services/storage_service.dart';
import 'package:magic_colors/core/state/app_state.dart';
import 'package:magic_colors/core/state/navigation_state.dart';
import 'package:magic_colors/core/state/player_state.dart';
import 'package:magic_colors/core/state/settings_state.dart';
import 'package:magic_colors/core/theme/app_theme.dart';

// =============================================================================
//  MagicColorsApp — public root widget.
// =============================================================================

class MagicColorsApp extends StatelessWidget {
  const MagicColorsApp({
    super.key,
    required this.storage,
    required this.prefs,
    required this.sound,
    required this.appState,
    required this.settingsState,
    required this.playerState,
    required this.navigationState,
  });

  final StorageService storage;
  final PreferencesService prefs;
  final SoundService sound;
  final AppState appState;
  final SettingsState settingsState;
  final PlayerState playerState;
  final NavigationState navigationState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<StorageService>.value(value: storage),
        Provider<PreferencesService>.value(value: prefs),
        Provider<SoundService>.value(value: sound),
        Provider<AnalyticsService>.value(value: AnalyticsService.instance),
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<SettingsState>.value(value: settingsState),
        ChangeNotifierProvider<PlayerState>.value(value: playerState),
        ChangeNotifierProvider<NavigationState>.value(value: navigationState),
      ],
      child: const _MagicColorsAppShell(),
    );
  }
}

// =============================================================================
//  _MagicColorsAppShell — MaterialApp.router with reactive theming + locale.
// =============================================================================

class _MagicColorsAppShell extends StatelessWidget {
  const _MagicColorsAppShell();

  // M2.4 hotfix — `DefaultMaterialLocalizations.delegate` etc. are
  // lazily-constructed singletons, NOT compile-time constants. Drop
  // `const` so the static initializer evaluates at first access.
  static final List<LocalizationsDelegate<dynamic>> _localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    DefaultMaterialLocalizations.delegate,
    DefaultCupertinoLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context) {
    // Selector restricts rebuild to actual (themeMode, locale) changes —
    // toggling `soundOn` in SettingsState does NOT rebuild MaterialApp.
    return Selector<SettingsState, ({ThemeMode themeMode, Locale? locale})>(
      selector: (_, settings) => (
        themeMode: settings.themeMode,
        locale: settings.locale,
      ),
      builder: (context, snapshot, _) {
        return MaterialApp.router(
          title: 'Magic Colors',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: snapshot.themeMode,
          locale: snapshot.locale,
          localizationsDelegates: _localizationsDelegates,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            // Children under 8 never see anything but English for v1.0.
            return supportedLocales.first;
          },
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            // Clamp OS-driven text scaling into [0.85, 1.30] so layout
            // can't smear off-screen on iPhone SE or iPad Mini at 1.30.
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.30,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
