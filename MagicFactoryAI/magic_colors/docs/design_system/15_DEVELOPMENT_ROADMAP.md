# 15 — Magic Colors · Development Roadmap
**Document:** Official Build Roadmap v1.0
**Audience:** Engineering, design, QA, ops, leadership
**Status:** v1.0 baseline

---

## 1. Roadmap Philosophy

Magic Colors ships in **three milestones** (M1–M3) followed by **continuous improvement**:

- **M1 (Sprint 4)**: Splash + Home + foundations shippable
- **M2 (Sprint 6)**: Worlds + Coloring core + Wave 1 ships with paid offering
- **M3 (Sprint 9)**: All 10 worlds, library, parents zone — feature-complete v1.0
- **Continuous (Sprint 10+)**: DLC waves, accessibility, localization

We aim for **1 build per week** after Sprint 4, with **2-week release cadence**.

## 2. Sprint Cadence

| Sprint | Duration | Outcome |
|---|---|---|
| 1 | 2 weeks | Splash + Home (current). Code review complete. |
| 2 | 2 weeks | Navigation + Sound + Reduced Motion + Theme stabilization |
| 3 | 2 weeks | Worlds + Coloring core + Daily Event |
| 4 | 2 weeks | M1 build (closed alpha) |
| 5 | 2 weeks | Polish + bug bash + 90 % accessibility coverage |
| 6 | 2 weeks | M2 build (open beta) |
| 7 | 2 weeks | Wave 2 worlds (Christmas/Halloween/Dino) seasonal preview |
| 8 | 2 weeks | Library + Saved work + Print-to-PDF |
| 9 | 2 weeks | M3 build (RC, then GA v1.0) |
| 10+ | rolling | Wave 3 / localization / accessibility refinements |

Total time from Sprint 1 to GA v1.0: **18 weeks**.

## 3. Milestone 1 — Foundations (Sprint 4 target)

### 3.1 Mission
Deliver the visual and audio "first 10 seconds" that **hooks** a parent and a child.

### 3.2 Objectives

- Ship Splash + Home with full visual quality.
- Establish the core token system + CustomPaint foundation.
- Wire Sound Service and reduced-motion defaults.
- Set up CI, build artifacts, and provisioning.

### 3.3 Major features

| Feature | Status per Sprint 1 |
|---|---|
| Splashed Animated Logo + Sparkle Field | ✅ |
| Splash Mascot entrance animation | ✅ |
| Home Animated Sky + Clouds + Rainbow | ✅ |
| Magic Particles field | ✅ |
| Floating stars overlay | ✅ |
| Mascot center with breath + blink | ✅ |
| PLAY NOW big button with glow pulse | ✅ |
| 5 secondary buttons (Collection, Rewards, Shop, Parents, Premium) | ✅ |
| Daily Event Card with chest burst | ✅ |
| Currency HUD (Coin + Gem) | ✅ |
| Bottom Nav (5 tabs) | ✅ |
| Material 3 theme (light + dark) | ✅ |
| Sound service + 12 canonical cues | ✅ |
| Reduced motion scaffolding | ✅ |
| Codestyle + analysis_options | ✅ |
| Asset manifest | ✅ |
| Design system docs v1.0 | ✅ (this document + 14 others) |

### 3.4 Estimated Development Time

Already invested. Remaining polish: 4 weeks.

### 3.5 Risks

| Risk | Mitigation |
|---|---|
| Wide variety of phone screens, scale-breaking layouts | Use `MediaQuery` size class; clamp text scaler; AssetManifest enforces scale-aware assets |
| Audio engine friction with mute/hardware interruptions | Sound service handles autoplay pause; tested iOS + Android |
| Child zone accidental entry to monetize | Two-step gate enforced at primitive level |
| Custom Paint perf on low-end devices | Aggressive dispose of controllers + 60 FPS profiling |

### 3.6 Dependencies

- Flutter ≥3.27 (locked).
- `google_fonts`, `provider`, `audioplayers`, `flutter_animate` packaged in `pubspec.yaml`.

### 3.7 Success Criteria

