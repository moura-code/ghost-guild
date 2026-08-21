# M1-A: Core Combat Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A headless, deterministic, data-driven card-combat engine for Ghost Guild — content loading and validation, the Sexton/Catacombs slice content, the fight engine with statuses, enemy AI, relics and a one-turn-lookahead autopilot — proven by a command-line tool that simulates fights and prints the event log.

**Architecture:** Everything in this plan lives in `core/` and has no Node dependencies: `RefCounted` classes operated on by static engine functions. The engine mutates a `FightState` in place and returns the list of events the mutation produced; `FightState.clone()` gives the autopilot and simulator cheap what-if copies. All randomness flows through one seeded `Rng` with named streams, so every fight is replayable from a seed. Content is JSON under `data/`, loaded into typed definition objects and validated by a test.

**Tech Stack:** Godot 4.3+ (GDScript, static typing), GdUnit4 for tests, JSON content, Git.

**Spec:** `docs/superpowers/specs/2026-08-21-ghost-guild-design.md` (v2) — this plan implements §4 (Combat) in full, §7 (content model) for the slice's combat content, and the `core/combat/`, `core/content/`, `core/rng.gd` and `tools/` parts of §8. Plans M1-B (run & ghost economy) and M1-C (UI) follow.

## Global Constraints

- Godot **4.3 or newer**; GDScript with **static typing everywhere** (every `var`, parameter and return typed; `Variant` only where JSON forces it). No typed dictionaries (`Dictionary[K, V]`) — they need 4.4 and the floor is 4.3.
- **The simulation core has no Node dependencies.** Nothing under `core/` may `extends Node`, touch the scene tree, or call `get_tree()`.
- **Determinism:** all randomness comes from `Rng` named streams. No `randi()`, `randf()`, `shuffle()` or `pick_random()` calls anywhere in `core/`.
- **Engine API shape:** `apply(state, action) -> events` — mutate in place, return the events produced. Events are `Dictionary` values with a `"type"` key.
- **Fights end within 30 turns** under the autopilot (spec §10 invariant); the engine enforces a hard cap of 30 turns by declaring a loss.
- **Content is JSON under `data/`**, every player-facing string is a key resolved through `data/strings/en.csv`; a content validation failure is a test failure.
- **Commit after every task** with the message given in the task. Tests are written before implementation.
- Test command: `tools\test.cmd <dir-or-file>` (defined in Task 1). Every "Run" step below uses it.

---

## File structure

```
project.godot                         Godot project (Task 1)
addons/gdUnit4/                       test framework (Task 1, vendored, not hand-edited)
tools/test.cmd                        headless test runner wrapper (Task 1)
tools/fight_demo.gd                   CLI: simulate a fight, print events (Task 12)
core/rng.gd                           Rng — seeded named streams (Task 2)
core/content/card_def.gd              CardDef (Task 3)
core/content/enemy_def.gd             EnemyDef (Task 3)
core/content/relic_def.gd             RelicDef (Task 3)
core/content/class_def.gd             ClassDef (Task 3)
core/content/biome_def.gd             BiomeDef (Task 3)
core/content/content.gd               Content — loads data/ into defs + strings (Task 3)
core/content/validator.gd             ContentValidator (Task 4)
data/cards/*.json, data/enemies/*.json, data/relics/*.json,
data/classes/*.json, data/biomes/*.json, data/affinity.json,
data/balance.json, data/strings/en.csv   slice content (Task 5)
core/combat/card_instance.gd          CardInstance (Task 6)
core/combat/hero_snapshot.gd          HeroSnapshot — what the run layer hands the engine (Task 6)
core/combat/enemy_state.gd            EnemyState (Task 6)
core/combat/fight_state.gd            FightState + clone() (Task 6)
core/combat/scaling.gd                Scaling — per-floor enemy curves (Task 6)
core/combat/effect_resolver.gd        EffectResolver — ops, damage pipeline (Task 7)
core/combat/enemy_ai.gd               EnemyAI — patterns, move execution, summons (Task 8)
core/combat/relics.gd                 Relics — hook firing (Task 8)
core/combat/status_system.gd          StatusSystem — ticks and decay (Task 9)
core/combat/combat_engine.gd          CombatEngine — start_fight, legal_actions, apply (Task 10)
core/combat/autopilot.gd              Autopilot — one-turn lookahead (Task 11)
core/combat/fight_simulator.gd        FightSimulator — N fights → stats (Task 12)
tests/smoke_test.gd                   harness check (Task 1)
tests/core/rng_test.gd                (Task 2)
tests/core/content/content_test.gd    (Task 3)
tests/core/content/validator_test.gd  (Task 4)
tests/core/content/slice_content_test.gd (Task 5)
tests/core/combat/fight_state_test.gd (Task 6)
tests/core/combat/effects_test.gd     (Task 7)
tests/core/combat/enemy_ai_test.gd    (Task 8)
tests/core/combat/relics_test.gd      (Task 8)
tests/core/combat/status_test.gd      (Task 9)
tests/core/combat/turn_flow_test.gd   (Task 10)
tests/core/combat/autopilot_test.gd   (Task 11)
tests/core/combat/simulator_test.gd   (Task 12)
tests/fixtures/content_ok/...         tiny valid content set for loader tests (Task 3)
tests/helpers/fixtures.gd             TestFixtures — builds in-memory content for engine tests (Task 6)
```

Responsibilities: `content/` knows how to read and check data; `combat/` knows the rules; `rng.gd` knows randomness; `tools/` wires them for humans. Nothing in `combat/` reads files — it receives a `Content` object.

---

### Task 1: Project scaffold and headless test harness

**Files:**
- Create: `project.godot`
- Create: `tools/test.cmd`
- Create: `tests/smoke_test.gd`
- Create: `core/.gdkeep`, `data/.gdkeep`, `tools/.gdkeep`, `tests/.gdkeep` (empty marker files so the directories exist)
- Modify: `.gitignore`
- Vendor: `addons/gdUnit4/` (downloaded, committed as-is)

**Interfaces:**
- Produces: `tools\test.cmd <path...>` — runs GdUnit4 headless on the given test directories/files, exit code 0 on success, non-zero on any failure. Every later task runs tests through it.

- [ ] **Step 1: Install Godot and expose it as `GODOT_BIN`**

Install Godot 4.3+ (standard build, not .NET). On Windows with winget:

```powershell
winget install --id GodotEngine.GodotEngine --exact
```

Find the executable (for winget it lands under `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.*-stable_win64.exe` or is on PATH as `godot`) and set a user environment variable:

```powershell
[Environment]::SetEnvironmentVariable("GODOT_BIN", "<full path to Godot_v4.x-stable_win64.exe>", "User")
```

Open a new shell and verify:

```powershell
& $env:GODOT_BIN --version
```

Expected: a line starting with `4.` (for example `4.4.1.stable.official`).

- [ ] **Step 2: Create `project.godot`**

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.

config_version=5

[application]

config/name="Ghost Guild"
config/features=PackedStringArray("4.3")
config/icon="res://icon.svg"

[debug]

gdscript/warnings/untyped_declaration=1
gdscript/warnings/inferred_declaration=0

[display]

window/size/viewport_width=1280
window/size/viewport_height=720

[editor_plugins]

enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

Create the placeholder icon so the editor does not complain:

```powershell
Set-Content -Path icon.svg -Value '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" fill="#0b0b10"/><circle cx="64" cy="64" r="36" fill="#7fe7ff" fill-opacity="0.6"/></svg>'
```

- [ ] **Step 3: Vendor GdUnit4**

Download the latest GdUnit4 release zip from https://github.com/MikeSchulze/gdUnit4/releases (the asset named like `gdUnit4-v5.x.x.zip`; any 4.x/5.x release that supports Godot 4.3+), extract it, and copy its `addons/gdUnit4` folder into the project so that `addons/gdUnit4/plugin.cfg` and `addons/gdUnit4/bin/GdUnitCmdTool.gd` exist. Then import the project once headlessly so the addon's resources are registered:

```powershell
& $env:GODOT_BIN --headless --path . --import
```

Expected: the command finishes without errors and a `.godot/` directory now exists (it is git-ignored).

- [ ] **Step 4: Create the test runner wrapper `tools/test.cmd`**

```bat
@echo off
setlocal
if "%GODOT_BIN%"=="" set GODOT_BIN=godot
set ARGS=
:loop
if "%~1"=="" goto run
set ARGS=%ARGS% -a %~1
shift
goto loop
:run
"%GODOT_BIN%" --headless --path "%~dp0.." -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode %ARGS%
exit /b %ERRORLEVEL%
```

Usage: `tools\test.cmd tests` runs everything; `tools\test.cmd tests/core/combat` runs one directory; a single file path also works. From Git Bash use `cmd //c tools\\test.cmd tests`.

- [ ] **Step 5: Write the smoke test**

`tests/smoke_test.gd`:

```gdscript
extends GdUnitTestSuite

func test_harness_runs() -> void:
	assert_int(1 + 1).is_equal(2)

func test_can_read_project_file() -> void:
	var text := FileAccess.get_file_as_string("res://project.godot")
	assert_str(text).contains("Ghost Guild")
```

- [ ] **Step 6: Run the smoke test**

Run: `tools\test.cmd tests`
Expected: output ends with a summary reporting 2 test cases, 0 failures, and the process exits with code 0. If GdUnit4 complains about the headless mode, confirm `--ignoreHeadlessMode` is in `tools/test.cmd`; if it reports "no tests found", confirm the file extends `GdUnitTestSuite` and the path passed is `tests`.

- [ ] **Step 7: Update `.gitignore` and create directory markers**

Append to `.gitignore`:

```
# GdUnit4 reports
/reports/
```

Create empty marker files `core/.gdkeep`, `data/.gdkeep`, `tools/.gdkeep` is not needed (tools already has test.cmd), `tests/.gdkeep` is not needed (tests has smoke_test.gd). Only `core/.gdkeep` and `data/.gdkeep` are required:

```powershell
New-Item -ItemType File core/.gdkeep, data/.gdkeep | Out-Null
```

- [ ] **Step 8: Commit**

```bash
git add project.godot icon.svg tools/test.cmd tests/smoke_test.gd addons/gdUnit4 .gitignore core/.gdkeep data/.gdkeep
git commit -m "chore: scaffold Godot project with GdUnit4 headless test runner"
```

---

### Task 2: Rng — seeded named streams

**Files:**
- Create: `core/rng.gd`
- Test: `tests/core/rng_test.gd`

**Interfaces:**
- Produces: `class_name Rng` with `Rng.new(seed: int)`, `stream(name: String) -> RandomNumberGenerator`, `randi_range(name: String, from: int, to: int) -> int`, `randf(name: String) -> float`, `shuffle(name: String, items: Array) -> void` (in place), `pick(name: String, items: Array) -> Variant`, `weighted_pick(name: String, weights: Array) -> int` (index), `clone() -> Rng` (continues identically). Stream names used by the engine: `"deck"` (shuffles and draws), `"enemy_ai"` (move choice), `"encounter"` (reserved for Plan B), `"autopilot"` (reserved for tie-breaks).

- [ ] **Step 1: Write the failing tests**

`tests/core/rng_test.gd`:

```gdscript
extends GdUnitTestSuite

func test_same_seed_same_sequence() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	for i in 10:
		assert_int(a.randi_range("x", 0, 1000)).is_equal(b.randi_range("x", 0, 1000))

func test_different_seeds_differ() -> void:
	var a := Rng.new(1)
	var b := Rng.new(2)
	var same := 0
	for i in 20:
		if a.randi_range("x", 0, 100000) == b.randi_range("x", 0, 100000):
			same += 1
	assert_int(same).is_less(5)

func test_streams_are_independent() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	a.randi_range("other", 0, 1000)
	a.randi_range("other", 0, 1000)
	assert_int(a.randi_range("x", 0, 1000)).is_equal(b.randi_range("x", 0, 1000))

func test_shuffle_is_deterministic_and_permutes() -> void:
	var items := [1, 2, 3, 4, 5, 6, 7, 8]
	var x := items.duplicate()
	var y := items.duplicate()
	Rng.new(7).shuffle("s", x)
	Rng.new(7).shuffle("s", y)
	assert_array(x).is_equal(y)
	assert_array(x).is_not_equal(items)
	x.sort()
	assert_array(x).is_equal(items)

func test_clone_continues_identically() -> void:
	var a := Rng.new(3)
	a.randi_range("x", 0, 100)
	a.randf("y")
	var c := a.clone()
	for i in 5:
		assert_int(a.randi_range("x", 0, 100)).is_equal(c.randi_range("x", 0, 100))
		assert_float(a.randf("y")).is_equal(c.randf("y"))

func test_weighted_pick_skips_zero_weights() -> void:
	var a := Rng.new(1)
	for i in 50:
		assert_int(a.weighted_pick("w", [0.0, 1.0, 0.0])).is_equal(1)

func test_weighted_pick_covers_all_positive_weights() -> void:
	var a := Rng.new(9)
	var seen := {}
	for i in 200:
		seen[a.weighted_pick("w", [1.0, 1.0, 1.0])] = true
	assert_int(seen.size()).is_equal(3)

func test_pick_returns_member() -> void:
	var a := Rng.new(5)
	var items := ["a", "b", "c"]
	for i in 20:
		assert_bool(items.has(a.pick("p", items))).is_true()
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core`
Expected: FAIL — parse errors mentioning `Rng` not found (the suite cannot compile because the class does not exist).

- [ ] **Step 3: Implement `core/rng.gd`**

```gdscript
class_name Rng
extends RefCounted
## Seeded randomness with independent named streams.
## Every stream is derived from (seed, name), so consuming one stream never
## changes another, and a clone continues every stream from the same point.

var seed_value: int
var _streams: Dictionary = {}


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed


func stream(name: String) -> RandomNumberGenerator:
	if not _streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, name])
		_streams[name] = rng
	return _streams[name]


func randi_range(name: String, from: int, to: int) -> int:
	return stream(name).randi_range(from, to)


func randf(name: String) -> float:
	return stream(name).randf()


func shuffle(name: String, items: Array) -> void:
	var rng := stream(name)
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


func pick(name: String, items: Array) -> Variant:
	assert(items.size() > 0, "pick from empty array")
	return items[stream(name).randi_range(0, items.size() - 1)]


func weighted_pick(name: String, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	assert(total > 0.0, "weighted_pick needs a positive total weight")
	var r := stream(name).randf() * total
	var acc := 0.0
	for i in weights.size():
		var w := float(weights[i])
		if w <= 0.0:
			continue
		acc += w
		if r < acc:
			return i
	for i in range(weights.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return i
	return 0


func clone() -> Rng:
	var c := Rng.new(seed_value)
	for name in _streams:
		var src: RandomNumberGenerator = _streams[name]
		var rng := RandomNumberGenerator.new()
		rng.seed = src.seed
		rng.state = src.state
		c._streams[name] = rng
	return c
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core`
Expected: PASS — 8 test cases, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/rng.gd tests/core/rng_test.gd
git commit -m "feat(core): add Rng with seeded named streams"
```

---

### Task 3: Content definitions and loader

**Files:**
- Create: `core/content/card_def.gd`, `core/content/enemy_def.gd`, `core/content/relic_def.gd`, `core/content/class_def.gd`, `core/content/biome_def.gd`, `core/content/content.gd`
- Create: `tests/fixtures/content_ok/cards/cards.json`, `tests/fixtures/content_ok/enemies/enemies.json`, `tests/fixtures/content_ok/relics/relics.json`, `tests/fixtures/content_ok/classes/classes.json`, `tests/fixtures/content_ok/biomes/biomes.json`, `tests/fixtures/content_ok/affinity.json`, `tests/fixtures/content_ok/balance.json`, `tests/fixtures/content_ok/strings/en.csv`
- Test: `tests/core/content/content_test.gd`

**Interfaces:**
- Produces:
  - `CardDef` fields: `id: String`, `name_key: String`, `text_key: String`, `pool: String`, `type: String` ("attack"|"skill"|"power"), `cost: int` (-1 means X), `rarity: String`, `tags: Array[String]`, `keywords: Array[String]`, `target: String` ("enemy"|"all_enemies"|"self"|"none"), `effects: Array` (of Dictionary), `upgrade_effects: Array`, `upgrade_cost: int` (-2 = unchanged), `ai_value: float`; methods `effects_for(upgraded: bool) -> Array`, `cost_for(upgraded: bool) -> int`, `has_keyword(k: String) -> bool`; `static from_dict(d: Dictionary) -> CardDef`.
  - `EnemyDef` fields: `id`, `name_key`, `biome: String`, `tags: Array[String]`, `hp: int`, `moves: Dictionary` (move id → move Dictionary with keys `id`, `intent`, and per intent `damage`, `hits`, `block`, `status`, `stacks`, `enemy`), `pattern: Dictionary` (`{"kind": "sequence", "moves": [...]}` or `{"kind": "weighted", "moves": [{"move": id, "weight": float}], "no_repeat": bool}`), `kind: String` ("regular"|"elite"|"boss"); `static from_dict`.
  - `RelicDef` fields: `id`, `name_key`, `text_key`, `hooks: Dictionary` (hook name → Array of effect Dictionaries); `static from_dict`.
  - `ClassDef` fields: `id`, `name_key`, `base_hp: int`, `stats: Dictionary` (might/wit/vigor/focus ints), `starting_deck: Array[String]` (card ids, duplicates allowed), `relic: String`, `pool: String`; `static from_dict`.
  - `BiomeDef` fields: `id`, `name_key`, `first_floor: int`, `last_floor: int`, `encounters: Array` (of `{"floors": [a, b], "groups": [[enemy ids]]}`), `elites: Array` (of `[enemy ids]`), `boss: Array[String]`, `node_patterns: Array` (of `Array[String]`), `card_pool: String`; `static from_dict`.
  - `Content` fields: `cards`, `enemies`, `relics`, `classes`, `biomes` (Dictionary id → def), `affinity: Dictionary` (tag → {enemy tag → float}), `balance: Dictionary`, `strings: Dictionary`, `load_errors: Array[String]`; `static load_from(root: String) -> Content`; `text(key: String) -> String` (returns the key itself when missing).
- Consumes: nothing from earlier tasks.

- [ ] **Step 1: Create the fixture content set**

`tests/fixtures/content_ok/cards/cards.json`:

```json
[
  {
    "id": "fx_strike",
    "name": "card.fx_strike.name",
    "text": "card.fx_strike.text",
    "pool": "fx_class",
    "type": "attack",
    "cost": 1,
    "rarity": "basic",
    "tags": ["bone"],
    "keywords": [],
    "target": "enemy",
    "effects": [{"op": "damage", "amount": 6, "scale": "might"}],
    "upgrade": {"effects": [{"op": "damage", "amount": 9, "scale": "might"}]},
    "ai_value": 6
  },
  {
    "id": "fx_brace",
    "name": "card.fx_brace.name",
    "text": "card.fx_brace.text",
    "pool": "fx_class",
    "type": "skill",
    "cost": 1,
    "rarity": "basic",
    "tags": ["shield"],
    "keywords": [],
    "target": "self",
    "effects": [{"op": "block", "amount": 5, "scale": "wit"}],
    "upgrade": {"effects": [{"op": "block", "amount": 8, "scale": "wit"}]},
    "ai_value": 5
  },
  {
    "id": "fx_surge",
    "name": "card.fx_surge.name",
    "text": "card.fx_surge.text",
    "pool": "fx_class",
    "type": "skill",
    "cost": "x",
    "rarity": "rare",
    "tags": ["draw"],
    "keywords": ["exhaust"],
    "target": "none",
    "effects": [{"op": "draw", "amount": "x"}],
    "upgrade": {"cost": 0},
    "ai_value": 4
  }
]
```

`tests/fixtures/content_ok/enemies/enemies.json`:

```json
[
  {
    "id": "fx_rat",
    "name": "enemy.fx_rat.name",
    "biome": "fx_biome",
    "tags": ["undead"],
    "hp": 14,
    "kind": "regular",
    "moves": [
      {"id": "bite", "intent": "attack", "damage": 5, "hits": 1},
      {"id": "hide", "intent": "block", "block": 4}
    ],
    "pattern": {"kind": "sequence", "moves": ["bite", "bite", "hide"]}
  },
  {
    "id": "fx_boss",
    "name": "enemy.fx_boss.name",
    "biome": "fx_biome",
    "tags": ["undead"],
    "hp": 60,
    "kind": "boss",
    "moves": [
      {"id": "crush", "intent": "attack", "damage": 12, "hits": 1},
      {"id": "call", "intent": "summon", "enemy": "fx_rat"}
    ],
    "pattern": {"kind": "weighted", "moves": [{"move": "crush", "weight": 2}, {"move": "call", "weight": 1}], "no_repeat": true}
  }
]
```

`tests/fixtures/content_ok/relics/relics.json`:

```json
[
  {
    "id": "fx_lantern",
    "name": "relic.fx_lantern.name",
    "text": "relic.fx_lantern.text",
    "hooks": {"on_fight_start": [{"op": "block", "amount": 3}]}
  }
]
```

`tests/fixtures/content_ok/classes/classes.json`:

```json
[
  {
    "id": "fx_class",
    "name": "class.fx_class.name",
    "base_hp": 70,
    "stats": {"might": 0, "wit": 0, "vigor": 0, "focus": 0},
    "starting_deck": ["fx_strike", "fx_strike", "fx_brace"],
    "relic": "fx_lantern",
    "pool": "fx_class"
  }
]
```

`tests/fixtures/content_ok/biomes/biomes.json`:

```json
[
  {
    "id": "fx_biome",
    "name": "biome.fx_biome.name",
    "floors": [1, 10],
    "card_pool": "fx_biome",
    "encounters": [
      {"floors": [1, 9], "groups": [["fx_rat"], ["fx_rat", "fx_rat"]]}
    ],
    "elites": [["fx_boss"]],
    "boss": ["fx_boss"],
    "node_patterns": [["fight", "fight", "rest"], ["fight", "event", "fight"]]
  }
]
```

`tests/fixtures/content_ok/affinity.json`:

```json
{"poison": {"construct": 0.0, "flesh": 1.5}}
```

`tests/fixtures/content_ok/balance.json`:

```json
{
  "enemy_hp_growth": 1.06,
  "enemy_damage_growth": 1.04,
  "base_energy": 3,
  "base_draw": 5,
  "hand_limit": 10,
  "turn_cap": 30,
  "focus_draw_thresholds": [3, 9],
  "focus_energy_thresholds": [6, 12],
  "weak_multiplier": 0.75,
  "vulnerable_multiplier": 1.5
}
```

`tests/fixtures/content_ok/strings/en.csv`:

```csv
key,text
card.fx_strike.name,Strike
card.fx_strike.text,Deal 6 damage.
card.fx_brace.name,Brace
card.fx_brace.text,Gain 5 Block.
card.fx_surge.name,Surge
card.fx_surge.text,Draw X cards. Exhaust.
enemy.fx_rat.name,Fixture Rat
enemy.fx_boss.name,Fixture Boss
relic.fx_lantern.name,Fixture Lantern
relic.fx_lantern.text,Start each fight with 3 Block.
class.fx_class.name,Fixture Class
biome.fx_biome.name,Fixture Biome
```

- [ ] **Step 2: Write the failing tests**

`tests/core/content/content_test.gd`:

```gdscript
extends GdUnitTestSuite

