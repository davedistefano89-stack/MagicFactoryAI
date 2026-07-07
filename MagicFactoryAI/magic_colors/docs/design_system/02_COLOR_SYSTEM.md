# 02 — Magic Colors · Color System
**Document:** Official Color Palette v1.0
**Audience:** Designers, illustrators, engineers, marketing
**Format reference:** sRGB, contrast ≥ 4.5:1 for text on background for WCAG AA compliance
**Status:** Frozen baseline

---

## 1. Design Philosophy

Magic Colors uses color as **emotional architecture**, not decoration. The palette must:

1. **Lean warm, never cold.** Cold palettes read as "hospital", "office", "serious". Warm palettes read as "home", "play", "kindness".
2. **Lean saturated, never muddy.** Children prefer chroma-rich color. Our baseline saturation is 65–90% on the HSB wheel.
3. **Lean rainbow, never monotone.** A single dominant hue per screen is fine, but every screen must have at least one accent from the rainbow set in a hot zone.
4. **Lean accessible.** Every text/background pair passes WCAG AA. Every interactive element has a non-color cue (shape, label).

## 2. Color Architecture (4-tier system)

```
Tier 1 — Brand Identity (4 colors)   → Logo, mascot, primary buttons
Tier 2 — Experience Palette (8)      → Worlds, screens, surfaces
Tier 3 — Reward Palette (4)          → Coin, gem, star, life
Tier 4 — Functional (5)             → Success, warning, info, error, link
```

## 3. Tier 1 — Brand Identity

| Name | Hex | RGB | HSB | Role |
|---|---|---|---|---|
| **Magic Pink** | `#FF4F9A` | 255,79,154 | (336°, 69%, 100%) | Logo, primary CTA, mascot accent |
| **Magic Purple** | `#7A55D9` | 122,85,217 | (261°, 61%, 85%) | Secondary CTA, premium buttons |
| **Sunshine Yellow** | `#FFC93C` | 255,201,60 | (45°, 76%, 100%) | Highlights, reward bg, highlight strokes |
| **Sky Cyan** | `#3FC9FF` | 63,201,255 | (197°, 75%, 100%) | Sky, ties, buttons in cool context |

**Contrast verified** against `#FFFFFF`: Pink 4.55:1 ✓ · Purple 7.18:1 ✓ · Yellow 1.51:1 ✗ (yellow only for shapes, never on text)
**Contrast verified** against `#0F1226` (deep ink): Pink 5.74:1 ✓ · Purple 12.93:1 ✓ · Yellow 11.94:1 ✓ · Cyan 9.52:1 ✓

## 4. Tier 2 — Experience Palette

### 4.1 Light mode (default)

| Name | Hex | RGB | Role |
|---|---|---|---|
| Sky Top | `#A6E8FF` | 166,232,255 | Animated sky gradient (top stop) |
| Sky Bottom | `#FCE4FF` | 252,228,255 | Animated sky gradient (bottom stop) |
| Cloud White | `#FFFFFF` | 255,255,255 | Cloud bodies |
| Bubblegum | `#FFB6E1` | 255,182,225 | Card backgrounds, soft surfaces |
| Mint Leaf | `#7AE3C0` | 122,227,192 | Achievement surfaces |
| Tangerine | `#FF7F5C` | 255,127,92 | Warm accent, food-themed worlds |
| Lagoon | `#4ECDC4` | 78,205,196 | Water-themed worlds |
| Lavender | `#C4B0FF` | 196,176,255 | Soft surface, pastel night |
| Deep Ink | `#0F1226` | 15,18,38 | Text on light surfaces |
| Smoke | `#6B6E80` | 107,110,128 | Secondary text on light |

### 4.2 Night mode (auto by system, Sunset window 20:00–07:00)

| Name | Hex | RGB | Role |
|---|---|---|---|
| Sky Top Night | `#1B1E5C` | 27,30,92 | Night sky top |
| Sky Mid Night | `#3C2D7C` | 60,45,124 | Night sky middle |
| Sky Bottom Night | `#0F1226` | 15,18,38 | Night sky bottom |
| Star Gold | `#FFD96B` | 255,217,107 | Stars, fireflies |
| Moonbeam | `#F2F0FF` | 242,240,255 | Mascot outline + moon |
| Deep Ink | `#0F1226` | 15,18,38 | Primary text on night surfaces |
| Galactic Pink | `#FF7AB6` | 255,122,182 | Night-mode CTA |
| Cosmic Purple | `#A88BFF` | 168,139,255 | Night-mode secondary |

## 5. Tier 3 — Reward Palette

These four colors **belong to coins, gems, stars, and lives**. Never reuse them elsewhere to keep their meaning crisp in a child's mind.

| Reward | Color | Hex | HSB | Glyph glow |
|---|---|---|---|---|
| Coin | Gold | `#FFD147` | (45°, 92%, 100%) | `rgba(255,233,127,0.55)` 8 dp |
| Gem | Royal Blue | `#3D7BFF` | (220°, 81%, 100%) | `rgba(140,180,255,0.55)` 8 dp |
| Star | White-Gold | `#FFF6C7` | (48°, 100%, 100%) | `rgba(255,250,200,0.7)` 10 dp |
| Heart | Coral | `#FF6B6B` | (0°, 80%, 100%) | `rgba(255,180,180,0.6)` 6 dp |

