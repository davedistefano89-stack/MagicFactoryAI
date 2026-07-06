// =============================================================================
// Magic Colors · core/state/settings_state.dart
// =============================================================================
//
// Per-app preferences. Backed by SharedPreferences (the few tiny flags
// that don't justify a Hive schema). Initialised once at startup; every
// mutation persists synchronously and fires a single notifyListeners.
//
// Fields:
//   • locale       — Locale('en') or system fallback. Switchable from
//                    Settings → Language. Default = system.
//   • soundOn      — Tap sounds / boost sounds. Default true.
//   • musicOn      — World background music loops. Default true.
//   • hapticsOn    — Light taptic on tap. Default true.
//   • reduceMotion — Honours OS-level "Reduce Motion". When true, every
//                    AnimationController shortens to a 60 ms mono-fade and
//                    the mascot stops breathing.
//   • themeMode    — ThemeMode.system / .light / .dark. Default system.
//
// Operations are idempotent (no spurious notifyListeners when the value
// is already set).
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

// ── SharedPreferences key constants ─────────────────────────────────────

const String _kLocaleKey = 'pref.locale';
const String _kSoundOnKey = 'pref.sound';
const String _kMusicOnKey = 'pref.music';
const String _kHapticsOnKey = 'pref.haptics';
const String _kReduceMotionKey = 'pref.reduceMotion';
const String _kThemeModeKey = 'pref.themeMode';

// =============================================================================
//  SettingsState — ChangeNotifier.
// =============================================================================

final class SettingsState extends ChangeNotifier {
  SettingsState._(this._prefs) {
    _hydrate();
  }

  /// Construct from a pre-loaded [SharedPreferences] instance. The caller
  /// (lib/main.dart) is responsible for awaiting
  /// `SharedPreferences.getInstance()` BEFORE invoking this factory.
  factory SettingsState.fromPrefs(SharedPreferences prefs) = SettingsState._;

  /// Test-only factory that bypasses [SharedPreferences] entirely. The
  /// isolate-wide `SharedPreferences.getInstance()` singleton is pollutable
  /// by earlier tests in `flutter test --concurrency=1`, so any widget
  /// test that depends on `reduceMotion` (e.g. [OutlinePulse] short-circuit)
  /// MUST construct the settings object through this factory. All
  /// mutators in this instance are no-op for persistence — the in-memory
  /// field flips and `notifyListeners()` fire, but the underlying prefs
  /// store is never touched.
  ///
  /// NOTE: only `reduceMotion` is overridable here. The other fields
  /// (`soundOn`, `musicOn`, `hapticsOn`, `themeMode`, `locale`) keep the
  /// production defaults — pass an explicit future param if a widget
  /// under test branches on them.
  @visibleForTesting
  factory SettingsState.forTest({bool reduceMotion = true}) =>
      SettingsState._forTest(reduceMotion: reduceMotion);

  // Forwarding-body factory (intentionally NOT a redirecting-factory):
  // Dart disallows default parameter values on redirecting factories
  // when the target uses defaults, which would force every test author
  // to spell the parameter at every call site.
  SettingsState._forTest({bool reduceMotion = true}) : _prefs = null {
    _reduceMotion = reduceMotion;
  }

  /// Backing store. `null` for `_forTest` instances. All persist guards
  /// check this so a forTest instance never reads/writes the disk.
  final SharedPreferences? _prefs;

  // ── Defaults ──────────────────────────────────────────────────────────
  static const Locale _defaultLocale = Locale('en');
  static const ThemeMode _defaultThemeMode = ThemeMode.system;
  static const bool _defaultSoundOn = true;
  static const bool _defaultMusicOn = true;
  static const bool _defaultHapticsOn = true;
  static const bool _defaultReduceMotion = false;

  // ── Public read model ──────────────────────────────────────────────────
  Locale? _locale = _defaultLocale;
  bool _soundOn = _defaultSoundOn;
  bool _musicOn = _defaultMusicOn;
  bool _hapticsOn = _defaultHapticsOn;
  bool _reduceMotion = _defaultReduceMotion;
  ThemeMode _themeMode = _defaultThemeMode;

  /// `null` means "follow system locale". MaterialApp respects this.
  Locale? get locale => _locale;

  /// Whether to play tap / reward / coin sounds.
  bool get soundOn => _soundOn;

  /// Whether to play world background music.
  bool get musicOn => _musicOn;

  /// Whether to produce haptic feedback on tap.
  bool get hapticsOn => _hapticsOn;

  /// True forces every AnimationController to skip long curves and short
  /// the mascot breathing animation. Honoured by
  /// `core/widgets/animated_background.dart`.
  bool get reduceMotion => _reduceMotion;

