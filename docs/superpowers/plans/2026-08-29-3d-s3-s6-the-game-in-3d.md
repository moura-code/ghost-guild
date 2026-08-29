# Stages 3–6 — The Game in 3D

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.
> Executed inline in the authoring session, TDD per task, one commit per task, per the project owner's standing preference.

**Goal:** Finish the pivot. The fight happens where you stand, the floor loop is played rather than auto-resolved, the guild is a walkable room with your dead standing in a well, and death is a beat you look at — then the replaced 2D world comes out of the tree.

**Architecture:** One `Crawl` root owns two places — the guild (no run) and the dungeon (a run) — and one `HudRoot` that hosts the 2D panels over whichever is live. 3D is the world; 2D is everything you read. `core/` is untouched: every panel already speaks `bind(game, run)` / `refresh()`, and the fight animator already consumes the engine's event stream, so what changes is *where the reaction is drawn*, not what drives it.

**Tech Stack:** Godot 4.7.2 Forward+, GDScript, GdUnit4.

**Spec:** `docs/superpowers/specs/2026-08-29-3d-pivot-design.md` (stages 3–6 of §9; §8 for the module map).

**Predecessor:** `2026-08-29-3d-s2-it-can-be-walked.md`. Baseline entering this plan: **667 test cases, 70 suites, green, exit 0.**

## Global Constraints

- Godot 4.7.2; `GODOT_BIN`; tests via `cmd //c "tools\\test.cmd tests"`, exit 0.
- **`core/` and `data/` are not touched by this plan.** Not one line. If something looks like it needs a core change, it is a presentation problem wearing a disguise — say so and stop.
- Nothing under `game/world/`, `game/fight/` or `game/hud/` writes to `RunState`. The only channel is `GameRoot.run_action` → `RunEngine.apply` (spec §4). `Crawl` is the only node that holds a `GameRoot`.
- Static typing everywhere. Commit every `.gd.uid` beside its `.gd`.
- Player-facing strings are keys resolved against `data/strings/en.csv`. **No new English string literals in code.** If a new line is needed, it goes in the CSV.
- Geometry comparisons use `is_equal_approx` — `Vector3` components are 32-bit.
- The suite is `--headless`: nothing handed to the RenderingServer reads back. Geometry and layout maths live in pure functions the tests can read. Physics and `Input.action_press` **do** work.

## The ruling that reshapes this plan

Spec §3.2 says "every screen under `game/screens/` and `game/run/`" is deleted. Written before implementation, that was a guess, and it is wrong in one specific way worth stating rather than quietly ignoring:

**The spec's own argument for keeping cards in 2D applies to every panel.** "A card rendered in perspective is a card you cannot read" is not an argument about cards. It is an argument about text and choice. A shop list, a rest menu, an exit decision and a ladder of ghosts are the same object.

So the line is drawn differently, and the new line is sharper than the old one:

| | Fate |
|---|---|
| The 2D **world** — `atmosphere.gd` + its three shaders, `palette_layer.gd`, `props.gd`, `stone_box.gd`, `doorway_view.gd`, `enemy_view.gd` | **Deleted.** 3D is the world now. |
| The 2D **navigation and framing** — `main.gd`/`main.tscn`, `run_router.gd`, `floor_map_screen.gd`, `fight_screen.gd`, `fight_animator.gd`, `nav_bar.gd`, `transition.gd` | **Deleted.** You walk to places now; there are no tabs and no screen swaps. |
| The 2D **panels** — `choice_screen`, `exit_screen`, `epitaph_screen`, `guild_screen`, `seance_screen`, `hero_screen`, `ladder_screen`, `offline_summary` | **Kept**, re-hosted in `HudRoot`. They already take `bind(game, run)` and know nothing about what is behind them. |
| The 2D **furniture** — `card_view`, `hero_panel`, `float_number`, `turn_banner`, `upgrade_plaque`, `fate_panel`, `ghost_line`, `ghost_mark`, `wallet_bar`, `tower_view`, `ui_theme`, `palette`, `icons`, `ticker`, `screen_layout`, `num`, `sfx` | **Kept.** |

Rewriting eight working, tested panels to say the same words in a different file is not progress. `tower_view.gd` survives too: the 3D well is the *pitch* image, the ladder panel is how you actually read twenty floors of ghosts.

Net: about **1,900 lines deleted**, not 7,000, and roughly 24 test suites become 6.

## File Structure

