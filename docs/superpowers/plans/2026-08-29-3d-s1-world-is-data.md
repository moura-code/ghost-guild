# 3D Pivot — Stage 1: The World Is Data — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a floor something you can walk in any order and something whose shape is generated as pure data — with no 3D code written yet.

**Architecture:** Two independent pieces. First, `RunState` gains a per-node `resolved` flag and `RunEngine` accepts `{"kind": "enter", "index": i}`, so the player picks which room to enter instead of following a fixed order; the bare `{"kind": "enter"}` keeps meaning "the next unresolved node", which is what keeps the autopilot, the demos and the balance simulator working untouched. Second, a new pure module pair — `FloorLayout` (the data) and `LayoutGenerator` (the seeded algorithm) — produces rooms, corridors, walls, role assignments and dressing anchors on an integer grid, tested headless. Stage 2's 3D builder will consume that data; nothing in this stage renders anything.

**Tech Stack:** Godot 4.7.2, GDScript with static typing, GdUnit4, no engine randomness.

**Spec:** `docs/superpowers/specs/2026-08-29-3d-pivot-design.md` (§5 for the `core/run/` change, §6 for the layout module, §10 for testing)

## Global Constraints

Copied from `CLAUDE.md` and the spec. Every task's requirements implicitly include this section.

- Everything under `core/` extends `RefCounted` only: no `Node`, no scene tree.
- No engine randomness (`randi()`, `randf()`, `shuffle()`, `pick_random()`). All randomness goes through `Rng`'s named streams. The layout module uses exactly one stream, named `"layout"`.
- Static typing everywhere; `Variant` only where JSON parsing forces it.
- Engine functions mutate a state object and return the events they produced. Event payloads are immutable snapshots: `duplicate()` any array or dictionary put in an event.
- Nothing in `core/` reads the clock.
- **Commit every `.gd.uid` sidecar alongside its `.gd` file.** Godot writes the sidecar during the `--import` pass that `tools\test.cmd` runs first, so the order is always: write the file → run the tests → `git add` both.
- Test command, from Git Bash: `cmd //c "tools\\test.cmd <dir-or-file>"`. Exit code 0 on success. The full suite takes about 2min 45s; a single file takes a few seconds.
- Baseline to preserve: **576 test cases across 60 suites, green.** Task 2 edits five existing assertions across four files by design (see its Step 7); nothing else may go red.
- **`balance_sim` exits 1 on `main` and must keep exiting 1** — its `watch_beats_corpse` invariant is a known untuned balance finding, not a broken build. The acceptance criterion for the demos is therefore *output identical to `main`*, not exit 0. Compare with a throwaway worktree: `git worktree add <tmp> main`, import it headlessly, run the same command in both, `diff`.
- Every commit ends with the repo's two trailers:

  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
  ```

- Branch: `3d-pivot`. Do not merge to `main`.

## File Structure

| File | Responsibility |
|---|---|
| `core/run/run_state.gd` *(modify)* | Gains `resolved: Array` plus the four accessors that keep it sized to `nodes`, and serialises it. |
| `core/run/run_engine.gd` *(modify)* | `legal_actions` offers one `enter` per unresolved node; `_enter_node` takes a target; `_advance` marks resolved; `layout_for` derives the floor's shape. |
| `core/save/save_game.gd` *(modify)* | `VERSION` 2 and the migration that fills `resolved` for saves written before the pivot. |
| `core/run/floor_layout.gd` *(create)* | The floor's shape as data: grid, rooms, roles, anchors, and queries over them. Knows nothing about metres. |
| `core/run/layout_generator.gd` *(create)* | The seeded algorithm that fills a `FloorLayout`: place, carve, connect, wall, assign, dress. |
| `tests/helpers/fixtures.gd` *(modify)* | `set_nodes` resets `resolved` along with `nodes`. |
| `tests/core/run/run_routing_test.gd` *(create)* | Entering a floor's nodes in a chosen order. |
| `tests/core/run/floor_layout_test.gd` *(create)* | The data object's grid and room queries. |
| `tests/core/run/layout_generator_test.gd` *(create)* | Placement, connectivity, walls, roles, anchors, determinism. |
| `tests/core/run/run_flow_test.gd` *(modify)* | One assertion updated to the new `legal_actions` contract. |
| `tests/core/save/save_game_test.gd` *(modify)* | The version 1 → 2 migration. |

`FloorLayout` and `LayoutGenerator` are split for the reason the rest of `core/` is split that way — `FloorGenerator` (static algorithm) and `RunState` (data) already follow it. The data object is what Stage 2's builder depends on; the generator is what changes when floors need to feel different.

---

### Task 1: Nodes remember whether they are done

`RunState` currently tracks only `node_index`, which encodes "how far along the fixed order am I". Walking a floor means the order is the player's, so the state has to record *which* nodes are finished rather than *how many*.

**Files:**
- Modify: `core/run/run_state.gd`
- Modify: `tests/helpers/fixtures.gd:75-78`
- Test: `tests/core/run/run_routing_test.gd` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `RunState.resolved: Array`, `RunState.is_resolved(index: int) -> bool`, `RunState.resolve(index: int) -> void`, `RunState.next_unresolved() -> int`. Task 2 calls all three methods; Task 3 migrates the `"resolved"` key in `to_dict`'s output.

- [ ] **Step 1: Write the failing test**

Create `tests/core/run/run_routing_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_a_fresh_floor_has_nothing_resolved() -> void:
	var run := TestFixtures.new_run(1, 1)
	assert_int(run.next_unresolved()).is_equal(0)
	for i in run.nodes.size():
		assert_bool(run.is_resolved(i)).is_false()


func test_resolving_moves_the_next_unresolved_forward() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(0)
	assert_bool(run.is_resolved(0)).is_true()
	assert_int(run.next_unresolved()).is_equal(1)
	run.resolve(2)
	assert_int(run.next_unresolved()).is_equal(1)
	run.resolve(1)
	assert_int(run.next_unresolved()).is_equal(-1)


func test_flags_resize_to_whoever_wrote_the_nodes_last() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(0)
	run.nodes = [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}]
	assert_bool(run.is_resolved(0)).is_true()
	assert_bool(run.is_resolved(3)).is_false()
	assert_int(run.next_unresolved()).is_equal(1)


func test_out_of_range_flags_are_ignored() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(-1)
	run.resolve(99)
	assert_bool(run.is_resolved(-1)).is_false()
	assert_bool(run.is_resolved(99)).is_false()
	assert_int(run.next_unresolved()).is_equal(0)


