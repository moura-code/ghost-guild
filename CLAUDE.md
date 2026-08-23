# Ghost Guild

Card-battling roguelite (Godot 4.7.2, GDScript, GdUnit4): the living hero is
the roguelite, dead heroes become idle-farming ghosts.

## Environment

- `GODOT_BIN` env var points at the Godot 4.7.2 executable; all commands use it.
- Tests: `tools\test.cmd <dir-or-file>` (Git Bash: `cmd //c "tools\\test.cmd tests"`).
  It runs `--import` first, then the GdUnit4 headless runner — required because
  Godot's `-s` script runner only sees `class_name` scripts after the editor's
  class cache is rebuilt by an import pass. Exit code 0 on success.
- Demo: `"$GODOT_BIN" --headless --path . -s tools/fight_demo.gd -- <enemy_id ...>`.
  Runs one narrated autopilot fight plus a 50-fight simulation summary.
  Exit 0 on success; exit 1 on content validation errors or an unknown enemy id.
- Run demo: `"$GODOT_BIN" --headless --path . -s tools/run_demo.gd -- [entry_floor] [seed]`.
  Plays one autopilot run and prints its event log plus an `OUTCOME` line.
  Exit 1 on content validation errors or an entry floor outside 1..10.
- Campaign demo: `"$GODOT_BIN" --headless --path . -s tools/campaign_demo.gd -- [seed] [runs]`.
  Plays autopilot runs with the ghost economy between them and a save/load round trip.
- Balance sim: `"$GODOT_BIN" --headless --path . -s tools/balance_sim.gd -- [runs] [sim_fights]`.
  Prints typical-deck yield per floor and the spec §12 invariants; exit 1 when one fails.

## core/ rules

- Everything under `core/` extends `RefCounted` only: no `Node`, no scene tree.
- No engine randomness (`randi()`, `randf()`, `shuffle()`, `pick_random()`).
  All randomness goes through `Rng`'s named streams so runs replay from a seed.
- Engine functions mutate a state object and return the events they produced:
  `apply(state, action) -> events`. Events are `Dictionary` values with a
  `"type"` key, appended via `state.emit(...)`.
- Static typing everywhere; `Variant` only where JSON parsing forces it.
- Event payloads are immutable snapshots: copy (`duplicate()`) any array or
  dictionary you put in an event or keep as live state, because Godot's
  `Array(from)` returns the same array, not a copy.

## Sidecars

- Commit every `.gd.uid` sidecar alongside its `.gd` file.
- Every loader-read CSV (e.g. `data/strings/en.csv`) has a committed
  `<name>.csv.import` with `importer="keep"`, so Godot treats it as plain data.
- Never commit `*.translation` files.

## Content

- Game data lives under `data/` (cards, enemies, relics, classes, biomes,
  affinity, balance, events) loaded by `Content.load_from`. Player-facing
  strings are keys resolved against `data/strings/en.csv`.
- The shipped slice content is validated by
  `tests/core/content/slice_content_test.gd`.
- `core/run/` is the roguelite layer (Hero, RunState + RunEngine, FloorGenerator,
  Rewards, RunProjection, RunAutopilot); `core/ghosts/` (Ghost, Strength, Ladder,
  YieldSimulator), `core/economy/` (Upgrades, Production, Seance, BalanceSim),
  `core/onboarding/` and `core/save/` form the idle layer; `Campaign` +
  `CampaignEngine` are the aggregate the UI observes and the save file stores.
  Nothing in `core/` reads the clock: every time-dependent function takes `now`.

## Docs

- Specs: `docs/superpowers/specs/`. Plans: `docs/superpowers/plans/`.
