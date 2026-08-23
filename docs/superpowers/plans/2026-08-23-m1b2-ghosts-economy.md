# M1-B2: Ghosts, Economy, Onboarding and Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The idle half of Ghost Guild, headless: ghost records built from finished runs with measured-plus-simulated strength, the Ladder with soft-cap saturation and marginal yield, the Soul economy (meta upgrades, echoes, Calls, a minimal Tend, Mend), the Founder and the first-death rite, real-time production with offline catch-up, a versioned JSON save with backups, the three exit-screen numbers, and a balance simulator that asserts the spec's M1 invariants — proven by a headless campaign demo.

**Architecture:** Everything lives in `core/ghosts/`, `core/economy/`, `core/onboarding/`, `core/save/` and `core/campaign.gd` as `RefCounted` data classes operated on by static rule classes, mirroring `RunState`/`RunEngine`. `Campaign` is the single aggregate the UI observes and the save file stores; `CampaignEngine` owns every state transition (new campaign, start/finish a run, purchases, ticks). Ghost strength is computed on placement and on change, never per tick; production is integrated by real time from a cached rate. Everything random derives from `Rng` streams seeded by the campaign, so two campaigns with the same seed and the same player actions are identical. Plan M1-C (UI) follows.

**Tech Stack:** Godot 4.7.2 (GDScript, static typing), GdUnit4 (vendored), JSON content and saves, Git. Consumes M1-A (`Rng`, `Content`, `HeroSnapshot`, `CardInstance`, `FightSimulator.simulate_table`, `Autopilot`) and M1-B1 (`Hero`, `RunState`/`RunEngine`, `RunStats`, `RunAutopilot`, `RunProjection`, `Rewards.soul_for`, `FloorGenerator`), both merged on `main`.

**Spec:** `docs/superpowers/specs/2026-08-21-ghost-guild-design.md` (v2) — this plan implements §3.2's exit numbers, Retreat/Mend and the Soul conversion, §3.3 hero creation with meta stats, §3.4 onboarding (Founder, first death, Take the Watch unlock, free Tend), §5.1–§5.5 (ghost record, strength, soft cap, currencies, echoes/Calls/Tend), §5.8 (production, offline), §5.9 (ten upgrades), §8's `core/ghosts`, `core/economy`, `core/onboarding`, `core/save`, §10's `tools/balance_sim.gd`, and §12's invariants 1, 2, 3 and 5 for floors 1–10. Out of scope by §11: priority rules, Expeditions, hauntings, tending beyond restless, laying to rest, prestige, the Hexer, Steam, localization.

## Global Constraints

