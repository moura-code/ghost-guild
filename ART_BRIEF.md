# Ghost Guild — art brief

Rewritten on 2026-08-29 for the 3D pivot. The previous brief described a
2D pixel-art game; that direction is on `main` and is not what this branch
builds.

Everything below is **already wired**. The game reads these folders at
startup and falls back to a placeholder when a file is missing, so a
delivered asset appears in the build with no code change. Deliver one file,
see it in the game.

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
| The guild | **Done, unpolished.** Room, four stations, well, shaft | `GuildRoom._plinth`, and the well head in `GuildRoom._build_well_head` |
| Props | **Done.** Eight CC0 Poly Haven models, placed by `Dressing` against walls, never blocking a route | `Dressing.CATALOGUE` |
| **Enemies** | **PLACEHOLDER**, but five distinguishable silhouettes (humanoid, beast, wisp, stack, hulk) with per-archetype idles rather than one capsule for everything | `EnemyShape.build` + `EnemyBody.recoil` / `die` |
| **Ghosts** | **PLACEHOLDER.** Translucent capsule stand-ins | `GhostFigure._build` |
| Cards, panels, icons, fonts | **Done**, carried over from the 2D game unchanged | — |

## The open question: enemies

This is the only part of the pipeline that is not proven, and it has been
the open question since stage 0.

Environments are solved: CC0 PBR materials are effectively unlimited, legally
clean, and with correct texel density and torchlight they read as a
commercial game with no art skill. **Creatures are not.** They need a rig and
at minimum four animation states — idle, attack, take hit, die.

What is known:

- The rigged-animation **pipeline works**. A skinned humanoid imports from
  glTF, animates, takes torchlight, casts a real shadow and stands at correct
  scale under Forward+ (proven in stage 0 with a borrowed model).
- Godot 4.7.2 has `ufbx` compiled in, so FBX imports natively — Mixamo's
  export format needs no converter.
- **Mixamo has no usable API.** `/api/v1/characters` returns 401 and
  `/api/v1/products` 403 without an Adobe IMS session. Downloads are manual.
- Poly Haven has no characters. Quaternius has CC0 rigged monsters but they
  are explicitly low-poly and will clash with photoreal stone.

The roster is ten enemies, of which **four need no humanoid rig** —
`grave_wisp`, `skull_stack`, `crypt_spider`, `bone_rat` — and six do,
including the boss `mother_of_bones`.

Everything around the model is finished and model-agnostic: staging,
targeting, the event-driven animator, the HUD, the death fall. Dropping in a
creature is one function and an `AnimationPlayer`.

## Attribution

Every asset lands in `ATTRIBUTION.md` as it is added, not at the end.
