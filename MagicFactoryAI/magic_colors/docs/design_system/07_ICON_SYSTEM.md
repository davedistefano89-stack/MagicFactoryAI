# 07 — Magic Colors · Icon System
**Document:** Official Iconography v1.0
**Audience:** Designers, illustrators, engineers
**Status:** v1.0 baseline

---

## 1. Icon Philosophy

Icons in Magic Colors serve three roles:

1. **Recognition** — visual shortcut for a feature or state.
2. **Affordance** — communicates an action ("tap me").
3. **Emotional cue** — mascot or character iconography, friendly tone.

Children 3–4 cannot read words; they must identify features by **shape + color**. Therefore every icon must:

- Be recognizable at 24 dp (the smallest legal tap target).
- Use no thin strokes (min stroke 2.4 dp at 24 dp scale).
- Use no detail that disappears at 16 dp.
- Be **shape-distinct** (not just color-distinct) for color-blind users.

## 2. Visual Style

| Aspect | Rule |
|---|---|
| Stroke | 2.4 dp at 24 dp, 3 dp at 32 dp, 3.6 dp at 48 dp |
| Fill | Solid where the icon is "primary object"; outline where it is "secondary" |
| Corner | Always rounded radius ≥ 1 dp; never sharp |
| Padding | 2 dp inside bounding box |
| Two-tone | Allowed but never more than 2 colors per icon |
| Style | Friendly, soft, slightly bouncy (slight asymmetry adds life) |
| Forbidden | Sharp claws, scary faces, weapons, religious symbols, brand logos of competitors |

## 3. Sizes (canonical export sizes)

| Context | Size |
|---|---|
| Bottom Nav | 32 dp |
| Top HUD | 24 dp |
| Buttons (secondary) | 32 dp |
| Reward popups | 48–64 dp |
| Locked badges | 28 dp |
| Settings (mobile) | 24 dp |
| Settings (desktop, future) | 20 dp |
| Marketing | 128 dp + SVG master |

## 4. The Icon Catalog (v1.0)

### 4.1 Currency icons (Tier-3 reward colors)

- **Coin** — CustomPaint gold circle with rune face. Halo 8 dp.
- **Gem** — Royal-blue diamond with 4 facets. Halo 8 dp.
- **Star** — 5-pointed white-gold star with center highlight.
- **Heart** — Coral heart with rounded top.

### 4.2 Tool icons (palette screen)

- **Brush** — flat paintbrush with single paint drop dripping.
- **Pencil** — tilted pencil with eraser end visible.
- **Bucket** — bucket with handle and a small splash.
- **Marker** — coloring marker with smiling face stickers.
- **Crayon** — chubby crayon with wax tip.
- **Glitter** — sparkle cluster (3 sizes).
- **Pattern brush** — brush with pattern swatch behind it.
- **Stamp** — flat hand silhouette + stamp shape.

### 4.3 Navigation icons

- **Home** — house outline with heart-shaped window.
- **Worlds** — globe with little sparkles dotting it.
- **Gallery** — picture frame with mountain sun motif.
- **Shop** — shopping bag with heart on the front.
- **Profile** — circular avatar ring with sparkle.

### 4.4 Utility icons

- **Settings** — gear with 6 rounded teeth and central heartbeat pulse.
- **Parents** — shield with check inside.
- **Premium** — crown with single star on top.
- **Sound** — speaker with wave lines.
- **Music** — eighth note with sparkle.
- **Help** — question mark inside balloon.

### 4.5 Action icons (in-game)

- **Undo** — curved arrow returning to start position.
- **Redo** — curved arrow returning forward.
- **Save** — floppy disk with star sticker.
- **Print** — printer with paper.
- **Share** — square with rising heart.
- **Reset** — circular arrow with sparkle (NEVER red — keep positive).
- **Confirm** — checkmark inside soft squircle.
- **Cancel** — gentle X inside soft squircle (only in Parents Area).

### 4.6 Magic / decoration icons

- **Magic Wand** — wand with star tip and trailing sparkle.
- **Sparkle** — 4-pointed star with rounded indent.
- **Magic Burst** — bigger sparkle (use for premium animation only).

### 4.7 Achievement icons

- **Trophy** — gold cup with star ribbon.
- **Certificate** — scroll with star and ribbon.
- **Crown** — ornament above all achievement icons.
- **Heart Badge** — coral heart inside white circle.

### 4.8 World entry icons (per world)

- **Unicorn** — pixel silhouette, 1 dp stroke.
- **Princess** — silhouette with tiara.
- **Animal** — paw print style (multi-animal weighted average).
- **Mermaid** — silhouette with fishtail.
- **Space** — small rocket.
- **Christmas** — snowflake.
- **Halloween** — pumpkin.
- **Dinosaur** — silhouette T-rex head.
- **Dragon** — silhouette dragon head.
- **Fantasy** — multicolor star.

## 5. Color Rules

Each icon has a **default tint**. Tints follow Token Rules:

- Default tint = Deep Ink `#0F1226`.
- On Tier-1 background: White `#FFFFFF`.
- On Tier-3 reward widget: the reward color itself.
- On Parents Area buttons: Deep Ink + Tier-4 Info `#5BB8FF` accent.

Color is **never** the only cue — every icon also has its unique shape and stroke.

## 6. State Variants

Every stateful icon must have 4 explicit variants:

| State | Visual change |
|---|---|
| Default | Standard fill |
| Hovered | 8 % lift shadow |
| Pressed | 5 % scale + 8 % darker fill |
| Disabled | 30 % opacity (only in Parents Area; child zone has no disabled state) |

## 7. Custom-Painted Icons vs Vector

Today (Sprint 1): **CustomPaint-rendered** to avoid asset heavy lifting. Use Flutter Path API for any icon ≥ 32 dp.

Future (Sprint 3+): **SVG** via `flutter_svg` for the full mastery set. Need an SVG master + 4 PNG sizes per icon.

Hard rule: **no iconography should ever be downloaded at runtime** — all icons compile into the bundle.

## 8. Accessibility

- Every icon must be paired with a **label or text** when interactive (use `Semantics(label: '...')` widget).
- Icons that are decorative only (no tap action) must have `excludeFromSemantics: true`.
- Tap targets containing only an icon must be at least 56 × 56 dp.
- Icon size must respect the OS dynamic type scale by ± 20 % maximum (no infinite growth).

## 9. Icon Implementation Status

| Icon family | Status | Implementation in code |
|---|---|---|
| Coin / Gem / Star / Heart | ✅ | `lib/features/home/widgets/currency_hud.dart` |
| Sparkle | ✅ | `lib/features/splash/widgets/sparkle_field.dart` + home animations |
| Mascot | ✅ | `lib/core/widgets/mascot.dart` |
| Bottom Nav | 🚧 | Sprint 3 |
| Action (Undo/Redo/etc.) | 🚧 | Sprint 4 (in-game) |
| Setting (gear, etc.) | 🚧 | Sprint 4 (Parents Area) |

## 10. Anti-Iconography (do NOT make icons into...)

- ❌ No copyrighted brand logos of any kind.
- ❌ No violence (no swords, no realistic guns).
- ❌ No medication pills, real-looking food, fast food logos.
- ❌ No realistic scary faces (clown face, ghost face).
- ❌ No real currencies or money symbols.
- ❌ No competitive sports logos.
- ❌ No religious icons (crosses, crescents, etc.).

## 11. Icon Donations

We accept community icon donations under OFL or CC-BY license, posted via Discord. Every donation is screened by a designer before shipping.

---

**Document complete. v1.0 frozen.**
