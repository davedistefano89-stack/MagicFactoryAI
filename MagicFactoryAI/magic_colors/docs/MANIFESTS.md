# Magic Colors — Manifests

Single source of truth for asset handoffs to art, audio, and animation vendors.

All paths are relative to `magic_colors/`. Files not yet shipped are marked `[pending]` — UI degrades gracefully when they are missing.

---

## 1. Sounds (`assets/sfx/`)

| File | Duration | Format | Trigger | License | Fallback |
|---|---|---|---|---|---|
| `button_tap.mp3` | 0.10 s | 44.1 kHz mono | generic secondary button tap | in-house | UI tap silent |
| `button_tap_big.mp3` | 0.14 s | 44.1 kHz mono | Shop card press | in-house | `button_tap.mp3` |
| `reward_chime.mp3` | 1.20 s | 44.1 kHz stereo | rewards tab open | in-house + library: `chime_03.wav` from freesound.org (CC0) | UI silent |
| `chest_open.mp3` | 1.50 s | 44.1 kHz stereo | daily reward claim | in-house | UI silent |
| `coin_collect.mp3` | 0.30 s | 44.1 kHz mono | coin awarded | in-house | UI silent |
| `gem_collect.mp3` | 0.35 s | 44.1 kHz stereo | gem awarded | in-house | UI silent |
| `drawing_complete.mp3` | 2.10 s | 44.1 kHz stereo | coloring page complete (Sprint 2) | in-house | UI silent |
| `magic_sparkle.mp3` | 0.80 s | 44.1 kHz stereo | sparkle / premium accent | in-house | UI silent |
| `play_button_special.mp3` | 0.90 s | 44.1 kHz stereo | PLAY NOW tap | in-house | `magic_sparkle.mp3` |
| `daily_reward_alert.mp3` | 1.10 s | 44.1 kHz stereo | notification bell tap | in-house | `reward_chime.mp3` |

Mastering target: **-6 dB RMS** so sitting alongside the music track never clips.

---

## 2. Fonts (`assets/fonts/`)

| File | Family | Weights | Source |
|---|---|---|---|
| `Baloo2-Regular.ttf` | Baloo 2 | 400 | Google Fonts (SIL OFL) |
| `Baloo2-Bold.ttf`     | Baloo 2 | 700 | Google Fonts (SIL OFL) |
| `Baloo2-ExtraBold.ttf`| Baloo 2 | 800 | Google Fonts (SIL OFL) |
| `Nunito-Regular.ttf`   | Nunito  | 400 | Google Fonts (SIL OFL) |
| `Nunito-Bold.ttf`      | Nunito  | 700 | Google Fonts (SIL OFL) |

`pubspec.yaml` declares the families. `google_fonts` package mirrors these at runtime if the bundled TTFs are removed (fallback path).

---

## 3. Images (`assets/images/`)

The home screen ships without raster images. Sprint 2 onward will use this folder for:

| File | Use |
|---|---|
| `mascot_proud.png` `[pending]` | alt mascot pose for "Daily Streak" celebration |
| `world_thumb_*.png` `[pending]` | Worlds screen thumbnails |
| `drawing_area_preview.png` `[pending]` | tutorial overlay |
| `premium_banner.png` `[pending]` | subscription upsell backplate |

---

## 4. Animations (`assets/lottie/`)

Home screen uses **CustomPaint-only** animations (no Lottie ships in Sprint 1). Sprint 2 onward reserved:

| File | Trigger | Fallback |
|---|---|---|
| `chest_open.json` `[pending]` | reward claim (currently CustomPaint chest — kept as upgrade path) | live chest painter already in `daily_event_card.dart` |
| `mascot_celebrate.json` `[pending]` | 5-day streak celebration | breathing scale already in `mascot.dart` |
| `starfield_loop.json` `[pending]` | Galaxy world background | `AnimatedSkyBackground` |

When a Lottie file lands, prefer it for the chest + mascot celebrate so first-party art can drive fine detail beyond CustomPaint.

---

## 5. Audio fade rules

| Trigger | fadeIn | fadeOut | duckDuring |
|---|---|---|---|
| Button tap (small) | 0 | 60 ms | never |
| Reward chime | 100 ms | 400 ms | never |
| Chest open | 200 ms | 600 ms | background music -3 db |
| Play button | 80 ms | 200 ms | never |

Background music (Sprint 2): cheerful 60–80 BPM loop, 4 min, ducked -12 dB during voice-overs.
