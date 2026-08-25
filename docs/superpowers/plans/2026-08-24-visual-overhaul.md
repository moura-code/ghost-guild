# Visual Overhaul Implementation Plan

**Goal:** Make Ghost Guild look like a game someone would buy — a real light
model, a focal hierarchy, objects with weight, ambient motion on every screen,
and generated card and enemy art landing in a layout that can carry it.

**Architecture:** Nothing under `core/` changes. All work is in `game/` plus
`tools/art/` and `tools/screenshot.gd`. Three new files carry the new
concerns — `game/theme/ticker.gd` (numbers that count), `game/widgets/props.gd`
(drawn decor), and an extended `Atmosphere` (focus falloff, flicker, fog) —
and every screen composes from them instead of inventing its own.

**Tech Stack:** Godot 4.7.2, GDScript with static typing, GdUnit4, one
`canvas_item` shader, ComfyUI + SDXL base 1.0 at `C:\ComfyUI` for raster art.

**Spec:** `docs/superpowers/specs/2026-08-24-visual-overhaul-design.md` —
binding authority. Parent: `2026-08-21-ghost-guild-design.md` §9.

**Execution:** Inline, in this session — not subagent-driven. Joao asked for
this on 2026-08-24 because dispatch round trips cost too much wall clock, the
same call made for M1-C2. Consequence for this document, stated plainly: it is
a **design and task plan, not a code transcript.** It carries file targets,
interfaces, decisions already made and the test strategy — everything that
would otherwise get re-litigated mid-task — but not verbatim implementations,
because the person implementing it wrote it.

**What survives from the subagent discipline:** a real failing test before
every behavioural change, verification by running commands rather than by
assertion, reading my own diff before committing, and the ruling ledger at
`docs/superpowers/plans/visual-overhaul-rulings.md`.

## Starting State

`main` at `b593af6`, **498 GdUnit4 tests green**, plus one uncommitted change
in `game/widgets/tower_view.gd` (undug floors drawn as masonry) which Task 4
completes rather than discards.

## Global Constraints

- **Nothing under `core/` is modified.** If a task appears to need a core
  change, stop and report it — that is a plan defect, not a licence.
- Static typing everywhere; `project.godot` sets
  `gdscript/warnings/untyped_declaration=1`.
- **No colour literals outside `palette.gd`.** Widgets name a palette entry.
  This is the existing rule and the overhaul depends on it holding.
- Every player-facing string stays a key in `data/strings/en.csv`.
- Commit every `.gd.uid` sidecar alongside its `.gd`.
- The suite stays green at every commit. **498 tests is the floor**, never
  the target — tests are added, never removed to pass.
- Appearance is judged by eye from the contact sheet. Tests assert *rules*
  (a background is darker than its content; a ticker reaches its target and
  stops), never pixels or tween interpolation.

---

## Task 1 — The look-at-it loop

Everything after this is judged by eye, so the eye needs one command.

**Files:** Modify `tools/screenshot.gd`.

**Produces:** `godot --path . -s tools/screenshot.gd -- <out_dir> all` writes
all twelve screens plus `sheet.png`, a labelled contact sheet.

The existing tool takes one screen per process launch, and the `ladder` branch
deliberately skips the rich-campaign setup — which is why the game's signature
screen is the one screen that is only ever captured empty. Both get fixed: one
launch captures every screen, and the Ladder is captured twice, once at second
zero and once with a populated tower.

**Test:** none. This is a dev tool; its output is the test.

**Stop-here value:** every later change is visible in one command.

---

## Task 2 — The light model

**Files:** Modify `game/theme/palette.gd`, `game/theme/crypt.gdshader`.
Test: `tests/game/theme_test.gd`.

The palette ladder from spec §3.1, and the shader stops competing: `stone`
drops to roughly a quarter of its current value, the edge pillars fall into
shadow instead of brightening by 60%, the second rank of arches is removed and
the first is deepened until it reads as an opening, and the vignette tightens.

**Interfaces produced:** `Palette.ABYSS`, `Palette.LANTERN`, and
`Palette.luma(c: Color) -> float` for the tests below.

**Test strategy — rules, not pixels:**
- The value ladder is monotonic: `luma(ABYSS) < luma(STONE) < luma(STONE_RAISED)
  < luma(STONE_HIGH) < luma(STONE_EDGE) < luma(BONE)`.
- The ladder actually spans: `luma(BONE) - luma(ABYSS) > 0.80`. This is the
  test that fails today and is the whole point of the task.
- `EDGE_LIGHT` and `LANTERN` are warm: `r > b`.
- `GHOST` is the only cool accent: no other non-status palette entry has
  `b > r` by more than a small margin.

---

## Task 3 — The focus rule

**Files:** Modify `game/theme/atmosphere.gd`, `game/theme/crypt.gdshader`;
each screen sets its rect. Test: `tests/game/atmosphere_test.gd`.

`Atmosphere.focus_rect: Rect2` in screen space, pushed to the shader as a
normalised centre and radius; outside it the ground falls off toward `ABYSS`.
Default is the full rect, so a screen that declares nothing is unchanged.

**Test:** setting a focus rect leaves the shader parameter matching it;
clearing it restores the default. Assert the parameter, not the render.

---

## Task 4 — The six defects

Folded into one task because each is small and they share a verification pass.

