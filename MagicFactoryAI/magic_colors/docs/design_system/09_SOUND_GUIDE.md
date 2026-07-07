# 09 — Magic Colors · Sound Guide
**Document:** Official Audio System v1.0
**Audience:** Sound designers, audio engineers, QA
**Status:** v1.0 baseline — voice-light, music-mood-driven

---

## 1. Audio Philosophy

Magic Colors is **musical, not loud**. Sound must:

1. **Reward good behavior** — every tap has a gentle cue, every success has a chime.
2. **Never punish** — no harsh notes, no alarms, no startle-buzz sounds.
3. **Be tasteful** — single-instrument pad loops, soft chimes, no overwhelming bass.
4. **Be politeness-aware** — auto-pause when a phone call arrives.
5. **Respect silence** — child can mute with a single tap.

Volume ceiling: max **-3 dBFS** peak on the master bus. Children are sensitive to high SPL.

## 2. Audio Architecture

```
[SoundSource] → [MixerBus] → [MasterBus] → [Output]
                  ↓
           [Snapshot weight + duck]
```

- **SoundSource** — a single audio file or synth. Each tap spawns one.
- **MixerBus** — groups sources (UI, Ambient, Music).
- **Snapshot** — preset mixer config per app state (Home, Gameplay, Reward).
- **Duck** — when UI sound fires, Music dips to -6 dB for 250 ms.

In Flutter: use `audioplayers` (already declared in `pubspec.yaml`) per source, or migrate to `just_audio` in Sprint 3 for finer mixer control.

## 3. The 12 Canonical Cues (v1.0)

| ID | Name | Spec | Trigger |
|---|---|---|---|
| `MagicSound.bigTap` | Big tap | Soft chime C5 + E5, 220 ms, -3 dBFS | PLAY NOW press |
| `MagicSound.smallTap` | Small tap | Single chime G4, 180 ms | Secondary button press |
| `MagicSound.tertiaryTap` | Chip tap | Soft pluck, 120 ms | Chip press |
| `MagicSound.coin` | Coin pickup | Glissando up C5 → E5 + shimmer, 320 ms | +coin event |
| `MagicSound.gem` | Gem pickup | Glass arrow tone + sparkle tail, 400 ms | +gem event |
| `MagicSound.star` | Star earned | C major triad arpeggio, 600 ms | Page 3-star achievement |
| `MagicSound.reward` | Big reward | C-G-E-C arpeggio + chime, 1200 ms | Reward pop-up appear |
| `MagicSound.chest` | Chest open | Wooden latch + sparkle ascent, 800 ms | Daily event card tap |
| `MagicSound.paint` | Stroke paint | Brush sweep (filtered noise, 220 ms) | Continuous while coloring |
| `MagicSound.bucketFill` | Fill bucket | Soft tone fall A4 → E4, 180 ms | Bucket fill on tap |
| `MagicSound.busy` | Activity | Subtle whoosh, 280 ms | Game start / scene change |
| `MagicSound.page` | Page saved | Soft pad + paper rustle, 600 ms | Saving drawing |

All files wave/synthesized at 48 kHz mono, compressed to OGG Vorbis ~ 96 kbps.

## 4. World Music Loops

| World | Style | Key | Length | Tempo |
|---|---|---|---|---|
| Unicorn Valley | Pad synth + harp | C major | 80 s | 76 BPM |
| Princess Kingdom | Pizzicato strings + glock | A major | 80 s | 80 BPM |
| Animal Forest | Acoustic guitar | D major | 80 s | 84 BPM |
| Mermaid Ocean | Marimba + soft splash | G major | 80 s | 72 BPM |
| Space Planet | Synth pad + minor motif | F major | 80 s | 70 BPM |
| Christmas Village | Jingle bells + strings | G major | 80 s | 80 BPM |
| Halloween World | Pizzicato + celesta | A minor → A major | 80 s | 76 BPM |
| Dinosaur Island | Synth didgeridoo-like | D major | 80 s | 84 BPM |
| Dragon Mountain | Strings + harp + glockenspiel | D major | 80 s | 76 BPM |
| Fantasy Land | Grand orchestral | C major | 80 s | 80 BPM |

