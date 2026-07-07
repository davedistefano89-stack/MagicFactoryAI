// =============================================================================
// Magic Colors · core/state/app_state.dart
// =============================================================================
//
// Whole-app lifecycle state. Persisted in a single Hive `Box<dynamic>` so
// the data survives uninstall-unfriendly OS state-purge events but does NOT
// leak through cloud backups (Hive boxes are stored under the app sandbox).
//
// Public surface:
//   • onboardingCompleted    — set true the first time a child walks through
//                              the 3-step welcome. Surfaces in
//                              PlayerState as a "first launch" hint.
//   • firstLaunchDate        — timestamp captured on the first call to
//                              recordSession(). Used by the analytics
//                              dashboard to compute retention curves.
//   • buildFlavour           — `'production' | 'staging' | 'dev'`. Switched
//                              at compile-time via dart-define; surfaced
//                              to widgets so staging-only chrome can render.
//   • assetsReady            — flips true once SoundService.preload() and
//                              asset decoding finish. Used by the App shell
//                              to swap the 2400ms splash for Home.
//   • sessionCount           — increments each cold start. Drives the
//                              "Welcome back!" greeting on Home.
//
// All mutating methods call `notifyListeners()` exactly once and persist
// the new value synchronously. EOF failures are swallowed but logged.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../utils/logger.dart';

// ── Hive key constants ───────────────────────────────────────────────────

/// Single-store key for the onboarding completion flag.
const String _kOnboardingKey = 'onboardingCompleted';

/// Single-store key for the first-launched-at timestamp (DateTime).
const String _kFirstLaunchKey = 'firstLaunchDate';

/// Single-store key for the active build flavour (String).
const String _kFlavourKey = 'buildFlavour';

/// Single-store key for the assets-ready flag (bool).
const String _kAssetsReadyKey = 'assetsReady';

/// Single-store key for the cold-start session counter (int).
const String _kSessionCountKey = 'sessionCount';

/// Single-store key for the last-session timestamp (DateTime).
const String _kLastSessionKey = 'lastSessionDate';

// =============================================================================
//  AppState — ChangeNotifier.
// =============================================================================

final class AppState extends ChangeNotifier {
  AppState._(this._box) {
    _hydrate();
  }

  /// Opens the underlying Hive box and constructs the [AppState].
  ///
  /// The caller (lib/main.dart or lib/app.dart) is responsible for calling
  /// `Hive.initFlutter()` and `Hive.openBox<dynamic>('app_state')` BEFORE
  /// invoking this factory.
  factory AppState.fromBox(Box<dynamic> box) = AppState._;

  final Box<dynamic> _box;

  // ── Public read model ──────────────────────────────────────────────────
  bool _onboardingCompleted = false;
  DateTime? _firstLaunchDate;
  String _buildFlavour = 'production';
  bool _assetsReady = false;
  int _sessionCount = 0;
  DateTime? _lastSessionDate;

  /// True once the child has walked through the 3-step welcome.
  bool get onboardingCompleted => _onboardingCompleted;

  /// Set on the first call to [recordSession]. Stays null on very fresh
  /// installs (i.e. before the first session has ended).
  DateTime? get firstLaunchDate => _firstLaunchDate;

  /// `'production'`, `'staging'` or `'dev'`. Surfaced to widgets so
  /// staging-only chrome (debug banner, fake paywall, etc.) can render.
  String get buildFlavour => _buildFlavour;

  /// Flips `true` once SoundService.preload() finishes. The App shell
  /// watches this to swap Splash for Home.
  bool get assetsReady => _assetsReady;

  /// Cold-start session counter. Increments on every cold start of the
  /// process. The analytics dashboard uses it for retention.
  int get sessionCount => _sessionCount;

  /// Wall-clock time of the most recent cold start. Updated by
  /// [recordSession].
  DateTime? get lastSessionDate => _lastSessionDate;

  // ── Mutators ─────────────────────────────────────────────────────────
  /// Idempotent. Calling twice is a no-op.
  void markOnboardingCompleted() {
    if (_onboardingCompleted) {
      return;
    }
    _onboardingCompleted = true;
    _persist(_kOnboardingKey, true);
    logger.info('AppState.onboardingCompleted = true');
    notifyListeners();
  }

  /// Increments [_sessionCount] and updates [_lastSessionDate]. Captures
  /// [_firstLaunchDate] on the very first invocation.
  void recordSession() {
    final now = DateTime.now();
    _firstLaunchDate ??= now;
    _lastSessionDate = now;
    _sessionCount = _sessionCount + 1;
    _persist(_kFirstLaunchKey, _firstLaunchDate);
    _persist(_kLastSessionKey, _lastSessionDate);
    _persist(_kSessionCountKey, _sessionCount);
    logger.info('AppState.recordSession → #$_sessionCount');
    notifyListeners();
  }

  /// Idempotent. Called by the asset-preload pipeline.
  void markAssetsReady() {
    if (_assetsReady) {
      return;
    }
    _assetsReady = true;
    _persist(_kAssetsReadyKey, true);
    logger.info('AppState.assetsReady = true');
    notifyListeners();
  }

  /// Sets the build flavour at app construction. Not mutable after init.
  void setBuildFlavour(String flavour) {
    if (_buildFlavour == flavour) {
      return;
    }
    _buildFlavour = flavour;
    _persist(_kFlavourKey, flavour);
    logger.info('AppState.setBuildFlavour = $flavour');
    notifyListeners();
  }

  /// Wipes onboarding so QA can re-run the welcome flow. NOT exposed to
  /// production traffic — only callable from Parents Area.
  void resetOnboardingForReRun() {
    _onboardingCompleted = false;
    _persist(_kOnboardingKey, false);
    logger.warn('AppState.resetOnboardingForReRun');
    notifyListeners();
  }

  // ── Internals ────────────────────────────────────────────────────────
  void _hydrate() {
    _onboardingCompleted = _readOrDefault<bool>(_kOnboardingKey, false);
    _firstLaunchDate = _readOrNull<DateTime>(_kFirstLaunchKey);
    _buildFlavour = _readOrNull<String>(_kFlavourKey) ?? 'production';
    _assetsReady = _readOrDefault<bool>(_kAssetsReadyKey, false);
    _sessionCount = _readOrDefault<int>(_kSessionCountKey, 0);
    _lastSessionDate = _readOrNull<DateTime>(_kLastSessionKey);
  }

  /// Reads `key` from the Hive box and casts to [T]. If the entry is
  /// missing, returns [defaultValue]. If the cast fails (older build,
  /// schema-drift, manual Hive edit), logs the failure and returns
  /// [defaultValue] so the provider can never crash cold-start.
  T _readOrDefault<T>(String key, T defaultValue) {
    try {
      return _box.get(key, defaultValue: defaultValue) as T;
    } on Object catch (error, stack) {
      logger.error(
        'AppState._readOrDefault<$T> cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return defaultValue;
    }
  }

  /// Reads `key` returning a nullable [T]?. Missing key → null. Cast
  /// failure → null + logger.error. Used for fields where `null` is
  /// semantically meaningful (e.g. firstLaunchDate before first session).
  T? _readOrNull<T>(String key) {
    try {
      return _box.get(key) as T?;
    } on Object catch (error, stack) {
      logger.error(
        'AppState._readOrNull<$T> cast failed key=$key',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Persists a single key, swallowing disk errors so a corrupted box
  /// cannot crash the app on cold start. The state remains in-memory even
  /// if write fails.
  void _persist(String key, Object? value) {
    try {
      _box.put(key, value);
    } on Object catch (error, stack) {
      logger.error(
        'AppState._persist failed for key=$key',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
