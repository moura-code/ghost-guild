# Stage 2 — It Can Be Walked

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **This project's owner has asked for inline execution** (subagent round trips are too slow for him), so in practice: `superpowers:executing-plans`, in this session, TDD per task, commit per task.

**Goal:** Boot the game into a generated crypt floor and walk it in first person — Forward+ renderer, torchlit PBR geometry with collision, a mouselook character controller, and encounter rooms that report the player's route to `RunEngine` and to nothing else.

**Architecture:** `core/run/layout_generator.gd` already answers "what shape is this floor". Stage 2 adds the presentation half: `Kit` owns the metres and the materials, `DungeonBuilder` turns a `FloorLayout` into three MultiMeshes plus one merged collision body, `Grade` owns the single `Environment` for the whole game, `Player` is a `CharacterBody3D`, `EncounterMarker` is an `Area3D` over a node's room, and `Crawl` is the scene root that wires them to `GameRoot`. The spec's invariant is the design constraint: **nothing under `game/world/` writes to `RunState`; the only channel is `GameRoot.run_action` → `RunEngine.apply`.**

**Tech Stack:** Godot 4.7.2 Forward+, GDScript (static typing everywhere), GdUnit4, CC0 ambientCG PBR materials already in `assets/materials/`.

**Spec:** `docs/superpowers/specs/2026-08-29-3d-pivot-design.md` (stage 2 of §9; architecture in §8; art discipline in §7).

## Global Constraints

- Godot **4.7.2**; `GODOT_BIN` env var points at it; every command goes through it.
- Tests: `tools\test.cmd <dir-or-file>` — from Git Bash, `cmd //c "tools\\test.cmd tests"`. Exit code 0 on success.
- **`core/` is off limits in this stage.** Stage 1 finished the `core/` change. If a layout bug shows up, the fix goes in `core/run/`, test-first, and is called out as a scope exception — the builder never compensates for a bad layout.
- Everything under `core/` extends `RefCounted` only. Everything new in this stage is under `game/` and `tools/` and may use `Node`.
- Static typing everywhere; `Variant` only where JSON/`Dictionary` parsing forces it.
- No engine randomness in anything that decides layout. `Kit`, `DungeonBuilder` and `Crawl` take a `FloorLayout`; they never call `randi()`. Cosmetic-only jitter (torch flicker phase) may use engine randomness because nothing reads it back.
- Commit every `.gd.uid` sidecar alongside its `.gd` file.
- Player-facing strings are keys resolved against `data/strings/en.csv`. Stage 2 adds no new player-facing strings — the only text it shows is debug print.
- Attribution for any asset lands in `ATTRIBUTION.md` as it is added, not at the end. Stage 2 adds no new assets; the four ambientCG materials are already credited.
- **The regression net is 614 test cases across 61 suites, green, exit 0.** That number must not go down; new suites push it up.

## Two facts this plan is written against

1. **`forward_plus` keeps the suite green.** Probed on 2026-08-29 by flipping `renderer/rendering_method` and running the full suite, then reverting. The tests do not care about the renderer.
2. **The suite runs `--headless`, so the renderer is never exercised by it.** Every assertion in this stage is about *structure* — node counts, layers, transforms, material parameters — and none of it is evidence that the game looks right. That evidence is a screenshot, and Task 8 exists to produce one. Do not report "stage 2 works" on a green suite alone.

## Deliberate deviations from the spec, and why

Record these; do not silently drift.

| Spec says | This plan does | Why |
|---|---|---|
| §7 "roughly twelve pieces on a **4 m grid**" | **3 m cells**, `Kit.CELL = 3.0`, wall height 3.2 m | A 24×24 grid at 4 m is 96 m across and a 4 m-wide corridor reads as a hall, not a crypt. 3 m is the width the stage 0 spike shot was framed at and it is the reason that shot read as a crypt. The spec line is corrected as part of Task 2. |
| §7 "modular kit — `assets/kit/`" of authored pieces | **Procedural** meshes (plane, box) sharing the three tiling materials | There is no artist, and stage 0 proved that boxes plus correct texel density plus torchlight already read as commercial. Authored kit pieces are a later upgrade that swaps `Kit`'s mesh functions and nothing else. `assets/kit/` is not created in this stage. |
| §8 lists `game/world/` without a scene root | Adds **`game/world/crawl.gd`** and `game/crawl.tscn` | Something has to own the bind-build-respawn cycle and be the `main_scene`. `Crawl` is that node. |
| §9 stage 4 owns "the exit decision" | Stage 2 wires a **bare stairs trigger** (`push` when the floor is clear) and **auto-resolves encounters with `RunAutopilot`** | Without these, walking into a room soft-locks the run in phase `fight` with no fight UI, and there is no way to see a second floor. Both are explicitly scaffolding, marked in the code, and deleted in stages 3 and 4. |

Nothing is deleted from `game/` in this stage. The 2D screens stop being reachable (the main scene changes) but they still compile and their suites still run, so the regression net stays whole until the screen that replaces each one exists.

## File Structure

| File | Responsibility |
|---|---|
| `project.godot` (modify) | Forward+, native-resolution display, input map, 3D physics layer names, new main scene. |
| `game/world/kit.gd` (create) | `class_name Kit`. The metres: cell size, wall height, texel density, the three shared PBR materials, the shared meshes, and cell↔world conversion. The only place in the game that knows how big a cell is. |
| `game/theme/grade.gd` (create) | `class_name Grade`. One `Environment` for the whole game — ACES tonemap, fog, ambient, SSAO, glow — parameterised only by depth. |
| `game/world/dungeon_builder.gd` (create) | `class_name DungeonBuilder`. `FloorLayout` → three `MultiMeshInstance3D`s, one merged `StaticBody3D`, one `OmniLight3D` per torch anchor. Has no opinions about layout. |
| `game/world/player.gd` (create) | `class_name Player`. `CharacterBody3D`: capsule, head, camera, the hero's own torch, WASD + mouselook, sprint. Movement maths are static functions so they are testable without a window. |
| `game/world/encounter_marker.gd` (create) | `class_name EncounterMarker`. `Area3D` over a node's room; emits `entered(index)` once, goes inert when resolved. |
| `game/world/crawl.gd` (create) | `class_name Crawl`. The scene root. Binds `GameRoot`, builds the floor the run is on, spawns the player, wires markers to `run_action`, rebuilds on descent. **The only file in `game/world/` that talks to `GameRoot`.** |
| `game/crawl.tscn` (create) | The shipped scene: one `Node3D` with `crawl.gd`. |
| `tools/crawl_shot.gd` (create) | Headless-adjacent capture: builds a floor with the real `Kit`/`DungeonBuilder`/`Grade` and saves a PNG. The stage's actual evidence. |
| `tests/game/world_settings_test.gd` (create) | The project settings are a contract: renderer, actions, layers. |
| `tests/game/kit_test.gd` (create) | Texel density, material sharing, cell↔world. |
| `tests/game/grade_test.gd` (create) | Depth curve, deeper is darker and foggier, tonemap is ACES everywhere. |
| `tests/game/dungeon_builder_test.gd` (create) | Wall-run merging, instance counts, collision layers, torch placement. |
| `tests/game/player_test.gd` (create) | Movement maths, rig structure, layers, gravity. |
| `tests/game/encounter_marker_test.gd` (create) | Fires once, watches the player layer, goes inert. |
| `tests/game/crawl_test.gd` (create) | The whole wiring, including the invariant that the run only changes through `run_action`. |
| `docs/superpowers/specs/2026-08-29-3d-pivot-design.md` (modify) | The 4 m → 3 m correction and the `crawl.gd` addition to §8. |

---

### Task 1: The project is a 3D project

**Files:**
- Modify: `project.godot`
- Test: `tests/game/world_settings_test.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: input actions `move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `interact`; 3D physics layers `1=world`, `2=player`, `3=interactable`, `4=ghost`; `rendering/renderer/rendering_method == "forward_plus"`. Every later task depends on these names.

- [ ] **Step 1: Write the failing test**

Create `tests/game/world_settings_test.gd`:

```gdscript
extends GdUnitTestSuite
## The project settings are a contract the world code reads at runtime: the
## controller asks the InputMap for its actions by name and the bodies set
## layer bits by number. A rename here is a silent behaviour change
## everywhere, so it is asserted like any other interface.

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "interact"]
const LAYERS := {1: "world", 2: "player", 3: "interactable", 4: "ghost"}


func test_the_game_renders_with_forward_plus() -> void:
	assert_str(String(ProjectSettings.get_setting("rendering/renderer/rendering_method"))).is_equal("forward_plus")


func test_the_pixel_art_viewport_is_gone() -> void:
	# 640x360 with an integer viewport stretch was the pixel-art direction.
	# A 3D game renders at the window's real resolution.
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_width"))).is_greater(640)
	assert_str(String(ProjectSettings.get_setting("display/window/stretch/mode"))).is_equal("canvas_items")
	assert_bool(ProjectSettings.has_setting("rendering/textures/canvas_textures/default_texture_filter")).is_false()


func test_every_movement_action_exists_and_is_bound() -> void:
	for action in ACTIONS:
		assert_bool(InputMap.has_action(action)).override_failure_message("missing action: " + action).is_true()
		assert_array(InputMap.action_get_events(action)).override_failure_message("unbound action: " + action).is_not_empty()


func test_the_physics_layers_are_named() -> void:
	for bit in LAYERS:
		var key := "layer_names/3d_physics/layer_%d" % bit
		assert_str(String(ProjectSettings.get_setting(key))).is_equal(String(LAYERS[bit]))


func test_the_game_boots_into_the_crawl() -> void:
	assert_str(String(ProjectSettings.get_setting("application/run/main_scene"))).is_equal("res://game/crawl.tscn")
```