const ROOT := "res://tests/fixtures/content_ok"


func test_loads_all_types_without_errors() -> void:
	var c := Content.load_from(ROOT)
	assert_array(c.load_errors).is_empty()
	assert_int(c.cards.size()).is_equal(3)
	assert_int(c.enemies.size()).is_equal(2)
	assert_int(c.relics.size()).is_equal(1)
	assert_int(c.classes.size()).is_equal(1)
	assert_int(c.biomes.size()).is_equal(1)


func test_card_def_fields() -> void:
	var c := Content.load_from(ROOT)
	var strike: CardDef = c.cards["fx_strike"]
	assert_str(strike.type).is_equal("attack")
	assert_int(strike.cost).is_equal(1)
	assert_str(strike.target).is_equal("enemy")
	assert_array(strike.tags).contains(["bone"])
	assert_int(strike.effects.size()).is_equal(1)
	assert_str(strike.effects[0]["op"]).is_equal("damage")
	assert_int(strike.effects_for(true)[0]["amount"]).is_equal(9)
	assert_int(strike.cost_for(true)).is_equal(1)
	assert_float(strike.ai_value).is_equal(6.0)


func test_x_cost_and_upgrade_cost() -> void:
	var c := Content.load_from(ROOT)
	var surge: CardDef = c.cards["fx_surge"]
	assert_int(surge.cost).is_equal(-1)
	assert_int(surge.cost_for(false)).is_equal(-1)
	assert_int(surge.cost_for(true)).is_equal(0)
	assert_bool(surge.has_keyword("exhaust")).is_true()
	assert_array(surge.effects_for(true)).is_equal(surge.effects)


func test_enemy_def_fields() -> void:
	var c := Content.load_from(ROOT)
	var rat: EnemyDef = c.enemies["fx_rat"]
	assert_int(rat.hp).is_equal(14)
	assert_str(rat.kind).is_equal("regular")
	assert_bool(rat.moves.has("bite")).is_true()
	assert_int(rat.moves["bite"]["damage"]).is_equal(5)
	assert_str(rat.pattern["kind"]).is_equal("sequence")
	var boss: EnemyDef = c.enemies["fx_boss"]
	assert_str(boss.kind).is_equal("boss")
	assert_bool(boss.pattern["no_repeat"]).is_true()


func test_relic_class_biome_fields() -> void:
	var c := Content.load_from(ROOT)
	var relic: RelicDef = c.relics["fx_lantern"]
	assert_bool(relic.hooks.has("on_fight_start")).is_true()
	var klass: ClassDef = c.classes["fx_class"]
	assert_int(klass.base_hp).is_equal(70)
	assert_array(klass.starting_deck).has_size(3)
	assert_str(klass.relic).is_equal("fx_lantern")
	var biome: BiomeDef = c.biomes["fx_biome"]
	assert_int(biome.first_floor).is_equal(1)
	assert_int(biome.last_floor).is_equal(10)
	assert_int(biome.encounters.size()).is_equal(1)
	assert_array(biome.boss).is_equal(["fx_boss"])
	assert_int(biome.node_patterns.size()).is_equal(2)


func test_affinity_balance_and_strings() -> void:
	var c := Content.load_from(ROOT)
	assert_float(c.affinity["poison"]["flesh"]).is_equal(1.5)
	assert_float(c.balance["enemy_hp_growth"]).is_equal(1.06)
	assert_int(c.balance["turn_cap"]).is_equal(30)
	assert_str(c.text("card.fx_strike.name")).is_equal("Strike")
	assert_str(c.text("card.fx_surge.text")).is_equal("Draw X cards. Exhaust.")
	assert_str(c.text("missing.key")).is_equal("missing.key")


func test_missing_root_reports_errors() -> void:
	var c := Content.load_from("res://tests/fixtures/does_not_exist")
	assert_array(c.load_errors).is_not_empty()
```

- [ ] **Step 3: Run to verify they fail**

Run: `tools\test.cmd tests/core/content`
Expected: FAIL — `Content` / `CardDef` not found.

- [ ] **Step 4: Implement the definition classes**

`core/content/card_def.gd`:

```gdscript
class_name CardDef
extends RefCounted
## Immutable description of a card, loaded from JSON.

const COST_X := -1
const COST_UNCHANGED := -2

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var pool: String = "neutral"
var type: String = "attack"
var cost: int = 1
var rarity: String = "common"
var tags: Array[String] = []
var keywords: Array[String] = []
var target: String = "enemy"
var effects: Array = []
var upgrade_effects: Array = []
var upgrade_cost: int = COST_UNCHANGED
var ai_value: float = 0.0


static func from_dict(d: Dictionary) -> CardDef:
	var c := CardDef.new()
	c.id = String(d.get("id", ""))
	c.name_key = String(d.get("name", ""))
	c.text_key = String(d.get("text", ""))
	c.pool = String(d.get("pool", "neutral"))
	c.type = String(d.get("type", "attack"))
	c.cost = _parse_cost(d.get("cost", 1), 1)
	c.rarity = String(d.get("rarity", "common"))
	for t in d.get("tags", []):
		c.tags.append(String(t))
	for k in d.get("keywords", []):
		c.keywords.append(String(k))
	c.target = String(d.get("target", "enemy"))
	var fx: Array = d.get("effects", [])
	c.effects = fx.duplicate(true)
	var up: Dictionary = d.get("upgrade", {})
	var up_fx: Array = up.get("effects", fx)
	c.upgrade_effects = up_fx.duplicate(true)
	c.upgrade_cost = _parse_cost(up.get("cost", COST_UNCHANGED), COST_UNCHANGED)
	c.ai_value = float(d.get("ai_value", 0.0))
	return c


static func _parse_cost(value: Variant, fallback: int) -> int:
	if value is String:
		return COST_X if String(value).to_lower() == "x" else fallback
	if value is float or value is int:
		return int(value)
	return fallback


func effects_for(upgraded: bool) -> Array:
	return upgrade_effects if upgraded else effects


func cost_for(upgraded: bool) -> int:
	if upgraded and upgrade_cost != COST_UNCHANGED:
		return upgrade_cost
	return cost


func has_keyword(k: String) -> bool:
	return keywords.has(k)
```

`core/content/enemy_def.gd`:

```gdscript
class_name EnemyDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var biome: String = ""
var tags: Array[String] = []
var hp: int = 1
var moves: Dictionary = {}
var pattern: Dictionary = {}
var kind: String = "regular"


static func from_dict(d: Dictionary) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = String(d.get("id", ""))
	e.name_key = String(d.get("name", ""))
	e.biome = String(d.get("biome", ""))
	for t in d.get("tags", []):
		e.tags.append(String(t))
	e.hp = int(d.get("hp", 1))
	for m in d.get("moves", []):
		var move: Dictionary = m
		e.moves[String(move.get("id", ""))] = move.duplicate(true)
	var p: Dictionary = d.get("pattern", {})
	e.pattern = p.duplicate(true)
	e.kind = String(d.get("kind", "regular"))
	return e
```

`core/content/relic_def.gd`:

```gdscript
class_name RelicDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var hooks: Dictionary = {}


static func from_dict(d: Dictionary) -> RelicDef:
	var r := RelicDef.new()
	r.id = String(d.get("id", ""))
	r.name_key = String(d.get("name", ""))
	r.text_key = String(d.get("text", ""))
	var h: Dictionary = d.get("hooks", {})
	r.hooks = h.duplicate(true)
	return r
```

`core/content/class_def.gd`:

```gdscript
class_name ClassDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var base_hp: int = 70
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var starting_deck: Array[String] = []
var relic: String = ""
var pool: String = ""


static func from_dict(d: Dictionary) -> ClassDef:
	var c := ClassDef.new()
	c.id = String(d.get("id", ""))
	c.name_key = String(d.get("name", ""))
	c.base_hp = int(d.get("base_hp", 70))
	var s: Dictionary = d.get("stats", {})
	for key in ["might", "wit", "vigor", "focus"]:
		c.stats[key] = int(s.get(key, 0))
	for card_id in d.get("starting_deck", []):
		c.starting_deck.append(String(card_id))
	c.relic = String(d.get("relic", ""))
	c.pool = String(d.get("pool", c.id))
	return c
```

`core/content/biome_def.gd`:

```gdscript
class_name BiomeDef
extends RefCounted

var id: String = ""
var name_key: String = ""
var first_floor: int = 1
var last_floor: int = 10
var card_pool: String = ""
var encounters: Array = []
var elites: Array = []
var boss: Array[String] = []
var node_patterns: Array = []


static func from_dict(d: Dictionary) -> BiomeDef:
	var b := BiomeDef.new()
	b.id = String(d.get("id", ""))
	b.name_key = String(d.get("name", ""))
	var floors: Array = d.get("floors", [1, 10])
	b.first_floor = int(floors[0])
	b.last_floor = int(floors[1])
	b.card_pool = String(d.get("card_pool", b.id))
	var enc: Array = d.get("encounters", [])
	b.encounters = enc.duplicate(true)
	var el: Array = d.get("elites", [])
	b.elites = el.duplicate(true)
	for enemy_id in d.get("boss", []):
		b.boss.append(String(enemy_id))
	var patterns: Array = d.get("node_patterns", [])
	b.node_patterns = patterns.duplicate(true)
	return b
```

- [ ] **Step 5: Implement `core/content/content.gd`**

```gdscript
class_name Content
extends RefCounted
## Loads every JSON file under a data root into typed definitions.
## Never throws: problems are collected in load_errors so the validator
## (and the test suite) can report them all at once.

var cards: Dictionary = {}
var enemies: Dictionary = {}
var relics: Dictionary = {}
var classes: Dictionary = {}
var biomes: Dictionary = {}
var affinity: Dictionary = {}
var balance: Dictionary = {}
var strings: Dictionary = {}
var load_errors: Array[String] = []


static func load_from(root: String) -> Content:
	var c := Content.new()
	if not DirAccess.dir_exists_absolute(root):
		c.load_errors.append("missing content root: " + root)
		return c
	c._load_dir(root.path_join("cards"), func(d: Dictionary) -> void: c.cards[d["id"]] = CardDef.from_dict(d))
	c._load_dir(root.path_join("enemies"), func(d: Dictionary) -> void: c.enemies[d["id"]] = EnemyDef.from_dict(d))
	c._load_dir(root.path_join("relics"), func(d: Dictionary) -> void: c.relics[d["id"]] = RelicDef.from_dict(d))
	c._load_dir(root.path_join("classes"), func(d: Dictionary) -> void: c.classes[d["id"]] = ClassDef.from_dict(d))
	c._load_dir(root.path_join("biomes"), func(d: Dictionary) -> void: c.biomes[d["id"]] = BiomeDef.from_dict(d))
	c.affinity = c._load_object(root.path_join("affinity.json"))
	c.balance = c._load_object(root.path_join("balance.json"))
	c._load_strings(root.path_join("strings").path_join("en.csv"))
	return c


func text(key: String) -> String:
	return String(strings.get(key, key))


