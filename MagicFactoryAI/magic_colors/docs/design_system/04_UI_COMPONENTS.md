# 04 — Magic Colors · UI Components
**Document:** Official Component Library v1.0
**Audience:** Designers, engineers, QA
**Status:** Frozen baseline

---

## 1. Design Tokens (top of the component tree)

All components consume tokens from `app_colors.dart`, `app_typography.dart`, `app_shape.dart`, and `app_gradients.dart`. A component without a token source is forbidden.

```dart
// Magic Colors · canonical paddle outline (every primary CTA uses this shape)
class AppShape {
  static const radiusLg = 28.0;   // CTA, large card
  static const radiusMd = 20.0;   // small card, button
  static const radiusSm = 12.0;   // chip, pill
  static const radiusXs = 6.0;    // tag

  static const elevation1 = [
    BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
  static const elevation2 = [
    BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
}
```

## 2. Buttons

### 2.1 Primary Button — **PLAY NOW (BigButton)**

| Aspect | Spec |
|---|---|
| Size | min height 88 dp, width ≥ 280 dp |
| Radius | `radiusLg` (28 dp) |
| Gradient | Magic Pink → Magic Purple |
| Text | `buttonLg` Baloo 800/30 sp, white |
| Shadow | `elevation2` with pink glow `Color(0xFFFF4F9A).withAlpha(80)` |
| Idle | Static |
| Pressed | Scale to 0.96, gradient brightens 8% |
| Idle micro-animation | Glow pulses every 1800 ms |
| Sound | `MagicSound.bigTap` on press |

```dart
final playNow = BigButton(
  gradient: AppGradients.playNow,
  label: 'PLAY NOW',
  onTap: () { /* keep <= 1 line */ },
);
```

### 2.2 Secondary Buttons (5 in home grid)

| Aspect | Spec |
|---|---|
| Size | 88 × 88 dp minimum, expandable to 120 |
| Radius | `radiusMd` (20 dp) |
| Gradient | One per button (see table) |
| Icon | Centered, 32 dp, white |
| Label | `buttonMd` Baloo 700/20 sp, white |
| Idle | Static |
| Pressed | Scale 0.95 + tilt 2° |
| Idle micro-animation | Subtle 1 px floating |

| Label | Gradient | Icon |
|---|---|---|
| Collection | Mint Leaf → Lagoon | AlbumIcon |
| Rewards | Coin Gold → Tangerine | ChestIcon |
| Shop | Sky Cyan → Magic Purple | CartIcon |
| Parents | White → Soft Pink | ShieldIcon |
| Premium | Rainbow shimmer (animated) | CrownIcon |

### 2.3 Tertiary Button (chip)

| Aspect | Spec |
|---|---|
| Size | height 44 dp, padding 12 dp horizontal |
| Radius | `radiusSm` (12 dp) |
| Fill | White surface with 8% tint of gradient |
| Text | `labelMd` Nunito 700/14 sp |
| Pressed | Scale 0.97 |

### 2.4 Text Button (e.g. "Skip", "Not now")

| Aspect | Spec |
|---|---|
| Text | `bodyMd` Nunito 500/16 sp |
| Color | Deep Ink (no underline by default) |
| Pressed | 50% tint over 80 ms |

## 3. Cards

### 3.1 Daily Event Card

| Aspect | Spec |
|---|---|
| Size | full-bleed minus 16 dp margin, height 156 dp |
| Radius | `radiusLg` (28 dp) |
| Gradient | Magic Pink → Magic Purple, top-left lit |
| Surface | Image bubblegum cloud behind text |
| Hero illustration | Floating chest with cheek-glow eyes |
| Text | Title `titleSm` Baloo 700/22 sp; Reward `labelMd` Nunito 700/14 sp |
| CTA | Inline pill: "Open Chest" — Tertiary Button with white surface |
| Idle animation | Chest breathes (8 % scale, 1800 ms) |
| On press | Sparkle burst from chest |

### 3.2 World Card (in Worlds list)

| Aspect | Spec |
|---|---|
| Size | grid of 2 columns, aspect 0.85 |
| Radius | `radiusLg` (28 dp) |
| Image | World illustration fills card |
| Title overlay | Bottom strip, gradient Bubble Pink to transparent, `titleSm` |
| Lock badge | Top-right, 32 dp, gold, only on locked cards |
| Pressed | Scale 0.97 |