func test_resolved_flags_survive_a_save_round_trip() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(1)
	var back := RunState.from_dict(TestFixtures.content(), run.to_dict())
	assert_bool(back.is_resolved(0)).is_false()
	assert_bool(back.is_resolved(1)).is_true()
	assert_int(back.next_unresolved()).is_equal(0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/run/run_routing_test.gd"`
Expected: FAIL — `Invalid call. Nonexistent function 'next_unresolved' in base 'RefCounted (RunState)'`.

- [ ] **Step 3: Add the field and its accessors**

In `core/run/run_state.gd`, add the field next to `node_index`:

```gdscript
var node_index: int = 0
## One flag per node, so a floor can be walked in any order. `node_index` still
## means "the node being played"; this is what says which ones are behind you.
var resolved: Array = []
```

Then add the accessors after `current_node()`:

```gdscript
## The flags always match the node list. Nodes get written from three places --
## the floor generator, a loaded save, and the test fixtures -- and a flag array
## that has drifted out of step is a silent wrong answer rather than a crash, so
## every reader sizes it first instead of trusting whoever wrote nodes last.
func _sync_resolved() -> void:
	if resolved.size() == nodes.size():
		return
	var out: Array = []
	for i in nodes.size():
		out.append(bool(resolved[i]) if i < resolved.size() else false)
	resolved = out


func is_resolved(index: int) -> bool:
	_sync_resolved()
	return index >= 0 and index < resolved.size() and bool(resolved[index])


func resolve(index: int) -> void:
	_sync_resolved()
	if index >= 0 and index < resolved.size():
		resolved[index] = true


func next_unresolved() -> int:
	_sync_resolved()
	for i in resolved.size():
		if not bool(resolved[i]):
			return i
	return -1
```

- [ ] **Step 4: Serialise it**

In `to_dict()`, add the key next to `node_index`. The mid-fight rewind needs no special handling: `to_dict` already rewinds `phase` and `fight_counter` to before the fight, and the node being fought is not marked resolved until the fight finishes, so the flags are already correct at that moment.

```gdscript
		"node_index": node_index,
		"resolved": resolved.duplicate(),
```

In `from_dict()`, read it next to `node_index`:

```gdscript
	run.node_index = int(d.get("node_index", 0))
	for flag in d.get("resolved", []):
		run.resolved.append(bool(flag))
```

- [ ] **Step 5: Keep the fixtures in step**

In `tests/helpers/fixtures.gd`, `set_nodes` writes `nodes` directly and is used by most run tests. Reset the flags with them:

```gdscript
static func set_nodes(run: RunState, nodes: Array) -> void:
	run.nodes = nodes
	run.node_index = 0
	run.resolved = []
	run.phase = "node"
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/run/run_routing_test.gd"`
Expected: PASS, 5 test cases, exit code 0.

- [ ] **Step 7: Run the run and save suites for regressions**

Run: `cmd //c "tools\\test.cmd tests/core/run"` then `cmd //c "tools\\test.cmd tests/core/save"`
Expected: PASS both, exit code 0. Nothing should have changed behaviour yet — this task only adds state.

- [ ] **Step 8: Commit**

```bash
git add core/run/run_state.gd core/run/run_state.gd.uid \
        tests/helpers/fixtures.gd tests/helpers/fixtures.gd.uid \
        tests/core/run/run_routing_test.gd tests/core/run/run_routing_test.gd.uid
git commit -F - <<'EOF'
feat(run): a node remembers whether it is done

node_index means "the node being played" and no longer doubles as "how far
along the fixed order am I", because walking a floor means the order is the
player's. The flags resize to the node list on every read: nodes are written
by the generator, by a loaded save and by the fixtures, and a stale flag
array is a wrong answer rather than a crash.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

### Task 2: You choose which room to enter

**Files:**
- Modify: `core/run/run_engine.gd:29-46` (`legal_actions`), `:84-88` (`apply`), `:149-178` (`_enter_floor`, `_enter_node`), `:240-246` (`_advance`)
- Modify: `tests/core/run/run_flow_test.gd:15`
- Test: `tests/core/run/run_routing_test.gd` (extend)

**Interfaces:**
- Consumes: `RunState.is_resolved(index)`, `RunState.resolve(index)`, `RunState.next_unresolved()` from Task 1.
- Produces: the action `{"kind": "enter", "index": int}`. `{"kind": "enter"}` with no index still resolves to `next_unresolved()`. Task 8 adds `RunEngine.layout_for(run)` to the same file.

- [ ] **Step 1: Write the failing test**

Append to `tests/core/run/run_routing_test.gd`:

```gdscript
func test_every_unresolved_node_is_on_offer() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	assert_array(RunEngine.legal_actions(run)).is_equal([
		{"kind": "enter", "index": 0},
		{"kind": "enter", "index": 1},
		{"kind": "enter", "index": 2},
	])


func test_a_floor_can_be_walked_out_of_order() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter", "index": 2})
	assert_int(run.node_index).is_equal(2)
	RunEngine.apply(run, {"kind": "rest_heal"})
	assert_bool(run.is_resolved(2)).is_true()
	assert_str(run.phase).is_equal("node")
	assert_array(RunEngine.legal_actions(run)).is_equal([
		{"kind": "enter", "index": 0},
		{"kind": "enter", "index": 1},
	])


func test_the_stairs_wait_until_every_room_is_done() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	for index in [1, 0, 2]:
		assert_str(run.phase).is_equal("node")
		RunEngine.apply(run, {"kind": "enter", "index": index})
		RunEngine.apply(run, {"kind": "rest_heal"})
	assert_str(run.phase).is_equal("exit")
	assert_array(TestFixtures.run_events_of(run, "floor_cleared")).has_size(1)


func test_a_bare_enter_still_takes_the_next_one() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_int(run.node_index).is_equal(0)
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "enter"})
	assert_int(run.node_index).is_equal(1)


func test_a_resolved_or_missing_room_cannot_be_entered() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	assert_str(run.phase).is_equal("node")
	RunEngine.apply(run, {"kind": "enter", "index": 7})
	assert_str(run.phase).is_equal("node")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/run/run_routing_test.gd"`
Expected: FAIL — `test_every_unresolved_node_is_on_offer` reports `[{kind:enter}]` against the expected three-entry array.

- [ ] **Step 3: Offer one entry per unresolved node**

In `core/run/run_engine.gd`, `legal_actions`, replace the `"node"` branch:

```gdscript
		"node":
			out.append({"kind": "enter"})
```

with:

```gdscript
		"node":
			for i in run.nodes.size():
				if not run.is_resolved(i):
					out.append({"kind": "enter", "index": i})
```

- [ ] **Step 4: Route the action to the chosen node**

In `apply`, replace the `"node"` branch:

```gdscript
		"node":
			if kind == "enter":
				_enter_node(run)
			else:
				push_error("run: expected enter, got " + kind)
```

with:

```gdscript
		"node":
			if kind == "enter":
				# No index means "the next one", which is what the autopilot,
				# the demos and the balance simulator all send.
				_enter_node(run, int(action.get("index", run.next_unresolved())))
			else:
				push_error("run: expected enter, got " + kind)
```

Change `_enter_node` to take the target and guard it:

```gdscript
static func _enter_node(run: RunState, index: int) -> void:
	if index < 0 or index >= run.nodes.size() or run.is_resolved(index):
		push_error("enter: cannot enter node %d" % index)
		return
	run.node_index = index
	var node := run.current_node()
	var kind := String(node.get("kind", ""))
	run.emit({"type": "node_enter", "index": run.node_index, "kind": kind})
```