func _load_dir(dir: String, add: Callable) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		load_errors.append("missing directory: " + dir)
		return
	var files := Array(da.get_files())
	files.sort()
	for f in files:
		var file_name := String(f)
		if not file_name.ends_with(".json"):
			continue
		var path := dir.path_join(file_name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed == null:
			load_errors.append("invalid JSON: " + path)
			continue
		var items: Array = parsed if parsed is Array else [parsed]
		for item in items:
			if not (item is Dictionary) or not item.has("id"):
				load_errors.append("entry without id in " + path)
				continue
			add.call(item)


func _load_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_errors.append("missing file: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		load_errors.append("invalid JSON object: " + path)
		return {}
	return parsed


func _load_strings(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_errors.append("missing strings file: " + path)
		return
	var first := true
	while not file.eof_reached():
		var row := file.get_csv_line()
		if first:
			first = false
			continue
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		strings[row[0]] = row[1]
```

- [ ] **Step 6: Run to verify they pass**

Run: `tools\test.cmd tests/core/content`
Expected: PASS — 7 test cases, 0 failures.

Note for the export milestone (M3): JSON and CSV files are not resources, so the export preset must include `*.json, *.csv` in "Filters to export non-resource files". Nothing to do now.

- [ ] **Step 7: Commit**

```bash
git add core/content tests/core/content/content_test.gd tests/fixtures
git commit -m "feat(content): typed definitions and JSON loader"
```

---

### Task 4: Content validator

**Files:**
- Create: `core/content/validator.gd`
- Test: `tests/core/content/validator_test.gd`

**Interfaces:**
- Consumes: `Content` and the def classes from Task 3.
- Produces: `ContentValidator.validate(c: Content) -> Array[String]` — empty means valid; each entry is a human-readable error naming the offending item. Constants used by the engine too: `ContentValidator.OPS`, `STATUSES`, `CARD_TYPES`, `TARGETS`, `RARITIES`, `KEYWORDS`, `INTENTS`, `HOOKS`, `NODE_KINDS`, `ENEMY_KINDS`, `PATTERN_KINDS`.

- [ ] **Step 1: Write the failing tests**

`tests/core/content/validator_test.gd`:

```gdscript
extends GdUnitTestSuite

const ROOT := "res://tests/fixtures/content_ok"


func _ok() -> Content:
	return Content.load_from(ROOT)


func test_fixture_content_is_valid() -> void:
	assert_array(ContentValidator.validate(_ok())).is_empty()


func test_load_errors_are_reported() -> void:
	var c := _ok()
	c.load_errors.append("boom")
	assert_array(ContentValidator.validate(c)).contains(["boom"])


func test_unknown_effect_op_is_an_error() -> void:
	var c := _ok()
	var card: CardDef = c.cards["fx_strike"]
	card.effects = [{"op": "explode", "amount": 1}]
	var errors := ContentValidator.validate(c)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("fx_strike")
	assert_str(errors[0]).contains("explode")


func test_unknown_status_and_missing_add_card_are_errors() -> void:
	var c := _ok()
	var card: CardDef = c.cards["fx_brace"]
	card.effects = [{"op": "apply_status", "status": "confusion", "stacks": 1}]
	card.upgrade_effects = [{"op": "add_card", "card": "nope", "where": "hand"}]
	var errors := ContentValidator.validate(c)
	assert_int(errors.size()).is_equal(2)


func test_bad_card_type_target_rarity_keyword() -> void:
	var c := _ok()
	var card: CardDef = c.cards["fx_strike"]
	card.type = "spell"
	card.target = "everyone"
	card.rarity = "mythic"
	card.keywords = ["innate"]
	assert_int(ContentValidator.validate(c).size()).is_equal(4)


func test_missing_string_keys_are_errors() -> void:
	var c := _ok()
	c.strings.erase("card.fx_strike.name")
	c.strings.erase("enemy.fx_rat.name")
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_enemy_pattern_must_reference_moves() -> void:
	var c := _ok()
	var rat: EnemyDef = c.enemies["fx_rat"]
	rat.pattern = {"kind": "sequence", "moves": ["bite", "fly"]}
	var errors := ContentValidator.validate(c)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("fly")


func test_enemy_move_shapes() -> void:
	var c := _ok()
	var rat: EnemyDef = c.enemies["fx_rat"]
	rat.moves["bite"] = {"id": "bite", "intent": "attack"}
	rat.moves["hide"] = {"id": "hide", "intent": "dance"}
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_summon_must_reference_enemy_and_kind_must_be_known() -> void:
	var c := _ok()
	var boss: EnemyDef = c.enemies["fx_boss"]
	boss.moves["call"] = {"id": "call", "intent": "summon", "enemy": "dragon"}
	boss.kind = "legendary"
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_weighted_pattern_needs_positive_weights() -> void:
	var c := _ok()
	var boss: EnemyDef = c.enemies["fx_boss"]
	boss.pattern = {"kind": "weighted", "moves": [{"move": "crush", "weight": 0}]}
	assert_int(ContentValidator.validate(c).size()).is_equal(1)


func test_relic_hooks_and_effects() -> void:
	var c := _ok()
	var relic: RelicDef = c.relics["fx_lantern"]
	relic.hooks = {"on_sneeze": [{"op": "block", "amount": 1}], "on_fight_end": [{"op": "teleport"}]}
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_class_references() -> void:
	var c := _ok()
	var klass: ClassDef = c.classes["fx_class"]
	klass.starting_deck = ["fx_strike", "missing_card"]
	klass.relic = "missing_relic"
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_biome_references_and_patterns() -> void:
	var c := _ok()
	var biome: BiomeDef = c.biomes["fx_biome"]
	biome.encounters = [{"floors": [1, 9], "groups": [["fx_rat", "ghoul"]]}]
	biome.boss = ["nobody"] as Array[String]
	biome.node_patterns = [["fight", "fight", "casino"]]
	assert_int(ContentValidator.validate(c).size()).is_equal(3)


func test_empty_collections_are_errors() -> void:
	var c := _ok()
	var klass: ClassDef = c.classes["fx_class"]
	klass.starting_deck = [] as Array[String]
	var biome: BiomeDef = c.biomes["fx_biome"]
	biome.node_patterns = []
	biome.elites = []
	assert_int(ContentValidator.validate(c).size()).is_equal(3)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/content`
Expected: FAIL — `ContentValidator` not found.

- [ ] **Step 3: Implement `core/content/validator.gd`**

```gdscript
class_name ContentValidator
extends RefCounted
## Checks loaded content for broken references and malformed data.
## Returns every problem found; an empty array means the content is valid.

const OPS: Array[String] = ["damage", "block", "apply_status", "draw", "energy", "heal", "exhaust_self", "add_card", "coin"]
const STATUSES: Array[String] = ["poison", "bleed", "burn", "weak", "vulnerable", "might_buff", "wit_buff", "thorns", "regen", "vigil", "knell"]
const CARD_TYPES: Array[String] = ["attack", "skill", "power"]
const TARGETS: Array[String] = ["enemy", "all_enemies", "self", "none"]
const EFFECT_TARGETS: Array[String] = ["target", "self", "all_enemies"]
const RARITIES: Array[String] = ["basic", "common", "uncommon", "rare"]
const KEYWORDS: Array[String] = ["exhaust", "retain"]
const INTENTS: Array[String] = ["attack", "block", "buff", "debuff", "summon"]
const HOOKS: Array[String] = ["on_fight_start", "on_turn_start", "on_card_played", "on_damage_taken", "on_fight_end", "on_floor_enter"]
const NODE_KINDS: Array[String] = ["fight", "elite", "event", "rest", "shop"]
const ENEMY_KINDS: Array[String] = ["regular", "elite", "boss"]
const PATTERN_KINDS: Array[String] = ["sequence", "weighted"]
const ADD_CARD_WHERE: Array[String] = ["hand", "discard", "draw"]


static func validate(c: Content) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(c.load_errors)
	for id in c.cards:
		_card(c, c.cards[id], errors)
	for id in c.enemies:
		_enemy(c, c.enemies[id], errors)
	for id in c.relics:
		_relic(c, c.relics[id], errors)
	for id in c.classes:
		_class(c, c.classes[id], errors)
	for id in c.biomes:
		_biome(c, c.biomes[id], errors)
	return errors


static func _key(c: Content, where: String, key: String, errors: Array[String]) -> void:
	if key == "" or not c.strings.has(key):
		errors.append("%s: missing string key '%s'" % [where, key])


static func _amount_ok(value: Variant) -> bool:
	if value is float or value is int:
		return true
	return value is String and String(value).to_lower() == "x"


static func _effects(c: Content, where: String, effects: Array, errors: Array[String]) -> void:
	for raw in effects:
		if not (raw is Dictionary) or not raw.has("op"):
			errors.append("%s: effect without op" % where)
			continue
		var e: Dictionary = raw
		var op := String(e["op"])
		if not OPS.has(op):
			errors.append("%s: unknown op '%s'" % [where, op])
			continue
		if e.has("target") and not EFFECT_TARGETS.has(String(e["target"])):
			errors.append("%s: bad effect target '%s'" % [where, String(e["target"])])
		if e.has("amount") and not _amount_ok(e["amount"]):
			errors.append("%s: amount must be a number or \"x\"" % where)
		match op:
			"apply_status":
				if not STATUSES.has(String(e.get("status", ""))):
					errors.append("%s: unknown status '%s'" % [where, String(e.get("status", ""))])
				if not _amount_ok(e.get("stacks", 1)):
					errors.append("%s: stacks must be a number or \"x\"" % where)
			"add_card":
				if not c.cards.has(String(e.get("card", ""))):
					errors.append("%s: add_card references missing card '%s'" % [where, String(e.get("card", ""))])
				if not ADD_CARD_WHERE.has(String(e.get("where", "hand"))):
					errors.append("%s: add_card bad where '%s'" % [where, String(e.get("where", ""))])
			"damage", "block", "draw", "energy", "heal", "coin":
				if not e.has("amount"):
					errors.append("%s: op '%s' needs an amount" % [where, op])


static func _card(c: Content, card: CardDef, errors: Array[String]) -> void:
	var where := "card " + card.id
	if not CARD_TYPES.has(card.type):
		errors.append("%s: bad type '%s'" % [where, card.type])
	if not TARGETS.has(card.target):
		errors.append("%s: bad target '%s'" % [where, card.target])
	if not RARITIES.has(card.rarity):
		errors.append("%s: bad rarity '%s'" % [where, card.rarity])
	for k in card.keywords:
		if not KEYWORDS.has(k):
			errors.append("%s: bad keyword '%s'" % [where, k])
	if card.cost < CardDef.COST_X:
		errors.append("%s: bad cost" % where)
	_effects(c, where, card.effects, errors)
	_effects(c, where + " (upgraded)", card.upgrade_effects, errors)
	_key(c, where, card.name_key, errors)
	_key(c, where, card.text_key, errors)


static func _enemy(c: Content, enemy: EnemyDef, errors: Array[String]) -> void:
	var where := "enemy " + enemy.id
	if enemy.hp <= 0:
		errors.append("%s: hp must be positive" % where)
	if not ENEMY_KINDS.has(enemy.kind):
		errors.append("%s: bad kind '%s'" % [where, enemy.kind])
	_key(c, where, enemy.name_key, errors)
	for move_id in enemy.moves:
		var m: Dictionary = enemy.moves[move_id]
		var intent := String(m.get("intent", ""))
		var mwhere := "%s move %s" % [where, String(move_id)]
		if not INTENTS.has(intent):
			errors.append("%s: bad intent '%s'" % [mwhere, intent])
			continue
		match intent:
			"attack":
				if not m.has("damage"):
					errors.append("%s: attack needs damage" % mwhere)
				if m.has("status") and not STATUSES.has(String(m["status"])):
					errors.append("%s: unknown status '%s'" % [mwhere, String(m["status"])])
			"block":
				if not m.has("block"):
					errors.append("%s: block needs block" % mwhere)
			"buff", "debuff":
				if not STATUSES.has(String(m.get("status", ""))):
					errors.append("%s: unknown status '%s'" % [mwhere, String(m.get("status", ""))])
			"summon":
				if not c.enemies.has(String(m.get("enemy", ""))):
					errors.append("%s: summon references missing enemy '%s'" % [mwhere, String(m.get("enemy", ""))])
	var kind := String(enemy.pattern.get("kind", ""))
	if not PATTERN_KINDS.has(kind):
		errors.append("%s: bad pattern kind '%s'" % [where, kind])
		return
	var moves: Array = enemy.pattern.get("moves", [])
	if moves.is_empty():
		errors.append("%s: pattern has no moves" % where)
	for entry in moves:
		var move_ref := String(entry["move"]) if entry is Dictionary else String(entry)
		if not enemy.moves.has(move_ref):
			errors.append("%s: pattern references missing move '%s'" % [where, move_ref])
		if kind == "weighted":
			var weight := float(entry.get("weight", 0.0)) if entry is Dictionary else 0.0
			if weight <= 0.0:
				errors.append("%s: weighted move '%s' needs a positive weight" % [where, move_ref])


static func _relic(c: Content, relic: RelicDef, errors: Array[String]) -> void:
	var where := "relic " + relic.id
	for hook in relic.hooks:
		if not HOOKS.has(String(hook)):
			errors.append("%s: unknown hook '%s'" % [where, String(hook)])
			continue
		_effects(c, "%s %s" % [where, String(hook)], relic.hooks[hook], errors)
	_key(c, where, relic.name_key, errors)
	_key(c, where, relic.text_key, errors)


static func _class(c: Content, klass: ClassDef, errors: Array[String]) -> void:
	var where := "class " + klass.id
	if klass.base_hp <= 0:
		errors.append("%s: base_hp must be positive" % where)
	if klass.starting_deck.is_empty():
		errors.append("%s: starting_deck is empty" % where)
	for card_id in klass.starting_deck:
		if not c.cards.has(card_id):
			errors.append("%s: starting_deck references missing card '%s'" % [where, card_id])
	if not c.relics.has(klass.relic):
		errors.append("%s: relic '%s' missing" % [where, klass.relic])
	_key(c, where, klass.name_key, errors)


static func _biome(c: Content, biome: BiomeDef, errors: Array[String]) -> void:
	var where := "biome " + biome.id
	if biome.first_floor > biome.last_floor:
		errors.append("%s: floors out of order" % where)
	for enc in biome.encounters:
		var groups: Array = enc.get("groups", [])
		if groups.is_empty():
			errors.append("%s: encounter without groups" % where)
		for group in groups:
			if group.is_empty():
				errors.append("%s: empty encounter group" % where)
			for enemy_id in group:
				if not c.enemies.has(String(enemy_id)):
					errors.append("%s: encounter references missing enemy '%s'" % [where, String(enemy_id)])
	if biome.elites.is_empty():
		errors.append("%s: no elites" % where)
	for group in biome.elites:
		for enemy_id in group:
			if not c.enemies.has(String(enemy_id)):
				errors.append("%s: elite references missing enemy '%s'" % [where, String(enemy_id)])
	if biome.boss.is_empty():
		errors.append("%s: no boss" % where)
	for enemy_id in biome.boss:
		if not c.enemies.has(enemy_id):
			errors.append("%s: boss references missing enemy '%s'" % [where, enemy_id])
	if biome.node_patterns.is_empty():
		errors.append("%s: no node patterns" % where)
	for pattern in biome.node_patterns:
		for node in pattern:
			if not NODE_KINDS.has(String(node)):
				errors.append("%s: bad node kind '%s'" % [where, String(node)])
	_key(c, where, biome.name_key, errors)
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/content`
Expected: PASS — 21 test cases across both suites, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/content/validator.gd tests/core/content/validator_test.gd
git commit -m "feat(content): validator for cards, enemies, relics, classes and biomes"
```

---

### Task 5: Slice content — Sexton, Catacombs, relics, balance, strings

**Files:**
- Create: `data/cards/basic.json`, `data/cards/sexton.json`, `data/cards/catacombs.json`, `data/enemies/catacombs.json`, `data/relics/slice.json`, `data/classes/sexton.json`, `data/biomes/catacombs.json`, `data/affinity.json`, `data/balance.json`, `data/strings/en.csv`
- Delete: `data/.gdkeep`
- Test: `tests/core/content/slice_content_test.gd`

**Interfaces:**
- Produces: the real content at `res://data` — 30 cards (3 basic, 17 Sexton, 10 Catacombs), 10 enemies (8 regular, 1 elite, 1 boss), 6 relics, the `sexton` class, the `catacombs` biome, affinity, balance and English strings. Card and enemy ids below are referenced by tests in later tasks exactly as written.
- Consumes: `Content`, `ContentValidator`.

Effect conventions used by the content (the engine in Tasks 7–9 implements exactly these):
- `damage {amount, scale?: "might", hits?: int, target?}` — from an Attack card it is an attack (Might applies if `scale`, Weak/Vulnerable apply, Bleed/Thorns trigger); from a Skill it is plain damage.
- `block {amount, scale?: "wit", target?: "self"}`; `apply_status {status, stacks, scale?: "wit", target?}` where the default target is the card's target (`self` for buffs); `draw {amount}`; `energy {amount}`; `heal {amount}`; `exhaust_self {}`; `add_card {card, where}`; `coin {amount}`.
- Per-effect `target` overrides the card's target: `"self"`, `"target"` (the chosen enemy) or `"all_enemies"`.

- [ ] **Step 1: Write the failing test**

`tests/core/content/slice_content_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_slice_content_is_valid() -> void:
	var c := Content.load_from("res://data")
	var errors := ContentValidator.validate(c)
	assert_array(errors).is_empty()


func test_slice_content_volume() -> void:
	var c := Content.load_from("res://data")
	assert_int(c.cards.size()).is_equal(30)
	assert_int(c.enemies.size()).is_equal(10)
	assert_int(c.relics.size()).is_equal(6)
	assert_int(c.classes.size()).is_equal(1)
	assert_int(c.biomes.size()).is_equal(1)
	var sexton: ClassDef = c.classes["sexton"]
	assert_array(sexton.starting_deck).has_size(10)
	var elites := 0
	var bosses := 0
	for id in c.enemies:
		var e: EnemyDef = c.enemies[id]
		if e.kind == "elite":
			elites += 1
		elif e.kind == "boss":
			bosses += 1
	assert_int(elites).is_equal(1)
	assert_int(bosses).is_equal(1)


func test_every_card_belongs_to_a_known_pool() -> void:
	var c := Content.load_from("res://data")
	for id in c.cards:
		var card: CardDef = c.cards[id]
		assert_bool(card.pool == "sexton" or card.pool == "catacombs").override_failure_message("card %s has pool %s" % [id, card.pool]).is_true()
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools\test.cmd tests/core/content`
Expected: FAIL — `test_slice_content_is_valid` reports "missing content root" or missing directories.

- [ ] **Step 3: Write the card files**

`data/cards/basic.json`:

```json
[
  {"id": "strike", "name": "card.strike.name", "text": "card.strike.text", "pool": "sexton", "type": "attack", "cost": 1, "rarity": "basic", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 6, "scale": "might"}],
   "upgrade": {"effects": [{"op": "damage", "amount": 9, "scale": "might"}]}, "ai_value": 6},
  {"id": "brace", "name": "card.brace.name", "text": "card.brace.text", "pool": "sexton", "type": "skill", "cost": 1, "rarity": "basic", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "block", "amount": 5, "scale": "wit"}],
   "upgrade": {"effects": [{"op": "block", "amount": 8, "scale": "wit"}]}, "ai_value": 5},
  {"id": "last_rites", "name": "card.last_rites.name", "text": "card.last_rites.text", "pool": "sexton", "type": "attack", "cost": 1, "rarity": "basic", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 4, "scale": "might"}, {"op": "apply_status", "status": "weak", "stacks": 2}],
   "upgrade": {"effects": [{"op": "damage", "amount": 6, "scale": "might"}, {"op": "apply_status", "status": "weak", "stacks": 2}]}, "ai_value": 6}
]
```

`data/cards/sexton.json`:

```json
[
  {"id": "shovel_swing", "name": "card.shovel_swing.name", "text": "card.shovel_swing.text", "pool": "sexton", "type": "attack", "cost": 1, "rarity": "common", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 8, "scale": "might"}],
   "upgrade": {"effects": [{"op": "damage", "amount": 11, "scale": "might"}]}, "ai_value": 8},
  {"id": "bone_wall", "name": "card.bone_wall.name", "text": "card.bone_wall.text", "pool": "sexton", "type": "skill", "cost": 2, "rarity": "common", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "block", "amount": 11, "scale": "wit"}],
   "upgrade": {"effects": [{"op": "block", "amount": 15, "scale": "wit"}]}, "ai_value": 9},
  {"id": "grave_dust", "name": "card.grave_dust.name", "text": "card.grave_dust.text", "pool": "sexton", "type": "skill", "cost": 0, "rarity": "common", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "apply_status", "status": "vulnerable", "stacks": 1}, {"op": "draw", "amount": 1}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "vulnerable", "stacks": 2}, {"op": "draw", "amount": 1}]}, "ai_value": 4},
  {"id": "reaping", "name": "card.reaping.name", "text": "card.reaping.text", "pool": "sexton", "type": "attack", "cost": 2, "rarity": "common", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 4, "scale": "might", "hits": 3}],
   "upgrade": {"effects": [{"op": "damage", "amount": 5, "scale": "might", "hits": 3}]}, "ai_value": 11},
  {"id": "vigil", "name": "card.vigil.name", "text": "card.vigil.text", "pool": "sexton", "type": "power", "cost": 1, "rarity": "uncommon", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "apply_status", "status": "vigil", "stacks": 3, "target": "self"}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "vigil", "stacks": 4, "target": "self"}]}, "ai_value": 7},
  {"id": "censer_smoke", "name": "card.censer_smoke.name", "text": "card.censer_smoke.text", "pool": "sexton", "type": "skill", "cost": 1, "rarity": "common", "tags": ["shield"], "keywords": [], "target": "all_enemies",
   "effects": [{"op": "block", "amount": 4, "scale": "wit", "target": "self"}, {"op": "apply_status", "status": "weak", "stacks": 1, "target": "all_enemies"}],
   "upgrade": {"effects": [{"op": "block", "amount": 6, "scale": "wit", "target": "self"}, {"op": "apply_status", "status": "weak", "stacks": 1, "target": "all_enemies"}]}, "ai_value": 6},
  {"id": "exhume", "name": "card.exhume.name", "text": "card.exhume.text", "pool": "sexton", "type": "skill", "cost": 1, "rarity": "uncommon", "tags": ["draw"], "keywords": ["exhaust"], "target": "none",
   "effects": [{"op": "draw", "amount": 2}],
   "upgrade": {"effects": [{"op": "draw", "amount": 3}]}, "ai_value": 5},
  {"id": "lantern_oil", "name": "card.lantern_oil.name", "text": "card.lantern_oil.text", "pool": "sexton", "type": "skill", "cost": 0, "rarity": "common", "tags": ["draw"], "keywords": ["exhaust"], "target": "none",
   "effects": [{"op": "energy", "amount": 1}, {"op": "draw", "amount": 1}],
   "upgrade": {"effects": [{"op": "energy", "amount": 1}, {"op": "draw", "amount": 2}]}, "ai_value": 4},
  {"id": "bone_shard", "name": "card.bone_shard.name", "text": "card.bone_shard.text", "pool": "sexton", "type": "attack", "cost": 0, "rarity": "common", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 3, "scale": "might"}],
   "upgrade": {"effects": [{"op": "damage", "amount": 5, "scale": "might"}]}, "ai_value": 3},
  {"id": "sanctify", "name": "card.sanctify.name", "text": "card.sanctify.text", "pool": "sexton", "type": "skill", "cost": 2, "rarity": "uncommon", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "block", "amount": 8, "scale": "wit"}, {"op": "heal", "amount": 3}],
   "upgrade": {"effects": [{"op": "block", "amount": 10, "scale": "wit"}, {"op": "heal", "amount": 4}]}, "ai_value": 8},
  {"id": "hallowed_strike", "name": "card.hallowed_strike.name", "text": "card.hallowed_strike.text", "pool": "sexton", "type": "attack", "cost": 2, "rarity": "uncommon", "tags": ["bone", "holy"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 12, "scale": "might"}],
   "upgrade": {"effects": [{"op": "damage", "amount": 16, "scale": "might"}]}, "ai_value": 12},
  {"id": "bulwark", "name": "card.bulwark.name", "text": "card.bulwark.text", "pool": "sexton", "type": "power", "cost": 2, "rarity": "rare", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "apply_status", "status": "thorns", "stacks": 3, "target": "self"}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "thorns", "stacks": 5, "target": "self"}]}, "ai_value": 7},
  {"id": "requiem", "name": "card.requiem.name", "text": "card.requiem.text", "pool": "sexton", "type": "attack", "cost": 3, "rarity": "rare", "tags": ["bone"], "keywords": [], "target": "all_enemies",
   "effects": [{"op": "damage", "amount": 20, "scale": "might"}],
   "upgrade": {"effects": [{"op": "damage", "amount": 26, "scale": "might"}]}, "ai_value": 16},
  {"id": "second_wind", "name": "card.second_wind.name", "text": "card.second_wind.text", "pool": "sexton", "type": "skill", "cost": 1, "rarity": "rare", "tags": ["shield"], "keywords": ["exhaust"], "target": "self",
   "effects": [{"op": "heal", "amount": 6}],
   "upgrade": {"effects": [{"op": "heal", "amount": 9}]}, "ai_value": 5},
  {"id": "dig_in", "name": "card.dig_in.name", "text": "card.dig_in.text", "pool": "sexton", "type": "skill", "cost": 1, "rarity": "common", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "block", "amount": 3, "scale": "wit"}, {"op": "apply_status", "status": "wit_buff", "stacks": 1, "target": "self"}],
   "upgrade": {"effects": [{"op": "block", "amount": 5, "scale": "wit"}, {"op": "apply_status", "status": "wit_buff", "stacks": 1, "target": "self"}]}, "ai_value": 5},
  {"id": "sharpen_spade", "name": "card.sharpen_spade.name", "text": "card.sharpen_spade.text", "pool": "sexton", "type": "skill", "cost": 1, "rarity": "uncommon", "tags": ["bone"], "keywords": ["exhaust"], "target": "self",
   "effects": [{"op": "apply_status", "status": "might_buff", "stacks": 2, "target": "self"}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "might_buff", "stacks": 3, "target": "self"}]}, "ai_value": 7},
  {"id": "tolling_bell", "name": "card.tolling_bell.name", "text": "card.tolling_bell.text", "pool": "sexton", "type": "skill", "cost": 1, "rarity": "uncommon", "tags": ["bone"], "keywords": [], "target": "all_enemies",
   "effects": [{"op": "apply_status", "status": "vulnerable", "stacks": 2}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "vulnerable", "stacks": 3}]}, "ai_value": 6}
]
```

`data/cards/catacombs.json`:

```json
[
  {"id": "rat_swarm", "name": "card.rat_swarm.name", "text": "card.rat_swarm.text", "pool": "catacombs", "type": "attack", "cost": 1, "rarity": "common", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 2, "scale": "might", "hits": 4}],
   "upgrade": {"effects": [{"op": "damage", "amount": 3, "scale": "might", "hits": 4}]}, "ai_value": 8},
  {"id": "cold_iron", "name": "card.cold_iron.name", "text": "card.cold_iron.text", "pool": "catacombs", "type": "attack", "cost": 1, "rarity": "common", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 7, "scale": "might"}, {"op": "apply_status", "status": "weak", "stacks": 1}],
   "upgrade": {"effects": [{"op": "damage", "amount": 9, "scale": "might"}, {"op": "apply_status", "status": "weak", "stacks": 1}]}, "ai_value": 8},
  {"id": "shroud", "name": "card.shroud.name", "text": "card.shroud.text", "pool": "catacombs", "type": "skill", "cost": 1, "rarity": "common", "tags": ["shield"], "keywords": ["retain"], "target": "self",
   "effects": [{"op": "block", "amount": 6, "scale": "wit"}],
   "upgrade": {"effects": [{"op": "block", "amount": 8, "scale": "wit"}]}, "ai_value": 6},
  {"id": "grave_moss", "name": "card.grave_moss.name", "text": "card.grave_moss.text", "pool": "catacombs", "type": "skill", "cost": 1, "rarity": "common", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "apply_status", "status": "regen", "stacks": 3, "target": "self"}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "regen", "stacks": 4, "target": "self"}]}, "ai_value": 5},
  {"id": "tomb_lantern", "name": "card.tomb_lantern.name", "text": "card.tomb_lantern.text", "pool": "catacombs", "type": "skill", "cost": 1, "rarity": "uncommon", "tags": ["draw"], "keywords": [], "target": "none",
   "effects": [{"op": "draw", "amount": 2}],
   "upgrade": {"effects": [{"op": "draw", "amount": 3}]}, "ai_value": 5},
  {"id": "bone_spear", "name": "card.bone_spear.name", "text": "card.bone_spear.text", "pool": "catacombs", "type": "attack", "cost": 2, "rarity": "uncommon", "tags": ["bone"], "keywords": [], "target": "enemy",
   "effects": [{"op": "damage", "amount": 14, "scale": "might"}],
   "upgrade": {"effects": [{"op": "damage", "amount": 18, "scale": "might"}]}, "ai_value": 13},
  {"id": "plague_vial", "name": "card.plague_vial.name", "text": "card.plague_vial.text", "pool": "catacombs", "type": "skill", "cost": 1, "rarity": "uncommon", "tags": ["poison"], "keywords": [], "target": "enemy",
   "effects": [{"op": "apply_status", "status": "poison", "stacks": 4, "scale": "wit"}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "poison", "stacks": 6, "scale": "wit"}]}, "ai_value": 7},
  {"id": "death_knell", "name": "card.death_knell.name", "text": "card.death_knell.text", "pool": "catacombs", "type": "power", "cost": 2, "rarity": "rare", "tags": ["bone"], "keywords": [], "target": "self",
   "effects": [{"op": "apply_status", "status": "knell", "stacks": 4, "target": "self"}],
   "upgrade": {"effects": [{"op": "apply_status", "status": "knell", "stacks": 6, "target": "self"}]}, "ai_value": 9},
  {"id": "cairn", "name": "card.cairn.name", "text": "card.cairn.text", "pool": "catacombs", "type": "skill", "cost": 2, "rarity": "rare", "tags": ["shield"], "keywords": [], "target": "self",
   "effects": [{"op": "block", "amount": 14, "scale": "wit"}, {"op": "apply_status", "status": "thorns", "stacks": 2, "target": "self"}],
   "upgrade": {"effects": [{"op": "block", "amount": 18, "scale": "wit"}, {"op": "apply_status", "status": "thorns", "stacks": 3, "target": "self"}]}, "ai_value": 11},
  {"id": "ashes", "name": "card.ashes.name", "text": "card.ashes.text", "pool": "catacombs", "type": "skill", "cost": 1, "rarity": "uncommon", "tags": ["ember"], "keywords": [], "target": "all_enemies",
   "effects": [{"op": "damage", "amount": 3}, {"op": "apply_status", "status": "burn", "stacks": 2}],
   "upgrade": {"effects": [{"op": "damage", "amount": 4}, {"op": "apply_status", "status": "burn", "stacks": 3}]}, "ai_value": 7}
]
```

- [ ] **Step 4: Write the enemies, relics, class, biome, affinity and balance files**

`data/enemies/catacombs.json`:

```json
[
  {"id": "bone_rat", "name": "enemy.bone_rat.name", "biome": "catacombs", "tags": ["undead"], "hp": 14, "kind": "regular",
   "moves": [{"id": "bite", "intent": "attack", "damage": 5, "hits": 1}, {"id": "gnaw", "intent": "attack", "damage": 3, "hits": 2}],
   "pattern": {"kind": "weighted", "moves": [{"move": "bite", "weight": 2}, {"move": "gnaw", "weight": 1}], "no_repeat": false}},
  {"id": "shambler", "name": "enemy.shambler.name", "biome": "catacombs", "tags": ["undead"], "hp": 24, "kind": "regular",
   "moves": [{"id": "lurch", "intent": "attack", "damage": 7, "hits": 1}, {"id": "brace", "intent": "block", "block": 6}],
   "pattern": {"kind": "sequence", "moves": ["lurch", "lurch", "brace"]}},
  {"id": "grave_wisp", "name": "enemy.grave_wisp.name", "biome": "catacombs", "tags": ["undead"], "hp": 12, "kind": "regular",
   "moves": [{"id": "wail", "intent": "debuff", "status": "weak", "stacks": 1}, {"id": "flicker", "intent": "attack", "damage": 4, "hits": 1}],
   "pattern": {"kind": "sequence", "moves": ["wail", "flicker", "flicker"]}},
  {"id": "skull_stack", "name": "enemy.skull_stack.name", "biome": "catacombs", "tags": ["undead"], "hp": 20, "kind": "regular",
   "moves": [{"id": "reassemble", "intent": "buff", "status": "might_buff", "stacks": 1}, {"id": "topple", "intent": "attack", "damage": 9, "hits": 1}],
   "pattern": {"kind": "sequence", "moves": ["reassemble", "topple"]}},
  {"id": "bone_archer", "name": "enemy.bone_archer.name", "biome": "catacombs", "tags": ["undead"], "hp": 16, "kind": "regular",
   "moves": [{"id": "aim", "intent": "buff", "status": "might_buff", "stacks": 2}, {"id": "volley", "intent": "attack", "damage": 3, "hits": 3}],
   "pattern": {"kind": "sequence", "moves": ["aim", "volley"]}},
  {"id": "crypt_spider", "name": "enemy.crypt_spider.name", "biome": "catacombs", "tags": ["flesh"], "hp": 18, "kind": "regular",
   "moves": [{"id": "sting", "intent": "attack", "damage": 4, "hits": 1, "status": "poison", "stacks": 3}, {"id": "web", "intent": "debuff", "status": "weak", "stacks": 1}],
   "pattern": {"kind": "weighted", "moves": [{"move": "sting", "weight": 2}, {"move": "web", "weight": 1}], "no_repeat": true}},
  {"id": "hollow_knight", "name": "enemy.hollow_knight.name", "biome": "catacombs", "tags": ["undead"], "hp": 34, "kind": "regular",
   "moves": [{"id": "guard", "intent": "block", "block": 10}, {"id": "cleave", "intent": "attack", "damage": 11, "hits": 1}],
   "pattern": {"kind": "sequence", "moves": ["guard", "cleave", "cleave"]}},
  {"id": "plague_bearer", "name": "enemy.plague_bearer.name", "biome": "catacombs", "tags": ["undead", "flesh"], "hp": 22, "kind": "regular",
   "moves": [{"id": "cough", "intent": "attack", "damage": 3, "hits": 1, "status": "poison", "stacks": 2}, {"id": "swell", "intent": "block", "block": 5}],
   "pattern": {"kind": "sequence", "moves": ["cough", "swell"]}},
  {"id": "ossuary_warden", "name": "enemy.ossuary_warden.name", "biome": "catacombs", "tags": ["undead"], "hp": 60, "kind": "elite",
   "moves": [{"id": "wall", "intent": "block", "block": 12}, {"id": "slam", "intent": "attack", "damage": 14, "hits": 1}, {"id": "rally", "intent": "buff", "status": "might_buff", "stacks": 2}],
   "pattern": {"kind": "sequence", "moves": ["wall", "slam", "rally", "slam"]}},
  {"id": "mother_of_bones", "name": "enemy.mother_of_bones.name", "biome": "catacombs", "tags": ["undead"], "hp": 110, "kind": "boss",
   "moves": [{"id": "raise", "intent": "summon", "enemy": "bone_rat"}, {"id": "crush", "intent": "attack", "damage": 16, "hits": 1}, {"id": "bristle", "intent": "buff", "status": "thorns", "stacks": 3}],
   "pattern": {"kind": "sequence", "moves": ["raise", "crush", "bristle", "crush", "crush"]}}
]
```

`data/relics/slice.json`:

```json
[
  {"id": "sextons_lantern", "name": "relic.sextons_lantern.name", "text": "relic.sextons_lantern.text", "hooks": {"on_fight_start": [{"op": "block", "amount": 3}]}},
  {"id": "bone_charm", "name": "relic.bone_charm.name", "text": "relic.bone_charm.text", "hooks": {"on_fight_start": [{"op": "apply_status", "status": "might_buff", "stacks": 1, "target": "self"}]}},
  {"id": "cracked_hourglass", "name": "relic.cracked_hourglass.name", "text": "relic.cracked_hourglass.text", "hooks": {"on_fight_start": [{"op": "draw", "amount": 1}]}},
  {"id": "ossuary_key", "name": "relic.ossuary_key.name", "text": "relic.ossuary_key.text", "hooks": {"on_fight_end": [{"op": "heal", "amount": 4}]}},
  {"id": "lead_censer", "name": "relic.lead_censer.name", "text": "relic.lead_censer.text", "hooks": {"on_fight_start": [{"op": "apply_status", "status": "weak", "stacks": 1, "target": "all_enemies"}]}},
  {"id": "grave_coin", "name": "relic.grave_coin.name", "text": "relic.grave_coin.text", "hooks": {"on_fight_end": [{"op": "coin", "amount": 10}]}}
]
```

`data/classes/sexton.json`:

```json
[
  {"id": "sexton", "name": "class.sexton.name", "base_hp": 70,
   "stats": {"might": 0, "wit": 0, "vigor": 0, "focus": 0},
   "starting_deck": ["strike", "strike", "strike", "strike", "strike", "brace", "brace", "brace", "brace", "last_rites"],
   "relic": "sextons_lantern", "pool": "sexton"}
]
```

`data/biomes/catacombs.json`:

```json
[
  {"id": "catacombs", "name": "biome.catacombs.name", "floors": [1, 10], "card_pool": "catacombs",
   "encounters": [
     {"floors": [1, 3], "groups": [["bone_rat"], ["bone_rat", "bone_rat"], ["grave_wisp"], ["shambler"]]},
     {"floors": [4, 6], "groups": [["shambler", "bone_rat"], ["skull_stack"], ["bone_archer", "grave_wisp"], ["crypt_spider"]]},
     {"floors": [7, 10], "groups": [["hollow_knight"], ["plague_bearer", "bone_archer"], ["skull_stack", "crypt_spider"], ["shambler", "shambler", "bone_rat"]]}
   ],
   "elites": [["ossuary_warden"]],
   "boss": ["mother_of_bones"],
   "node_patterns": [["fight", "fight", "rest"], ["fight", "event", "fight"], ["fight", "shop", "fight"], ["fight", "fight", "elite"], ["event", "fight", "rest"], ["fight", "elite", "shop"]]}
]
```

`data/affinity.json`:

```json
{
  "poison": {"construct": 0.0, "flesh": 1.5},
  "holy": {"undead": 1.5}
}
```

`data/balance.json`:

```json
{
  "enemy_hp_growth": 1.06,
  "enemy_damage_growth": 1.04,
  "base_energy": 3,
  "base_draw": 5,
  "hand_limit": 10,
  "turn_cap": 30,
  "focus_draw_thresholds": [3, 9],
  "focus_energy_thresholds": [6, 12],
  "weak_multiplier": 0.75,
  "vulnerable_multiplier": 1.5
}
```

- [ ] **Step 5: Write the strings file**

`data/strings/en.csv`:

```csv
key,text
class.sexton.name,Sexton
biome.catacombs.name,Catacombs
card.strike.name,Strike
card.strike.text,Deal 6 damage.
card.brace.name,Brace
card.brace.text,Gain 5 Block.
card.last_rites.name,Last Rites
card.last_rites.text,Deal 4 damage. Apply 2 Weak.
card.shovel_swing.name,Shovel Swing
card.shovel_swing.text,Deal 8 damage.
card.bone_wall.name,Bone Wall
card.bone_wall.text,Gain 11 Block.
card.grave_dust.name,Grave Dust
card.grave_dust.text,Apply 1 Vulnerable. Draw 1 card.
card.reaping.name,Reaping
card.reaping.text,Deal 4 damage 3 times.
card.vigil.name,Vigil
card.vigil.text,At the start of each turn gain 3 Block.
card.censer_smoke.name,Censer Smoke
card.censer_smoke.text,Gain 4 Block. Apply 1 Weak to all enemies.
card.exhume.name,Exhume
card.exhume.text,Draw 2 cards. Exhaust.
card.lantern_oil.name,Lantern Oil
card.lantern_oil.text,Gain 1 Energy. Draw 1 card. Exhaust.
card.bone_shard.name,Bone Shard
card.bone_shard.text,Deal 3 damage.
card.sanctify.name,Sanctify
card.sanctify.text,Gain 8 Block. Heal 3.
card.hallowed_strike.name,Hallowed Strike
card.hallowed_strike.text,Deal 12 damage. Holy: 50% more against the undead.
card.bulwark.name,Bulwark
card.bulwark.text,Gain 3 Thorns.
card.requiem.name,Requiem
card.requiem.text,Deal 20 damage to all enemies.
card.second_wind.name,Second Wind
card.second_wind.text,Heal 6. Exhaust.
card.dig_in.name,Dig In
card.dig_in.text,Gain 3 Block. Gain 1 Wit this fight.
card.sharpen_spade.name,Sharpen Spade
card.sharpen_spade.text,Gain 2 Might this fight. Exhaust.
card.tolling_bell.name,Tolling Bell
card.tolling_bell.text,Apply 2 Vulnerable to all enemies.
card.rat_swarm.name,Rat Swarm
card.rat_swarm.text,Deal 2 damage 4 times.
card.cold_iron.name,Cold Iron
card.cold_iron.text,Deal 7 damage. Apply 1 Weak.
card.shroud.name,Shroud
card.shroud.text,Gain 6 Block. Retain.
card.grave_moss.name,Grave Moss
card.grave_moss.text,Gain 3 Regen.
card.tomb_lantern.name,Tomb Lantern
card.tomb_lantern.text,Draw 2 cards.
card.bone_spear.name,Bone Spear
card.bone_spear.text,Deal 14 damage.
card.plague_vial.name,Plague Vial
card.plague_vial.text,Apply 4 Poison.
card.death_knell.name,Death Knell
card.death_knell.text,At the start of each turn deal 4 damage to all enemies.
card.cairn.name,Cairn
card.cairn.text,Gain 14 Block. Gain 2 Thorns.
card.ashes.name,Ashes
card.ashes.text,Deal 3 damage to all enemies. Apply 2 Burn to all enemies.
enemy.bone_rat.name,Bone Rat
enemy.shambler.name,Shambler
enemy.grave_wisp.name,Grave Wisp
enemy.skull_stack.name,Skull Stack
enemy.bone_archer.name,Bone Archer
enemy.crypt_spider.name,Crypt Spider
enemy.hollow_knight.name,Hollow Knight
enemy.plague_bearer.name,Plague Bearer
enemy.ossuary_warden.name,Ossuary Warden
enemy.mother_of_bones.name,Mother of Bones
relic.sextons_lantern.name,Sexton's Lantern
relic.sextons_lantern.text,Start each fight with 3 Block.
relic.bone_charm.name,Bone Charm
relic.bone_charm.text,Start each fight with 1 Might.
relic.cracked_hourglass.name,Cracked Hourglass
relic.cracked_hourglass.text,Draw 1 extra card at the start of each fight.
relic.ossuary_key.name,Ossuary Key
relic.ossuary_key.text,Heal 4 after each fight.
relic.lead_censer.name,Lead Censer
relic.lead_censer.text,Enemies start each fight with 1 Weak.
relic.grave_coin.name,Grave Coin
relic.grave_coin.text,Gain 10 Coin after each fight.
```

Delete the marker: `data/.gdkeep`.

- [ ] **Step 6: Run to verify they pass**

Run: `tools\test.cmd tests/core/content`
Expected: PASS — all content suites green, including `test_slice_content_is_valid`. If the validator reports a missing string key, the CSV row is missing or misspelled — fix the data, not the test.

- [ ] **Step 7: Commit**

```bash
git rm -q data/.gdkeep
git add data tests/core/content/slice_content_test.gd
git commit -m "content: Sexton class, 30 cards, Catacombs enemies, slice relics, balance and strings"
```

---

### Task 6: Fight state, hero snapshot, enemy state, scaling

**Files:**
- Create: `core/combat/card_instance.gd`, `core/combat/hero_snapshot.gd`, `core/combat/enemy_state.gd`, `core/combat/fight_state.gd`, `core/combat/scaling.gd`
- Create: `tests/helpers/fixtures.gd`
- Test: `tests/core/combat/fight_state_test.gd`

**Interfaces:**
- Consumes: `Content`, `CardDef`, `EnemyDef`, `ClassDef`, `Rng`.
- Produces:
  - `CardInstance(uid: int, def_id: String, upgraded: bool)`; `clone()`, `to_dict()`, `static from_dict(d)`.
  - `HeroSnapshot` fields `class_id: String`, `deck: Array[CardInstance]`, `relics: Array[String]`, `stats: Dictionary` (might/wit/vigor/focus), `hp: int`, `max_hp: int`; `static starter(content: Content, class_id: String) -> HeroSnapshot`; `static max_hp_for(base_hp: int, vigor: int) -> int`; `clone()`.
  - `EnemyState` fields `def_id`, `hp`, `max_hp`, `block`, `statuses: Dictionary`, `pattern_index: int`, `last_move: String`, `next_move: String`, `alive: bool`; `status(name: String) -> int`; `clone()`.
  - `FightState` fields `content`, `rng`, `floor`, `turn`, `phase` ("player"|"won"|"lost"), `hero_hp`, `hero_max_hp`, `hero_block`, `energy`, `max_energy`, `draw_per_turn`, `stats`, `statuses`, `relics`, `draw_pile`, `hand`, `discard_pile`, `exhaust_pile` (all `Array[CardInstance]`), `enemies: Array[EnemyState]`, `cards_played_this_turn`, `next_uid`, `pending_x`, `events: Array`; methods `emit(event: Dictionary)`, `card_def(card) -> CardDef`, `might() -> int`, `wit() -> int`, `hero_status(name) -> int`, `living_enemy_indices() -> Array[int]`, `all_enemies_dead() -> bool`, `is_over() -> bool`, `hand_limit() -> int`, `new_card(def_id, upgraded=false) -> CardInstance`, `draw(n) -> Array[CardInstance]`, `reshuffle()`, `discard_hand()`, `clone() -> FightState`.
  - `Scaling.enemy_hp(base: int, floor: int, balance: Dictionary) -> int`, `Scaling.enemy_damage(base: int, floor: int, balance: Dictionary) -> int`.
  - `TestFixtures` (tests only): `content() -> Content` (the real `res://data`, cached), `bare_state(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1) -> FightState` (hero 70 HP, 3 energy, no cards, enemies spawned at scaled HP, no intents chosen), `give_hand(s, card_ids, upgraded=false)`, `fill_draw(s, card_ids)`.
  - Events emitted here: `card_drawn {uid, card}`, `reshuffle {count}`, `card_discarded {uid, card}`, `hand_full {}`.

- [ ] **Step 1: Write the test helper**

`tests/helpers/fixtures.gd`:

```gdscript
class_name TestFixtures
extends RefCounted
## Builders for engine tests. Uses the real slice content so tests exercise
## the same data the game ships.

static var _content: Content


static func content() -> Content:
	if _content == null:
		_content = Content.load_from("res://data")
	return _content


static func bare_state(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1) -> FightState:
	var s := FightState.new()
	s.content = content()
	s.rng = Rng.new(seed)
	s.floor = floor
	s.hero_hp = 70
	s.hero_max_hp = 70
	s.energy = 3
	s.max_energy = 3
	s.draw_per_turn = 5
	for enemy_id in enemy_ids:
		var def: EnemyDef = content().enemies[String(enemy_id)]
		var e := EnemyState.new()
		e.def_id = String(enemy_id)
		e.max_hp = Scaling.enemy_hp(def.hp, floor, content().balance)
		e.hp = e.max_hp
		s.enemies.append(e)
	return s


static func give_hand(s: FightState, card_ids: Array, upgraded: bool = false) -> void:
	s.hand.clear()
	for id in card_ids:
		s.hand.append(s.new_card(String(id), upgraded))


static func fill_draw(s: FightState, card_ids: Array) -> void:
	s.draw_pile.clear()
	for id in card_ids:
		s.draw_pile.append(s.new_card(String(id)))


static func events_of(s: FightState, type: String) -> Array:
	var out: Array = []
	for ev in s.events:
		if ev["type"] == type:
			out.append(ev)
	return out
```

- [ ] **Step 2: Write the failing tests**

`tests/core/combat/fight_state_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_starter_hero_snapshot() -> void:
	var h := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	assert_str(h.class_id).is_equal("sexton")
	assert_array(h.deck).has_size(10)
	assert_str(h.deck[0].def_id).is_equal("strike")
	assert_int(h.deck[9].uid).is_equal(10)
	assert_array(h.relics).is_equal(["sextons_lantern"])
	assert_int(h.max_hp).is_equal(70)
	assert_int(h.hp).is_equal(70)
	assert_int(h.stats["focus"]).is_equal(0)


func test_max_hp_formula_and_clone() -> void:
	assert_int(HeroSnapshot.max_hp_for(70, 4)).is_equal(82)
	var h := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	var c := h.clone()
	c.deck.clear()
	c.stats["might"] = 5
	assert_array(h.deck).has_size(10)
	assert_int(h.stats["might"]).is_equal(0)


func test_card_instance_round_trip() -> void:
	var card := CardInstance.new(7, "strike", true)
	var back := CardInstance.from_dict(card.to_dict())
	assert_int(back.uid).is_equal(7)
	assert_str(back.def_id).is_equal("strike")
	assert_bool(back.upgraded).is_true()


func test_scaling_curves() -> void:
	var b := TestFixtures.content().balance
	assert_int(Scaling.enemy_hp(14, 1, b)).is_equal(14)
	assert_int(Scaling.enemy_hp(14, 10, b)).is_equal(24)
	assert_int(Scaling.enemy_damage(5, 1, b)).is_equal(5)
	assert_int(Scaling.enemy_damage(5, 10, b)).is_equal(7)


func test_bare_state_spawns_scaled_enemies() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "shambler"], 10)
	assert_array(s.enemies).has_size(2)
	assert_int(s.enemies[0].hp).is_equal(24)
	assert_int(s.enemies[1].hp).is_equal(41)
	assert_array(s.living_enemy_indices()).is_equal([0, 1])
	assert_bool(s.all_enemies_dead()).is_false()


func test_draw_then_reshuffle_from_discard() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.fill_draw(s, ["strike", "brace", "strike"])
	var drawn := s.draw(5)
	assert_array(drawn).has_size(3)
	assert_array(s.hand).has_size(3)
	assert_array(s.draw_pile).is_empty()
	assert_array(TestFixtures.events_of(s, "reshuffle")).is_empty()
	s.discard_hand()
	assert_array(s.discard_pile).has_size(3)
	s.draw(2)
	assert_array(s.hand).has_size(2)
	assert_array(s.draw_pile).has_size(1)
	assert_array(s.discard_pile).is_empty()
	assert_array(TestFixtures.events_of(s, "reshuffle")).has_size(1)


func test_draw_respects_hand_limit() -> void:
	var s := TestFixtures.bare_state()
	var ids: Array = []
	for i in 12:
		ids.append("strike")
	TestFixtures.fill_draw(s, ids)
	s.draw(12)
	assert_array(s.hand).has_size(10)
	assert_array(TestFixtures.events_of(s, "hand_full")).has_size(1)


func test_discard_hand_keeps_retain_cards() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.give_hand(s, ["strike", "shroud"])
	s.discard_hand()
	assert_array(s.hand).has_size(1)
	assert_str(s.hand[0].def_id).is_equal("shroud")
	assert_array(s.discard_pile).has_size(1)


func test_new_card_uids_are_unique() -> void:
	var s := TestFixtures.bare_state()
	var a := s.new_card("strike")
	var b := s.new_card("strike")
	assert_int(a.uid).is_not_equal(b.uid)


func test_might_and_wit_include_buffs() -> void:
	var s := TestFixtures.bare_state()
	s.stats["might"] = 2
	s.stats["wit"] = 1
	s.statuses["might_buff"] = 3
	s.statuses["wit_buff"] = 2
	assert_int(s.might()).is_equal(5)
	assert_int(s.wit()).is_equal(3)
	assert_int(s.hero_status("weak")).is_equal(0)


func test_clone_is_independent() -> void:
	var s := TestFixtures.bare_state(["bone_rat"], 1, 5)
	TestFixtures.give_hand(s, ["strike", "brace"])
	s.statuses["weak"] = 1
	var c := s.clone()
	c.hand.clear()
	c.enemies[0].hp -= 5
	c.enemies[0].statuses["vulnerable"] = 2
	c.statuses["weak"] = 9
	c.stats["might"] = 4
	assert_array(s.hand).has_size(2)
	assert_int(s.enemies[0].hp).is_equal(14)
	assert_int(s.enemies[0].status("vulnerable")).is_equal(0)
	assert_int(s.hero_status("weak")).is_equal(1)
	assert_int(s.stats["might"]).is_equal(0)
	assert_array(c.events).is_empty()
	assert_int(s.rng.randi_range("deck", 0, 100000)).is_equal(c.rng.randi_range("deck", 0, 100000))
```

- [ ] **Step 3: Run to verify they fail**

Run: `tools\test.cmd tests/core/combat`
Expected: FAIL — `FightState` / `TestFixtures` not found.

- [ ] **Step 4: Implement the state classes**

`core/combat/card_instance.gd`:

```gdscript
class_name CardInstance
extends RefCounted
## One physical card in a deck. uid is unique within a hero's lifetime.

var uid: int = 0
var def_id: String = ""
var upgraded: bool = false


func _init(p_uid: int = 0, p_def_id: String = "", p_upgraded: bool = false) -> void:
	uid = p_uid
	def_id = p_def_id
	upgraded = p_upgraded


func clone() -> CardInstance:
	return CardInstance.new(uid, def_id, upgraded)


func to_dict() -> Dictionary:
	return {"uid": uid, "def_id": def_id, "upgraded": upgraded}


static func from_dict(d: Dictionary) -> CardInstance:
	return CardInstance.new(int(d.get("uid", 0)), String(d.get("def_id", "")), bool(d.get("upgraded", false)))
```

`core/combat/hero_snapshot.gd`:

```gdscript
class_name HeroSnapshot
extends RefCounted
## What the run layer hands the combat engine: the hero as they enter a fight.

var class_id: String = ""
var deck: Array[CardInstance] = []
var relics: Array[String] = []
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var hp: int = 1
var max_hp: int = 1


static func max_hp_for(base_hp: int, vigor: int) -> int:
	return base_hp + 3 * vigor


static func starter(content: Content, class_id: String) -> HeroSnapshot:
	var klass: ClassDef = content.classes[class_id]
	var h := HeroSnapshot.new()
	h.class_id = class_id
	var uid := 1
	for card_id in klass.starting_deck:
		h.deck.append(CardInstance.new(uid, card_id, false))
		uid += 1
	h.relics.append(klass.relic)
	for key in klass.stats:
		h.stats[key] = int(klass.stats[key])
	h.max_hp = max_hp_for(klass.base_hp, int(h.stats["vigor"]))
	h.hp = h.max_hp
	return h


func clone() -> HeroSnapshot:
	var h := HeroSnapshot.new()
	h.class_id = class_id
	for card in deck:
		h.deck.append(card.clone())
	h.relics = relics.duplicate()
	h.stats = stats.duplicate()
	h.hp = hp
	h.max_hp = max_hp
	return h
```

`core/combat/enemy_state.gd`:

```gdscript
class_name EnemyState
extends RefCounted

var def_id: String = ""
var hp: int = 1
var max_hp: int = 1
var block: int = 0
var statuses: Dictionary = {}
var pattern_index: int = 0
var last_move: String = ""
var next_move: String = ""
var alive: bool = true


func status(name: String) -> int:
	return int(statuses.get(name, 0))


func clone() -> EnemyState:
	var e := EnemyState.new()
	e.def_id = def_id
	e.hp = hp
	e.max_hp = max_hp
	e.block = block
	e.statuses = statuses.duplicate()
	e.pattern_index = pattern_index
	e.last_move = last_move
	e.next_move = next_move
	e.alive = alive
	return e
```

`core/combat/scaling.gd`:

```gdscript
class_name Scaling
extends RefCounted
## Per-floor enemy curves. Floor 1 is the unscaled base.


static func enemy_hp(base: int, floor: int, balance: Dictionary) -> int:
	var growth := float(balance.get("enemy_hp_growth", 1.06))
	return maxi(1, int(round(base * pow(growth, floor - 1))))


static func enemy_damage(base: int, floor: int, balance: Dictionary) -> int:
	var growth := float(balance.get("enemy_damage_growth", 1.04))
	return maxi(0, int(round(base * pow(growth, floor - 1))))
```

`core/combat/fight_state.gd`:

```gdscript
class_name FightState
extends RefCounted
## The complete state of one fight. Mutated in place by the engine;
## clone() returns an independent copy for what-if searches. Events are
## appended to `events` and never cloned.

var content: Content
var rng: Rng
var floor: int = 1
var turn: int = 0
var phase: String = "player"
var hero_hp: int = 1
var hero_max_hp: int = 1
var hero_block: int = 0
var energy: int = 0
var max_energy: int = 3
var draw_per_turn: int = 5
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var statuses: Dictionary = {}
var relics: Array[String] = []
var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []
var enemies: Array[EnemyState] = []
var cards_played_this_turn: int = 0
var next_uid: int = 1000
var pending_x: int = 0
var events: Array = []


func emit(event: Dictionary) -> void:
	events.append(event)


func card_def(card: CardInstance) -> CardDef:
	return content.cards[card.def_id]


func might() -> int:
	return int(stats.get("might", 0)) + int(statuses.get("might_buff", 0))


func wit() -> int:
	return int(stats.get("wit", 0)) + int(statuses.get("wit_buff", 0))


func hero_status(name: String) -> int:
	return int(statuses.get(name, 0))


func living_enemy_indices() -> Array[int]:
	var out: Array[int] = []
	for i in enemies.size():
		if enemies[i].alive:
			out.append(i)
	return out


func all_enemies_dead() -> bool:
	return living_enemy_indices().is_empty()


func is_over() -> bool:
	return phase != "player"


func hand_limit() -> int:
	return int(content.balance.get("hand_limit", 10))


func new_card(def_id: String, upgraded: bool = false) -> CardInstance:
	var card := CardInstance.new(next_uid, def_id, upgraded)
	next_uid += 1
	return card


func draw(n: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in n:
		if hand.size() >= hand_limit():
			emit({"type": "hand_full"})
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			reshuffle()
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
		emit({"type": "card_drawn", "uid": card.uid, "card": card.def_id})
	return drawn


func reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	rng.shuffle("deck", draw_pile)
	emit({"type": "reshuffle", "count": draw_pile.size()})


func discard_hand() -> void:
	var kept: Array[CardInstance] = []
	for card in hand:
		if card_def(card).has_keyword("retain"):
			kept.append(card)
		else:
			discard_pile.append(card)
			emit({"type": "card_discarded", "uid": card.uid, "card": card.def_id})
	hand = kept


func clone() -> FightState:
	var s := FightState.new()
	s.content = content
	s.rng = rng.clone()
	s.floor = floor
	s.turn = turn
	s.phase = phase
	s.hero_hp = hero_hp
	s.hero_max_hp = hero_max_hp
	s.hero_block = hero_block
	s.energy = energy
	s.max_energy = max_energy
	s.draw_per_turn = draw_per_turn
	s.stats = stats.duplicate()
	s.statuses = statuses.duplicate()
	s.relics = relics.duplicate()
	s.draw_pile = _clone_cards(draw_pile)
	s.hand = _clone_cards(hand)
	s.discard_pile = _clone_cards(discard_pile)
	s.exhaust_pile = _clone_cards(exhaust_pile)
	for e in enemies:
		s.enemies.append(e.clone())
	s.cards_played_this_turn = cards_played_this_turn
	s.next_uid = next_uid
	s.pending_x = pending_x
	return s


static func _clone_cards(cards: Array[CardInstance]) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for c in cards:
		out.append(c.clone())
	return out
```

- [ ] **Step 5: Run to verify they pass**

Run: `tools\test.cmd tests/core/combat`
Expected: PASS — 11 test cases, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add core/combat tests/helpers tests/core/combat/fight_state_test.gd
git commit -m "feat(combat): fight state, hero snapshot, enemy state and floor scaling"
```

---

### Task 7: Effect resolver and damage pipeline

**Files:**
- Create: `core/combat/effect_resolver.gd`
- Test: `tests/core/combat/effects_test.gd`

**Interfaces:**
- Consumes: `FightState`, `EnemyState`, `CardDef`, `Content.affinity`, `Content.balance`.
- Produces (all `static`, all on `EffectResolver`):
  - `resolve(s: FightState, effects: Array, source: Dictionary, ctx: Dictionary) -> void` — `source` is `{"kind": "hero"}` or `{"kind": "relic", "id": String}` (enemy moves do not use effect lists; they call the hit functions directly). `ctx` keys: `"target": int` (chosen enemy index or -1), `"card_target": String` (the card's target mode, default `"enemy"`), `"tags": Array` (card tags), `"is_attack": bool`, `"x": int`; the resolver sets `ctx["exhaust"] = true` when an `exhaust_self` op runs.
  - `hit_enemy(s, index: int, base: int, is_attack: bool, tags: Array) -> int` (damage dealt to HP) — applies Weak (hero), Vulnerable (enemy), affinity, block; fires Thorns on the hero per hit when `is_attack`; kills at 0.
  - `hit_hero(s, base: int, attacker_index: int, is_attack: bool) -> int` — applies Weak (enemy), Vulnerable (hero), block; fires hero Thorns on the attacker per hit when `is_attack`.
  - `direct_damage_hero(s, amount: int, cause: String) -> void` and `direct_damage_enemy(s, index: int, amount: int, cause: String) -> void` — ignore block.
  - `heal_hero(s, amount: int) -> void`; `apply_status(s, who: Dictionary, status: String, stacks: int) -> void` where `who` is `{"kind": "hero"}` or `{"kind": "enemy", "index": i}`; Poison stacks are multiplied by the `poison` affinity against the enemy's tags.
  - `kill_enemy(s, index: int) -> void`; `affinity_multiplier(s, tags: Array, enemy: EnemyState) -> float`.
  - Events: `damage {target: "enemy"|"hero", index?, amount, blocked, hp, direct?: bool, cause?: String}`, `block_gained {target, index?, amount}`, `status_applied {target, index?, status, stacks, total}`, `heal {amount, hp}`, `energy_changed {energy}`, `enemy_died {index}`, `card_added {card, where}`, `coin {amount}`.

- [ ] **Step 1: Write the failing tests**

`tests/core/combat/effects_test.gd`:

```gdscript
extends GdUnitTestSuite

const HERO := {"kind": "hero"}


func _ctx(target: int = 0, card_target: String = "enemy", tags: Array = [], is_attack: bool = true, x: int = 0) -> Dictionary:
	return {"target": target, "card_target": card_target, "tags": tags, "is_attack": is_attack, "x": x}


func _card_effects(id: String, upgraded: bool = false) -> Array:
	var def: CardDef = TestFixtures.content().cards[id]
	return def.effects_for(upgraded)


func test_attack_damage_scales_with_might_and_buff() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.stats["might"] = 2
	s.statuses["might_buff"] = 1
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx(0, "enemy", ["bone"]))
	assert_int(s.enemies[0].hp).is_equal(5)
	var ev: Dictionary = TestFixtures.events_of(s, "damage")[0]
	assert_int(ev["amount"]).is_equal(9)
	assert_int(ev["blocked"]).is_equal(0)


func test_multi_hit_and_upgrade() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	EffectResolver.resolve(s, _card_effects("reaping", true), HERO, _ctx())
	assert_int(s.enemies[0].hp).is_equal(24 - 15)
	assert_array(TestFixtures.events_of(s, "damage")).has_size(3)


func test_weak_hero_deals_less_vulnerable_enemy_takes_more() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	s.statuses["weak"] = 1
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.enemies[0].hp).is_equal(24 - 4)
	s.statuses.erase("weak")
	s.enemies[0].statuses["vulnerable"] = 1
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.enemies[0].hp).is_equal(24 - 4 - 9)


