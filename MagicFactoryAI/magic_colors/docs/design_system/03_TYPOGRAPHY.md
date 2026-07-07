# 03 — Magic Colors · Typography
**Document:** Official Type System v1.0
**Audience:** Designers, engineers, localization
**Status:** Frozen baseline

---

## 1. Type Philosophy

Children read symbols before letters. Typography in Magic Colors must therefore:

1. **Feel friendly at a glance.** Slight roundness, no mechanical geometric rigidity.
2. **Be legible for an early reader.** Generous x-height, open counters, generous spacing.
3. **Scale gracefully with the reader's age.** Larger text + same proportion as the reader grows.
4. **Survive translation.** Slab-serif and condensed families die in German; sans-serif survives.

We use **two type families** total. Adding a third is a brand-level decision.

## 2. Type Families

### 2.1 Title family — **Baloo 2** (Google Fonts, OFL)

Used for: screen titles, button labels, modal headers, reward pop-ups.

Why Baloo 2:
- Soft rounded geometric forms.
- Built-in *very strong* weights — perfect for "PLAY NOW".
- Used by leading kid apps (Lingokids, Khan Academy Kids).
- Free / OFL licensed.

Variants used: **Baloo 2 ExtraBold 800** (titles only), **Baloo 2 Bold 700** (buttons, modals).

```dart
// Implementation snippet (lib/core/theme/app_typography.dart)
static const titleLg = TextStyle(
  fontFamily: 'Baloo2',
  fontWeight: FontWeight.w800,
  fontSize: 36,
  height: 1.1,
  letterSpacing: -0.2,
);
```

### 2.2 Body family — **Nunito** (Google Fonts, OFL)

Used for: body copy, captions, Parents Area, tooltips, system notifications.

Why Nunito:
- High x-height (great for early readers).
- Five weights from 400 to 900.
- Excellent language coverage (Latin Extended, Cyrillic, Vietnamese).
- Free / OFL licensed.

Variants used: **Nunito Regular 400** (body), **Nunito SemiBold 600** (emphasis), **Nunito Bold 700** (strong emphasis).

```dart
static const bodyMd = TextStyle(
  fontFamily: 'Nunito',
  fontWeight: FontWeight.w500,
  fontSize: 16,
  height: 1.4,
  letterSpacing: 0.0,
);
```

## 3. Type Scale

Modular scale: **1.250 (major third)**, rounded for screen rendering.

| Token | Family | Weight | Size | Use |
|---|---|---|---|---|
| `displayXxl` | Baloo 2 | 800 | 56 | Splash logo only |
| `displayXl` | Baloo 2 | 800 | 44 | Reward pop-ups |
| `titleLg` | Baloo 2 | 800 | 36 | Screen titles |
| `titleMd` | Baloo 2 | 700 | 28 | Modal titles |
| `titleSm` | Baloo 2 | 700 | 22 | Card titles |
| `buttonLg` | Baloo 2 | 800 | 30 | Big CTA (PLAY NOW) |
| `buttonMd` | Baloo 2 | 700 | 20 | Medium CTA |
| `buttonSm` | Baloo 2 | 700 | 16 | Tertiary chips |
| `bodyXl` | Nunito | 600 | 20 | Body emphasis |
| `bodyLg` | Nunito | 500 | 18 | Body default |
| `bodyMd` | Nunito | 500 | 16 | Body small |
| `bodySm` | Nunito | 500 | 14 | Caption |
| `labelLg` | Nunito | 700 | 16 | Tab label, nav label |
| `labelMd` | Nunito | 700 | 14 | Chip label |
| `numericXl` | Baloo 2 | 800 | 28 | Currency counters |

## 4. Title vs Body — Decision Tree

```
Is the text ≤ 8 characters, including titles?
  ├─ Yes, and on a SOLID-colored background?
  │     → Baloo 2 (rounded, friendly)
  ├─ Yes, and on transparent / image?
  │     → Baloo 2 with text shadow (1 px, 30% black)
  └─ No (longer than 8 chars)
        → Nunito (readable at length)
```