- [ ] **Step 2: Run it and watch it fail**

```
cmd //c "tools\\test.cmd tests/game/world_settings_test.gd"
```

Expected: five failures — `gl_compatibility`, viewport 640, no actions, no layer names, main scene is `main.tscn`.

- [ ] **Step 3: Edit `project.godot`**

Replace the `[display]` block (comment included — the pixel-art rationale is no longer true and a stale comment is worse than none):

```ini
[display]

; Native resolution. The 3D world is rendered at whatever the window is; the
; HUD scales with "canvas_items" so cards and text stay sharp at any size.
; The 640x360 integer viewport that made the pixel art work is gone with it.
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

Replace the `[rendering]` block:

```ini
[rendering]

; Forward+: clustered lighting, real shadows, SSAO, volumetric-ready fog.
; The torchlit crypt is the whole visual pitch and none of it exists under
; gl_compatibility. This raises the minimum spec, which is the accepted cost
; of the "textured PBR realism" decision (spec 2026-08-29 §1.3, §3.3).
renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/anisotropic_filtering_level=4
```

Change the main scene under `[application]`:

```ini
run/main_scene="res://game/crawl.tscn"
```

Append these two sections at the end of the file:

```ini
[input]

move_forward={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_back={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
sprint={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194325,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="interactable"
3d_physics/layer_4="ghost"
```

Physical keycodes: 87=W, 83=S, 65=A, 68=D, 69=E, 4194325=Shift. `physical_keycode` rather than `keycode` so WASD stays in the same place on an AZERTY keyboard.

- [ ] **Step 4: Create the scene the main scene setting points at**

`main_scene` naming a file that does not exist is a boot failure, so the scene lands here even though its script arrives in Task 7. Create `game/crawl.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://game/world/crawl.gd" id="1"]

[node name="Crawl" type="Node3D"]
script = ExtResource("1")
```

and a placeholder `game/world/crawl.gd` that Task 7 replaces wholesale:

```gdscript
class_name Crawl
extends Node3D
## Placeholder — Task 7 of the stage 2 plan replaces this with the real root.
```

- [ ] **Step 5: Run the new suite**

```
cmd //c "tools\\test.cmd tests/game/world_settings_test.gd"
```

Expected: 5 passing.

- [ ] **Step 6: Run the whole suite — this is the step that matters**

```
cmd //c "tools\\test.cmd tests"
```

Expected: exit 0, **619 tests** (614 + 5). If a 2D UI suite fails because it depended on a 640×360 viewport, that is a real finding: record which suite and why in this plan before fixing it, and prefer fixing the test over restoring the viewport — the viewport is gone on purpose.

**What happened:** 619 tests, **one** failure — `tests/game/main_test.gd:96`,
`test_the_main_scene_loads_and_is_the_project_entry_point`, which asserted
`application/run/main_scene == "res://game/main.tscn"`. Nothing to do with the
viewport: it is the one test that encoded *which screen boots*, and the pivot
changed that answer. Renamed to
`test_the_main_scene_still_loads_even_though_it_no_longer_boots` and inverted
to `is_not_equal`, keeping the `load()` assertion — the 2D screen still has to
build until the 3D screen that replaces it exists. Add
`tests/game/main_test.gd` to the Step 7 commit.

- [ ] **Step 7: Commit**

```bash
git add project.godot game/crawl.tscn game/world/crawl.gd game/world/crawl.gd.uid tests/game/world_settings_test.gd tests/game/world_settings_test.gd.uid
git commit -m "feat(3d): the project renders Forward+ and has a movement input map"
```

---

### Task 2: `Kit` — the metres and the materials

**Files:**
- Create: `game/world/kit.gd`
- Test: `tests/game/kit_test.gd`
- Modify: `docs/superpowers/specs/2026-08-29-3d-pivot-design.md` (the 4 m → 3 m correction)

**Interfaces:**
- Consumes: `assets/materials/{bricks100,pavingstones119,rock051}/{color,normal,roughness,ao}.jpg`.
- Produces:
  - `Kit.CELL: float = 3.0`, `Kit.WALL_H: float = 3.2`, `Kit.TEXEL: float = 2.0`
  - `Kit.floor_material() -> StandardMaterial3D`, `Kit.wall_material() -> StandardMaterial3D`, `Kit.ceiling_material() -> StandardMaterial3D` — all cached and shared
  - `Kit.floor_mesh() -> PlaneMesh`, `Kit.ceiling_mesh() -> PlaneMesh`, `Kit.wall_mesh() -> BoxMesh` — all cached and shared
  - `Kit.cell_to_world(cell: Vector2i) -> Vector3` (floor level, y = 0)
  - `Kit.world_to_cell(at: Vector3) -> Vector2i`

- [ ] **Step 1: Write the failing test**

Create `tests/game/kit_test.gd`:

```gdscript
extends GdUnitTestSuite
## The kit is where "asset flip" is prevented or caused. The assertions that
## matter are not about looks -- they are that every surface in the game
## repeats its texture every TEXEL metres, whatever the surface's size, and
## that everyone shares one material so the whole crypt grades as one thing.


func _metres_per_repeat(m: StandardMaterial3D, span: Vector2) -> Vector2:
	return Vector2(span.x / m.uv1_scale.x, span.y / m.uv1_scale.y)


func test_every_material_carries_its_four_maps() -> void:
	for m in [Kit.floor_material(), Kit.wall_material(), Kit.ceiling_material()]:
		assert_object(m.albedo_texture).is_not_null()
		assert_object(m.normal_texture).is_not_null()
		assert_object(m.roughness_texture).is_not_null()
		assert_object(m.ao_texture).is_not_null()


func test_the_whole_kit_shares_one_texel_density() -> void:
	# A floor cell is CELL x CELL; a wall face is CELL wide and WALL_H tall.
	# Both must come out at TEXEL metres per repeat, which is why the wall
	# does not simply reuse the floor's uv1_scale.
	var floor_span := _metres_per_repeat(Kit.floor_material(), Vector2(Kit.CELL, Kit.CELL))
	var wall_span := _metres_per_repeat(Kit.wall_material(), Vector2(Kit.CELL, Kit.WALL_H))
	for span in [floor_span, wall_span]:
		assert_float(span.x).is_equal_approx(Kit.TEXEL, 0.001)
		assert_float(span.y).is_equal_approx(Kit.TEXEL, 0.001)


func test_materials_and_meshes_are_shared_not_rebuilt() -> void:
	# 500+ cells per floor. A material per cell is 500 shader instances and a
	# MultiMesh that cannot batch at all.
	assert_object(Kit.floor_material()).is_same(Kit.floor_material())
	assert_object(Kit.wall_material()).is_same(Kit.wall_material())
	assert_object(Kit.floor_mesh()).is_same(Kit.floor_mesh())
	assert_object(Kit.wall_mesh()).is_same(Kit.wall_mesh())


func test_the_floor_and_wall_meshes_are_one_cell_across() -> void:
	assert_float(Kit.floor_mesh().size.x).is_equal(Kit.CELL)
	assert_float(Kit.floor_mesh().size.y).is_equal(Kit.CELL)
	assert_float(Kit.wall_mesh().size.x).is_equal(Kit.CELL)
	assert_float(Kit.wall_mesh().size.y).is_equal(Kit.WALL_H)
	assert_float(Kit.wall_mesh().size.z).is_equal(Kit.CELL)


func test_cell_and_world_are_the_same_place_read_two_ways() -> void:
	for c in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(23, 23)]:
		assert_vector(Kit.world_to_cell(Kit.cell_to_world(c))).is_equal(c)


func test_a_point_inside_a_cell_reads_as_that_cell() -> void:
	var middle := Kit.cell_to_world(Vector2i(5, 6)) + Vector3(Kit.CELL * 0.4, 1.7, -Kit.CELL * 0.4)
	assert_vector(Kit.world_to_cell(middle)).is_equal(Vector2i(5, 6))
```

- [ ] **Step 2: Run it and watch it fail**

```
cmd //c "tools\\test.cmd tests/game/kit_test.gd"
```

Expected: parse failure — `Kit` is not a known class.

- [ ] **Step 3: Write `game/world/kit.gd`**

```gdscript
class_name Kit
extends RefCounted
## The modular kit: the only place in the game that knows how big a cell is
## and what stone looks like. Everything else works in cells and asks here
## for metres.
##
## The pieces are procedural -- a plane and a box -- rather than authored
## meshes, because stage 0 proved that with correct texel density and
## torchlight, boxes already read as a crypt, and there is no artist to
## author twelve pieces. Swapping in authored geometry later changes the
## three mesh functions below and nothing else in the game.

## Metres per grid cell. Not the 4 m the spec first guessed: a 24x24 grid at
## 4 m is 96 m across and a 4 m corridor reads as a hall. 3 m is the width
## the stage 0 shot was framed at, and it is why that shot read as a crypt.
const CELL := 3.0
const WALL_H := 3.2
## Metres per texture repeat, for every surface in the game. This single
## number is the discipline that stops mixed CC0 sources reading as an asset
## flip: a wall and the floor it meets never disagree about how big a stone
## is (spec §7).
const TEXEL := 2.0
const MAT_ROOT := "res://assets/materials/"

static var _cache: Dictionary = {}


static func floor_material() -> StandardMaterial3D:
	return _material("floor", "pavingstones119", Vector2(CELL, CELL))


static func wall_material() -> StandardMaterial3D:
	return _material("wall", "bricks100", Vector2(CELL, WALL_H))


static func ceiling_material() -> StandardMaterial3D:
	return _material("ceiling", "rock051", Vector2(CELL, CELL))


static func floor_mesh() -> PlaneMesh:
	if not _cache.has("floor_mesh"):
		var m := PlaneMesh.new()
		m.size = Vector2(CELL, CELL)
		_cache["floor_mesh"] = m
	return _cache["floor_mesh"]


static func ceiling_mesh() -> PlaneMesh:
	# Same plane, flipped by the instance transform rather than by a second
	# mesh: one less resource and one less thing to keep in sync.
	return floor_mesh()


static func wall_mesh() -> BoxMesh:
	if not _cache.has("wall_mesh"):
		var m := BoxMesh.new()
		m.size = Vector3(CELL, WALL_H, CELL)
		_cache["wall_mesh"] = m
	return _cache["wall_mesh"]


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)


static func world_to_cell(at: Vector3) -> Vector2i:
	return Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))