func test_skill_damage_ignores_might_and_weak() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	s.stats["might"] = 5
	s.statuses["weak"] = 1
	EffectResolver.resolve(s, _card_effects("ashes"), HERO, _ctx(0, "all_enemies", ["ember"], false))
	assert_int(s.enemies[0].hp).is_equal(21)
	assert_int(s.enemies[0].status("burn")).is_equal(2)


func test_holy_affinity_against_undead_and_not_flesh() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "crypt_spider"])
	EffectResolver.resolve(s, _card_effects("hallowed_strike"), HERO, _ctx(0, "enemy", ["bone", "holy"]))
	assert_bool(s.enemies[0].alive).is_false()
	assert_int(s.enemies[0].hp).is_equal(0)
	assert_array(TestFixtures.events_of(s, "enemy_died")).has_size(1)
	EffectResolver.resolve(s, _card_effects("hallowed_strike"), HERO, _ctx(1, "enemy", ["bone", "holy"]))
	assert_int(s.enemies[1].hp).is_equal(18 - 12)


func test_poison_stacks_use_affinity_and_wit() -> void:
	var s := TestFixtures.bare_state(["crypt_spider", "bone_rat"])
	s.stats["wit"] = 2
	EffectResolver.resolve(s, _card_effects("plague_vial"), HERO, _ctx(0, "enemy", ["poison"], false))
	assert_int(s.enemies[0].status("poison")).is_equal(9)
	EffectResolver.resolve(s, _card_effects("plague_vial"), HERO, _ctx(1, "enemy", ["poison"], false))
	assert_int(s.enemies[1].status("poison")).is_equal(6)