The rest of `_enter_node`'s body is unchanged. Its error branch already calls `_advance(run)`, which stays correct.

- [ ] **Step 5: Mark the node done and hold the stairs**

Replace `_advance`:

```gdscript
static func _advance(run: RunState) -> void:
	if run.node_index < run.nodes.size() - 1:
		run.node_index += 1
		run.phase = "node"
	else:
		run.phase = "exit"
		run.emit({"type": "floor_cleared", "floor": run.floor})
```

with:

```gdscript
## The floor exits only when every node is behind you. Keeping the count of
## encounters per floor fixed is what lets the balance invariants of spec §12
## stand unchanged through the pivot -- you choose the order, not the number.
static func _advance(run: RunState) -> void:
	run.resolve(run.node_index)
	if run.next_unresolved() >= 0:
		run.phase = "node"
	else:
		run.phase = "exit"
		run.emit({"type": "floor_cleared", "floor": run.floor})
```

In `_enter_floor`, clear the flags when the new floor's nodes are written:

```gdscript
	run.node_index = 0
	run.resolved = []
	run.phase = "node"
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/run/run_routing_test.gd"`
Expected: PASS, 10 test cases, exit code 0.

- [ ] **Step 7: Update the one assertion that encoded the old contract**

`tests/core/run/run_flow_test.gd:15` asserts the single-action shape. Replace:

```gdscript
	assert_array(RunEngine.legal_actions(run)).is_equal([{"kind": "enter"}])
```

with:

```gdscript
	assert_array(RunEngine.legal_actions(run)).is_equal([
		{"kind": "enter", "index": 0},
		{"kind": "enter", "index": 1},
		{"kind": "enter", "index": 2},
	])
```

- [ ] **Step 8: Run the full suite**

Run: `cmd //c "tools\\test.cmd tests"`
Expected: PASS, exit code 0, **586 test cases** (576 baseline + 5 from Task 1 + 5 from Task 2).

Four suites fail on the first run — `run_flow_test`, `run_nodes_test`, `run_save_test` and `save_game_test` each assert `node_index == 1` after the first node finishes. That is one cause, not four bugs: `_advance` used to walk `node_index` forward, so between nodes it pointed at the next one. With per-node flags that pointer is vestigial, and leaving it advanced would hand the 3D layer a room the player never chose, so `node_index` keeps its single meaning. Replace each of the four with the state that carries the meaning now:

```gdscript
	assert_bool(run.is_resolved(0)).is_true()
	assert_int(run.next_unresolved()).is_equal(1)
```

(in `run_save_test` the receiver is `back`, in `save_game_test` it is `back.run`). Behaviour is unaffected: `save_game_test` still applies a bare `enter` then `rest_heal` after its round trip and lands on the right node, because `resolved` survives serialisation.

- [ ] **Step 9: Verify the demos still agree**

Run:

```bash
"$GODOT_BIN" --headless --path . -s tools/run_demo.gd -- 1 7
"$GODOT_BIN" --headless --path . -s tools/balance_sim.gd -- 20 4
```

Expected: `run_demo` exits 0; `balance_sim` exits **1**, on the pre-existing `watch_beats_corpse` finding. Capture both outputs and diff them against the same commands run in a `main` worktree — they must be **byte-identical**. These drive `core/` through the bare `enter` action, so this is the real proof that the contract change is backwards compatible. Note that `$?` after a pipe reports the pipe's status, so redirect to a file rather than piping to `tail`.

- [ ] **Step 10: Commit**

```bash
git add core/run/run_engine.gd core/run/run_engine.gd.uid \
        tests/core/run/run_routing_test.gd tests/core/run/run_flow_test.gd
git commit -F - <<'EOF'
feat(run): the floor is entered in the order you choose

legal_actions offers one enter per unresolved node and enter carries the
target, so a floor can be walked in any order. A bare enter still means "the
next one", which is what the autopilot, the demos and the balance simulator
send -- so they are untouched.

The stairs still wait for every node, so the count of encounters per floor is
unchanged and the spec §12 balance invariants stand. One assertion in
run_flow_test encoded the old single-action contract and moves with it.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

### Task 3: Old saves learn the new flag

**Files:**
- Modify: `core/save/save_game.gd:8` (`VERSION`), `:53-62` (`migrate`)
- Test: `tests/core/save/save_game_test.gd` (extend)

**Interfaces:**
- Consumes: the `"resolved"` key written by `RunState.to_dict` in Task 1.
- Produces: `SaveGame.VERSION == 2`. No later task depends on this.

- [ ] **Step 1: Write the failing test**

Append to `tests/core/save/save_game_test.gd`:

```gdscript
func test_version_one_saves_learn_which_nodes_were_done() -> void:
	var old := {
		"version": 1,
		"run": {
			"nodes": [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}],
			"node_index": 2,
		},
	}
	var migrated := SaveGame.migrate(old)
	assert_int(int(migrated["version"])).is_equal(SaveGame.VERSION)
	assert_array(migrated["run"]["resolved"]).is_equal([true, true, false])


func test_migration_leaves_a_save_with_no_run_alone() -> void:
	var migrated := SaveGame.migrate({"version": 1, "run": {}})
	assert_int(int(migrated["version"])).is_equal(SaveGame.VERSION)
	assert_bool((migrated["run"] as Dictionary).has("resolved")).is_false()


func test_migration_does_not_overwrite_flags_it_already_has() -> void:
	var migrated := SaveGame.migrate({
		"version": 1,
		"run": {"nodes": [{"kind": "rest"}, {"kind": "rest"}], "node_index": 0, "resolved": [false, true]},
	})
	assert_array(migrated["run"]["resolved"]).is_equal([false, true])
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/save/save_game_test.gd"`
Expected: FAIL — the migrated run has no `"resolved"` key.

- [ ] **Step 3: Bump the version and add the migration**

In `core/save/save_game.gd`, change the constant:

```gdscript
const VERSION := 2
```

Add the case to `migrate`:

```gdscript
		match version:
			0:
				pass
			1:
				_fill_run_resolved(out)
```

And the migration itself, after `migrate`:

```gdscript
## Version 2 gave every node its own resolved flag so a floor can be walked in
## any order. A version 1 run always cleared its nodes in index order, so
## everything before node_index is exactly what was already done.
static func _fill_run_resolved(d: Dictionary) -> void:
	var raw: Variant = d.get("run", {})
	if not (raw is Dictionary):
		return
	var run: Dictionary = raw
	if run.is_empty() or run.has("resolved"):
		return
	var nodes: Array = run.get("nodes", [])
	var index := int(run.get("node_index", 0))
	var flags: Array = []
	for i in nodes.size():
		flags.append(i < index)
	run["resolved"] = flags
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/save/save_game_test.gd"`
Expected: PASS, exit code 0.

- [ ] **Step 5: Run the save and campaign suites**

Run: `cmd //c "tools\\test.cmd tests/core/save"` then `cmd //c "tools\\test.cmd tests/core/campaign_test.gd"`
Expected: PASS both, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add core/save/save_game.gd core/save/save_game.gd.uid tests/core/save/save_game_test.gd
git commit -F - <<'EOF'
feat(save): version 2 fills in the resolved flags