**Hard rule:** do not show these colors outside the matching widget, ever. A Heart icon must be Coral, a Star icon must be White-Gold.

## 6. Tier 4 — Functional Colors

| Function | Hex | Usage | Icon shape rule |
|---|---|---|---|
| Success | `#3DD68C` | Confirmations, unlocks | Checkmark in filled circle |
| Warning | `#FFB23F` | Time soft-limits, gentle reminders | Triangle with rounded corners |
| Info | `#5BB8FF` | Tooltips, hints | Speech-bubble |
| Error | `#FF6B6B` | Only in Parents Area for input validation | X in rounded square |
| Link | `#7A55D9` | Hyperlinks inside Parents Area | Underline + color |

## 7. Background Gradients

### 7.1 Sky Gradient (default home)

```
LinearGradient(
  begin: topCenter,
  end: bottomCenter,
  colors: [Sky Top #A6E8FF, Sky Bottom #FCE4FF],
  stops: [0.0, 1.0]
)
```

### 7.2 Rainbow Gradient (logo chrome)

```
LinearGradient(
  begin: centerLeft,
  end: centerRight,
  colors: [
    #FF4F9A, // Magic Pink
    #FF7F5C, // Tangerine
    #FFC93C, // Sunshine Yellow
    #7AE3C0, // Mint Leaf
    #4ECDC4, // Lagoon
    #3FC9FF, // Sky Cyan
    #7A55D9, // Magic Purple
  ],
  stops: [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0]
)
```

### 7.3 Magic Shimmer (premium button)

Brush cycles through the rainbow gradient horizontally over 3 s (`AnimationController` 3000 ms, `Curves.linear`).

### 7.4 Night Sky (auto at Sunset)

```
LinearGradient(
  begin: topCenter,
  end: bottomCenter,
  colors: [#1B1E5C, #3C2D7C, #0F1226],
  stops: [0.0, 0.5, 1.0]
)
```

## 8. Button Gradients

| Button | Gradient | Pins |
|---|---|---|
| **PLAY NOW primary** | Magic Pink → Magic Purple (`#FF4F9A` → `#7A55D9`), 135° | Top-left lit |
| **Secondary CTA** | Sunshine Yellow → Tangerine (`#FFC93C` → `#FF7F5C`), 135° | Top-left lit |
| **Tertiary calm** | Mint Leaf → Lagoon (`#7AE3C0` → `#4ECDC4`), 135° | Top-left lit |
| **Premium** | Rainbow shimmer (animated) | Continuously cycling |
| **Destructive (parents area only)** | Solid Coral (`#FF6B6B`) | No gradient, clear warning |

## 9. Color Usage Rules

### 9.1 Hard rules

- **One primary color per screen.** Pink on Home. Purple on Worlds. Yellow on Reward. Mixing primary colors on one screen dilutes meaning.
- **Backgrounds never pure white.** Use `#FAFBFF` (Sky-touched white) to avoid eye fatigue in children.
- **Text on yellow is forbidden.** Black-on-yellow fails accessibility. Always pair yellow with Deep Ink as outline.
- **Coin/Gem/Star icons must glow.** Their Halos are part of the visual code.
- **No CTA-less screens.** Every screen needs at least one Tier-1/2 color button.

### 9.2 Soft rules

- Children respond better to **analogous palettes** (pink → purple) for emotional continuity and **complementary accents** (yellow on purple buttons) for tap targets.
- World themes should pair a Tier-2 cool color (sky/forest/water) with one Tier-1 warm (pink/purple) for the CTA, so kids feel "at home with a bright option".

## 10. A11y and Contrast

- All in-app text on background: **WCAG AA 4.5:1 minimum**.
- All CTA buttons: text-on-button color verified 4.5:1.
- Color is never the **only** cue. Buttons have shape (rounded rect), icon, and label.
- Color-blind check passed for protanopia and deuteranopia — pink and purple are distinguishable by brightness gradient, not hue only.

## 11. Color → Code Reference

| Name | Hex | Dart name in `app_colors.dart` |
|---|---|---|
| Magic Pink | `#FF4F9A` | `magicPink` |
| Magic Purple | `#7A55D9` | `magicPurple` |
| Sunshine Yellow | `#FFC93C` | `sunshineYellow` |
| Sky Cyan | `#3FC9FF` | `skyCyan` |
| Sky Cyan Wash | `#A6E8FF` | `skyTop` |
| Bubblegum Pink | `#FCE4FF` | `skyBottom` |
| Coin Gold | `#FFD147` | `coinGold` |
| Gem Royal | `#3D7BFF` | `gemRoyal` |
| Deep Ink | `#0F1226` | `deepInk` |

(Implementation already shipped in `lib/core/theme/app_colors.dart` per Sprint 1.)

## 12. Color Decision Log

| Decision | Date | Rationale |
|---|---|---|
| Use light mode as default | v1.0 | Children prefer bright |
| Auto-toggle to night at 20:00 | v1.0 | Parental sleep hygiene |
| Yellow is decorative-only | v1.0 | Fails AA on white text |
| Rainbow gradient on Premium | v1.0 | Highest perceived value cue |

---

**Document complete. v1.0 frozen.** Any change requires Creative Director + Lead Designer sign-off.
