# Visual Overhaul — Design Spec

**Version:** 1 · **Status:** approved 2026-08-24 · **Author:** brainstormed with Joao
**Parent spec:** `2026-08-21-ghost-guild-design.md` §9 (UI and aesthetic) — binding.
This document does not change the game design. It changes how it looks and moves.

## 0. Why

The vertical slice is complete and green (498 tests), and Joao's reaction to
looking at it was "I still don't like the visuals." That is the correct
reaction, and the cause is not a shortage of assets.

Twelve screens were captured from the running build and reviewed. They share
one visual idea — dim purple stone, white glyph on a coloured plate — applied
uniformly, and that idea is missing the three properties that make flat,
art-cheap games look expensive: **value range, focal hierarchy, and motion
outside the fight.**

## 1. The diagnosis, with the lines responsible

### 1.1 No value range

Every stone colour in `game/theme/palette.gd` sits between 4% and 42%
luminance, and every one of them is purple. There is no true black and no
bone white anywhere in a composition, so nothing separates from anything and
the frame reads as fog.

The comparison that settles it is `art_previews/mother_of_bones.png`, made by
this project's own SDXL pipeline: pure black shadow, bright bone highlight,
one cold light source. That image is the target and the UI palette
contradicts it.

### 1.2 The background outshines the content

`game/theme/crypt.gdshader` fills all 1280x720 with `stone = (0.19,0.17,0.26)`
— a mid-tone — and then:

- **Edge pillars brighten by 60%** (`col * 1.6 + accent * 0.028`). The two
  vertical bands at the extreme left and right edges are the brightest pixels
  on most screens. The eye goes to the frame instead of the game.
- **Arches darken by only 26%** (`dark = 0.74 - f * 0.06`, with a comment
  deliberately choosing "never much darker than the wall"). At that contrast
  they do not read as openings; they read as smudges, and the second rank
  reads as a rendering artifact.
- The vignette (`1.0 - dot(c,c) * 1.45`) is too weak to hold the centre.

### 1.3 Space is empty rather than composed

Séance is a black box with two numbers in one corner. Hero is a stock
pictogram over a text dump whose deck is `5x Strike / 4x Brace`. Event is
titled "An event" with three underlined text rows. Epitaph is 90% void. The
offline summary — the payoff of an idle game — is a dialog with an OK button.

### 1.4 Things are not things

Relics are a text row (`Grave Coin — 150`). Coin is a grey label. The deck is
a list. A ghost is one 14x20 shape. Nothing has object identity or weight.

### 1.5 Motion stops at the fight screen

`FightAnimator` is good work: float numbers, shake, hit-stop, particles, a
staggered beat per blow. Nothing else in the game moves. No flicker, no dust
in the idle screens, no counting numbers, no button response, no ambient life.

### 1.6 Defects found during the review

- `game/theme/icons.gd:21` hardcodes `.svg`. Dropping a `.png` into
  `assets/icons/card_art/` — **exactly what `ART_BRIEF.md` instructs an
  artist to do** — silently does nothing. The delivery contract is broken.
- `game/widgets/tower_view.gd:203` draws unexcavated rock across the full
  gutter-to-gutter rect instead of the tapered `chamber_rect`, erasing the
  shaft's perspective below floor 1. This is why the Ladder reads as a wall.
- Card body text is clipped mid-sentence in the reward picker and occluded
  by the neighbouring card in the fanned hand.
- The Soul balance is rendered only by `ladder_screen.gd`. The Guild and
  Séance — the two screens where Soul is spent — never show it.
- `ART_BRIEF.md` is stale: its "exact" palette table is wrong on nearly every
  value, its card-art section predates the 97 wired icons, and its backdrops
  section describes files deleted in `1e81f63`.

## 2. Principles

1. **One light source per screen.** Warm lantern light, cold near-black
   shadow. Complementary contrast is what Darkest Dungeon and Cultist
   Simulator run on; a single hue is what this game currently runs on.
2. **The background recedes. Always.** It is never brighter than the content
   and never more detailed. If the eye lands on the frame, the frame is wrong.
3. **Ghost cyan is the only cool accent in the game.** It is what the game is
   about, so nothing else is allowed to compete for it.
4. **Every number counts; it never snaps.** A number that jumps is a
   spreadsheet, a number that climbs is a game.
5. **Every screen has something alive on it** — flicker, drift, dust, a bob —
   even when the player is doing nothing.
6. **Generated art lands in a layout that can carry it**, which is why the
   composition work comes first and the art last.

## 3. Architecture