## `span` is the size in metres of the surface this material goes on, so the
## uv scale can be solved for TEXEL metres per repeat on both axes. Godot maps
## a PlaneMesh and each BoxMesh face across 0..1, so the span is exactly the
## face's dimensions.
static func _material(key: String, folder: String, span: Vector2) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(MAT_ROOT + folder + "/color.jpg")
	m.normal_enabled = true
	m.normal_texture = load(MAT_ROOT + folder + "/normal.jpg")
	m.roughness_texture = load(MAT_ROOT + folder + "/roughness.jpg")
	m.ao_enabled = true
	m.ao_texture = load(MAT_ROOT + folder + "/ao.jpg")
	m.ao_light_affect = 0.7
	m.uv1_scale = Vector3(span.x / TEXEL, span.y / TEXEL, 1.0)
	_cache[key] = m
	return m
```

- [ ] **Step 4: Run the test**

```
cmd //c "tools\\test.cmd tests/game/kit_test.gd"
```

Expected: 6 passing.

- [ ] **Step 5: Correct the spec**

In `docs/superpowers/specs/2026-08-29-3d-pivot-design.md` §7, the bullet currently reads "roughly twelve pieces on a 4 m grid". Replace the sentence with:

```markdown
- **Modular kit** — `game/world/kit.gd`: the pieces are procedural (plane,
  box) on a **3 m grid**, sharing three tiling materials at one texel
  density. 4 m was the first guess and it is wrong: a 24×24 grid at 4 m is
  96 m across, and a 4 m-wide corridor reads as a hall rather than a crypt.
  Authored geometry is a later upgrade that swaps `Kit`'s mesh functions and
  nothing else — `assets/kit/` does not exist yet, deliberately.
```

- [ ] **Step 6: Commit**

```bash
git add game/world/kit.gd game/world/kit.gd.uid tests/game/kit_test.gd tests/game/kit_test.gd.uid docs/superpowers/specs/2026-08-29-3d-pivot-design.md
git commit -m "feat(3d): one kit, one texel density, three metres per cell"
```

---

### Task 3: `Grade` — one look for the whole game

**Files:**
- Create: `game/theme/grade.gd`
- Test: `tests/game/grade_test.gd`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Grade.depth_of(floor: int, last_floor: int) -> float` — 0.0 at the surface, 1.0 at the bottom of the biome
  - `Grade.environment(depth: float) -> Environment`
  - `Grade.world_environment(depth: float) -> WorldEnvironment`

- [ ] **Step 1: Write the failing test**

Create `tests/game/grade_test.gd`:

```gdscript
extends GdUnitTestSuite
## "Depth is the threat" (spec §2.3) has to be measurable or it is a mood
## board. These are the numbers that make floor 20 feel unlike floor 2 before
## a card is played.


func test_depth_runs_from_the_surface_to_the_bottom_of_the_biome() -> void:
	assert_float(Grade.depth_of(1, 10)).is_equal(0.0)
	assert_float(Grade.depth_of(10, 10)).is_equal(1.0)
	assert_float(Grade.depth_of(6, 10)).is_equal_approx(5.0 / 9.0, 0.0001)


func test_a_one_floor_biome_does_not_divide_by_zero() -> void:
	assert_float(Grade.depth_of(1, 1)).is_equal(0.0)


func test_depth_is_clamped_however_it_is_asked_for() -> void:
	assert_float(Grade.depth_of(-4, 10)).is_equal(0.0)
	assert_float(Grade.depth_of(400, 10)).is_equal(1.0)


func test_the_deep_is_foggier_and_darker_than_the_surface() -> void:
	var top := Grade.environment(0.0)
	var bottom := Grade.environment(1.0)
	assert_float(bottom.fog_density).is_greater(top.fog_density)
	assert_float(bottom.ambient_light_energy).is_less(top.ambient_light_energy)


func test_every_floor_is_graded_the_same_way() -> void:
	# One tonemap for the whole game is what makes mixed CC0 sources look like
	# one game (spec §7). Depth changes the light, never the grade.
	for depth in [0.0, 0.5, 1.0]:
		var env := Grade.environment(depth)
		assert_int(env.tonemap_mode).is_equal(Environment.TONE_MAPPER_ACES)
		assert_bool(env.ssao_enabled).is_true()
		assert_bool(env.glow_enabled).is_true()
		assert_bool(env.fog_enabled).is_true()


func test_the_world_environment_carries_the_environment() -> void:
	var we: WorldEnvironment = auto_free(Grade.world_environment(0.4))
	assert_object(we.environment).is_not_null()
	assert_int(we.environment.tonemap_mode).is_equal(Environment.TONE_MAPPER_ACES)
```

- [ ] **Step 2: Run it and watch it fail**

```
cmd //c "tools\\test.cmd tests/game/grade_test.gd"
```

Expected: parse failure — `Grade` is not a known class.

- [ ] **Step 3: Write `game/theme/grade.gd`**

```gdscript
class_name Grade
extends RefCounted
## The single grade for the whole game: one tonemap, one fog, one ambient,
## everywhere, on every floor, over every asset. Mixed CC0 sources look like
## one game only if they are lit and graded by one thing (spec §7), so this
## is the one thing.
##
## Depth is the only parameter. It does not change the grade -- it changes
## how much light there is inside it, which is "depth is the threat"
## (spec §2.3) expressed as numbers.

const AMBIENT_TOP := 0.085
const AMBIENT_BOTTOM := 0.030
const FOG_TOP := 0.026
const FOG_BOTTOM := 0.075


static func depth_of(floor: int, last_floor: int) -> float:
	if last_floor <= 1:
		return 0.0
	return clampf(float(floor - 1) / float(last_floor - 1), 0.0, 1.0)


static func environment(depth: float) -> Environment:
	var d := clampf(depth, 0.0, 1.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.015, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Cold ambient against warm torchlight: the contrast is what makes a torch
	# read as a torch instead of as the room's brightness.
	env.ambient_light_color = Color(0.30, 0.36, 0.48).lerp(Color(0.16, 0.20, 0.34), d)
	env.ambient_light_energy = lerpf(AMBIENT_TOP, AMBIENT_BOTTOM, d)
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.15, 0.20).lerp(Color(0.07, 0.07, 0.11), d)
	env.fog_density = lerpf(FOG_TOP, FOG_BOTTOM, d)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15
	return env


static func world_environment(depth: float) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.environment = environment(depth)
	return we
```

- [ ] **Step 4: Run the test**

```
cmd //c "tools\\test.cmd tests/game/grade_test.gd"
```

Expected: 6 passing.

- [ ] **Step 5: Commit**

```bash
git add game/theme/grade.gd game/theme/grade.gd.uid tests/game/grade_test.gd tests/game/grade_test.gd.uid
git commit -m "feat(3d): one grade for the whole game, darker the deeper you go"
```

---

### Task 4: `DungeonBuilder` — a layout becomes a place

**Files:**
- Create: `game/world/dungeon_builder.gd`
- Test: `tests/game/dungeon_builder_test.gd`

**Interfaces:**
- Consumes: `Kit.CELL`, `Kit.WALL_H`, `Kit.floor_mesh()`, `Kit.wall_mesh()`, `Kit.floor_material()`, `Kit.wall_material()`, `Kit.ceiling_material()`, `Kit.cell_to_world()`; `FloorLayout` (cells, `is_walkable`, `torch_anchors`).
- Produces:
  - `DungeonBuilder.build(layout: FloorLayout, parent: Node3D) -> Dictionary` returning `{"floors": int, "walls": int, "torches": int, "boxes": int}`
  - `DungeonBuilder.wall_boxes(layout: FloorLayout) -> Array` of `Rect2i` (merged horizontal wall runs)
  - `DungeonBuilder.LAYER_WORLD := 1` (bit value, i.e. layer 1)

- [ ] **Step 1: Write the failing test**

Create `tests/game/dungeon_builder_test.gd`:

