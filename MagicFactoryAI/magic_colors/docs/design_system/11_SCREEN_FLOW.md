# 11 — Magic Colors · Screen Flow
**Document:** Official Navigation & State Map v1.0
**Audience:** Designers, engineers, QA
**Status:** v1.0 baseline

---

## 1. Navigation Hierarchy

Magic Colors uses a **stack with modal layers** + a global **bottom-nav root**. Not a tab-everywhere design.

```
                 [Splash]
                    ↓
              ┌──[Home]──┐
              ↓    ↓     ↓
           [Worlds] [Gallery] [Shop]
              ↓        ↓
        [WorldDetail] [SavedPage]
              ↓
       [Coloring]
              ↓
       [Reward Pop-up]
              ↑
              ← 
              └──→ [Parents Area]  (separate stack, gated)

       [Profile] (from Bottom Nav)
       [Settings] (from any Nav, then Parents Area only)
```

## 2. The 15 Screens (v1.0 catalogue)

| # | Screen | Entry | Exit |
|---|---|---|---|
| S1 | Splash | App open | Home (auto) |
| S2 | Home | Splash | Worlds / Daily Event / Gallery / Shop / Profile / Settings |
| S3 | Daily Event Pop-up | Tap daily event card | Home / Reward success |
| S4 | Worlds List | Home tap | World Detail |
| S5 | World Detail | Tap world | Page List / Coloring |
| S6 | Page List | World Detail / "Continue" | Coloring |
| S7 | Coloring | Page List tap | Reward Pop-up / Page List |
| S8 | Reward Pop-up | Page complete | Coloring / Gallery / Home |
| S9 | Gallery | Home tap | Saved Page Detail |
| S10 | Saved Page Detail | Gallery tap | Edit / Share / Print |
| S11 | Share to Parent | Saved Page Detail | Confirmed |
| S12 | Shop | Home tap | Pack Detail |
| S13 | Pack Detail | Shop tap | Confirmed Buy |
| S14 | Profile | Bottom Nav Profile | Settings / Home |
| S15 | Parents Area | Lock-screen gesture (cover parents button + locked code) | Home |

## 3. Transitions (canonical)

| From | To | Type | Duration | Curve |
|---|---|---|---|---|
| Splash | Home | Crossfade | 320 ms | easeOut (both sides) |
| Home | Worlds | Slide-up (full screen) | 320 ms | easeOutCubic |
| Home | Gallery | Slide-up | 320 ms | easeOutCubic |
| Home | Shop | Slide-up | 320 ms | easeOutCubic |
| Worlds | World Detail | Slide-up | 320 ms | easeOutCubic |
| World Detail | Page List | Inline expand | 240 ms | easeOut |
| Page List | Coloring | Fade to canvas | 240 ms | easeOut |
| Coloring | Reward Pop-up | Modal pop | 320 ms | elasticOut (12 %) |
| Reward Pop-up | Coloring / Gallery / Home | Fade + slide-down | 320 ms | easeInOut |
| Tap "Parents" | Lock screen | Modal cover | 240 ms | easeOut |
| Lock screen unlock | Parents Area | Modal stack | 240 ms | easeOut |
| Parents Area | Home | Modal dismiss | 240 ms | easeIn |

## 4. State Persistence Across Screens

| State | Where stored | Lifetime |
|---|---|---|
| Currency | SQLite + SharedPreferences-backed cache | persistent |
| Progress per page | SQLite | persistent |
| Currently played audio | `SoundService` singleton | runtime |
| Last page visited | `last_session.json` | until next open |
| Streak count | `streak.json` | persistent |
| Theme (light/night) | OS setting | runtime + persisted |
| Reduced motion | Parents Area | persistent |
| Volume slider values | Parents Area | persistent |

## 5. Routing Library

We use Flutter's `Navigator 2.0` (declarative `RouterDelegate`) with a single `RootRouter` defined in `lib/core/router/root_router.dart` (Sprint 3).

