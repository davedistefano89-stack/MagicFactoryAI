// SoundService — typed wrapper over `audioplayers` exposed to the UI.
//
// Why a custom wrapper: we want a single, auditable place that defines every
// sound effect the home screen uses, the volume tier it lives on, and the
// "play and forget" semantics that match a kid's tap cadence (no listener
// leaks, no overlapping playback fatigue).
//
// Failure mode: missing audio assets log a warning but never crash the UI.
// This keeps development friction-free when the audio folder is empty.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Named sound effects in the home screen sound catalog.
///
/// Add new entries here whenever the design system introduces a new SFX.
enum MagicSound {
  buttonTap('sfx/button_tap.mp3'),
  buttonTapBig('sfx/button_tap_big.mp3'),
  rewardChime('sfx/reward_chime.mp3'),
  chestOpen('sfx/chest_open.mp3'),
  coinCollect('sfx/coin_collect.mp3'),
  gemCollect('sfx/gem_collect.mp3'),
  drawingComplete('sfx/drawing_complete.mp3'),
  magicSparkle('sfx/magic_sparkle.mp3'),
  playButtonSpecial('sfx/play_button_special.mp3'),
  dailyRewardAlert('sfx/daily_reward_alert.mp3');

  const MagicSound(this.assetPath);
  final String assetPath;
}

/// Singleton-feel service exposing typed `play(MagicSound)` calls.
///
/// Injected via Provider at app boot (see `app.dart`). Used by interactive
/// widgets that need quick audio feedback (buttons, rewards, chest).
class SoundService extends ChangeNotifier {
  final Map<MagicSound, AudioPlayer> _players = <MagicSound, AudioPlayer>{};
  bool _muted = false;

  bool get muted => _muted;

  /// Pre-warm every player so the first user tap has zero audible latency.
  Future<void> preload() async {
    for (final sfx in MagicSound.values) {
      try {
        final player = AudioPlayer(playerId: 'magic_colors_${sfx.name}');
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(_volumeFor(sfx));
        // Pre-set the source — `setSource` loads the asset into the decoder.
        try {
          await player.setSource(AssetSource(sfx.assetPath));
        } on Exception catch (_) {
          // Asset missing is acceptable in dev; logged below.
          developer.log(
            'Sound asset missing for ${sfx.name}: ${sfx.assetPath}',
            name: 'SoundService',
          );
        }
        _players[sfx] = player;
      } on Exception catch (e, st) {
        developer.log(
          'Failed to initialize AudioPlayer for ${sfx.name}',
          name: 'SoundService',
          error: e,
          stackTrace: st,
        );
      }
    }
    notifyListeners();
  }

  /// Plays a sound effect. Safe to call repeatedly and from any isolate that
  /// has access to the root widget tree.
  Future<void> play(MagicSound sfx) async {
    if (_muted) return;
    final player = _players[sfx];
    if (player == null) return;
    try {
      await player.stop();
      await player.resume();
    } on Exception catch (err) {
      developer.log('Failed to play ${sfx.name}',
          name: 'SoundService', error: err);
    }
  }

  /// Toggle the global mute (used by the Parents gate and Settings → Audio).
  Future<void> setMuted(bool value) async {
    _muted = value;
    for (final player in _players.values) {
      await player.setVolume(value ? 0.0 : 1.0);
    }
    notifyListeners();
  }

  double _volumeFor(MagicSound sfx) {
    // Magic sparkle, gems, rewards are accent layers — keep them under the
    // primary tap and chest sounds so they don't fatigue the listener.
    switch (sfx) {
      case MagicSound.buttonTap:
      case MagicSound.buttonTapBig:
      case MagicSound.playButtonSpecial:
        return 0.95;
      case MagicSound.chestOpen:
      case MagicSound.dailyRewardAlert:
        return 0.85;
      case MagicSound.coinCollect:
      case MagicSound.gemCollect:
        return 0.8;
      case MagicSound.rewardChime:
      case MagicSound.drawingComplete:
        return 0.75;
      case MagicSound.magicSparkle:
        return 0.55;
    }
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
    super.dispose();
  }
}
