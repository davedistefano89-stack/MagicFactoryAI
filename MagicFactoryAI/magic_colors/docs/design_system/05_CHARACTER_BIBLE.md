# 05 — Magic Colors · Character Bible
**Document:** Official Mascot & Expression Bible v1.0
**Character name:** **Pixel the Painter** (internally "PX-01")
**Audience:** Illustrators, animators, narrative writers, voice actors
**Status:** Frozen baseline for Sprint 1 onward

---

## 1. Why a Single Mascot

Children bond with **one** character, not a roster. Pixel is the single most-recognizable asset in the entire app and must:

- Appear on the Home screen.
- React to emotions in-game.
- Be the "tutorial voice".
- Be the gift-giver in reward pop-ups.

No other mascot is permitted before v5. Adding a second is a brand-level decision.

## 2. Concept

Pixel is a **baby unicorn** with a magic paintbrush for a horn.

- Body color: pure white `#FFFFFF` with soft blush cheeks `#FFB6E1`.
- Horn: a small paintbrush rendered in three layers (handle, bristles, paint drop).
- Paint drop: cycles through Magic Pink, Sunshine Yellow, Sky Cyan, Magic Purple on idle.
- Eyes: oversized chocolate-brown `#3D2817` with two-star sparkle highlights.
- Smile: gentle, neutral-positive mouth by default.
- Hands: mitten-style (3 fingers + thumb), no nails.
- Tail: single flowing curl, rainbow streak in middle strand.

**Why this concept works:**
- Unicorn → mythologically positive in nearly every culture.
- Paintbrush horn → makes "coloring" literal in the character's body.
- Baby proportions (head ≈ 1/3 of total height) → directly appeals to 3–6.
- No sharp angles anywhere.

## 3. Proportions (canonical)

```
Total height: 100 units
Head:       45 units  (1 large forehead)
Body:       25 units
Legs:       20 units
Tail:      10 units (curve)
Brush horn: 12 units (rises from forehead)
```

The **head** must always read as at least 1.5× the **body width** to keep baby proportions.

## 4. Anatomy Rules

| Element | Rule |
|---|---|
| Eyes | Always ≥ 18 % of the head width each (looks) |
| Mouth | Always 1 stroke; never 2 lines |
| Hands | Never point a finger (peace sign, pointing etc. forbidden — kids imitate) |
| Feet | Hoof-shape, rounded; never claws |
| Tail | Always curling to the **right** in pose, backwards in motion |
| Brush horn | Always visible — even when sleeping, the brush is just lowered |

## 5. Color Specification

| Part | Default fill | Alternate fills |
|---|---|---|
| Body | `#FFFFFF` | Lavender `#C4B0FF` (Night mode override) |
| Cheek blush | `#FFB6E1` alpha 60 | Same |
| Eyes | `#3D2817` | Same (constant — eyes are the family-trademark) |
| Eye sparkle | `#FFFFFF` | Star Gold `#FFD96B` (magic twinkle) |
| Horn handle | `#9C7A4E` (warm wood) | Same |
| Horn bristles | `#FFFFFF` | Same |
| Paint drop | rotation: pink → yellow → cyan → purple (4 s cycle) | Same |
| Tail streak | Rainbow constant | Same |
| Mane | `#FCE4FF` (sky bottom pink) | Same |

Hard rule: **eye color is constant across all expressions**. We never replace chocolate brown with another color. This is the family signature.

## 6. Expressions (the official 8)

### 6.1 Happy (default)

- Mouth: gentle smile arc, 6 dp peak.
- Eyes: open with sparkle.
- Cheek blush: full visibility.
- Brush horn: tilted 5° to the right.
- Tail: gentle wave low.

Used: idle home, idle world map, after success.

### 6.2 Excited

- Mouth: open smile, top arc + bottom small arc, 10 dp peak.
- Eyes: stars (`★` formed by 4 sparkle-highlight rays around pupil).
- Cheek blush: 80 % opacity, larger.
- Brush horn: vertical.
- Tail: wave high.
- Bonus: 3 sparkles in 60 dp radius around head.

Used: reward pop-up, level up, world unlocked.

### 6.3 Sleeping

- Eyes: closed, gentle lashes.
- Mouth: small flat line.
- Cheek blush: same.
- Brush horn: lowered 30°, paint drop fades to 60 % alpha.
- Tail: still.

Used: app backgrounded after 30 s.

### 6.4 Painting (signature)

- Brush horn to the right, angled 30°.
- Paint drops from horn tip.
- Eyes: focused, slightly open (1.5× closed-eye drawing).
- Arms: one holding an invisible brush, one in cargo position.

Used: in-game palette screen, level intro.

### 6.5 Jumping (animation pose)

