# 12 — Magic Colors · Asset List
**Document:** Official Asset Library Manifest v1.0
**Audience:** Artists, engineers, QA, ops
**Status:** v1.0 baseline

---

## 1. Asset Pipeline Overview

```
WAV/SVG/PNG (master) → review → QC pass          → Convert (per-platform)
                                                                  ↓
                                                   iOS: Asset Catalog
                                                   Android: Asset Studio
                                                   Web: PNG/WebP/SVG
```

Every asset has:

- **Master**: source-of-truth file (PSD, AI, OGG, WAV).
- **Source**: machine-friendly format (PNG, SVG, OGG Vorbis).
- **Derived**: per-platform sizes.
- **License & ownership**: Creative Director-approved.

## 2. Asset Categories (9 total)

```
A — Logo & Brand
B — Mascot
C — UI Icons
D — Buttons & Cards
E — World Illustrations
F — Coloring Page Templates
G — Stickers & Stamps
H — Audio (voice/music/SFX)
I — Particles / Effects
J — Fonts & Typography Assets
```

## 3. A — Logo & Brand

| Asset | Master | Source | Sizes | Owner |
|---|---|---|---|---|
| Logo Hero (rainbow) | logomaster_hero.ai | logomaster_hero.svg | 256, 512, 1024 | Designer |
| Logo Compact | logomaster_sm.ai | logomaster_sm.svg | 96, 192, 384 | Designer |
| Logo Monochrome (white) | logomaster_monoW.ai | logomaster_monoW.svg, .png | 256, 512 | Designer |
| Logo Mask | logomaster_mask.ai | logomaster_mask.png | 1024 | Designer |
| Tagline | tagline_v1.svg | (vector text) | any | Designer |

Total bytes (compressed bundled): < 800 KB.

## 4. B — Mascot

| Asset | Source | Format | Sizes | Status |
|---|---|---|---|---|
| Pixel mascot — happy | `lib/core/widgets/mascot.dart` (CustomPaint) | runtime | any | ✅ Sprint 1 |
| Pixel mascot — excited | (future Rive) | .riv | 1024 | 🚧 Sprint 3 |
| Pixel mascot — sleeping | (future Rive) | .riv | 1024 | 🚧 Sprint 3 |
| Pixel mascot — painting | (future Rive) | .riv | 1024 | 🚧 Sprint 3 |
| Pixel mascot — wave | (future Rive) | .riv | 1024 | 🚧 Sprint 3 |
| Pixel mascot — sad | (future Rive) | .riv | 1024 | 🚧 Sprint 4 |
| Pixel — sprite sheet | pixel_sprites_v1.png | PNG | 1024 × 1024 (4×4 grid) | 🚧 Sprint 3 |
| Pixel — Lottie | pixel_v1.json | Lottie | variable | 🚧 Sprint 3 |

Hard rules: 1 kebab-case name only. Pixel is THE mascot. Other mascot variants are costumes.

## 5. C — UI Icons (per `07_ICON_SYSTEM.md`)

```
lib/core/icons/
├── coin.svg     (32, 48, 64)
├── gem.svg      (32, 48, 64)
├── star.svg     (28, 48, 64)
├── heart.svg    (28, 48, 64)
├── brush.svg    (24, 32, 48)
├── pencil.svg   (24, 32, 48)
├── bucket.svg   (24, 32, 48)
├── marker.svg   (24, 32, 48)
├── crayon.svg   (24, 32, 48)
├── glitter.svg  (24, 32, 48)
├── stamp.svg    (24, 32, 48)
└── ... (40 total)
```

Each icon master is **a single SVG**, exported to 3 PNG sizes + 1 PDF.

## 6. D — Buttons & Cards

| Component | Asset | Format | Status |
|---|---|---|---|
| PLAY NOW background | (handled by GradientCustomPaint) | runtime | ✅ Sprint 1 |
| Big tap ripple | ripple_v1.png | PNG (128 × 128), 9-patch | ✅ asset/sfx/.gitkeep ship |
| Daily Event Card bg | (animated gradient in code) | runtime | ✅ Sprint 1 |
| Card border highlight | card_highlight.png | PNG @1x, @2x, @3x | 🚧 Sprint 3 |
| World Card backgrounds | world_card_{unicorn,princess,...}.png | PNG (512×512) | 🚧 Sprint 3 |
| Reward pop-up frame | reward_frame_v1.png | PNG 9-patch | 🚧 Sprint 3 |

## 7. E — World Illustrations

Each of the 10 worlds ships:

| Asset | Format | Count |
|---|---|---|
| World cover background | PNG (2048×1536) | 1 |
| World parallax layers | PNG (2560 wide, stacked for parallax) | 3 layers |
| 40 page templates | SVG (vector pages) | 40 |
| World badge | PNG (512×512) | 1 |
| World entry jingle | OGG (4 bars mono) | 1 |
| World completion jingle | OGG (8 bars mono) | 1 |
| Music loop | OGG (~ 80 s, stereo) | 1 |
| 5 ambient SFX | OGG | 5 |

Compressed payload per world: ~ 12 MB.