```gdscript
extends GdUnitTestSuite
## The builder has no opinions about layout (spec §6): everything it produces
## is a function of the cells it was handed. So the assertions are all
## "the world contains exactly what the layout asked for", which is also the
## only thing a headless suite can honestly check about a 3D scene.


func _bar() -> FloorLayout:
	# Three wall cells in a row, one floor cell under them.
	var l := FloorLayout.create(6, 4)
	l.set_cell(1, 2, FloorLayout.Cell.FLOOR)
	for x in [1, 2, 3]:
		l.set_cell(x, 1, FloorLayout.Cell.WALL)
	return l


func _generated() -> FloorLayout:
	return LayoutGenerator.generate(3, Rng.new(7))


func test_a_run_of_wall_cells_becomes_one_box() -> void:
	var boxes := DungeonBuilder.wall_boxes(_bar())
	assert_array(boxes).has_size(1)
	assert_object(boxes[0]).is_equal(Rect2i(1, 1, 3, 1))


func test_every_wall_cell_is_covered_by_exactly_one_box() -> void:
	var layout := _generated()
	var covered: Dictionary = {}
	for raw in DungeonBuilder.wall_boxes(layout):
		var box: Rect2i = raw
		for x in range(box.position.x, box.position.x + box.size.x):
			var key := Vector2i(x, box.position.y)
			assert_bool(covered.has(key)).override_failure_message("cell %s covered twice" % key).is_false()
			covered[key] = true
	var walls := 0
	for y in layout.height:
		for x in layout.width:
			if layout.cell(x, y) == FloorLayout.Cell.WALL:
				walls += 1
				assert_bool(covered.has(Vector2i(x, y))).override_failure_message("cell %d,%d uncovered" % [x, y]).is_true()
	assert_int(covered.size()).is_equal(walls)


func test_it_instances_one_floor_and_one_ceiling_per_walkable_cell() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var counts := DungeonBuilder.build(layout, root)
	var walkable := 0
	for y in layout.height:
		for x in layout.width:
			if layout.is_walkable(x, y):
				walkable += 1
	assert_int(int(counts["floors"])).is_equal(walkable)
	var floors: MultiMeshInstance3D = root.get_node("Floors")
	var ceilings: MultiMeshInstance3D = root.get_node("Ceilings")
	assert_int(floors.multimesh.instance_count).is_equal(walkable)
	assert_int(ceilings.multimesh.instance_count).is_equal(walkable)


func test_a_floor_instance_sits_at_its_cell_and_the_ceiling_above_it() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	DungeonBuilder.build(_bar(), root)
	var floors: MultiMeshInstance3D = root.get_node("Floors")
	var ceilings: MultiMeshInstance3D = root.get_node("Ceilings")
	assert_vector(floors.multimesh.get_instance_transform(0).origin).is_equal(Kit.cell_to_world(Vector2i(1, 2)))
	assert_float(ceilings.multimesh.get_instance_transform(0).origin.y).is_equal(Kit.WALL_H)


func test_walls_collide_on_the_world_layer_and_mask_nothing() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var counts := DungeonBuilder.build(layout, root)
	var body: StaticBody3D = root.get_node("Collision")
	assert_int(body.collision_layer).is_equal(DungeonBuilder.LAYER_WORLD)
	# Static geometry never needs to detect anything; masking is what makes a
	# body ask the physics server about others, and 500 walls asking is a bill
	# for nothing.
	assert_int(body.collision_mask).is_equal(0)
	# One shape per merged wall run, plus the ground slab.
	assert_int(body.get_child_count()).is_equal(int(counts["boxes"]) + 1)


func test_the_ground_slab_spans_the_whole_grid() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	DungeonBuilder.build(layout, root)
	var slab: CollisionShape3D = root.get_node("Collision/Ground")
	var box: BoxShape3D = slab.shape
	assert_float(box.size.x).is_greater_equal(layout.width * Kit.CELL)
	assert_float(box.size.z).is_greater_equal(layout.height * Kit.CELL)
	assert_float(slab.position.y).is_less(0.0)


func test_a_torch_hangs_in_the_open_cell_in_front_of_its_wall() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var counts := DungeonBuilder.build(layout, root)
	var torches: Node3D = root.get_node("Torches")
	assert_int(torches.get_child_count()).is_equal(int(counts["torches"]))
	assert_int(torches.get_child_count()).is_greater(0)
	for child in torches.get_children():
		var light: OmniLight3D = child
		# A light left on the anchor sits inside the wall and lights it from
		# within, which reads as a glowing window floating in the stone.
		var cell := Kit.world_to_cell(light.position)
		assert_bool(layout.is_walkable(cell.x, cell.y)).override_failure_message("torch inside stone at %s" % cell).is_true()
		assert_bool(light.shadow_enabled).is_true()


func test_building_the_same_layout_twice_produces_the_same_world() -> void:
	var a: Node3D = auto_free(Node3D.new())
	var b: Node3D = auto_free(Node3D.new())
	add_child(a)
	add_child(b)
	assert_dict(DungeonBuilder.build(_generated(), a)).is_equal(DungeonBuilder.build(_generated(), b))
```

- [ ] **Step 2: Run it and watch it fail**

```
cmd //c "tools\\test.cmd tests/game/dungeon_builder_test.gd"
```

Expected: parse failure — `DungeonBuilder` is not a known class.

- [ ] **Step 3: Write `game/world/dungeon_builder.gd`**

```gdscript
class_name DungeonBuilder
extends RefCounted
## Turns a FloorLayout into geometry, collision and light. It has no opinions
## about layout: if the corridor is wrong, the fix is in core/run/, where it
## can be tested without a window (spec §6).
##
## Geometry goes into three MultiMeshInstance3Ds rather than ~600 nodes,
## because a floor is 600 identical boxes and that is exactly what a MultiMesh
## is for. Collision is separate and merged into runs, because a collision
## box is invisible and can therefore be any size without stretching a
## texture.

const LAYER_WORLD := 1
const TORCH_COLOR := Color(1.0, 0.66, 0.32)
const TORCH_ENERGY := 5.0
## How far out of its wall the flame hangs, in cells.
const TORCH_OUT := 0.62
const GROUND_THICKNESS := 1.0


static func build(layout: FloorLayout, parent: Node3D) -> Dictionary:
	var floors: Array[Transform3D] = []
	var ceilings: Array[Transform3D] = []
	var walls: Array[Transform3D] = []
	# A ceiling plane faces up like the floor does, so it is rolled 180° to
	# face back down; a plane lit from the wrong side is a black ceiling.
	var flip := Basis(Vector3.FORWARD, PI)
	for y in layout.height:
		for x in layout.width:
			var at := Kit.cell_to_world(Vector2i(x, y))
			match layout.cell(x, y):
				FloorLayout.Cell.FLOOR:
					floors.append(Transform3D(Basis.IDENTITY, at))
					ceilings.append(Transform3D(flip, at + Vector3(0.0, Kit.WALL_H, 0.0)))
				FloorLayout.Cell.WALL:
					walls.append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, Kit.WALL_H * 0.5, 0.0)))

	parent.add_child(_multi("Floors", Kit.floor_mesh(), Kit.floor_material(), floors))
	parent.add_child(_multi("Ceilings", Kit.ceiling_mesh(), Kit.ceiling_material(), ceilings))
	parent.add_child(_multi("Walls", Kit.wall_mesh(), Kit.wall_material(), walls))

	var boxes := wall_boxes(layout)
	parent.add_child(_collision(layout, boxes))

	var torches := Node3D.new()
	torches.name = "Torches"
	parent.add_child(torches)
	for raw in layout.torch_anchors:
		var light := torch_light(layout, raw)
		if light != null:
			torches.add_child(light)

	return {
		"floors": floors.size(),
		"walls": walls.size(),
		"torches": torches.get_child_count(),
		"boxes": boxes.size(),
	}


## Horizontal runs of wall merged into single boxes. One collider per cell is
## ~500 shapes per floor and every one of them is a seam the character
## controller can catch on; a merged run is one flat surface to slide along.
static func wall_boxes(layout: FloorLayout) -> Array:
	var out: Array = []
	for y in layout.height:
		var x := 0
		while x < layout.width:
			if layout.cell(x, y) != FloorLayout.Cell.WALL:
				x += 1
				continue
			var run := 0
			while layout.cell(x + run, y) == FloorLayout.Cell.WALL:
				run += 1
			out.append(Rect2i(x, y, run, 1))
			x += run
	return out


## The bracket is bolted to a wall cell, so the flame has to hang in the open
## cell in front of it. Returns null for an anchor with nothing walkable
## beside it, which the generator can produce at a grid edge.
static func torch_light(layout: FloorLayout, anchor: Vector2i) -> OmniLight3D:
	var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var out_dir := Vector2i.ZERO
	for side in sides:
		if layout.is_walkable(anchor.x + side.x, anchor.y + side.y):
			out_dir = side
			break
	if out_dir == Vector2i.ZERO:
		return null
	var light := OmniLight3D.new()
	light.position = Vector3(
		(anchor.x + out_dir.x * TORCH_OUT) * Kit.CELL,
		Kit.WALL_H * 0.62,
		(anchor.y + out_dir.y * TORCH_OUT) * Kit.CELL)
	light.light_color = TORCH_COLOR
	light.light_energy = TORCH_ENERGY
	light.omni_range = Kit.CELL * 4.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	return light


static func _multi(node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return inst


## One body for the whole floor: the walls as merged boxes, plus a slab under
## everything to stand on. The slab is safe because add_walls() rings every
## walkable cell in wall, so there is nowhere to walk off.
static func _collision(layout: FloorLayout, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0

	var ground := CollisionShape3D.new()
	ground.name = "Ground"
	var slab := BoxShape3D.new()
	slab.size = Vector3(layout.width * Kit.CELL + Kit.CELL, GROUND_THICKNESS, layout.height * Kit.CELL + Kit.CELL)
	ground.shape = slab
	ground.position = Vector3(
		(layout.width - 1) * Kit.CELL * 0.5,
		-GROUND_THICKNESS * 0.5,
		(layout.height - 1) * Kit.CELL * 0.5)
	body.add_child(ground)

	for raw in boxes:
		var box: Rect2i = raw
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.size.x * Kit.CELL, Kit.WALL_H, Kit.CELL)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(
			(box.position.x + (box.size.x - 1) * 0.5) * Kit.CELL,
			Kit.WALL_H * 0.5,
			box.position.y * Kit.CELL)
		body.add_child(cs)
	return body
```