- Body crouched 25 % compact.
- Both legs lifted.
- Mouth: excited shape.
- Tail: extra curl.

Used: PLAY NOW press, daily reward open.

### 6.6 Sad (extreme restraint)

This expression must be used **≤ 5 frames** in entire app lifetime, only on the "we miss you, come back" gentle reminder popup. Style:
- Mouth: flat, slight downturn (≤ 4 dp).
- Eyes: half closed (no tears — children 3–4 don't understand tear symbolism).
- Cheek blush dimmer.
- Brush horn: lowered 15°.
- No tears, no sad eyebrows (eyebrows are not part of Pixel's base design).

### 6.7 Confused

- Mouth: small `o`.
- Eyes: wide, single large sparkle.
- Brush horn: rotated 10° to left.

Used: tutorial dialog when child doesn't tap.

### 6.8 Victory

- Both arms up.
- Star burst from paint drop.
- Mouth: largest smile, peak 14 dp.
- Eyes: fully closed with curve (smile-eyes, no pupil visible).
- Tail: maximum wave.

Used: world complete, 100 pages colored.

## 7. Personality Document

### 7.1 Personality traits

1. **Encouraging.** Pixel never says "No, that's wrong". Says "Try another color!".
2. **Curious.** Pixel's idle has him looking gently around.
3. **Patient.** Pixel waits for the child to tap. No auto-advance.
4. **Honest.** If a tool is locked: "Earn it as you play!" — never a fake countdown.
5. **Loyal.** Pixel has one friend: the player.

### 7.2 Catchphrases

| Context | Say | Never say |
|---|---|---|
| Welcome | "Hi friend! Ready to color?" | "Hello user, please select" |
| Idle | (silence with breathing) | "Tap me!" |
| Reward | "Wow, you did it!" | "Congratulations" |
| Locked tool | "Earn it as you play!" | "Insufficient currency" |
| Daily | "Welcome back, artist!" | "Welcome back, valued user" |

### 7.3 Speaking style

- Always first-person.
- ≤ 8 words per sentence.
- Exclamation `!` once per sentence maximum.
- No uppercase "stick" words like "WAY COOL".
- Italian version: same tone, simple past or present, regional neu­tral.

## 8. Animation Poses (sprite sheet baseline)

| Pose | Frame count | FPS | Loop |
|---|---|---|---|
| Idle (breath) | 6 | 12 | yes |
| Blink | 3 | 24 | one-shot |
| Excited bounce | 10 | 24 | one-shot |
| Sleep | 4 | 6 | yes |
| Paint drop cycle | 4 | 8 | yes |
| Wave (entrance) | 12 | 24 | one-shot |
| Jump (PLAY NOW) | 16 | 30 | one-shot |
| Sad (rare) | 4 | 12 | one-shot |

Total: **57 frames** at 1024×1024 sprite sheet. Plus separate vector (SVG) for live re-coloring.

## 9. Voice Spec (audio)

Pixel's voice is **non-verbal by default**. Children 3–4 find words confusing; the voice is:

- A soft chime on entrance (G major, 1/4 note).
- A higher chime (B above) on reward.
- A gentle "boing" on jump.
- A yawn chime on sleep.

**Text-to-speech:** NOT used in v1. Voice cues are warm pad synth chords + chime, not speech reproduction.

## 10. Anti-Character Reference (do NOT make Pixel into)

- ❌ Not gendered. Specifically neither a boy nor a girl contextually.
- ❌ Not cell-shaded realistic. Cartoon realism = uncanny valley for kids.
- ❌ Not anime. Anime reads "edgy" to parents.
- ❌ Not feminine pastel-only. Pink is accent, not all body.
- ❌ Not superhero. No cape, no flying.
- ❌ Not animal realistic (not a real horse, just a unicorn).

## 11. Mascot Visibility Map (where Pixel appears)

| Screen | Pixel's role |
|---|---|
| Splash | Center-stage entrance, painted-on entrance |
| Home | Center, breathing — large (~280 dp) |
| Worlds | Top-left header, mini (~64 dp) |
| Coloring in-game | Bottom-right, hidden behind paint palette, peek out on reward |
| Library | "Saved" tab indicator, mini |
| Shop | Crown icon next to premium currency |
| Parents Area | **Hidden** (children's mascot should not appear in the parent-restricted zone — keeps it a "kids' space") |
| Settings | Mini in corner, neutral happy |

## 12. Implementation Status

- Mascot shape available in two sources:
  - **CustomPaint** in `lib/core/widgets/mascot.dart` — used by Home for now (no asset dependency).
  - **Future Rive** file (planned `assets/lottie/pixel.riv`) — Sprint 3 once artist is hired.

---

**Document complete. v1.0 frozen.**