## 8. F — Coloring Page Templates

Format: **SVG with layer separation**:

```svg
<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <g id="layer-1-contour">
    <path d="M ... " stroke="#000000" stroke-width="4" fill="transparent" />
  </g>
  <g id="layer-2-color-zone-a">
    <path d="M ... " fill="transparent" />
  </g>
  <g id="layer-3-color-zone-b">
    <path d="M ... " fill="transparent" />
  </g>
</svg>
```

Sprint 3 will introduce **bucket-fill-friendly zones** (closed SVG paths with proper fill semantics).

**Total pages at v1.0**: 5 free × 10 worlds = 50 starter pages + 350 unlock-as-play = 400 pages.

## 9. G — Stickers & Stamps

| Pack | Sticker count | Source | Format |
|---|---|---|---|
| Pixel pack | 24 | `lib/features/stickers/pixel_pack.json` | runtime tier-1 |
| Unicorn pack | 16 | PNG sticker sheet | 🚧 |
| Animals pack | 20 | PNG sticker sheet | 🚧 |
| Holidays pack | 16 | PNG sticker sheet | 🚧 |
| Dinosaurs pack | 16 | PNG sticker sheet | 🚧 |
| Fantasy pack | 24 | PNG sticker sheet | 🚧 |

Each sticker master: **PNG transparent**, 200 × 200 dp at @1x.

## 10. H — Audio (per `09_SOUND_GUIDE.md`)

```
assets/sfx/
├── big_tap.ogg
├── small_tap.ogg
├── tertiary_tap.ogg
├── coin.ogg
├── gem.ogg
├── star.ogg
├── reward.ogg
├── chest.ogg
├── paint.ogg
├── bucket_fill.ogg
├── busy.ogg
└── page.ogg

assets/music/
└── home_idle.ogg    (one for now per platform)

assets/music/worlds/
├── unicorn_valley.ogg
├── princess_kingdom.ogg
├── animal_forest.ogg
├── mermaid_ocean.ogg
├── space_planet.ogg
├── christmas_village.ogg
├── halloween_world.ogg
├── dinosaur_island.ogg
├── dragon_mountain.ogg
└── fantasy_land.ogg
```

Compressed target total: < 12 MB.

## 11. I — Particles / Effects

| Asset | Source | Format |
|---|---|---|
| Sparkle (4-armed) | CustomPaint in code | runtime |
| Burst confetti | CustomPaint in code | runtime |
| Cloud puffs | CustomPaint in code | runtime |
| Magic trail | CustomPaint in code | runtime |
| Loading shimmer | shimmer.ogg | OGG |
| Rainbow shimmer | CustomPaint in code | runtime |

In v1, all particles are CustomPaint-painted (no raster). Sprint 3 may introduce Lottie for splash / reward scenes.

## 12. J — Fonts & Typography Assets

| Font | Source | Format |
|---|---|---|
| Baloo 2 ExtraBold / Bold | Google Fonts (OFL) | runtime |
| Nunito 400 / 600 / 700 | Google Fonts (OFL) | runtime |
| OpenDyslexic (Parents opt) | bundled | TTF (cached locally) |
| Cairo (Arabic titles) | Google Fonts | runtime |
| Noto Naskh Arabic (Arabic body) | Google Fonts | runtime |
| M PLUS Rounded 1c (CJK titles) | Google Fonts | runtime |
| Noto Sans CJK (CJK body) | Google Fonts | runtime |

Fonts in app: balanced at ~ 5 MB net after subsetting.

## 13. Lottie & Animation

- Splash logo motion: CustomPaint (no Lottie yet).
- Reward pop-up: CustomPaint + SparkleField in v1; Lottie in v1.2.
- World entry: World-specific CustomPaint.
- Particle bursts: CustomPaint.

Lottie assets folder: `assets/lottie/` (declared in pubspec).

## 14. Asset QC Checklist

Every asset must have:

- [ ] Designer sign-off in `/design/qc/<asset>.log`
- [ ] Master on shared drive with version number
- [ ] Source in repo
- [ ] Per-platform derived files
- [ ] License verified
- [ ] Accessibility verification (text-alternate for icons, audio levels checked for SFX)
- [ ] Addressable path in `lib/`

## 15. Asset Ownership & Hashing

Each asset has a **content hash** stored in `assets_manifest.json`:

```json
{
  "version": "1.0.0",
  "assets": [
    { "path": "icons/coin.svg", "sha256": "…", "version": 1 },
    { "path": "sfx/big_tap.ogg", "sha256": "…", "version": 1 }
  ]
}
```

The app refuses to start if any local asset differs from the manifest (anti-tamper). Asset updates flow through normal versioned releases.

## 16. Bundle Size Budget

| Bundle | Target |
|---|---|
| Splash launch on cold start | < 4 MB |
| First world full delivery | < 12 MB |
| Full v1.0 ship | < 80 MB |
| Full v1.2 (all worlds + DLC) | < 200 MB |

Compression: OGG q6 for audio, SVG for vector, PNG q9 with palette for raster.

---

**Document complete. v1.0 frozen.**
