# Ghost Guild in 3D — Pivot Design Spec

**Date:** 2026-08-29 · **Status:** approved for planning · **Engine:** Godot 4.7.2, Forward+ · **Branch:** `3d-pivot`
**Supersedes:** spec §9 (UI and aesthetic) of `2026-08-21-ghost-guild-design.md`, and all of `2026-08-24-visual-overhaul-design.md`.

## 0. What changes, in one line

The dungeon stops being a menu and becomes a place: you walk the crypt in first
person, and the card fight happens where you are standing.

Everything about *what the game is* — the card combat, the run structure, the
ghost economy, the balance — is unchanged. What changes is that the player's
interface to a floor is a body in a corridor instead of a list of three buttons.

## 1. The four decisions this spec encodes

Taken with the developer on 2026-08-29, in this order, each one narrowing the next:

1. **The card game survives.** This is a first-person dungeon crawler whose
   combat is the existing card engine — not a new genre, and not a 3D restaging
   of the same menus.
2. **Movement is free first-person** (WASD + mouselook), not grid-stepped.
3. **The look is textured PBR realism**, not low-res pixel 3D and not flat-shaded
   low-poly. The renderer moves to Forward+.
4. **The guild is a walkable place**, not a panel over a backdrop: an upgrade
   table, a séance circle, and a well you look down to see your ghosts.

Decisions 2 and 3 were taken against a recommendation. Both were reaffirmed;
this spec commits to them and §4 and §7 exist to make them work rather than to
relitigate them.

## 2. Design pillars added by the pivot

The six pillars of the original spec stand. The pivot adds three, and each one
must be visible in the game or the pivot did not pay for itself:

1. **The dead are in the room with you.** A ghost is not a row in a ladder; it
   is a figure standing in the corridor on the floor where it died, still
   working, that you walk past on your way deeper. The core pitch stops being
   explained and starts being seen.
2. **The world is data.** Level geometry is generated from a pure, seeded,
   headless-testable layout. Physics lives only in the presentation layer and
   never feeds back into the simulation. This is what keeps `core/` honest.
3. **Depth is the threat.** Darkness, fog and the reach of your own torch are
   the difficulty made physical. A floor 20 corridor should feel different from
   a floor 2 corridor before a single card is played.

## 3. What survives and what is replaced

### 3.1 Untouched

Baseline on the day of the pivot: **576 test cases across 60 suites, all green,
exit 0** (2min 43s). That number is the regression net this spec is written
against, and §10 exists to keep the `core/` share of it green throughout.

- **`core/` — 3,762 LOC, 31 test suites.** Combat, ghosts, economy, onboarding,
  save, content, RNG. The one exception is a contained change to `core/run/`
  described in §5.
- **`data/` — all of it.** Cards, enemies, relics, biomes, classes, events,
  upgrades, strings. Content is unaffected by presentation.
- **`tools/`** — `fight_demo`, `run_demo`, `campaign_demo`, `balance_sim` all
  keep working, because they drive `core/` headlessly and never touched the UI.
- **`assets/fonts/`, `assets/icons/`** — still used by the HUD and the cards.

### 3.2 Replaced — `game/`, 7,486 LOC, 28 test suites

Every `Control`-based screen goes. Four things are rescued:

| Kept | Why |
|---|---|
| `game/game.gd` (`GameRoot`) | Still the only bridge between the `RefCounted` core and the scene tree. Its contract does not change. |
| `game/util/num.gd` | Number formatting is presentation-neutral. |
| `game/theme/sfx.gd` | The voice pool survives; 3D positional audio is added around it. |
| `game/widgets/card_view.gd` | **Cards stay 2D on a HUD.** A card rendered in perspective is a card you cannot read. This is a deliberate design position, not a shortcut. |

Explicitly deleted: `palette_layer.gd` (whole-frame palette snap), `atmosphere.gd`
(the 2D shader ground), `props.gd`, `stone_box.gd`, `tower_view.gd`,
`doorway_view.gd`, `ghost_line.gd`, `ghost_mark.gd`, `screen_layout.gd`,
`transition.gd`, and every screen under `game/screens/` and `game/run/`.

The pixel-art direction dies with `PaletteLayer`. `ART_BRIEF.md` is rewritten;
`ATTRIBUTION.md` is extended, not replaced — the fonts and icons stay credited.

### 3.3 `project.godot`

- `renderer/rendering_method` → `forward_plus` (from `gl_compatibility`)
- remove `window/stretch/mode="viewport"` and the 640x360 viewport; the game
  renders at native resolution with `canvas_items` stretch for the HUD
- remove `textures/canvas_textures/default_texture_filter=0`
- add an input map: move, look, interact, sprint
- add physics layers: world, player, interactable, ghost

This raises the minimum hardware spec. That is an accepted cost of decision 3.

## 4. The determinism problem, and how free movement keeps it

`core/` is deterministic on purpose. The fight autopilot, Expeditions, ghost
strength simulation and the balance simulator all run **headless, with no scene
tree**, and must agree with what the player experiences. Free-look movement
appears to threaten this: physics is not reproducible headless, and a navmesh
is not something `RefCounted` code can walk.

