# 08 — Magic Colors · Animation Guide
**Document:** Official Motion System v1.0
**Audience:** Animators, engineers, QA
**Status:** v1.0 baseline — applications across UI, mascot, environment

---

## 1. Motion Philosophy

Animation in Magic Colors must:

1. **Make the world feel alive** without distracting from a child's task.
2. **Always serve a purpose** — convey feedback, draw attention, signal reward, or remove ambiguity.
3. **Be honest** — animations never lie about game state (no fake "loading").
4. **Respect motion sensitivity** — all motion is opt-out-able via "Reduced motion" in Parents Area.

**Rule of thumb:** if you cannot articulate why an animation exists in **one sentence**, remove it.

## 2. Motion Vocabulary (the 8 lawful moves)

| Move | When | Curve | Duration |
|---|---|---|---|
| **Bounce** | Reward, success, "play" press | `Curves.elasticOut` with 30 % overshoot | 320 ms |
| **Breath** | Idle mascot, idle button glow | `Curves.easeInOut` sine wave | 1800 ms loop |
| **Float** | Clouds, stars, particles | `Curves.easeInOut` sine wave, 8 dp amplitude | 4000–8000 ms loop |
| **Sparkle** | Reward pop-up, premium buttons | `Curves.easeOutCubic`, fade at end | 600–1200 ms |
| **Burst** | Tap response on big CTAs | `Curves.easeOutQuint` | 280 ms |
| **Slide** | Screen transitions | `Curves.easeOutCubic` | 320 ms |
| **Fade** | Modal/dialog entry | `Curves.easeOut` | 240 ms |
| **Pop** | Currency counter increment | `Curves.easeOutBack` (overshoot 12 %) | 320 ms |

## 3. Button Animations

### 3.1 Primary BigButton (PLAY NOW)

- **Idle glow pulse** — shadow opacity 0.3 → 0.55 → 0.3 over 1800 ms.
- **Press ripple** — radial pink ripple, 280 ms.
- **Hold (post-tap)** — gradient brightens 8 % for 600 ms.
- **Sound** — `MagicSound.bigTap` on press.

### 3.2 Secondary buttons (5 home grid)

- **Idle float** — y axis ± 2 dp over 2400 ms, staggered 200 ms each.
- **Press scale** — 0.95 scale + 2° tilt, 220 ms `Curves.easeOutCubic`.
- **Return** — 320 ms `Curves.elasticOut`.

### 3.3 Tertiary chip

- **Press** — 0.97 scale.
- **No idle animation** (calm CTAs).

## 4. Mascot Animations

| Pose | Description | Timeline |
|---|---|---|
| Idle (breath) | Body tilts ±2° + chest 8 % scale; brush horn sways ±5° | 2400 ms loop |
| Blink | Eyes close 80 ms; sparkles afterglow 120 ms | every 4–6 s |
| Excited | Jump 12 dp + sparkle burst (3 sparkles around head) | one-shot 600 ms |
| Wave | Right paw up, gentle 12° rotation | one-shot 800 ms |
| Sleep | Eyes close + brush horn lowered | 600 ms + sustained |
| Sad | Slight bow forward, brush horn 15° lowered | one-shot 600 ms (use rarely) |
| Paint | Brush horn rotated 30° right + paint drop cycle | loop while in palette |

## 5. Environment Animations

### 5.1 Clouds

- **Direction**: left → right at 0.05 dp/s (subliminal).
- **Density**: 4–6 clouds visible.
- **Cloud size variation**: 30–60 dp height with proportional width.

### 5.2 Stars / Twinkles (overlayed)

- 12 stars total, 6 twinkling at any time.
- Each twinkle: scale 1 → 1.6 → 1 over 600 ms; alpha 0.5 → 1 → 0.5.

### 5.3 Rainbow

- **Gradient shimmer** — full 7-stop rainbow gradient shifts horizontally over 6000 ms.
- Always present behind mascot, never blocking CTAs.

### 5.4 Magic Particles

- 16 particles max on Home.
- Each particle's life: 1500 ms.
- Each spawns from a random `Curves.easeOutCubic` path.

## 6. Reward Animations

### 6.1 Reward pop-up (the high-end moment)