Nothing under `core/` changes. This is entirely `game/`, plus `tools/art/`.

### 3.1 The light model — `game/theme/palette.gd`, `crypt.gdshader`

Replace the six-value purple ramp with a ladder anchored at true black and
bone, and split light from surface:

| Role | Value | Note |
|---|---|---|
| `ABYSS` | `#04050a` | what everything falls off to |
| `STONE` | `#0d0f16` | |
| `STONE_RAISED` | `#161a24` | |
| `STONE_HIGH` | `#2b2f3d` | |
| `STONE_EDGE` | `#454a5c` | |
| `EDGE_LIGHT` | `#c9a86a` | **lantern warm** — was `#6b6390`, cold purple |
| `LANTERN` | `#ffe6b0` | lit surfaces, used at low alpha |
| `BONE` | `#f4efe4` | |
| `GHOST` | unchanged cyan | the only cool accent |

Shader changes: `stone` drops to roughly a quarter of its current value so it
is a *ground*, not a subject; edge pillars stop brightening and instead fall
into shadow; the second rank of arches is removed and the first is deepened
until it reads as an opening; the vignette is strengthened.

### 3.2 The focus rule — `game/theme/atmosphere.gd`

`Atmosphere` gains a `focus_rect: Rect2` (in screen space) and a radial
falloff toward `ABYSS` outside it. Each screen declares where its content
lives; everything else darkens. This is what gives every screen a subject.

`Atmosphere` also gains the ambient layer: lantern flicker driving light
intensity with low-frequency noise, and a slow fog drift. It already owns
motes and `pulse()`; this extends the same node rather than adding another.

### 3.3 The object layer — `game/widgets/props.gd` (new)

Reusable drawn decor, `_draw()`-based, no assets: candle with flame, hanging
chain, bone pile, banner, ritual circle, water drip, floor rubble. Screens
compose from these instead of leaving black space.

Consequences per screen: Séance gets a ritual circle with candles and stands
its dead inside it; Hero gets a fanned deck built from the existing
`CardView` plus relic plates; Event gets its own name as the title, a vellum
panel and carved choice plaques; Shop puts relics on a shelf as objects;
Soul and Coin become currency chips.

### 3.4 The motion layer — `game/theme/ticker.gd` (new)

A shared value-tweening helper: give it a Label, a formatter (`Num.short`,
`Num.rate`, …) and a target, and it counts. Applied to Soul, Coin, HP, yield
and the offline total. `Num` itself stays a pure static formatter.

Plus: hover lift and warm glow on buttons, saturated floors pulsing on the
Ladder, the waypoint marker animating when it moves, new ghosts easing into
their row, soul motes drifting up the shaft, and the offline summary
rebuilt as a payoff sequence that counts from zero.

### 3.5 The generated-art layer — `tools/art/generate.py`, `assets/`

Prerequisite: `Icons.get_icon` prefers `.png`, falls back to `.svg`, so both
the existing CC BY icons and new raster art coexist and the `ART_BRIEF`
contract becomes true.

`generate.py` gains `cards`, `enemies` and `relics` sets driven by the ids
already enumerated in `ART_BRIEF.md`: 30 card arts, 10 enemy portraits, 6
relics, the ghost, 3 biome backdrops, the capsule. Output goes to `assets/`
(shipped) rather than `art_previews/` (throwaway).

**Two constraints on this layer.** Card art renders at 1024² and displays at
122x74; atmosphere survives that downscale, fine detail does not, so prompts
ask for a single silhouette and one focal shape. And shipping generated art
requires ticking Steam's AI-content disclosure at store setup — Joao's call,
made on 2026-08-24.

## 4. Verification

Pixels cannot be asserted, so this spec adds the loop instead of tests for
appearance:

- `tools/screenshot.gd` gains an `all` mode writing every screen plus a
  contact sheet in one command. One command, one look, after every change.
- Screen behaviour keeps the existing state-based test discipline. Colours
  and geometry get tests only where a *rule* exists to assert — that the
  background is darker than the content it sits behind, that a focus rect
  covers the content, that a ticker reaches its target and stops.
- The suite stays green at every commit; 498 tests is the floor.

## 5. Order of work

Foundation (light model, focus rule) → the six defects in §1.6 → object layer
→ motion layer → generated art. Foundation first because every later choice
is made against the new light model; art last because it should land in a
layout that can carry it.

## 6. Out of scope

Sound (unscoped everywhere, and the single largest remaining feel gap after
this work — it needs its own spec). Localisation of the new strings beyond
the existing key discipline. Any change to `core/`. Any change to game rules,
balance or content values.