The resolution is to notice that **none of those systems need to walk.** They
need to know *which encounters occur on a floor and in what order*. Walking is
the player's interface for choosing that order, not an input to the simulation.

So the pivot splits the floor in two:

- **The logical floor** — the existing array of 3 encounter nodes plus the exit.
  Unchanged, pure, and the only thing the simulation sees.
- **The spatial floor** — a layout of rooms and corridors that *embeds* those
  nodes in space. Generated from the same seed by pure code (§6), consumed by
  the presentation layer to build geometry.

The autopilot's model of movement is a **visit policy** over the logical floor
("take the nearest unresolved node", which reproduces today's sequential order).
That is a legitimate model of a player, not an approximation of physics — the
simulation was never simulating footsteps.

**Invariant:** nothing in `game/world/` ever writes to `RunState`. The physics
layer reads the layout and reports player intent (`enter node i`) as an action
through `RunEngine.apply`. There is no other channel.

## 5. The change to `core/run/`

Today `RunState.nodes` is a linear array of 3 nodes and `_advance` walks it with
`node_index += 1`. Walking a floor means the player picks the order. The change
is contained and is developed test-first.

### 5.1 `RunState`

Gains `resolved: Array` — one bool per node, initialised in `_enter_floor`,
serialised in `to_dict`/`from_dict` with a save version bump and a migration
that fills it from `node_index` for saves written before the pivot.

### 5.2 `RunEngine`

- `legal_actions` in phase `node` returns one `{"kind": "enter", "index": i}`
  per **unresolved** node instead of a single bare `enter`.
- `_enter_node(run, index)` sets `run.node_index = index` before the existing
  body runs. The `node_enter` event already carries `index`, so the event stream
  shape does not change.
- `{"kind": "enter"}` **without** an index keeps meaning "the lowest unresolved
  node". This is the compatibility hinge: `RunAutopilot` emits the bare form, so
  every existing core test, the balance simulator and all four demo tools
  reproduce today's behaviour exactly and stay green.
- `_advance` marks `resolved[node_index] = true`; if any node is unresolved the
  phase returns to `node`, otherwise it becomes `exit` and emits `floor_cleared`
  as it does today.

### 5.3 What this deliberately does not change

The floor still has exactly three encounters and the stairs down unlock only
when all three are resolved. **You cannot skip a fight by finding the exit.**
This preserves the per-floor encounter count that every balance invariant in
§12 of the original spec depends on, so `balance_sim` and the "deeper pays"
assertion are untouched by the pivot. Letting players route around encounters is
a real design question, but it is an economy change, not a presentation change,
and it is out of scope here.

## 6. The new pure module: `core/run/floor_layout.gd`

`RefCounted`, seeded, no engine randomness, no `Node` — the same rules as the
rest of `core/`, and tested headless like the rest of `core/`.

**Input:** `(biome, floor, run_seed, node_count)`.

**Output:** a plain dictionary describing a floor on an integer grid:

- a grid of cells (target 24×24, 4 m cells) marked floor / wall / void
- carved rooms joined by corridors, guaranteed connected
- one room assigned per encounter node, plus an entry room and a stairs room
- per cell, which kit piece occupies it and its rotation
- prop anchors: torch brackets, rubble, biome dressing
- ghost anchors: where a ghost standing on this floor is placed

**Testable properties** (this is what the headless suite asserts): every room is
reachable from the entry room; each encounter node is assigned exactly one room;
the stairs room is not the entry room; the same seed produces an identical
layout; room count and grid bounds stay inside configured limits.

`game/world/dungeon_builder.gd` consumes this and instances geometry. The
builder has no opinions about layout — if the corridor is wrong, the fix is in
`core/`, where it can be tested without a window.

## 7. Art production without an artist

Decision 3 asks for textured PBR realism. That is achievable solo, but only as a
**discipline**, because "asset flip" is a coherence failure, not a quality
failure: it happens when sources disagree about texel density, physical scale
and colour grading. The pipeline exists to force agreement.

- **Modular kit** — `assets/kit/`: roughly twelve pieces on a 4 m grid (floor,
  ceiling, wall, wall with arch, corner, column, doorway, stair, well head, and
  biome variants), sharing three tiling materials. This is how studios build
  dungeons: simple geometry, infinite corridors, one material budget.
- **CC0 materials** — `assets/materials/`: PBR sets (albedo, normal, roughness,
  AO) from ambientCG and Poly Haven, both CC0, resampled to **one texel
  density**. Materials carry most of the realism; the supply is effectively
  unlimited and legally clean.
- **One grade for the whole game** — a single `WorldEnvironment`, one tonemap,
  one LUT. Mixed sources unify under shared lighting and shared grading.
- **Light does the work** — torches with flicker, volumetric fog per biome, real
  shadows. Well-lit simple geometry beats badly-lit complex geometry.
- **Attribution** — every asset lands in `ATTRIBUTION.md` as it is added, not at
  the end.

### 7.1 The known risk: enemies

Environments are solved by the above. **Enemies are not**: they need rigs and at
minimum four animation states (idle, attack, take hit, die). CC0 rigged monster
packs (Quaternius) and Mixamo retargeting are the intended path, but this is the
one part of the pipeline that is not proven. It is therefore the first thing
built (§9, stage 0), not the last — the project must find out whether a credible
animated enemy is reachable in days, not after months of environment work.

## 8. Presentation architecture

```
game/
  game.gd            GameRoot — unchanged contract, still the only core↔tree bridge
  world/
    dungeon_builder.gd   FloorLayout -> geometry, lights, nav, anchors
    kit.gd               the modular piece catalogue and its materials
    player.gd            CharacterBody3D: walk, look, interact, torch
    encounter_marker.gd  a node's room: triggers `enter index` on approach
    ghost_figure.gd      a dead hero standing where it died
    guild_room.gd        the walkable guild: table, circle, desk, well
    well_view.gd         the tower of floors seen down the well
  fight/
    fight_director.gd    camera lock, staging, turn flow in 3D
    enemy_body.gd        mesh, animation states, hit reactions
    fight_animator_3d.gd core event stream -> 3D reactions (replaces fight_animator.gd)
  hud/
    hand_view.gd         the 2D card hand over the live 3D room
    card_view.gd         kept from game/widgets/
    vitals.gd            HP, block, energy
    prompts.gd           interact prompts, floor banners
  theme/
    sfx.gd               kept, plus 3D positional audio
    grade.gd             the single WorldEnvironment + LUT
  util/num.gd            kept
```

**The fight, staged:** you walk into the room, the enemy is there lit by your
torch, the camera locks to it, and the hand fans up from the bottom of the
screen. `core/combat` drives every rule exactly as it does today;
`fight_animator_3d.gd` maps the same event stream to 3D reactions — recoil on
`damage`, particles on `status_applied`, camera shake on hits, the enemy's death
animation on `enemy_died`. The event stream is the contract, and it is the same
contract the 2D animator consumed.

**The guild:** a walkable room with an upgrade table, a séance circle, the
hero's desk, and the well. Looking down the well shows the tower of floors with
your ghosts standing on them; walking into it starts the descent. This is the
Steam capsule shot and the first three seconds of the trailer.

**Ghosts in the world:** a ghost's floor is already in its record, and the
layout already emits ghost anchors, so placing your dead in the corridors of
floors you re-descend is nearly free. It is also the single highest-value image
the pivot buys.

## 9. Stages

Each stage ends in something that runs and can be looked at.

| Stage | Name | Content |
|---|---|---|
| **0** | Spike: the look | One corridor, CC0 materials, torch, fog, grade — **and one animated enemy**, because that is the risk. Ends in a screenshot and a go/no-go on the art pipeline. |
| **1** | The world is data | `core/run/floor_layout.gd` and the §5 `RunEngine` change, TDD, headless, full core suite green. No production 3D yet — stage 0's corridor was a throwaway probe and is not built on. |
| **2** | It can be walked | Forward+, player controller, kit, dungeon builder, collision. Walk a generated floor. |
| **3** | The fight happens where you stand | Enemy bodies, camera staging, card HUD over 3D, `fight_animator_3d`. |
| **4** | The floor loop | Reward, event, rest, shop and stairs rooms; the exit decision. |
| **5** | The guild is a place | Guild room, well, tower, ghosts standing in the world. |
| **6** | Death | The epitaph beat in 3D — the moment the trailer opens on. |

Stage 0 is a firewall, not ceremony: the difference between "looks commercial"
and "looks like an asset flip" is decided in the first week, and it is cheaper to
learn it there.

## 10. Testing

- **`core/` keeps its standard**: `floor_layout.gd` and the `RunEngine` change
  are developed test-first, headless, deterministic from a seed. The existing
  31 core suites must stay green throughout — they are the regression net that
  proves the pivot did not damage the game.
- **`game/` tests are rebuilt, not ported.** Of the 28 UI suites, the 24 that
  exercise `Control` trees which will not exist are deleted as their screens are
  replaced; `num_test`, `sfx_test`, `game_test` and `card_view_test` cover
  modules that survive §3.2 and stay. New coverage is smoke-level plus targeted:
  the builder produces the cell count the layout asked for, the animator reacts
  to each event type, the HUD renders a hand from a `FightState`.
- **`tools/` demos are the integration test.** `run_demo`, `campaign_demo` and
  `balance_sim` exercise the whole core headlessly and must keep exiting 0.

## 11. Out of scope

Routing around encounters (§5.3), a second class, Expeditions, priority rules,
prestige, biomes beyond the Catacombs, Steam integration, localisation. The
pivot changes how the existing slice is played and seen; it does not grow it.

## 12. Reversibility

`main` keeps the finished 2D pixel-art slice. This branch replaces it rather
than living alongside it: there is no configuration flag and no dual maintenance
of two presentation layers. If the pivot is abandoned, the fallback is `main`,
intact.