| File | Responsibility |
|---|---|
| `game/hud/hud_root.gd` | `CanvasLayer`. The 2D layer over the 3D world, scaled so panels authored at 640×360 fill any window. Owns panel show/hide and the mouse mode that goes with it. |
| `game/hud/hand_view.gd` | The fan of `CardView`s at the bottom of the screen. Emits `card_pressed(hand_index)`. |
| `game/hud/enemy_tag.gd` | Name, HP bar and intent for one enemy, drawn in 2D at the enemy's projected screen position. |
| `game/hud/prompts.gd` | The floor banner and the "press E" interact line. |
| `game/fight/enemy_body.gd` | `Node3D`. The thing standing in the room: mesh, recoil, death. Mesh is a stand-in behind one function. |
| `game/fight/fight_animator_3d.gd` | The engine event stream → 3D reactions and 2D numbers. Port of `fight_animator.gd`'s beat/hit-stop/stagger; the reactions change, the pacing does not. |
| `game/fight/fight_director.gd` | Stages the fight: places bodies, locks the camera, runs targeting and the turn, ends it. |
| `game/world/interactable.gd` | `Area3D` you walk up to and press E on. The guild's furniture and the dungeon's stairs are all this. |
| `game/world/ghost_figure.gd` | A dead hero standing where it died. |
| `game/world/guild_room.gd` | The walkable guild: table, circle, desk, well, ladder down. |
| `game/world/well_view.gd` | The tower of floors seen down the well, with your ghosts on them. |
| `game/world/crawl.gd` (rewrite) | Two places, one root: guild when there is no run, dungeon when there is. |
| `game/theme/grade.gd` (extend) | `guild_environment()` — the one room in the game that is not a crypt. |
| Deleted | see the ruling table above, plus each one's suite. |

---

## Stage 3 — The fight happens where you stand

### Task 1: `HudRoot` — 2D over 3D

**Files:** create `game/hud/hud_root.gd`, `tests/game/hud_root_test.gd`

**Interfaces produced:**
- `HudRoot.REFERENCE := Vector2(640, 360)`
- `HudRoot.scale_for(viewport: Vector2) -> float` (static, pure — this is the testable part)
- `hud.ui: Control` — the 640×360 space children lay out in
- `hud.show_panel(panel: Control) -> void`, `hud.clear_panel() -> void`, `hud.panel: Control`
- `hud.set_pointer(on: bool) -> void` — mouse visible and cards clickable, or captured and the player looking

**Decisions:** the panels and every kept widget were authored against a 640×360 viewport (`CardView.CARD_SIZE` is 82×159, `UiTheme` font sizes match). Stage 2 moved the viewport to 1280×720 native so the 3D renders sharp. Rather than rescale thirty widgets, the HUD carries one scale: `ui.scale = min(vw/640, vh/360)` and `ui.size = viewport / scale`, so children keep authoring in the coordinates they already use. Fractional, not integer — the pixel-art constraint that demanded integer scaling died with `PaletteLayer`.

**Tests:** scale at 1280×720 is 2.0 and at 1920×1080 is 3.0; a window narrower than 640 does not scale below 1.0; `ui` is sized so its bottom-right lands on the window's; showing a panel frees the previous one and leaves exactly one child; `set_pointer(true)` releases the mouse and `false` captures it.

- [ ] Write `tests/game/hud_root_test.gd` · run it, watch it fail · write `game/hud/hud_root.gd` · run it green · commit.

### Task 2: `HandView` — the cards, over the room

**Files:** create `game/hud/hand_view.gd`, `tests/game/hand_view_test.gd`

**Interfaces produced:**
- signal `card_pressed(hand_index: int)`
- `hand.bind(content: Content) -> void`
- `hand.show_hand(fight: FightState, playable: Dictionary) -> void`
- `hand.selected: int`, `hand.select(index: int) -> void`
- `hand.views: Array[CardView]`
- `HandView.fan(count: int, width: float) -> Array` (static, pure) → one `{"position": Vector2, "angle": float}` per card

**Decisions:** `fan()` comes out of `fight_screen.gd:390` as a static function of `(count, width)` so the arc is testable without a tree — the old one read node sizes mid-layout and could only be checked by eye. `CardView` is used unchanged, including `fly_in`/`fly_out`/`set_selected`, so the deal and discard animations survive the pivot for free.

**Tests:** a five-card hand makes five views bound to the five cards; the fan is symmetric about the centre and its outer cards are rotated outward; a one-card hand is centred and unrotated; unplayable cards are marked; pressing a view re-emits with its hand index; selecting one deselects the rest; showing a shorter hand frees the extra views.

