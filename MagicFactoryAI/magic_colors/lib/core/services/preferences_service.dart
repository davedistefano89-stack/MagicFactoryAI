// =============================================================================
// Magic Colors · core/services/preferences_service.dart
// =============================================================================
//
// Typed wrapper around `SharedPreferences`. Provides synchronous getters
// (data is loaded once at startup) and async setters (writes flush to
// platform preferences on every call). Used as a backing store by
// `SettingsState` — the constructor takes a fully-loaded instance so the
// `ChangeNotifier` can hydrate synchronously.
//
// Persistence contract: every setter returns a `Future<void>` that
// resolves once the platform write has been flushed. We DO NOT swallow
// errors here — `SettingsState` already wraps them with a try/on Object
// catch.
// =============================================================================

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

// ── Preference key constants ──────────────────────────────────────────────

const String _kLocaleKey = 'pref.locale';
const String _kSoundOnKey = 'pref.sound';
const String _kMusicOnKey = 'pref.music';
const String _kHapticsOnKey = 'pref.haptics';
const String _kReduceMotionKey = 'pref.reduceMotion';
const String _kThemeModeKey = 'pref.themeMode';

// ── Defaults ──────────────────────────────────────────────────────────────

/// Defaults are duplicated here and in `SettingsState` so the service can
/// be used stand-alone (e.g. inside a widget test without the full state
/// layer wired up). Keep in sync; any divergence is a bug.
const Locale _defaultLocale = Locale('en');
const ThemeMode _defaultThemeMode = ThemeMode.system;
const bool _kDefaultSoundOn = true;
const bool _kDefaultMusicOn = true;
const bool _kDefaultHapticsOn = true;
const bool _kDefaultReduceMotion = false;

// =============================================================================
//  PreferencesService — typed accessor facade.
// =============================================================================

final class PreferencesService {
  PreferencesService._(this._prefs);

  /// Awaits `SharedPreferences.getInstance()` and wraps it.
  static Future<PreferencesService> load() async {
    logger.info('PreferencesService.load → SharedPreferences.getInstance');
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService._(prefs);
  }

  final SharedPreferences _prefs;

  /// Raw `SharedPreferences` for callers that want direct key access
  /// (e.g. `SettingsState.fromPrefs`, which still operates in raw-key
  /// mode to keep its own storage schema self-contained). Not for use
  /// outside the foundation wiring path.
  SharedPreferences get raw => _prefs;

  // ── Read-only accessors ──────────────────────────────────────────────
  /// `null` means "follow system locale".
  Locale? get locale {
    final tag = _prefs.getString(_kLocaleKey);
    return tag == null ? _defaultLocale : Locale(tag);
  }

  bool get soundOn => _prefs.getBool(_kSoundOnKey) ?? _kDefaultSoundOn;
  bool get musicOn => _prefs.getBool(_kMusicOnKey) ?? _kDefaultMusicOn;
  bool get hapticsOn => _prefs.getBool(_kHapticsOnKey) ?? _kDefaultHapticsOn;
  bool get reduceMotion =>
      _prefs.getBool(_kReduceMotionKey) ?? _kDefaultReduceMotion;

  ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeModeKey);
    return raw == null ? _defaultThemeMode : _themeModeFromString(raw);
  }

  // ── Async setters (each returns a future that resolves on flush) ───
  Future<void> setLocale(Locale? value) async {
    if (value == null) {
      await _prefs.remove(_kLocaleKey);
      return;
    }
    await _prefs.setString(_kLocaleKey, value.toLanguageTag());
  }

  Future<void> setSoundOn(bool value) => _prefs.setBool(_kSoundOnKey, value);
  Future<void> setMusicOn(bool value) => _prefs.setBool(_kMusicOnKey, value);
  Future<void> setHapticsOn(bool value) =>
      _prefs.setBool(_kHapticsOnKey, value);
  Future<void> setReduceMotion(bool value) =>
      _prefs.setBool(_kReduceMotionKey, value);

  Future<void> setThemeMode(ThemeMode value) =>
      _prefs.setString(_kThemeModeKey, _themeModeToString(value));

  // ── Maintenance ──────────────────────────────────────────────────────
  /// Re-reads the underlying SharedPreferences. Lets Parents Area override
  /// a value via deep-link without bouncing the app.
  Future<void> reload() async {
    await _prefs.reload();
    logger.info('PreferencesService.reload');
  }

  // ── ThemeMode round-trip parser (no built-in encoder) ──────────────
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