This rule keeps short labels feeling icon-like and longer labels feeling readable.

## 5. Line Height & Truncation

- **Titles**: line-height 1.1 (tight), max 2 lines.
- **Buttons**: line-height 1.0 (overlap of bold strokes is fine), max 1 line, ellipsis never used (button text is canonical).
- **Body**: line-height 1.4 (relaxed), max 3 lines then ellipsis.
- **Captions**: line-height 1.3, max 2 lines.

## 6. Letter-Spacing

- All titles: **-0.2 px** at any size (tight).
- All buttons: **+0.0 px** (default).
- All body: **+0.0 px**.
- Numerics (counters): **-0.2 px** (tight for visual rhythm).

## 7. Alignment

- Title bars: **center-aligned** within 220 dp wide container.
- Body text in Parents Area: **left-aligned**, ragged right.
- Body text in toasts / cards: **left-aligned**.
- Numerics in currency HUD: **right-aligned**, monospaced layout (we use `tabularFigures` from `Baloo 2`).

## 8. Truncation Behavior

- Buttons never truncate. If text overflows, the **button** shrinks horizontally only by ≤ 16 dp, then the **font** may shrink one step (e.g. `buttonLg` → `buttonMd`); never both.
- Card titles truncate with **single-line ellipsis**.
- Body text truncates with **two-line ellipsis** and a "Read more" pill in Parents Area only.

## 9. Accessibility Type Rules

Magic Colors must respect the OS-level type scaling (Settings → Display → Text Size) with the following overrides:

| OS scale | Body multiplier | Title multiplier |
|---|---|---|
| x0.85 | 0.85 | 0.9 |
| x1.00 (default) | 1.0 | 1.0 |
| x1.15 | 1.15 | 1.1 |
| x1.30 | 1.30 | 1.2 |

In Flutter we implement this via `MediaQuery.textScaler` clamping with `Clamp(0.85, 1.30)` so we don't break layout.

### 9.1 Dyslexia-friendly mode

If the user enables "Dyslexia-friendly mode" in Parents Area, swap **Nunito** for **OpenDyslexic** (OFL, free). Keep Baloo 2.

### 9.2 Minimum tap target

Type of 14 sp or smaller is **never paired** with a tap action smaller than 56 dp — we always pair tiny labels with an icon.

## 10. Localization

| Locale | Baloo 2 / Nunito behavior |
|---|---|
| Latin scripts | Direct use |
| Cyrillic (ru, uk) | Both fonts cover fully |
| Arabic (ar) | **Butterfly swap to Cairo** (titles) and **Noto Naskh Arabic** (body) — RTL handled by Flutter |
| Hebrew (he) | Same RTL pattern |
| CJK (ja, ko, zh) | **M PLUS Rounded 1c** (titles), **Noto Sans CJK** (body) |
| Vietnamese (vi) | Both fonts support diacritics |

Font asset strategy: download at first run, cache locally. Never bundle all fonts in the APK — costs ~7 MB extra.

## 11. Don'ts

- ❌ No all-caps title spans longer than 3 words.
- ❌ No italic in body. (Italic = stress = negative emotion.)
- ❌ No font weight below 500 in children-facing copy.
- ❌ No third or fourth font family. Two is the policy.
- ❌ No text without a corresponding icon, in any child CTA.

## 12. Type → Code Reference

| Token | Dart name in `app_typography.dart` |
|---|---|
| `titleLg` 36/800 | `titleLg` |
| `buttonLg` 30/800 | `bigButton` (already shipped, used by PLAY NOW) |
| `bodyMd` 16/500 | `bodyMedium` |
| `numericXl` 28/800 | `numericCounter` |

**Implementation status:** Baloo 2 + Nunito runtime-loaded via `google_fonts` package, declared in `pubspec.yaml`. Achievement in Sprint 1.

---

**Document complete. v1.0 frozen.**