- A test device (Pixel 2 era, 60 FPS) opens the splash within 1.5 s and the home within 3 s, and remains 60 FPS for 60 s of idle.
- The five home buttons respond within 60 ms.
- Sound plays 100 ms after Play Now tap.

## 4. Milestone 2 — Worlds + Coloring core (Sprint 6 target)

### 4.1 Mission
The full **paint experience** — choose a world, color a page, save the result, and earn a reward.

### 4.2 Objectives

- Worlds navigation.
- In-game coloring screen (vector paint + bucket fill).
- Save + gallery.
- Reward pop-up sequence.
- Daily streak tracking.
- Payment integration.

### 4.3 Major features

- Worlds List screen with 10 world cards.
- World Detail screen with Page List.
- Coloring screen with full palette.
- Bucket fill with closed-path detection.
- Sticker drag-and-place.
- Save Page action + thumbnail.
- Reward Pop-up with confetti.
- Coin / gem pop animations on counter.
- Daily event timer logic + daily login pop-up.
- Premium subscription IAP integration.
- Coin pack IAP integration.
- Parents Zone (basic).

### 4.4 Estimated Development Time

8 weeks (Sprint 3 + Sprint 4 + Sprint 5 + half of Sprint 6).

### 4.5 Risks

| Risk | Mitigation |
|---|---|
| Vector paint complexity on low-end devices | Use `CustomPainter` caching + offscreen layer for the canvas |
| Multiple IAP providers diverging | Abstract via `lib/core/iap/iap_service.dart` Apple/Google/Windows |
| Child-zone accidental IAP | Two-step gate enforced |

### 4.6 Dependencies

- Apple Developer account + provisioning.
- Google Play Console account + signed APK.
- `in_app_purchase` plugin verification on each store.

### 4.7 Success Criteria

- End-to-end test: tap PLAY → choose world → color page → save → see reward → unlock next page.
- IAP flow tested on iOS devices + Android emulator.
- All Worlds 1–5 reachable from default launch.

## 5. Milestone 3 — Feature Complete (Sprint 9 target, GA v1.0)

### 5.1 Mission
Complete the v1 experience: library, parents zone, full reward system, accessibility, localization (EN + 4 core languages).

### 5.2 Objectives

- Full Library with thumbnails.
- Family albums (multi-child profiles).
- Print-to-PDF export.
- Reduced motion full coverage.
- WCAG AA pass.
- All 10 worlds shipped.
- All 12 SFX shipped.

### 5.3 Major features

- Family album (per-child gallery).
- Custom avatar per child.
- Print-to-PDF + share to parent.
- All 10 worlds accessible.
- All 12 SFX in 9-locale variants.
- Reduced motion fully functional.
- Localized copy: en, it, fr, es, de, ja.
- Tutorial overlay (1-time, dismissible).
- Achievement cards.
- 60-day polish + accessibility.

### 5.4 Estimated Development Time

12 weeks (Sprint 6 vs 7–9).

### 5.5 Risks

| Risk | Mitigation |
|---|---|
| Bundle size > 200 MB | Per-world lazy loading; manifest-driven |
| Localization regressions | Strings extraction tool + per-locale linter |
| Print-to-PDF rendering issues | `pdf` package raster fallback |

### 5.6 Dependencies

- `pdf` package.
- `image` package.
- Translation memory system.

### 5.7 Success Criteria

- All acceptance criteria pass.
- WCAG AA rating.
- 95 % Crash-free Sessions in TestFlight / Beta track.
- App launch < 3 s on Pixel 2s.

## 6. Sprint Plan (one-line summary)

| Sprint | Outcome |
|---|---|
| 1 | Splash + Home (current) |
| 2 | Sound + Navigation router |
| 3 | Worlds + Coloring core |
| 4 | M1 closed alpha |
| 5 | Polish + Accessibility pass |
| 6 | M2 open beta |
| 7 | Wave 2 worlds (seasonal) |
| 8 | Library + Print |
| 9 | M3 RC + GA v1.0 |
| 10 | Localization + Audio polish |
| 11 | Accessibility deep pass |
| 12 | v1.0.1 hotfix window |
| 13 | Performance profiling + battery audit |
| 14 | Wave 3 world dress (early prep) |
| 15 | v1.1 RC + GA |
| 16 | v1.1.x bug fixes |
| 17 | v1.2 wave-3 + Studio Brush |
| 18 | v1.2 GA |