A version 1 run always cleared its nodes in index order, so everything before
node_index is exactly what had been resolved. A save already carrying flags is
left alone, so the migration is safe to run twice.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

### Task 4: The floor's shape, as data

**Files:**
- Create: `core/run/floor_layout.gd`
- Test: `tests/core/run/floor_layout_test.gd` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `class_name FloorLayout`, `enum Cell { VOID, FLOOR, WALL }` (VOID is 0 so a fresh grid is void), `FloorLayout.create(width: int, height: int) -> FloorLayout`, and the fields `width`, `height`, `cells: PackedByteArray`, `rooms: Array` (of `{"x": int, "y": int, "w": int, "h": int}`), `entry_room: int`, `stairs_room: int`, `node_rooms: Array`, `torch_anchors: Array` (of `Vector2i`), `ghost_anchors: Array` (of `Vector2i`). Methods: `in_bounds(x, y) -> bool`, `cell(x, y) -> int`, `set_cell(x, y, value) -> void`, `is_walkable(x, y) -> bool`, `room_rect(index) -> Dictionary`, `room_center(index) -> Vector2i`, `room_of_node(node_index) -> int`. Tasks 5–8 fill these fields; Stage 2's builder reads them.

- [ ] **Step 1: Write the failing test**

Create `tests/core/run/floor_layout_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_a_new_grid_is_solid_void() -> void:
	var layout := FloorLayout.create(6, 4)
	assert_int(layout.width).is_equal(6)
	assert_int(layout.height).is_equal(4)
	assert_int(layout.cells.size()).is_equal(24)
	for y in 4:
		for x in 6:
			assert_int(layout.cell(x, y)).is_equal(FloorLayout.Cell.VOID)


func test_cells_are_addressed_by_row() -> void:
	var layout := FloorLayout.create(6, 4)
	layout.set_cell(2, 3, FloorLayout.Cell.FLOOR)
	assert_int(layout.cell(2, 3)).is_equal(FloorLayout.Cell.FLOOR)
	assert_int(layout.cell(3, 2)).is_equal(FloorLayout.Cell.VOID)
	assert_bool(layout.is_walkable(2, 3)).is_true()
	assert_bool(layout.is_walkable(3, 2)).is_false()


func test_outside_the_grid_reads_as_solid_rock() -> void:
	var layout := FloorLayout.create(6, 4)
	assert_bool(layout.in_bounds(0, 0)).is_true()
	assert_bool(layout.in_bounds(6, 0)).is_false()
	assert_bool(layout.in_bounds(-1, 2)).is_false()
	assert_int(layout.cell(-1, -1)).is_equal(FloorLayout.Cell.VOID)
	assert_int(layout.cell(99, 99)).is_equal(FloorLayout.Cell.VOID)
	layout.set_cell(99, 99, FloorLayout.Cell.FLOOR)
	assert_int(layout.cells.size()).is_equal(24)


func test_a_room_reports_its_middle() -> void:
	var layout := FloorLayout.create(24, 24)
	layout.rooms = [{"x": 2, "y": 3, "w": 4, "h": 5}]
	var centre := layout.room_center(0)
	assert_int(centre.x).is_equal(4)
	assert_int(centre.y).is_equal(5)
	assert_int(int(layout.room_rect(0)["w"])).is_equal(4)


func test_missing_rooms_and_nodes_answer_without_crashing() -> void:
	var layout := FloorLayout.create(24, 24)
	assert_dict(layout.room_rect(0)).is_empty()
	assert_int(layout.room_center(0).x).is_equal(0)
	assert_int(layout.room_of_node(0)).is_equal(-1)


func test_a_room_rect_is_a_copy() -> void:
	var layout := FloorLayout.create(24, 24)
	layout.rooms = [{"x": 2, "y": 3, "w": 4, "h": 5}]
	var rect := layout.room_rect(0)
	rect["w"] = 99
	assert_int(int((layout.rooms[0] as Dictionary)["w"])).is_equal(4)


func test_nodes_map_to_rooms() -> void:
	var layout := FloorLayout.create(24, 24)
	layout.node_rooms = [2, 1, 3]
	assert_int(layout.room_of_node(0)).is_equal(2)
	assert_int(layout.room_of_node(2)).is_equal(3)
	assert_int(layout.room_of_node(9)).is_equal(-1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/run/floor_layout_test.gd"`
Expected: FAIL — `Identifier "FloorLayout" not declared in the current scope`.

- [ ] **Step 3: Write the data object**

Create `core/run/floor_layout.gd`:

```gdscript
class_name FloorLayout
extends RefCounted
## The shape of one floor as data: a grid of cells, the rooms carved into it,
## which room holds which encounter, and where the dressing goes. Built by
## LayoutGenerator from a seed and read by the 3D builder, which owns the
## metres -- nothing here knows how big a cell is in the world, so the whole
## thing stays testable headless like the rest of core/.

enum Cell { VOID, FLOOR, WALL }

var width: int = 0
var height: int = 0
## Row-major, one byte per cell, holding a Cell value. VOID is 0, so a freshly
## resized grid is solid rock without a fill pass.
var cells: PackedByteArray = PackedByteArray()
## Grid rects: {"x": int, "y": int, "w": int, "h": int}.
var rooms: Array = []
var entry_room: int = -1
var stairs_room: int = -1
## node_rooms[node_index] -> index into rooms.
var node_rooms: Array = []
var torch_anchors: Array = []
var ghost_anchors: Array = []


static func create(p_width: int, p_height: int) -> FloorLayout:
	var layout := FloorLayout.new()
	layout.width = maxi(0, p_width)
	layout.height = maxi(0, p_height)
	layout.cells.resize(layout.width * layout.height)
	return layout


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## Outside the grid reads as VOID so callers can scan a neighbourhood without
## guarding every edge: the world behaves like solid rock past its own border.
func cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Cell.VOID
	return cells[y * width + x]


func set_cell(x: int, y: int, value: int) -> void:
	if in_bounds(x, y):
		cells[y * width + x] = value


func is_walkable(x: int, y: int) -> bool:
	return cell(x, y) == Cell.FLOOR


func room_rect(index: int) -> Dictionary:
	if index < 0 or index >= rooms.size():
		return {}
	return (rooms[index] as Dictionary).duplicate()


func room_center(index: int) -> Vector2i:
	if index < 0 or index >= rooms.size():
		return Vector2i.ZERO
	var r: Dictionary = rooms[index]
	return Vector2i(int(r["x"]) + int(r["w"]) / 2, int(r["y"]) + int(r["h"]) / 2)


func room_of_node(node_index: int) -> int:
	if node_index < 0 or node_index >= node_rooms.size():
		return -1
	return int(node_rooms[node_index])
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/run/floor_layout_test.gd"`
Expected: PASS, 7 test cases, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add core/run/floor_layout.gd core/run/floor_layout.gd.uid \
        tests/core/run/floor_layout_test.gd tests/core/run/floor_layout_test.gd.uid