- Godot **4.3 or newer** (4.7.2 installed); GDScript with **static typing everywhere** (every `var`, parameter and return typed; `Variant` only where JSON forces it). No typed dictionaries.
- **The simulation core has no Node dependencies.** Nothing under `core/` may `extends Node`, touch the scene tree, or call `get_tree()`. `Time.get_unix_time_from_system()` is never called inside `core/`: every function that needs the clock takes `now: int` (unix seconds) as a parameter so tests and the save loader control time.
- **Determinism:** no `randi()`, `randf()`, `shuffle()` or `pick_random()` in `core/`. Campaign randomness derives from `Rng.new(hash([campaign_seed, tag, counter]))`; ghost strength simulations use `hash([campaign_seed, "strength", ghost_id])`.
- **Engine API shape:** rule functions are static, mutate the aggregate in place and return what they produced (`-> Array` of events for run transitions, `-> Dictionary` results for purchases). Events are Dictionaries with a `"type"` key. **Event payloads are immutable snapshots** — `duplicate()` anything you put in an event or keep as live state (Godot's `Array(from)` aliases).
- **Spec numbers verbatim:** ghost-time turn 10 s, respawn 20 s, lost fight 120 s; `strength = 3600 / E[seconds per kill]`; blend weight `w = n / (n + 3)` on the measurement; 50-fight simulation; `spawn_rate(f) = 60 × 1.08^f`, `soul_per_kill(f) = 1.3^f`; overflow pays 25%; prepared +25%, restless −30%; echo strength `75% × min(source, simulated on the echo floor)`; echo cost `50 × 1.15^(echoes owned)`; Call = 25% of a new echo; upgrade costs `×1.6` per level; offline cap 8 h base; Take the Watch locked until the first death; the campaign's first Tend is free; Resolve max 1, upgradeable to 2 in M1.
- **Content is JSON under `data/`**, every player-facing string a key in `data/strings/en.csv` (no commas inside texts); a validation failure is a test failure. Saves are JSON under `user://saves/` with a `version` field.
- **Repo conventions (`CLAUDE.md`):** commit every `.gd.uid` sidecar; stage explicitly; every commit message ends with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`. Test command: `tools\test.cmd <dir-or-file>` (Git Bash: `cmd //c "tools\\test.cmd tests"`). Starting suite: 188 test cases green.
- **Commit after every task** with the message given in the task. Tests are written before implementation.

---

## File structure

```
core/content/upgrade_def.gd            UpgradeDef (Task 1)
core/content/content.gd                Modify: load data/upgrades (Task 1)
core/content/validator.gd              Modify: UPGRADE_GROUPS, UPGRADE_EFFECTS, _upgrade (Task 1)
data/upgrades/guild.json               10 slice upgrades (Task 1)
data/balance.json, data/strings/en.csv Modify: ghost/economy keys, epitaphs, upgrade strings (Task 1)
tests/fixtures/content_ok/upgrades/upgrades.json, strings/en.csv   fixture upgrade (Task 1)
core/run/floor_generator.gd            Modify: groups_for(biome, floor) (Task 2)
core/ghosts/strength.gd                Strength — ghost-time math, simulation, blend (Task 2)
core/ghosts/ghost.gd                   Ghost — the record, epitaph, serialization (Task 3)
core/ghosts/ladder.gd                  Ladder — ghosts per floor, soft cap, marginal yield, waypoint (Task 4)
core/economy/upgrades.gd               Upgrades — levels, costs, modifiers (Task 5)
core/economy/production.gd             Production — rate and real-time accrual with the offline cap (Task 6)
core/onboarding/onboarding.gd          Onboarding — Founder seeding, first-death rite flags (Task 7)
core/campaign.gd                       Campaign — the aggregate (Task 7)
core/campaign_engine.gd                CampaignEngine — new_campaign, start_run, finish_run, tick (Task 7)
core/economy/seance.gd                 Seance — echoes, Calls, Tend, Mend (Task 8)
core/ghosts/yield_simulator.gd         YieldSimulator — exit-screen numbers (Task 9)
core/save/save_game.gd                 SaveGame — JSON file, backups, migrations, offline summary (Task 10)
tools/balance_sim.gd                   balance simulator asserting §12 invariants 1, 2, 3, 5 (Task 11)
core/economy/balance_sim.gd            BalanceSim — the simulator's logic (Task 11)
tools/campaign_demo.gd                 headless campaign demo (Task 12)
tests/helpers/fixtures.gd              Modify: campaign helpers (Task 7)
tests/core/content/*                   Modify (Task 1)
tests/core/ghosts/strength_test.gd     (Task 2)
tests/core/ghosts/ghost_test.gd        (Task 3)
tests/core/ghosts/ladder_test.gd       (Task 4)
tests/core/economy/upgrades_test.gd    (Task 5)
tests/core/economy/production_test.gd  (Task 6)
tests/core/campaign_test.gd            (Task 7)
tests/core/economy/seance_test.gd      (Task 8)
tests/core/ghosts/yield_test.gd        (Task 9)
tests/core/save/save_game_test.gd      (Task 10)
tests/core/economy/balance_sim_test.gd (Task 11)
```

Responsibilities: `ghosts/` knows what a ghost is worth and how floors pay; `economy/` knows prices, upgrades and time; `onboarding/` knows the first twenty minutes; `campaign.gd` holds everything the save stores; `campaign_engine.gd` is the only thing that mutates a campaign; `save/` reads and writes files — nothing else touches the filesystem.

Modifiers dictionary (produced by `Upgrades.modifiers`, consumed by `Ladder`, `Production`, `Seance`, `CampaignEngine`): `{"global_strength": float multiplier (1.0 base), "global_spawn": float multiplier, "restless_penalty": float (0.3 base), "offline_cap_hours": float (8 base), "mend_discount": float (0 base), "max_resolve_bonus": int, "stats": {might, wit, vigor, focus}}`.

---

### Task 1: Upgrade content, ghost/economy balance keys, epitaph strings

**Files:**
- Create: `core/content/upgrade_def.gd`
- Modify: `core/content/content.gd` (field `upgrades` + `_load_dir`), `core/content/validator.gd` (constants, `_upgrade`, loop)
- Create: `data/upgrades/guild.json`; Modify: `data/balance.json`, `data/strings/en.csv`
- Create: `tests/fixtures/content_ok/upgrades/upgrades.json`; Modify: `tests/fixtures/content_ok/strings/en.csv`
- Test: `tests/core/content/content_test.gd`, `validator_test.gd`, `slice_content_test.gd` (additions)

**Interfaces:**
- Consumes: `Content`, `ContentValidator._key`, `ContentValidator.STATS`.
- Produces: `UpgradeDef` fields `id, name_key, text_key, group ("hero"|"ghosts"|"descent"|"seance"), effect: Dictionary ({"kind", "amount", "stat"?}), max_level: int, base_cost: float, cost_growth: float`; `static from_dict`. `Content.upgrades`. `ContentValidator.UPGRADE_GROUPS := ["hero", "ghosts", "descent", "seance"]`, `UPGRADE_EFFECTS := ["stat", "max_resolve", "mend_discount", "global_strength", "global_spawn", "offline_cap", "restless_penalty"]`. Balance keys (read with defaults by later tasks): `spawn_rate_base 60`, `spawn_rate_growth 1.08`, `overflow_rate 0.25`, `prepared_bonus 0.25`, `restless_penalty 0.3`, `echo_factor 0.75`, `echo_base_cost 50`, `echo_cost_growth 1.15`, `call_cost_factor 0.25`, `tend_base_cost 20`, `tend_cost_growth 1.3`, `mend_base_cost 15`, `mend_cost_growth 1.3`, `offline_cap_hours 8`, `founder_strength 40`, `upgrade_cost_growth 1.6`, `ghost_turn_seconds 10`, `ghost_respawn_seconds 20`, `ghost_loss_seconds 120`, `strength_sim_fights 50`, `strength_blend_k 3`. Upgrade ids used by later tests exactly: `might`, `wit`, `vigor`, `focus`, `resolve`, `mend_discount`, `ghost_strength`, `ghost_spawn`, `offline_cap`, `restless_relief`. String keys: `epitaph.watch`, `epitaph.death`, `epitaph.death_unknown`, `epitaph.founder`, `ghost.founder.name`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/core/content/content_test.gd` (and add the one assertion to `test_loads_all_types_without_errors` after the events assertion: `assert_int(c.upgrades.size()).is_equal(1)`):

```gdscript
func test_upgrade_def_fields() -> void:
	var c := Content.load_from(ROOT)
	var up: UpgradeDef = c.upgrades["fx_might"]
	assert_str(up.group).is_equal("hero")
	assert_str(up.effect["kind"]).is_equal("stat")
	assert_str(up.effect["stat"]).is_equal("might")
	assert_int(up.effect["amount"]).is_equal(1)
	assert_int(up.max_level).is_equal(3)
	assert_float(up.base_cost).is_equal(25.0)
	assert_float(up.cost_growth).is_equal(1.6)
```

Append to `tests/core/content/validator_test.gd`:

```gdscript
func test_upgrade_rules() -> void:
	var c := _ok()
	var up: UpgradeDef = c.upgrades["fx_might"]
	up.group = "cosmic"
	up.effect = {"kind": "teleport", "amount": 1}
	up.max_level = 0
	up.base_cost = 0.0
	assert_int(ContentValidator.validate(c).size()).is_equal(4)


func test_upgrade_stat_effect_needs_a_known_stat() -> void:
	var c := _ok()
	var up: UpgradeDef = c.upgrades["fx_might"]
	up.effect = {"kind": "stat", "stat": "luck", "amount": "lots"}
	assert_int(ContentValidator.validate(c).size()).is_equal(2)
```

In `tests/core/content/slice_content_test.gd`, `test_slice_content_volume`, after the events assertion add:

```gdscript
	assert_int(c.upgrades.size()).is_equal(10)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/content`
Expected: FAIL — parse errors: `UpgradeDef` not declared.

- [ ] **Step 3: Fixture upgrade and strings**

`tests/fixtures/content_ok/upgrades/upgrades.json`:

```json
[
  {"id": "fx_might", "name": "upgrade.fx_might.name", "text": "upgrade.fx_might.text", "group": "hero",
   "effect": {"kind": "stat", "stat": "might", "amount": 1}, "max_level": 3, "base_cost": 25}
]
```

Append to `tests/fixtures/content_ok/strings/en.csv`:

```csv
upgrade.fx_might.name,Fixture Might
upgrade.fx_might.text,+1 Might.
```

- [ ] **Step 4: Implement `core/content/upgrade_def.gd` and extend the loader**

```gdscript
class_name UpgradeDef
extends RefCounted
## A meta upgrade node in the Guild panel (spec §5.9): one effect, levels
## with exponential cost.

var id: String = ""
var name_key: String = ""
var text_key: String = ""
var group: String = "hero"
var effect: Dictionary = {}
var max_level: int = 1
var base_cost: float = 10.0
var cost_growth: float = 1.6


static func from_dict(d: Dictionary) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = String(d.get("id", ""))
	u.name_key = String(d.get("name", ""))
	u.text_key = String(d.get("text", ""))
	u.group = String(d.get("group", "hero"))
	var e: Dictionary = d.get("effect", {})
	u.effect = e.duplicate(true)
	u.max_level = int(d.get("max_level", 1))
	u.base_cost = float(d.get("base_cost", 10.0))
	u.cost_growth = float(d.get("cost_growth", 1.6))
	return u
```

In `core/content/content.gd`: add `var upgrades: Dictionary = {}` after `events`, and in `load_from` after the events `_load_dir` line:

```gdscript
	c._load_dir(root.path_join("upgrades"), func(d: Dictionary) -> void: c.upgrades[d["id"]] = UpgradeDef.from_dict(d))
```

- [ ] **Step 5: Extend the validator**

Add after `const STATS ...`:

```gdscript
const UPGRADE_GROUPS: Array[String] = ["hero", "ghosts", "descent", "seance"]
const UPGRADE_EFFECTS: Array[String] = ["stat", "max_resolve", "mend_discount", "global_strength", "global_spawn", "offline_cap", "restless_penalty"]
```

In `validate`, after the events loop:

```gdscript
	for id in c.upgrades:
		_upgrade(c, c.upgrades[id], errors)
```

Append:

```gdscript
static func _upgrade(c: Content, up: UpgradeDef, errors: Array[String]) -> void:
	var where := "upgrade " + up.id
	if not UPGRADE_GROUPS.has(up.group):
		errors.append("%s: bad group '%s'" % [where, up.group])
	var kind := String(up.effect.get("kind", ""))
	if not UPGRADE_EFFECTS.has(kind):
		errors.append("%s: unknown effect kind '%s'" % [where, kind])
	elif kind == "stat" and not STATS.has(String(up.effect.get("stat", ""))):
		errors.append("%s: unknown stat '%s'" % [where, String(up.effect.get("stat", ""))])
	if not _number(up.effect.get("amount")):
		errors.append("%s: effect needs a numeric amount" % where)
	if up.max_level < 1:
		errors.append("%s: max_level must be at least 1" % where)
	if up.base_cost <= 0.0:
		errors.append("%s: base_cost must be positive" % where)
	_key(c, where, up.name_key, errors)
	_key(c, where, up.text_key, errors)
```

- [ ] **Step 6: Slice upgrades, balance keys, strings**

`data/upgrades/guild.json`:

```json
[
  {"id": "might", "name": "upgrade.might.name", "text": "upgrade.might.text", "group": "hero",
   "effect": {"kind": "stat", "stat": "might", "amount": 1}, "max_level": 3, "base_cost": 25},
  {"id": "wit", "name": "upgrade.wit.name", "text": "upgrade.wit.text", "group": "hero",
   "effect": {"kind": "stat", "stat": "wit", "amount": 1}, "max_level": 3, "base_cost": 25},
  {"id": "vigor", "name": "upgrade.vigor.name", "text": "upgrade.vigor.text", "group": "hero",
   "effect": {"kind": "stat", "stat": "vigor", "amount": 1}, "max_level": 3, "base_cost": 20},
  {"id": "focus", "name": "upgrade.focus.name", "text": "upgrade.focus.text", "group": "hero",
   "effect": {"kind": "stat", "stat": "focus", "amount": 1}, "max_level": 3, "base_cost": 40},
  {"id": "resolve", "name": "upgrade.resolve.name", "text": "upgrade.resolve.text", "group": "hero",
   "effect": {"kind": "max_resolve", "amount": 1}, "max_level": 1, "base_cost": 60},
  {"id": "mend_discount", "name": "upgrade.mend_discount.name", "text": "upgrade.mend_discount.text", "group": "hero",
   "effect": {"kind": "mend_discount", "amount": 0.15}, "max_level": 3, "base_cost": 30},
  {"id": "ghost_strength", "name": "upgrade.ghost_strength.name", "text": "upgrade.ghost_strength.text", "group": "ghosts",
   "effect": {"kind": "global_strength", "amount": 0.1}, "max_level": 5, "base_cost": 40},
  {"id": "ghost_spawn", "name": "upgrade.ghost_spawn.name", "text": "upgrade.ghost_spawn.text", "group": "ghosts",
   "effect": {"kind": "global_spawn", "amount": 0.1}, "max_level": 5, "base_cost": 40},
  {"id": "offline_cap", "name": "upgrade.offline_cap.name", "text": "upgrade.offline_cap.text", "group": "ghosts",
   "effect": {"kind": "offline_cap", "amount": 16}, "max_level": 1, "base_cost": 120},
  {"id": "restless_relief", "name": "upgrade.restless_relief.name", "text": "upgrade.restless_relief.text", "group": "ghosts",
   "effect": {"kind": "restless_penalty", "amount": 0.1}, "max_level": 2, "base_cost": 35}
]
```

Append to `data/balance.json` (inside the object, after `"survival_samples": 20` — add the comma):

```json
  "spawn_rate_base": 60,
  "spawn_rate_growth": 1.08,
  "overflow_rate": 0.25,
  "prepared_bonus": 0.25,
  "restless_penalty": 0.3,
  "echo_factor": 0.75,
  "echo_base_cost": 50,
  "echo_cost_growth": 1.15,
  "call_cost_factor": 0.25,
  "tend_base_cost": 20,
  "tend_cost_growth": 1.3,
  "mend_base_cost": 15,
  "mend_cost_growth": 1.3,
  "offline_cap_hours": 8,
  "founder_strength": 40,
  "upgrade_cost_growth": 1.6,
  "ghost_turn_seconds": 10,
  "ghost_respawn_seconds": 20,
  "ghost_loss_seconds": 120,
  "strength_sim_fights": 50,
  "strength_blend_k": 3
```

Append to `data/strings/en.csv`:

```csv
upgrade.might.name,Grave Strength
upgrade.might.text,+1 Might for every new hero.
upgrade.wit.name,Old Rites
upgrade.wit.text,+1 Wit for every new hero.
upgrade.vigor.name,Hardy Stock
upgrade.vigor.text,+1 Vigor for every new hero.
upgrade.focus.name,Lantern Discipline
upgrade.focus.text,+1 Focus for every new hero.
upgrade.resolve.name,Second Thoughts
upgrade.resolve.text,+1 max Resolve. Retreat twice per hero.
upgrade.mend_discount.name,Guild Surgeon
upgrade.mend_discount.text,Mend costs 15% less per level.
upgrade.ghost_strength.name,Restless Vigour
upgrade.ghost_strength.text,All ghosts are 10% stronger per level.
upgrade.ghost_spawn.name,Deeper Burrows
upgrade.ghost_spawn.text,Every floor spawns 10% more per level.
upgrade.offline_cap.name,Night Watch
upgrade.offline_cap.text,Ghosts keep farming for 24 hours while you are away.
upgrade.restless_relief.name,Kind Words
upgrade.restless_relief.text,Restless ghosts lose 10% less per level.
epitaph.watch,{name} took the watch on Floor {floor}
epitaph.death,{name} fell to {killer} on Floor {floor}
epitaph.death_unknown,{name} fell on Floor {floor}
epitaph.founder,{name} founded the guild and holds Floor {floor}
ghost.founder.name,Ilse
```

- [ ] **Step 7: Run to verify they pass**

Run: `tools\test.cmd tests/core/content`
Expected: PASS — 31 test cases, 0 failures. Then `tools\test.cmd tests` — 191 test cases, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add core/content/upgrade_def.gd core/content/upgrade_def.gd.uid core/content/content.gd core/content/validator.gd data/upgrades data/balance.json data/strings/en.csv tests/fixtures/content_ok/upgrades tests/fixtures/content_ok/strings/en.csv tests/core/content
git commit -m "feat(content): meta upgrades, ghost and economy balance keys, epitaph strings"
```

---

### Task 2: Strength — ghost-time math, simulation and the measured/simulated blend

**Files:**
- Modify: `core/run/floor_generator.gd` (add `groups_for`, make `encounter_for` use it)
- Create: `core/ghosts/strength.gd`
- Test: `tests/core/ghosts/strength_test.gd`

**Interfaces:**
- Consumes: `FightSimulator.simulate_table(content, hero, groups, floor, seed, fights, autopilot)` → `{fights, wins, win_rate, avg_turns, ...}`; `BiomeDef.encounters`; balance keys from Task 1.
- Produces:
  - `FloorGenerator.groups_for(biome, floor) -> Array` — the encounter groups of the bucket containing `floor` (last bucket as fallback), a deep copy.
  - `Strength.seconds_per_kill(win_rate: float, avg_turns: float, balance) -> float` — `(avg_turns × turn + respawn) / p + (1 − p) / p × loss`; `INF` when `p <= 0`.
  - `Strength.from_stats(win_rate, avg_turns, balance) -> float` — `3600 / seconds_per_kill`, `0.0` when the win rate is 0.
  - `Strength.simulate(content, snapshot: HeroSnapshot, biome, floor, seed, fights = -1) -> Dictionary` `{fights, wins, win_rate, avg_turns}` over the floor's encounter table (`fights` −1 = balance `strength_sim_fights`).
  - `Strength.blend(measured: Dictionary, simulated: Dictionary, balance) -> Dictionary` `{win_rate, avg_turns, weight}` with `w = n / (n + k)`, `n = measured.fights`; when the measurement has no wins its `avg_turns` is ignored (the simulated one is used).
  - `Strength.of_ghost_stats(measured, simulated, balance) -> float` — `from_stats(blend(...))`.

- [ ] **Step 1: Write the failing tests**

`tests/core/ghosts/strength_test.gd`:

```gdscript
extends GdUnitTestSuite


func _balance() -> Dictionary:
	return TestFixtures.content().balance


func test_seconds_per_kill_and_strength() -> void:
	assert_float(Strength.seconds_per_kill(1.0, 4.0, _balance())).is_equal_approx(60.0, 0.0001)
	assert_float(Strength.from_stats(1.0, 4.0, _balance())).is_equal_approx(60.0, 0.0001)
	assert_float(Strength.seconds_per_kill(0.5, 4.0, _balance())).is_equal_approx(240.0, 0.0001)
	assert_float(Strength.from_stats(0.5, 4.0, _balance())).is_equal_approx(15.0, 0.0001)
	assert_float(Strength.from_stats(0.0, 4.0, _balance())).is_equal(0.0)
	assert_bool(is_inf(Strength.seconds_per_kill(0.0, 4.0, _balance()))).is_true()


func test_blend_weights_by_sample_size() -> void:
	var measured := {"fights": 2, "wins": 2, "win_rate": 1.0, "avg_turns": 4.0}
	var simulated := {"fights": 50, "wins": 25, "win_rate": 0.5, "avg_turns": 6.0}
	var b := Strength.blend(measured, simulated, _balance())
	assert_float(b["weight"]).is_equal_approx(0.4, 0.0001)
	assert_float(b["win_rate"]).is_equal_approx(0.7, 0.0001)
	assert_float(b["avg_turns"]).is_equal_approx(5.2, 0.0001)
	var none := Strength.blend({"fights": 0, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}, simulated, _balance())
	assert_float(none["weight"]).is_equal(0.0)
	assert_float(none["win_rate"]).is_equal_approx(0.5, 0.0001)


func test_blend_ignores_measured_turns_without_wins() -> void:
	var measured := {"fights": 3, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}
	var simulated := {"fights": 50, "wins": 50, "win_rate": 1.0, "avg_turns": 5.0}
	var b := Strength.blend(measured, simulated, _balance())
	assert_float(b["weight"]).is_equal_approx(0.5, 0.0001)
	assert_float(b["win_rate"]).is_equal_approx(0.5, 0.0001)
	assert_float(b["avg_turns"]).is_equal_approx(5.0, 0.0001)
	assert_float(Strength.of_ghost_stats(measured, simulated, _balance())).is_equal_approx(3600.0 / 260.0, 0.001)


func test_groups_for_reads_the_right_bucket() -> void:
	var biome: BiomeDef = TestFixtures.content().biomes["catacombs"]
	assert_array(FloorGenerator.groups_for(biome, 2)).has_size(4)
	assert_array(FloorGenerator.groups_for(biome, 5)[1]).is_equal(["skull_stack"])
	assert_array(FloorGenerator.groups_for(biome, 12)[0]).is_equal(["hollow_knight"])
	var groups := FloorGenerator.groups_for(biome, 1)
	groups[0].append("ghoul")
	assert_array(FloorGenerator.groups_for(biome, 1)[0]).is_equal(["bone_rat"])


func test_simulate_is_deterministic_and_sane() -> void:
	var content := TestFixtures.content()
	var biome: BiomeDef = content.biomes["catacombs"]
	var snap := TestFixtures.hero().snapshot()
	var a := Strength.simulate(content, snap, biome, 1, 7, 10)
	var b := Strength.simulate(content, snap, biome, 1, 7, 10)
	assert_dict(a).is_equal(b)
	assert_int(a["fights"]).is_equal(10)
	assert_float(a["win_rate"]).is_greater_equal(0.5)
	assert_float(a["avg_turns"]).is_between(1.0, 30.0)
	var deep := Strength.simulate(content, snap, biome, 10, 7, 4)
	assert_float(deep["win_rate"]).is_less_equal(a["win_rate"])
	assert_int(Strength.simulate(content, snap, biome, 1, 7)["fights"]).is_equal(50)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/ghosts`
Expected: FAIL — `Strength` not declared.

- [ ] **Step 3: Add `groups_for` to `core/run/floor_generator.gd`**

Replace the body of `encounter_for` and add the helper:

```gdscript
static func groups_for(biome: BiomeDef, floor: int) -> Array:
	var groups: Array = []
	for bucket in biome.encounters:
		var span: Array = bucket.get("floors", [1, 1])
		if floor >= int(span[0]) and floor <= int(span[1]):
			groups = bucket.get("groups", [])
			break
	if groups.is_empty() and not biome.encounters.is_empty():
		var last: Dictionary = biome.encounters[biome.encounters.size() - 1]
		groups = last.get("groups", [])
	return groups.duplicate(true)


static func encounter_for(biome: BiomeDef, floor: int, rng: Rng) -> Array:
	var groups := groups_for(biome, floor)
	var group: Array = groups[rng.randi_range("encounter", 0, groups.size() - 1)]
	return group.duplicate()
```

- [ ] **Step 4: Implement `core/ghosts/strength.gd`**

```gdscript
class_name Strength
extends RefCounted
## Ghost strength in kills per hour (spec §5.2): ghost-time per kill from a
## win rate and an average fight length, measured stats blended with a
## simulation by sample size. Never called per tick.


static func seconds_per_kill(win_rate: float, avg_turns: float, balance: Dictionary) -> float:
	if win_rate <= 0.0:
		return INF
	var turn := float(balance.get("ghost_turn_seconds", 10))
	var respawn := float(balance.get("ghost_respawn_seconds", 20))
	var loss := float(balance.get("ghost_loss_seconds", 120))
	return (avg_turns * turn + respawn) / win_rate + (1.0 - win_rate) / win_rate * loss


static func from_stats(win_rate: float, avg_turns: float, balance: Dictionary) -> float:
	var seconds := seconds_per_kill(win_rate, avg_turns, balance)
	if is_inf(seconds) or seconds <= 0.0:
		return 0.0
	return 3600.0 / seconds


static func simulate(content: Content, snapshot: HeroSnapshot, biome: BiomeDef, floor: int, seed_value: int, fights: int = -1) -> Dictionary:
	var n := fights if fights > 0 else int(content.balance.get("strength_sim_fights", 50))
	var groups := FloorGenerator.groups_for(biome, floor)
	var r := FightSimulator.simulate_table(content, snapshot, groups, floor, seed_value, n)
	return {"fights": int(r["fights"]), "wins": int(r["wins"]), "win_rate": float(r["win_rate"]), "avg_turns": float(r["avg_turns"])}


static func blend(measured: Dictionary, simulated: Dictionary, balance: Dictionary) -> Dictionary:
	var n := float(measured.get("fights", 0))
	var k := float(balance.get("strength_blend_k", 3))
	var w := n / (n + k) if n > 0.0 else 0.0
	var sim_rate := float(simulated.get("win_rate", 0.0))
	var sim_turns := float(simulated.get("avg_turns", 0.0))
	var win_rate := w * float(measured.get("win_rate", 0.0)) + (1.0 - w) * sim_rate
	var avg_turns := sim_turns
	if int(measured.get("wins", 0)) > 0:
		avg_turns = w * float(measured.get("avg_turns", 0.0)) + (1.0 - w) * sim_turns
	return {"win_rate": win_rate, "avg_turns": avg_turns, "weight": w}


static func of_ghost_stats(measured: Dictionary, simulated: Dictionary, balance: Dictionary) -> float:
	var b := blend(measured, simulated, balance)
	return from_stats(float(b["win_rate"]), float(b["avg_turns"]), balance)
```

- [ ] **Step 5: Run to verify they pass**

Run: `tools\test.cmd tests/core/ghosts` — PASS, 5 test cases. Then `tools\test.cmd tests/core/run` — the floor generator tests still pass (22 of the run suite's 64).
Expected totals: `tests` — 196 test cases, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add core/run/floor_generator.gd core/ghosts/strength.gd core/ghosts/strength.gd.uid tests/core/ghosts/strength_test.gd tests/core/ghosts/strength_test.gd.uid
git commit -m "feat(ghosts): ghost strength from ghost-time, simulation and the measured blend"
```

---

### Task 3: Ghost — the record, epitaph and serialization

**Files:**
- Create: `core/ghosts/ghost.gd`
- Test: `tests/core/ghosts/ghost_test.gd`

**Interfaces:**
- Consumes: `Hero` (deck/relics/stats/name/class_id), `CardInstance`, `HeroSnapshot`, `Content.text`, `Content.enemies[id].name_key`, run `outcome` (`kind`, `floor`, `killer`, `cause`, `stat_bonus`), `RunStats.measured(floor)`.
- Produces: `Ghost` fields `id: int`, `name`, `class_id`, `deck: Array[CardInstance]`, `relics: Array[String]`, `stats: Dictionary`, `max_hp: int`, `floor: int`, `kind ("true"|"echo")`, `source_id: int` (echo → source ghost id, else 0), `cause ("watch"|"death"|"founder")`, `killer: String`, `prepared: bool`, `restless: bool`, `created_at: int`, `epitaph_key: String`, `measured: Dictionary`, `strength: float` (base, before multipliers), `fixed_strength: bool` (Founder); `static from_run(hero: Hero, outcome: Dictionary, measured: Dictionary, created_at: int) -> Ghost` (watch → prepared, death → restless; stats = hero stats + outcome stat_bonus; deck cloned; `id` 0 until the Ladder assigns it); `static founder(content, created_at) -> Ghost` (Sexton starting deck, floor 1, `cause "founder"`, `fixed_strength` true with balance `founder_strength`, name from `ghost.founder.name`); `snapshot() -> HeroSnapshot` (full HP); `epitaph(content) -> String`; `clone_as_echo(floor, created_at) -> Ghost` (an echo inherits `restless` from its source — spec §5.5 ties echoes to their source, and Tend clears both; it is never `prepared`); `to_dict()`, `static from_dict(d)`.

- [ ] **Step 1: Write the failing tests**

`tests/core/ghosts/ghost_test.gd`:

```gdscript
extends GdUnitTestSuite


func _outcome(kind: String, floor: int, killer: String = "", cause: String = "") -> Dictionary:
	return {"kind": kind, "floor": floor, "killer": killer, "cause": cause, "coin": 0, "soul_from_coin": 0.0, "soul": 0.0, "hero_hp": 0, "stat_bonus": {"wit": 1}}


func test_ghost_from_a_watch() -> void:
	var hero := TestFixtures.hero("Maren")
	hero.upgrade_card(1)
	hero.relics.append("bone_charm")
	var measured := {"fights": 2, "wins": 2, "win_rate": 1.0, "avg_turns": 4.0}
	var g := Ghost.from_run(hero, _outcome("watch", 4), measured, 1000)
	assert_str(g.name).is_equal("Maren")
	assert_str(g.class_id).is_equal("sexton")
	assert_int(g.floor).is_equal(4)
	assert_str(g.kind).is_equal("true")
	assert_str(g.cause).is_equal("watch")
	assert_bool(g.prepared).is_true()
	assert_bool(g.restless).is_false()
	assert_int(g.created_at).is_equal(1000)
	assert_array(g.deck).has_size(10)
	assert_bool(g.deck[0].upgraded).is_true()
	assert_array(g.relics).is_equal(["sextons_lantern", "bone_charm"])
	assert_int(g.stats["wit"]).is_equal(1)
	assert_int(g.max_hp).is_equal(70)
	assert_dict(g.measured).is_equal(measured)
	assert_str(g.epitaph_key).is_equal("epitaph.watch")
	assert_str(g.epitaph(TestFixtures.content())).is_equal("Maren took the watch on Floor 4")
	hero.deck.clear()
	assert_array(g.deck).has_size(10)


func test_ghost_from_a_death_names_the_killer() -> void:
	var g := Ghost.from_run(TestFixtures.hero("Osk"), _outcome("death", 7, "ossuary_warden", "hero_died"), {"fights": 3, "wins": 2, "win_rate": 0.6667, "avg_turns": 5.0}, 5)
	assert_bool(g.restless).is_true()
	assert_bool(g.prepared).is_false()
	assert_str(g.killer).is_equal("ossuary_warden")
	assert_str(g.epitaph(TestFixtures.content())).is_equal("Osk fell to Ossuary Warden on Floor 7")
	var stalled := Ghost.from_run(TestFixtures.hero("Edda"), _outcome("death", 3, "", "turn_cap"), {"fights": 1, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}, 5)
	assert_str(stalled.epitaph_key).is_equal("epitaph.death_unknown")
	assert_str(stalled.epitaph(TestFixtures.content())).is_equal("Edda fell on Floor 3")


func test_founder() -> void:
	var g := Ghost.founder(TestFixtures.content(), 42)
	assert_str(g.name).is_equal("Ilse")
	assert_int(g.floor).is_equal(1)
	assert_str(g.cause).is_equal("founder")
	assert_bool(g.fixed_strength).is_true()
	assert_float(g.strength).is_equal(40.0)
	assert_array(g.deck).has_size(10)
	assert_str(g.epitaph(TestFixtures.content())).is_equal("Ilse founded the guild and holds Floor 1")
	var snap := g.snapshot()
	assert_int(snap.hp).is_equal(70)
	assert_array(snap.deck).has_size(10)


func test_echo_clone_links_to_its_source() -> void:
	var g := Ghost.from_run(TestFixtures.hero("Wren"), _outcome("watch", 6), {"fights": 1, "wins": 1, "win_rate": 1.0, "avg_turns": 3.0}, 1)
	g.id = 9
	g.strength = 30.0
	var e := g.clone_as_echo(2, 77)
	assert_str(e.kind).is_equal("echo")
	assert_int(e.source_id).is_equal(9)
	assert_int(e.floor).is_equal(2)
	assert_int(e.created_at).is_equal(77)
	assert_bool(e.prepared).is_false()
	assert_bool(e.restless).is_false()
	assert_array(e.deck).has_size(10)
	assert_int(e.id).is_equal(0)
	g.restless = true
	var r := g.clone_as_echo(1, 78)
	assert_bool(r.restless).is_true()
	assert_bool(r.prepared).is_false()


func test_json_round_trip() -> void:
	var hero := TestFixtures.hero("Tobiah")
	hero.upgrade_card(2)
	var g := Ghost.from_run(hero, _outcome("death", 5, "bone_rat", "hero_died"), {"fights": 2, "wins": 1, "win_rate": 0.5, "avg_turns": 6.0}, 123)
	g.id = 3
	g.strength = 12.5
	var back := Ghost.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert_int(back.id).is_equal(3)
	assert_str(back.name).is_equal("Tobiah")
	assert_int(back.floor).is_equal(5)
	assert_str(back.kind).is_equal("true")
	assert_str(back.killer).is_equal("bone_rat")
	assert_bool(back.restless).is_true()
	assert_int(back.created_at).is_equal(123)
	assert_float(back.strength).is_equal(12.5)
	assert_bool(back.deck[1].upgraded).is_true()
	assert_int(back.deck[9].uid).is_equal(10)
	assert_int(back.measured["fights"]).is_equal(2)
	assert_float(back.measured["win_rate"]).is_equal(0.5)
	assert_int(back.stats["wit"]).is_equal(1)
	assert_str(back.epitaph_key).is_equal("epitaph.death")
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/ghosts`
Expected: FAIL — `Ghost` not declared.

- [ ] **Step 3: Implement `core/ghosts/ghost.gd`**

```gdscript
class_name Ghost
extends RefCounted
## A ghost record (spec §5.1): who they were, where they stand, how they
## fought. `strength` is the cached base kills/hour before multipliers.

var id: int = 0
var name: String = ""
var class_id: String = ""
var deck: Array[CardInstance] = []
var relics: Array[String] = []
var stats: Dictionary = {"might": 0, "wit": 0, "vigor": 0, "focus": 0}
var max_hp: int = 1
var floor: int = 1
var kind: String = "true"
var source_id: int = 0
var cause: String = "watch"
var killer: String = ""
var prepared: bool = false
var restless: bool = false
var created_at: int = 0
var epitaph_key: String = ""
var measured: Dictionary = {"fights": 0, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}
var strength: float = 0.0
var fixed_strength: bool = false


static func from_run(hero: Hero, outcome: Dictionary, p_measured: Dictionary, p_created_at: int) -> Ghost:
	var g := Ghost.new()
	g.name = hero.name
	g.class_id = hero.class_id
	for card in hero.deck:
		g.deck.append(card.clone())
	g.relics = hero.relics.duplicate()
	var bonus: Dictionary = outcome.get("stat_bonus", {})
	for key in hero.stats:
		g.stats[key] = int(hero.stats[key]) + int(bonus.get(key, 0))
	g.max_hp = hero.max_hp
	g.floor = int(outcome.get("floor", 1))
	g.kind = "true"
	var outcome_kind := String(outcome.get("kind", "death"))
	g.cause = "watch" if outcome_kind == "watch" else "death"
	g.killer = String(outcome.get("killer", ""))
	g.prepared = g.cause == "watch"
	g.restless = g.cause == "death"
	g.created_at = p_created_at
	g.measured = p_measured.duplicate()
	if g.cause == "watch":
		g.epitaph_key = "epitaph.watch"
	elif g.killer != "":
		g.epitaph_key = "epitaph.death"
	else:
		g.epitaph_key = "epitaph.death_unknown"
	return g


static func founder(content: Content, p_created_at: int) -> Ghost:
	var klass: ClassDef = content.classes["sexton"]
	var g := Ghost.new()
	g.name = content.text("ghost.founder.name")
	g.class_id = klass.id
	var uid := 1
	for card_id in klass.starting_deck:
		g.deck.append(CardInstance.new(uid, card_id, false))
		uid += 1
	g.relics.append(klass.relic)
	for key in klass.stats:
		g.stats[key] = int(klass.stats[key])
	g.max_hp = HeroSnapshot.max_hp_for(klass.base_hp, int(g.stats["vigor"]))
	g.floor = 1
	g.cause = "founder"
	g.created_at = p_created_at
	g.epitaph_key = "epitaph.founder"
	g.strength = float(content.balance.get("founder_strength", 40))
	g.fixed_strength = true
	return g


func snapshot() -> HeroSnapshot:
	var s := HeroSnapshot.new()
	s.class_id = class_id
	for card in deck:
		s.deck.append(card.clone())
	s.relics = relics.duplicate()
	s.stats = stats.duplicate()
	s.max_hp = max_hp
	s.hp = max_hp
	return s


func epitaph(content: Content) -> String:
	var killer_name := ""
	if killer != "" and content.enemies.has(killer):
		var def: EnemyDef = content.enemies[killer]
		killer_name = content.text(def.name_key)
	return content.text(epitaph_key).format({"name": name, "floor": floor, "killer": killer_name})


func clone_as_echo(p_floor: int, p_created_at: int) -> Ghost:
	var e := Ghost.from_dict(to_dict())
	e.id = 0
	e.kind = "echo"
	e.source_id = id
	e.floor = p_floor
	e.prepared = false
	e.restless = restless
	e.created_at = p_created_at
	e.fixed_strength = false
	e.strength = 0.0
	return e


func to_dict() -> Dictionary:
	var cards: Array = []
	for card in deck:
		cards.append(card.to_dict())
	return {
		"id": id, "name": name, "class_id": class_id, "deck": cards, "relics": relics.duplicate(),
		"stats": stats.duplicate(), "max_hp": max_hp, "floor": floor, "kind": kind, "source_id": source_id,
		"cause": cause, "killer": killer, "prepared": prepared, "restless": restless, "created_at": created_at,
		"epitaph_key": epitaph_key, "measured": measured.duplicate(), "strength": strength, "fixed_strength": fixed_strength,
	}


static func from_dict(d: Dictionary) -> Ghost:
	var g := Ghost.new()
	g.id = int(d.get("id", 0))
	g.name = String(d.get("name", ""))
	g.class_id = String(d.get("class_id", ""))
	for raw in d.get("deck", []):
		g.deck.append(CardInstance.from_dict(raw))
	for r in d.get("relics", []):
		g.relics.append(String(r))
	var s: Dictionary = d.get("stats", {})
	for key in ["might", "wit", "vigor", "focus"]:
		g.stats[key] = int(s.get(key, 0))
	g.max_hp = int(d.get("max_hp", 1))
	g.floor = int(d.get("floor", 1))
	g.kind = String(d.get("kind", "true"))
	g.source_id = int(d.get("source_id", 0))
	g.cause = String(d.get("cause", "watch"))
	g.killer = String(d.get("killer", ""))
	g.prepared = bool(d.get("prepared", false))
	g.restless = bool(d.get("restless", false))
	g.created_at = int(d.get("created_at", 0))
	g.epitaph_key = String(d.get("epitaph_key", ""))
	var m: Dictionary = d.get("measured", {})
	g.measured = {"fights": int(m.get("fights", 0)), "wins": int(m.get("wins", 0)), "win_rate": float(m.get("win_rate", 0.0)), "avg_turns": float(m.get("avg_turns", 0.0))}
	g.strength = float(d.get("strength", 0.0))
	g.fixed_strength = bool(d.get("fixed_strength", false))
	return g
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/ghosts`
Expected: PASS — 10 test cases, 0 failures. If the watch epitaph comes out with `{killer}` unreplaced, `String.format` was given a missing key — every key the strings use is always passed.

- [ ] **Step 5: Commit**

```bash
git add core/ghosts/ghost.gd core/ghosts/ghost.gd.uid tests/core/ghosts/ghost_test.gd tests/core/ghosts/ghost_test.gd.uid
git commit -m "feat(ghosts): ghost record with epitaph, founder and echo cloning"
```

---

### Task 4: Ladder — ghosts per floor, soft cap, marginal yield, waypoint

**Files:**
- Create: `core/ghosts/ladder.gd`
- Test: `tests/core/ghosts/ladder_test.gd`

**Interfaces:**
- Consumes: `Ghost`, `Rewards.soul_for`, balance keys `spawn_rate_base`, `spawn_rate_growth`, `overflow_rate`, `prepared_bonus`, `restless_penalty`; the modifiers dictionary (`global_strength`, `global_spawn`, `restless_penalty`).
- Produces: `Ladder` fields `ghosts: Array[Ghost]`, `next_ghost_id: int`; statics `spawn_rate(floor, balance) -> float` (`base × growth^floor`), `soul_per_kill(floor, balance) -> float`, `output_for(total_strength, floor, balance, spawn_mult = 1.0) -> float` (the §5.3 formula), `effective_strength(ghost, balance, modifiers) -> float` (prepared +25%, restless −penalty, × global strength); methods `add(ghost) -> Ghost` (assigns the next id), `find(id) -> Ghost` (null when absent), `remove(id) -> bool`, `on_floor(floor) -> Array[Ghost]`, `floor_strength(floor, balance, modifiers)`, `floor_output(floor, balance, modifiers)`, `saturation(floor, balance, modifiers)` (S / effective spawn rate), `total_output(balance, modifiers)`, `marginal_yield(floor, candidate_strength, balance, modifiers)` (output with minus without), `waypoint() -> int` (deepest floor with a standing `true` ghost, 0 when none), `floors() -> Array[int]` (sorted, distinct), `to_dict()`, `static from_dict(d)`.

- [ ] **Step 1: Write the failing tests**

`tests/core/ghosts/ladder_test.gd`:

```gdscript
extends GdUnitTestSuite


func _balance() -> Dictionary:
	return TestFixtures.content().balance


func _mods() -> Dictionary:
	return {"global_strength": 1.0, "global_spawn": 1.0, "restless_penalty": 0.3}


func _ghost(floor: int, strength: float, prepared: bool = false, restless: bool = false, kind: String = "true") -> Ghost:
	var g := Ghost.new()
	g.name = "G%d" % floor
	g.floor = floor
	g.strength = strength
	g.prepared = prepared
	g.restless = restless
	g.kind = kind
	return g


func test_curves() -> void:
	assert_float(Ladder.spawn_rate(1, _balance())).is_equal_approx(64.8, 0.0001)
	assert_float(Ladder.spawn_rate(10, _balance())).is_equal_approx(129.5382, 0.001)
	assert_float(Ladder.soul_per_kill(1, _balance())).is_equal_approx(1.3, 0.0001)


func test_output_soft_cap() -> void:
	assert_float(Ladder.output_for(40.0, 1, _balance())).is_equal_approx(52.0, 0.0001)
	assert_float(Ladder.output_for(100.0, 1, _balance())).is_equal_approx(95.68, 0.0001)
	assert_float(Ladder.output_for(0.0, 1, _balance())).is_equal(0.0)
	assert_float(Ladder.output_for(100.0, 1, _balance(), 2.0)).is_equal_approx(130.0, 0.0001)


func test_effective_strength_multipliers() -> void:
	assert_float(Ladder.effective_strength(_ghost(1, 30.0, true), _balance(), _mods())).is_equal_approx(37.5, 0.0001)
	assert_float(Ladder.effective_strength(_ghost(1, 30.0, false, true), _balance(), _mods())).is_equal_approx(21.0, 0.0001)
	var mods := {"global_strength": 1.2, "global_spawn": 1.0, "restless_penalty": 0.1}
	assert_float(Ladder.effective_strength(_ghost(1, 30.0, false, true), _balance(), mods)).is_equal_approx(32.4, 0.0001)


func test_add_find_remove_and_floors() -> void:
	var ladder := Ladder.new()
	var a := ladder.add(_ghost(3, 10.0))
	var b := ladder.add(_ghost(1, 5.0))
	assert_int(a.id).is_equal(1)
	assert_int(b.id).is_equal(2)
	assert_int(ladder.next_ghost_id).is_equal(3)
	assert_object(ladder.find(2)).is_same(b)
	assert_object(ladder.find(9)).is_null()
	assert_array(ladder.floors()).is_equal([1, 3])
	assert_array(ladder.on_floor(3)).has_size(1)
	assert_bool(ladder.remove(1)).is_true()
	assert_bool(ladder.remove(1)).is_false()
	assert_array(ladder.ghosts).has_size(1)


func test_floor_math_and_marginal_yield() -> void:
	var ladder := Ladder.new()
	assert_float(ladder.marginal_yield(1, 40.0, _balance(), _mods())).is_equal_approx(52.0, 0.0001)
	ladder.add(_ghost(1, 64.8))
	assert_float(ladder.floor_strength(1, _balance(), _mods())).is_equal_approx(64.8, 0.0001)
	assert_float(ladder.saturation(1, _balance(), _mods())).is_equal_approx(1.0, 0.0001)
	assert_float(ladder.floor_output(1, _balance(), _mods())).is_equal_approx(84.24, 0.0001)
	assert_float(ladder.marginal_yield(1, 40.0, _balance(), _mods())).is_equal_approx(13.0, 0.0001)
	ladder.add(_ghost(3, 20.0))
	assert_float(ladder.total_output(_balance(), _mods())).is_equal_approx(84.24 + 20.0 * 2.197, 0.001)
	var spawny := {"global_strength": 1.0, "global_spawn": 2.0, "restless_penalty": 0.3}
	assert_float(ladder.saturation(1, _balance(), spawny)).is_equal_approx(0.5, 0.0001)


func test_waypoint_counts_true_ghosts_only() -> void:
	var ladder := Ladder.new()
	assert_int(ladder.waypoint()).is_equal(0)
	ladder.add(_ghost(2, 1.0))
	ladder.add(_ghost(6, 1.0, false, false, "echo"))
	assert_int(ladder.waypoint()).is_equal(2)
	ladder.add(_ghost(4, 1.0, true))
	assert_int(ladder.waypoint()).is_equal(4)


func test_round_trip() -> void:
	var ladder := Ladder.new()
	ladder.add(Ghost.founder(TestFixtures.content(), 9))
	ladder.add(_ghost(5, 12.5, true))
	var back := Ladder.from_dict(JSON.parse_string(JSON.stringify(ladder.to_dict())))
	assert_array(back.ghosts).has_size(2)
	assert_int(back.next_ghost_id).is_equal(3)
	assert_str(back.ghosts[0].name).is_equal("Ilse")
	assert_int(back.ghosts[1].id).is_equal(2)
	assert_float(back.ghosts[1].strength).is_equal(12.5)
	assert_int(back.waypoint()).is_equal(5)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/ghosts`
Expected: FAIL — `Ladder` not declared.

- [ ] **Step 3: Implement `core/ghosts/ladder.gd`**

```gdscript
class_name Ladder
extends RefCounted
## Every ghost on every floor and what each floor pays (spec §5.3):
## output/h = min(spawn_rate, S) × soul_per_kill + max(0, S − spawn_rate) × 0.25 × soul_per_kill.

var ghosts: Array[Ghost] = []
var next_ghost_id: int = 1


static func spawn_rate(floor: int, balance: Dictionary) -> float:
	return float(balance.get("spawn_rate_base", 60)) * pow(float(balance.get("spawn_rate_growth", 1.08)), floor)


static func soul_per_kill(floor: int, balance: Dictionary) -> float:
	return Rewards.soul_for(floor, balance)


static func output_for(total_strength: float, floor: int, balance: Dictionary, spawn_mult: float = 1.0) -> float:
	var rate := spawn_rate(floor, balance) * spawn_mult
	var per_kill := soul_per_kill(floor, balance)
	var overflow := float(balance.get("overflow_rate", 0.25))
	return minf(rate, total_strength) * per_kill + maxf(0.0, total_strength - rate) * overflow * per_kill


static func effective_strength(ghost: Ghost, balance: Dictionary, modifiers: Dictionary) -> float:
	var s := ghost.strength
	if ghost.prepared:
		s *= 1.0 + float(balance.get("prepared_bonus", 0.25))
	if ghost.restless:
		s *= 1.0 - float(modifiers.get("restless_penalty", balance.get("restless_penalty", 0.3)))
	return s * float(modifiers.get("global_strength", 1.0))


func add(ghost: Ghost) -> Ghost:
	ghost.id = next_ghost_id
	next_ghost_id += 1
	ghosts.append(ghost)
	return ghost


func find(id: int) -> Ghost:
	for g in ghosts:
		if g.id == id:
			return g
	return null


func remove(id: int) -> bool:
	for i in ghosts.size():
		if ghosts[i].id == id:
			ghosts.remove_at(i)
			return true
	return false


func on_floor(floor: int) -> Array[Ghost]:
	var out: Array[Ghost] = []
	for g in ghosts:
		if g.floor == floor:
			out.append(g)
	return out


func floors() -> Array[int]:
	var seen := {}
	for g in ghosts:
		seen[g.floor] = true
	var out: Array[int] = []
	for f in seen:
		out.append(int(f))
	out.sort()
	return out


func floor_strength(floor: int, balance: Dictionary, modifiers: Dictionary) -> float:
	var total := 0.0
	for g in on_floor(floor):
		total += effective_strength(g, balance, modifiers)
	return total


func floor_output(floor: int, balance: Dictionary, modifiers: Dictionary) -> float:
	return output_for(floor_strength(floor, balance, modifiers), floor, balance, float(modifiers.get("global_spawn", 1.0)))


func saturation(floor: int, balance: Dictionary, modifiers: Dictionary) -> float:
	var rate := spawn_rate(floor, balance) * float(modifiers.get("global_spawn", 1.0))
	return floor_strength(floor, balance, modifiers) / rate if rate > 0.0 else 0.0


func total_output(balance: Dictionary, modifiers: Dictionary) -> float:
	var total := 0.0
	for f in floors():
		total += floor_output(f, balance, modifiers)
	return total


func marginal_yield(floor: int, candidate_strength: float, balance: Dictionary, modifiers: Dictionary) -> float:
	var spawn_mult := float(modifiers.get("global_spawn", 1.0))
	var current := floor_strength(floor, balance, modifiers)
	return output_for(current + candidate_strength, floor, balance, spawn_mult) - output_for(current, floor, balance, spawn_mult)


func waypoint() -> int:
	var deepest := 0
	for g in ghosts:
		if g.kind == "true" and g.floor > deepest:
			deepest = g.floor
	return deepest


func to_dict() -> Dictionary:
	var out: Array = []
	for g in ghosts:
		out.append(g.to_dict())
	return {"ghosts": out, "next_ghost_id": next_ghost_id}


static func from_dict(d: Dictionary) -> Ladder:
	var ladder := Ladder.new()
	for raw in d.get("ghosts", []):
		ladder.ghosts.append(Ghost.from_dict(raw))
	ladder.next_ghost_id = int(d.get("next_ghost_id", 1))
	return ladder
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/ghosts`
Expected: PASS — 17 test cases, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/ghosts/ladder.gd core/ghosts/ladder.gd.uid tests/core/ghosts/ladder_test.gd tests/core/ghosts/ladder_test.gd.uid
git commit -m "feat(ghosts): ladder with soft-cap floor output, marginal yield and waypoint"
```

---

### Task 5: Upgrades — levels, costs and modifiers

**Files:**
- Create: `core/economy/upgrades.gd`
- Test: `tests/core/economy/upgrades_test.gd`

**Interfaces:**
- Consumes: `Content.upgrades` → `UpgradeDef`, balance `restless_penalty`, `offline_cap_hours`.
- Produces: `Upgrades` field `levels: Dictionary` (id → int); `level(id) -> int`; `static cost_at(def, level) -> float` (`base_cost × cost_growth^level`); `cost(content, id) -> float` (next level's price, `-1.0` when unknown or maxed); `can_buy(content, id, soul: float) -> bool`; `buy(content, id) -> float` (increments the level and returns the price paid, `-1.0` when refused — the caller spends the Soul); `modifiers(content) -> Dictionary` exactly the shape in the File structure section (`global_strength` = 1 + Σ, `global_spawn` = 1 + Σ, `restless_penalty` = base − Σ (≥ 0), `offline_cap_hours` = base + Σ, `mend_discount` = Σ capped at 0.9, `max_resolve_bonus` = Σ, `stats` per stat); `to_dict()`, `static from_dict(d)`.

- [ ] **Step 1: Write the failing tests**

`tests/core/economy/upgrades_test.gd`:

```gdscript
extends GdUnitTestSuite


func _content() -> Content:
	return TestFixtures.content()


func test_costs_grow_per_level() -> void:
	var def: UpgradeDef = _content().upgrades["might"]
	assert_float(Upgrades.cost_at(def, 0)).is_equal_approx(25.0, 0.0001)
	assert_float(Upgrades.cost_at(def, 1)).is_equal_approx(40.0, 0.0001)
	assert_float(Upgrades.cost_at(def, 2)).is_equal_approx(64.0, 0.0001)
	var u := Upgrades.new()
	assert_float(u.cost(_content(), "might")).is_equal_approx(25.0, 0.0001)
	assert_float(u.cost(_content(), "nothing")).is_equal(-1.0)


func test_buy_respects_soul_and_max_level() -> void:
	var u := Upgrades.new()
	assert_bool(u.can_buy(_content(), "resolve", 59.0)).is_false()
	assert_bool(u.can_buy(_content(), "resolve", 60.0)).is_true()
	assert_float(u.buy(_content(), "resolve")).is_equal_approx(60.0, 0.0001)
	assert_int(u.level("resolve")).is_equal(1)
	assert_bool(u.can_buy(_content(), "resolve", 100000.0)).is_false()
	assert_float(u.buy(_content(), "resolve")).is_equal(-1.0)
	assert_float(u.cost(_content(), "resolve")).is_equal(-1.0)
	assert_float(u.buy(_content(), "nothing")).is_equal(-1.0)


func test_modifiers_from_levels() -> void:
	var u := Upgrades.new()
	var base := u.modifiers(_content())
	assert_float(base["global_strength"]).is_equal(1.0)
	assert_float(base["global_spawn"]).is_equal(1.0)
	assert_float(base["restless_penalty"]).is_equal_approx(0.3, 0.0001)
	assert_float(base["offline_cap_hours"]).is_equal(8.0)
	assert_float(base["mend_discount"]).is_equal(0.0)
	assert_int(base["max_resolve_bonus"]).is_equal(0)
	assert_int(base["stats"]["might"]).is_equal(0)
	u.levels = {"might": 2, "vigor": 1, "resolve": 1, "ghost_strength": 3, "ghost_spawn": 1, "offline_cap": 1, "restless_relief": 2, "mend_discount": 2}
	var m := u.modifiers(_content())
	assert_int(m["stats"]["might"]).is_equal(2)
	assert_int(m["stats"]["vigor"]).is_equal(1)
	assert_int(m["stats"]["wit"]).is_equal(0)
	assert_int(m["max_resolve_bonus"]).is_equal(1)
	assert_float(m["global_strength"]).is_equal_approx(1.3, 0.0001)
	assert_float(m["global_spawn"]).is_equal_approx(1.1, 0.0001)
	assert_float(m["offline_cap_hours"]).is_equal_approx(24.0, 0.0001)
	assert_float(m["restless_penalty"]).is_equal_approx(0.1, 0.0001)
	assert_float(m["mend_discount"]).is_equal_approx(0.3, 0.0001)


func test_round_trip() -> void:
	var u := Upgrades.new()
	u.buy(_content(), "wit")
	u.buy(_content(), "wit")
	var back := Upgrades.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	assert_int(back.level("wit")).is_equal(2)
	assert_float(back.cost(_content(), "wit")).is_equal_approx(64.0, 0.0001)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/economy`
Expected: FAIL — `Upgrades` not declared.

- [ ] **Step 3: Implement `core/economy/upgrades.gd`**

```gdscript
class_name Upgrades
extends RefCounted
## Meta upgrade levels (spec §5.9) and the modifiers they produce. Prices
## grow ×cost_growth per level; the caller spends the Soul.

var levels: Dictionary = {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


static func cost_at(def: UpgradeDef, p_level: int) -> float:
	return def.base_cost * pow(def.cost_growth, p_level)


func cost(content: Content, id: String) -> float:
	if not content.upgrades.has(id):
		return -1.0
	var def: UpgradeDef = content.upgrades[id]
	if level(id) >= def.max_level:
		return -1.0
	return cost_at(def, level(id))


func can_buy(content: Content, id: String, soul: float) -> bool:
	var price := cost(content, id)
	return price >= 0.0 and soul >= price


func buy(content: Content, id: String) -> float:
	var price := cost(content, id)
	if price < 0.0:
		return -1.0
	levels[id] = level(id) + 1
	return price


func modifiers(content: Content) -> Dictionary:
	var m := {
		"global_strength": 1.0,
		"global_spawn": 1.0,
		"restless_penalty": float(content.balance.get("restless_penalty", 0.3)),
		"offline_cap_hours": float(content.balance.get("offline_cap_hours", 8)),
		"mend_discount": 0.0,
		"max_resolve_bonus": 0,
		"stats": {"might": 0, "wit": 0, "vigor": 0, "focus": 0},
	}
	for id in levels:
		var n := int(levels[id])
		if n <= 0 or not content.upgrades.has(id):
			continue
		var def: UpgradeDef = content.upgrades[id]
		var amount := float(def.effect.get("amount", 0)) * n
		match String(def.effect.get("kind", "")):
			"stat":
				var stat := String(def.effect.get("stat", ""))
				m["stats"][stat] = int(m["stats"].get(stat, 0)) + int(amount)
			"max_resolve":
				m["max_resolve_bonus"] = int(m["max_resolve_bonus"]) + int(amount)
			"mend_discount":
				m["mend_discount"] = minf(0.9, float(m["mend_discount"]) + amount)
			"global_strength":
				m["global_strength"] = float(m["global_strength"]) + amount
			"global_spawn":
				m["global_spawn"] = float(m["global_spawn"]) + amount
			"offline_cap":
				m["offline_cap_hours"] = float(m["offline_cap_hours"]) + amount
			"restless_penalty":
				m["restless_penalty"] = maxf(0.0, float(m["restless_penalty"]) - amount)
	return m


func to_dict() -> Dictionary:
	return {"levels": levels.duplicate()}


static func from_dict(d: Dictionary) -> Upgrades:
	var u := Upgrades.new()
	var raw: Dictionary = d.get("levels", {})
	for id in raw:
		u.levels[String(id)] = int(raw[id])
	return u
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/economy`
Expected: PASS — 4 test cases, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/economy/upgrades.gd core/economy/upgrades.gd.uid tests/core/economy/upgrades_test.gd tests/core/economy/upgrades_test.gd.uid
git commit -m "feat(economy): meta upgrade levels, exponential costs and modifiers"
```

---

### Task 6: Production — rate and real-time accrual with the offline cap

**Files:**
- Create: `core/economy/production.gd`
- Test: `tests/core/economy/production_test.gd`

**Interfaces:**
- Consumes: `Ladder.total_output`.
- Produces: `Production.rate_per_hour(ladder, balance, modifiers) -> float`; `Production.accrue(rate_per_hour: float, elapsed_seconds: int, cap_hours: float) -> Dictionary` `{"elapsed": int (≥ 0), "counted": int (seconds actually paid, ≤ cap), "capped": bool, "soul": float}`. Production is integrated from a cached rate; the campaign (Task 7) stores `rate_per_hour` and `last_tick` and recomputes the rate only when the ladder or modifiers change.

- [ ] **Step 1: Write the failing tests**

`tests/core/economy/production_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_accrue_integrates_real_time() -> void:
	var r := Production.accrue(60.0, 1800, 8.0)
	assert_int(r["elapsed"]).is_equal(1800)
	assert_int(r["counted"]).is_equal(1800)
	assert_bool(r["capped"]).is_false()
	assert_float(r["soul"]).is_equal_approx(30.0, 0.0001)


func test_accrue_caps_offline_time() -> void:
	var r := Production.accrue(10.0, 10 * 3600, 8.0)
	assert_int(r["counted"]).is_equal(8 * 3600)
	assert_bool(r["capped"]).is_true()
	assert_float(r["soul"]).is_equal_approx(80.0, 0.0001)
	var longer := Production.accrue(10.0, 10 * 3600, 24.0)
	assert_bool(longer["capped"]).is_false()
	assert_float(longer["soul"]).is_equal_approx(100.0, 0.0001)


func test_accrue_never_goes_backwards() -> void:
	var r := Production.accrue(60.0, -50, 8.0)
	assert_int(r["elapsed"]).is_equal(0)
	assert_float(r["soul"]).is_equal(0.0)
	assert_float(Production.accrue(0.0, 3600, 8.0)["soul"]).is_equal(0.0)


func test_rate_reads_the_ladder() -> void:
	var ladder := Ladder.new()
	var balance := TestFixtures.content().balance
	var mods := {"global_strength": 1.0, "global_spawn": 1.0, "restless_penalty": 0.3}
	assert_float(Production.rate_per_hour(ladder, balance, mods)).is_equal(0.0)
	ladder.add(Ghost.founder(TestFixtures.content(), 1))
	assert_float(Production.rate_per_hour(ladder, balance, mods)).is_equal_approx(52.0, 0.0001)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/economy`
Expected: FAIL — `Production` not declared.

- [ ] **Step 3: Implement `core/economy/production.gd`**

```gdscript
class_name Production
extends RefCounted
## Soul per hour from the ladder, integrated by real time (spec §5.8):
## rate × elapsed, elapsed capped by the offline cap. Never per frame.


static func rate_per_hour(ladder: Ladder, balance: Dictionary, modifiers: Dictionary) -> float:
	return ladder.total_output(balance, modifiers)


static func accrue(rate: float, elapsed_seconds: int, cap_hours: float) -> Dictionary:
	var elapsed := maxi(0, elapsed_seconds)
	var cap := int(round(cap_hours * 3600.0))
	var counted := mini(elapsed, cap)
	return {
		"elapsed": elapsed,
		"counted": counted,
		"capped": elapsed > counted,
		"soul": rate * counted / 3600.0,
	}
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/economy`
Expected: PASS — 8 test cases, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/economy/production.gd core/economy/production.gd.uid tests/core/economy/production_test.gd tests/core/economy/production_test.gd.uid
git commit -m "feat(economy): production rate and capped real-time accrual"
```

---

### Task 7: Onboarding, Campaign and CampaignEngine — new campaign, heroes, runs, ticks, upgrades

**Files:**
- Create: `core/onboarding/onboarding.gd`, `core/campaign.gd`, `core/campaign_engine.gd`
- Modify: `tests/helpers/fixtures.gd` (append campaign helpers)
- Test: `tests/core/campaign_test.gd`

**Interfaces:**
- Consumes: `Ladder`, `Ghost`, `Strength`, `Upgrades`, `Production`, `Hero`, `RunEngine.start_run`, `RunState.outcome/stats/is_over`, `Rng`.
- Produces:
  - `Onboarding` fields `first_death_seen`, `watch_unlocked`, `free_tend_available` (true), `founder_seeded`; `on_run_end(outcome) -> Array` (events `first_death` and `watch_unlocked` the first time a run ends in death; empty otherwise); `consume_free_tend() -> bool`; `to_dict()`, `static from_dict(d)`.
  - `Campaign` fields `content`, `campaign_seed: int`, `biome_id` ("catacombs"), `ladder: Ladder`, `upgrades: Upgrades`, `onboarding: Onboarding`, `hero: Hero`, `run: RunState` (null between runs), `soul: float`, `record_depth: int`, `hero_counter: int`, `run_counter: int`, `created_at: int`, `last_tick: int`, `rate_per_hour: float`, `sim_fights: int` (−1 = balance; tests set a small number), `events: Array`; methods `emit`, `balance() -> Dictionary`, `biome() -> BiomeDef`, `modifiers() -> Dictionary`, `sub_rng(tag, n) -> Rng`, `spend(cost) -> bool`.
  - `CampaignEngine` statics: `new_campaign(content, campaign_seed, now) -> Campaign` (seeds the Founder on floor 1, creates hero 1, caches the rate; emits `campaign_start`); `new_hero(c, now) -> Hero` (name from `sub_rng("names", hero_counter)`, class `sexton`, meta stats and Resolve from the modifiers; emits `hero_created {id, name}`); `reach(c) -> int` = `max(1, waypoint, hero.camp, record_depth)`; `start_run(c, entry_floor, now) -> RunState` (refuses while a run is in progress or when `entry_floor` is outside `1..min(reach, biome.last_floor)` — returns null; ticks production first; run seed `hash([campaign_seed, "run", run_counter])`; passes `onboarding.watch_unlocked`); `finish_run(c, now) -> Dictionary` `{kind, floor, soul, ghost_id, epitaph, new_hero, rite_events}` (banks `outcome.soul`; `record_depth = max(record_depth, floor cleared)` where a death clears `floor − 1`; death/watch → `Ghost.from_run`, added to the ladder, `strength` computed by `strength_for`, the onboarding rite, and a new hero; retreat keeps the hero; `run` set to null; rate refreshed; emits `ghost_placed {id, floor, strength, epitaph}` and `run_finished`); `strength_for(c, ghost) -> float` (fixed ghosts keep theirs; otherwise `Strength.of_ghost_stats(measured, Strength.simulate(... seed hash([campaign_seed, "strength", ghost.id]), c.sim_fights))`); `refresh_rate(c)`; `tick(c, now) -> Dictionary` (`Production.accrue` since `last_tick` with the offline cap; banks Soul; `last_tick = now`); `buy_upgrade(c, id) -> Dictionary` `{ok, cost, reason}` (spends, levels up, applies a stat/max-Resolve effect to the living hero immediately, refreshes the rate; emits `upgrade_bought`).
  - `TestFixtures.campaign(seed = 1, now = 1000) -> Campaign` (`sim_fights` 4), `TestFixtures.die_on_floor(c, floor, now) -> Dictionary`, `TestFixtures.end_at_exit(c, floor, choice, now) -> Dictionary`, `TestFixtures.campaign_events_of(c, type) -> Array`.

- [ ] **Step 1: Extend the test helper**

Append to `tests/helpers/fixtures.gd`:

```gdscript
static func campaign(campaign_seed: int = 1, now: int = 1000) -> Campaign:
	var c := CampaignEngine.new_campaign(content(), campaign_seed, now)
	c.sim_fights = 4
	return c


static func die_on_floor(c: Campaign, floor: int, now: int) -> Dictionary:
	var run := CampaignEngine.start_run(c, 1, now)
	run.floor = floor
	run.hero.hp = 1
	set_nodes(run, [{"kind": "fight", "enemies": ["shambler", "shambler", "shambler"]}])
	RunEngine.apply(run, {"kind": "enter"})
	autofight(run)
	return CampaignEngine.finish_run(c, now)


static func end_at_exit(c: Campaign, floor: int, choice: String, now: int) -> Dictionary:
	var run := CampaignEngine.start_run(c, 1, now)
	run.floor = floor
	run.watch_unlocked = true
	set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": choice})
	return CampaignEngine.finish_run(c, now)


static func campaign_events_of(c: Campaign, type: String) -> Array:
	var out: Array = []
	for ev in c.events:
		if ev["type"] == type:
			out.append(ev)
	return out
```

- [ ] **Step 2: Write the failing tests**

`tests/core/campaign_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_new_campaign_seeds_the_founder_and_a_hero() -> void:
	var c := TestFixtures.campaign(1, 1000)
	assert_array(c.ladder.ghosts).has_size(1)
	assert_str(c.ladder.ghosts[0].name).is_equal("Ilse")
	assert_int(c.ladder.waypoint()).is_equal(1)
	assert_bool(c.onboarding.founder_seeded).is_true()
	assert_bool(c.onboarding.watch_unlocked).is_false()
	assert_int(c.hero.id).is_equal(1)
	assert_bool(Hero.NAMES.has(c.hero.name)).is_true()
	assert_int(c.hero.resolve).is_equal(1)
	assert_float(c.soul).is_equal(0.0)
	assert_float(c.rate_per_hour).is_equal_approx(52.0, 0.0001)
	assert_int(CampaignEngine.reach(c)).is_equal(1)
	assert_int(c.last_tick).is_equal(1000)
	assert_object(c.run).is_null()
	assert_array(TestFixtures.campaign_events_of(c, "campaign_start")).has_size(1)


func test_same_seed_same_campaign() -> void:
	var a := TestFixtures.campaign(7)
	var b := TestFixtures.campaign(7)
	assert_str(a.hero.name).is_equal(b.hero.name)
	assert_int(a.ladder.ghosts[0].created_at).is_equal(b.ladder.ghosts[0].created_at)


func test_start_run_validates_entry_and_uses_watch_flag() -> void:
	var c := TestFixtures.campaign()
	assert_object(CampaignEngine.start_run(c, 0, 1001)).is_null()
	assert_object(CampaignEngine.start_run(c, 2, 1001)).is_null()
	var run := CampaignEngine.start_run(c, 1, 1001)
	assert_object(run).is_not_null()
	assert_bool(run.watch_unlocked).is_false()
	assert_int(c.run_counter).is_equal(1)
	assert_object(CampaignEngine.start_run(c, 1, 1002)).is_same(run)
	assert_int(c.run_counter).is_equal(1)


func test_death_places_a_restless_ghost_and_replaces_the_hero() -> void:
	var c := TestFixtures.campaign(3, 1000)
	var old_name := c.hero.name
	var result := TestFixtures.die_on_floor(c, 1, 2000)
	assert_str(result["kind"]).is_equal("death")
	assert_int(result["floor"]).is_equal(1)
	assert_bool(result["new_hero"]).is_true()
	assert_array(c.ladder.ghosts).has_size(2)
	var ghost := c.ladder.find(int(result["ghost_id"]))
	assert_str(ghost.name).is_equal(old_name)
	assert_bool(ghost.restless).is_true()
	assert_str(ghost.killer).is_equal("shambler")
	assert_str(result["epitaph"]).is_equal("%s fell to Shambler on Floor 1" % old_name)
	assert_float(ghost.strength).is_greater_equal(0.0)
	assert_int(c.hero.id).is_equal(2)
	assert_int(c.hero.hp).is_equal(70)
	assert_bool(c.onboarding.first_death_seen).is_true()
	assert_bool(c.onboarding.watch_unlocked).is_true()
	assert_array(result["rite_events"]).has_size(2)
	assert_object(c.run).is_null()
	assert_int(c.record_depth).is_equal(0)
	assert_array(TestFixtures.campaign_events_of(c, "ghost_placed")).has_size(1)


func test_watch_places_a_prepared_ghost_and_raises_record_depth() -> void:
	var c := TestFixtures.campaign(4, 1000)
	c.onboarding.watch_unlocked = true
	var result := TestFixtures.end_at_exit(c, 3, "watch", 2000)
	assert_str(result["kind"]).is_equal("watch")
	var ghost := c.ladder.find(int(result["ghost_id"]))
	assert_bool(ghost.prepared).is_true()
	assert_int(ghost.floor).is_equal(3)
	assert_float(ghost.strength).is_greater(0.0)
	assert_int(c.record_depth).is_equal(3)
	assert_int(c.ladder.waypoint()).is_equal(3)
	assert_int(CampaignEngine.reach(c)).is_equal(3)
	assert_int(c.hero.id).is_equal(2)
	assert_float(c.rate_per_hour).is_greater(52.0)
	assert_array(result["rite_events"]).is_empty()


func test_retreat_keeps_the_hero_and_sets_camp() -> void:
	var c := TestFixtures.campaign(5, 1000)
	var hero := c.hero
	var result := TestFixtures.end_at_exit(c, 2, "retreat", 2000)
	assert_str(result["kind"]).is_equal("retreat")
	assert_bool(result["new_hero"]).is_false()
	assert_object(c.hero).is_same(hero)
	assert_int(c.hero.camp).is_equal(2)
	assert_int(c.hero.resolve).is_equal(0)
	assert_int(CampaignEngine.reach(c)).is_equal(2)
	assert_int(c.record_depth).is_equal(2)
	assert_array(c.ladder.ghosts).has_size(1)
	assert_float(c.soul).is_greater_equal(0.0)


func test_tick_banks_production_with_the_offline_cap() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var r := CampaignEngine.tick(c, 1000 + 3600)
	assert_float(r["soul"]).is_equal_approx(52.0, 0.0001)
	assert_float(c.soul).is_equal_approx(52.0, 0.0001)
	assert_int(c.last_tick).is_equal(4600)
	var far := CampaignEngine.tick(c, 4600 + 30 * 3600)
	assert_bool(far["capped"]).is_true()
	assert_float(far["soul"]).is_equal_approx(52.0 * 8.0, 0.0001)
	CampaignEngine.tick(c, 100)
	assert_int(c.last_tick).is_equal(100)


func test_buy_upgrade_spends_and_applies() -> void:
	var c := TestFixtures.campaign()
	assert_bool(CampaignEngine.buy_upgrade(c, "might")["ok"]).is_false()
	c.soul = 100.0
	var r := CampaignEngine.buy_upgrade(c, "might")
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(25.0, 0.0001)
	assert_float(c.soul).is_equal_approx(75.0, 0.0001)
	assert_int(c.hero.stats["might"]).is_equal(1)
	assert_int(c.upgrades.level("might")).is_equal(1)
	c.soul = 1000.0
	CampaignEngine.buy_upgrade(c, "vigor")
	assert_int(c.hero.max_hp).is_equal(73)
	CampaignEngine.buy_upgrade(c, "resolve")
	assert_int(c.hero.max_resolve).is_equal(2)
	assert_int(c.hero.resolve).is_equal(2)
	var before := c.rate_per_hour
	CampaignEngine.buy_upgrade(c, "ghost_strength")
	assert_float(c.rate_per_hour).is_greater(before)
	assert_bool(CampaignEngine.buy_upgrade(c, "nothing")["ok"]).is_false()
	var next := CampaignEngine.new_hero(c, 5000)
	assert_int(next.stats["might"]).is_equal(1)
	assert_int(next.max_resolve).is_equal(2)
```

- [ ] **Step 3: Run to verify they fail**

Run: `tools\test.cmd tests/core/campaign_test.gd`
Expected: FAIL — `Campaign` / `CampaignEngine` not declared.

- [ ] **Step 4: Implement `core/onboarding/onboarding.gd`**

```gdscript
class_name Onboarding
extends RefCounted
## The first twenty minutes (spec §3.4): the Founder is seeded by the
## campaign, the first death unlocks Take the Watch, the first Tend is free.

var first_death_seen: bool = false
var watch_unlocked: bool = false
var free_tend_available: bool = true
var founder_seeded: bool = false


func on_run_end(outcome: Dictionary) -> Array:
	if String(outcome.get("kind", "")) != "death" or first_death_seen:
		return []
	first_death_seen = true
	watch_unlocked = true
	return [{"type": "first_death", "floor": int(outcome.get("floor", 1))}, {"type": "watch_unlocked"}]


func consume_free_tend() -> bool:
	if not free_tend_available:
		return false
	free_tend_available = false
	return true


func to_dict() -> Dictionary:
	return {"first_death_seen": first_death_seen, "watch_unlocked": watch_unlocked, "free_tend_available": free_tend_available, "founder_seeded": founder_seeded}


static func from_dict(d: Dictionary) -> Onboarding:
	var o := Onboarding.new()
	o.first_death_seen = bool(d.get("first_death_seen", false))
	o.watch_unlocked = bool(d.get("watch_unlocked", false))
	o.free_tend_available = bool(d.get("free_tend_available", true))
	o.founder_seeded = bool(d.get("founder_seeded", false))
	return o
```

- [ ] **Step 5: Implement `core/campaign.gd`**

```gdscript
class_name Campaign
extends RefCounted
## Everything the save file stores: the ladder, the living hero, the run in
## progress, Soul, upgrades, onboarding and the production clock. Mutated
## only by CampaignEngine and Seance.

var content: Content
var campaign_seed: int = 0
var biome_id: String = "catacombs"
var ladder: Ladder = Ladder.new()
var upgrades: Upgrades = Upgrades.new()
var onboarding: Onboarding = Onboarding.new()
var hero: Hero
var run: RunState
var soul: float = 0.0
var record_depth: int = 0
var hero_counter: int = 0
var run_counter: int = 0
var created_at: int = 0
var last_tick: int = 0
var rate_per_hour: float = 0.0
var sim_fights: int = -1
var events: Array = []


func emit(event: Dictionary) -> void:
	events.append(event)


func balance() -> Dictionary:
	return content.balance


func biome() -> BiomeDef:
	return content.biomes[biome_id]


func modifiers() -> Dictionary:
	return upgrades.modifiers(content)


func sub_rng(tag: String, n: int) -> Rng:
	return Rng.new(hash([campaign_seed, tag, n]))


func spend(cost: float) -> bool:
	if cost < 0.0 or soul < cost:
		return false
	soul -= cost
	emit({"type": "soul_spent", "amount": cost, "total": soul})
	return true
```

- [ ] **Step 6: Implement `core/campaign_engine.gd`**

```gdscript
class_name CampaignEngine
extends RefCounted
## Every transition of a Campaign: creation, heroes, runs, production
## ticks and upgrades. Static functions that mutate the campaign in place;
## Seance owns echoes, Calls, Tend and Mend.


static func new_campaign(content: Content, campaign_seed: int, now: int) -> Campaign:
	var c := Campaign.new()
	c.content = content
	c.campaign_seed = campaign_seed
	c.created_at = now
	c.last_tick = now
	c.ladder.add(Ghost.founder(content, now))
	c.onboarding.founder_seeded = true
	new_hero(c, now)
	refresh_rate(c)
	c.emit({"type": "campaign_start", "seed": campaign_seed, "at": now})
	return c


static func new_hero(c: Campaign, now: int) -> Hero:
	c.hero_counter += 1
	var mods := c.modifiers()
	var hero_name := Hero.generate_name(c.sub_rng("names", c.hero_counter))
	var hero := Hero.create(c.content, "sexton", hero_name, mods["stats"], 1 + int(mods["max_resolve_bonus"]))
	hero.id = c.hero_counter
	c.hero = hero
	c.emit({"type": "hero_created", "id": hero.id, "name": hero.name, "at": now})
	return hero


static func reach(c: Campaign) -> int:
	var camp := c.hero.camp if c.hero != null else 0
	return maxi(1, maxi(c.ladder.waypoint(), maxi(camp, c.record_depth)))


static func start_run(c: Campaign, entry_floor: int, now: int) -> RunState:
	if c.run != null and not c.run.is_over():
		push_error("start_run: a run is already in progress")
		return c.run
	var deepest := mini(reach(c), c.biome().last_floor)
	if entry_floor < 1 or entry_floor > deepest:
		push_error("start_run: entry floor %d outside 1..%d" % [entry_floor, deepest])
		return null
	tick(c, now)
	c.run_counter += 1
	var run_seed := hash([c.campaign_seed, "run", c.run_counter])
	c.run = RunEngine.start_run(c.content, c.hero, c.biome_id, entry_floor, run_seed, c.onboarding.watch_unlocked)
	c.emit({"type": "run_started", "run": c.run_counter, "entry_floor": entry_floor, "seed": run_seed, "at": now})
	return c.run


static func finish_run(c: Campaign, now: int) -> Dictionary:
	if c.run == null or not c.run.is_over():
		push_error("finish_run: no finished run")
		return {}
	var outcome := c.run.outcome
	var kind := String(outcome.get("kind", "death"))
	var floor := int(outcome.get("floor", 1))
	var soul := float(outcome.get("soul", 0.0))
	c.soul += soul
	c.emit({"type": "soul_banked", "amount": soul, "total": c.soul})
	var cleared := floor - 1 if kind == "death" else floor
	c.record_depth = maxi(c.record_depth, cleared)
	var result := {"kind": kind, "floor": floor, "soul": soul, "ghost_id": 0, "epitaph": "", "new_hero": false, "rite_events": []}
	if kind == "death" or kind == "watch":
		var ghost := Ghost.from_run(c.hero, outcome, c.run.stats.measured(floor), now)
		c.ladder.add(ghost)
		ghost.strength = strength_for(c, ghost)
		result["ghost_id"] = ghost.id
		result["epitaph"] = ghost.epitaph(c.content)
		c.emit({"type": "ghost_placed", "id": ghost.id, "floor": ghost.floor, "strength": ghost.strength, "epitaph": result["epitaph"], "cause": ghost.cause})
		var rite := c.onboarding.on_run_end(outcome)
		for ev in rite:
			c.emit(ev)
		result["rite_events"] = rite
		new_hero(c, now)
		result["new_hero"] = true
	c.run = null
	refresh_rate(c)
	c.emit({"type": "run_finished", "kind": kind, "floor": floor, "soul": soul, "at": now})
	return result


static func strength_for(c: Campaign, ghost: Ghost) -> float:
	if ghost.fixed_strength:
		return ghost.strength
	var sim := Strength.simulate(c.content, ghost.snapshot(), c.biome(), ghost.floor, hash([c.campaign_seed, "strength", ghost.id]), c.sim_fights)
	return Strength.of_ghost_stats(ghost.measured, sim, c.balance())


static func refresh_rate(c: Campaign) -> void:
	c.rate_per_hour = Production.rate_per_hour(c.ladder, c.balance(), c.modifiers())


static func tick(c: Campaign, now: int) -> Dictionary:
	var r := Production.accrue(c.rate_per_hour, now - c.last_tick, float(c.modifiers()["offline_cap_hours"]))
	if float(r["soul"]) > 0.0:
		c.soul += float(r["soul"])
	c.last_tick = now
	return r


static func buy_upgrade(c: Campaign, id: String) -> Dictionary:
	var price := c.upgrades.cost(c.content, id)
	if price < 0.0:
		return {"ok": false, "cost": price, "reason": "unavailable"}
	if not c.spend(price):
		return {"ok": false, "cost": price, "reason": "soul"}
	c.upgrades.buy(c.content, id)
	var def: UpgradeDef = c.content.upgrades[id]
	var amount := int(def.effect.get("amount", 0))
	match String(def.effect.get("kind", "")):
		"stat":
			var stat := String(def.effect.get("stat", ""))
			c.hero.stats[stat] = int(c.hero.stats.get(stat, 0)) + amount
			if stat == "vigor":
				c.hero.recompute_max_hp(c.content)
		"max_resolve":
			c.hero.max_resolve += amount
			c.hero.resolve += amount
	refresh_rate(c)
	c.emit({"type": "upgrade_bought", "id": id, "level": c.upgrades.level(id), "cost": price})
	return {"ok": true, "cost": price, "reason": ""}
```

- [ ] **Step 7: Run to verify they pass**

Run: `tools\test.cmd tests/core/campaign_test.gd`
Expected: PASS — 8 test cases, 0 failures (each death/watch computes a 4-fight strength simulation). Then `tools\test.cmd tests` — 224 test cases, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add core/onboarding core/campaign.gd core/campaign.gd.uid core/campaign_engine.gd core/campaign_engine.gd.uid tests/helpers/fixtures.gd tests/core/campaign_test.gd tests/core/campaign_test.gd.uid
git commit -m "feat(campaign): campaign aggregate with founder, heroes, run lifecycle, ticks and upgrades"
```

---

### Task 8: Seance — echoes, Calls, Tend and Mend

**Files:**
- Create: `core/economy/seance.gd`
- Test: `tests/core/economy/seance_test.gd`

**Interfaces:**
- Consumes: `Campaign` (`ladder`, `soul`, `spend`, `onboarding`, `hero`, `modifiers`, `sim_fights`, `sub_rng`), `Ghost.clone_as_echo/snapshot`, `Strength.simulate/from_stats`, `CampaignEngine.refresh_rate`, balance keys `echo_base_cost`, `echo_cost_growth`, `call_cost_factor`, `echo_factor`, `tend_base_cost`, `tend_cost_growth`, `mend_base_cost`, `mend_cost_growth`.
- Produces (static on `Seance`, every mutator returns `{"ok": bool, "cost": float, "reason": String, ...}`): `echo_count(c) -> int`; `echo_cost(c) -> float` (`base × growth^count`); `call_cost(c) -> float` (`echo_cost × call_cost_factor`); `tend_cost(c, ghost) -> float` (`base × growth^floor`, 0 while the free Tend is available); `mend_cost(c) -> float` (`base × growth^camp × (1 − mend_discount)`); `echo_strength(c, source, floor) -> float` (`echo_factor × min(source.strength, simulated on floor)`, simulation seed `hash([campaign_seed, "echo", source.id, floor])`); `create_echo(c, source_id, floor, now)` (source must be a standing `true` ghost, `1 <= floor <= waypoint`, Soul spent, echo added with its strength, rate refreshed; emits `echo_placed`); `call_echo(c, echo_id, floor)` (echo only, `floor <= waypoint`, pays the Call, moves and recomputes strength; emits `echo_called`); `tend(c, ghost_id)` (`true` ghost that is restless; free once, then paid; clears `restless` on the ghost and on every echo of it; emits `ghost_tended`); `mend(c)` (hero below max HP; pays; heals to full; emits `hero_mended`).

- [ ] **Step 1: Write the failing tests**

`tests/core/economy/seance_test.gd`:

```gdscript
extends GdUnitTestSuite


func _with_ghost_on(floor: int, seed: int = 2) -> Campaign:
	var c := TestFixtures.campaign(seed, 1000)
	c.onboarding.watch_unlocked = true
	TestFixtures.end_at_exit(c, floor, "watch", 2000)
	return c


func test_costs() -> void:
	var c := TestFixtures.campaign()
	assert_float(Seance.echo_cost(c)).is_equal_approx(50.0, 0.0001)
	assert_float(Seance.call_cost(c)).is_equal_approx(12.5, 0.0001)
	var g := Ghost.new()
	g.floor = 3
	assert_float(Seance.tend_cost(c, g)).is_equal_approx(0.0, 0.0001)
	c.onboarding.free_tend_available = false
	assert_float(Seance.tend_cost(c, g)).is_equal_approx(43.94, 0.0001)
	c.hero.camp = 2
	assert_float(Seance.mend_cost(c)).is_equal_approx(25.35, 0.0001)
	c.upgrades.levels = {"mend_discount": 2}
	assert_float(Seance.mend_cost(c)).is_equal_approx(17.745, 0.0001)


func test_create_echo_rules() -> void:
	var c := _with_ghost_on(3)
	var source := c.ladder.ghosts[1]
	c.soul = 10.0
	assert_str(Seance.create_echo(c, source.id, 2, 3000)["reason"]).is_equal("soul")
	c.soul = 500.0
	assert_str(Seance.create_echo(c, 999, 2, 3000)["reason"]).is_equal("source")
	assert_str(Seance.create_echo(c, source.id, 4, 3000)["reason"]).is_equal("floor")
	assert_str(Seance.create_echo(c, source.id, 0, 3000)["reason"]).is_equal("floor")
	var before_rate := c.rate_per_hour
	var r := Seance.create_echo(c, source.id, 2, 3000)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(50.0, 0.0001)
	assert_float(c.soul).is_equal_approx(450.0, 0.0001)
	var echo := c.ladder.find(int(r["ghost_id"]))
	assert_str(echo.kind).is_equal("echo")
	assert_int(echo.source_id).is_equal(source.id)
	assert_int(echo.floor).is_equal(2)
	assert_float(echo.strength).is_less_equal(0.75 * source.strength + 0.0001)
	assert_float(echo.strength).is_greater(0.0)
	assert_float(c.rate_per_hour).is_greater(before_rate)
	assert_int(Seance.echo_count(c)).is_equal(1)
	assert_float(Seance.echo_cost(c)).is_equal_approx(57.5, 0.0001)
	assert_str(Seance.create_echo(c, echo.id, 1, 3000)["reason"]).is_equal("source")
	assert_int(c.ladder.waypoint()).is_equal(3)


func test_echo_never_out_earns_its_source() -> void:
	var c := _with_ghost_on(3)
	var source := c.ladder.ghosts[1]
	source.strength = 0.5
	assert_float(Seance.echo_strength(c, source, 1)).is_less_equal(0.375 + 0.0001)


func test_call_moves_an_echo() -> void:
	var c := _with_ghost_on(3)
	c.soul = 500.0
	var echo_id := int(Seance.create_echo(c, c.ladder.ghosts[1].id, 1, 3000)["ghost_id"])
	assert_str(Seance.call_echo(c, c.ladder.ghosts[1].id, 2)["reason"]).is_equal("echo")
	assert_str(Seance.call_echo(c, echo_id, 9)["reason"]).is_equal("floor")
	var r := Seance.call_echo(c, echo_id, 2)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(57.5 * 0.25, 0.0001)
	assert_int(c.ladder.find(echo_id).floor).is_equal(2)
	assert_array(c.ladder.on_floor(1)).has_size(1)


func test_tend_clears_restless_first_one_free() -> void:
	var c := TestFixtures.campaign(6, 1000)
	TestFixtures.die_on_floor(c, 1, 2000)
	TestFixtures.die_on_floor(c, 1, 3000)
	var first := c.ladder.ghosts[1]
	var second := c.ladder.ghosts[2]
	assert_bool(first.restless).is_true()
	c.soul = 500.0
	var echo_id := int(Seance.create_echo(c, first.id, 1, 4000)["ghost_id"])
	assert_bool(c.ladder.find(echo_id).restless).is_true()
	var rate_before := c.rate_per_hour
	var r := Seance.tend(c, first.id)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal(0.0)
	assert_bool(first.restless).is_false()
	assert_bool(c.ladder.find(echo_id).restless).is_false()
	assert_bool(c.onboarding.free_tend_available).is_false()
	assert_float(c.rate_per_hour).is_greater_equal(rate_before)
	assert_str(Seance.tend(c, first.id)["reason"]).is_equal("not_restless")
	c.soul = 0.0
	assert_str(Seance.tend(c, second.id)["reason"]).is_equal("soul")
	c.soul = 100.0
	var paid := Seance.tend(c, second.id)
	assert_bool(paid["ok"]).is_true()
	assert_float(paid["cost"]).is_equal_approx(26.0, 0.0001)
	assert_str(Seance.tend(c, 999)["reason"]).is_equal("ghost")


func test_mend_heals_for_soul() -> void:
	var c := TestFixtures.campaign()
	assert_str(Seance.mend(c)["reason"]).is_equal("healthy")
	c.hero.hp = 20
	c.hero.camp = 1
	c.soul = 1.0
	assert_str(Seance.mend(c)["reason"]).is_equal("soul")
	c.soul = 100.0
	var r := Seance.mend(c)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(19.5, 0.0001)
	assert_int(c.hero.hp).is_equal(70)
	assert_float(c.soul).is_equal_approx(80.5, 0.0001)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/economy/seance_test.gd`
Expected: FAIL — `Seance` not declared.

- [ ] **Step 3: Implement `core/economy/seance.gd`**

```gdscript
class_name Seance
extends RefCounted
## Soul sinks between runs (spec §5.5, §3.2): echoes, Calls, a minimal Tend
## that clears restless, and Mend. Every mutator returns {ok, cost, reason}.


static func echo_count(c: Campaign) -> int:
	var n := 0
	for g in c.ladder.ghosts:
		if g.kind == "echo":
			n += 1
	return n


static func echo_cost(c: Campaign) -> float:
	var b := c.balance()
	return float(b.get("echo_base_cost", 50)) * pow(float(b.get("echo_cost_growth", 1.15)), echo_count(c))


static func call_cost(c: Campaign) -> float:
	return echo_cost(c) * float(c.balance().get("call_cost_factor", 0.25))


static func tend_cost(c: Campaign, ghost: Ghost) -> float:
	if c.onboarding.free_tend_available:
		return 0.0
	var b := c.balance()
	return float(b.get("tend_base_cost", 20)) * pow(float(b.get("tend_cost_growth", 1.3)), ghost.floor)


static func mend_cost(c: Campaign) -> float:
	var b := c.balance()
	var discount := float(c.modifiers()["mend_discount"])
	return float(b.get("mend_base_cost", 15)) * pow(float(b.get("mend_cost_growth", 1.3)), c.hero.camp) * (1.0 - discount)


static func echo_strength(c: Campaign, source: Ghost, floor: int) -> float:
	var sim := Strength.simulate(c.content, source.snapshot(), c.biome(), floor, hash([c.campaign_seed, "echo", source.id, floor]), c.sim_fights)
	var simulated := Strength.from_stats(float(sim["win_rate"]), float(sim["avg_turns"]), c.balance())
	return float(c.balance().get("echo_factor", 0.75)) * minf(source.strength, simulated)


static func create_echo(c: Campaign, source_id: int, floor: int, now: int) -> Dictionary:
	var source := c.ladder.find(source_id)
	var cost := echo_cost(c)
	if source == null or source.kind != "true":
		return {"ok": false, "cost": cost, "reason": "source"}
	if floor < 1 or floor > c.ladder.waypoint():
		return {"ok": false, "cost": cost, "reason": "floor"}
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	var echo := source.clone_as_echo(floor, now)
	c.ladder.add(echo)
	echo.strength = echo_strength(c, source, floor)
	CampaignEngine.refresh_rate(c)
	c.emit({"type": "echo_placed", "id": echo.id, "source": source.id, "floor": floor, "strength": echo.strength, "cost": cost})
	return {"ok": true, "cost": cost, "reason": "", "ghost_id": echo.id}


static func call_echo(c: Campaign, echo_id: int, floor: int) -> Dictionary:
	var echo := c.ladder.find(echo_id)
	var cost := call_cost(c)
	if echo == null or echo.kind != "echo":
		return {"ok": false, "cost": cost, "reason": "echo"}
	if floor < 1 or floor > c.ladder.waypoint():
		return {"ok": false, "cost": cost, "reason": "floor"}
	var source := c.ladder.find(echo.source_id)
	if source == null:
		return {"ok": false, "cost": cost, "reason": "source"}
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	echo.floor = floor
	echo.strength = echo_strength(c, source, floor)
	CampaignEngine.refresh_rate(c)
	c.emit({"type": "echo_called", "id": echo.id, "floor": floor, "strength": echo.strength, "cost": cost})
	return {"ok": true, "cost": cost, "reason": ""}


static func tend(c: Campaign, ghost_id: int) -> Dictionary:
	var ghost := c.ladder.find(ghost_id)
	if ghost == null or ghost.kind != "true":
		return {"ok": false, "cost": 0.0, "reason": "ghost"}
	if not ghost.restless:
		return {"ok": false, "cost": 0.0, "reason": "not_restless"}
	var cost := tend_cost(c, ghost)
	if cost > 0.0 and not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	if cost == 0.0:
		c.onboarding.consume_free_tend()
	ghost.restless = false
	for g in c.ladder.ghosts:
		if g.kind == "echo" and g.source_id == ghost.id:
			g.restless = false
	CampaignEngine.refresh_rate(c)
	c.emit({"type": "ghost_tended", "id": ghost.id, "cost": cost})
	return {"ok": true, "cost": cost, "reason": ""}


static func mend(c: Campaign) -> Dictionary:
	if c.hero.hp >= c.hero.max_hp:
		return {"ok": false, "cost": 0.0, "reason": "healthy"}
	var cost := mend_cost(c)
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	c.hero.hp = c.hero.max_hp
	c.emit({"type": "hero_mended", "cost": cost, "hp": c.hero.hp})
	return {"ok": true, "cost": cost, "reason": ""}
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/economy`
Expected: PASS — 14 test cases, 0 failures. `test_tend_clears_restless_first_one_free` expects the paid Tend at floor 1 to cost `20 × 1.3 = 26`.

- [ ] **Step 5: Commit**

```bash
git add core/economy/seance.gd core/economy/seance.gd.uid tests/core/economy/seance_test.gd tests/core/economy/seance_test.gd.uid
git commit -m "feat(economy): seance with echoes, calls, tend and mend"
```

---

### Task 9: YieldSimulator — the three exit-screen numbers

**Files:**
- Create: `core/ghosts/yield_simulator.gd`
- Test: `tests/core/ghosts/yield_test.gd`

**Interfaces:**
- Consumes: `RunEngine.exit_summary(run, samples)`, `RunState.stats.measured/hero_snapshot/floor/run_counter`, `Strength.simulate/of_ghost_stats/from_stats`, `Ladder.marginal_yield`, balance `prepared_bonus`.
- Produces: `YieldSimulator.strength_here(c, run) -> float` (measured on this floor blended with a simulation, seed `hash([campaign_seed, "yield", run_counter, floor])`); `strength_at(c, run, floor) -> float` (simulation only); `exit_numbers(c, run, samples = -1) -> Dictionary` = `RunEngine.exit_summary` plus `"strength_here"`, `"yield_here"` (marginal Soul/h of a prepared ghost with this deck on this floor), `"strength_next"`, `"yield_next"` (`-1.0` when pushing is impossible).

- [ ] **Step 1: Write the failing tests**

`tests/core/ghosts/yield_test.gd`:

```gdscript
extends GdUnitTestSuite


func _run_at_exit(c: Campaign, floor: int) -> RunState:
	var run := CampaignEngine.start_run(c, 1, 1001)
	run.floor = floor
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "skip_card"})
	return run


func test_exit_numbers_extend_the_run_summary() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var run := _run_at_exit(c, 2)
	var n := YieldSimulator.exit_numbers(c, run, 2)
	assert_int(n["floor"]).is_equal(2)
	assert_int(n["next_floor"]).is_equal(3)
	assert_float(n["survival"]).is_between(0.0, 1.0)
	assert_float(n["strength_here"]).is_greater(0.0)
	assert_float(n["yield_here"]).is_greater(0.0)
	assert_float(n["strength_next"]).is_greater_equal(0.0)
	assert_float(n["yield_next"]).is_greater_equal(0.0)
	assert_bool(n["can_push"]).is_true()


func test_yield_is_marginal_over_the_ladder_and_prepared() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var run := _run_at_exit(c, 1)
	var strength := YieldSimulator.strength_here(c, run)
	var expected := c.ladder.marginal_yield(1, strength * 1.25, c.balance(), c.modifiers())
	var n := YieldSimulator.exit_numbers(c, run, 1)
	assert_float(n["yield_here"]).is_equal_approx(expected, 0.0001)
	assert_float(YieldSimulator.strength_here(c, run)).is_equal(strength)


func test_no_next_floor_past_the_slice() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var run := _run_at_exit(c, 10)
	var n := YieldSimulator.exit_numbers(c, run, 1)
	assert_bool(n["can_push"]).is_false()
	assert_float(n["yield_next"]).is_equal(-1.0)
	assert_float(n["strength_next"]).is_equal(-1.0)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/ghosts/yield_test.gd`
Expected: FAIL — `YieldSimulator` not declared.

- [ ] **Step 3: Implement `core/ghosts/yield_simulator.gd`**

```gdscript
class_name YieldSimulator
extends RefCounted
## The exit screen's numbers (spec §3.2): the marginal yield of a prepared
## ghost with this deck here (measured this run, blended with a simulation),
## the same simulated for the next floor, and the survival chance.


static func strength_here(c: Campaign, run: RunState) -> float:
	var measured := run.stats.measured(run.floor)
	var sim := Strength.simulate(c.content, run.hero_snapshot(), c.biome(), run.floor, hash([c.campaign_seed, "yield", c.run_counter, run.floor]), c.sim_fights)
	return Strength.of_ghost_stats(measured, sim, c.balance())


static func strength_at(c: Campaign, run: RunState, floor: int) -> float:
	var sim := Strength.simulate(c.content, run.hero_snapshot(), c.biome(), floor, hash([c.campaign_seed, "yield", c.run_counter, floor]), c.sim_fights)
	return Strength.from_stats(float(sim["win_rate"]), float(sim["avg_turns"]), c.balance())


static func exit_numbers(c: Campaign, run: RunState, samples: int = -1) -> Dictionary:
	var out := RunEngine.exit_summary(run, samples)
	var prepared := 1.0 + float(c.balance().get("prepared_bonus", 0.25))
	var mods := c.modifiers()
	var here := strength_here(c, run)
	out["strength_here"] = here
	out["yield_here"] = c.ladder.marginal_yield(run.floor, here * prepared, c.balance(), mods)
	if bool(out["can_push"]):
		var next := strength_at(c, run, run.floor + 1)
		out["strength_next"] = next
		out["yield_next"] = c.ladder.marginal_yield(run.floor + 1, next * prepared, c.balance(), mods)
	else:
		out["strength_next"] = -1.0
		out["yield_next"] = -1.0
	return out
```

- [ ] **Step 4: Run to verify they pass**

Run: `tools\test.cmd tests/core/ghosts`
Expected: PASS — 20 test cases, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add core/ghosts/yield_simulator.gd core/ghosts/yield_simulator.gd.uid tests/core/ghosts/yield_test.gd tests/core/ghosts/yield_test.gd.uid
git commit -m "feat(ghosts): exit-screen yield numbers from measured and simulated strength"
```

---

### Task 10: Campaign serialization and SaveGame — JSON file, backups, migrations, offline catch-up

**Files:**
- Modify: `core/campaign.gd` (append `to_dict`, `static from_dict`)
- Create: `core/save/save_game.gd`
- Test: `tests/core/save/save_game_test.gd`

**Interfaces:**
- Consumes: `Ladder/Upgrades/Onboarding/Hero/RunState` `to_dict`/`from_dict`, `Content.normalize_json`, `CampaignEngine.tick`, Godot `FileAccess`/`DirAccess`/`JSON`.
- Produces: `Campaign.to_dict() -> Dictionary` (`version` 1 plus every field except `content`, `events`, `sim_fights`; `run` is `{}` between runs); `static Campaign.from_dict(content, d) -> Campaign` (when a run is present the campaign adopts `run.hero` as its living hero so both refer to one object). `SaveGame.VERSION := 1`, `DEFAULT_PATH := "user://saves/slot1.json"`, `BACKUPS := 2`; `static save(c, path = DEFAULT_PATH) -> Error` (creates the directory, rotates `path.bak1`/`.bak2`, writes pretty JSON); `static load(content, path = DEFAULT_PATH) -> Campaign` (null when missing or unparsable; numbers normalized through `Content.normalize_json`; `migrate` applied); `static exists(path) -> bool`; `static migrate(d) -> Dictionary` (raises `version` step by step to `VERSION`; v0→v1 only sets the field); `static load_and_catch_up(content, now, path = DEFAULT_PATH) -> Dictionary` `{"campaign": Campaign|null, "offline": accrue result}` — the "While you were away" numbers come from `CampaignEngine.tick` with the offline cap. Nothing else in `core/` touches the filesystem.

- [ ] **Step 1: Write the failing tests**

`tests/core/save/save_game_test.gd`:

```gdscript
extends GdUnitTestSuite

const PATH := "user://test_saves/slot.json"


func before_test() -> void:
	_wipe()


func after_test() -> void:
	_wipe()


func _wipe() -> void:
	var da := DirAccess.open("user://")
	if da == null or not da.dir_exists("test_saves"):
		return
	var dir := DirAccess.open("user://test_saves")
	for f in dir.get_files():
		dir.remove(f)
	da.remove("test_saves")


func test_campaign_round_trip_between_runs() -> void:
	var c := TestFixtures.campaign(3, 1000)
	c.onboarding.watch_unlocked = true
	TestFixtures.end_at_exit(c, 2, "watch", 2000)
	c.soul = 123.5
	CampaignEngine.buy_upgrade(c, "vigor")
	var back := Campaign.from_dict(TestFixtures.content(), JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_int(back.campaign_seed).is_equal(3)
	assert_array(back.ladder.ghosts).has_size(2)
	assert_int(back.ladder.waypoint()).is_equal(2)
	assert_str(back.hero.name).is_equal(c.hero.name)
	assert_int(back.hero.id).is_equal(2)
	assert_int(back.hero.max_hp).is_equal(73)
	assert_float(back.soul).is_equal_approx(c.soul, 0.0001)
	assert_int(back.upgrades.level("vigor")).is_equal(1)
	assert_bool(back.onboarding.watch_unlocked).is_true()
	assert_int(back.record_depth).is_equal(2)
	assert_int(back.hero_counter).is_equal(2)
	assert_int(back.run_counter).is_equal(1)
	assert_int(back.last_tick).is_equal(2000)
	assert_float(back.rate_per_hour).is_equal_approx(c.rate_per_hour, 0.0001)
	assert_object(back.run).is_null()
	assert_array(back.events).is_empty()


func test_round_trip_with_a_run_in_progress_adopts_the_run_hero() -> void:
	var c := TestFixtures.campaign(4, 1000)
	var run := CampaignEngine.start_run(c, 1, 1500)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "take_card", "card": run.reward["cards"][0]})
	var back := Campaign.from_dict(TestFixtures.content(), JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_object(back.run).is_not_null()
	assert_object(back.hero).is_same(back.run.hero)
	assert_array(back.hero.deck).has_size(11)
	assert_str(back.run.phase).is_equal("node")
	assert_int(back.run.node_index).is_equal(1)
	RunEngine.apply(back.run, {"kind": "enter"})
	RunEngine.apply(back.run, {"kind": "rest_heal"})
	RunEngine.apply(back.run, {"kind": "retreat"})
	var result := CampaignEngine.finish_run(back, 3000)
	assert_str(result["kind"]).is_equal("retreat")
	assert_int(back.hero.camp).is_equal(1)


func test_save_writes_file_and_rotates_backups() -> void:
	var c := TestFixtures.campaign(5, 1000)
	assert_bool(SaveGame.exists(PATH)).is_false()
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	assert_bool(SaveGame.exists(PATH)).is_true()
	assert_bool(FileAccess.file_exists(PATH + ".bak1")).is_false()
	c.soul = 1.0
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	assert_bool(FileAccess.file_exists(PATH + ".bak1")).is_true()
	c.soul = 2.0
	assert_int(SaveGame.save(c, PATH)).is_equal(OK)
	assert_bool(FileAccess.file_exists(PATH + ".bak2")).is_true()
	var loaded := SaveGame.load(TestFixtures.content(), PATH)
	assert_float(loaded.soul).is_equal(2.0)
	var older := Campaign.from_dict(TestFixtures.content(), Content.normalize_json(JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak1"))))
	assert_float(older.soul).is_equal(1.0)


func test_load_missing_or_corrupt_returns_null() -> void:
	assert_object(SaveGame.load(TestFixtures.content(), PATH)).is_null()
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_object(SaveGame.load(TestFixtures.content(), PATH)).is_null()


func test_migrate_raises_the_version() -> void:
	var d := SaveGame.migrate({"campaign_seed": 1})
	assert_int(d["version"]).is_equal(SaveGame.VERSION)
	assert_int(SaveGame.migrate({"version": 1, "campaign_seed": 1})["version"]).is_equal(1)


func test_load_and_catch_up_banks_offline_soul() -> void:
	var c := TestFixtures.campaign(6, 1000)
	SaveGame.save(c, PATH)
	var r := SaveGame.load_and_catch_up(TestFixtures.content(), 1000 + 2 * 3600, PATH)
	var loaded: Campaign = r["campaign"]
	assert_object(loaded).is_not_null()
	assert_float(r["offline"]["soul"]).is_equal_approx(104.0, 0.0001)
	assert_float(loaded.soul).is_equal_approx(104.0, 0.0001)
	assert_int(loaded.last_tick).is_equal(1000 + 2 * 3600)
	var capped := SaveGame.load_and_catch_up(TestFixtures.content(), 1000 + 100 * 3600, PATH)
	assert_bool(capped["offline"]["capped"]).is_true()
	assert_float(capped["offline"]["soul"]).is_equal_approx(52.0 * 8.0, 0.0001)
	assert_object(SaveGame.load_and_catch_up(TestFixtures.content(), 5, "user://test_saves/nothing.json")["campaign"]).is_null()
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/save`
Expected: FAIL — `SaveGame` not declared / `Campaign.to_dict` missing.

- [ ] **Step 3: Append serialization to `core/campaign.gd`**

```gdscript
func to_dict() -> Dictionary:
	return {
		"version": 1,
		"campaign_seed": campaign_seed,
		"biome_id": biome_id,
		"ladder": ladder.to_dict(),
		"upgrades": upgrades.to_dict(),
		"onboarding": onboarding.to_dict(),
		"hero": hero.to_dict() if hero != null else {},
		"run": run.to_dict() if run != null else {},
		"soul": soul,
		"record_depth": record_depth,
		"hero_counter": hero_counter,
		"run_counter": run_counter,
		"created_at": created_at,
		"last_tick": last_tick,
		"rate_per_hour": rate_per_hour,
	}


static func from_dict(p_content: Content, d: Dictionary) -> Campaign:
	var c := Campaign.new()
	c.content = p_content
	c.campaign_seed = int(d.get("campaign_seed", 0))
	c.biome_id = String(d.get("biome_id", "catacombs"))
	c.ladder = Ladder.from_dict(d.get("ladder", {}))
	c.upgrades = Upgrades.from_dict(d.get("upgrades", {}))
	c.onboarding = Onboarding.from_dict(d.get("onboarding", {}))
	var hero_raw: Dictionary = d.get("hero", {})
	if not hero_raw.is_empty():
		c.hero = Hero.from_dict(hero_raw)
	var run_raw: Dictionary = d.get("run", {})
	if not run_raw.is_empty():
		c.run = RunState.from_dict(p_content, run_raw)
		c.hero = c.run.hero
	c.soul = float(d.get("soul", 0.0))
	c.record_depth = int(d.get("record_depth", 0))
	c.hero_counter = int(d.get("hero_counter", 0))
	c.run_counter = int(d.get("run_counter", 0))
	c.created_at = int(d.get("created_at", 0))
	c.last_tick = int(d.get("last_tick", 0))
	c.rate_per_hour = float(d.get("rate_per_hour", 0.0))
	return c
```

- [ ] **Step 4: Implement `core/save/save_game.gd`**

```gdscript
class_name SaveGame
extends RefCounted
## The campaign on disk (spec §8): one JSON file with a version field,
## rotating backups and one migration per version. The only file I/O in core/.

const VERSION := 1
const DEFAULT_PATH := "user://saves/slot1.json"
const BACKUPS := 2


static func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func save(c: Campaign, path: String = DEFAULT_PATH) -> Error:
	var dir := path.get_base_dir()
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK and made != ERR_ALREADY_EXISTS:
		return made
	_rotate(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var d := c.to_dict()
	d["version"] = VERSION
	file.store_string(JSON.stringify(d, "\t"))
	file.close()
	return OK


static func load(content: Content, path: String = DEFAULT_PATH) -> Campaign:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return null
	var d: Dictionary = Content.normalize_json(parsed)
	return Campaign.from_dict(content, migrate(d))


static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var version := int(out.get("version", 0))
	while version < VERSION:
		match version:
			0:
				pass
		version += 1
		out["version"] = version
	return out


static func load_and_catch_up(content: Content, now: int, path: String = DEFAULT_PATH) -> Dictionary:
	var c := load(content, path)
	if c == null:
		return {"campaign": null, "offline": {"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0}}
	var offline := CampaignEngine.tick(c, now)
	return {"campaign": c, "offline": offline}


static func _rotate(path: String) -> void:
	var da := DirAccess.open(path.get_base_dir())
	if da == null:
		return
	var file := path.get_file()
	for i in range(BACKUPS, 0, -1):
		var newer := file if i == 1 else "%s.bak%d" % [file, i - 1]
		var older := "%s.bak%d" % [file, i]
		if da.file_exists(newer):
			if da.file_exists(older):
				da.remove(older)
			da.rename(newer, older)
```

- [ ] **Step 5: Run to verify they pass**

Run: `tools\test.cmd tests/core/save`
Expected: PASS — 6 test cases, 0 failures. Then `tools\test.cmd tests` — 239 test cases, 0 failures. If `test_save_writes_file_and_rotates_backups` cannot find `.bak1`, check that `_rotate` runs before the new file is opened and that `DirAccess.rename` is given file names relative to the opened directory, not `user://` paths.

- [ ] **Step 6: Commit**

```bash
git add core/campaign.gd core/save/save_game.gd core/save/save_game.gd.uid tests/core/save/save_game_test.gd tests/core/save/save_game_test.gd.uid
git commit -m "feat(save): campaign serialization, JSON save with backups, migrations and offline catch-up"
```

---

### Task 11: Balance simulator — typical decks per floor and the §12 invariants

**Files:**
- Create: `core/economy/balance_sim.gd`, `tools/balance_sim.gd`
- Test: `tests/core/economy/balance_sim_test.gd`

**Interfaces:**
- Consumes: `Hero.create`, `RunEngine`, `RunAutopilot` (`choose`, `fight_ap`), `Strength`, `Ladder.output_for`, `Ghost.founder`, `Seance` cost formulas via balance, `Upgrades.cost_at`.
- Produces: `BalanceSim` (instance) fields `content`, `runs: int = 4`, `sim_fights: int = 12`, `seed_base: int = 1`; `sample_runs() -> Array` — plays `runs` autopilot runs from floor 1 that always push (the watch is taken only at the last floor), recording at every floor exit `{"run", "floor", "snapshot": HeroSnapshot, "measured": Dictionary}` and, per run, `{"first_run_soul": float, "death_floor": int}`; `floor_table() -> Dictionary` (floor → `{"samples", "strength", "yield_watch", "yield_corpse_plus_echo"}` averaged over samples; `yield_*` are `Ladder.output_for` on an empty floor with the founder's ladder, watch = `1.25 × s`, corpse = `0.7 × s` plus an echo of the corpse `0.75 × 0.7 × s` on the same floor); `report() -> Dictionary` `{"floors": floor_table, "invariants": {"deeper_pays": {ok, detail}, "watch_beats_corpse": {ok, detail}, "first_purchase_early": {ok, detail}}, "retreat_note": String}`; `static is_non_decreasing(values: Array) -> bool`; `all_ok(report) -> bool`. Invariant 3 (retreat costs) is reported as a note, not asserted — see the plan self-review. `tools/balance_sim.gd -- [runs] [sim_fights]` prints the table and the invariant lines; exit 0 when every asserted invariant holds, 1 otherwise (or on content errors).

- [ ] **Step 1: Write the failing tests**

`tests/core/economy/balance_sim_test.gd`:

```gdscript
extends GdUnitTestSuite


func test_non_decreasing_helper() -> void:
	assert_bool(BalanceSim.is_non_decreasing([1.0, 2.0, 2.0, 5.0])).is_true()
	assert_bool(BalanceSim.is_non_decreasing([3.0, 2.0])).is_false()
	assert_bool(BalanceSim.is_non_decreasing([])).is_true()


func test_small_simulation_reports_every_section() -> void:
	var sim := BalanceSim.new()
	sim.content = TestFixtures.content()
	sim.runs = 2
	sim.sim_fights = 4
	sim.seed_base = 3
	var report := sim.report()
	assert_bool(report["floors"].has(1)).is_true()
	var floor1: Dictionary = report["floors"][1]
	assert_int(floor1["samples"]).is_equal(2)
	assert_float(floor1["strength"]).is_greater(0.0)
	assert_float(floor1["yield_watch"]).is_greater(0.0)
	assert_bool(report["invariants"].has("deeper_pays")).is_true()
	assert_bool(report["invariants"].has("watch_beats_corpse")).is_true()
	assert_bool(report["invariants"].has("first_purchase_early")).is_true()
	for key in report["invariants"]:
		assert_bool(report["invariants"][key].has("ok")).is_true()
		assert_str(report["invariants"][key]["detail"]).is_not_empty()
	assert_str(report["retreat_note"]).is_not_empty()
	var every_ok := bool(report["invariants"]["deeper_pays"]["ok"]) and bool(report["invariants"]["watch_beats_corpse"]["ok"]) and bool(report["invariants"]["first_purchase_early"]["ok"])
	assert_bool(sim.all_ok(report) == every_ok).is_true()


func test_sampling_is_deterministic() -> void:
	var a := BalanceSim.new()
	a.content = TestFixtures.content()
	a.runs = 1
	a.sim_fights = 2
	var b := BalanceSim.new()
	b.content = TestFixtures.content()
	b.runs = 1
	b.sim_fights = 2
	var ra := a.sample_runs()
	var rb := b.sample_runs()
	assert_int(ra["per_run"].size()).is_equal(1)
	assert_int(ra["per_run"][0]["death_floor"]).is_equal(rb["per_run"][0]["death_floor"])
	assert_int(ra["samples"].size()).is_equal(rb["samples"].size())
	assert_int(ra["samples"].size()).is_greater_equal(1)
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools\test.cmd tests/core/economy/balance_sim_test.gd`
Expected: FAIL — `BalanceSim` not declared.

- [ ] **Step 3: Implement `core/economy/balance_sim.gd`**

```gdscript
class_name BalanceSim
extends RefCounted
## The balance simulator (spec §10, §12): plays autopilot runs that always
## push, measures the deck a hero typically has at each floor, and checks
## the M1 invariants — deeper pays, watch beats the corpse, first purchase
## early. Retreat-vs-push is reported, not asserted (no EV model in M1).

var content: Content
var runs: int = 4
var sim_fights: int = 12
var seed_base: int = 1


static func is_non_decreasing(values: Array) -> bool:
	for i in range(1, values.size()):
		if float(values[i]) < float(values[i - 1]):
			return false
	return true


func sample_runs() -> Dictionary:
	var samples: Array = []
	var per_run: Array = []
	var biome: BiomeDef = content.biomes["catacombs"]
	for i in runs:
		var hero := Hero.create(content, "sexton", "Sim%d" % i)
		var run := RunEngine.start_run(content, hero, biome.id, 1, hash([seed_base, "balance", i]), true)
		var ap := RunAutopilot.new()
		ap.survival_samples = 1
		var guard := 0
		while not run.is_over() and guard < 10000:
			guard += 1
			if run.phase == "fight":
				for action in ap.fight_ap.choose_turn(run.fight):
					if run.phase != "fight":
						break
					RunEngine.apply(run, action)
			elif run.phase == "exit":
				samples.append({"run": i, "floor": run.floor, "snapshot": run.hero_snapshot(), "measured": run.stats.measured(run.floor)})
				RunEngine.apply(run, {"kind": "push" if RunEngine.can_push(run) else "watch"})
			else:
				RunEngine.apply(run, ap.choose(run))
		var outcome := run.outcome
		per_run.append({"run": i, "death_floor": int(outcome.get("floor", 0)), "kind": String(outcome.get("kind", "")), "first_run_soul": float(outcome.get("soul", 0.0))})
	return {"samples": samples, "per_run": per_run}


func floor_table(sampled: Dictionary) -> Dictionary:
	var biome: BiomeDef = content.biomes["catacombs"]
	var balance := content.balance
	var by_floor := {}
	for s in sampled["samples"]:
		var floor := int(s["floor"])
		var sim := Strength.simulate(content, s["snapshot"], biome, floor, hash([seed_base, "balance_strength", int(s["run"]), floor]), sim_fights)
		var strength := Strength.of_ghost_stats(s["measured"], sim, balance)
		var row: Dictionary = by_floor.get(floor, {"samples": 0, "strength": 0.0})
		row["samples"] = int(row["samples"]) + 1
		row["strength"] = float(row["strength"]) + strength
		by_floor[floor] = row
	var prepared := 1.0 + float(balance.get("prepared_bonus", 0.25))
	var restless := 1.0 - float(balance.get("restless_penalty", 0.3))
	var echo := float(balance.get("echo_factor", 0.75))
	for floor in by_floor:
		var row: Dictionary = by_floor[floor]
		var s := float(row["strength"]) / int(row["samples"])
		row["strength"] = s
		row["yield_watch"] = Ladder.output_for(s * prepared, int(floor), balance)
		row["yield_corpse_plus_echo"] = Ladder.output_for(s * restless, int(floor), balance) + Ladder.output_for(s * restless * echo, int(floor), balance)
	return by_floor


func report() -> Dictionary:
	var sampled := sample_runs()
	var floors := floor_table(sampled)
	var keys: Array = floors.keys()
	keys.sort()
	var yields: Array = []
	var watch_ok := true
	var watch_detail := ""
	for f in keys:
		var row: Dictionary = floors[f]
		yields.append(float(row["yield_watch"]))
		var ok := float(row["yield_watch"]) > float(row["yield_corpse_plus_echo"])
		watch_ok = watch_ok and ok
		watch_detail += "f%d watch %.2f vs corpse+echo %.2f%s; " % [int(f), float(row["yield_watch"]), float(row["yield_corpse_plus_echo"]), "" if ok else " FAIL"]
	var deeper_ok := is_non_decreasing(yields)
	var deeper_detail := "prepared yield per floor: " + str(yields) + (" (floors sampled: %s)" % str(keys))
	var founder_rate := Ladder.output_for(float(content.balance.get("founder_strength", 40)), 1, content.balance)
	var first_soul := 0.0
	if not sampled["per_run"].is_empty():
		first_soul = float(sampled["per_run"][0]["first_run_soul"])
	var twenty_minutes := founder_rate / 3.0 + first_soul
	var cheapest := INF
	for id in content.upgrades:
		var def: UpgradeDef = content.upgrades[id]
		cheapest = minf(cheapest, def.base_cost)
	var first_ok := twenty_minutes >= cheapest
	var first_detail := "Soul after 20 min: founder %.1f + first run %.1f = %.1f vs cheapest upgrade %.1f" % [founder_rate / 3.0, first_soul, twenty_minutes, cheapest]
	return {
		"floors": floors,
		"per_run": sampled["per_run"],
		"invariants": {
			"deeper_pays": {"ok": deeper_ok, "detail": deeper_detail},
			"watch_beats_corpse": {"ok": watch_ok, "detail": watch_detail},
			"first_purchase_early": {"ok": first_ok, "detail": first_detail},
		},
		"retreat_note": "invariant 3 (retreat costs) is not asserted in M1: it needs an expected-value model of Mend versus pushing that the spec does not define",
	}


func all_ok(rep: Dictionary) -> bool:
	var inv: Dictionary = rep["invariants"]
	for key in inv:
		if not bool(inv[key]["ok"]):
			return false
	return true
```

- [ ] **Step 4: Write `tools/balance_sim.gd`**

```gdscript
extends SceneTree
## Balance simulator: plays autopilot runs, prints the typical deck's ghost
## yield per floor and the spec §12 invariants. Exit 1 when an asserted
## invariant fails or the content is invalid.
## Usage: godot --headless --path . -s tools/balance_sim.gd -- [runs] [sim_fights]


func _init() -> void:
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var sim := BalanceSim.new()
	sim.content = content
	sim.runs = int(args[0]) if args.size() > 0 else 4
	sim.sim_fights = int(args[1]) if args.size() > 1 else 12
	var rep := sim.report()
	var keys: Array = rep["floors"].keys()
	keys.sort()
	print("floor samples strength yield_watch yield_corpse+echo")
	for f in keys:
		var row: Dictionary = rep["floors"][f]
		print("%5d %7d %8.2f %11.2f %17.2f" % [int(f), int(row["samples"]), float(row["strength"]), float(row["yield_watch"]), float(row["yield_corpse_plus_echo"])])
	for r in rep["per_run"]:
		print("run %d: %s at floor %d, soul %.1f" % [int(r["run"]), String(r["kind"]), int(r["death_floor"]), float(r["first_run_soul"])])
	var inv: Dictionary = rep["invariants"]
	for key in inv:
		print("%s: %s — %s" % [key, "OK" if bool(inv[key]["ok"]) else "FAIL", String(inv[key]["detail"])])
	print("note: " + String(rep["retreat_note"]))
	quit(0 if sim.all_ok(rep) else 1)
```

- [ ] **Step 5: Run the tests and the tool**

Run: `tools\test.cmd tests/core/economy`
Expected: PASS — 17 test cases, 0 failures (the simulation tests play 1–2 full runs; under a minute).

Run: `& $env:GODOT_BIN --headless --path . -s tools/balance_sim.gd -- 4 12`
Expected: a per-floor table, one line per run, three invariant lines and the retreat note; exit 0 if the slice balance holds, 1 otherwise. **Record the exit code and the three invariant lines in the task report** — a failing invariant is a balance finding for the designer, not a code defect, and does not block this task.

- [ ] **Step 6: Commit**

```bash
git add core/economy/balance_sim.gd core/economy/balance_sim.gd.uid tools/balance_sim.gd tools/balance_sim.gd.uid tests/core/economy/balance_sim_test.gd tests/core/economy/balance_sim_test.gd.uid
git commit -m "feat(economy): balance simulator with typical decks per floor and the M1 invariants"
```

---

### Task 12: Campaign demo — the whole loop headless

**Files:**
- Create: `tools/campaign_demo.gd`
- Modify: `CLAUDE.md` (the three new tools and the `core/` layout)

**Interfaces:**
- Consumes: `CampaignEngine`, `RunAutopilot`, `Seance`, `YieldSimulator`, `SaveGame`.
- Produces: `tools/campaign_demo.gd -- [seed] [runs]` — creates a campaign, then for each run: ticks ten minutes, starts at the current reach, plays with `RunAutopilot` (survival 4 samples), finishes the run, prints the outcome and epitaph, buys the cheapest affordable upgrade, creates an echo when affordable, prints the ladder (floor, ghosts, saturation, rate/h) and Soul; saves to `user://saves/demo.json` and reloads it; exit 0, exit 1 on content errors. No test: it is the demo of the tested pieces.

- [ ] **Step 1: Write `tools/campaign_demo.gd`**

```gdscript
extends SceneTree
## Headless campaign demo: a few autopilot runs with the ghost economy
## between them, then a save/load round trip.
## Usage: godot --headless --path . -s tools/campaign_demo.gd -- [seed] [runs]


func _init() -> void:
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var runs := int(args[1]) if args.size() > 1 else 3
	var now := 1000
	var c := CampaignEngine.new_campaign(content, seed_value, now)
	print("campaign seed=%d founder=%s hero=%s rate=%.1f/h" % [seed_value, c.ladder.ghosts[0].name, c.hero.name, c.rate_per_hour])
	for i in runs:
		now += 600
		var entry := CampaignEngine.reach(c)
		var run := CampaignEngine.start_run(c, entry, now)
		var ap := RunAutopilot.new()
		ap.survival_samples = 4
		ap.play_run(run)
		var result := CampaignEngine.finish_run(c, now)
		print("run %d: entry %d -> %s at floor %d, soul +%.1f%s" % [i + 1, entry, String(result["kind"]), int(result["floor"]), float(result["soul"]), (" | " + String(result["epitaph"])) if String(result["epitaph"]) != "" else ""])
		_buy_cheapest(c)
		_echo_if_affordable(c, now)
		_print_ladder(c)
	var path := "user://saves/demo.json"
	var err := SaveGame.save(c, path)
	var back := SaveGame.load(content, path)
	print("save %s, reload %s, soul %.1f" % [error_string(err), "ok" if back != null and is_equal_approx(back.soul, c.soul) else "FAILED", c.soul])
	quit(0 if err == OK and back != null else 1)


func _buy_cheapest(c: Campaign) -> void:
	var best := ""
	var best_cost := INF
	for id in c.content.upgrades:
		var cost := c.upgrades.cost(c.content, id)
		if cost >= 0.0 and cost < best_cost:
			best_cost = cost
			best = String(id)
	if best != "" and c.soul >= best_cost:
		CampaignEngine.buy_upgrade(c, best)
		print("  bought %s for %.1f" % [best, best_cost])


func _echo_if_affordable(c: Campaign, now: int) -> void:
	var source: Ghost = null
	for g in c.ladder.ghosts:
		if g.kind == "true" and g.cause != "founder" and (source == null or g.strength > source.strength):
			source = g
	if source == null or c.soul < Seance.echo_cost(c):
		return
	var r := Seance.create_echo(c, source.id, c.ladder.waypoint(), now)
	if bool(r["ok"]):
		print("  echo of %s on floor %d for %.1f" % [source.name, c.ladder.waypoint(), float(r["cost"])])


func _print_ladder(c: Campaign) -> void:
	var mods := c.modifiers()
	for f in c.ladder.floors():
		print("  floor %2d: %d ghost(s), %3.0f%% farmed, %.1f soul/h" % [f, c.ladder.on_floor(f).size(), 100.0 * c.ladder.saturation(f, c.balance(), mods), c.ladder.floor_output(f, c.balance(), mods)])
	print("  soul %.1f, rate %.1f/h, reach %d, hero %s (%d/%d hp)" % [c.soul, c.rate_per_hour, CampaignEngine.reach(c), c.hero.name, c.hero.hp, c.hero.max_hp])
```

- [ ] **Step 2: Update `CLAUDE.md`**

Add under Environment, after the run demo bullet:

```
- Campaign demo: `"$GODOT_BIN" --headless --path . -s tools/campaign_demo.gd -- [seed] [runs]`.
  Plays autopilot runs with the ghost economy between them and a save/load round trip.
- Balance sim: `"$GODOT_BIN" --headless --path . -s tools/balance_sim.gd -- [runs] [sim_fights]`.
  Prints typical-deck yield per floor and the spec §12 invariants; exit 1 when one fails.
```

Replace the `core/run/` bullet under Content with:

```
- `core/run/` is the roguelite layer (Hero, RunState + RunEngine, FloorGenerator,
  Rewards, RunProjection, RunAutopilot); `core/ghosts/` (Ghost, Strength, Ladder,
  YieldSimulator), `core/economy/` (Upgrades, Production, Seance, BalanceSim),
  `core/onboarding/` and `core/save/` form the idle layer; `Campaign` +
  `CampaignEngine` are the aggregate the UI observes and the save file stores.
  Nothing in `core/` reads the clock: every time-dependent function takes `now`.
```

- [ ] **Step 3: Run everything**

Run: `tools\test.cmd tests` — expect 242 test cases, 0 failures.
Run: `& $env:GODOT_BIN --headless --path . -s tools/campaign_demo.gd -- 1 3` — three run lines with epitaphs, ladder summaries, and a final `save OK, reload ok, soul …` line; exit 0.

- [ ] **Step 4: Commit**

```bash
git add tools/campaign_demo.gd tools/campaign_demo.gd.uid CLAUDE.md
git commit -m "feat(tools): headless campaign demo; CLAUDE.md covers the idle layer and tools"
```

---

## Plan self-review

**Spec coverage.** §3.2: exit numbers (measured yield here, simulated next, survival) — Task 9; Retreat with Resolve and paid Mend scaled by camp — Tasks 7–8; Take the Watch → prepared ghost, death → restless ghost, Coin→Soul banked — Task 7. §3.3: creation with meta stats and Resolve from upgrades, generated names, new hero after a ghost — Task 7. §3.4: the Founder at second zero, Take the Watch locked until the first death, the free first Tend — Tasks 3, 7, 8. §5.1 ghost record (name, class, deck, relics, stats, floor, kind, cause, prepared/restless, created_at, epitaph, measured, cached strength; priority rules are M2) — Task 3. §5.2 ghost-time, measured/simulated blend with `w = n/(n+3)`, 50-fight simulation, computed on placement and on change — Tasks 2, 7, 8. §5.3 soft cap, saturation, marginal yield — Task 4. §5.4 Soul and Coin (Ink and biome claims are M2) — Tasks 7, 8. §5.5 echoes with the source cap and cost curve, Calls at 25%, Tend clearing restless (first free, cost scaling with floor), echoes inheriting and shedding restless with their source (laying to rest is M2) — Tasks 3, 8. §5.8 production by real time, offline cap with the upgrade, "while you were away" numbers on load — Tasks 6, 7, 10. §5.9 ten upgrades with ×1.6 costs, base costs in data — Tasks 1, 5, 7. §8 `core/ghosts`, `core/economy`, `core/onboarding`, `core/save` and the save file with version, backups and migrations — Tasks 3–10. §10 `tools/balance_sim.gd` reporting death floors, yields and the invariants — Task 11. §12: invariant 1 and 2 asserted, 5 asserted, 3 reported only (the spec gives no EV model for Mend vs push; M2 can add one), 4 is M2. §11 M1 list: every item except the UI (M1-C) and the explicitly excluded features.

**Decisions the spec leaves open (made here):** the Founder's strength is a balance number (40 kills/h ≈ 62% of floor 1); meta stat upgrades apply to the living hero immediately as well as to future heroes; buying max Resolve also grants the point; echoes inherit `restless` from their source and Tend clears it on the source and its echoes; the balance simulator's "typical deck at depth f" is the autopilot's deck at the exit of floor f when always pushing; corpse-plus-echo is evaluated on the same floor (the echo's best floor under the source cap); offline catch-up happens on load and before every run start; the campaign ticks with the cap even while live (live ticks never approach it); `sim_fights` on the campaign lets tests and the demo trade accuracy for time.

**Placeholder scan.** Every step has its code; no TBD/TODO; every referenced function exists in this plan or in M1-A/M1-B1 (`RunEngine.start_run/apply/exit_summary/can_push`, `RunState.hero_snapshot/stats/outcome/to_dict/from_dict`, `RunAutopilot.choose/fight_ap`, `Hero.create/generate_name/recompute_max_hp/to_dict/from_dict`, `FightSimulator.simulate_table`, `Rewards.soul_for`, `Content.normalize_json`, `TestFixtures.hero/set_nodes/autofight/content`).

**Type consistency.** `Ghost.measured` keys `fights/wins/win_rate/avg_turns` match `RunStats.measured`; `Strength.simulate` returns the same four keys; the modifiers dictionary shape is produced by `Upgrades.modifiers` and read by `Ladder`, `Production`, `Seance`, `CampaignEngine`; `Seance`/`CampaignEngine` mutators all return `{ok, cost, reason}` (+ `ghost_id`); `Campaign.sim_fights` flows into `Strength.simulate`'s `fights` parameter (−1 = balance); `SaveGame.load_and_catch_up` returns `{"campaign", "offline"}` with `Production.accrue`'s keys. Expected counts assume the suite starts at 188: content 31 after Task 1; ghosts 5/10/17/20 after Tasks 2/3/4/9; economy 4/8/14/17 after Tasks 5/6/8/11; campaign 8; save 6; the whole tree 242 after Task 12.