## 7. Build Pipeline

```
feature/* → pull request → CI (lint + test + build) → main branch
                                                       ↓
                                          Weekly internal release
                                                       ↓
                                      TestFlight / Play internal track
                                                       ↓
                                            Weekly QA pass
                                                       ↓
                                       Bi-weekly public release
```

CI tasks:

- Static analysis (`flutter analyze`)
- Unit tests (target: 70 % coverage at v1.0)
- Widget tests (target: 40 % coverage at v1.0)
- Integration tests on splash/home/coloring (golden tests)
- Build verify (iOS + Android + Web)
- Asset verification (manifest hash check)
- Audio attachment check

## 8. Release Channels

| Channel | Audience | Cadence |
|---|---|---|
| `internal` | Build engineers | per merge |
| `alpha` | Internal team + 5 close testers | weekly |
| `beta` | 50 trusted parents + 50 trusted kids | bi-weekly |
| `rc` | 500 parents + 200 kids | at M3 |
| `ga` | public | at M3 + GA date |
| `lts` | select customers (locks feature surface) | quarterly |

## 9. Hotfix Path

- Critical bug → `hotfix/* → main → internal → alpha → beta → ga` within 4 h, 24 h, 48 h.
- Regression risk classification: P0 only.

## 10. Stable + LTS Designation

- **Stable:** the latest tagged `vX.Y.Z` on the public storefront.
- **LTS:** select stable tags retained 12 months for school / clinic customers who need predictable surfaces.

## 11. Continuous Improvement (Beyond v1.0)

| Initiative | v1.1 | v1.2 | v2.0 |
|---|---|---|---|
| Localization (ar, he, zh-CN, ko) | ✅ Sprint 16 | | |
| Wave 3 worlds | | ✅ Sprint 17 | |
| Tablet / iPad layout | | ✅ Sprint 18 | |
| Web companion (parents only) | | | ✅ |
| Multiplayer-friendly (NOT chat) creative collab | | | ✅ |
| Verified Creators (kids book illustrators publishing inside app) | | ✅ Phase 2 | |
| AI Brush Suggestions (premium, parent opt-in only) | | | ✅ (ethical roll-out) |

## 12. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| AI provider hallucinating | No AI in v1.0 |
| Voice/speech synthesis | Off until v2 to avoid uncanny valley |
| Personal data compliance | No analytics SDKs in child zone |
| Apple rejection for IAP issues | Strict gate + parental consent screens |
| Android targeting SDK upgrade lag | Quarterly review |

## 13. Success Metrics (GA v1.0)

| Metric | Target |
|---|---|
| Monthly active users | 250 K by month 3 |
| Subscription conversion | 4 % |
| Average session length | 14 min |
| Crash-free sessions | 99.5 % |
| App Store rating | 4.6+ |
| NPS (parents) | 50+ |

## 14. Cross-functional RACI

| Function | Engineering | Design | QA | Marketing |
|---|---|---|---|---|
| Code standard | R | C | C | I |
| Visual quality | C | R | C | I |
| Accessibility | R | C | C | I |
| Performance | R | I | C | I |
| App Store | C | R | C | R |
| Content (worlds) | C | R | I | R |

## 15. Anti-Roadmap Decision Log

| Decision | Date | Why |
|---|---|---|
| No chat / multiplayer in v1.0 | Wk 1 | Maturity risk; trust cost too high |
| No voice-over until v2 | Wk 1 | Tonality is safer, no uncanny valley for kids |
| No Lottie-heavy effects in v1.0 | Wk 1 | Performance budget too tight |
| No analytics SDK | Wk 1 | Privacy > insight |

---

**Document complete. v1.0 frozen.**