func test_block_scales_with_wit_and_absorbs() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.stats["wit"] = 2
	EffectResolver.resolve(s, _card_effects("brace"), HERO, _ctx(-1, "self", ["shield"], false))
	assert_int(s.hero_block).is_equal(7)
	EffectResolver.hit_hero(s, 10, 0, true)
	assert_int(s.hero_block).is_equal(0)
	assert_int(s.hero_hp).is_equal(67)
	var ev: Dictionary = TestFixtures.events_of(s, "damage")[0]
	assert_int(ev["blocked"]).is_equal(7)
	assert_int(ev["amount"]).is_equal(3)


func test_enemy_block_absorbs_hero_damage() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	s.enemies[0].block = 4
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.enemies[0].block).is_equal(0)
	assert_int(s.enemies[0].hp).is_equal(22)


func test_enemy_weak_and_hero_vulnerable() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].statuses["weak"] = 1
	EffectResolver.hit_hero(s, 10, 0, true)
	assert_int(s.hero_hp).is_equal(63)
	s.enemies[0].statuses.erase("weak")
	s.statuses["vulnerable"] = 1
	EffectResolver.hit_hero(s, 10, 0, true)
	assert_int(s.hero_hp).is_equal(48)


func test_thorns_both_ways_ignore_block() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].statuses["thorns"] = 3
	s.hero_block = 10
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.hero_hp).is_equal(67)
	assert_int(s.hero_block).is_equal(10)
	s.statuses["thorns"] = 2
	s.enemies[0].block = 5
	EffectResolver.hit_hero(s, 1, 0, true)
	assert_int(s.enemies[0].hp).is_equal(14 - 6 - 2)
	assert_int(s.enemies[0].block).is_equal(5)


func test_all_enemies_targeting_and_self_override() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "bone_rat"])
	EffectResolver.resolve(s, _card_effects("censer_smoke"), HERO, _ctx(-1, "all_enemies", ["shield"], false))
	assert_int(s.hero_block).is_equal(4)
	assert_int(s.enemies[0].status("weak")).is_equal(1)
	assert_int(s.enemies[1].status("weak")).is_equal(1)
	EffectResolver.resolve(s, _card_effects("requiem"), HERO, _ctx(-1, "all_enemies", ["bone"]))
	assert_bool(s.all_enemies_dead()).is_true()


func test_self_targeted_status_lands_on_hero() -> void:
	var s := TestFixtures.bare_state()
	EffectResolver.resolve(s, _card_effects("vigil"), HERO, _ctx(-1, "self", ["shield"], false))
	assert_int(s.hero_status("vigil")).is_equal(3)
	EffectResolver.resolve(s, _card_effects("sharpen_spade"), HERO, _ctx(-1, "self", ["bone"], false))
	assert_int(s.might()).is_equal(2)


func test_draw_energy_heal_and_x() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.fill_draw(s, ["strike", "strike", "strike", "strike"])
	s.hero_hp = 60
	EffectResolver.resolve(s, _card_effects("lantern_oil"), HERO, _ctx(-1, "none", ["draw"], false))
	assert_int(s.energy).is_equal(4)
	assert_array(s.hand).has_size(1)
	EffectResolver.resolve(s, [{"op": "draw", "amount": "x"}], HERO, _ctx(-1, "none", [], false, 2))
	assert_array(s.hand).has_size(3)
	EffectResolver.resolve(s, _card_effects("second_wind", true), HERO, _ctx(-1, "self", [], false))
	assert_int(s.hero_hp).is_equal(69)
	EffectResolver.resolve(s, _card_effects("second_wind"), HERO, _ctx(-1, "self", [], false))
	assert_int(s.hero_hp).is_equal(70)


func test_exhaust_self_add_card_and_coin() -> void:
	var s := TestFixtures.bare_state()
	var ctx := _ctx(-1, "none", [], false)
	EffectResolver.resolve(s, [{"op": "exhaust_self"}, {"op": "add_card", "card": "bone_shard", "where": "hand"}, {"op": "add_card", "card": "strike", "where": "draw"}, {"op": "add_card", "card": "brace", "where": "discard"}, {"op": "coin", "amount": 10}], HERO, ctx)
	assert_bool(ctx["exhaust"]).is_true()
	assert_str(s.hand[0].def_id).is_equal("bone_shard")
	assert_str(s.draw_pile[0].def_id).is_equal("strike")
	assert_str(s.discard_pile[0].def_id).is_equal("brace")
	assert_int(TestFixtures.events_of(s, "coin")[0]["amount"]).is_equal(10)


func test_direct_damage_and_kill() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].block = 50
	EffectResolver.direct_damage_enemy(s, 0, 14, "poison")
	assert_bool(s.enemies[0].alive).is_false()
	s.hero_block = 50
	EffectResolver.direct_damage_hero(s, 70, "burn")
	assert_int(s.hero_hp).is_equal(0)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/combat`
Expected: FAIL — `EffectResolver` not found.

- [ ] **Step 3: Implement `core/combat/effect_resolver.gd`**

```gdscript
class_name EffectResolver
extends RefCounted
## Executes effect op lists from cards and relics, and owns the damage
## pipeline used by enemy moves as well. Everything here is static and
## mutates the FightState it is given.


static func resolve(s: FightState, effects: Array, source: Dictionary, ctx: Dictionary) -> void:
	for raw in effects:
		var e: Dictionary = raw
		var op := String(e.get("op", ""))
		match op:
			"damage":
				_damage(s, e, ctx)
			"block":
				_block(s, e, ctx)
			"apply_status":
				_apply_status_op(s, e, ctx)
			"draw":
				s.draw(_amount(e, "amount", ctx))
			"energy":
				s.energy += _amount(e, "amount", ctx)
				s.emit({"type": "energy_changed", "energy": s.energy})
			"heal":
				heal_hero(s, _amount(e, "amount", ctx))
			"exhaust_self":
				ctx["exhaust"] = true
			"add_card":
				_add_card(s, e)
			"coin":
				s.emit({"type": "coin", "amount": _amount(e, "amount", ctx)})
			_:
				push_error("unknown effect op: " + op)


static func _amount(e: Dictionary, key: String, ctx: Dictionary) -> int:
	var v: Variant = e.get(key, 0)
	if v is String:
		return int(ctx.get("x", 0))
	return int(v)


static func _enemy_targets(s: FightState, e: Dictionary, ctx: Dictionary) -> Array[int]:
	var mode := String(e.get("target", "target"))
	var card_target := String(ctx.get("card_target", "enemy"))
	var out: Array[int] = []
	if mode == "self":
		return out
	if mode == "all_enemies" or (mode == "target" and card_target == "all_enemies"):
		return s.living_enemy_indices()
	var t := int(ctx.get("target", -1))
	if t >= 0 and t < s.enemies.size() and s.enemies[t].alive:
		out.append(t)
	return out