git commit -F - <<'EOF'
feat(run): a floor's shape is a grid you can hold in memory

The data half of the layout module: cells, rooms, roles and anchors, with the
queries the builder will need. It knows nothing about metres, so the whole
thing is testable headless like the rest of core/. Reads outside the grid
answer VOID so neighbourhood scans do not have to guard every edge.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

### Task 5: Rooms, one per block

**Files:**
- Create: `core/run/layout_generator.gd`
- Test: `tests/core/run/layout_generator_test.gd` (create)

**Interfaces:**
- Consumes: `FloorLayout.create`, `FloorLayout.rooms`, `FloorLayout.room_center` from Task 4; `Rng.randi_range(name, from, to)` and `Rng.shuffle(name, items)`.
- Produces: `class_name LayoutGenerator`, constants `STREAM := "layout"`, `GRID := 24`, `BLOCK := 8`, `BLOCKS_PER_SIDE := 3`, `ROOM_MIN := 3`, `ROOM_MAX := 6`, and `LayoutGenerator.place_rooms(layout: FloorLayout, count: int, rng: Rng) -> void`. Tasks 6–8 add `carve_rooms`, `connect_rooms`, `add_walls`, `assign_roles`, `place_anchors` and `generate` to this file.

- [ ] **Step 1: Write the failing test**

Create `tests/core/run/layout_generator_test.gd`:

```gdscript
extends GdUnitTestSuite


func _placed(seed: int, count: int = 5) -> FloorLayout:
	var layout := FloorLayout.create(LayoutGenerator.GRID, LayoutGenerator.GRID)
	LayoutGenerator.place_rooms(layout, count, Rng.new(seed))
	return layout


func test_it_places_every_room_it_was_asked_for() -> void:
	for seed in 12:
		assert_array(_placed(seed).rooms).has_size(5)


func test_rooms_stay_inside_the_grid() -> void:
	for seed in 12:
		var layout := _placed(seed)
		for raw in layout.rooms:
			var r: Dictionary = raw
			assert_bool(int(r["x"]) >= 0).is_true()
			assert_bool(int(r["y"]) >= 0).is_true()
			assert_bool(int(r["x"]) + int(r["w"]) <= layout.width).is_true()
			assert_bool(int(r["y"]) + int(r["h"]) <= layout.height).is_true()
			assert_bool(int(r["w"]) >= LayoutGenerator.ROOM_MIN).is_true()
			assert_bool(int(r["h"]) <= LayoutGenerator.ROOM_MAX).is_true()


func test_rooms_never_overlap_or_touch() -> void:
	for seed in 12:
		var rooms := _placed(seed).rooms
		for i in rooms.size():
			for j in range(i + 1, rooms.size()):
				var a: Dictionary = rooms[i]
				var b: Dictionary = rooms[j]
				var apart_x: bool = int(a["x"]) + int(a["w"]) < int(b["x"]) or int(b["x"]) + int(b["w"]) < int(a["x"])
				var apart_y: bool = int(a["y"]) + int(a["h"]) < int(b["y"]) or int(b["y"]) + int(b["h"]) < int(a["y"])
				assert_bool(apart_x or apart_y).is_true()


func test_placement_is_deterministic_and_varies_by_seed() -> void:
	assert_array(_placed(4).rooms).is_equal(_placed(4).rooms)
	var seen: Dictionary = {}
	for seed in 20:
		seen[str(_placed(seed).rooms)] = true
	assert_int(seen.size()).is_greater(1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: FAIL — `Identifier "LayoutGenerator" not declared in the current scope`.

- [ ] **Step 3: Write the placer**

Create `core/run/layout_generator.gd`:

```gdscript
class_name LayoutGenerator
extends RefCounted
## Builds a FloorLayout from a seed: place rooms, carve them, join them with
## corridors, ring the result in wall, hand out the roles, then dress it.
## Uses the "layout" rng stream only, so generating a floor's shape never
## disturbs the encounter or fight streams.

const STREAM := "layout"
const GRID := 24
## The grid is partitioned into BLOCKS_PER_SIDE^2 blocks of BLOCK cells and
## each room gets its own block, so rooms cannot overlap and placement cannot
## fail. Rejection sampling on an open grid can run out of attempts and quietly
## return a floor with a room missing, which would strand an encounter with no
## room to happen in -- a wrong answer rather than a crash.
const BLOCK := 8
const BLOCKS_PER_SIDE := 3
const ROOM_MIN := 3
const ROOM_MAX := 6
## One cell of padding inside each block, so neighbouring rooms always have at
## least one solid cell between them and never share a wall.
const PAD := 1


static func place_rooms(layout: FloorLayout, count: int, rng: Rng) -> void:
	var slots: Array = []
	for by in BLOCKS_PER_SIDE:
		for bx in BLOCKS_PER_SIDE:
			slots.append(Vector2i(bx, by))
	rng.shuffle(STREAM, slots)
	var rooms: Array = []
	var span := BLOCK - PAD * 2
	for i in mini(count, slots.size()):
		var slot: Vector2i = slots[i]
		var w := rng.randi_range(STREAM, ROOM_MIN, mini(ROOM_MAX, span))
		var h := rng.randi_range(STREAM, ROOM_MIN, mini(ROOM_MAX, span))
		var x := slot.x * BLOCK + PAD + rng.randi_range(STREAM, 0, span - w)
		var y := slot.y * BLOCK + PAD + rng.randi_range(STREAM, 0, span - h)
		rooms.append({"x": x, "y": y, "w": w, "h": h})
	layout.rooms = rooms
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: PASS, 4 test cases, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add core/run/layout_generator.gd core/run/layout_generator.gd.uid \
        tests/core/run/layout_generator_test.gd tests/core/run/layout_generator_test.gd.uid
git commit -F - <<'EOF'
feat(run): rooms get a block each

One room per block of a 3x3 partition rather than rejection sampling on an
open grid: placement cannot overlap and cannot fail. Sampling that runs out
of attempts returns a floor with a room missing, which strands an encounter
with nowhere to happen -- a wrong answer rather than a crash, and the kind
that only shows up on one seed in a hundred.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

### Task 6: Corridors, and the guarantee that you can get everywhere

**Files:**
- Modify: `core/run/layout_generator.gd`
- Modify: `core/run/floor_layout.gd`
- Test: `tests/core/run/layout_generator_test.gd` (extend)

**Interfaces:**
- Consumes: `LayoutGenerator.place_rooms` from Task 5.
- Produces: `LayoutGenerator.carve_rooms(layout) -> void`, `LayoutGenerator.carve_corridor(layout, a: Vector2i, b: Vector2i, horizontal_first: bool) -> void`, `LayoutGenerator.connect_rooms(layout, rng) -> void`, and `FloorLayout.reachable_from(start: Vector2i) -> Dictionary` (keys are `Vector2i`). Tasks 7 and 8 call `reachable_from` in their tests.

- [ ] **Step 1: Write the failing test**

Append to `tests/core/run/layout_generator_test.gd`:

