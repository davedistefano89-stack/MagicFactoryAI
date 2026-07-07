// =============================================================================
// Magic Colors · core/services/sound_service.dart
// =============================================================================
//
// Wraps the `audioplayers` package with a hot-path-safe sound-effect
// pipeline. Conceptually two halves:
//
//   1. SFX pool — every MagicSound has a small `AudioPool` (4 concurrent
//      players by default) pre-loaded with an OGG asset. Multiple rapid
//      taps (the user is 3 years old, after all) never starve the
//      pool — the longest ring is the 4th queued instance, which costs
//      a single frame.
//   2. Music loop — one dedicated `AudioPlayer` running on `ReleaseMode.loop`
//      so world background music threads seamlessly.
//
// `preload()` is invoked from `lib/main.dart` once on boot. The audio
// decoder is async; the splash screen reads `AppState.assetsReady` (set
// when preload completes) before swapping to Home.
//
// Re-entrancy: every `play(...)` call is idempotent against a tap-storm —
// the AudioPool's internal queue handles it. `startMusic(...)` refuses
// when a track is already playing (deferring to the caller rather than
// truncating an in-flight loop).
// =============================================================================

import 'dart:collection';

import 'package:audioplayers/audioplayers.dart'
    show AssetSource, AudioPlayer, AudioPool, ReleaseMode;

import '../utils/logger.dart';

// ── MagicSound — short effects from docs/design_system/09 §2 ───────────

/// One-shot sound effects, exposed through [SoundService.play].
enum MagicSound {
  bigTap, // button bounce
  magicSparkle, // reward counter / coin pickup
  reward, // chest open / world unlock
  coin, // separate from magicSparkle — distinct cue
  gem, // gem pickup
  paint, // brush stroke on canvas
  victory, // drawing completion
  notif, // notification bubble appear
  // M2.3 PRODUCTION — widget-layer aliases added to back the call
  // sites in features/home/widgets/ (currency_hud, secondary_button,
  // play_now_button) that predate the M2.1 sound-pool refactor.
  rewardChime, // short reward ping (pop-up card subtle layer)
  buttonTapBig, // explicit name for primary CTA tap
  buttonTap, // smaller button tap (secondary button + chips)
  dailyRewardAlert, // home-screen daily coin alert popup
}

// ── MagicMusic — looping world themes ───────────────────────────────────

/// Background music tracks, one per world + one for Home + one for Splash.
enum MagicMusic {
  splashTheme,
  homeTheme,
  unicornValley,
  animalForest,
  dinosaurIsland,
  dragonMountain,
  mermaidOcean,
  spacePlanet,
  christmasVillage,
  halloweenWorld,
  fantasyLand,
}

// ── Asset-path helpers ───────────────────────────────────────────────────

String _soundAssetPath(MagicSound s) {
  switch (s) {
    case MagicSound.bigTap:
      return 'audio/sfx/big_tap.ogg';
    case MagicSound.magicSparkle:
      return 'audio/sfx/magic_sparkle.ogg';
    case MagicSound.reward:
      return 'audio/sfx/reward.ogg';
    case MagicSound.coin:
      return 'audio/sfx/coin.ogg';
    case MagicSound.gem:
      return 'audio/sfx/gem.ogg';
    case MagicSound.paint:
      return 'audio/sfx/paint.ogg';
    case MagicSound.victory:
      return 'audio/sfx/victory.ogg';
    case MagicSound.notif:
      return 'audio/sfx/notif.ogg';
    case MagicSound.rewardChime:
      // M2.3 PRODUCTION — short reward ping. Aliases the legacy
      // `rewardChime` sound that the design bible calls for on
      // Pop-Up card subtle layer; placeholder until the audio
      // designer drops the final OGG.
      return 'audio/sfx/reward_chime.ogg';
    case MagicSound.buttonTapBig:
      // Same audio source as bigTap — both surface the primary
      // CTA bounce; primary prefix is the legacy name.
      return 'audio/sfx/big_tap.ogg';
    case MagicSound.buttonTap:
      // Smaller button tap (secondary + chips); distinct cue.
      return 'audio/sfx/button_tap.ogg';
    case MagicSound.dailyRewardAlert:
      // Home-screen daily coin alert popup. Designer's bespoke
      // cue; placeholder mirrors the notif color tint.
      return 'audio/sfx/daily_reward_alert.ogg';
  }
}

String _musicAssetPath(MagicMusic m) {
  switch (m) {
    case MagicMusic.splashTheme:
      return 'audio/music/splash_theme.ogg';
    case MagicMusic.homeTheme:
      return 'audio/music/home_theme.ogg';
    case MagicMusic.unicornValley:
      return 'audio/music/unicorn_valley.ogg';
    case MagicMusic.animalForest:
      return 'audio/music/animal_forest.ogg';
    case MagicMusic.dinosaurIsland:
      return 'audio/music/dinosaur_island.ogg';
    case MagicMusic.dragonMountain:
      return 'audio/music/dragon_mountain.ogg';
    case MagicMusic.mermaidOcean:
      return 'audio/music/mermaid_ocean.ogg';
    case MagicMusic.spacePlanet:
      return 'audio/music/space_planet.ogg';
    case MagicMusic.christmasVillage:
      return 'audio/music/christmas_village.ogg';
    case MagicMusic.halloweenWorld:
      return 'audio/music/halloween_world.ogg';
    case MagicMusic.fantasyLand:
      return 'audio/music/fantasy_land.ogg';
  }
}