static func _damage(s: FightState, e: Dictionary, ctx: Dictionary) -> void:
	var base := _amount(e, "amount", ctx)
	if String(e.get("scale", "")) == "might":
		base += s.might()
	var hits := int(e.get("hits", 1))
	var is_attack := bool(ctx.get("is_attack", false))
	var tags: Array = ctx.get("tags", [])
	for i in hits:
		for t in _enemy_targets(s, e, ctx):
			hit_enemy(s, t, base, is_attack, tags)


static func _block(s: FightState, e: Dictionary, ctx: Dictionary) -> void:
	var amount := _amount(e, "amount", ctx)
	if String(e.get("scale", "")) == "wit":
		amount += s.wit()
	s.hero_block += amount
	s.emit({"type": "block_gained", "target": "hero", "amount": amount})


static func _apply_status_op(s: FightState, e: Dictionary, ctx: Dictionary) -> void:
	var status := String(e.get("status", ""))
	var stacks := _amount(e, "stacks", ctx)
	if String(e.get("scale", "")) == "wit":
		stacks += s.wit()
	var mode := String(e.get("target", "target"))
	var card_target := String(ctx.get("card_target", "enemy"))
	if mode == "self" or (mode == "target" and (card_target == "self" or card_target == "none")):
		apply_status(s, {"kind": "hero"}, status, stacks)
		return
	for t in _enemy_targets(s, e, ctx):
		apply_status(s, {"kind": "enemy", "index": t}, status, stacks)


static func _add_card(s: FightState, e: Dictionary) -> void:
	var card := s.new_card(String(e.get("card", "")))
	var where := String(e.get("where", "hand"))
	match where:
		"hand":
			s.hand.append(card)
		"discard":
			s.discard_pile.append(card)
		"draw":
			s.draw_pile.append(card)
	s.emit({"type": "card_added", "card": card.def_id, "where": where})


static func affinity_multiplier(s: FightState, tags: Array, enemy: EnemyState) -> float:
	var mult := 1.0
	var def: EnemyDef = s.content.enemies[enemy.def_id]
	for tag in tags:
		var row: Dictionary = s.content.affinity.get(String(tag), {})
		for enemy_tag in def.tags:
			mult *= float(row.get(enemy_tag, 1.0))
	return mult


static func hit_enemy(s: FightState, index: int, base: int, is_attack: bool, tags: Array) -> int:
	var e := s.enemies[index]
	if not e.alive:
		return 0
	var mult := 1.0
	if is_attack and s.hero_status("weak") > 0:
		mult *= float(s.content.balance.get("weak_multiplier", 0.75))
	if e.status("vulnerable") > 0:
		mult *= float(s.content.balance.get("vulnerable_multiplier", 1.5))
	mult *= affinity_multiplier(s, tags, e)
	var amount := int(floor(base * mult))
	var blocked := mini(e.block, amount)
	e.block -= blocked
	var dealt := amount - blocked
	e.hp -= dealt
	s.emit({"type": "damage", "target": "enemy", "index": index, "amount": dealt, "blocked": blocked, "hp": e.hp})
	if is_attack and e.status("thorns") > 0:
		direct_damage_hero(s, e.status("thorns"), "thorns")
	if e.hp <= 0:
		kill_enemy(s, index)
	return dealt


static func hit_hero(s: FightState, base: int, attacker_index: int, is_attack: bool) -> int:
	var attacker := s.enemies[attacker_index]
	var mult := 1.0
	if is_attack and attacker.status("weak") > 0:
		mult *= float(s.content.balance.get("weak_multiplier", 0.75))
	if s.hero_status("vulnerable") > 0:
		mult *= float(s.content.balance.get("vulnerable_multiplier", 1.5))
	var amount := int(floor(base * mult))
	var blocked := mini(s.hero_block, amount)
	s.hero_block -= blocked
	var dealt := amount - blocked
	s.hero_hp -= dealt
	s.emit({"type": "damage", "target": "hero", "amount": dealt, "blocked": blocked, "hp": s.hero_hp, "source": attacker_index})
	if is_attack and s.hero_status("thorns") > 0:
		direct_damage_enemy(s, attacker_index, s.hero_status("thorns"), "thorns")
	return dealt


static func direct_damage_hero(s: FightState, amount: int, cause: String) -> void:
	s.hero_hp -= amount
	s.emit({"type": "damage", "target": "hero", "amount": amount, "blocked": 0, "hp": s.hero_hp, "direct": true, "cause": cause})


static func direct_damage_enemy(s: FightState, index: int, amount: int, cause: String) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	e.hp -= amount
	s.emit({"type": "damage", "target": "enemy", "index": index, "amount": amount, "blocked": 0, "hp": e.hp, "direct": true, "cause": cause})
	if e.hp <= 0:
		kill_enemy(s, index)


static func kill_enemy(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	e.hp = 0
	e.alive = false
	e.block = 0
	s.emit({"type": "enemy_died", "index": index, "enemy": e.def_id})


static func heal_hero(s: FightState, amount: int) -> void:
	var before := s.hero_hp
	s.hero_hp = mini(s.hero_max_hp, s.hero_hp + amount)
	s.emit({"type": "heal", "amount": s.hero_hp - before, "hp": s.hero_hp})


static func apply_status(s: FightState, who: Dictionary, status: String, stacks: int) -> void:
	if String(who.get("kind", "")) == "hero":
		s.statuses[status] = s.hero_status(status) + stacks
		s.emit({"type": "status_applied", "target": "hero", "status": status, "stacks": stacks, "total": s.statuses[status]})
		return
	var index := int(who.get("index", -1))
	var e := s.enemies[index]
	if not e.alive:
		return
	if status == "poison":
		stacks = int(floor(stacks * affinity_multiplier(s, ["poison"], e)))
	if stacks <= 0:
		return
	e.statuses[status] = e.status(status) + stacks
	s.emit({"type": "status_applied", "target": "enemy", "index": index, "status": status, "stacks": stacks, "total": e.statuses[status]})
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/combat`
Expected: PASS — 26 test cases across both combat suites, 0 failures. If `test_holy_affinity_against_undead_and_not_flesh` fails on the spider, check that `affinity_multiplier` looks up the enemy's *definition* tags (`s.content.enemies[...]`), not `EnemyState`.

- [ ] **Step 5: Commit**

```bash
git add core/combat/effect_resolver.gd tests/core/combat/effects_test.gd
git commit -m "feat(combat): effect ops, damage pipeline, affinity and statuses application"
```

---

### Task 8: Enemy AI and relic hooks

**Files:**
- Create: `core/combat/enemy_ai.gd`, `core/combat/relics.gd`
- Test: `tests/core/combat/enemy_ai_test.gd`, `tests/core/combat/relics_test.gd`

**Interfaces:**
- Consumes: `FightState`, `EnemyState`, `EnemyDef`, `RelicDef`, `Scaling`, `EffectResolver`, `Rng` stream `"enemy_ai"`.
- Produces:
  - `EnemyAI.spawn(s, enemy_id: String) -> int` — appends a scaled `EnemyState`, chooses its first move, returns its index; returns -1 (and emits `summon_failed`) when `CombatEngine.MAX_ENEMIES` (5) are already alive.
  - `EnemyAI.choose_next_move(s, index: int) -> void` — sets `next_move` from the pattern; emits `enemy_intent {index, move, intent}`.
  - `EnemyAI.intent_of(s, index: int) -> Dictionary` — `{"kind": "attack", "damage": scaled incl. might_buff, "hits"}`, `{"kind": "block", "block"}`, `{"kind": "buff"|"debuff", "status", "stacks"}`, `{"kind": "summon", "enemy"}`.
  - `EnemyAI.scaled_damage(s, index: int, move: Dictionary) -> int`.
  - `EnemyAI.execute_move(s, index: int) -> void` — performs `next_move`, records `last_move`, clears `next_move`; fires `on_damage_taken` relics if hero HP dropped; emits `enemy_move {index, move, intent}` and, for summons, `summon {index, enemy}`.
  - `Relics.fire(s, hook: String) -> void` — for every relic the hero holds, resolves that hook's effects with a relic source and a neutral ctx; emits `relic_triggered {relic, hook}`.
  - Constant `EnemyAI.MAX_ENEMIES := 5`.

- [ ] **Step 1: Write the failing tests**

`tests/core/combat/enemy_ai_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_sequence_pattern_cycles() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	var moves: Array = []
	for i in 4:
		EnemyAI.choose_next_move(s, 0)
		moves.append(s.enemies[0].next_move)
		s.enemies[0].next_move = ""
	assert_array(moves).is_equal(["lurch", "lurch", "brace", "lurch"])
	assert_array(TestFixtures.events_of(s, "enemy_intent")).has_size(4)


func test_weighted_no_repeat_never_repeats() -> void:
	var s := TestFixtures.bare_state(["crypt_spider"])
	var last := ""
	for i in 30:
		EnemyAI.choose_next_move(s, 0)
		var move := s.enemies[0].next_move
		assert_str(move).is_not_equal(last)
		s.enemies[0].last_move = move
		last = move


func test_weighted_is_deterministic_per_seed() -> void:
	var a := TestFixtures.bare_state(["bone_rat"], 1, 11)
	var b := TestFixtures.bare_state(["bone_rat"], 1, 11)
	for i in 10:
		EnemyAI.choose_next_move(a, 0)
		EnemyAI.choose_next_move(b, 0)
		assert_str(a.enemies[0].next_move).is_equal(b.enemies[0].next_move)


func test_intent_shows_scaled_damage_with_buff() -> void:
	var s := TestFixtures.bare_state(["skull_stack"], 10)
	EnemyAI.choose_next_move(s, 0)
	assert_str(s.enemies[0].next_move).is_equal("reassemble")
	EnemyAI.execute_move(s, 0)
	assert_int(s.enemies[0].status("might_buff")).is_equal(1)
	EnemyAI.choose_next_move(s, 0)
	var intent := EnemyAI.intent_of(s, 0)
	assert_str(intent["kind"]).is_equal("attack")
	assert_int(intent["damage"]).is_equal(14)
	assert_int(intent["hits"]).is_equal(1)


func test_attack_moves_hit_hero() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(65)
	assert_str(s.enemies[0].last_move).is_equal("bite")
	assert_str(s.enemies[0].next_move).is_equal("")
	s.enemies[0].next_move = "gnaw"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(59)
	assert_array(TestFixtures.events_of(s, "enemy_move")).has_size(2)


func test_attack_with_status_poisons_hero() -> void:
	var s := TestFixtures.bare_state(["crypt_spider"])
	s.enemies[0].next_move = "sting"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(66)
	assert_int(s.hero_status("poison")).is_equal(3)


func test_block_buff_debuff_moves() -> void:
	var s := TestFixtures.bare_state(["hollow_knight", "grave_wisp", "bone_archer"])
	s.enemies[0].next_move = "guard"
	EnemyAI.execute_move(s, 0)
	assert_int(s.enemies[0].block).is_equal(10)
	s.enemies[1].next_move = "wail"
	EnemyAI.execute_move(s, 1)
	assert_int(s.hero_status("weak")).is_equal(1)
	s.enemies[2].next_move = "aim"
	EnemyAI.execute_move(s, 2)
	assert_int(s.enemies[2].status("might_buff")).is_equal(2)


func test_summon_adds_enemy_with_intent_up_to_cap() -> void:
	var s := TestFixtures.bare_state(["mother_of_bones"], 3)
	s.enemies[0].next_move = "raise"
	EnemyAI.execute_move(s, 0)
	assert_array(s.enemies).has_size(2)
	assert_str(s.enemies[1].def_id).is_equal("bone_rat")
	assert_int(s.enemies[1].hp).is_equal(Scaling.enemy_hp(14, 3, TestFixtures.content().balance))
	assert_str(s.enemies[1].next_move).is_not_equal("")
	assert_array(TestFixtures.events_of(s, "summon")).has_size(1)
	for i in 4:
		s.enemies[0].next_move = "raise"
		EnemyAI.execute_move(s, 0)
	assert_array(s.enemies).has_size(5)
	assert_array(TestFixtures.events_of(s, "summon_failed")).has_size(1)


func test_dead_enemy_does_not_act() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].alive = false
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(70)


func test_bleeding_enemy_hurts_itself_when_attacking() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].statuses["bleed"] = 2
	s.enemies[0].next_move = "gnaw"
	EnemyAI.execute_move(s, 0)
	assert_int(s.enemies[0].hp).is_equal(12)
```

`tests/core/combat/relics_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_fight_start_hooks() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "bone_rat"])
	s.relics = ["sextons_lantern", "bone_charm", "lead_censer"] as Array[String]
	Relics.fire(s, "on_fight_start")
	assert_int(s.hero_block).is_equal(3)
	assert_int(s.might()).is_equal(1)
	assert_int(s.enemies[0].status("weak")).is_equal(1)
	assert_int(s.enemies[1].status("weak")).is_equal(1)
	assert_array(TestFixtures.events_of(s, "relic_triggered")).has_size(3)


func test_fight_end_hooks_and_unrelated_hook() -> void:
	var s := TestFixtures.bare_state()
	s.hero_hp = 50
	s.relics = ["ossuary_key", "grave_coin"] as Array[String]
	Relics.fire(s, "on_turn_start")
	assert_int(s.hero_hp).is_equal(50)
	Relics.fire(s, "on_fight_end")
	assert_int(s.hero_hp).is_equal(54)
	assert_int(TestFixtures.events_of(s, "coin")[0]["amount"]).is_equal(10)


func test_draw_hook_draws_from_pile() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.fill_draw(s, ["strike", "brace"])
	s.relics = ["cracked_hourglass"] as Array[String]
	Relics.fire(s, "on_fight_start")
	assert_array(s.hand).has_size(1)


func test_unknown_relic_is_ignored() -> void:
	var s := TestFixtures.bare_state()
	s.relics = ["not_a_relic"] as Array[String]
	Relics.fire(s, "on_fight_start")
	assert_array(TestFixtures.events_of(s, "relic_triggered")).is_empty()


func test_on_damage_taken_fires_after_enemy_attack() -> void:
	var content := Content.load_from("res://data")
	content.relics["fx_shell"] = RelicDef.from_dict({"id": "fx_shell", "name": "x", "text": "x", "hooks": {"on_damage_taken": [{"op": "block", "amount": 2}]}})
	var s := TestFixtures.bare_state(["bone_rat"])
	s.content = content
	s.relics = ["fx_shell"] as Array[String]
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(65)
	assert_int(s.hero_block).is_equal(2)
	s.hero_block = 50
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_block).is_equal(45)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/combat`
Expected: FAIL — `EnemyAI` / `Relics` not found.

- [ ] **Step 3: Implement `core/combat/relics.gd`**

```gdscript
class_name Relics
extends RefCounted
## Fires relic hooks. A relic is a RelicDef id carried on the FightState.


static func fire(s: FightState, hook: String) -> void:
	for relic_id in s.relics:
		var def: RelicDef = s.content.relics.get(relic_id)
		if def == null or not def.hooks.has(hook):
			continue
		s.emit({"type": "relic_triggered", "relic": relic_id, "hook": hook})
		var ctx := {"target": -1, "card_target": "none", "tags": [], "is_attack": false, "x": 0}
		EffectResolver.resolve(s, def.hooks[hook], {"kind": "relic", "id": relic_id}, ctx)
```

- [ ] **Step 4: Implement `core/combat/enemy_ai.gd`**

```gdscript
class_name EnemyAI
extends RefCounted
## Enemy move selection and execution. Patterns come from EnemyDef.pattern;
## move choice uses the "enemy_ai" rng stream so fights replay from a seed.

const MAX_ENEMIES := 5


static func spawn(s: FightState, enemy_id: String) -> int:
	if s.living_enemy_indices().size() >= MAX_ENEMIES:
		s.emit({"type": "summon_failed", "enemy": enemy_id})
		return -1
	var def: EnemyDef = s.content.enemies[enemy_id]
	var e := EnemyState.new()
	e.def_id = enemy_id
	e.max_hp = Scaling.enemy_hp(def.hp, s.floor, s.content.balance)
	e.hp = e.max_hp
	s.enemies.append(e)
	var index := s.enemies.size() - 1
	choose_next_move(s, index)
	return index


static func choose_next_move(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	var def: EnemyDef = s.content.enemies[e.def_id]
	var kind := String(def.pattern.get("kind", "sequence"))
	var moves: Array = def.pattern.get("moves", [])
	var chosen := ""
	if kind == "sequence":
		chosen = String(moves[e.pattern_index % moves.size()])
		e.pattern_index += 1
	else:
		var no_repeat := bool(def.pattern.get("no_repeat", false))
		var candidates: Array = []
		var weights: Array = []
		for entry in moves:
			var move_id := String(entry["move"])
			if no_repeat and move_id == e.last_move and moves.size() > 1:
				continue
			candidates.append(move_id)
			weights.append(float(entry["weight"]))
		chosen = String(candidates[s.rng.weighted_pick("enemy_ai", weights)])
	e.next_move = chosen
	s.emit({"type": "enemy_intent", "index": index, "move": chosen, "intent": intent_of(s, index)})


static func scaled_damage(s: FightState, index: int, move: Dictionary) -> int:
	var e := s.enemies[index]
	return Scaling.enemy_damage(int(move.get("damage", 0)), s.floor, s.content.balance) + e.status("might_buff")


static func intent_of(s: FightState, index: int) -> Dictionary:
	var e := s.enemies[index]
	var def: EnemyDef = s.content.enemies[e.def_id]
	var move: Dictionary = def.moves.get(e.next_move, {})
	var intent := String(move.get("intent", ""))
	var out := {"kind": intent}
	match intent:
		"attack":
			out["damage"] = scaled_damage(s, index, move)
			out["hits"] = int(move.get("hits", 1))
		"block":
			out["block"] = int(move.get("block", 0))
		"buff", "debuff":
			out["status"] = String(move.get("status", ""))
			out["stacks"] = int(move.get("stacks", 0))
		"summon":
			out["enemy"] = String(move.get("enemy", ""))
	return out


static func execute_move(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive or e.next_move == "":
		return
	var def: EnemyDef = s.content.enemies[e.def_id]
	var move: Dictionary = def.moves[e.next_move]
	var intent := String(move.get("intent", ""))
	var hp_before := s.hero_hp
	s.emit({"type": "enemy_move", "index": index, "move": e.next_move, "intent": intent})
	match intent:
		"attack":
			var dmg := scaled_damage(s, index, move)
			for i in int(move.get("hits", 1)):
				EffectResolver.hit_hero(s, dmg, index, true)
			if e.alive and e.status("bleed") > 0:
				EffectResolver.direct_damage_enemy(s, index, e.status("bleed"), "bleed")
			if move.has("status"):
				EffectResolver.apply_status(s, {"kind": "hero"}, String(move["status"]), int(move.get("stacks", 1)))
		"block":
			var amount := int(move.get("block", 0))
			e.block += amount
			s.emit({"type": "block_gained", "target": "enemy", "index": index, "amount": amount})
		"buff":
			EffectResolver.apply_status(s, {"kind": "enemy", "index": index}, String(move.get("status", "")), int(move.get("stacks", 1)))
		"debuff":
			EffectResolver.apply_status(s, {"kind": "hero"}, String(move.get("status", "")), int(move.get("stacks", 1)))
		"summon":
			var enemy_id := String(move.get("enemy", ""))
			var new_index := spawn(s, enemy_id)
			if new_index >= 0:
				s.emit({"type": "summon", "index": new_index, "enemy": enemy_id, "by": index})
	e.last_move = e.next_move
	e.next_move = ""
	if s.hero_hp < hp_before:
		Relics.fire(s, "on_damage_taken")
```

- [ ] **Step 5: Run to verify they pass**

Run: `tools\test.cmd tests/core/combat`
Expected: PASS — 41 test cases, 0 failures. `test_summon_adds_enemy_with_intent_up_to_cap` expects the fifth raise to fail: four successful summons after the first make five living enemies, then `summon_failed`.

- [ ] **Step 6: Commit**

```bash
git add core/combat/enemy_ai.gd core/combat/relics.gd tests/core/combat/enemy_ai_test.gd tests/core/combat/relics_test.gd
git commit -m "feat(combat): enemy patterns, move execution, summons and relic hooks"
```

---

### Task 9: Status ticks and decay

**Files:**
- Create: `core/combat/status_system.gd`
- Test: `tests/core/combat/status_test.gd`

**Interfaces:**
- Consumes: `FightState`, `EffectResolver.direct_damage_hero/direct_damage_enemy/heal_hero`.
- Produces (static on `StatusSystem`):
  - `hero_turn_start(s, reset_block: bool) -> void` — order: reset block (if asked) → Vigil grants block → Regen heals then decays → Poison damages then decays → Knell damages every living enemy.
  - `hero_turn_end(s) -> void` — Burn damages then decays; Weak, Vulnerable and Bleed decay by 1.
  - `enemy_turn_start(s, index: int) -> void` — reset that enemy's block → Poison damages then decays → Regen heals then decays.
  - `enemy_turn_end(s, index: int) -> void` — Burn damages then decays; Weak, Vulnerable and Bleed decay by 1.
  - `decay(statuses: Dictionary, name: String) -> void` — subtract 1, erase at 0.
  - Permanent for the fight (never decay): `might_buff`, `wit_buff`, `thorns`, `vigil`, `knell`.
  - Events: `status_tick {target, index?, status, amount}` before each damage/heal/block a status produces.

- [ ] **Step 1: Write the failing tests**

`tests/core/combat/status_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_hero_turn_start_order_and_block_reset() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "bone_rat"])
	s.hero_block = 9
	s.hero_hp = 50
	s.statuses = {"vigil": 3, "regen": 2, "poison": 4, "knell": 5}
	StatusSystem.hero_turn_start(s, true)
	assert_int(s.hero_block).is_equal(3)
	assert_int(s.hero_hp).is_equal(50 + 2 - 4)
	assert_int(s.hero_status("regen")).is_equal(1)
	assert_int(s.hero_status("poison")).is_equal(3)
	assert_int(s.hero_status("vigil")).is_equal(3)
	assert_int(s.hero_status("knell")).is_equal(5)
	assert_int(s.enemies[0].hp).is_equal(9)
	assert_int(s.enemies[1].hp).is_equal(9)


