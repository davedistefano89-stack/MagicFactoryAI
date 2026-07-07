# Magic Colors — Design System

This document is the contract between pixels and pixels-of-tomorrow. Every widget ships from a token, every animation conforms to a curve, every screen yields space to a soft shadow.

---

## 1. Brand tokens

### 1.1 Palette (defined in `lib/theme/app_theme.dart`)

| Role | Hex | Used for |
|---|---|---|
| `skyTop`        | `#B6E2FF` | upper sky band |
| `skyMid`        | `#FFE0F0` | mid-band pink |
| `skyBottom`     | `#FFF6E6` | warm cream base |
| `rainbowRed`    | `#FF6B6B` | rainbow accents |
| `rainbowOrange` | `#FFA94D` | rainbow accents |
| `rainbowYellow` | `#FFD93D` | coin gold, sparkle |
| `rainbowGreen`  | `#6BCB77` | success, on-state |
| `rainbowBlue`   | `#4D96FF` | primary accent |
| `rainbowPurple` | `#C780FA` | primary accent |
| `primaryPurple` | `#7B5BFF` | buttons, active states |
| `primaryPink`   | `#FF7BB6` | PLAY NOW gradient |
| `accentYellow`  | `#FFD93D` | sparkle, star |
| `accentMint`    | `#6FE6C7` | success ribbon |
| `coinGold`      | `#FFC93C` | coin glyph + shadow |
| `gemPink`       | `#FF77B7` | gem glyph + shadow |
| `textDark`      | `#3A2E5A` | body text |
| `textMid`       | `#6E6397` | caption text |
| `textLight`     | `#B8B0D6` | disabled text |
| `notificationBubble` | `#FF4D6D` | reward alert ring |

### 1.2 Gradients

| Token | Direction | Stops | Used by |
|---|---|---|---|
| `AppGradients.rainbow` | TL→BR | red→orange→yellow→green→blue→purple | mascot horn, logo, claims |
| `AppGradients.playNow`  | T→B   | pink→gold→orange | PLAY NOW button |
| `AppGradients.sky`      | T→B   | skyTop→skyMid→skyBottom | background |
| `AppGradients.collection` | TL→BR | cyan→pink | Collection card |
| `AppGradients.rewards`    | TL→BR | gold→orange | Rewards card |
| `AppGradients.shop`       | TL→BR | lavender→pink | Shop card |
| `AppGradients.parents`    | TL→BR | mint→sky | Parents card |
| `AppGradients.premium`    | TL→BR | purple→blue→indigo | Premium card |

### 1.3 Typography

Two families only:
- **Baloo 2** — display, logo, big buttons, section titles.
- **Nunito** — body, caption, button label small, currency amount.

Catalog: `logo`, `bigButton`, `buttonLabel`, `sectionTitle`, `body`, `caption`, `currencyAmount`. Sized via the `size:` parameter so every widget dials the same family consistently.

Minimum body size in any visible UI is **16 sp**. Recommended minimum is **18 sp** for kids 3–5 copy.

### 1.4 Shape & shadows

**Shape tokens:** `radiusXS=8`, `radiusS=14`, `radiusM=22`, `radiusL=32`, `radiusXL=48`, `radiusPill=999`.

**Shadows:** `soft`, `medium`, `deep`, `playButton`. Every interactive surface uses **medium** or deeper.

---

## 2. Reusable components (catalog)

| Component | File | Responsibility |
|---|---|---|
| `AnimatedSkyBackground` | `lib/widgets/effects/animated_background.dart` | 5-layer animated environment (sky, rainbow, clouds, stars, particles). |
| `MascotWidget` | `lib/widgets/mascot/mascot.dart` | Custom-painted smiling unicorn mascot. Breathes + blinks. |
| `PlayNowButton` | `lib/widgets/buttons/play_button.dart` | Primary CTA. Gradient ground, glow halo, particle burst, sound on tap. |
| `SecondaryButton` | `lib/widgets/buttons/secondary_button.dart` | Pill card per secondary action (one per `SecondaryVariant`). |
| `HomeBottomNav` | `lib/widgets/buttons/bottom_nav.dart` | Rounded 5-tab bottom bar. |
| `CurrencyHud` | `lib/widgets/currency/currency_hud.dart` | Top header: settings, logo, coin, gem, daily bell. |
| `DailyEventCard` | `lib/widgets/cards/daily_event_card.dart` | Featured coloring page card with animated chest. |

Adding a new component means:
1. Adding the widget file under the appropriate folder.
2. Using **only** `AppColors` / `AppGradients` / `AppTypography` / `AppShape` / `AppShadows` tokens.
3. Hard-shadow size + radius constraints as parameters, not literals.
4. A Semantics widget at the root if it carries user interaction.

---

## 3. Motion principles

1. **Slow & continuous** — clouds drift at 30s loops; particles rise at 9s loops.
2. **Snappy on intent** — buttons bounce in **220ms or less**; children expect immediate feedback.
3. **Soft on success** — chest opens slowly (400ms) so the reward feels earned.
4. **Never linear** — every animation uses `Curves.easeOut` or `easeOutBack`.
5. **Reduce-motion friendly** — implicit future work (Sprint 2) will respect platform motion settings; current screen does not jitter when system "Reduce Motion" is on because no critical UI depends on motion.

---

## 4. Accessibility defaults

- **Touch target minimum** — `AppShape.minTouchTarget = 64 dp`. Bottom nav is 72dp tall, secondary cards are 76dp.
- **Contrast** — body text passes 4.5:1 against the cream base.
- **Typography** — min 16sp; display ≥ 22sp.
- **Semantic labels** — every interactive widget has a `Semantics(label:, button:)` wrapper.
- **Audio** — sound effects are skippable via the Parents gate (Sprint 2 wires it).

See `ACCESSIBILITY.md` for the full audit checklist.

---

## 5. Quality bar (Top-10 kids apps reference)

The visual language targets the experience floor of:

- **Bimi Boo** — Bold, flat, large typography, friendly characters.
- **Toca Boca** — Whimsical environments, highly responsive buttons, no real-world time pressure.
- **Sago Mini** — Bright cream backgrounds, rounded everything.
- **Pepi Play** — Layered environments, sparkly embellishments, instant feedback.

We **do not** import their art. We **do** chase their polish.