// =============================================================================
//  SoundService — the public facade.
// =============================================================================

final class SoundService {
  SoundService._();

  /// Default maximum concurrent players per SFX pool. Small enough that
  /// memory stays < 1 MB total per effect (4 × 16 KB OGG frames).
  static const int _poolMaxPlayers = 4;

  bool _ready = false;
  final Map<MagicSound, AudioPool> _sfxPools = <MagicSound, AudioPool>{};

  AudioPlayer? _musicPlayer;
  MagicMusic? _currentMusic;

  /// True once [preload] has finished. The App shell watches this so
  /// Splash can swap to Home only after every audio source is hot.
  bool get ready => _ready;

  /// Currently-playing music track, or null if stopped.
  MagicMusic? get currentMusic => _currentMusic;

  // ── Bootstrap ──────────────────────────────────────────────────────────
  /// Static factory used by `lib/main.dart`. Constructs a [SoundService]
  /// and awaits its instance [preload] — collapsing the two-step
  /// "construct + warm pools" sequence into a single await that mirrors
  /// `StorageService.bootstrap` / `PreferencesService.load`. The base
  /// instance [preload] method stays public for tests that want to
  /// construct the service without warming the pool.
  static Future<SoundService> preload() async {
    final svc = SoundService._();
    await svc._warmPools();
    return svc;
  }

  /// Pre-creates every pool (one async resolve per MagicSound) and primes
  /// the dedicated music player on `ReleaseMode.loop`. Errors that occur
  /// mid-bootstrap are swallowed (logged) so a missing OGG file does not
  /// block the splash transition.
  Future<void> _warmPools() async {
    logger.info('SoundService.preload → ${MagicSound.values.length} SFX + '
        '${MagicMusic.values.length} music');

    for (final sound in MagicSound.values) {
      try {
        final pool = await AudioPool.create(
          source: AssetSource(_soundAssetPath(sound)),
          maxPlayers: _poolMaxPlayers,
        );
        _sfxPools[sound] = pool;
      } on Object catch (error, stack) {
        logger.error(
          'SoundService.preload failed for ${sound.name}',
          error: error,
          stackTrace: stack,
        );
      }
    }

    try {
      _musicPlayer = AudioPlayer();
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
    } on Object catch (error, stack) {
      logger.error(
        'SoundService.preload failed for music player',
        error: error,
        stackTrace: stack,
      );
    }

    _ready = true;
    logger.info('SoundService.preload complete → ready=true');
  }

  // ── SFX playback ──────────────────────────────────────────────────────
  /// Plays a one-shot SFX. Refuses if [preload] hasn't completed so a
  /// tap that lands mid-cold-start doesn't crash on a missing pool.
  Future<void> play(MagicSound sound) async {
    if (!_ready) {
      return;
    }
    final pool = _sfxPools[sound];
    if (pool == null) {
      logger.warn('SoundService.play called for unloaded pool: ${sound.name}');
      return;
    }
    try {
      await pool.start();
    } on Object catch (error, stack) {
      logger.error(
        'SoundService.play failed for ${sound.name}',
        error: error,
        stackTrace: stack,
      );
    }
  }

  // ── Music playback ────────────────────────────────────────────────────
  /// Starts looping the given magic music track. Calling this with the
  /// already-current track is a no-op (so a React-style "tap repeatedly"
  /// effect doesn't re-decode the buffer). Calling it with a different
  /// track first stops the previous loop.
  Future<void> startMusic(MagicMusic music) async {
    if (!_ready) {
      return;
    }
    if (_currentMusic == music && _musicPlayer != null) {
      return;
    }
    _currentMusic = music;
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.play(AssetSource(_musicAssetPath(music)));
      logger.info('SoundService.startMusic = ${music.name}');
    } on Object catch (error, stack) {
      logger.error(
        'SoundService.startMusic failed for ${music.name}',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Stops the current music loop. Safe to call when nothing is playing.
  Future<void> stopMusic() async {
    if (_currentMusic == null) {
      return;
    }
    _currentMusic = null;
    try {
      await _musicPlayer?.stop();
      logger.info('SoundService.stopMusic');
    } on Object catch (error, stack) {
      logger.error('SoundService.stopMusic failed',
          error: error, stackTrace: stack);
    }
  }

  // ── Maintenance ──────────────────────────────────────────────────────
  /// Tears down every pool + the music player. Called from
  /// `lib/app.dart.dispose()` ONLY at process exit (e.g. integration-test
  /// teardown, parent-area "Sign out + clear storage" flow).
  Future<void> dispose() async {
    logger.warn('SoundService.dispose → releasing all pools');
    for (final pool in _sfxPools.values) {
      try {
        await pool.dispose();
      } on Object catch (error, stack) {
        logger.error('pool dispose failed', error: error, stackTrace: stack);
      }
    }
    _sfxPools.clear();
    try {
      await _musicPlayer?.dispose();
    } on Object catch (error, stack) {
      logger.error('music dispose failed', error: error, stackTrace: stack);
    }
    _musicPlayer = null;
    _ready = false;
  }

  /// Read-only snapshot of the loaded-pool set, used by the Settings
  /// screen to show "X of Y sound banks loaded".
  UnmodifiableSetView<MagicSound> get loadedSounds =>
      UnmodifiableSetView(_sfxPools.keys.toSet());
}