func test_hero_turn_start_can_keep_block() -> void:
	var s := TestFixtures.bare_state()
	s.hero_block = 3
	StatusSystem.hero_turn_start(s, false)
	assert_int(s.hero_block).is_equal(3)


func test_poison_ignores_block_and_can_kill_hero() -> void:
	var s := TestFixtures.bare_state()
	s.hero_block = 100
	s.hero_hp = 2
	s.statuses = {"poison": 2}
	StatusSystem.hero_turn_start(s, false)
	assert_int(s.hero_hp).is_equal(0)
	assert_int(s.hero_status("poison")).is_equal(1)


func test_hero_turn_end_burn_and_decays() -> void:
	var s := TestFixtures.bare_state()
	s.hero_hp = 50
	s.statuses = {"burn": 3, "weak": 1, "vulnerable": 2, "bleed": 1, "might_buff": 2, "thorns": 1}
	StatusSystem.hero_turn_end(s)
	assert_int(s.hero_hp).is_equal(47)
	assert_int(s.hero_status("burn")).is_equal(2)
	assert_int(s.hero_status("weak")).is_equal(0)
	assert_bool(s.statuses.has("weak")).is_false()
	assert_int(s.hero_status("vulnerable")).is_equal(1)
	assert_int(s.hero_status("bleed")).is_equal(0)
	assert_int(s.hero_status("might_buff")).is_equal(2)
	assert_int(s.hero_status("thorns")).is_equal(1)


func test_enemy_turn_start_resets_block_poison_regen() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	var e := s.enemies[0]
	e.block = 6
	e.hp = 10
	e.statuses = {"poison": 3, "regen": 2}
	StatusSystem.enemy_turn_start(s, 0)
	assert_int(e.block).is_equal(0)
	assert_int(e.hp).is_equal(10 - 3 + 2)
	assert_int(e.status("poison")).is_equal(2)
	assert_int(e.status("regen")).is_equal(1)


func test_enemy_poison_can_kill() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].hp = 3
	s.enemies[0].statuses = {"poison": 3}
	StatusSystem.enemy_turn_start(s, 0)
	assert_bool(s.enemies[0].alive).is_false()
	assert_array(TestFixtures.events_of(s, "enemy_died")).has_size(1)


func test_enemy_turn_end_burn_and_decays() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	var e := s.enemies[0]
	e.statuses = {"burn": 2, "weak": 2, "vulnerable": 1, "bleed": 3, "might_buff": 1}
	StatusSystem.enemy_turn_end(s, 0)
	assert_int(e.hp).is_equal(22)
	assert_int(e.status("burn")).is_equal(1)
	assert_int(e.status("weak")).is_equal(1)
	assert_int(e.status("vulnerable")).is_equal(0)
	assert_int(e.status("bleed")).is_equal(2)
	assert_int(e.status("might_buff")).is_equal(1)


func test_status_tick_events() -> void:
	var s := TestFixtures.bare_state()
	s.statuses = {"poison": 2, "burn": 1}
	StatusSystem.hero_turn_start(s, false)
	StatusSystem.hero_turn_end(s)
	var ticks := TestFixtures.events_of(s, "status_tick")
	assert_array(ticks).has_size(2)
	assert_str(ticks[0]["status"]).is_equal("poison")
	assert_str(ticks[1]["status"]).is_equal("burn")


func test_dead_enemy_is_skipped() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].alive = false
	s.enemies[0].statuses = {"poison": 5}
	StatusSystem.enemy_turn_start(s, 0)
	StatusSystem.enemy_turn_end(s, 0)
	assert_array(TestFixtures.events_of(s, "status_tick")).is_empty()


func test_decay_helper() -> void:
	var d := {"weak": 1, "burn": 3}
	StatusSystem.decay(d, "weak")
	StatusSystem.decay(d, "burn")
	StatusSystem.decay(d, "missing")
	assert_bool(d.has("weak")).is_false()
	assert_int(d["burn"]).is_equal(2)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/combat`
Expected: FAIL — `StatusSystem` not found.

- [ ] **Step 3: Implement `core/combat/status_system.gd`**

```gdscript
class_name StatusSystem
extends RefCounted
## Start/end-of-turn status processing for hero and enemies.


static func decay(statuses: Dictionary, name: String) -> void:
	if not statuses.has(name):
		return
	var left := int(statuses[name]) - 1
	if left <= 0:
		statuses.erase(name)
	else:
		statuses[name] = left


static func hero_turn_start(s: FightState, reset_block: bool) -> void:
	if reset_block:
		s.hero_block = 0
	var vigil := s.hero_status("vigil")
	if vigil > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "vigil", "amount": vigil})
		s.hero_block += vigil
		s.emit({"type": "block_gained", "target": "hero", "amount": vigil})
	var regen := s.hero_status("regen")
	if regen > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "regen", "amount": regen})
		EffectResolver.heal_hero(s, regen)
		decay(s.statuses, "regen")
	var poison := s.hero_status("poison")
	if poison > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "poison", "amount": poison})
		EffectResolver.direct_damage_hero(s, poison, "poison")
		decay(s.statuses, "poison")
	var knell := s.hero_status("knell")
	if knell > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "knell", "amount": knell})
		for i in s.living_enemy_indices():
			EffectResolver.direct_damage_enemy(s, i, knell, "knell")


static func hero_turn_end(s: FightState) -> void:
	var burn := s.hero_status("burn")
	if burn > 0:
		s.emit({"type": "status_tick", "target": "hero", "status": "burn", "amount": burn})
		EffectResolver.direct_damage_hero(s, burn, "burn")
		decay(s.statuses, "burn")
	decay(s.statuses, "weak")
	decay(s.statuses, "vulnerable")
	decay(s.statuses, "bleed")


static func enemy_turn_start(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	e.block = 0
	var poison := e.status("poison")
	if poison > 0:
		s.emit({"type": "status_tick", "target": "enemy", "index": index, "status": "poison", "amount": poison})
		EffectResolver.direct_damage_enemy(s, index, poison, "poison")
		decay(e.statuses, "poison")
	if not e.alive:
		return
	var regen := e.status("regen")
	if regen > 0:
		s.emit({"type": "status_tick", "target": "enemy", "index": index, "status": "regen", "amount": regen})
		e.hp = mini(e.max_hp, e.hp + regen)
		s.emit({"type": "heal", "target": "enemy", "index": index, "amount": regen, "hp": e.hp})
		decay(e.statuses, "regen")


static func enemy_turn_end(s: FightState, index: int) -> void:
	var e := s.enemies[index]
	if not e.alive:
		return
	var burn := e.status("burn")
	if burn > 0:
		s.emit({"type": "status_tick", "target": "enemy", "index": index, "status": "burn", "amount": burn})
		EffectResolver.direct_damage_enemy(s, index, burn, "burn")
		decay(e.statuses, "burn")
	decay(e.statuses, "weak")
	decay(e.statuses, "vulnerable")
	decay(e.statuses, "bleed")
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/combat`
Expected: PASS — 51 test cases, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/combat/status_system.gd tests/core/combat/status_test.gd
git commit -m "feat(combat): status ticks and decay for hero and enemies"
```

---

### Task 10: Combat engine — start, legal actions, play, end turn

**Files:**
- Create: `core/combat/combat_engine.gd`
- Test: `tests/core/combat/turn_flow_test.gd`

**Interfaces:**
- Consumes: everything from Tasks 6–9.
- Produces (static on `CombatEngine`):
  - `start_fight(content: Content, hero: HeroSnapshot, enemy_ids: Array, floor: int, rng: Rng) -> FightState` — builds the state, spawns enemies (with intents), fires `on_fight_start`, begins turn 1 (block from relics survives turn 1).
  - `legal_actions(s: FightState) -> Array` of `{"kind": "play", "hand_index": int, "target": int}` (one per living enemy for enemy-targeted cards, `target` -1 otherwise) plus `{"kind": "end_turn"}`; empty when the fight is over. X-cost cards are always affordable.
  - `apply(s: FightState, action: Dictionary) -> Array` — performs the action, returns the events it produced; no-op (empty array) when the fight is over.
  - Turn order inside `end_turn`: `hero_turn_end` → discard hand → for each living enemy: `enemy_turn_start` → `execute_move` → `enemy_turn_end` → choose next moves → turn cap check → `begin_player_turn` (`turn += 1`, `hero_turn_start(reset_block = turn > 1)`, `on_turn_start` relics, energy refilled, draw).
  - Events: `fight_start {floor}`, `turn_start {turn}`, `turn_end {turn}`, `card_played {uid, card, target, cost}`, `card_exhausted {uid, card}`, `fight_won {turns, hp}`, `fight_lost {reason: "hero_died"|"turn_cap"}`.
  - Bleed on the hero deals its stacks as direct damage once per Attack card played.

- [ ] **Step 1: Write the failing tests**

`tests/core/combat/turn_flow_test.gd`:

```gdscript
extends GdUnitTestSuite


func _start(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1, relics: Array = []) -> FightState:
	var hero := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	if not relics.is_empty():
		hero.relics.clear()
		for r in relics:
			hero.relics.append(String(r))
	return CombatEngine.start_fight(TestFixtures.content(), hero, enemy_ids, floor, Rng.new(seed))


func _play(s: FightState, def_id: String, target: int = -1) -> Array:
	for i in s.hand.size():
		if s.hand[i].def_id == def_id:
			return CombatEngine.apply(s, {"kind": "play", "hand_index": i, "target": target})
	fail("card not in hand: " + def_id)
	return []


func _end(s: FightState) -> Array:
	return CombatEngine.apply(s, {"kind": "end_turn"})


func test_start_fight_sets_up_turn_one() -> void:
	var s := _start()
	assert_str(s.phase).is_equal("player")
	assert_int(s.turn).is_equal(1)
	assert_int(s.energy).is_equal(3)
	assert_int(s.hero_block).is_equal(3)
	assert_array(s.hand).has_size(5)
	assert_array(s.draw_pile).has_size(5)
	assert_str(s.enemies[0].next_move).is_not_equal("")
	assert_array(TestFixtures.events_of(s, "fight_start")).has_size(1)
	assert_array(TestFixtures.events_of(s, "relic_triggered")).has_size(1)
	assert_array(TestFixtures.events_of(s, "turn_start")).has_size(1)
	assert_array(TestFixtures.events_of(s, "card_drawn")).has_size(5)


func test_focus_thresholds_raise_energy_and_draw() -> void:
	var hero := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	hero.stats["focus"] = 6
	var s := CombatEngine.start_fight(TestFixtures.content(), hero, ["bone_rat"], 1, Rng.new(1))
	assert_int(s.max_energy).is_equal(4)
	assert_int(s.energy).is_equal(4)
	assert_int(s.draw_per_turn).is_equal(6)
	assert_array(s.hand).has_size(6)


func test_legal_actions_respect_energy_and_targets() -> void:
	var s := _start(["bone_rat", "bone_rat"])
	TestFixtures.give_hand(s, ["strike", "brace", "bone_wall", "reaping"])
	s.energy = 1
	assert_array(CombatEngine.legal_actions(s)).has_size(4)
	s.energy = 3
	assert_array(CombatEngine.legal_actions(s)).has_size(7)
	s.enemies[1].alive = false
	assert_array(CombatEngine.legal_actions(s)).has_size(5)


func test_play_card_costs_energy_and_discards() -> void:
	var s := _start()
	TestFixtures.give_hand(s, ["strike", "brace"])
	var events := _play(s, "strike", 0)
	assert_int(s.energy).is_equal(2)
	assert_array(s.hand).has_size(1)
	assert_array(s.discard_pile).has_size(1)
	assert_int(s.enemies[0].hp).is_equal(8)
	assert_str(events[0]["type"]).is_equal("card_played")
	assert_int(s.cards_played_this_turn).is_equal(1)


func test_exhaust_and_power_go_to_exhaust_pile() -> void:
	var s := _start()
	TestFixtures.give_hand(s, ["exhume", "vigil"])
	TestFixtures.fill_draw(s, ["strike", "strike"])
	_play(s, "exhume")
	assert_array(s.exhaust_pile).has_size(1)
	assert_array(s.hand).has_size(3)
	_play(s, "vigil")
	assert_array(s.exhaust_pile).has_size(2)
	assert_int(s.hero_status("vigil")).is_equal(3)
	assert_array(TestFixtures.events_of(s, "card_exhausted")).has_size(2)


func test_bleed_hurts_hero_on_attack_cards_only() -> void:
	var s := _start()
	s.statuses["bleed"] = 2
	TestFixtures.give_hand(s, ["strike", "brace"])
	_play(s, "strike", 0)
	assert_int(s.hero_hp).is_equal(68)
	_play(s, "brace")
	assert_int(s.hero_hp).is_equal(68)


func test_end_turn_enemy_acts_and_new_turn_begins() -> void:
	var s := _start(["shambler"])
	assert_str(s.enemies[0].next_move).is_equal("lurch")
	var events := _end(s)
	assert_int(s.hero_hp).is_equal(66)
	assert_int(s.turn).is_equal(2)
	assert_int(s.energy).is_equal(3)
	assert_int(s.hero_block).is_equal(0)
	assert_array(s.hand).has_size(5)
	assert_array(s.discard_pile).has_size(5)
	assert_str(s.enemies[0].next_move).is_equal("lurch")
	var types: Array = []
	for ev in events:
		types.append(ev["type"])
	assert_array(types).contains(["turn_end", "enemy_move", "turn_start"])


func test_win_fires_fight_end_relics_and_stops_play() -> void:
	var s := _start(["bone_rat"], 1, 1, ["ossuary_key"])
	s.hero_hp = 60
	TestFixtures.give_hand(s, ["strike", "strike", "strike"])
	_play(s, "strike", 0)
	_play(s, "strike", 0)
	assert_str(s.phase).is_equal("player")
	_play(s, "strike", 0)
	assert_str(s.phase).is_equal("won")
	assert_int(s.hero_hp).is_equal(64)
	assert_array(TestFixtures.events_of(s, "fight_won")).has_size(1)
	assert_array(CombatEngine.legal_actions(s)).is_empty()
	assert_array(_end(s)).is_empty()


func test_loss_when_hero_dies() -> void:
	var s := _start(["shambler"])
	s.hero_hp = 1
	_end(s)
	assert_str(s.phase).is_equal("lost")
	assert_str(TestFixtures.events_of(s, "fight_lost")[0]["reason"]).is_equal("hero_died")


func test_retain_and_reshuffle_across_turns() -> void:
	var s := _start(["bone_rat"])
	TestFixtures.give_hand(s, ["shroud"])
	s.draw_pile.clear()
	for i in 3:
		s.discard_pile.append(s.new_card("strike"))
	_end(s)
	assert_array(s.hand).has_size(4)
	assert_str(s.hand[0].def_id).is_equal("shroud")
	assert_array(TestFixtures.events_of(s, "reshuffle")).has_size(1)


func test_turn_cap_loses_the_fight() -> void:
	var s := _start(["bone_rat"])
	s.hero_hp = 100000
	s.hero_max_hp = 100000
	s.enemies[0].hp = 1000000
	for i in 40:
		if s.is_over():
			break
		_end(s)
	assert_str(s.phase).is_equal("lost")
	assert_int(s.turn).is_equal(30)
	assert_str(TestFixtures.events_of(s, "fight_lost")[0]["reason"]).is_equal("turn_cap")


func test_summon_during_enemy_turn() -> void:
	var s := _start(["mother_of_bones"])
	assert_str(s.enemies[0].next_move).is_equal("raise")
	_end(s)
	assert_array(s.enemies).has_size(2)
	assert_str(s.enemies[1].def_id).is_equal("bone_rat")


func test_x_cost_spends_all_energy() -> void:
	var content := Content.load_from("res://data")
	content.cards["fx_surge"] = CardDef.from_dict({"id": "fx_surge", "name": "x", "text": "x", "pool": "sexton", "type": "skill", "cost": "x", "rarity": "rare", "tags": ["draw"], "keywords": ["exhaust"], "target": "none", "effects": [{"op": "draw", "amount": "x"}]})
	var hero := HeroSnapshot.starter(content, "sexton")
	var s := CombatEngine.start_fight(content, hero, ["bone_rat"], 1, Rng.new(1))
	s.hand.clear()
	s.hand.append(s.new_card("fx_surge"))
	TestFixtures.fill_draw(s, ["strike", "strike", "strike", "strike"])
	assert_array(CombatEngine.legal_actions(s)).has_size(2)
	_play(s, "fx_surge")
	assert_int(s.energy).is_equal(0)
	assert_array(s.hand).has_size(3)
	assert_array(s.exhaust_pile).has_size(1)


func test_poison_kill_at_enemy_turn_start_wins() -> void:
	var s := _start(["bone_rat"])
	s.enemies[0].hp = 2
	s.enemies[0].statuses["poison"] = 3
	_end(s)
	assert_str(s.phase).is_equal("won")
	assert_int(s.hero_hp).is_equal(70)


func test_dead_target_falls_back_to_living_enemy() -> void:
	var s := _start(["bone_rat", "bone_rat"])
	TestFixtures.give_hand(s, ["strike"])
	s.enemies[0].alive = false
	_play(s, "strike", 0)
	assert_int(s.enemies[1].hp).is_equal(8)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/combat`
Expected: FAIL — `CombatEngine` not found.

- [ ] **Step 3: Implement `core/combat/combat_engine.gd`**

```gdscript
class_name CombatEngine
extends RefCounted
## The rules of a fight. Static functions that mutate a FightState and
## return the events they produced. Pure with respect to the scene tree.


static func start_fight(content: Content, hero: HeroSnapshot, enemy_ids: Array, floor: int, rng: Rng) -> FightState:
	var s := FightState.new()
	s.content = content
	s.rng = rng
	s.floor = floor
	s.hero_hp = hero.hp
	s.hero_max_hp = hero.max_hp
	s.stats = hero.stats.duplicate()
	s.relics = hero.relics.duplicate()
	var focus := int(s.stats.get("focus", 0))
	var balance := content.balance
	s.max_energy = int(balance.get("base_energy", 3)) + _thresholds_met(focus, balance.get("focus_energy_thresholds", []))
	s.draw_per_turn = int(balance.get("base_draw", 5)) + _thresholds_met(focus, balance.get("focus_draw_thresholds", []))
	var max_uid := 0
	for card in hero.deck:
		s.draw_pile.append(card.clone())
		max_uid = maxi(max_uid, card.uid)
	s.next_uid = max_uid + 1000
	s.rng.shuffle("deck", s.draw_pile)
	for enemy_id in enemy_ids:
		EnemyAI.spawn(s, String(enemy_id))
	s.emit({"type": "fight_start", "floor": floor})
	Relics.fire(s, "on_fight_start")
	_begin_player_turn(s)
	return s


static func _thresholds_met(value: int, thresholds: Array) -> int:
	var n := 0
	for t in thresholds:
		if value >= int(t):
			n += 1
	return n


static func legal_actions(s: FightState) -> Array:
	var out: Array = []
	if s.is_over():
		return out
	for i in s.hand.size():
		var card := s.hand[i]
		var def := s.card_def(card)
		var cost := def.cost_for(card.upgraded)
		if cost == CardDef.COST_X:
			cost = 0
		if cost > s.energy:
			continue
		if def.target == "enemy":
			for t in s.living_enemy_indices():
				out.append({"kind": "play", "hand_index": i, "target": t})
		else:
			out.append({"kind": "play", "hand_index": i, "target": -1})
	out.append({"kind": "end_turn"})
	return out


static func apply(s: FightState, action: Dictionary) -> Array:
	if s.is_over():
		return []
	var start := s.events.size()
	match String(action.get("kind", "")):
		"play":
			_play(s, int(action.get("hand_index", -1)), int(action.get("target", -1)))
		"end_turn":
			_end_turn(s)
		_:
			push_error("unknown action kind: " + String(action.get("kind", "")))
	return s.events.slice(start)


static func _play(s: FightState, hand_index: int, target: int) -> void:
	if hand_index < 0 or hand_index >= s.hand.size():
		push_error("play: bad hand index %d" % hand_index)
		return
	var card := s.hand[hand_index]
	var def := s.card_def(card)
	var cost := def.cost_for(card.upgraded)
	var x := 0
	if cost == CardDef.COST_X:
		x = s.energy
		cost = s.energy
	if cost > s.energy:
		push_error("play: cannot afford %s" % card.def_id)
		return
	if def.target == "enemy":
		if target < 0 or target >= s.enemies.size() or not s.enemies[target].alive:
			var living := s.living_enemy_indices()
			if living.is_empty():
				return
			target = living[0]
	s.energy -= cost
	s.hand.remove_at(hand_index)
	s.cards_played_this_turn += 1
	s.emit({"type": "card_played", "uid": card.uid, "card": card.def_id, "target": target, "cost": cost})
	var is_attack := def.type == "attack"
	if is_attack and s.hero_status("bleed") > 0:
		EffectResolver.direct_damage_hero(s, s.hero_status("bleed"), "bleed")
	var ctx := {"target": target, "card_target": def.target, "tags": def.tags, "is_attack": is_attack, "x": x, "exhaust": false}
	EffectResolver.resolve(s, def.effects_for(card.upgraded), {"kind": "hero"}, ctx)
	Relics.fire(s, "on_card_played")
	if def.type == "power" or def.has_keyword("exhaust") or bool(ctx.get("exhaust", false)):
		s.exhaust_pile.append(card)
		s.emit({"type": "card_exhausted", "uid": card.uid, "card": card.def_id})
	else:
		s.discard_pile.append(card)
	_check_end(s)


static func _end_turn(s: FightState) -> void:
	s.emit({"type": "turn_end", "turn": s.turn})
	StatusSystem.hero_turn_end(s)
	if _check_end(s):
		return
	s.discard_hand()
	for i in s.enemies.size():
		if not s.enemies[i].alive:
			continue
		StatusSystem.enemy_turn_start(s, i)
		if _check_end(s):
			return
		if not s.enemies[i].alive:
			continue
		EnemyAI.execute_move(s, i)
		if _check_end(s):
			return
		StatusSystem.enemy_turn_end(s, i)
		if _check_end(s):
			return
	for i in s.enemies.size():
		if s.enemies[i].alive and s.enemies[i].next_move == "":
			EnemyAI.choose_next_move(s, i)
	if s.turn >= int(s.content.balance.get("turn_cap", 30)):
		s.phase = "lost"
		s.emit({"type": "fight_lost", "reason": "turn_cap"})
		return
	_begin_player_turn(s)


static func _begin_player_turn(s: FightState) -> void:
	s.turn += 1
	s.cards_played_this_turn = 0
	s.emit({"type": "turn_start", "turn": s.turn})
	StatusSystem.hero_turn_start(s, s.turn > 1)
	if _check_end(s):
		return
	Relics.fire(s, "on_turn_start")
	s.energy = s.max_energy
	s.emit({"type": "energy_changed", "energy": s.energy})
	s.draw(s.draw_per_turn)


static func _check_end(s: FightState) -> bool:
	if s.phase != "player":
		return true
	if s.hero_hp <= 0:
		s.phase = "lost"
		s.emit({"type": "fight_lost", "reason": "hero_died"})
		return true
	if s.all_enemies_dead():
		s.phase = "won"
		Relics.fire(s, "on_fight_end")
		s.emit({"type": "fight_won", "turns": s.turn, "hp": s.hero_hp})
		return true
	return false
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/combat`
Expected: PASS — 66 test cases, 0 failures. If `test_end_turn_enemy_acts_and_new_turn_begins` reports 63 HP instead of 66, block was reset before the enemy attacked — `hero_turn_start` must only reset block when `turn > 1`.

- [ ] **Step 5: Commit**

```bash
git add core/combat/combat_engine.gd tests/core/combat/turn_flow_test.gd
git commit -m "feat(combat): fight engine with play, end turn, win/loss and turn cap"
```

---

### Task 11: Autopilot — one-turn lookahead

**Files:**
- Create: `core/combat/autopilot.gd`
- Test: `tests/core/combat/autopilot_test.gd`

**Interfaces:**
- Consumes: `CombatEngine.legal_actions/apply`, `FightState.clone`, `EnemyAI.intent_of`.
- Produces: `class_name Autopilot` (instance, so weights can vary per ghost later):
  - `var weights: Dictionary` — scoring weights; Plan B's priority rules will adjust these.
  - `const MAX_SEQUENCES := 200`.
  - `choose_turn(s: FightState) -> Array` — the best sequence of `play` actions found, followed by `{"kind": "end_turn"}`. Never mutates `s`.
  - `play_fight(s: FightState) -> Dictionary` — plays until the fight ends; returns `{"won": bool, "turns": int, "hp": int}`.
  - `var last_explored: int` — how many sequences the last `choose_turn` evaluated (for tests and tuning).
  - `static incoming_damage(s: FightState) -> int` — sum of telegraphed attack damage × hits from living enemies.

- [ ] **Step 1: Write the failing tests**

`tests/core/combat/autopilot_test.gd`:

```gdscript
extends GdUnitTestSuite


func _start(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1) -> FightState:
	var hero := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	return CombatEngine.start_fight(TestFixtures.content(), hero, enemy_ids, floor, Rng.new(seed))


func _run_turn(ap: Autopilot, s: FightState) -> void:
	for action in ap.choose_turn(s):
		if s.is_over():
			return
		CombatEngine.apply(s, action)


func test_takes_lethal() -> void:
	var s := _start(["bone_rat"])
	s.enemies[0].hp = 6
	TestFixtures.give_hand(s, ["brace", "brace", "strike"])
	var ap := Autopilot.new()
	var seq := ap.choose_turn(s)
	assert_str(seq[seq.size() - 1]["kind"]).is_equal("end_turn")
	_run_turn(ap, s)
	assert_str(s.phase).is_equal("won")


func test_prefers_full_block_over_chip_damage() -> void:
	var s := _start(["shambler"])
	s.hero_block = 0
	s.enemies[0].next_move = "lurch"
	TestFixtures.give_hand(s, ["brace", "brace", "strike"])
	s.energy = 2
	var ap := Autopilot.new()
	_run_turn(ap, s)
	assert_int(s.hero_hp).is_equal(70)


func test_plays_draw_card_to_find_more_damage() -> void:
	var s := _start(["shambler"])
	s.enemies[0].next_move = "brace"
	TestFixtures.give_hand(s, ["exhume", "strike"])
	TestFixtures.fill_draw(s, ["strike", "strike"])
	var ap := Autopilot.new()
	_run_turn(ap, s)
	assert_int(s.enemies[0].hp).is_equal(24 - 18)


func test_is_deterministic() -> void:
	var a := _start(["bone_rat", "shambler"], 3, 9)
	var b := _start(["bone_rat", "shambler"], 3, 9)
	var ap := Autopilot.new()
	var seq_a := ap.choose_turn(a)
	var seq_b := ap.choose_turn(b)
	assert_array(seq_a).is_equal(seq_b)


func test_choose_turn_does_not_mutate_state() -> void:
	var s := _start(["bone_rat"])
	var hand_before := s.hand.size()
	var energy_before := s.energy
	var events_before := s.events.size()
	Autopilot.new().choose_turn(s)
	assert_int(s.hand.size()).is_equal(hand_before)
	assert_int(s.energy).is_equal(energy_before)
	assert_int(s.events.size()).is_equal(events_before)


func test_search_is_bounded() -> void:
	var s := _start(["bone_rat", "bone_rat", "bone_rat"])
	var ids: Array = []
	for i in 10:
		ids.append("bone_shard")
	TestFixtures.give_hand(s, ids)
	var ap := Autopilot.new()
	ap.choose_turn(s)
	assert_int(ap.last_explored).is_less_equal(Autopilot.MAX_SEQUENCES)
	assert_int(ap.last_explored).is_greater(1)


func test_incoming_damage_reads_intents() -> void:
	var s := _start(["bone_rat", "shambler"])
	s.enemies[0].next_move = "gnaw"
	s.enemies[1].next_move = "brace"
	assert_int(Autopilot.incoming_damage(s)).is_equal(6)


func test_play_fight_wins_easy_fight_quickly() -> void:
	var s := _start(["bone_rat"], 1, 4)
	var result := Autopilot.new().play_fight(s)
	assert_bool(result["won"]).is_true()
	assert_int(result["turns"]).is_less_equal(6)
	assert_int(result["hp"]).is_greater(50)


func test_play_fight_always_terminates() -> void:
	for seed in [1, 2, 3]:
		var s := _start(["ossuary_warden"], 1, seed)
		var result := Autopilot.new().play_fight(s)
		assert_bool(s.is_over()).is_true()
		assert_int(result["turns"]).is_less_equal(30)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/combat`
Expected: FAIL — `Autopilot` not found.

- [ ] **Step 3: Implement `core/combat/autopilot.gd`**

```gdscript
class_name Autopilot
extends RefCounted
## Plays a turn by searching every distinct ordering of playable cards
## (bounded) on cloned states and scoring the result. Used by ghosts,
## projections, Expeditions and the balance simulator. Deterministic.

const MAX_SEQUENCES := 200

var weights: Dictionary = {
	"lethal": 1000.0,
	"damage": 1.0,
	"kill": 25.0,
	"block_useful": 1.2,
	"block_excess": 0.1,
	"unblocked": -3.0,
	"hp_lost": -3.0,
	"heal": 1.0,
	"energy_left": -0.2,
	"ai_value": 0.1,
	"enemy_status": {"poison": 1.5, "vulnerable": 2.0, "weak": 2.0, "burn": 1.0},
	"hero_status": {"might_buff": 3.0, "wit_buff": 2.0, "thorns": 1.0, "vigil": 2.0, "regen": 1.0, "knell": 3.0},
}
var last_explored: int = 0


static func incoming_damage(s: FightState) -> int:
	var total := 0
	for i in s.living_enemy_indices():
		var intent := EnemyAI.intent_of(s, i)
		if String(intent.get("kind", "")) == "attack":
			total += int(intent["damage"]) * int(intent["hits"])
	return total


func choose_turn(s: FightState) -> Array:
	var incoming := incoming_damage(s)
	var best := {"score": -INF, "seq": []}
	var counter := {"n": 0}
	_explore(s, s, [], 0.0, incoming, best, counter)
	last_explored = counter["n"]
	var out: Array = []
	for action in best["seq"]:
		out.append(action)
	out.append({"kind": "end_turn"})
	return out


func play_fight(s: FightState) -> Dictionary:
	while not s.is_over():
		var turn_before := s.turn
		for action in choose_turn(s):
			if s.is_over():
				break
			CombatEngine.apply(s, action)
		if not s.is_over() and s.turn == turn_before:
			push_error("autopilot made no progress; forcing end_turn")
			CombatEngine.apply(s, {"kind": "end_turn"})
	return {"won": s.phase == "won", "turns": s.turn, "hp": maxi(0, s.hero_hp)}


func _explore(start: FightState, s: FightState, seq: Array, ai_sum: float, incoming: int, best: Dictionary, counter: Dictionary) -> void:
	counter["n"] += 1
	var score := _score(start, s, incoming, ai_sum)
	if score > best["score"]:
		best["score"] = score
		best["seq"] = seq.duplicate()
	if s.is_over() or counter["n"] >= MAX_SEQUENCES:
		return
	var seen := {}
	for action in CombatEngine.legal_actions(s):
		if String(action["kind"]) != "play":
			continue
		var card: CardInstance = s.hand[int(action["hand_index"])]
		var key := "%s|%s|%d" % [card.def_id, str(card.upgraded), int(action["target"])]
		if seen.has(key):
			continue
		seen[key] = true
		var next := s.clone()
		CombatEngine.apply(next, action)
		var next_seq := seq.duplicate()
		next_seq.append(action)
		_explore(start, next, next_seq, ai_sum + s.card_def(card).ai_value, incoming, best, counter)
		if counter["n"] >= MAX_SEQUENCES:
			return


func _score(start: FightState, s: FightState, incoming: int, ai_sum: float) -> float:
	var w := weights
	var score := 0.0
	if s.all_enemies_dead():
		score += float(w["lethal"])
	var damage := 0
	var kills := 0
	for i in start.enemies.size():
		var before := start.enemies[i].hp
		var after := s.enemies[i].hp if i < s.enemies.size() else 0
		damage += maxi(0, before - after)
		if start.enemies[i].alive and (i >= s.enemies.size() or not s.enemies[i].alive):
			kills += 1
	score += damage * float(w["damage"]) + kills * float(w["kill"])
	var useful := mini(s.hero_block, incoming)
	var excess := maxi(0, s.hero_block - incoming)
	var unblocked := maxi(0, incoming - s.hero_block)
	if not s.all_enemies_dead():
		score += useful * float(w["block_useful"]) + excess * float(w["block_excess"]) + unblocked * float(w["unblocked"])
	var hp_delta := s.hero_hp - start.hero_hp
	score += (hp_delta * float(w["hp_lost"]) * -1.0) if hp_delta < 0 else hp_delta * float(w["heal"])
	score += s.energy * float(w["energy_left"])
	score += ai_sum * float(w["ai_value"])
	var enemy_w: Dictionary = w["enemy_status"]
	for i in s.living_enemy_indices():
		var before: Dictionary = start.enemies[i].statuses if i < start.enemies.size() else {}
		for status in enemy_w:
			var gained := s.enemies[i].status(status) - int(before.get(status, 0))
			score += maxi(0, gained) * float(enemy_w[status])
	var hero_w: Dictionary = w["hero_status"]
	for status in hero_w:
		var gained := s.hero_status(status) - start.hero_status(status)
		score += maxi(0, gained) * float(hero_w[status])
	return score
```

Note on `hp_lost`: the weight is negative and `hp_delta` is negative when HP was lost, so the product is multiplied by −1 to yield a penalty — a 2-HP loss scores −6.

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/combat`
Expected: PASS — 75 test cases, 0 failures. `test_prefers_full_block_over_chip_damage` relies on the default weights: two Braces (10 block against 7 incoming) score 7×1.2 + 3×0.1 + ai 1.0 ≈ 9.7; Strike plus Brace scores 6 + 5×1.2 − 2×3 + ai 1.1 ≈ 7.1. If it fails, check that `incoming_damage` reads the enemy's *telegraphed* move through `intent_of` rather than its last move.

- [ ] **Step 5: Commit**

```bash
git add core/combat/autopilot.gd tests/core/combat/autopilot_test.gd
git commit -m "feat(combat): lookahead autopilot with weighted state scoring"
```

---

### Task 12: Fight simulator and command-line demo

**Files:**
- Create: `core/combat/fight_simulator.gd`
- Create: `tools/fight_demo.gd`
- Test: `tests/core/combat/simulator_test.gd`

**Interfaces:**
- Consumes: `CombatEngine`, `Autopilot`, `HeroSnapshot`, `Rng`.
- Produces:
  - `FightSimulator.simulate(content: Content, hero: HeroSnapshot, enemy_ids: Array, floor: int, seed: int, fights: int, autopilot: Autopilot = null) -> Dictionary` — `{"fights", "wins", "win_rate", "avg_turns" (winning fights), "avg_hp_left" (winning fights), "losses"}`; fight i uses `Rng.new(hash([seed, i]))`.
  - `FightSimulator.simulate_table(content, hero, groups: Array, floor: int, seed: int, fights: int, autopilot: Autopilot = null) -> Dictionary` — same shape; fight i uses `groups[i % groups.size()]`. Plan B's ghost strength uses this with the biome's encounter table.
  - `tools/fight_demo.gd` — `godot --headless --path . -s tools/fight_demo.gd -- [enemy_id ...]` prints the event log of one autopilot fight and a 50-fight summary; exit code 0, or 1 when content fails validation.

- [ ] **Step 1: Write the failing tests**

`tests/core/combat/simulator_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_simulation_is_deterministic() -> void:
	var content := TestFixtures.content()
	var a := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["bone_rat", "bone_rat"], 2, 77, 10)
	var b := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["bone_rat", "bone_rat"], 2, 77, 10)
	assert_dict(a).is_equal(b)
	assert_int(a["fights"]).is_equal(10)