  /// User-chosen ThemeMode override. Default is `system`.
  ThemeMode get themeMode => _themeMode;

  // ── Mutators ─────────────────────────────────────────────────────────
  /// Pass `null` to follow the system locale.
  void setLocale(Locale? locale) {
    if (_locale == locale) {
      return;
    }
    _locale = locale;
    _persistString(_kLocaleKey, locale?.toLanguageTag());
    logger.info('SettingsState.setLocale = $locale');
    notifyListeners();
  }

  void toggleSound() => setSoundOn(!_soundOn);
  void toggleMusic() => setMusicOn(!_musicOn);
  void toggleHaptics() => setHapticsOn(!_hapticsOn);
  void toggleReduceMotion() => setReduceMotion(!_reduceMotion);

  void setSoundOn(bool value) {
    if (_soundOn == value) {
      return;
    }
    _soundOn = value;
    _persistBool(_kSoundOnKey, value);
    logger.info('SettingsState.soundOn = $value');
    notifyListeners();
  }

  void setMusicOn(bool value) {
    if (_musicOn == value) {
      return;
    }
    _musicOn = value;
    _persistBool(_kMusicOnKey, value);
    logger.info('SettingsState.musicOn = $value');
    notifyListeners();
  }

  void setHapticsOn(bool value) {
    if (_hapticsOn == value) {
      return;
    }
    _hapticsOn = value;
    _persistBool(_kHapticsOnKey, value);
    logger.info('SettingsState.hapticsOn = $value');
    notifyListeners();
  }

  void setReduceMotion(bool value) {
    if (_reduceMotion == value) {
      return;
    }
    _reduceMotion = value;
    _persistBool(_kReduceMotionKey, value);
    logger.info('SettingsState.reduceMotion = $value');
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    _persistString(_kThemeModeKey, _themeModeToString(value));
    logger.info('SettingsState.themeMode = $value');
    notifyListeners();
  }

  // ── Convenience selector: derive MaterialApp themeMode ──────────────
  /// The theme mode to plug into `MaterialApp.themeMode`. Identical to
  /// [themeMode]; exposed as a dedicated getter so consumers don't need to
  /// reach into SettingsState from two places.
  ThemeMode get resolvedThemeMode => _themeMode;

  // ── Internals ────────────────────────────────────────────────────────
  void _hydrate() {
    final SharedPreferences? p = _prefs;
    if (p == null) {
      // forTest instance — fields keep constructor-set defaults.
      return;
    }
    final locTag = p.getString(_kLocaleKey);
    _locale = locTag == null ? _defaultLocale : Locale(locTag);
    _soundOn = p.getBool(_kSoundOnKey) ?? _defaultSoundOn;
    _musicOn = p.getBool(_kMusicOnKey) ?? _defaultMusicOn;
    _hapticsOn = p.getBool(_kHapticsOnKey) ?? _defaultHapticsOn;
    _reduceMotion = p.getBool(_kReduceMotionKey) ?? _defaultReduceMotion;
    final themeStr = p.getString(_kThemeModeKey);
    _themeMode =
        themeStr == null ? _defaultThemeMode : _themeModeFromString(themeStr);
  }

  /// Re-reads the underlying SharedPreferences. Lets Parents Area override
  /// a value via deep-link without bouncing the app.
  ///
  /// `forTest` instances: no `_prefs` backing store, so `reload` is a
  /// pure in-memory refresh. We still fire `notifyListeners()` so any
  /// watcher re-evaluates against the (unchanged) defaults.
  Future<void> reload() async {
    final SharedPreferences? p = _prefs;
    if (p != null) {
      await p.reload();
    }
    _hydrate();
    notifyListeners();
  }

  void _persistString(String key, String? value) {
    final SharedPreferences? p = _prefs;
    if (p == null) return; // forTest instance — pure in-memory.
    try {
      if (value == null) {
        p.remove(key);
      } else {
        p.setString(key, value);
      }
    } on Object catch (error, stack) {
      logger.error(
        'SettingsState._persistString failed key=$key',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void _persistBool(String key, bool value) {
    final SharedPreferences? p = _prefs;
    if (p == null) return; // forTest instance — pure in-memory.
    try {
      p.setBool(key, value);
    } on Object catch (error, stack) {
      logger.error(
        'SettingsState._persistBool failed key=$key',
        error: error,
        stackTrace: stack,
      );
    }
  }

  // ── ThemeMode serialisation (no built-in encoder) ───────────────────
  static String _themeModeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode _themeModeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
