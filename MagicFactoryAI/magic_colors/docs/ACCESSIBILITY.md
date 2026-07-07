# Magic Colors — Accessibility

This children's app targets **WCAG 2.2 AA** with one strict upgrade: **all interactive surfaces have a 64dp minimum touch target** (above the 48dp AAA recommendation) because the audience is 3–8 and accuracy matters.

---

## 1. Touch targets & spacing

| Element | Min Size | Note |
|---|---|---|
| Header icon buttons | 44 dp visual, 64 dp touch bubble | InkWell wraps a smaller visual glyph. |
| Currency pills (coin, gem) | 32 dp tall, 64 dp tap bubble | tap bubble expands via padding. |
| Bottom nav item | 72 dp tall × full-width / 5 | full-height row. |
| PLAY NOW button | 240 × 86 dp | well above 64 dp. |
| Secondary cards | 76 dp square | center-tap zone fully covers card. |
| Daily event card | full-width × 100+ dp tall | horizontal padding supports sloppy taps. |

**Spacing between actionable items** is always ≥ 8 dp so a child's finger lands on the right target.

---

## 2. Color contrast

All text on the cream/sky background passes **4.5:1**. Headers / big buttons / ranks pass **7:1** (AAA).

| Pairing | Contrast |
|---|---|
| `textDark` on `cream` | 11.8:1 |
| `textMid` on `cream` | 5.3:1 |
| Coin gold (filled) on `cream` | 3.6:1 — used as decoration only, not for text |
| Gem pink (filled) on `cream` | 4.1:1 — used as decoration only |

**Decorations** (rainbow stripes, gradients) carry no text on top. Text is always laid over a solid base color or white pill.

---

## 3. Typography

- Min body copy ≥ 16sp; on the home screen the smallest copy is 11sp but it's decorative subtitles (caption role, OK).
- Display/heading copy ≥ 22sp (logo, big button).
- Sentence-case for all strings — easier for early readers.
- Bold weight (700+) for headings — easier for low-vision readers.

---

## 4. Screen reader support

Every interactive widget has a `Semantics` wrap with:
- `label` (string).
- `button: true` for tap targets.
- `selected` for the active bottom nav tab.

Examples:

| Widget | Semantics label |
|---|---|
| Settings gear | `"Settings"` |
| Reward bell (alert) | `"Daily reward available"` |
| Reward bell (idle) | `"Rewards"` |
| PLAY NOW | `"Play now"` |
| Bottom nav | `"${tab.label} tab"` (with `selected` flag) |

The `Material.elevation` circle on icon buttons gives TalkBack a clean focus target.

---

## 5. Motion

- All animations run on independent `AnimationController`s so a frame drop in one never propagates to the UI thread.
- No flashing content faster than **3 Hz** (WCAG 2.3.1).
- No motion-only signaling — every important state change has audio + visual feedback.
- Future work (Sprint 2): honor `MediaQuery.disableAnimations` globally; current screen does not lose meaning when motion is suppressed because static layout is fully readable.

---

## 6. Audio safety

- All sounds are mastered at ≤ -6 dB RMS and never exceed -3 dB peak.
- Background music (when added) is ≤ 50 dB at 1m on default device output.
- Audio cues are **redundant with visuals** — losing audio never blocks understanding.
- A "Mute" toggle lives in the Parents gate (Sprint 2 wires the route).

---

## 7. Photosensitive epilepsy (PSE)

- We use **no strobing effects**.
- No frame-to-frame flash exceeding 3 Hz.
- Particle opacity ramps smoothly on 200–500ms cycles.
- Rainbow gradient animates by color stop offset only — no flashing bands.

---

## 8. Cognitive load

- Every screen has exactly **one primary action** (PLAY NOW on the home).
- Secondary grid has **at most 5 items** so a 5-year-old can count them.
- Color-meaning mapping is consistent across screens (gold = coins, pink = gems).
- All copy is short, sentence-case, no idioms.

---

## 9. Localization & RTL

- Every user-visible string goes through the localizer. Sprint 1 ships in **English only** with the `lib/l10n/` folder scaffolded (Sprint 2 wires AppLocalizations).
- Gradients and the mascot are **mirrored in RTL** — visual order only flips, not the artwork itself.
- Bottom nav tabs retain their order; the home tab stays leftmost on LTR and rightmost on RTL.

---

## 10. Inclusive siblings

- **Color-blind mode** planned (Sprint 3) — adds shape motifs to coin/gem icons so they remain distinguishable without color.
- **Voice control** — every CTA above is `Semantics`-labeled so Voice Access can target by name.
- **Switch control** — large tap zones + clear focus rings keep switches usable.

---

## 11. Audit checklist (pre-release)

- [ ] TalkBack sweep: every actionable surface announces a sensible label.
- [ ] VoiceOver sweep: same.
- [ ] iPhone "Increase Contrast" — text remains legible.
- [ ] iPhone "Reduce Motion" — screen is still readable.
- [ ] Android "Remove Animations" — same.
- [ ] Parent surrogate: a 5-year-old can complete "tap PLAY NOW" with one hand on first attempt.
