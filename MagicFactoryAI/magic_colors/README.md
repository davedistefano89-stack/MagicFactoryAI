# Magic Colors 🎨✨

> **Magic Colors — a premium children's coloring game for kids 3–8 (and the grown-ups who guide them).**
> Peaceful. Ad-free. Offline-first. Designed for tiny hands and small screens.

[![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-54C5F8?logo=flutter&logoColor=white)](https://flutter.dev)
[![Material 3](https://img.shields.io/badge/Material%203-Enabled-FF6E40)](https://m3.material.io)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20Feature--First-blueviolet)]()
[![State](https://img.shields.io/badge/State-Provider-39A2DB)](https://pub.dev/packages/provider)
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

---

## Table of Contents

1. [Project Description](#1-project-description)
2. [Architecture](#2-architecture)
3. [Folder Structure](#3-folder-structure)
4. [Dependencies](#4-dependencies)
5. [State Management](#5-state-management)
6. [Routing](#6-routing)
7. [Theme](#7-theme)
8. [Design System](#8-design-system)
9. [How to Run](#9-how-to-run)
10. [How to Build](#10-how-to-build)
11. [Future Roadmap](#11-future-roadmap)
12. [Contributing](#12-contributing)
13. [Coding Standards](#13-coding-standards)
14. [License](#14-license)
15. [Version History](#15-version-history)
16. [Requirements](#16-requirements)

---

## 1. Project Description

**Magic Colors** is a single-player, offline-first coloring experience designed from the ground up for children between **3 and 8 years old**. The game respects three hard constraints:

- **No predatory monetization.** No ads. No loot boxes. No energy timers. The only paid feature is a flat-rate Premium subscription that unlocks every world and removes nothing else.
- **Safe creative space.** Every drawing is sandboxed inside the app — no social features, no uploads, no chat, no public profile. Artwork stays on the device until the family chooses to export it.
- **Inclusive by default.** All UI is one-thumb reachable, scaled to the FAT-finger rule ≥ 48 dp, and supports system font-size, system dark mode, and a high-contrast accessibility theme.

### 1.1 Who is it for?

| Audience | What they get |
|---|---|
| **Kids 3 – 5** | Large tap targets, infinite-undo crayon, sound-on-every-tap rewards, "magic paintbrush" mascot. |
| **Kids 6 – 8** | Real coloring pages with shading, save-to-gallery, weekly world drops. |
| **Parents & Educators** | Parents Area (off by default in-game), offline-first, no tracking, no external links, COPPA / GDPR-K compliant. |

### 1.2 What the app is NOT

- ❌ Not a social network.
- ❌ Not a messenger.
- ❌ Not a real-money marketplace.
- ❌ Not a "kids' game" with hidden adult content. Every asset is family-curated.

---

## 2. Architecture

Magic Colors is built with **two complementary layering strategies**:

| Layering | Purpose | Where you see it |
|---|---|---|
| **Clean Architecture** | Dependency direction always points inward (`features → core`). | `lib/core/` (lowest), `lib/features/` (highest), `lib/shared/` (cross-cutting). |
| **Feature-First** | Files are grouped by user-facing destination, not by technical concern. | `lib/features/home/`, `lib/features/coloring/`, etc. |

The combined rule of thumb is: **a feature folder may import from `core/` and `shared/`, but never from another feature folder.** Cross-feature communication happens through Provider-singleton services (router, sound, settings, player) that live in `core/state/` and `core/services/`.

### 2.1 The five rings

```
  ┌──────────────────────────────────────────────────────────────────┐
  │  features/<destination>/                                         │  ─┐
  │  ├ screens / widgets / controllers                                │   │
  │  └ bloc / notifiers (Provider ChangeNotifier)                     │   │ Pure UI +
  ├──────────────────────────────────────────────────────────────────┤   │ business
  │  shared/                                                         │   │ rules inside
  │  ├ widgets (cross-feature: empty-state, currency HUD, ...)       │   │ a single
  │  └ mixins (a11y helpers, faded hero transitions)                 │   │ feature.
  ├──────────────────────────────────────────────────────────────────┤   │
  │  core/state/                                                     │  ─┤
  │  ├ app_state · settings_state · player_state · nav_state        │   │ Global/notifiers
  ├──────────────────────────────────────────────────────────────────┤   │
  │  core/services/                                                  │  ─┤
  │  ├ storage (Hive) · preferences (SharedPreferences) · analytics  │   │ I/O boundaries
  │  └ sound · in-app-purchase · notifications                        │   │
  ├──────────────────────────────────────────────────────────────────┤   │
  │  core/routing/  ·  core/theme/  ·  core/widgets/                 │  ─┤
  │  └ GoRouter config, Material 3 theme, design-system widgets       │   │ Pure UI
  │                                                                   │   │ primitives.
  ├──────────────────────────────────────────────────────────────────┤   │
  │  core/utils/ · core/models/                                      │   │
  │  └ responsive breakpoints, haptics, ids, value objects            │   │ Pure helpers.
  └──────────────────────────────────────────────────────────────────┘  ─┘
```

### 2.2 Why clean + feature-first?

- A new screen (`worlds/`) instantiates with zero coupling to other features.
- thA future us can spin up a "magic-colors-editor" harness by composing only `core/` modules without bringing the splash screen along.
- Designers can find any widget they designed by `search into` `core/widgets/` rather than chasing it across features.

---

## 3. Folder Structure

```
magic_colors/
├─ android/                      → Android Gradle config + signing
├─ ios/                          → Xcode workspace + Info.plist
├─ web/                          → Preview-only target (no production)
├─ linux/                        → (disabled by design — kids' tablets)
├─ macos/                        → (disabled by design — kids' tablets)
├─ windows/                      → (disabled by design — kids' tablets)
├─ test/                         → Widget + golden + integration tests
├─ integration_test/             → End-to-end smoke tests (Patrol-style)
├─ tools/                        → Asset resizer, lottie-cdn sync, l10n
│
├─ assets/
│  ├─ animations/                → Lottie JSON / dotlottie / rive
│  ├─ icons/                     → PNG @1x @2x @3x + .svg master
│  ├─ illustrations/             → Background art for screens & worlds
│  ├─ audio/                     → .ogg (Android) + .m4a (iOS), 96 kbps
│  └─ fonts/OFL/                 → Pre-licensed OFL fonts for non-Latin
│
├─ docs/
│  ├─ design_system/             → 15-document Game Design System bible
│  ├─ MANIFEST.md                → Asset ↔ code map
│  └─ ACCESSIBILITY.md           → A11y checklist & IQ test protocol
│
├─ lib/
│  ├─ main.dart                  → WidgetsFlutterBinding + runApp
│  ├─ app.dart                   → MagicColorsApp shell + provider tree
│  │
│  ├─ core/                      ─────────────────────────────────────
│  │  ├─ theme/                  → Material 3 light + dark + tokens
│  │  │   ├─ app_colors.dart
│  │  │   ├─ app_gradients.dart
│  │  │   ├─ app_typography.dart
│  │  │   ├─ app_shape.dart
│  │  │   └─ app_theme.dart
│  │  ├─ design/                 → Cross-cutting tokens
│  │  │   └─ design_tokens.dart  → spacing, radius, motion, elevation
│  │  ├─ routing/                → GoRouter
│  │  │   ├─ app_routes.dart
│  │  │   └─ app_router.dart
│  │  ├─ state/                  → Provider ChangeNotifiers
│  │  │   ├─ app_state.dart
│  │  │   ├─ settings_state.dart
│  │  │   ├─ player_state.dart
│  │  │   └─ navigation_state.dart
│  │  ├─ services/               → I/O Boundaries
│  │  │   ├─ storage_service.dart        (Hive)
│  │  │   ├─ preferences_service.dart    (SharedPreferences)
│  │  │   ├─ sound_service.dart
│  │  │   ├─ analytics_service.dart      (no-op offline-first)
│  │  │   └─ iap_service.dart            (RevenueCat bridge)
│  │  ├─ widgets/                → Reusable design-system components
│  │  │   ├─ primary_button.dart
│  │  │   ├─ secondary_button.dart
│  │  │   ├─ magic_card.dart
│  │  │   ├─ coin_counter.dart
│  │  │   ├─ gem_counter.dart
│  │  │   ├─ currency_hud.dart
│  │  │   ├─ animated_background.dart
│  │  │   ├─ floating_cloud.dart
│  │  │   ├─ magic_particles.dart
│  │  │   ├─ rainbow_header.dart
│  │  │   └─ bottom_navigation.dart
│  │  ├─ models/                 → Pure value objects (Hive-aware)
│  │  │   ├─ world.dart
│  │  │   ├─ achievement.dart
│  │  │   ├─ consumable.dart
│  │  │   ├─ unlockable.dart
│  │  │   └─ player_profile.dart
│  │  └─ utils/                  → Pure helpers
│  │      ├─ responsive.dart
│  │      ├─ haptics.dart
│  │      └─ logger.dart
│  │
│  ├─ features/                  ─────────────────────────────────────
│  │  ├─ splash/
│  │  │   ├─ splash_screen.dart
│  │  │   └─ widgets/
│  │  │       ├─ animated_logo.dart
│  │  │       ├─ sparkle_field.dart
│  │  │       └─ splash_mascot.dart
│  │  ├─ home/
│  │  │   ├─ home_screen.dart
│  │  │   ├─ home_controller.dart
│  │  │   └─ widgets/
│  │  │       ├─ animated_background.dart
│  │  │       ├─ mascot.dart
│  │  │       ├─ play_now_button.dart
│  │  │       ├─ secondary_button.dart
│  │  │       ├─ bottom_nav.dart
│  │  │       ├─ currency_hud.dart
│  │  │       └─ daily_event_card.dart
│  │  ├─ worlds/
│  │  ├─ gallery/
│  │  ├─ coloring/
│  │  ├─ rewards/
│  │  ├─ shop/
│  │  ├─ premium/
│  │  ├─ profile/
│  │  └─ settings/
│  │
│  └─ shared/                    → Cross-feature widgets & mixins
│     ├─ widgets/
│     │   ├─ empty_state.dart
│     │   ├─ loading_indicator.dart
│     │   └─ progress_bar.dart
│     └─ mixins/
│         └─ focus_traversal_mixin.dart
│
├─ pubspec.yaml                  → Manifest (Deps · Assets · Splash)
├─ analysis_options.yaml         → Strict lints (see §13)
├─ l10n.yaml                     → i18n config
├─ .metadata                     → Flutter metadata
└─ README.md                     → This file
```

---

## 4. Dependencies

The complete dependency contract lives in `pubspec.yaml`. At a glance:

### 4.1 Production

| Category | Package | Why it's there |
|---|---|---|
| State | `provider` | Tiny, REPL-friendly, taught in 100-level Flutter courses. |
| Routing | `go_router` | Declarative; supports nested shells (necessary for the bottom-nav pattern). |
| Local persistence | `hive`, `hive_flutter`, `path_provider`, `shared_preferences` | Hive for structured data (drawings, achievements, player profile), prefs for the few tiny flags. |
| Theme / Type | `google_fonts` | First-run graceful, with the option to drop OFL files when needed. |
| Animation | `lottie`, `flutter_animate` | Lottie for marker-driven worlds, `flutter_animate` for micro-interactions. |
| Audio | `audioplayers` | Pre-cache-aware; OC-friendly licensing for our 90 trimmed loops. |
| Responsive | `responsive_framework` | Reads breakpoints, scales `MediaQuery`, exposes `MaxWidthContainer`. |
| IAP | (See §10.2) | RevenueCat via Flutter — single purchase token on iOS / Android. |
| Util | `collection`, `meta`, `equatable`, `uuid`, `intl` | Standard library glue. |
| i18n | `flutter_localizations`, `intl_utils` | First-class localized strings & dynamic plurals. |

### 4.2 Dev / QA

| Package | Purpose |
|---|---|
| `flutter_lints`, `very_good_analysis`, `dart_code_metrics` | Static analysis stack (see §13). |
| `flutter_test` | Widget + golden tests. |
| `integration_test` | End-to-end smoke. |
| `build_runner`, `hive_generator`, `intl_utils` | Codegen for Hive adapters and ARB catalogs. |

---

## 5. State Management

Provider is the single, deliberate choice. We do NOT introduce Riverpod, Bloc, GetX, or Redux — three libraries would be one too many for a children's game.

| Provider | Scope | Persisted? | File |
|---|---|---|---|
| `AppState` | Whole-app lifecycle. First-run flag, build flavours, onboarding state. | Hive (`app_settings` box) | `lib/core/state/app_state.dart` |
| `SettingsState` | Sound on/off, music on/off, haptics on/off, language, reduce-motion, theme mode (system/light/dark). | SharedPreferences | `lib/core/state/settings_state.dart` |
| `PlayerState` | Coin & gem balances, premium entitlement, owned worlds, avatar. | Hive (`player` box) | `lib/core/state/player_state.dart` |
| `NavigationState` | Active bottom-nav tab, splash → home transition, deep-link routes. | None (in-memory) | `lib/core/state/navigation_state.dart` |

### 5.1 Scope rule
A feature folder may READ any state above, but only WRITES to its own `*_state.dart` if exposed explicitly. Cross-feature writes go through a service (`core/services/`) so the call stack remains grep-able.

```dart
// ✅ Allowed: world feature reads premium status.
final isPremium = context.watch<PlayerState>().isPremium;

// ❌ Not allowed: world feature directly mutates PlayerState.
Provider.of<PlayerState>(context, listen: false).addCoins(50);
// — use PlayerController.grantCoins(50) instead, which validates the call.
```

### 5.2 Conventions

- All notifiers extend `ChangeNotifier` and follow the wrap-method pattern (no `set state` directly).
- Build methods are pure (no business logic).
- Provider scoping is `MultiProvider` at the root of `app.dart`; `ProxyProvider` for derivations; `Selector` for granular rebuilds inside widgets.

---

## 6. Routing

Navigation is built on **GoRouter**. One `GoRouter` instance is constructed in `lib/core/routing/app_router.dart` and provided to the MaterialApp.router scope.

| Route | Destination | Builder |
|---|---|---|
| `/` | Animated splash | `SplashScreen` |
| `/home` | Home (default after splash) | `HomeScreen` |
| `/worlds` | World map | `WorldsScreen` |
| `/worlds/:id` | Detail (locked badge, sample pages) | `WorldsScreen` |
| `/gallery` | Saved drawings + templates | `GalleryScreen` |
| `/coloring/:id` | Coloring canvas | `ColoringScreen` |
| `/rewards` | Achievements, daily chest, streak | `RewardsScreen` |
| `/shop` | Coin & gem packs | `ShopScreen` |
| `/premium` | Subscription description | `PremiumScreen` |
| `/profile` | Player avatar, owned worlds | `ProfileScreen` |
| `/settings` | App preferences + Parents Area | `SettingsScreen` |

The bottom navigation is implemented via GoRouter's `StatefulShellRoute.indexedStack` so each tab keeps its own navigator stack and back gesture history survives the switch. See `lib/core/routing/app_router.dart`.

Deep links (`magiccolors://world/unicorn`) are wired in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`, then translated by `app_router.dart` once the plugins resolve platform URLs.

---

## 7. Theme

Material 3 is the only theme surface exposed to widgets. Variables in `lib/core/theme/app_theme.dart` compose the public `ThemeData` for both light and dark modes; the user cannot bypass the system.

### 7.1 Light vs. dark

- The app **defaults to system** (`ThemeMode.system`) so the OS-driven dynamic colors stay aligned with iOS and Android.
- The user can lock to **Light** or **Dark** from `Settings → Display`. Parents Area re-confirms the toggle with a child-locked PIN.
- All colors come from `ColorScheme.fromSeed(seedColor: AppColors.brandPurple)`, so any palette change at the seed level washes through the entire app — buttons, chips, switches, sliders, dialogs, banners, snack bars.

### 7.2 Tokens, not literals

`lib/core/theme/` exposes **named tokens** (`AppColors.brandPurple`, `AppColors.coinGold`). Widgets NEVER call `Color(0xFF…)` directly. This keeps themability localised and the magic-colors-editor harness friction-free.

---

## 8. Design System

The visual identity is documented in `docs/design_system/` — the 15-document Game Design System bible. Always consult these before touching a screen.

- `01_BRAND_GUIDE.md` — mission, voice, brand keywords.
- `02_COLOR_SYSTEM.md` — palette + gradient ramps.
- `03_TYPOGRAPHY.md` — Baloo 2 + Nunito, scale, accessibility sizes.
- `04_UI_COMPONENTS.md` — every reusable component spec.
- `05_CHARACTER_BIBLE.md` — Pixel the Painter mascot specs.
- `06_GAME_WORLDS.md` — ten worlds (Unicorn Valley → Fantasy Land).
- `07_ICON_SYSTEM.md` — every icon.
- `08_ANIMATION_GUIDE.md` — animation canon.
- `09_SOUND_GUIDE.md` — sound effects + music loops.
- `10_GAMEPLAY_FLOW.md` — player journey.
- `11_SCREEN_FLOW.md` — navigation map.
- `12_ASSET_LIST.md` — every asset, master & bundle budget.
- `13_APP_STORE_STYLE_GUIDE.md` — App Store creatives.
- `14_MONETIZATION.md` — premium, anti-dark-patterns.
- `15_DEVELOPMENT_ROADMAP.md` — release milestones.

---

## 9. How to Run

### 9.1 First-time setup

```bash
git clone <repo-url> magic_colors
cd magic_colors
flutter pub get
dart run intl_utils:generate              # ARB → generated/
dart run build_runner build --delete-conflicting-outputs
```

### 9.2 Daily development

```bash
flutter run -d <device-id>
```

If you have no physical device, start an emulator first (`flutter emulators --launch <name>`) or use Chrome for web preview (`flutter run -d chrome`).

### 9.3 Hot-restart, not hot-reload

State providers (especially `PlayerState`) hold Hive-backed singletons — prefer **hot-restart (R)** when exercising flows that read persistent state.

---

## 10. How to Build

### 10.1 Android

```bash
flutter build apk --release --split-per-abi           # 3 ABI APKs (~ 14 MB each)
flutter build appbundle --release                     # store-grade AAB
```

Sign with the keystore declared in `android/key.properties` (not committed; ask the release engineer). The store-grade AAB is uploaded via Google Play Console; the per-ABI APKs are reserved for sideloading tests.

### 10.2 iOS

```bash
flutter build ipa --release                           # archive
open ios/Runner.xcworkspace                          # for further signing
```

The provisioning profile lives in `ios/Runner.xcodeproj` and matches the bundle id `com.magiccolors.app`. TestFlight metadata is uploaded by the release engineer; the A/B feature flag values are read from `firebase_remote_config.json` at first launch.

### 10.3 Web (preview only)

```bash
flutter build web --release
```

The web target is for the design team's review environment only — no production traffic goes through it. Web-specific Material 3 quirks (e.g. tab-focus trajectories) are unit-tested in `test/web/`.

### 10.4 Continous integration

GitHub Actions runs:

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs`
3. `flutter analyze`
4. `dart run dart_code_metrics:metrics lib`
5. `flutter test`
6. `melos run integration` (Patrol-driven smoke on iOS sim + Android emu).

A green pipeline is required before any PR can land in `main`.

---

## 11. Future Roadmap

| Phase | Horizon | Highlights |
|---|---|---|
| **M1 · Foundation** | Sprint 1 (this) | Clean architecture, design tokens, theme, router, providers, reusable widgets. |
| **M2 · Vertical slice** | Sprints 2 – 4 | Splash → Home → Worlds → Coloring end-to-end with one world (Unicorn Valley). |
| **M3 · Content breadth** | Sprints 5 – 10 | Three more worlds, rewards, achievements, daily chest, save-to-gallery. |
| **M4 · Premium + IAP** | Sprints 11 – 13 | RevenueCat integration, family plan, Parents Area. |
| **M5 · Soft launch** | Sprints 14 – 16 | Localisation (12 languages), crash reporting, App Store creatives, 2-week TestFlight. |
| **M6 · GA v1.0** | Sprints 17 – 18 | 10 worlds, all metadata, store approval, ASO & launch marketing. |

Refer to `docs/design_system/15_DEVELOPMENT_ROADMAP.md` for sprint-level decomposition.

---

## 12. Contributing

The Magic Colors repo is closed-source. Internal contributors follow this flow:

1. Pick a ticket from the Linear project `Magic Colors`.
2. Branch off `main` using the convention `mc/<sprint>/<ticket>` (e.g. `mc/s1/foundation-2`).
3. Commit in atomic, reviewable units. Each commit's body explains WHY, not WHAT.
4. Open a PR. The PR template requires: story linkage, before/after screenshots (mobile + tablet), accessibility audit, and golden test diff.
5. Two reviewers are mandatory: one from UX/Design (visual fidelity) and one from the Game Logic squad (correctness).
6. CI must be green. PRs with red checks cannot be merged.
7. Squash-merge with a Conventional Commit message (`feat:`, `fix:`, `chore:`…). Each squash title is the entry to the changelog.

External contributors should **not** open PRs against this repository; refer to the public roadmap at `magiccolors.app/roadmap` for ways to engage.

---

## 13. Coding Standards

### 13.1 Lint configuration

`analysis_options.yaml` is the single source of truth. It imports `flutter_lints`, `very_good_analysis`, and `dart_code_metrics`, then layers Magic-Colors-specific rules on top:

- **Strict null safety.** No `dynamic`, no implicit casts.
- **Const discipline.** Build-time allocation > runtime allocation.
- **No dead code.** Unused imports / variables / fields become warnings.
- **No `print`.** Use `Logger` (from `core/utils/logger.dart`); production builds have logs stripped by `dart-define`.
- **Cognitive complexity ≤ 15 per function.** Render paths kept small to honour the 60-FPS budget.
- **Cognitive weight ≤ 0.33 per class.** Big widgets split into `widgets/<...>_part.dart` files.
- **No magic numbers > 1 in production code.** Colour, spacing, duration, and elevation all live in `core/design/design_tokens.dart`.

### 13.2 Naming conventions

| Surface | Convention | Example |
|---|---|---|
| Files (Dart) | `snake_case` | `play_now_button.dart` |
| Class / enum / typedef | `PascalCase` | `PlayNowButton` |
| Methods / fields / vars | `camelCase` | `handleTap()` |
| Constants | `lowerCamelCase` (Dart norm) | `maxCoinBalance = 999_999` |
| Asset files | `snake_case` | `coin_gold.png` |
| ARB message IDs | `lowerCamelCase` | `playNowCtaLabel` |

### 13.3 Imports

- **Relative** within a feature folder (`import 'widgets/foo.dart';`).
- **Absolute (`package:magic_colors/...`)** anywhere else.

### 13.4 Comments

- Public APIs get a `///` doc comment in the first 24 hours of landing.
- Magic constants are documented inline.
- `TODO` and `FIXME` are forbidden in `main`. Use Linear tickets instead.

---

## 14. License

Copyright © Magic Colors Studio. All rights reserved.

This source code, the design system, the audio loops, the illustrations, and the brand are released under a proprietary licence. Unauthorised redistribution, extraction, or reverse engineering is prohibited. Family-facing distribution is governed by the App Store / Play Store licences.

---

## 15. Version History

Semantic Versioning (`MAJOR.MINOR.PATCH+BUILD`) is enforced by `pubspec.yaml`.

| Version | Date | Highlights |
|---|---|---|
| `1.0.0+1` | _today_ | Initial Foundation sprint — clean architecture, design tokens, theme, router, providers, reusable widgets. Gameplay not yet shipped. |

Older drafts live in the internal Linear archive.

---

## 16. Requirements

### 16.1 Required toolchain

| Tool | Minimum | Recommended | Purpose |
|---|---|---|---|
| Flutter SDK | 3.27.0 | latest stable (3.27.x) | Runtime constraint declared in `pubspec.yaml`. |
| Dart SDK | 3.4.0 | 3.5.x | Bundled with Flutter. |
| Git | 2.34 | latest | Version control. |
| Java JDK | 17 (Android only) | 21 | Required by Gradle 8+. |

### 16.2 IDE

| IDE | Setup |
|---|---|
| **Android Studio** | Install the Flutter + Dart plugins. Open `magic_colors/` as a Flutter project. Tested with `Hedgehog` and newer. |
| **VS Code** | Install the official `dart-code` + `dart-code.flutter` extensions. Recommended `settings.json` snippet: |
| **Xcode** | 15.0+ on macOS for iOS development. CocoaPods 1.14 required for the iOS plugins. |

#### sample `.vscode/settings.json`

```json
{
  "dart.flutterSdkPath": "<absolute-path-to-flutter-sdk-3.27>",
  "dart.lineLength": 100,
  "editor.formatOnSave": true,
  "editor.rulers": [80, 100],
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.codeActionsOnSave": {
      "source.fixAll": true,
      "source.organizeImports": true
    }
  },
  "files.exclude": {
    "**/*.g.dart": true,
    "**/*.freezed.dart": true
  }
}
```

### 16.3 Recommended extensions (VS Code)

| Extension | Why |
|---|---|
| `Dart-Code.flutter` | Linting, hot reload, debug. |
| `Dart-Code.dart-code` | Companion Dart tooling. |
| `PKief.material-icon-theme` | Recognisable folder icons in the explorer. |
| `streetsidesoftware.code-spell-checker` | Catches typos in long identifiers. |
| `EditorConfig.EditorConfig` | Keeps the linter happy across mixed OS line endings. |

### 16.4 Required platforms (development)

| Platform | Built on | Tested on |
|---|---|---|
| iPhone (recommended) | macOS + Xcode | iPhone SE (3rd gen), iPhone 13, iPhone 15 Pro |
| iPad (recommended) | macOS + Xcode | iPad 10th gen, iPad Air M2 |
| Android phones | any OS | Pixel 6a, Samsung A14 |
| Android tablets | any OS | Tab S9 FE, Tab A8 |
| Web | any OS | Chrome stable (preview only) |

---

## ✨ Made with care for tiny hands.

> If something in this codebase looks unclear, that is a bug.
> Open a ticket — don't paper over the gap with a clever hack.

— _The Magic Colors Engineering Team_
