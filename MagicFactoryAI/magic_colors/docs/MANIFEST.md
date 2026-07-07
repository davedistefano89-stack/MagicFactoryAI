# Magic Colors — Asset Manifest

This file is the contract between pixel-pushers and the codebase. Every asset
referenced by the runtime exists either as a real file under `magic_colors/`
or as a runtime fallback.

> All paths are relative to `magic_colors/`.

---

## Fonts

Loaded at runtime through `google_fonts` (no binaries ship by default).
Sprint 1 will fall back gracefully if the device is offline.

| Family | Weights | Source | License |
|---|---|---|---|
| Baloo 2 | 400 / 700 / 800 | Google Fonts CDN | SIL OFL |
| Nunito  | 400 / 700      | Google Fonts CDN | SIL OFL |

## Sounds

| File | Trigger | Mastering | Fallback |
|---|---|---|---|
| `assets/sfx/button_tap.mp3` | Secondary cards | -6 dB RMS | UI silent |
| `assets/sfx/button_tap_big.mp3` | Shop card | -6 dB RMS | `button_tap.mp3` |
| `assets/sfx/reward_chime.mp3` | Rewards tab open | -6 dB RMS | UI silent |
| `assets/sfx/chest_open.mp3` | Daily reward claim | -6 dB RMS | UI silent |
| `assets/sfx/coin_collect.mp3` | Coin awarded | -6 dB RMS | UI silent |
| `assets/sfx/gem_collect.mp3` | Gem awarded | -6 dB RMS | UI silent |
| `assets/sfx/drawing_complete.mp3` | Coloring page done (Sprint 2) | -6 dB RMS | UI silent |
| `assets/sfx/magic_sparkle.mp3` | Premium / sparkle | -6 dB RMS | UI silent |
| `assets/sfx/play_button_special.mp3` | PLAY NOW | -6 dB RMS | `magic_sparkle.mp3` |
| `assets/sfx/daily_reward_alert.mp3` | Reward bell | -6 dB RMS | `reward_chime.mp3` |

Runtime contract: if a file is missing, `SoundService.play` logs at debug
level and silently no-ops. UI never crashes.

## Images

Sprint 1 needs none. Sprint 2 reserves:

| File | Use |
|---|---|
| `assets/images/mascot_proud.png` | streak celebration pose |
| `assets/images/world_thumb_*.png` | Worlds screen thumbnails |
| `assets/images/premium_banner.png` | subscription upsell |

## Animations (Lottie)

Sprint 1 uses only CustomPaint animations. Lottie is reserved for upgrades:

| File | Trigger | Fallback |
|---|---|---|
| `assets/lottie/chest_open.json` | reward claim | live chest painter in `daily_event_card.dart` |
| `assets/lottie/mascot_celebrate.json` | 5-day streak | breathing scale already in `mascot.dart` |

## Screen sizes (responsive)

Sprint 1 layout breakpoints (`lib/core/utils/responsive.dart`):

- Compact (≤ 480 dp) — 2-column secondary grid.
- Medium (≤ 720 dp) — 4-column secondary grid.
- Expanded (> 720 dp) — 4-column + larger mascot.

## Density

Layouts use logical pixels (`MediaQuery.devicePixelRatio`) — all assets are
expected at 2x and 3x. No raster assets ship in Sprint 1, so density is
irrelevant for visuals; layout sizes scale with dp.

## Theme readiness

- Both `light` and `dark` `ColorScheme` produced from the seed color
  `#7B5BFF`. Background paint in `AnimatedSkyBackground` is theme-aware:
  dark uses deep violet-blue, light uses the sky gradient.

## Missing-asset graceful degradation

Each effect/sound/image referenced in code is checked at startup. If a
resource is missing:

1. `SoundService` logs at `developer.log` severity `'INFO'`.
2. UI continues to draw.
3. Button-press animations and haptic feedback still fire.
4. A banner in Settings → Audio surfaces the missing catalog to the dev
   build (Sprint 2 wires this).

This ensures the QA tester never sees a hard crash on a clean checkout.