```gdscript
func _carved(seed: int, count: int = 5) -> FloorLayout:
	var layout := _placed(seed, count)
	LayoutGenerator.carve_rooms(layout)
	LayoutGenerator.connect_rooms(layout, Rng.new(seed))
	return layout


func test_carving_makes_every_room_cell_walkable() -> void:
	var layout := _placed(3)
	LayoutGenerator.carve_rooms(layout)
	for raw in layout.rooms:
		var r: Dictionary = raw
		for y in range(int(r["y"]), int(r["y"]) + int(r["h"])):
			for x in range(int(r["x"]), int(r["x"]) + int(r["w"])):
				assert_bool(layout.is_walkable(x, y)).is_true()


func test_a_corridor_is_carved_in_two_straight_legs() -> void:
	var layout := FloorLayout.create(10, 10)
	LayoutGenerator.carve_corridor(layout, Vector2i(1, 1), Vector2i(4, 3), true)
	for x in range(1, 5):
		assert_bool(layout.is_walkable(x, 1)).is_true()
	for y in range(1, 4):
		assert_bool(layout.is_walkable(4, y)).is_true()
	assert_bool(layout.is_walkable(1, 3)).is_false()


func test_every_room_can_be_reached_from_every_other() -> void:
	for seed in 12:
		var layout := _carved(seed)
		var seen := layout.reachable_from(layout.room_center(0))
		for i in layout.rooms.size():
			assert_bool(seen.has(layout.room_center(i))).is_true()


func test_reachability_stops_at_rock() -> void:
	var layout := FloorLayout.create(10, 10)
	layout.set_cell(1, 1, FloorLayout.Cell.FLOOR)
	layout.set_cell(1, 2, FloorLayout.Cell.FLOOR)
	layout.set_cell(5, 5, FloorLayout.Cell.FLOOR)
	var seen := layout.reachable_from(Vector2i(1, 1))
	assert_int(seen.size()).is_equal(2)
	assert_bool(seen.has(Vector2i(5, 5))).is_false()
	assert_dict(layout.reachable_from(Vector2i(9, 9))).is_empty()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: FAIL — `Invalid call. Nonexistent function 'carve_rooms' in base 'GDScript'`.

- [ ] **Step 3: Add reachability to the data object**

Append to `core/run/floor_layout.gd`:

```gdscript
## Every walkable cell reachable from `start`, as a set keyed by Vector2i.
## Orthogonal only -- a diagonal gap between two rooms is a wall you can see
## through, not a door you can walk through.
func reachable_from(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not is_walkable(start.x, start.y):
		return seen
	var queue: Array = [start]
	seen[start] = true
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = at + step
			if seen.has(next) or not is_walkable(next.x, next.y):
				continue
			seen[next] = true
			queue.append(next)
	return seen
```

- [ ] **Step 4: Carve and connect**

Append to `core/run/layout_generator.gd`:

```gdscript
static func carve_rooms(layout: FloorLayout) -> void:
	for raw in layout.rooms:
		var r: Dictionary = raw
		for y in range(int(r["y"]), int(r["y"]) + int(r["h"])):
			for x in range(int(r["x"]), int(r["x"]) + int(r["w"])):
				layout.set_cell(x, y, FloorLayout.Cell.FLOOR)


## Both legs are axis-aligned, so the walk below never moves diagonally and can
## never cut a one-cell diagonal gap you cannot walk through.
static func carve_corridor(layout: FloorLayout, a: Vector2i, b: Vector2i, horizontal_first: bool) -> void:
	var corner := Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
	_carve_line(layout, a, corner)
	_carve_line(layout, corner, b)


static func _carve_line(layout: FloorLayout, from: Vector2i, to: Vector2i) -> void:
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var at := from
	layout.set_cell(at.x, at.y, FloorLayout.Cell.FLOOR)
	while at != to:
		at += step
		layout.set_cell(at.x, at.y, FloorLayout.Cell.FLOOR)


## A chain through every room is what guarantees the floor is connected; the
## extra links are what make choosing a route a choice, rather than a single
## corridor with rooms hanging off it.
static func connect_rooms(layout: FloorLayout, rng: Rng) -> void:
	for i in range(1, layout.rooms.size()):
		carve_corridor(layout, layout.room_center(i - 1), layout.room_center(i), rng.randi_range(STREAM, 0, 1) == 0)
	if layout.rooms.size() < 4:
		return
	for _i in 2:
		var a := rng.randi_range(STREAM, 0, layout.rooms.size() - 1)
		var b := rng.randi_range(STREAM, 0, layout.rooms.size() - 1)
		if absi(a - b) < 2:
			continue
		carve_corridor(layout, layout.room_center(a), layout.room_center(b), rng.randi_range(STREAM, 0, 1) == 0)
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: PASS, 8 test cases, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add core/run/layout_generator.gd core/run/floor_layout.gd tests/core/run/layout_generator_test.gd
git commit -F - <<'EOF'
feat(run): corridors, and a floor you can always cross

A chain through every room guarantees connectivity; two extra links give the
floor loops, which is what turns walking it into a route you choose rather
than a corridor with rooms hanging off it. Both corridor legs are axis
aligned, so carving can never leave a diagonal gap -- something you can see
through but not walk through, and the classic way a generated dungeon strands
a room.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

### Task 7: Walls, and who lives where

**Files:**
- Modify: `core/run/layout_generator.gd`
- Test: `tests/core/run/layout_generator_test.gd` (extend)

**Interfaces:**
- Consumes: `carve_rooms`, `connect_rooms` from Task 6.
- Produces: `LayoutGenerator.add_walls(layout) -> void` and `LayoutGenerator.assign_roles(layout, node_count: int, rng: Rng) -> void`, which set `entry_room`, `stairs_room` and `node_rooms`. Task 8 calls both from `generate`.

- [ ] **Step 1: Write the failing test**

Append to `tests/core/run/layout_generator_test.gd`:

```gdscript
func _walled(seed: int, node_count: int = 3) -> FloorLayout:
	var layout := _carved(seed, node_count + 2)
	LayoutGenerator.add_walls(layout)
	LayoutGenerator.assign_roles(layout, node_count, Rng.new(seed))
	return layout


func test_no_walkable_cell_ever_touches_the_void() -> void:
	for seed in 12:
		var layout := _walled(seed)
		for y in layout.height:
			for x in layout.width:
				if not layout.is_walkable(x, y):
					continue
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						assert_int(layout.cell(x + dx, y + dy)).is_not_equal(FloorLayout.Cell.VOID)


func test_walls_only_go_where_they_are_needed() -> void:
	var layout := FloorLayout.create(10, 10)
	layout.set_cell(5, 5, FloorLayout.Cell.FLOOR)
	LayoutGenerator.add_walls(layout)
	assert_int(layout.cell(4, 4)).is_equal(FloorLayout.Cell.WALL)
	assert_int(layout.cell(6, 5)).is_equal(FloorLayout.Cell.WALL)
	assert_int(layout.cell(5, 5)).is_equal(FloorLayout.Cell.FLOOR)
	assert_int(layout.cell(0, 0)).is_equal(FloorLayout.Cell.VOID)
	assert_int(layout.cell(3, 5)).is_equal(FloorLayout.Cell.VOID)


func test_the_stairs_are_never_where_you_came_in() -> void:
	for seed in 12:
		var layout := _walled(seed)
		assert_int(layout.entry_room).is_equal(0)
		assert_int(layout.stairs_room).is_not_equal(layout.entry_room)
		assert_bool(layout.stairs_room >= 0).is_true()


func test_every_encounter_gets_a_room_of_its_own() -> void:
	for seed in 12:
		var layout := _walled(seed)
		assert_array(layout.node_rooms).has_size(3)
		var seen: Dictionary = {}
		for raw in layout.node_rooms:
			var room := int(raw)
			assert_bool(seen.has(room)).is_false()
			seen[room] = true
			assert_int(room).is_not_equal(layout.entry_room)
			assert_int(room).is_not_equal(layout.stairs_room)


func test_the_stairs_go_in_the_room_furthest_from_the_door() -> void:
	var layout := _walled(5)
	var entry := layout.room_center(layout.entry_room)
	var stairs := layout.room_center(layout.stairs_room)
	var furthest := absi(stairs.x - entry.x) + absi(stairs.y - entry.y)
	for i in layout.rooms.size():
		var c := layout.room_center(i)
		assert_bool(absi(c.x - entry.x) + absi(c.y - entry.y) <= furthest).is_true()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: FAIL — `Invalid call. Nonexistent function 'add_walls' in base 'GDScript'`.

- [ ] **Step 3: Ring the floor in wall**

Append to `core/run/layout_generator.gd`:

```gdscript
## Any solid cell touching walkable floor becomes wall; everything else stays
## void and never gets geometry. Diagonals count: a corner left void is a gap
## you can see straight through in a first-person view, and it is exactly the
## seam a modular kit cannot hide. Run this after every corridor is carved, or
## a later corridor punches a hole through a wall ring already built.
static func add_walls(layout: FloorLayout) -> void:
	var around := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for y in layout.height:
		for x in layout.width:
			if layout.cell(x, y) != FloorLayout.Cell.VOID:
				continue
			for step in around:
				if layout.cell(x + step.x, y + step.y) == FloorLayout.Cell.FLOOR:
					layout.set_cell(x, y, FloorLayout.Cell.WALL)
					break
```

- [ ] **Step 4: Hand out the roles**

Append to `core/run/layout_generator.gd`:

```gdscript
## You come in at the first room and the stairs go in the room furthest from
## it, so a floor has a direction even though you may walk it in any order.
## The encounters take the rooms in between, shuffled, so a room's size and
## shape never telegraph what is waiting in it.
static func assign_roles(layout: FloorLayout, node_count: int, rng: Rng) -> void:
	layout.entry_room = 0
	var entry := layout.room_center(0)
	var stairs := -1
	var furthest := -1
	for i in range(1, layout.rooms.size()):
		var c := layout.room_center(i)
		var distance := absi(c.x - entry.x) + absi(c.y - entry.y)
		if distance > furthest:
			furthest = distance
			stairs = i
	layout.stairs_room = stairs
	var free: Array = []
	for i in layout.rooms.size():
		if i != layout.entry_room and i != layout.stairs_room:
			free.append(i)
	rng.shuffle(STREAM, free)
	var out: Array = []
	for i in node_count:
		# generate() always places node_count + 2 rooms, so `free` has exactly
		# one room per node. The wrap is for a caller that asked for more nodes
		# than the 3x3 partition can seat: doubling up is bad, stranding an
		# encounter is worse.
		out.append(int(free[i % free.size()]) if not free.is_empty() else layout.entry_room)
	layout.node_rooms = out
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: PASS, 13 test cases, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add core/run/layout_generator.gd tests/core/run/layout_generator_test.gd
git commit -F - <<'EOF'
feat(run): walls that close, and rooms that know their job

Walls include diagonals: a void corner is a gap you see straight through in
first person, and it is the seam a modular kit cannot hide. You come in at the
first room and the stairs sit in the furthest one, so a floor has a direction
even though you may walk it in any order; encounters take the rooms between,
shuffled, so shape never telegraphs what is inside.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

### Task 8: Dressing, one call, and the run that asks for its floor

**Files:**
- Modify: `core/run/layout_generator.gd`
- Modify: `core/run/run_engine.gd`
- Test: `tests/core/run/layout_generator_test.gd` (extend)

**Interfaces:**
- Consumes: everything from Tasks 4–7, and `RunState.sub_rng(tag, n)`.
- Produces: `LayoutGenerator.place_anchors(layout, rng) -> void`, `LayoutGenerator.generate(node_count: int, rng: Rng) -> FloorLayout`, and `RunEngine.layout_for(run: RunState) -> FloorLayout`. Stage 2's `game/world/dungeon_builder.gd` calls `RunEngine.layout_for`.

- [ ] **Step 1: Write the failing test**

Append to `tests/core/run/layout_generator_test.gd`:

```gdscript
func test_torches_hang_on_walls_that_face_a_walkable_cell() -> void:
	for seed in 8:
		var layout := LayoutGenerator.generate(3, Rng.new(seed))
		assert_array(layout.torch_anchors).is_not_empty()
		for raw in layout.torch_anchors:
			var at: Vector2i = raw
			assert_int(layout.cell(at.x, at.y)).is_equal(FloorLayout.Cell.WALL)
			var faces_floor: bool = layout.is_walkable(at.x + 1, at.y) \
				or layout.is_walkable(at.x - 1, at.y) \
				or layout.is_walkable(at.x, at.y + 1) \
				or layout.is_walkable(at.x, at.y - 1)
			assert_bool(faces_floor).is_true()


func test_ghosts_stand_anywhere_but_the_way_in() -> void:
	var layout := LayoutGenerator.generate(3, Rng.new(2))
	assert_array(layout.ghost_anchors).has_size(layout.rooms.size() - 1)
	var entry := layout.room_center(layout.entry_room)
	for raw in layout.ghost_anchors:
		var at: Vector2i = raw
		assert_bool(at == entry).is_false()
		assert_bool(layout.is_walkable(at.x, at.y)).is_true()


func test_a_generated_floor_is_whole() -> void:
	for seed in 20:
		var layout := LayoutGenerator.generate(3, Rng.new(seed))
		assert_array(layout.rooms).has_size(5)
		var seen := layout.reachable_from(layout.room_center(layout.entry_room))
		assert_bool(seen.has(layout.room_center(layout.stairs_room))).is_true()
		for i in 3:
			assert_bool(seen.has(layout.room_center(layout.room_of_node(i)))).is_true()


func test_generation_is_deterministic_and_varies_by_seed() -> void:
	var a := LayoutGenerator.generate(3, Rng.new(6))
	var b := LayoutGenerator.generate(3, Rng.new(6))
	assert_bool(a.cells == b.cells).is_true()
	assert_array(a.rooms).is_equal(b.rooms)
	assert_array(a.node_rooms).is_equal(b.node_rooms)
	assert_int(a.stairs_room).is_equal(b.stairs_room)
	var seen: Dictionary = {}
	for seed in 20:
		seen[str(LayoutGenerator.generate(3, Rng.new(seed)).rooms)] = true
	assert_int(seen.size()).is_greater(1)


func test_a_run_asks_its_floor_for_a_shape() -> void:
	var run := TestFixtures.new_run(1, 1)
	var once := RunEngine.layout_for(run)
	var twice := RunEngine.layout_for(run)
	assert_array(once.rooms).is_equal(twice.rooms)
	assert_array(once.node_rooms).has_size(run.nodes.size())
	run.floor = 2
	assert_bool(RunEngine.layout_for(run).rooms == once.rooms).is_false()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: FAIL — `Invalid call. Nonexistent function 'generate' in base 'GDScript'`.

- [ ] **Step 3: Dress the floor**

Append to `core/run/layout_generator.gd`:

```gdscript
## Torches hang on walls that face somewhere walkable, thinned to about one in
## five so a corridor is lit in pools rather than evenly. The dark between them
## is the difficulty made physical (spec §2), so the thinning is a design
## choice, not a performance one.
static func place_anchors(layout: FloorLayout, rng: Rng) -> void:
	var torches: Array = []
	for y in layout.height:
		for x in layout.width:
			if layout.cell(x, y) != FloorLayout.Cell.WALL:
				continue
			var faces_floor: bool = layout.is_walkable(x + 1, y) \
				or layout.is_walkable(x - 1, y) \
				or layout.is_walkable(x, y + 1) \
				or layout.is_walkable(x, y - 1)
			if faces_floor and rng.randi_range(STREAM, 0, 4) == 0:
				torches.append(Vector2i(x, y))
	layout.torch_anchors = torches
	var ghosts: Array = []
	for i in layout.rooms.size():
		if i != layout.entry_room:
			ghosts.append(layout.room_center(i))
	rng.shuffle(STREAM, ghosts)
	layout.ghost_anchors = ghosts
```

- [ ] **Step 4: Put the whole pipeline behind one call**

Append to `core/run/layout_generator.gd`:

```gdscript
## Two rooms beyond the encounters: the one you come in by and the one the
## stairs are in. Biome dressing takes a parameter here when there is a second
## biome to dress; the floor number already reaches this through the seed.
static func generate(node_count: int, rng: Rng) -> FloorLayout:
	var layout := FloorLayout.create(GRID, GRID)
	place_rooms(layout, node_count + 2, rng)
	carve_rooms(layout)
	connect_rooms(layout, rng)
	add_walls(layout)
	assign_roles(layout, node_count, rng)
	place_anchors(layout, rng)
	return layout
```

- [ ] **Step 5: Let a run ask for its floor's shape**

In `core/run/run_engine.gd`, add after `exit_summary`:

```gdscript
## The floor's shape, derived from the run seed rather than stored with it: the
## same floor of the same run always builds the same crypt, so the layout never
## goes in the save file and can never disagree with it. Uses its own rng tag,
## so generating geometry never disturbs the encounter or fight streams.
static func layout_for(run: RunState) -> FloorLayout:
	return LayoutGenerator.generate(run.nodes.size(), run.sub_rng("layout", run.floor))
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cmd //c "tools\\test.cmd tests/core/run/layout_generator_test.gd"`
Expected: PASS, 18 test cases, exit code 0.

- [ ] **Step 7: Run the full suite**

Run: `cmd //c "tools\\test.cmd tests"`
Expected: PASS, exit code 0, **614 test cases** (576 baseline + 38 added across Tasks 1–8: 5, 5, 3, 7, 4, 4, 5, 5).

- [ ] **Step 8: Verify the demos and the balance invariants one more time**

Run:

```bash
"$GODOT_BIN" --headless --path . -s tools/run_demo.gd -- 1 7
"$GODOT_BIN" --headless --path . -s tools/campaign_demo.gd -- 3 4
"$GODOT_BIN" --headless --path . -s tools/balance_sim.gd -- 40 6
```

Expected: `run_demo` and `campaign_demo` exit 0; `balance_sim` exits **1** on the pre-existing finding. All three outputs must be byte-identical to the same commands run in a `main` worktree. This is the stage's acceptance check: the game's economy is provably unchanged by everything above.

- [ ] **Step 9: Commit**

```bash
git add core/run/layout_generator.gd core/run/run_engine.gd tests/core/run/layout_generator_test.gd
git commit -F - <<'EOF'
feat(run): a floor generates its own crypt

place_anchors hangs torches on walls that face somewhere walkable, thinned to
about one in five so a corridor is lit in pools -- the dark between them is
the difficulty made physical, so the thinning is a design choice.

RunEngine.layout_for derives the shape from the run seed instead of storing
it, so the layout never goes in the save file and can never disagree with it.
Stage 2's builder reads it and nothing writes back.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_015mnkMMxrhiGpUAq93kWTVB
EOF
```

---

## Stage 1 acceptance

- `cmd //c "tools\\test.cmd tests"` exits 0 with 614 test cases.
- `run_demo`, `campaign_demo` and `balance_sim` produce output byte-identical to `main` — the economy is unchanged. `balance_sim` still exits 1 on its known `watch_beats_corpse` finding, exactly as it does on `main`.
- A floor's three encounters can be entered in any order, and the exit still waits for all three.
- `RunEngine.layout_for(run)` returns a connected floor whose entry, stairs and every encounter room are reachable from one another, identical for a given run and floor.
- No file under `game/` has been touched, and no 3D code exists yet.

## Self-review

**Spec coverage.** §5.1 `resolved` → Task 1. §5.2 `legal_actions` / `_enter_node` / bare-`enter` hinge / `_advance` → Task 2, with the `run_flow_test` exception handled in Step 7. §5.1 save migration → Task 3. §5.3 fixed encounter count → enforced by Task 2 Step 5 and checked by Task 8 Step 8. §6 grid, rooms, corridors, roles, anchors and all five testable properties → Tasks 4–8 (reachability in Tasks 6 and 8, one room per node in Task 7, stairs ≠ entry in Task 7, determinism in Tasks 5 and 8, bounds in Task 5). §10 core suites stay green → Task 2 Step 8 and Task 8 Step 7.

**Deliberate deviation from the spec.** §6 gives `LayoutGenerator.generate` the signature `(biome, floor, run_seed, node_count)`. The plan uses `(node_count, rng)`: the floor number and run seed already reach the generator through `run.sub_rng("layout", run.floor)`, and there is no second biome to dress until Stage 2 has a kit, so a biome parameter would be an unused argument today. Task 8 Step 4 documents where it goes when it is real.

**Type consistency.** `FloorLayout.Cell` is used identically in Tasks 4, 6, 7 and 8. `Vector2i` is the cell type in `room_center`, `reachable_from`, `carve_corridor`, `torch_anchors` and `ghost_anchors` throughout. `rooms` entries are `{"x", "y", "w", "h"}` in Tasks 4, 5, 6 and 7. `STREAM` is the only rng stream name in Tasks 5–8. `is_resolved` / `resolve` / `next_unresolved` are named the same in Tasks 1, 2 and 3.