### 3.3 Achievement Card (toast)

| Aspect | Spec |
|---|---|
| Size | full-bleed minus 32 dp margin, height 96 dp |
| Radius | `radiusMd` (20 dp) |
| Fill | White with 90 % opacity |
| Icon | Left, 56 dp circle, world-specific |
| Title | `titleSm` Baloo 700/22 sp Deep Ink |
| Tap | Auto-dismiss 2.4 s |

### 3.4 Reward Pop-Up Card

| Aspect | Spec |
|---|---|
| Size | Centered modal 320 × 320 dp |
| Radius | `radiusLg` + 16 dp inner glow |
| Fill | Rainbow gradient (60° tilt) |
| Confetti | CustomPaint field, 24 particles |
| Primary text | "WOW! +50" `displayXl` Baloo 800/44 sp |
| Subtext | "You earned a chest!" `bodyLg` Nunito 600/18 sp |
| CTA | "Continue" big button, 56 dp tall |
| Sound | `MagicSound.reward` on appear |

## 4. Dialogs

### 4.1 Confirmation dialog

| Aspect | Spec |
|---|---|
| Size | width 320 dp max, padding 24 dp |
| Radius | `radiusLg` |
| Background | White 96 % opacity + 6 dp shadow |
| Title | `titleMd` Baloo 700/28 sp center |
| Body | `bodyMd` Nunito 500/16 sp center, max 2 lines |
| Buttons | Two pill buttons side by side, equal weight |

### 4.2 Tutorial dialog

| Aspect | Spec |
|---|---|
| Same as confirmation | + mascot waving + tip pointer |
| Pointer | Soft pink arrow path to teachable element |
| Skip link | Tertiary button top-right |
| Progress | 1/N dot indicator, Max 3 steps |

## 5. Badges & Tags

### 5.1 Notification Bubble

| Aspect | Spec |
|---|---|
| Position | Top-right of parent widget |
| Size | 20 dp circle minimum, scale 1.0 → 1.3 → 1.0 on appear |
| Fill | Coral, white center digit |
| Animation | Scale bounce + 4 sparkle particles |
| Sound | `MagicSound.notification` |

### 5.2 Tag Chip

| Aspect | Spec |
|---|---|
| Size | padding 8×16 dp, height 32 dp |
| Radius | `radiusSm` |
| Fill | White 70 % with stroke (Tier-1 color, 1 dp) |
| Text | `labelMd` Nunito 700/14 sp |

### 5.3 World Badge (filled on completion)

| Aspect | Spec |
|---|---|
| Size | 88 × 88 dp circular |
| Background | Rainbow gradient |
| Star | Center, gold, 56 dp |
| Pressed | Pulse glow |

## 6. Currency Widgets

### 6.1 Coin Widget

| Aspect | Spec |
|---|---|
| Size | 32 × 32 dp |
| Glyph | CustomPaint gold coin with `$` rune face, $scale = 0.92 |
| Halo | Glow radius 8 dp, rgba(255,233,127,0.55) |
| Animation on increment | Pop 1 → 1.2 → 1.0 over 320 ms |
| Animation on spend | Fall + small puff |

### 6.2 Gem Widget

| Aspect | Spec |
|---|---|
| Size | 32 × 32 dp |
| Glyph | CustomPaint royal-blue diamond, 4 facets |
| Halo | Glow radius 8 dp, rgb(140,180,255,0.55) |
| Animation | Sparkle facets rotate at 6° per second |

### 6.3 Currency HUD (top-bar)

| Aspect | Spec |
|---|---|
| Layout | Two pill-shaped containers, left-aligned |
| Container size | 96 × 36 dp, radius `radiusSm` |
| Spacing | 8 dp between pills |
| Fill | White 70 %, stroke Tier-1 color 1 dp |
| Typography | Value `numericXl` Baloo 800/28 sp |
| Animation | Float-bouncing digit when value changes |

## 7. Progress Bars

### 7.1 World Progress Bar

| Aspect | Spec |
|---|---|
| Size | full-width minus margins, height 12 dp |
| Radius | `radiusXs` |
| Track | Bubblegum Pink 30 % opacity |
| Fill | Rainbow shimmer (animated left → right) |
| Indicator | Star at the current fill position |

