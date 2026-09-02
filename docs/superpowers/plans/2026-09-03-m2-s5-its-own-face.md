# M2 Stage 5 — The game wears its own face

Two findings from the last two stages, both about the game looking like itself,
one in the HUD and one in the world.

## Finding 1: the theme is never applied

`UiTheme.build()` is constructed only in tests. Measured on a live `HudRoot`:

```
label    font=Open Sans SemiBold size=8   height=12.0
button   font=Open Sans SemiBold size=16  height=23.0
```

So the HUD draws in Godot's default face, and every `Button`, `PanelContainer`
and scrollbar stylebox in `build()` — the whole carved `StoneBox` treatment,
the lit top edge, the corner pegs, the pressed-in bevel — is dead code. The
screens that look carved are the ones whose authors called
`add_theme_stylebox_override` by hand.

And the fonts it *would* have applied are wrong anyway. `BODY_FONT_PATH` points
at Silkscreen and `TITLE_FONT_PATH` at PixelifySans — the pixel faces from the
2D direction that §3.2 of the pivot spec says "dies with `PaletteLayer`". The
docstrings above those constants still say Inter and Cinzel, which are the
faces the spec asks for (§9: "a display serif for titles, a humanist sans for
body and numbers") and which are sitting in `assets/fonts/` unused.

A pixel face over photoreal PBR stone would be a worse clash than the accident
we have. So this is not "apply the theme" — it is "point the theme at the right
faces, then apply it."

## Finding 2: the Deep is made of Catacombs

The second biome ships with the first biome's walls, floor and ceiling. The
accent, the fog and the banner carry the whole difference. Standing in it, the
only thing that says "somewhere else" is the colour of the air twenty metres
away.

The pivot spec's own answer (§7): "materials carry most of the realism; the
supply is effectively unlimited and legally clean." The Deep needs its own
stone, and `Kit` needs to be able to ask which biome it is building.

## Batches

### Batch A — the right faces, actually applied

**Files:** `game/theme/ui_theme.gd`, `game/hud/hud_root.gd`, layout constants,
tests, a render of every screen.

Cinzel for titles, Inter for body and numbers. `hud.ui.theme = UiTheme.build()`.

The risk is not the font — Inter at 8px and Open Sans at 8px are within a
hair of each other, which is exactly why nobody caught this. The risk is the
**styleboxes**, which have never been applied to anything that did not ask for
them: `StoneBox` has content margins of `max(6, bevel*2)` and a minimum size of
`bevel*2`, so every unstyled Button and PanelContainer in the game is about to
get 12px of padding it has never had. Every panel gets re-rendered and every
layout constant that moves gets fixed.

### Batch B — the Deep is made of different stone

**Files:** `game/world/kit.gd`, `game/world/dungeon_builder.gd`,
`assets/materials/` (new CC0 sets), `ATTRIBUTION.md`, tests, renders.

`Kit` takes a biome and returns that biome's materials, cached per biome rather
than per surface. New CC0 PBR sets from ambientCG for the Deep — something wet,
organic and cold against the Catacombs' dry warm brick — resampled to the same
texel density, because one texel density across the kit is the discipline that
stops mixed CC0 sources reading as an asset flip.

The Catacombs' materials do not change. Every judgement about the look was made
in them.

### Batch C — whatever the renders say

Reserved. The first two batches will produce twenty screenshots and the list
comes from those rather than from here.

## Self-review

Batch A is the one that can go wrong quietly, and not in a way a test sees: a
panel whose content now overflows still draws, it just draws past its frame.
The only real check is looking at every screen, which is why the batch is
defined as "render every screen" rather than as "apply the theme".

Batch B has the opposite risk — that the Deep ends up looking like a different
*game* rather than a different place. The grade is shared and stays shared;
what changes is the stone. If the two biomes stop reading as one dungeon, the
materials are wrong and not the plan.

---

## Executed

All three batches, plus one the renders added.

### Batch A — the right faces, actually applied

`BODY_FONT_PATH` → Inter, `TITLE_FONT_PATH` → Cinzel, `ui.theme = UiTheme.build()`
in `HudRoot`. Silkscreen and PixelifySans deleted: two milestones of dead
weight in the build, and the reason the mistake survived so long is that
`ATTRIBUTION.md` had been describing Cinzel and Inter the whole time.

Every screen was rendered. Three things broke, none of which a test could see:

**Every panel wore a stock blue focus rectangle.** Godot draws its own rounded
blue box for any Button state the theme leaves undefined, and something always
has focus — so the moment the theme was applied, every screen in the game had
one bright blue Godot control on it. The theme defines `normal`, `hover`,
`pressed` and `disabled` and had never needed `focus`, because it had never
been applied. `test_nothing_falls_back_to_a_stock_godot_box` now walks all five.

**The upgrade tablets overflowed.** `PLAQUE_SIZE` was 85×90 and the carved
frame's own content margins are 16 of them; a two-line name pushed the price
button onto the bottom edge. Godot reports an autowrapped Label's minimum
height as one line, so this is not measurable from inside the engine — the
check is looking at the wall. Now 98.

**A hovered reward card printed over the screen's title.** The gap budgeted for
the lift was `HOVER_LIFT`, but a card also scales about its own centre as it
lifts, so it reaches `HOVER_LIFT + height × (scale − 1) / 2`. That is
`CardView.hover_headroom()` now, and the spacer that uses it had to move above
the fan rather than below it — the cards are not in `_options`.

### Batch B — the Deep is made of different stone

Three CC0 ambientCG sets: Rock023 (fractured strata) for the walls, Ground068
(moss and rot) for the floor, Rock030 for the ceiling. `Kit.BIOME_STONE` maps a
biome to its three surfaces and three tints, falling back to the Catacombs — so
a biome can land in `data/` before its materials are downloaded and get a room
rather than a crash.

Four candidates were rejected by looking at them: Moss004 is a golf course,
Ground037 and Ground054 are daylight woodland and flat sand. All three are
photographs taken outdoors, and the thing they have in common is that nothing
fourteen floors underground looks like that.

Then the first render was a violet-black murk you could not read a corridor in,
because the fog tint from stage 3 had been carrying the whole difference on its
own and was now double-counting against grey rock and a dark floor.
`BIOME_FOG_TINT` went 0.34 → 0.18 and `BIOME_FILL_TINT` 0.20 → 0.12. **The air
says where you are; the walls say it too now, and they should not both shout.**

### Batch C — the enemies are made of something

Not in the plan; the fight render put it there. Every creature in the game was
a flat untextured colour on a smooth primitive — standing against a wall with
a normal map, a roughness map and ambient occlusion. That is a shop mannequin
however good the silhouette is, and it was the ugliest object in the frame.

`EnemySkin` gives them the kit's own stone, projected **triplanar** so
code-built spheres and capsules need no UVs, a tint read off the enemy's own
tags (fungal violet, construct iron, flesh dull red, undead bone), and a rim
light so a body at the edge of the torchlight is a shape rather than a hole.
One material per creature, not per type, because `EnemyBody` fades its own
albedo as it dies and a shared material would take the whole floor with it.

Still a stand-in. A rigged model replaces `EnemySkin` and `EnemyShape.build`
together and nothing else changes.

**And the enemy tags.** Once everything else was carved stone, the name-and-
health plate over each creature was the one flat rectangle left on screen. It
draws a `StoneBox` and the same banded, lit health bar the hero's own panel
uses — which existed in `UiTheme.draw_health` and the tag had never called.

### Notes for later

- The Deep's ceiling is the weakest surface in either biome: Rock030 at this
  texel density reads as speckle. Darkened so it recedes, not solved.
- `Kit.BIOME_STONE` has no entry for The Kiln, which is the fallback working as
  intended — but it means the Kiln will look like the Catacombs on the day its
  content lands and before its materials do.