func test_starter_beats_floor_one_rats() -> void:
	var content := TestFixtures.content()
	var r := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["bone_rat"], 1, 5, 20)
	assert_float(r["win_rate"]).is_greater_equal(0.9)
	assert_float(r["avg_turns"]).is_between(1.0, 6.0)
	assert_int(r["wins"] + r["losses"]).is_equal(20)


func test_starter_struggles_against_boss() -> void:
	var content := TestFixtures.content()
	var r := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["mother_of_bones"], 10, 5, 10)
	assert_float(r["win_rate"]).is_less(0.5)


func test_table_cycles_groups_and_hero_is_not_consumed() -> void:
	var content := TestFixtures.content()
	var hero := HeroSnapshot.starter(content, "sexton")
	hero.hp = 40
	var groups: Array = [["bone_rat"], ["shambler"], ["grave_wisp"]]
	var r := FightSimulator.simulate_table(content, hero, groups, 1, 3, 9)
	assert_int(r["fights"]).is_equal(9)
	assert_int(hero.hp).is_equal(40)
	assert_array(hero.deck).has_size(10)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/combat`
Expected: FAIL — `FightSimulator` not found.

- [ ] **Step 3: Implement `core/combat/fight_simulator.gd`**

```gdscript
class_name FightSimulator
extends RefCounted
## Runs many autopilot fights and summarizes them. The hero snapshot is
## cloned per fight, so callers can reuse it.


static func simulate(content: Content, hero: HeroSnapshot, enemy_ids: Array, floor: int, seed: int, fights: int, autopilot: Autopilot = null) -> Dictionary:
	var groups: Array = [enemy_ids]
	return simulate_table(content, hero, groups, floor, seed, fights, autopilot)


static func simulate_table(content: Content, hero: HeroSnapshot, groups: Array, floor: int, seed: int, fights: int, autopilot: Autopilot = null) -> Dictionary:
	var ap := autopilot if autopilot != null else Autopilot.new()
	var wins := 0
	var turns_total := 0
	var hp_total := 0
	for i in fights:
		var group: Array = groups[i % groups.size()]
		var s := CombatEngine.start_fight(content, hero.clone(), group, floor, Rng.new(hash([seed, i])))
		var r := ap.play_fight(s)
		if r["won"]:
			wins += 1
			turns_total += int(r["turns"])
			hp_total += int(r["hp"])
	return {
		"fights": fights,
		"wins": wins,
		"losses": fights - wins,
		"win_rate": (float(wins) / fights) if fights > 0 else 0.0,
		"avg_turns": (float(turns_total) / wins) if wins > 0 else 0.0,
		"avg_hp_left": (float(hp_total) / wins) if wins > 0 else 0.0,
	}
```

- [ ] **Step 4: Write `tools/fight_demo.gd`**

```gdscript
extends SceneTree
## Headless demo: one narrated autopilot fight plus a 50-fight summary.
## Usage: godot --headless --path . -s tools/fight_demo.gd -- [enemy_id ...]


func _init() -> void:
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var enemy_ids: Array = []
	for a in args:
		enemy_ids.append(String(a))
	if enemy_ids.is_empty():
		enemy_ids = ["bone_rat", "bone_rat"]
	for id in enemy_ids:
		if not content.enemies.has(id):
			printerr("unknown enemy: " + String(id))
			quit(1)
			return
	var hero := HeroSnapshot.starter(content, "sexton")
	var s := CombatEngine.start_fight(content, hero, enemy_ids, 1, Rng.new(1))
	var ap := Autopilot.new()
	var result := ap.play_fight(s)
	for ev in s.events:
		print(JSON.stringify(ev))
	print("RESULT won=%s turns=%d hp=%d" % [str(result["won"]), int(result["turns"]), int(result["hp"])])
	var stats := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), enemy_ids, 1, 7, 50)
	print("SIM fights=%d win_rate=%.2f avg_turns=%.1f avg_hp_left=%.1f" % [int(stats["fights"]), float(stats["win_rate"]), float(stats["avg_turns"]), float(stats["avg_hp_left"])])
	quit(0)
```

- [ ] **Step 5: Run the tests and the demo**

Run: `tools\test.cmd tests`
Expected: PASS — every suite green: 113 test cases (2 smoke, 8 rng, 24 content, 79 combat).

Run: `& $env:GODOT_BIN --headless --path . -s tools/fight_demo.gd -- bone_rat shambler`
Expected: a stream of JSON event lines starting with `{"type":"fight_start",...}` and ending with `RESULT won=true ...` and a `SIM ...` line; exit code 0. Then run it with a bad id — `-- dragon` — and confirm `unknown enemy: dragon` with exit code 1.

- [ ] **Step 6: Commit**

```bash
git add core/combat/fight_simulator.gd tools/fight_demo.gd tests/core/combat/simulator_test.gd
git commit -m "feat(combat): fight simulator and headless fight demo"
```

---

## Plan self-review

**Spec coverage (§4, §7 combat content, §8 core/combat):** turn structure, cards, effect ops, statuses, RPG stats with Focus thresholds, classes (Sexton), enemies with patterns/elite/boss/summon, affinity, relics with the six hooks, nodes' combat part, determinism, the lookahead autopilot, the simulator — all have tasks. Not in this plan by design: nodes other than fights (rest, shop, event), rewards, Descent, run state, ghosts, economy, saves (Plan M1-B); priority rules adjusting autopilot weights (M2, the `weights` dictionary is the hook); any UI (Plan M1-C).

**Known simplifications to carry into Plan B:** `on_floor_enter` is a valid hook but nothing fires it yet (the run layer will); `coin` is emitted as an event for the run layer to bank; enemy `regen` is supported but no slice enemy uses it.

**Type consistency:** `FightState.events` is `Array` of `Dictionary`; actions are `Dictionary` with `"kind"`; `hit_enemy/hit_hero` return `int`; `Autopilot.choose_turn` returns `Array` of action dictionaries ending in `end_turn`; `FightSimulator` results use the keys `fights/wins/losses/win_rate/avg_turns/avg_hp_left`; `StatusSystem.hero_turn_start(s, reset_block)` is called with `s.turn > 1` by the engine and with explicit booleans in tests. Expected test counts assume every earlier suite still passes — `tests/core/content` after Tasks 3, 4, 5: 7, 21, 24; `tests/core/combat` after Tasks 6–12: 11, 26, 41, 51, 66, 75, 79; the whole `tests` tree after Task 12: 113.