### 7.2 Star Reward Progress (in completion card)

| Aspect | Spec |
|---|---|
| Layout | 3 stars, 28 dp each, evenly spaced |
| State | Empty / Half / Filled (animated transition 320 ms) |

### 7.3 Daily Goal Slider

| Aspect | Spec |
|---|---|
| Range | 0 to 5 pages, integer steps |
| Thumb | 32 dp, star-shaped |
| Track | Coral / Aqua gradient by mood |

## 8. Navigation

### 8.1 Bottom Navigation

| Aspect | Spec |
|---|---|
| Size | height 80 dp + safe-area inset |
| Radius | Top corners `radiusLg` |
| Fill | White 95 %, blurring behind 12 dp |
| Icons | 32 dp, single tint when idle, Tier-1 color when active |
| Labels | `labelLg` Nunito 700/16 sp when active; absent when idle |
| Badge | Top-right of icon, 12 dp |
| Toggle | 220 ms `Curves.easeOutCubic` background fade-in |

### 8.2 Top Tab Strip

| Aspect | Spec |
|---|---|
| Size | height 48 dp |
| Indicator | 3 dp rainbow underline (Magic Purple → Magic Pink) |
| Tab text | `labelLg` Nunito 700/16 sp |

### 8.3 Breadcrumb Bar (Parents Area)

| Aspect | Spec |
|---|---|
| Padding | 16 dp horizontal |
| Items | `bodyMd` Nunito 500/16 sp Deep Ink, separated by `/` |
| Active | `bodyMd` Nunito 700 Magenta |

## 9. Pop-Ups

### 9.1 World Unlock Pop-Up

Triggered on first unlock. Visual specs identical to Reward Pop-Up Card.
Special: green star + world illustration.

### 9.2 Daily Streak Pop-Up

Triggered on streak milestones (3, 7, 14, 30 days). Adds a calendar mini-card inside Reward Pop-Up.

### 9.3 Shop Excited Popup

Triggered when limited pack is available (fashion: gentle, non-urgent). Banner-shaped (368×88 dp) with countdown timer visual (chevrons only, no numbers — children find numbers stressful).

## 10. Store Card (in Shop)

| Aspect | Spec |
|---|---|
| Size | grid of 2 columns, aspect 0.9 |
| Radius | `radiusLg` |
| Image | Pack illustration top half |
| Title | `titleSm` Baloo 700/22 sp |
| Sub | `bodyMd` Nunito 500/16 sp |
| Price | `buttonLg` Baloo 800/30 sp, gold gradient pill |
| On press | Reward Pop-Up preview |

## 11. Sliders (Settings)

| Aspect | Spec |
|---|---|
| Track | Bubblegum pink 30 % |
| Fill | Magic Purple 100 % |
| Thumb | 32 dp white circle, Tier-1 stroke |
| Tick labels | `bodySm` Nunito 500/14 sp |

## 12. Avatar Widget

Used for parent profile.

| Aspect | Spec |
|---|---|
| Size | 56–96 dp |
| Ring | Tier-1 color 2 dp stroke |
| Glow on hover | 6 dp, 30 % opacity |

## 13. Component Catalog (status)

| Component | Status | Implemented in |
|---|---|---|
| BigButton (PLAY NOW) | ✅ | `lib/features/home/widgets/play_now_button.dart` |
| Secondary Button | ✅ | `lib/features/home/widgets/secondary_button.dart` |
| Bottom Nav | ✅ | `lib/features/home/widgets/bottom_nav.dart` |
| Currency HUD | ✅ | `lib/features/home/widgets/currency_hud.dart` |
| Daily Event Card | ✅ | `lib/features/home/widgets/daily_event_card.dart` |
| Mascot Widget | ✅ | `lib/core/widgets/mascot.dart` |
| Animated Background | ✅ | `lib/features/home/widgets/animated_background.dart` |
| Reward Pop-Up | 🚧 | Sprint 3 |
| World Card | 🚧 | Sprint 3 |
| Slider | 🚧 | Sprint 4 (Parents Area) |
| Store Card | 🚧 | Sprint 4 |

---

**Document complete. v1.0 frozen.**