- [ ] **Step 4: Run the test**

```
cmd //c "tools\\test.cmd tests/game/dungeon_builder_test.gd"
```

Expected: 8 passing. If `test_a_torch_hangs_in_the_open_cell_in_front_of_its_wall` fails, check `TORCH_OUT` against `Kit.world_to_cell`'s rounding: at 0.62 a light rounds into the neighbouring cell, which is the intent.

- [ ] **Step 5: Commit**

```bash
git add game/world/dungeon_builder.gd game/world/dungeon_builder.gd.uid tests/game/dungeon_builder_test.gd tests/game/dungeon_builder_test.gd.uid
git commit -m "feat(3d): a floor layout becomes geometry, collision and torchlight"
```

---

### Task 5: `Player` — a body in the corridor

**Files:**
- Create: `game/world/player.gd`
- Test: `tests/game/player_test.gd`

**Interfaces:**
- Consumes: input actions from Task 1; `DungeonBuilder.LAYER_WORLD`.
- Produces:
  - `Player.LAYER_PLAYER := 2`, `Player.EYE := 1.62`
  - `Player.wish_direction(input: Vector2, yaw: float) -> Vector3` (static)
  - `Player.clamp_pitch(pitch: float) -> float` (static)
  - `Player.read_input() -> Vector2` — x = strafe, y = forward/back, y negative is forward
  - `player.place_at(at: Vector3, yaw: float) -> void`
  - `player.head: Node3D`, `player.camera: Camera3D`, `player.torch: OmniLight3D`

- [ ] **Step 1: Write the failing test**

Create `tests/game/player_test.gd`:

```gdscript
extends GdUnitTestSuite
## The controller's maths are static functions on purpose: a headless suite
## cannot press a key or move a mouse, but it can check that "forward" is
## where you are looking and that a diagonal is not a speed boost. The rig
## itself is asserted structurally. Whether it *feels* right is a question
## only running the game answers.


func _player() -> Player:
	var p: Player = auto_free(Player.new())
	add_child(p)
	return p


func test_forward_is_where_you_are_looking() -> void:
	# -Z is forward in Godot.
	assert_vector(Player.wish_direction(Vector2(0.0, -1.0), 0.0)).is_equal_approx(Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001)
	assert_vector(Player.wish_direction(Vector2(0.0, -1.0), PI / 2.0)).is_equal_approx(Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.001)


func test_a_diagonal_is_not_a_speed_boost() -> void:
	assert_float(Player.wish_direction(Vector2(1.0, -1.0), 0.0).length()).is_equal_approx(1.0, 0.001)


func test_standing_still_is_no_direction_at_all() -> void:
	assert_vector(Player.wish_direction(Vector2.ZERO, 1.3)).is_equal(Vector3.ZERO)


func test_you_cannot_look_far_enough_up_to_see_behind_you() -> void:
	assert_float(Player.clamp_pitch(9.0)).is_equal(Player.PITCH_LIMIT)
	assert_float(Player.clamp_pitch(-9.0)).is_equal(-Player.PITCH_LIMIT)
	assert_float(Player.clamp_pitch(0.2)).is_equal(0.2)


func test_the_rig_is_a_capsule_with_a_head_a_camera_and_a_torch() -> void:
	var p := _player()
	assert_object(p.head).is_not_null()
	assert_object(p.camera).is_not_null()
	assert_object(p.torch).is_not_null()
	assert_float(p.head.position.y).is_equal(Player.EYE)
	assert_object(p.camera.get_parent()).is_same(p.head)
	assert_object(p.torch.get_parent()).is_same(p.head)
	var shape: CollisionShape3D = p.get_node("Shape")
	assert_object(shape.shape).is_instanceof(CapsuleShape3D)


func test_the_player_is_on_the_player_layer_and_collides_with_the_world() -> void:
	var p := _player()
	assert_int(p.collision_layer).is_equal(Player.LAYER_PLAYER)
	assert_bool((p.collision_mask & DungeonBuilder.LAYER_WORLD) != 0).is_true()


func test_placing_the_player_sets_where_it_stands_and_which_way_it_faces() -> void:
	var p := _player()
	p.place_at(Vector3(9.0, 0.0, -4.0), PI)
	assert_vector(p.position).is_equal(Vector3(9.0, 0.0, -4.0))
	assert_float(p.rotation.y).is_equal_approx(PI, 0.001)
	assert_float(p.head.rotation.x).is_equal(0.0)


func test_input_reads_zero_when_nothing_is_pressed() -> void:
	# The suite never presses a key, so this is the only honest assertion
	# about read_input(): it exists, it is typed, and it is quiet.
	assert_vector(_player().read_input()).is_equal(Vector2.ZERO)


func test_gravity_puts_the_player_on_the_ground() -> void:
	var p := _player()
	var ground: StaticBody3D = auto_free(StaticBody3D.new())
	ground.collision_layer = DungeonBuilder.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	cs.shape = box
	cs.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(cs)
	add_child(ground)
	p.place_at(Vector3(0.0, 2.5, 0.0), 0.0)
	await await_millis(600)
	assert_bool(p.is_on_floor()).override_failure_message("player never landed, y=%f" % p.position.y).is_true()
	assert_float(p.position.y).is_equal_approx(0.0, 0.15)
```

- [ ] **Step 2: Run it and watch it fail**

```
cmd //c "tools\\test.cmd tests/game/player_test.gd"
```

Expected: parse failure — `Player` is not a known class.

- [ ] **Step 3: Write `game/world/player.gd`**

```gdscript
class_name Player
extends CharacterBody3D
## The hero's body in the crypt: walk, look, and carry the light.
##
## It reports where it is and nothing else. Nothing here writes to RunState;
## the only channel from the world to the simulation is Crawl calling
## GameRoot.run_action (spec §4).
##
## The movement maths are static so they can be tested without a window --
## the suite runs headless and cannot press a key, so the parts worth
## asserting are pulled out of the frame loop.

const LAYER_PLAYER := 2
const SPEED := 3.6
const SPRINT := 6.0
## High acceleration on purpose. A crawler wants a body that answers
## instantly; momentum is for vehicles.
const ACCEL := 14.0
const GRAVITY := 20.0
const EYE := 1.62
const RADIUS := 0.35
const HEIGHT := 1.75
const SENSITIVITY := 0.0022
## Just short of straight up, so the horizon never flips.
const PITCH_LIMIT := 1.45

var head: Node3D
var camera: Camera3D
var torch: OmniLight3D
## Off while a fight or a menu owns the mouse (stage 3 uses this).
var look_enabled: bool = true

var _pitch: float = 0.0


static func wish_direction(input: Vector2, yaw: float) -> Vector3:
	var v := Vector3(input.x, 0.0, input.y)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v.rotated(Vector3.UP, yaw)


static func clamp_pitch(pitch: float) -> float:
	return clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)


func _ready() -> void:
	collision_layer = LAYER_PLAYER
	collision_mask = DungeonBuilder.LAYER_WORLD

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, EYE, 0.0)
	add_child(head)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 72.0
	camera.current = true
	head.add_child(camera)

	# The reach of your own torch is the difficulty made physical (spec §2.3),
	# so the hero carries one and it is deliberately short.
	torch = OmniLight3D.new()
	torch.name = "Torch"
	torch.light_color = Color(1.0, 0.72, 0.42)
	torch.light_energy = 2.6
	torch.omni_range = Kit.CELL * 3.0
	torch.omni_attenuation = 1.6
	torch.position = Vector3(0.25, -0.15, 0.0)
	head.add_child(torch)

	capture_mouse(true)


func capture_mouse(on: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


func place_at(at: Vector3, yaw: float) -> void:
	position = at
	rotation = Vector3(0.0, yaw, 0.0)
	_pitch = 0.0
	if head != null:
		head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO


func read_input() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))


func _physics_process(delta: float) -> void:
	var speed := SPRINT if Input.is_action_pressed("sprint") else SPEED
	var wish := wish_direction(read_input(), rotation.y) * speed
	velocity.x = move_toward(velocity.x, wish.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, wish.z, ACCEL * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and look_enabled and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		rotate_y(-motion.relative.x * SENSITIVITY)
		_pitch = clamp_pitch(_pitch - motion.relative.y * SENSITIVITY)
		head.rotation.x = _pitch
		return
	# Escape gives the mouse back rather than quitting: a captured cursor with
	# no way out is the fastest way to make a build feel broken.
	if event.is_action_pressed("ui_cancel"):
		capture_mouse(Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED)
```