**Files:** `game/theme/icons.gd:21` (prefer `.png`, fall back to `.svg`),
`game/widgets/tower_view.gd:203` (draw undug rock into the tapered
`chamber_rect`, completing Joao's uncommitted change), `game/widgets/card_view.gd`
(body text must not clip — shrink or grow the box until the longest card text
in `data/` fits), `game/run/fight_screen.gd:398` (hand step so rules text is
not occluded), `game/main.gd` (move the Soul/rate header out of
`ladder_screen.gd` so Guild and Séance show the wallet), and a rewrite of
`ART_BRIEF.md` whose palette table, card-art section and backdrops section are
all stale.

**Tests:**
- `Icons.get_icon` returns the `.png` when both exist, the `.svg` when only it
  does, and `null` when neither — this is the one that unblocks Task 9.
- No card's rendered body text is truncated, driven over every card in
  `Content` rather than one sample.
- The Soul header is present on all four idle tabs.
- `tower_view` draws undug rock no wider than `chamber_rect(floor)`.

---

## Task 5 — Motion primitives

**Files:** Create `game/theme/ticker.gd`. Modify `game/theme/ui_theme.gd`
(button hover/press response), `game/theme/atmosphere.gd` (lantern flicker,
fog drift). Test: `tests/game/ticker_test.gd`, `tests/game/theme_test.gd`.

`Ticker` takes a `Label`, a `Callable` formatter and a target, and counts.
`Num` stays a pure static formatter and is not touched.

**Test:** a ticker driven to a target ends at exactly that target and its
label shows the formatted value; a second `to()` mid-flight retargets rather
than stacking tweens; a freed label does not crash the ticker. State only —
no interpolation assertions.

---

## Task 6 — The object layer

**Files:** Create `game/widgets/props.gd`. Test: `tests/game/props_test.gd`.

Drawn decor with no assets: candle with flame, hanging chain, bone pile,
banner, ritual circle, water drip, floor rubble. Static draw helpers taking a
`CanvasItem` plus a rect, so any screen can compose without owning nodes.

**Test:** each helper draws within the rect it is given (assert via a
`Rect2` the helper reports, not by reading pixels), and none of them reads a
colour outside `Palette`.

---

## Task 7 — Screen recomposition

The eight screens the review called out, in worst-first order: Séance, Hero,
Event, offline summary, Epitaph, Shop, floor map, reward picker.

**Files:** `game/screens/seance_screen.gd`, `game/screens/hero_screen.gd`,
`game/run/choice_screen.gd` (event, shop, reward), `game/screens/offline_summary.gd`,
`game/run/epitaph_screen.gd`, `game/run/floor_map_screen.gd`.

Each gets: a declared focus rect, props filling the dead space, its numbers on
tickers, and its "things" made into objects — the deck as a fanned stack, relics
as plates, currencies as chips, the event titled with its own name instead of
the literal string "An event".

The offline summary is rebuilt as a payoff sequence rather than a dialog: the
total counts from zero while motes stream up the tower behind it.

**Tests:** the existing per-screen suites keep passing, extended with the new
bound state (an event screen shows the event's name; the hero screen lists one
`CardView` per distinct card rather than a text line).

---

## Task 8 — The Ladder as the capsule

Separate from Task 7 because it is the store page, the first screenshot and
the first three seconds of the trailer, and it is currently the weakest screen.

**Files:** `game/widgets/tower_view.gd`, `game/widgets/ghost_mark.gd`,
`game/screens/ladder_screen.gd`.

Lit chambers get the frame; undug rock recedes rather than dominating.
Saturated floors pulse, the waypoint marker animates when it moves, new ghosts
ease into their row, and soul motes drift up the shaft.

**Tests:** extend `tests/game/ladder_screen_test.gd` — the marker moves when
the waypoint does, a newly placed ghost animates in and ends at its row
position, and `chamber_rect` still tapers with depth.

---

## Task 9 — Generated art

Unblocked by Task 4's PNG loader. Ordered last so the art lands in a finished
layout, per spec §2.6.

**Files:** Modify `tools/art/generate.py` and `tools/art/PROMPTS.md`. Output
into `assets/icons/card_art/`, `assets/icons/enemies/`, `assets/icons/relics/`,
`assets/backdrops/`. Update `ATTRIBUTION.md`.

Sets driven by the ids already enumerated in `ART_BRIEF.md`: 30 card arts, 10
enemy portraits, 6 relics, the ghost, 3 backdrops, the capsule.

**Two constraints, from spec §3.5.** Card art renders at 1024² and displays at
122x74, so prompts ask for one silhouette and one focal shape — and **the first
five are reviewed with Joao before the remaining twenty-five are generated.**
Shipping generated art requires Steam's AI-content disclosure; Joao made that
call on 2026-08-24 and it is recorded in the ruling ledger.

**Test:** `tests/game/assets_test.gd` extends to assert every card, enemy and
relic id in `Content` resolves to a texture, so a missing or misnamed file is
a red test rather than a silent fallback.

---

## Definition of Done

`godot --path . -s tools/screenshot.gd -- <dir> all` produces a contact sheet
in which no screen reads as a debug panel, every screen has a subject, and the
Ladder is worth putting on a store page. The suite is green and above 498
tests. `tools/balance_sim.gd`'s two open findings are unchanged — this plan
does not touch content values.