| Step | Time | Visual |
|---|---|---|
| 0 ms | 0 % | Fade in: black 0% → 50% backdrop |
| 80 ms | 25 % | Center sparkle ring appears (8 sparkles) |
| 200 ms | 50 % | Card scales 0.6 → 1.0 with elasticOut |
| 400 ms | 80 % | Confetti from above (24 pieces, 5 colors) |
| 800 ms | 100 % | "Continue" button enabled |
| ~ 3500 ms | auto-dismiss mode optional | If button not pressed in 3.5 s, button pulses gently |

### 6.2 Chest burst (daily event)

- Chest lid rises by 24 dp, glow interior pulse.
- 12 small particles burst outward.
- Total: 800 ms, then card appears.

### 6.3 Coin pop

- Counter HUD scales 1 → 1.2 → 1 over 320 ms.
- Number rolls visually with `Curves.easeOutQuint`.

## 7. Screen / Modal Animations

### 7.1 Splash → Home transition

- Splash fades out over 320 ms `Curves.easeOutCubic`.
- Home fades in over 320 ms `Curves.easeInCubic`.
- Logo slides up 12 dp on splash exit.

### 7.2 Modal entry

- Backdrop alpha 0 → 0.5 in 240 ms.
- Card scales 0.85 → 1.0 with elasticOut (12 % overshoot) in 320 ms.

### 7.3 Bottom sheet

- Slide up from bottom, 280 ms easeOutCubic.
- Backdrop fade in parallel.

## 8. Performance Budget

| Layer | Animation budget |
|---|---|
| Mascot + sky | 1 paint/frame |
| Particles | max 32, recycled pool |
| Buttons | no double-animate when scrolling |
| Sounds | only one SoundSource concurrent max |
| Combined target | **60 FPS** on any device ≥ 6 years old |

Render tree **must be paused** when the screen is invisible:

```dart
@override
void dispose() {
  _controllerA.dispose();
  _controllerB.dispose();
  super.dispose();
}
```

`AutomaticKeepAlive` should be off for screens that don't need preservation.

## 9. ReducedMotion (accessibility hook)

Magic Colors has a "**Reduced motion**" toggle in Parents Area. When enabled:

- Disable elasticity, overshoot, and Slide animations.
- Replace with a simple fade-in (320 ms `Curves.easeOut`).
- Keep static visual state changes (button states, modal open).
- Mascot remains alive but does a "still" pose (no breath, no blink).
- Reward pop-ups still appear but without bounce.

Implementation in Flutter: a top-level `Provider<MotionPreference>` is read by all animated widgets; widgets read `prefs.reducedMotion` and choose a less aggressive curve.

## 10. Implementation Status

| Animation | Status | File |
|---|---|---|
| Sky / Clouds / Rainbow / Particles | ✅ | `lib/features/home/widgets/animated_background.dart` |
| Mascot breath + blink | ✅ | `lib/core/widgets/mascot.dart` |
| BigButton glow pulse | ✅ | `lib/features/home/widgets/play_now_button.dart` |
| Secondary float + press bounce | ✅ | `lib/features/home/widgets/secondary_button.dart` |
| Daily event chest burst | ✅ | `lib/features/home/widgets/daily_event_card.dart` |
| Currency counter pop | ✅ | `lib/features/home/widgets/currency_hud.dart` |
| Splash → Home transition | ✅ | `lib/app.dart` (AnimatedSwitcher) |
| Reward pop-up | 🚧 | Sprint 3 |
| World unlocked pop-up | 🚧 | Sprint 3 |

## 11. Anti-Animation (do NOT animate)

- ❌ Things that aren't interactive (inactive background cards).
- ❌ Load spinners that suggest "wait" with no real loading.
- ❌ Ads, pop-ups, attention bait.
- ❌ Multiple simultaneous overshoots (max 1 elastic per screen).
- ❌ Long-running full-screen effects (anything > 1500 ms blocks parent observation).

## 12. Animation → Code Snippet (canonical)

```dart
final playBounce = Tween<double>(begin: 0.92, end: 1.0).animate(
  CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
);
```

Single-source-of-truth for curves: `lib/core/motion/curves.dart` (Sprint 3).

---

**Document complete. v1.0 frozen.**