**Music entry jingle:** 4-bar sting at world open.
**Completion jingle:** 8-bar sting at world 100 % completion.

All loops crossfade at end-of-length to avoid audible restart.

## 5. Layering Rules (mixer states)

| App state | Music | Ambient SFX | UI SFX |
|---|---|---|---|
| Splash | 80 % | 0 % | 50 % |
| Home (idle) | 60 % | 60 % | 100 % |
| Home (interacting) | 50 % (ducked by -6 dB) | 40 % | 100 % |
| Coloring | 50 % | 30 % | 100 % |
| Reward Pop-up | 80 % | 0 % | 100 % (priority) |
| Parents Area | **muted** | **muted** | 60 % |
| Locked device sleep | pause all | pause all | pause all |

## 6. Sound Service Implementation Status

- ✅ `lib/core/services/sound_service.dart` — preload + per-sound debounce + cleanup.
- ✅ All 12 v1 cues registered.
- 🚧 Per-world music loops (Sprint 3 once assets ship).

## 7. Voice Chimes (replaces voice-over)

Magic Colors v1 has **no spoken voice**. Voice replacement is by tonality:

| Cue | Tonal Message |
|---|---|
| Big tap | "Will you come play with me?" |
| Reward | "Now look what you've done!" |
| Chest open | "Surprise inside" |
| Page saved | "Done — and yours forever" |

These are **non-verbal**: chord changes carry semantic meaning, mimicking how Pixar uses music.

## 8. Volume Settings (Parents Area)

| Slider | Range | Default |
|---|---|---|
| Master | 0–100 % | 80 % |
| Music | 0–100 % | 70 % |
| Sound Effects | 0–100 % | 90 % |
| Voice | n/a | none in v1 |
| Mute | toggle | off |

Location: Parents Area → Audio → Volume.

## 9. Anti-Audio (do NOT include sounds that...)

- ❌ Mimic emergency sirens (startle + parental anxiety).
- ❌ Are real-world money sounds (ka-ching): wrong message for children.
- ❌ Are loud explosions: hearing safety.
- ❌ Are advertising jingles: not appropriate.
- ❌ Use real human voices narrating instructions.
- ❌ Mocks language: no "tsk tsk", no shame.

## 10. Hearing Health

- Master peaks: max -3 dBFS.
- Continuous SFX (paint stroke): max -8 dBFS.
- Reward pop-ups: max -3 dBFS, allowed brief.
- All audio respects iOS `AVAudioSession` category `ambient` and Android `STREAM_MUSIC`.
- All audio mutes during phone interrupts automatically.

## 11. Localization

- Sound IDs are locale-independent.
- Music loops are remix-friendly per region (Latin America: warmer larger strings; Asia: pluck-led). Ship v1 with English-region music; regionalization in v1.2.

## 12. Audio Asset Pipeline

```
WAV (24-bit, 48 kHz) → Sound designer cleanup → OGG Vorbis q6 → bundled in assets/sfx/
```

Naming: `sfx_<name>_v<N>.ogg`. Total audio payload target: < 12 MB at ship.

## 13. Sound Service Contract (canonical)

```dart
abstract class SoundService {
  Future<void> preload();
  Future<void> play(MagicSound cue, {double volume = 1.0});
  Future<void> stopAll();
  Future<void> setMasterVolume(double v); // 0..1
  Future<void> setMusicVolume(double v);
  Future<void> setEffectsVolume(double v);
  void dispose();
}
```

Implemented in `lib/core/services/sound_service.dart`. Reentrancy-safe (per the Sprint 1 code review).

---

**Document complete. v1.0 frozen.**