- [ ] Write the test · fail · implement · green · commit.

### Task 3: `EnemyBody` — the thing in the room

**Files:** create `game/fight/enemy_body.gd`, `tests/game/enemy_body_test.gd`

**Interfaces produced:**
- `EnemyBody.create(def: EnemyDef, index: int) -> EnemyBody`
- `body.index: int`, `body.head_point() -> Vector3`
- `body.recoil(amount: int) -> void`, `body.die() -> void`, `body.dying: bool`
- `body.set_highlight(on: bool) -> void`
- `EnemyBody.LAYER_ENEMY := 8` (layer 4, "ghost" in the project's layer names, reused for bodies you can click)
- `EnemyBody.stand_in_mesh(def: EnemyDef) -> Mesh` — **the one function a real model replaces**

**Decisions:** there is still no rigged enemy model (the open question from stage 0), and the pivot must not stall on it. So the body is a capsule-and-head stand-in whose proportions come from the enemy's `hp`/`size` so a `bone_rat` and the `mother_of_bones` are visibly different creatures. It is isolated in one static function, and swapping in a `.glb` changes that function and `recoil`/`die` to drive an `AnimationPlayer` instead of a tween. Everything else — staging, targeting, the animator, the HUD — is model-agnostic and is being built now rather than after the art question resolves. **Written down so nobody mistakes the stand-in for a decision about the art.**

**Tests:** a body is created per enemy with its index; the stand-in's height scales with the enemy's hp so two enemy kinds differ; the head point is above the origin and inside the body; recoil moves it and it returns; `die()` sets `dying` and it stops being clickable; it sits on the enemy layer with a collision shape a camera ray can hit.

- [ ] Write the test · fail · implement · green · commit.

### Task 4: `FightAnimator3D` — the event stream, in the room

**Files:** create `game/fight/fight_animator_3d.gd`, `tests/game/fight_animator_3d_test.gd`

**Interfaces produced:**
- signal `shake_requested(strength: float)`, `hit_landed(event: Dictionary)`, `finished()`
- `animator.bind(content: Content, sfx: Sfx) -> void`
- `animator.play(events: Array, anchors: Dictionary) -> void` — `anchors` maps `"hero"` and each enemy index to a **screen** position, exactly as the 2D animator did
- `animator.last_spawned: Array[FloatNumber]`
- constants `BEAT`, `HIT_STOP`, `SHAKE_PER_DAMAGE`, `SHAKE_MAX`, `BIG_HIT` carried over unchanged

**Decisions:** the 2D animator's *pacing* is the part that made fights feel like fights — one beat per blow, hit-stop on a heavy hit, numbers staggered so a multi-hit does not stack on one pixel — and it is presentation-neutral. It is carried over as-is. What changes is that anchors are now projected from 3D each beat rather than read off a layout, so `play()` takes a `Callable` supplier instead of a fixed dictionary: `anchors` is re-asked per beat, because a recoiling body has moved. The old animator is deleted in the cleanup task, not here, so both exist while this one is proven.

**Tests:** each event type produces the number, colour and beat the 2D animator produced (the existing `fight_animator_test.gd` assertions are the specification and are ported); a fully-absorbed hit still spawns a "blocked" beat; shake scales with damage and clamps at `SHAKE_MAX`; a big hit or a death adds hit-stop; `hit_landed` fires per blow, not per turn; an event whose anchor is missing is counted but spawns nothing; `finished` fires once, after the last beat.

- [ ] Write the test · fail · implement · green · commit.

### Task 5: `FightDirector` — staging and the turn

**Files:** create `game/fight/fight_director.gd`, `tests/game/fight_director_test.gd`

**Interfaces produced:**
- signal `fight_finished()`
- `director.begin(game: GameRoot, hud: HudRoot, player: Player, at: Vector3) -> void`
- `director.bodies: Array[EnemyBody]`, `director.living_bodies() -> Array`
- `FightDirector.stage_points(count: int, at: Vector3, facing: Vector3) -> Array` (static, pure)
- `director.play_card(hand_index: int, target: int) -> void`, `director.end_turn() -> void`
- `director.target_under(screen: Vector2) -> int` — camera ray → enemy index, `-1` for none

**Decisions:** the camera does not cut away. This is a first-person game, so "the camera locks to it" (spec §8) means the player's own body is frozen and its head is tweened to face the group — you are still looking through your own eyes, which is the whole point of the pivot. `Player` gains `frozen: bool` (zeroes the wish vector, gravity still applies) and the mouse is released so cards are clickable; targeting is a camera ray at the mouse. With one living enemy, targeting is skipped and the card plays on it — most fights are one enemy and asking the player to click it is friction, not depth.

**Tests:** three enemies get three bodies on an arc, all in front of the player and none inside another; `stage_points` is symmetric and its spacing does not depend on `at`; the player is frozen and the mouse released on `begin`, and both are restored on the last enemy dying; playing a card forwards exactly one action through `run_action` and no other write reaches the run; ending the turn forwards `end_turn`; a card played with one living enemy needs no target; `fight_finished` fires once when the fight ends; a dead body stops answering `target_under`.

- [ ] Write the test · fail · implement · green · commit.

### Task 6: Wire it into `Crawl`

**Files:** modify `game/world/crawl.gd`, `tests/game/crawl_test.gd`; create `game/hud/prompts.gd`, `tests/game/prompts_test.gd`

**Decisions:** the `_settle_to_node()` autopilot scaffolding from stage 2 loses its `fight` branch here — walking into a fight room now starts a real fight. The other phases keep auto-resolving until stage 4. The floor banner ("Floor 3") and the interact prompt move to `Prompts`.

**Tests:** walking into a fight room stages bodies and shows the hand instead of auto-resolving; winning returns control to the player and resolves the marker; the run's phase moves `node → fight → …` through the engine only; the floor banner announces on `floor_built`.

- [ ] Write the tests · fail · implement · green · **full suite** · commit.

---

## Stage 4 — The floor loop

### Task 7: The non-fight rooms are played, not skipped

**Files:** modify `game/world/crawl.gd`; move `choice_screen.gd` → `game/hud/`, `exit_screen.gd` → `game/hud/`; modify their tests' paths only; `tests/game/crawl_loop_test.gd`

**Decisions:** `ChoiceScreen` already handles `reward`, `event`, `rest`, `shop` and `descent` and `ExitScreen` already handles the exit decision, both against a live `RunState`. They are hosted in `HudRoot` over the room the player is standing in. `_settle_to_node()` is deleted entirely — nothing is auto-resolved any more, which is what closes the stage-2 scaffolding. The stairs become an `Interactable` you press E on, showing `ExitScreen`, whose `decided(kind)` forwards `push`/`retreat`/`watch`.

**Tests:** every phase the run can be in has a host and none falls through to the autopilot; a reward is taken through `run_action` and the panel closes; the descent draft shows on run start instead of being auto-picked; the stairs interactable only opens at phase `exit`; choosing `push` builds the next floor and the fog is denser; `retreat` and `watch` end the run.

- [ ] Write the tests · fail · implement · green · **full suite** · commit.

---

## Stage 5 — The guild is a place

### Task 8: `Interactable` and `GhostFigure`

**Files:** create `game/world/interactable.gd`, `game/world/ghost_figure.gd`, `tests/game/interactable_test.gd`, `tests/game/ghost_figure_test.gd`

**Interfaces produced:**
- `Interactable.create(id: String, at: Vector3, label_key: String) -> Interactable`; signals `focused(id)`, `blurred(id)`, `used(id)`; `LAYER_INTERACTABLE := 4`
- `GhostFigure.create(ghost: Ghost, at: Vector3) -> GhostFigure`; `figure.ghost_id: int`

**Decisions:** one interactable type for the whole game — the guild's four stations, the dungeon's stairs, and later anything else. It reports focus so `Prompts` can show "press E"; it never acts. A ghost figure is a pale, translucent, slowly-bobbing stand-in on the same swap-one-function basis as `EnemyBody`.

**Tests:** focus fires on approach and blur on leaving; pressing E only fires while focused; a ghost figure carries its ghost's id and stands on the floor; it is not solid — you walk through your dead, you do not bump into them.

- [ ] Write the tests · fail · implement · green · commit.

### Task 9: `GuildRoom` and `WellView`

**Files:** create `game/world/guild_room.gd`, `game/world/well_view.gd`, `tests/game/guild_room_test.gd`, `tests/game/well_view_test.gd`; extend `game/theme/grade.gd`

**Decisions:** the guild is hand-placed, not generated — it is one room the player returns to a thousand times and it is the Steam capsule shot, so it is authored. Four stations (upgrade table, séance circle, hero desk, ladder down) plus the well. `Grade.guild_environment()` is warmer and less foggy than any crypt floor: the guild is the only safe place in the game and it should read that way before a word is on screen. `WellView` builds a tower of floor discs down the shaft with a `GhostFigure` on each floor that has one — the pitch, made literal.

**Tests:** the room is enclosed and every station stands on walkable floor; the four stations have distinct ids; the well is a hole you can look down and not fall through; the tower has one disc per floor of the biome and one figure per ghost, on the floor its record names; a ghost on a floor beyond the tower's depth is clamped rather than dropped; the guild grade is brighter and less foggy than floor 1's.

- [ ] Write the tests · fail · implement · green · commit.

### Task 10: `Crawl` becomes two places

**Files:** modify `game/world/crawl.gd`; move the four guild panels into `game/hud/`; `tests/game/crawl_guild_test.gd`

**Decisions:** no run → guild; a run → dungeon. Descending is walking into the ladder. The four stations open the panels that already exist (`GuildScreen`, `SeanceScreen`, `HeroScreen`, `LadderScreen`), and `OfflineSummary` shows once on boot as it always did.

**Tests:** booting with no run builds the guild and not a dungeon; using the ladder starts a run and builds floor 1; finishing a run returns you to the guild; each station opens its own panel and closes it on Escape; the offline summary shows once and only when there is something to show; your ghosts are standing in the well.

- [ ] Write the tests · fail · implement · green · **full suite** · commit.

---

## Stage 6 — Death

### Task 11: The epitaph beat

**Files:** modify `game/world/crawl.gd`; move `epitaph_screen.gd` → `game/hud/`; `tests/game/crawl_death_test.gd`

**Decisions:** the run ends, the world does not cut. The hand fades, the fight music stops, the killer stays standing where it is, and a `GhostFigure` rises where the hero fell — then `EpitaphScreen` fades up over it. Dismissing it returns to the guild, where that same ghost is now in the well. This is the shot the trailer opens on (spec §8), so it is a sequence with beats and not a screen swap.

**Tests:** a run that ends in death raises a ghost figure at the player's position before the panel shows; a retreat shows no epitaph and no figure — nobody was left behind; dismissing returns to the guild; the new ghost is in the well's tower on the floor it died on.

- [ ] Write the tests · fail · implement · green · commit.

---

## Cleanup

### Task 12: The 2D world comes out

**Files:** delete per the ruling table, plus each file's `.uid` and its suite; rewrite `ART_BRIEF.md`; update `CLAUDE.md` and the spec.

**Decisions:** deletion happens **last and in one commit**, so that every deleted file has a working replacement in the tree before it goes, and so that one `git revert` puts the 2D game back. `main` remains the fallback regardless (spec §12).

**Steps:** delete the world/navigation files and suites · run the full suite · boot the game and walk guild → dungeon → fight → death → guild · take three shots (guild, corridor, fight) · record the stage 3–6 results in this plan · commit.

- [ ] Delete · full suite green · boot and walk it · shots · record · commit.

## Self-review

**Spec coverage.** §9 stage 3 → Tasks 1–6. Stage 4 → Task 7. Stage 5 → Tasks 8–10. Stage 6 → Task 11. §8's module map is covered except `theme/sfx.gd`'s "plus 3D positional audio", which is **deliberately deferred**: positional audio needs the source positions the fight staging produces, and adding it before the staging exists means guessing. It is recorded as not done rather than silently dropped. §3.2's deletion list is honoured by the ruling table with the one documented reversal (panels are kept), and executed in Task 12.

**Placeholder scan.** Every task names its files, its produced interfaces, its decisions and its tests. Implementation bodies are not transcribed: the author is the executor, holds the full context, and the project owner has asked for inline execution over hand-off. This is a deliberate departure from the skill's default and is the only one.

**Type consistency.** `HudRoot.ui` is the parent every panel and `HandView` attaches to. `FightDirector` consumes `HudRoot`, `Player` and `EnemyBody`, and hands `FightAnimator3D` a screen-space anchor supplier — the same `{"hero": Vector2, 0: Vector2, …}` shape `fight_animator.gd` already documents, so the ported assertions still mean what they meant. `EnemyBody.LAYER_ENEMY = 8` and `Interactable.LAYER_INTERACTABLE = 4` are bit values on layers 4 and 3, matching the constant already in `encounter_marker.gd`. `Ghost` is the existing `core/ghosts/ghost.gd`; `GhostFigure.ghost_id` matches its `id`.