Page names are constants in `lib/core/router/routes.dart`:

```dart
abstract class Routes {
  static const splash = '/';
  static const home = '/home';
  static const worlds = '/worlds';
  static const worldDetail = '/world/:id';
  static const pageList = '/world/:id/pages';
  static const coloring = '/world/:id/page/:pid';
  static const gallery = '/gallery';
  static const savedDetail = '/gallery/:id';
  static const shop = '/shop';
  static const packDetail = '/shop/:id';
  static const profile = '/profile';
  static const parents = '/parents';
}
```

## 6. Bottom Nav (always present on root)

5 tabs: **Home · Worlds · Gallery · Shop · Profile**.

- Home is root.
- Worlds opens the Worlds List.
- Gallery opens the saved work.
- Shop opens the Storefront.
- Profile opens the child profile.

`Parents Area` is **not** in the nav — it's gated behind a long-press tap + code. This prevents accidental child entry.

## 7. Modal Stack vs New Route

| Action | Where to push it |
|---|---|
| Reward pop-up | Modal (top of stack, prevents back navigation seam) |
| Daily event pop-up | Modal |
| Confirm dialog | Modal |
| Tutorial overlay | Modal but tap-through with skip |
| Parents Area entry | Modal (separate stack) |
| Settings | Modal (from any nav root screen) |
| Pack purchase confirm | Modal |
| Help | Modal bottom sheet |

## 8. Back Button Behavior

| Screen | Back does |
|---|---|
| Splash | (no back) |
| Home | App background |
| Worlds | Home (slide-down animation) |
| World Detail | Worlds |
| Page List | World Detail |
| Coloring | Page List (with save prompt if dirty state) |
| Reward Pop-up | Coloring |
| Gallery | Home |
| Saved Page Detail | Gallery |
| Shop | Home |
| Parents Area | Lock screen (back to Home) |

Hardware back button (Android) mirrors software back.

## 9. Parents Entry Gate

To prevent child access, a two-step gate:

1. **Long-press** (1.5 seconds) the **Settings** button — the only setting-access surface in the child zone.
2. **Math challenge**: solve a 3-digit addition (e.g. `42 + 18`). For ages 9+: 4-digit multiplication is offered.

Successful entry → Parents Area. Failed attempts: no penalty, just a mascot giggle and continue waiting.

## 10. Accessibility — Screen Reader Routing Order

When a screen reader is enabled, screen-reader order is **top-down, left-right**, in this priority:

1. Primary CTA
2. Secondary CTAs (in source order)
3. Daily event card
4. Currency HUD
5. Mascot

This pattern keeps the most user-actionable item first.

## 11. Reduced Motion Fallback

If reduced motion is enabled (Parents Area), all transitions become 240 ms crossfades, never slides or elastic.

## 12. Screen → Code Map

| Screen | Code file | Status |
|---|---|---|
| Splash | `lib/features/splash/splash_screen.dart` | ✅ Sprint 1 |
| Home | `lib/features/home/home_screen.dart` | ✅ Sprint 1 |
| Worlds | `lib/features/worlds/worlds_screen.dart` | 🚧 Sprint 3 |
| Coloring | `lib/features/coloring/coloring_screen.dart` | 🚧 Sprint 3 |
| Shop | `lib/features/shop/shop_screen.dart` | 🚧 Sprint 3 |
| Gallery | `lib/features/gallery/gallery_screen.dart` | 🚧 Sprint 3 |
| Profile | `lib/features/profile/profile_screen.dart` | 🚧 Sprint 3 |
| Parents | `lib/features/parents/parents_screen.dart` | 🚧 Sprint 4 |

## 13. Anti-Navigation (do NOT do)

- ❌ Hidden gesture-only navigation.
- ❌ Hamburger menus in the child zone.
- ❌ More than 5 bottom-nav tabs.
- ❌ Pop-up chains (one pop up triggering another pop up).
- ❌ Confirmation spam — max 2 confirms in any session.

---

**Document complete. v1.0 frozen.**
