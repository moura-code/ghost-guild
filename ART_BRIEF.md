# Ghost Guild — art brief

Rewritten on 2026-08-29 for the 3D pivot. The previous brief described a
2D pixel-art game; that direction is preserved on `2d-legacy`. The development
edition combines the 3D world with the shared management and inspection HUD.

The environment and interface load assets from the folders listed below.
Creatures and spirits are built in code from meshes attached to animated
joints; their entry points are listed alongside the file-backed assets.

Run it and look before starting: `godot --path .`, or render a still with
`godot --path . --rendering-method forward_plus --resolution 1280x720 -s tools/crawl_shot.gd -- out.png 3 30 0.35 [guild|fight|diag]`.

## The look, in one paragraph

A first-person crawl through a crypt, where the fighting is a card game. Wet
photoreal stone under warm torchlight, cold blue ambient in the gaps, real
shadows, fog that thickens the deeper you go. The dead are translucent cyan
and are the only genuinely bright thing down there. The 2D layer — cards,
panels, numbers — sits over it in bone-white on stone, and is the only thing
you read. References: *Legend of Grimrock*'s space, *Darkest Dungeon*'s
palette without its line weight, *Amnesia*'s light.

## The three rules that keep it from looking like an asset flip

"Asset flip" is a **coherence** failure, not a quality failure. It happens
when sources disagree. These are the agreements:

1. **One texel density.** Every surface repeats its texture every
   `Kit.TEXEL` = 2 metres, whatever the surface's size. `Kit._material`
   solves the uv scale from the span so a wall and the floor it meets never
   disagree about how big a stone is. `kit_test.gd` asserts it.
2. **One physical scale.** `Kit.CELL` = 3 m per grid cell, `Kit.WALL_H` =
   3.2 m. A human is `Player.HEIGHT` = 1.75 m. Nothing is authored to a
   different metre.
3. **One grade.** A single `Grade.environment()` — ACES tonemap, SSAO, glow,
   fog — over the whole game, on every floor and in the guild. Depth changes
   how much light is inside the grade; it never changes the grade.

## What exists, and what a delivered asset replaces

| Area | State | The one function to replace |
|---|---|---|
| Walls, floors, ceilings | **Done.** Procedural boxes and planes with CC0 ambientCG PBR sets | `Kit.floor_mesh` / `wall_mesh` / `ceiling_mesh` |
| Lighting and fog | **Done.** Torch pools, cold ambient, per-depth fog | `Grade.environment` |
| The guild | Room, five distinct stations: anvil table, ledger desk, séance candles, memorial Hall and well | `GuildRoom._plinth`, and the well head in `GuildRoom._build_well_head` |
| Props | **Done.** Eight CC0 Poly Haven models, placed by `Dressing` against walls, never blocking a route | `Dressing.CATALOGUE` |
| **Enemies** | Thirty enemies built from articulated bones, armor, weapons and growths. Spiders have eight legs; grubs have segmented bodies. | `CreatureRig.build`, `CreatureDetails.dress`, `CreaturePose` |
| **Ghosts** | Pleated burial shrouds, hollow hoods, glowing eyes and sleeves. Color reflects true, echo, prepared or restless state. | `GhostFigure._build` |
| Cards, panels, icons, fonts | Scalable Inter/Cinzel text, a compact combat HUD, larger card rules and explicit enemy health/intent. | `UiTheme`, `HandView`, `HeroPanel`, `EnemyTag` |

## Creature workflow

`EnemyShape` selects the movement archetype. `CreatureRig` builds jointed
anatomy, `CreatureDetails` attaches equipment and biome growths, and
`CreaturePose` supplies idle, flinch and collapse offsets. Keep new details
under the joint that should move them. Eye and ember names are collected by
`BoneMesh.lights_in` so death extinguishes them; `EnemyBody` fades every other
material with the corpse. Floating and low creatures use matching hitboxes.

The Catacombs equipment includes an archer's bow and quiver, the knight's
visor and sword, the warden's shield, plague vials and a bone crown. Fungal
variants carry caps and stalks; Kiln constructs carry furnace grilles and
exhausts. These are original procedural geometry, using the existing CC0
surface maps where appropriate.

Inspect the actual rigs in a neutral studio before checking dungeon light:

```sh
godot --path . -s tools/creature_shot.gd -- creatures.png bone_rat crypt_spider bone_archer hollow_knight plague_bearer
godot --path . -s tools/creature_shot.gd -- spirits.png ghosts
godot --path . -s tools/hud_shot.gd -- combat.png fight 50
```

The studio accepts any enemy IDs from `data/enemies/`. Both screenshot tools
run with a framebuffer; headless tests cover joint contracts, interaction,
layout and lifecycle behavior. HUD shots use a fixed clock and a disposable
save, including its backups, so repeated captures are comparable.

## Attribution

Every asset lands in `ATTRIBUTION.md` as it is added, not at the end.


## Hybrid presentation — 2026-09-06

`game/art/hero_figure.gd` builds the Sexton with a spade and lantern and the
Hexer with needle, charms and thimble. Both use the existing bone/material
helpers. `ModelPreview` instances these and the production `GhostFigure` in
a transparent, isolated 360×400 viewport with one unshadowed key light.
Hidden previews disable rendering and animation; each panel displays at most
one preview. Never reparent a live actor into a preview.

The UI uses persistent `PanelFrame` scroll surfaces, 100–150% scale, Inter
body text and Cinzel headings. Card inspection retains base/upgraded rules,
shows current modifiers and status explanations, and sorts draw composition
without exposing shuffle order. Reduced motion removes head bob, camera
shake and forced travel, ornamental drift and panel/card travel; the death
result and combat impacts remain visible.

Capture sizes are explicit and rendered natively, independent of desktop window
limits. For a production-room roster review, give the entry floor then enemy IDs:

```sh
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64
GG_PROFILE=review tools/launch.sh -s tools/hud_shot.gd -- /tmp/hero.png hexer 90 1280 720 1.25 es
GG_PROFILE=review tools/launch.sh -s tools/hud_shot.gd -- /tmp/kiln.png roster 90 1280 720 1 en 21 cinder_hound slag_crawler ember_wisp
GG_PROFILE=review tools/launch.sh -s tools/hybrid_bench.gd
```

See the hybrid validation record for the full 30-enemy review, UI captures and
measured hardware/renderer conditions. No lower-spec claim follows from those
measurements.