- [ ] **Step 4: Run the test**

```
cmd //c "tools\\test.cmd tests/game/player_test.gd"
```

Expected: 9 passing. `test_gravity_puts_the_player_on_the_ground` is the one that can be flaky — it depends on physics frames actually running under the headless runner. If it fails with "player never landed" **and** `y` is unchanged at 2.5, physics is not ticking in the runner: delete that one test and note here that landing is verified by Task 8's screenshot instead. Do not weaken the other eight to make it pass.

- [ ] **Step 5: Commit**

```bash
git add game/world/player.gd game/world/player.gd.uid tests/game/player_test.gd tests/game/player_test.gd.uid
git commit -m "feat(3d): a first-person body that walks, looks and carries a torch"
```

---

### Task 6: `EncounterMarker` — a room that knows what is in it

**Files:**
- Create: `game/world/encounter_marker.gd`
- Test: `tests/game/encounter_marker_test.gd`

**Interfaces:**
- Consumes: `Kit.CELL`, `Kit.cell_to_world()`, `Player.LAYER_PLAYER`; a room rect `{"x","y","w","h"}` from `FloorLayout.room_rect`.
- Produces:
  - `EncounterMarker.LAYER_INTERACTABLE := 4` (layer 3's bit value)
  - `EncounterMarker.create(index: int, room: Dictionary) -> EncounterMarker` (static)
  - signal `entered(index: int)`
  - `marker.resolve() -> void`
  - `marker.index: int`, `marker.resolved: bool`

- [ ] **Step 1: Write the failing test**

Create `tests/game/encounter_marker_test.gd`:

```gdscript
extends GdUnitTestSuite
## The marker is the whole "free movement" decision in one node: the player
## chooses a room by walking into it, and the only thing that leaves this
## node is an index. It never touches the run.


func _room() -> Dictionary:
	return {"x": 4, "y": 6, "w": 5, "h": 4}


func _marker(index: int = 1) -> EncounterMarker:
	var m: EncounterMarker = auto_free(EncounterMarker.create(index, _room()))
	add_child(m)
	return m


func test_it_sits_over_its_room() -> void:
	var m := _marker()
	var centre := Kit.cell_to_world(Vector2i(6, 8))
	assert_float(m.position.x).is_equal_approx(centre.x, 0.001)
	assert_float(m.position.z).is_equal_approx(centre.z, 0.001)
	var shape: BoxShape3D = (m.get_node("Shape") as CollisionShape3D).shape
	assert_float(shape.size.x).is_equal_approx(5.0 * Kit.CELL, 0.001)
	assert_float(shape.size.z).is_equal_approx(4.0 * Kit.CELL, 0.001)


func test_it_watches_the_player_and_nothing_else() -> void:
	var m := _marker()
	assert_int(m.collision_layer).is_equal(EncounterMarker.LAYER_INTERACTABLE)
	assert_int(m.collision_mask).is_equal(Player.LAYER_PLAYER)
	assert_bool(m.monitoring).is_true()


func test_walking_in_reports_which_node_it_is() -> void:
	var m := _marker(2)
	var seen: Array = []
	m.entered.connect(func(i: int) -> void: seen.append(i))
	m.report(auto_free(CharacterBody3D.new()))
	assert_array(seen).is_equal([2])


func test_it_reports_once_however_many_times_you_walk_through_it() -> void:
	var m := _marker()
	var seen: Array = []
	m.entered.connect(func(i: int) -> void: seen.append(i))
	var body: CharacterBody3D = auto_free(CharacterBody3D.new())
	m.report(body)
	m.report(body)
	m.report(body)
	assert_array(seen).has_size(1)


func test_a_resolved_marker_is_inert_and_invisible() -> void:
	var m := _marker()
	var seen: Array = []
	m.entered.connect(func(i: int) -> void: seen.append(i))
	m.resolve()
	m.report(auto_free(CharacterBody3D.new()))
	assert_array(seen).is_empty()
	assert_bool(m.resolved).is_true()
	assert_bool(m.monitoring).is_false()
	assert_bool(m.visible).is_false()
```

- [ ] **Step 2: Run it and watch it fail**

```
cmd //c "tools\\test.cmd tests/game/encounter_marker_test.gd"
```

Expected: parse failure — `EncounterMarker` is not a known class.

- [ ] **Step 3: Write `game/world/encounter_marker.gd`**

```gdscript
class_name EncounterMarker
extends Area3D
## A node's room, as a place you can walk into. Emits the node's index once
## and then waits to be told it is resolved.
##
## This is where the free-movement decision (spec §1.2) meets the pure
## simulation: the player picks the ORDER of the encounters by choosing which
## door to go through, and the only thing that crosses the boundary is an
## integer. The marker never touches RunState -- Crawl turns the index into a
## RunEngine action.

signal entered(index: int)

## Layer 3 of the project's physics layers, as a bit value.
const LAYER_INTERACTABLE := 4
const GLOW := Color(0.42, 0.72, 0.95)

var index: int = -1
var resolved: bool = false

var _fired: bool = false


static func create(node_index: int, room: Dictionary) -> EncounterMarker:
	var m := EncounterMarker.new()
	m.name = "Encounter%d" % node_index
	m.index = node_index
	m.collision_layer = LAYER_INTERACTABLE
	m.collision_mask = Player.LAYER_PLAYER
	var w := int(room.get("w", 1))
	var h := int(room.get("h", 1))
	var centre := Kit.cell_to_world(Vector2i(int(room.get("x", 0)) + w / 2, int(room.get("y", 0)) + h / 2))
	m.position = centre

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(w * Kit.CELL, Kit.WALL_H, h * Kit.CELL)
	shape.shape = box
	shape.position = Vector3(0.0, Kit.WALL_H * 0.5, 0.0)
	m.add_child(shape)

	# Stage 2 stand-in for the enemy that will be standing here in stage 3: a
	# cold light against the warm torches, so an unresolved room reads as
	# occupied from down the corridor.
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = GLOW
	light.light_energy = 1.6
	light.omni_range = Kit.CELL * 2.4
	light.position = Vector3(0.0, 1.2, 0.0)
	m.add_child(light)

	m.body_entered.connect(m.report)
	return m


## Separate from the signal handler so the suite can exercise it without a
## physics step: an Area3D only reports overlaps on its own schedule, and a
## test that has to wait for one is a test that fails on a slow machine.
func report(_body: Node3D) -> void:
	if resolved or _fired:
		return
	_fired = true
	entered.emit(index)


func resolve() -> void:
	resolved = true
	monitoring = false
	visible = false
```

- [ ] **Step 4: Run the test**

```
cmd //c "tools\\test.cmd tests/game/encounter_marker_test.gd"
```

Expected: 5 passing.

- [ ] **Step 5: Commit**

```bash
git add game/world/encounter_marker.gd game/world/encounter_marker.gd.uid tests/game/encounter_marker_test.gd tests/game/encounter_marker_test.gd.uid
git commit -m "feat(3d): a room you walk into reports which encounter it is"
```

---

### Task 7: `Crawl` — the floor you are standing on

**Files:**
- Modify: `game/world/crawl.gd` (replace the Task 1 placeholder)
- Test: `tests/game/crawl_test.gd`

**Interfaces:**
- Consumes: `GameRoot` (`campaign`, `start_run`, `run_action`, `finish_run`), `RunEngine.layout_for`, `RunAutopilot`, `Autopilot`, `DungeonBuilder.build`, `Grade.world_environment`, `Player`, `EncounterMarker`, `Kit`.
- Produces:
  - `crawl.bind(g: GameRoot) -> void`
  - `crawl.build_floor() -> void`
  - `crawl.layout: FloorLayout`, `crawl.player: Player`, `crawl.markers: Array`
  - signal `floor_built(floor: int)`

- [ ] **Step 1: Write the failing test**

Create `tests/game/crawl_test.gd`:

```gdscript
extends GdUnitTestSuite
## The wiring test. The assertion that matters most is the last one: the
## world reads the run and reports intent, and the run only ever changes
## through RunEngine (spec §4). Everything else here is scaffolding around
## that one invariant.

var _save_path: String


func before_test() -> void:
	_save_path = "user://crawl_test_%d.json" % Time.get_ticks_usec()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = _save_path
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	return g


func _crawl() -> Crawl:
	var c: Crawl = auto_free(Crawl.new())
	add_child(c)
	c.bind(_game())
	return c


func test_it_builds_the_floor_the_run_is_on() -> void:
	var c := _crawl()
	assert_object(c.game.campaign.run).is_not_null()
	assert_object(c.layout).is_not_null()
	assert_int(c.layout.width).is_equal(LayoutGenerator.GRID)
	assert_object(c.get_node("World/Floors")).is_not_null()
	assert_object(c.get_node("World/Collision")).is_not_null()


func test_the_descent_draft_never_leaves_the_player_in_a_room_that_does_not_exist() -> void:
	# A run opens in phase "descent" with card offers. Stage 2 has no draft
	# screen, so the crawl settles past it; either way the phase it builds a
	# floor in is a phase that has nodes.
	var c := _crawl()
	assert_str(c.game.campaign.run.phase).is_not_equal("descent")


func test_the_player_starts_in_the_entry_room() -> void:
	var c := _crawl()
	assert_object(c.player).is_not_null()
	var cell := Kit.world_to_cell(c.player.position)
	assert_vector(cell).is_equal(c.layout.room_center(c.layout.entry_room))
	assert_bool(c.layout.is_walkable(cell.x, cell.y)).is_true()


func test_there_is_one_marker_per_unresolved_node() -> void:
	var c := _crawl()
	var run := c.game.campaign.run
	assert_array(c.markers).has_size(run.nodes.size())
	var rooms: Array = []
	for m in c.markers:
		var marker: EncounterMarker = m
		rooms.append(c.layout.room_of_node(marker.index))
	assert_array(rooms).is_not_empty()
	# Two encounters in one room would make the second unreachable.
	assert_int(rooms.size()).is_equal(_unique(rooms).size())


func test_walking_into_a_room_enters_that_node_and_only_that_node() -> void:
	var c := _crawl()
	var run := c.game.campaign.run
	var marker: EncounterMarker = c.markers[c.markers.size() - 1]
	var chosen := marker.index
	marker.report(c.player)
	var entries := TestFixtures.run_events_of(run, "node_enter")
	assert_array(entries).has_size(1)
	assert_int(int(entries[0]["index"])).is_equal(chosen)
	assert_bool(run.is_resolved(chosen)).is_true()


func test_clearing_every_room_unlocks_the_stairs() -> void:
	var c := _crawl()
	var run := c.game.campaign.run
	assert_bool(c.stairs.visible).is_false()
	for m in c.markers.duplicate():
		var marker: EncounterMarker = m
		if run.is_over():
			break
		marker.report(c.player)
	if run.is_over():
		return  # The hero died on the way; the stairs question is moot.
	assert_str(run.phase).is_equal("exit")
	assert_bool(c.stairs.visible).is_true()


func test_taking_the_stairs_builds_the_next_floor() -> void:
	var c := _crawl()
	var run := c.game.campaign.run
	var started := run.floor
	for m in c.markers.duplicate():
		if run.is_over():
			return
		(m as EncounterMarker).report(c.player)
	if run.is_over() or run.phase != "exit" or not RunEngine.can_push(run):
		return
	var before := c.layout
	c.stairs.report(c.player)
	assert_int(c.game.campaign.run.floor).is_equal(started + 1)
	assert_object(c.layout).is_not_same(before)
	assert_int(c.get_node("World").get_child_count()).is_greater(0)


func test_the_world_only_changes_the_run_through_the_engine() -> void:
	# The invariant of the whole pivot (spec §4). A crawl that has built a
	# floor and had a marker fire has not touched the run object except
	# through GameRoot.run_action, so the run's own event log is the complete
	# record of what happened to it.
	var c := _crawl()
	var run := c.game.campaign.run
	var before := run.events.size()
	c.build_floor()
	assert_int(run.events.size()).is_equal(before)
	(c.markers[0] as EncounterMarker).report(c.player)
	assert_int(run.events.size()).is_greater(before)


func _unique(values: Array) -> Array:
	var seen: Dictionary = {}
	for v in values:
		seen[v] = true
	return seen.keys()
```

- [ ] **Step 2: Run it and watch it fail**

```
cmd //c "tools\\test.cmd tests/game/crawl_test.gd"
```

Expected: failures on `bind` not existing (the Task 1 placeholder has no members).

- [ ] **Step 3: Write `game/world/crawl.gd`**, replacing the placeholder entirely

```gdscript
class_name Crawl
extends Node3D
## The scene root, and the only file under game/world/ that talks to
## GameRoot. It reads the run, builds the floor that run is on, puts the
## player in the entry room, and turns "the player walked in here" into a
## RunEngine action. Nothing under it ever writes to RunState (spec §4).

signal floor_built(floor: int)

var game: GameRoot
var layout: FloorLayout
var player: Player
var markers: Array[EncounterMarker] = []
var stairs: EncounterMarker

var _world: Node3D
var _autopilot := RunAutopilot.new()
var _fight_autopilot := Autopilot.new()


func _ready() -> void:
	if game != null:
		return
	var autoload := get_node_or_null("/root/Game")
	if autoload is GameRoot:
		bind(autoload as GameRoot)


func bind(g: GameRoot) -> void:
	game = g
	if not g.is_booted:
		var result := g.boot()
		if not bool(result["ok"]):
			push_error("crawl: boot failed: %s" % result["reason"])
			return
	if g.campaign.run == null:
		g.start_run(1)
	_settle_to_node()
	build_floor()


func build_floor() -> void:
	var run := game.campaign.run
	if run == null:
		return
	if _world != null:
		_world.queue_free()
	markers.clear()
	stairs = null

	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	layout = RunEngine.layout_for(run)
	DungeonBuilder.build(layout, _world)
	_world.add_child(Grade.world_environment(Grade.depth_of(run.floor, run.biome().last_floor)))

	if player == null:
		player = Player.new()
		player.name = "Player"
		add_child(player)
	player.place_at(_stand_in(layout.entry_room), 0.0)

	for i in run.nodes.size():
		if run.is_resolved(i):
			continue
		var marker := EncounterMarker.create(i, layout.room_rect(layout.room_of_node(i)))
		marker.entered.connect(_on_marker_entered)
		_world.add_child(marker)
		markers.append(marker)

	stairs = EncounterMarker.create(-1, layout.room_rect(layout.stairs_room))
	stairs.name = "Stairs"
	stairs.entered.connect(_on_stairs_entered)
	_world.add_child(stairs)
	_refresh_stairs()

	print("crawl: floor %d, %d rooms, %d encounters left" % [run.floor, layout.rooms.size(), markers.size()])
	floor_built.emit(run.floor)


func _on_marker_entered(index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "node":
		return
	game.run_action({"kind": "enter", "index": index})
	# STAGE 2 SCAFFOLDING. Walking into a room puts the run into "fight",
	# "reward", "event", "rest" or "shop", and stage 2 has no screen for any
	# of them, so the autopilot plays them out. Stage 3 replaces this with the
	# fight staged where you are standing; stage 4 with the other rooms.
	_autoresolve()
	for m in markers:
		var marker: EncounterMarker = m
		if run.is_resolved(marker.index):
			marker.resolve()
	_refresh_stairs()


func _on_stairs_entered(_index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "exit":
		return
	if not RunEngine.can_push(run):
		# STAGE 2 SCAFFOLDING: the bottom of the biome. Stage 4 owns the real
		# exit decision (push / retreat / watch); here it just banks and
		# starts again so the loop can be walked.
		game.run_action({"kind": "retreat"})
		game.finish_run()
		game.start_run(1)
		_settle_to_node()
		build_floor()
		return
	game.run_action({"kind": "push"})
	_settle_to_node()
	build_floor()


## A floor cannot be built while the run is offering descent cards, and stage
## 2 has no draft screen. The autopilot picks, exactly as the demos do.
func _settle_to_node() -> void:
	var run := game.campaign.run
	var guard := 0
	while run != null and not run.is_over() and run.phase != "node" and run.phase != "exit" and guard < 200:
		guard += 1
		if run.phase == "fight":
			_play_fight(run)
			continue
		var action := _autopilot.choose(run)
		if action.is_empty():
			break
		game.run_action(action)


func _autoresolve() -> void:
	_settle_to_node()


func _play_fight(run: RunState) -> void:
	for action in _fight_autopilot.choose_turn(run.fight):
		if run.phase != "fight":
			break
		game.run_action(action)


## The centre of a room, on the floor. Room centres are always carved, so
## this is always somewhere you can stand.
func _stand_in(room_index: int) -> Vector3:
	return Kit.cell_to_world(layout.room_center(room_index))


func _refresh_stairs() -> void:
	if stairs == null:
		return
	var open := game.campaign.run != null and game.campaign.run.phase == "exit"
	stairs.visible = open
	stairs.monitoring = open
```

- [ ] **Step 4: Run the test**

```
cmd //c "tools\\test.cmd tests/game/crawl_test.gd"
```

Expected: 8 passing.

Two failure modes to expect and how to read them:
- **`test_the_player_starts_in_the_entry_room` fails on the cell** — `_stand_in` uses `room_center`, which is integer division, so it is always inside the rect. If it is not walkable, that is a `core/` layout bug and it is fixed in `core/run/layout_generator.gd`, test-first, not papered over here.
- **`test_walking_into_a_room_enters_that_node...` sees more than one `node_enter`** — `_autoresolve` is settling past the node it just entered and into the next one. `_settle_to_node` must stop at phase `node`; check the loop condition.

- [ ] **Step 5: Run the whole suite**

```
cmd //c "tools\\test.cmd tests"
```

Expected: exit 0, **651 tests** (614 + 5 + 6 + 6 + 8 + 9 + 5 + 8).

- [ ] **Step 6: Commit**

```bash
git add game/world/crawl.gd game/world/crawl.gd.uid tests/game/crawl_test.gd tests/game/crawl_test.gd.uid
git commit -m "feat(3d): the crawl builds the floor you are on and walks you into it"
```

---

### Task 8: The evidence

A green headless suite is not evidence that a 3D game looks right or walks right. This task produces the two things that are.

**Files:**
- Create: `tools/crawl_shot.gd`
- Modify: `CLAUDE.md` (document the new tool), `docs/superpowers/plans/2026-08-29-3d-s2-it-can-be-walked.md` (record the findings)

**Interfaces:**
- Consumes: `LayoutGenerator`, `DungeonBuilder`, `Kit`, `Grade`, `Player`.
- Produces: `"$GODOT_BIN" --path . --rendering-method forward_plus --resolution 1280x720 -s tools/crawl_shot.gd -- <out.png> [seed] [frames]`

- [ ] **Step 1: Write `tools/crawl_shot.gd`**

```gdscript
extends SceneTree
## Takes a picture of a real generated floor with the real kit, builder and
## grade -- no GameRoot, no save file, no run. The headless suite cannot see,
## so this is the only thing that can answer "does it look right", and it is
## also where the Steam capsule shot comes from.
##
##   godot --path . --rendering-method forward_plus --resolution 1280x720 \
##         -s tools/crawl_shot.gd -- <out.png> [seed] [frames]
##
## Note the missing --headless: there is no framebuffer to read without a
## renderer, so this runs windowed and reads the viewport texture.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://crawl.png"
	var seed_value := int(args[1]) if args.size() > 1 and String(args[1]).is_valid_int() else 3
	var frames := int(args[2]) if args.size() > 2 and String(args[2]).is_valid_int() else 24

	# SceneTree._init runs before the tree is up: nothing may be added or
	# transformed until a frame has passed.
	await process_frame
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1280, 720)

	var layout := LayoutGenerator.generate(3, Rng.new(seed_value))
	var world := Node3D.new()
	win.add_child(world)
	var counts := DungeonBuilder.build(layout, world)
	world.add_child(Grade.world_environment(0.35))

	var shot := _corridor_shot(layout)
	var cam := Camera3D.new()
	cam.fov = 72.0
	world.add_child(cam)
	cam.look_at_from_position(shot[0], shot[1], Vector3.UP)
	cam.current = true

	# The hero's torch is most of the near light, so the shot is wrong
	# without it: stand a player at the camera and borrow its lamp.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 2.6
	lamp.omni_range = Kit.CELL * 3.0
	lamp.omni_attenuation = 1.6
	cam.add_child(lamp)

	print("crawl_shot: floor cells=%d walls=%d torches=%d boxes=%d" % [
		counts["floors"], counts["walls"], counts["torches"], counts["boxes"]])

	for _i in frames:
		await process_frame
	await process_frame
	var err := win.get_texture().get_image().save_png(out)
	print("crawl_shot -> %s err=%d" % [out, err])
	quit()


## The classic dungeon shot looks ALONG a corridor, not across a room: it is
## the one framing where depth, torch falloff and the vanishing point all do
## their work at once. Deterministic, so a seed always frames the same way.
func _corridor_shot(layout: FloorLayout) -> Array:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var best_len := 0
	var best_from := Vector2i.ZERO
	var best_dir := Vector2i(1, 0)
	for dir in dirs:
		for y in layout.height:
			for x in layout.width:
				if not layout.is_walkable(x, y) or layout.is_walkable(x - dir.x, y - dir.y):
					continue
				var n := 0
				var at := Vector2i(x, y)
				while layout.is_walkable(at.x, at.y):
					n += 1
					at += dir
				if n > best_len:
					best_len = n
					best_from = Vector2i(x, y)
					best_dir = dir
	var from := Kit.cell_to_world(best_from) + Vector3(0.0, Player.EYE, 0.0)
	var to := from + Vector3(best_dir.x, 0.0, best_dir.y) * float(best_len - 1) * Kit.CELL
	to.y = Player.EYE - 0.15
	print("crawl_shot: corridor %d cells from %s dir %s" % [best_len, best_from, best_dir])
	return [from, to]
```

- [ ] **Step 2: Take the picture**

```bash
"$GODOT_BIN" --path . --rendering-method forward_plus --resolution 1280x720 \
  -s tools/crawl_shot.gd -- "$PWD/docs/shots/2026-08-29-stage2-corridor.png" 3 24
```

Create `docs/shots/` first if it does not exist. Look at the PNG. It must show: a corridor receding into fog, warm torch pools with dark between them, stone that repeats at the same scale on the floor and the walls, and a ceiling that is not black.

If the frame is black, the fault is almost always one of: no `WorldEnvironment` (nothing to see), the camera facing a wall, or a ceiling plane facing the wrong way. Add a `diag` argument that raises `ambient_light_energy` to 1.2 and disables fog before assuming the build is broken.

- [ ] **Step 3: Walk it — the part no test can do**

```bash
"$GODOT_BIN" --path .
```

Check, and write the answer for each into Step 5 below:
1. You spawn inside a room, not inside stone.
2. WASD moves you where you are looking; the mouse turns you; Shift is faster; Escape frees the cursor.
3. Walls stop you and you can slide along them without catching on seams.
4. Walking into a lit room prints `crawl: floor N` a moment later — the encounter resolved and the marker went dark.
5. Clearing all three rooms makes the stairs room's marker appear; walking into it builds floor 2 and the fog is thicker.

- [ ] **Step 4: Prove the simulation is untouched**

The pivot's whole claim is that presentation changed and the game did not. Re-run the three headless integration tools and compare against `main`:

```bash
"$GODOT_BIN" --headless --path . -s tools/run_demo.gd -- 1 7 > /tmp/s2_run.txt 2>&1; echo "exit=$?"
"$GODOT_BIN" --headless --path . -s tools/campaign_demo.gd -- 5 3 > /tmp/s2_camp.txt 2>&1; echo "exit=$?"
"$GODOT_BIN" --headless --path . -s tools/balance_sim.gd -- 20 4 > /tmp/s2_bal.txt 2>&1; echo "exit=$?"
```

Use the scratchpad rather than `/tmp` on Windows. Expected: `run_demo` and `campaign_demo` exit 0; **`balance_sim` exits 1 on `main` too**, on the known untuned `watch_beats_corpse` finding — the criterion is not the exit code, it is that the output is byte-identical to a `main` worktree:

```bash
git worktree add ../game-main main
# run the same three commands with --path ../game-main
diff s2_run.txt main_run.txt && echo IDENTICAL
```

- [ ] **Step 5: Record what actually happened**

Append a `## Stage 2 executed` section to this plan with: the final test count, the screenshot path, a one-line answer to each of the five walk checks in Step 3, the diff results from Step 4, and anything that had to change from what this plan says. **Write down what is not true**: any check that failed, any test that had to be dropped, any deviation. A plan that only records successes is not a record.

- [ ] **Step 6: Document the tool in `CLAUDE.md`**

Under `## Environment`, after the balance sim entry:

```markdown
- Crawl shot: `"$GODOT_BIN" --path . --rendering-method forward_plus --resolution 1280x720 -s tools/crawl_shot.gd -- <out.png> [seed] [frames]`.
  Renders one generated floor with the shipped kit, builder and grade and saves a PNG.
  Runs windowed on purpose: `--headless` has no framebuffer to read.
```

- [ ] **Step 7: Commit**

```bash
git add tools/crawl_shot.gd tools/crawl_shot.gd.uid docs/shots CLAUDE.md docs/superpowers/plans/2026-08-29-3d-s2-it-can-be-walked.md
git commit -m "feat(3d): a shot of the real crawl, and the stage 2 record"
```

---

## Self-review

**Spec coverage.** Stage 2 in §9 is "Forward+, player controller, kit, dungeon builder, collision. Walk a generated floor." — Task 1 (Forward+ and the input map), Task 2 (kit), Task 4 (builder, collision), Task 5 (controller), Task 7 (walk a generated floor). §3.3's five `project.godot` changes are all in Task 1. §8's `game/world/` list: `dungeon_builder.gd` Task 4, `kit.gd` Task 2, `player.gd` Task 5, `encounter_marker.gd` Task 6; `ghost_figure.gd`, `guild_room.gd`, `well_view.gd` belong to stage 5 and are not here. §8's `theme/grade.gd` is Task 3. §4's invariant is asserted directly in `crawl_test.gd`. §7's texel-density discipline is asserted in `kit_test.gd`. §10's "tools demos are the integration test" is Task 8 Step 4.

**Gap, accepted:** §7's `assets/kit/` of authored pieces does not exist and is not built. Recorded in the deviations table with the reason (no artist; procedural boxes proven in stage 0) and the upgrade path (swap `Kit`'s three mesh functions).

