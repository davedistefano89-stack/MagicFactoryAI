# 10 — Magic Colors · Gameplay Flow
**Document:** Official Player Journey v1.0
**Audience:** Designers, narrative designers, QA
**Status:** v1.0 baseline

---

## 1. Player Journey Map (the 9-step canonical loop)

1. **App open** → Splash
2. **Splash finishes** → Home (with daily event highlighted)
3. **Tap PLAY NOW** → Choose world (or resume last)
4. **In world** → Choose page (latest in-progress surface)
5. **Coloring** → Brush / Fill / Sticker / Pattern
6. **Page complete** → Star rating + save prompt
7. **Reward** → Coin / Gem / Random sticker drop
8. **World map** → Show progress + next-to-unlock
9. **Back home** → Daily refresh check + soft CTA feed

This is a **closed loop**. Open loops (notifications, marketing) are isolated to Parents Area.

## 2. Awareness States

We organize gameplay around **four awareness states**, each its own visual + audio:

| State | Child feels | Visual | Audio |
|---|---|---|---|
| **Wander** | "Anything could happen" | Floating clouds, mascots idle | World music loop |
| **Choose** | "Pick my next thing" | Card stack, glow on Unlocked | UI taps as user chooses |
| **Create** | "I'm the boss of colors" | Full canvas, palette open | Soft brush sweep + ambient |
| **Reward** | "I did something!" | Reward pop-up + sparkle | Reward chime |

Transitions are always forward (no jumping back to Wander from Reward — Reward always returns to either Create or Choose).

## 3. Pacing Rules

- **Maximum reward pop-ups per session: 4.** Children fatigue on positive stimuli.
- **Maximum continuous play before gentle rest nudge: 25 minutes.** After: "Want to save and rest?"
- **Mandatory save checkpoints** every 6 pages in a world (auto-saved, no UI).
- **Daily streak reset:** 36-hour grace period (so a child who plays at 5 PM and again at 9 AM next day keeps their streak).

## 4. The Daily Loop (returning user)

```
Home opens →
  Check daily event (always visible) →
  Check pending rewards (≤ 2) →
  Check streak progress (top-right) →
  Encouragement message from mascot →
  PLAY NOW tap → resume in-progress
```

The Home screen answers the question *"what should I do next?"* in under 2 seconds for returning users.

## 5. The First-Time Loop (new player)

```
First open →
  Splash (2.4 s) →
  Home with no daily event highlighted →
  One-time tutorial card (≤ 8 s, dismissible) →
  PLAY NOW (gentle glow) →
  → Tutorial world 🎓 Unicorn Valley guided:
      Page 1: tap to fill (single tap on bucket tool demonstrates)
      Page 2: drag a brush stroke
      Page 3: place a sticker
      Page 4: undo (introduces undo button)
  → After Page 4: tutorial completed celebration chime
  → Player free to explore
```

New users never see locked content in their first 10 minutes.

## 6. Save & Persistence

Every page is auto-saved as you color. Saving is **non-blocking** — a child never sees a "Saving..." modal.

**Saved Page Storage:**
- File: `assets_library/<world_id>/<page_id>.json` (vector format).
- Thumbnail: `assets_library/<world_id>/<page_id>.png` (256 × 256 dp).
- The export-to-PDF/parent-share button produces a PDF on demand.

**Stickers:**
- Sticker pack persisted in `sticker_packs/<child_id>.json`.

**Progress:**
- Stars → `progress_<child_id>.json`.
- Coins / Gems → `currency_<child_id>.json`.

## 7. Retention Without Dark Patterns

We retain through **delight**, never anxiety:

- Daily notifications: ONE per day, exactly **at the time the child typically plays**. Default 17:00 local.
- Notification copy: "Pixel found 50 coins under the cushion!"
- A parent's notification setting controls this entirely — parents can disable via Parents Area in one tap.

We **never** use:

- ❌ Daily login streaks with loss-of-progress framing.
- ❌ Energy / life system.
- ❌ Hard time-locked content ("come back in 4 hours").
- ❌ "Almost there!" status bars that imply failure.
- ❌ Competitive leaderboards.

## 8. The Reward Drop Table

Every completed page emits a tiny drop:

| Reward | Probability |
|---|---|
| Coin (5–20) | 70 % |
| Gem (1) | 10 % |
| Random sticker | 15 % |
| +1 "Magic Star" (toward next brush) | 5 % |

These drops accumulate over time. They are **never advertised as "rare"** because rarity framing confuses children.

## 9. Failure Modes (and how we handle them)

| Failure | Magic Colors behavior |
|---|---|
| Child taps outside a button | Nothing happens — no error tone. |
| Child disconnects mid-stroke | Auto-save retains previous snapshot. On reconnect, child sees last drawn state. |
| Subscription lapses | Free content remains usable; no locked content is removed. |
| Child tries to delete a saved page | Confirmation dialog with mascot reassurance ("Are you sure? You'll miss this drawing.") |

## 10. Mission / Quest System (v2.0)

In v2, **soft-goal weekly passes** appear:

- 1 weekly pass per child.
- Goal: e.g. "Color 3 pages" or "Try a new sticker".
- Reward: e.g. "Sunshine Brush".
- Pass visible on Home and in Parents Area.
- No urgency, no countdown, no missing-out.

## 11. Time-on-Screen Health

| Rule | Mechanic |
|---|---|
| After 25 min of continuous play | Soft greeting from mascot: "Want to save and rest for a bit?" |
| After 45 min | Parent notification sent (if enabled) |
| Saved pages accessible anytime | No expiry on saved work |

## 12. Keyboard / Mouse (Desktop, future)

v1 is mobile-only. Desktop is a v2 effort. When implemented:
- SPACE = next color in palette.
- B = brush tool.
- F = bucket fill.
- Z = undo.
- Y = redo.
- S = save.

Always with on-screen affordance for touch users.

## 13. The 12 Verbs (allowed user actions)

A child can only do 12 things. Each gets a verb-id for QA:

1. `tap_color`
2. `tap_tool`
3. `drag_stroke`
4. `tap_sticker`
5. `place_sticker`
6. `bucket_fill`
7. `undo`
8. `redo`
9. `save`
10. `share_to_parent`
11. `tap_world`
12. `tap_page`

These 12 verbs are the canonical QA checklist.

## 14. Streaks (gentle)

A "streak" is just **consecutive days playing**. After 3 days, the mascot celebration: "Three in a row! Wow!". After 7: special unicorn animation. After 30: rainbow mascot costume unlock. No streak "loss" messages — only "come back when you want" tone.

---

**Document complete. v1.0 frozen.**
