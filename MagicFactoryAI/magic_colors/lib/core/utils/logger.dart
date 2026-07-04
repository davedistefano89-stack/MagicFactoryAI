// =============================================================================
// Magic Colors · core/utils/logger.dart
// =============================================================================
//
// Tiny structured-logging helper wrapping `dart:developer.log`. The state
// layer uses this to emit `debug/info/warn/error` events without bypassing
// the DevTools console filter.
//
// Levels (numeric, matching dart:developer's Level class):
//   ▸ 500  fine / debug
//   ▸ 800  info
//   ▸ 900  warning
//   ▸ 1000 severe / error
//
// The class exposes static methods (`Logger.info(...)`) AND a top-level
// `const logger` value whose instance methods delegate 1-to-1 to the
// static surface. Both spellings reach the same DevTools sink.
//
// WHY A FACADE
//   The earlier version assigned the `Logger` *class type* to a `Logger`-
//   typed constant, generating `instance_access_to_static_member` warnings
//   on every call site. [LoggerFacade] is a stateless instance wrapper
//   that forwards every call to [Logger.X] — zero allocations per call,
//   no warnings, and `MAGIC_COLORS_LOG_LEVEL` tree-shaking still applies
//   (the static guard runs INSIDE each Logger method, before
//   `developer.log`).
//
// tree-shaking: builds with
//   `flutter build apk --dart-define=MAGIC_COLORS_LOG_LEVEL=<int>`
// (e.g. `800` for info-only, `900` for warn+, `1000` for error-only) raise
// the [Logger.currentLevel] threshold at compile time. Method bodies whose
// level is below the threshold are skipped by [Logger._isEnabled] and the
// `developer.log` invocation tree-shakes out of production AOT binaries.
// IGNORE: The dart-define value MUST be a numeric literal. Passing the
// string `info`/`warn`/`error` aliases will compile-fail.
// =============================================================================

import 'dart:developer' as developer;


// =============================================================================
//  Logger — static facade over dart:developer.log.
// =============================================================================

abstract final class Logger {
  const Logger._();

  /// Subscriber name (visible in DevTools filtering).
  static const String _name = 'magic_colors';

  /// Numerical levels (matches `dart:developer.Level` constants).
  static const int _levelDebug = 500;
  static const int _levelInfo = 800;
  static const int _levelWarn = 900;
  static const int _levelError = 1000;

  /// Active log threshold. Values whose level is ≥ [currentLevel] are
  /// emitted; everything below is dropped by the [_isEnabled] guard.
  /// Defaults to debug (500) in dev. Override per build with:
  ///
  /// ```sh
  /// flutter build apk --dart-define=MAGIC_COLORS_LOG_LEVEL=800
  /// ```
  ///
  /// (800 = info, 900 = warn, 1000 = error.)
  static const int currentLevel = int.fromEnvironment(
    'MAGIC_COLORS_LOG_LEVEL',
    defaultValue: _levelDebug,
  );

  static bool _isEnabled(int candidate) => candidate >= currentLevel;

  /// Fine-grained diagnostics off the hot path. Disabled when
  /// [currentLevel] is above debug.
  static void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled(_levelDebug)) {
      return;
    }
    developer.log(
      message,
      name: _name,
      level: _levelDebug,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Lifecycle hooks, session-start markers, intent events.
  static void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled(_levelInfo)) {
      return;
    }
    developer.log(
      message,
      name: _name,
      level: _levelInfo,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Recoverable surprises — failed spends, stale tabs, etc.
  static void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled(_levelWarn)) {
      return;
    }
    developer.log(
      message,
      name: _name,
      level: _levelWarn,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Unrecoverable error: persisted-state corruption, async-exception
  /// ruptures, anything Sentry should pick up.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled(_levelError)) {
      return;
    }
    developer.log(
      message,
      name: _name,
      level: _levelError,
      error: error,
      stackTrace: stackTrace,
    );
  }
}


// =============================================================================
//  LoggerFacade — instance-style alias for `Logger`.
// =============================================================================

/// Stateless instance facade that delegates every call to the matching
/// static [Logger] method. Constructing the facade in production costs
/// one pointer-width allocation (or zero when used as `const`); calling
/// a method is a single virtual-dispatch to the static `Logger.X`.
///
/// Why a separate class rather than instantiating [Logger]:
///   `Logger` is `abstract final` so its private constructor is
///   invokable only from within its library. Even if instantiated, the
///   resulting instance would forward to the same static methods AND
///   trigger `instance_access_to_static_member` warnings. [LoggerFacade]
///   is a non-abstract class with real instance methods, so call sites
///   read `logger.info('...')` naturally without diagnostics.
class LoggerFacade {
  const LoggerFacade();

  /// Mirror of [Logger.debug].
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      Logger.debug(
        message,
        error: error,
        stackTrace: stackTrace,
      );

  /// Mirror of [Logger.info].
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      Logger.info(
        message,
        error: error,
        stackTrace: stackTrace,
      );

  /// Mirror of [Logger.warn].
  void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      Logger.warn(
        message,
        error: error,
        stackTrace: stackTrace,
      );

  /// Mirror of [Logger.error].
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      Logger.error(
        message,
        error: error,
        stackTrace: stackTrace,
      );
}


// =============================================================================
//  Top-level convenience re-export — `logger.info(...)` syntax.
// =============================================================================

/// Top-level value used by every `logger.X(...)` call site. Marked
/// `const` because [LoggerFacade] carries zero state; the static
/// [Logger] thresholds still drive tree-shaking under
/// `MAGIC_COLORS_LOG_LEVEL`.
const LoggerFacade logger = LoggerFacade();