**Gap, accepted:** stage 2 deletes nothing from `game/`. The 24 doomed UI suites still run and still pass, which keeps the regression net whole. They go when their replacements exist, in stages 3–5.

**Placeholder scan.** Every code step carries the actual code. Every test step carries the actual assertions. Two steps say "if this fails, do X" — Task 5 Step 4 and Task 7 Step 4 — and both name the specific failure, the specific cause and the specific decision, rather than "handle errors".

**Type consistency.** `Kit.CELL`/`WALL_H`/`TEXEL` are used by name in Tasks 4, 5, 6, 7, 8 and defined in 2. `DungeonBuilder.LAYER_WORLD = 1` is consumed by `Player` in Task 5. `Player.LAYER_PLAYER = 2` is consumed by `EncounterMarker` in Task 6. `EncounterMarker.LAYER_INTERACTABLE = 4` is layer 3's bit value — the constant name says the layer, the value says the bit, and the test asserts the value; that is the trap in this file and it is asserted rather than commented. `EncounterMarker.create(index, room)` takes the room rect dictionary that `FloorLayout.room_rect` returns, with keys `x`,`y`,`w`,`h` — the same shape `LayoutGenerator.place_rooms` writes. `marker.report(body)` is the name used by both the signal connection and every test. `Grade.depth_of(floor, last_floor)` matches `Atmosphere.set_floor`'s existing 2D convention, so the two agree about what depth means.
