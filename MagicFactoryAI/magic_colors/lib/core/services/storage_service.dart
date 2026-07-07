// =============================================================================
// Magic Colors · core/services/storage_service.dart
// =============================================================================
//
// Hive-backed persistent storage. Owns the lifecycle of three long-lived
// `Box<dynamic>` instances:
//
//   ▸ appState box   — onboarding flags, session counter, build flavour
//                      (consumed by AppState).
//   ▸ player box     — coins, gems, premium entitlement, owned worlds,
//                      avatar, streak (consumed by PlayerState).
//   ▸ drawings box   — saved artwork (consumed by Gallery feature; reserved
//                      for Sprint 4).
//
// The service is a static-ish facade: it has no internal state to mutate.
// Callers obtain a fully-initialised instance via `StorageService.bootstrap`,
// then pass the typed box getters into the relevant `*State.fromBox(...)`
// factories.
//
// `app_state` and `player` must be opened before either `AppState.fromBox`
// or `PlayerState.fromBox` is invoked. `drawings` is optional and only
// required by the gallery feature once Sprint 4 lands.
// =============================================================================

import 'package:hive_flutter/hive_flutter.dart';

import '../utils/logger.dart';
import '../../features/coloring/data/coloring_adapters.dart'
    show registerColoringAdapters;

// ── Hive box-name constants (referenced from core/state/* for keys) ───────

/// Hive box for AppState data. Mirrored here as a constant so other
/// services (e.g. migration tooling, telemetry) can refer to the same id.
const String _kAppStateBox = 'app_state';

/// Hive box for PlayerState data.
const String _kPlayerBox = 'player';

/// Hive box for saved drawings (Sprint 4).
const String _kDrawingsBox = 'drawings';

// =============================================================================
//  StorageService — static facade for Hive + box accessors.
// =============================================================================

final class StorageService {
  StorageService._(this._appBox, this._playerBox, this._drawingsBox);

  /// Bootstraps Hive on the device document directory, opens every box
  /// the foundation needs, and returns a fully-initialised service.
  ///
  /// Called ONCE from `lib/main.dart` BEFORE constructing the providers.
  /// Subsequent calls (after a hot-restart) are safe but wasteful — the
  /// service has no internal mutable state, so re-bootstrap just re-opens
  /// the boxes.
  static Future<StorageService> bootstrap() async {
    await Hive.initFlutter('magic_colors');
    logger.info(
        'StorageService.bootstrap → registering adapters + opening 3 Hive boxes');

    // Register the coloring feature's Hive adapters BEFORE the first
    // openBox call so the box-side serializer fully understands Drawing
    // and DrawingStroke on first read. Idempotent — safe to call across
    // hot-restarts.
    registerColoringAdapters();

    final appBox = await Hive.openBox<dynamic>(_kAppStateBox);
    logger.info('  ▸ app_box opened: _kAppState=$_kAppStateBox');

    final playerBox = await Hive.openBox<dynamic>(_kPlayerBox);
    logger.info('  ▸ player_box opened: _kPlayer=$_kPlayerBox');

    final drawingsBox = await Hive.openBox<dynamic>(_kDrawingsBox);
    logger.info('  ▸ drawings_box opened: _kDrawings=$_kDrawingsBox');

    return StorageService._(appBox, playerBox, drawingsBox);
  }

  final Box<dynamic> _appBox;
  final Box<dynamic> _playerBox;
  final Box<dynamic> _drawingsBox;

  /// Box consumed by `AppState.fromBox(...)`.
  Box<dynamic> get appBox => _appBox;

  /// Box consumed by `PlayerState.fromBox(...)`.
  Box<dynamic> get playerBox => _playerBox;

  /// Box reserved for Sprint 4 gallery persistence. Already opened so the
  /// first frame after foundation wiring doesn't pay the open-latency.
  Box<dynamic> get drawingsBox => _drawingsBox;

  /// Total number of boxed keys across the three boxes. Surfaced for QA
  /// diagnostics (Settings → Storage Info).
  int get totalKeyCount =>
      _appBox.length + _playerBox.length + _drawingsBox.length;

  /// Closes every Hive box. Called from `lib/app.dart.dispose()` ONLY when
  /// the process is truly done (debug "hot quit" button, integration
  /// tests). Calling this in production crashes the Provider tree → DO
  /// NOT call from normal app lifecycle.
  Future<void> close() async {
    logger.warn('StorageService.close → closing all Hive boxes');
    await _appBox.close();
    await _playerBox.close();
    await _drawingsBox.close();
  }
}
