# Player clarity and world implementation evidence

Implementation follows [the roadmap](2026-09-08-player-clarity-progression-and-world.md).
The initial implementation was saved in `c3aa83a`; completion and verification
are delivered in subsequent commits. This record distinguishes automated
results from new-player acceptance. The user waived new-player feedback as
a release requirement on 2026-09-11; no human sessions were conducted.
Initial automated/native review: 2026-09-10. The
[2026-09-11 balance follow-up](2026-09-11-player-clarity-balance-follow-up.md)
records current tuning, 1,327 passing tests and a prepared late-cycle profile.
The measurements below retain the earlier implementation evidence; the player
release requirement is waived, with no novice success rate recorded.

## P0: baseline

Pinned engine: Godot 4.7.2 stable, official `ed1daf0bf`; fixed clock 1000.
`tools/difficulty_report.gd` measures combat events separately from `RunStats`
and the ghost-strength formula. The three combat policies are attack-first,
one-card defense-aware, and the existing lookahead Autopilot. Reward choices
use the production run policy. These are synthetic builds, not player saves.

Development seeds: `73019 + i * 7919`, 30 per profile and combat policy.
Held-out seeds: `970003 + i * 7919`, 100 per profile and policy. The four
profiles are a fresh Sexton, Might/Wit/Vigor level 1 (70 Soul total), the same
purchases on an unlocked Hexer, and a Floor-31 Sexton with four level-3 stats
and a 1.25 Legend blessing. The later profile's ten-floor span is 31–40.

Before changing enemies, both baseline batches completed: 360 development
runs and 1,200 held-out runs. Local JSON and logs are under
`reports/clarity/baseline/`; these generated diagnostics are intentionally
untracked. The baseline Hero capture is `reports/clarity/baseline/hero.png`;
earlier hybrid captures retain the old map, shop and hall appearance.
The historical shop could not be revisited: leaving discarded its stock.

Development fresh Sexton: Floor-2–4 normal wins averaged 1.77 / 2.12 / 1.86
turns for attack / defense / lookahead. Floor-4 exit median net HP losses were
45.7% / 20.0% / 14.3%, with 28 / 30 / 30 reaching that exit. Thus short fights
were a reproducible issue, while “almost no damage” depended on decisions
and healing. Reports retain damage, blocking, healing and deaths separately.

## P1: decisions and explanations

Shared stat/card descriptions read effect scaling and Focus thresholds from
content. Upgrade comparisons preserve card UID, duplicate counts, full rules,
cost and recipient; selection/cancel are read-only and confirmation carries
a room revision. Unaffordable shop stock stays visible; card inspection is
available by right-click or F. Event previews include capped healing, costs,
persistence and lethal sacrifices. Lessons are dismissed in machine settings
(F2 while walking), remain in Help, and do not unlock campaign features.
A run recap offers information about banked Soul, the resulting ghost and an
affordable next improvement without making a purchase.

47 focused tests passed, zero errors/failures/orphans, process exit 0
(`reports/clarity/p1-complete-tests.log`). They cover mixed copies, cancellation,
double/stale confirmation, a synthetic cost-changing upgrade, authored Focus
threshold changes, lethal previews, localization and lesson persistence.
Native 960×540 Spanish at 150% exposed hidden-choice spacing; it was removed.
`reports/clarity/native/upgrade-es-150.png` shows the readable before/after
comparison and focused commit. Panels retain bounded scrolling and keyboard
focus instead of shrinking text.

## Release evidence status

Implementation, migration and layout sweeps, final difficulty/economy
comparisons and native review are complete. The user waived the five novice
playtests on 2026-09-11, completing the agreed release scope. The follow-up
addresses the safe-route tuning deviation and adds the missing prepared
later-cycle comparison. The P2 section below
records the earlier revision for comparison. No novice success rate, lower-spec
performance or locked-60-FPS claim is made.


## P3–P4: room identity, persistent services and compatibility

39 focused world/map/marker tests passed, zero errors/failures/orphans,
exit 0 (`reports/clarity/p3-tests.log`). Signs, map and compass use the room
presentation mapping. Signs require line of sight, and prompts clear on
leaving. Even-width encounter volumes now fit inside their room footprint.
Elite, event, rest and shop engagement is deliberate; stairs remain visible
with their unmet requirements. Map marking remains read-only.

320 focused core tests passed, zero errors/failures/orphans, exit 0
(`reports/clarity/p2-p4-tests.log`). They include active fight HP/deck/RNG,
source-before-echo repricing, once-only offline income, fixed founder and
in-flight/returned expedition promises, schema-3 node/fight/reward/event/rest/
shop/exit migration, malformed records/layout rejection, multiple shops,
sold-out stock, removal limits, stale/double purchases and optional services
after stairs unlock. Saved JSON is validated again after migration.

Old active floors retain all old requirements. Their closed shops are
unavailable, because schema 3 discarded that stock. An old active shop keeps
its exact stock. New floors get two required encounters and one optional
room. Shops remain accessible on that floor after the requirements resolve;
no completion reward repeats. A lethal event cost ends the run once.

Content revisions settle income at the previously cached rate before
recomputing non-fixed source ghosts and then linked echoes. Saved combat
HP, deck, piles, energy, intents and RNG are retained. Revised move/effect
values apply to subsequent actions; revised spawn HP applies to new enemies.
The revision marker is saved by the game after catch-up. Fixed expedition
results, including already-launched expeditions, are never repriced.


## P2: revision r2 early curve and economy

Against the roadmap baseline, Bone Rat HP is 14 → 18 and Bite is 5 → 6;
Shambler HP is 24 → 30; Grave Wisp HP is 12 → 18. Lurch and Flicker retain
their original 7 and 4 damage after the development batch showed excessive
attrition with 8 and 5. Move schedules, starter cards/relics, stat prices and
economy formulas are unchanged. Early encounter buckets replace single weak
enemies with durable targets and combinations; all floors retain two required
encounters. There is no scaling tied to purchases or player performance.
Content revision `clarity-2026-09-09-r2` reprices existing non-fixed production
once, including campaigns that saved the initial clarity implementation.

Both 30-seed development routes and both 100-seed held-out routes completed
for all four builds and three combat policies. The committed
[difficulty summary](2026-09-09-difficulty-summary.csv) retains all distributions;
raw events and choices remain under `reports/clarity/`. Safe skips optional
elites; all visits each optional room once. These are forced-push diagnostics
through Floor 10 (31–40 for the later profile), not player retreat decisions.

| Held-out build / policy | Route | Reach F4 | Median F4 net HP loss | Mean F2–4 normal-win turns | Mean ending depth |
| --- | --- | --- | --- | --- | --- |
| Baseline fresh / defense | old required route | 100/100 | 25.7% | 2.11 | 8.13 |
| Fresh / attack-first | safe | 51/100 | 74.3% | 3.21 | 4.70 |
| Fresh / defense | safe | 100/100 | 44.3% | 4.60 | 6.70 |
| Fresh / lookahead | safe | 100/100 | 34.3% | 3.81 | 7.59 |
| Early purchases / defense | safe | 100/100 | 27.4% | 3.90 | 7.66 |
| Early purchases / lookahead | safe | 100/100 | 26.0% | 3.11 | 8.62 |
| Fresh / defense | all | 95/100 | 45.7% | 4.57 | 6.27 |
| Early purchases / defense | all | 100/100 | 28.8% | 3.86 | 7.53 |

At equal seeds/depth, the 70-Soul early purchases reduce mean safe-route F4
net loss by 38.7% for defense and 28.0% for lookahead, and reduce normal turns
by 15.2% / 18.3%. Safer routes improve fresh survival; elite victories add the
existing extra Coin and relic reward. No shop repricing was justified by this
batch. The simple defensive policy misses the provisional 15–35% median
loss target; that is recorded as a player-review question, not claimed as a
passed target. The synthetic level-3 Floor-31 profile dies on that floor
with every policy, exposing its insufficient preparation rather than proving
a viable later-cycle build. Late-biome tuning remains outside this first pass.

All 14-run / 48-simulation economy invariants pass, process exit 0
(`reports/clarity/final-balance-r2.log`). BalanceSim explicitly visits each
optional room once before sampling/pushing. Prepared Watch yield rises on
floors 1–9 from 53.91 to 764.33, and beats corpse-plus-echo at every sampled
floor. The first run plus 20 minutes of founder income yields 60.9 Soul,
above the cheapest 20-Soul improvement. Class contrast tests now compare
Deep versus Kiln: Catacombs starter win rates tied under the revised groups,
so the old assertion that Sexton must strictly win there was not retained.


## P5: authored rooms and physical clearance

All 14 room recipes are implemented: six Catacombs, four Deep and four Kiln.
Role selection reserves scarce elite/boss recipes before normal rooms and
honors size/repeat limits. A 300-layout selection sweep (100 seeds per biome)
passed. A separate 100-seed physics sweep across ordinary and boss floors in
all three biomes checks a player capsule against the actual solid props,
required routes with optional rooms removed, stairs, combat centers and shop
approaches. It found no blocked destination. This checks the shipped props,
not just the original logical grid.

Active floors save geometry, IDs and complete versioned recipes. A content
update test changes every catalogue composition and verifies that the saved
floor and combat RNG/state remain identical. Recipe validation rejects
unsupported anchors, dimensions, light budgets and activity budgets. Neutral
entry/stairs fallback has no authored props. One sign labels each continuous
door opening, avoiding overlapping repeated labels along wider openings.

Native captures cover every recipe at 1280×720 and short/tall production
enemies in each biome. Six wall sockets per room, zero extra room lights,
per-room activity limits, reduced-motion rest poses and 20 m update culling
bound the cost. Existing spatial torch sound remains on the Ambience bus.
Motion and sound use presentation state, never gameplay RNG.

## P6: authored Main Hall and earned history

The arrival view frames the cold well with four pillars, a canopy and brass
borders. Warm station areas have signs, tools, embers, books and spirit
vessels. One additional unshadowed light illuminates the overlook; the new
room recipes add no lights. The existing well barriers and five station
interactions remain usable, including G navigation.

`GuildHistory` derives banners, biome trophies, the three latest Legend
memorials and an expedition keepsake from existing campaign state. Captions
explain what earned each display and its permanence. The Founder already
earns the fresh guild's Catacombs banner. Biome claims and the commissioned
expedition count survive prestige; the current ghost population changes in
the well. History reads are tested against the complete campaign snapshot
and do not mutate it. A physical player-capsule flood reaches every station
and the well approach after decoration.

Native 1080p captures `07-guild-en-1.png`, `08-guild_progressed-en-1.png` and
`09-guild_prestige-en-1.png` under `reports/clarity/native/` show all three
states. The new geometry is original project work using existing materials,
fonts and audio; attribution and the art brief are updated. Banner motion
respects reduced motion and a 20 m update limit.

Final compact-screen review also corrected stat-button bounds, reduced the
hero portrait before text, and moved shop prices and Leave above the card
inventory. Upgrade inspection hides the unused choice area and retains
separate confirm/cancel actions. The compact combat lesson stays beside the
fight instead of covering the hand, and F2 dismisses the rest lesson too.
The final Spanish 150% shop and upgrade captures were repeated after these
changes; scrollable inventory retains full card rules and primary actions.

## P7: connected validation

### Tests and reproducible tools

The full pinned-engine run passed **1,321 cases in 128 suites**, with zero
errors, failures, skipped cases or orphans; process exit **0**. Evidence:
`reports/clarity/final-suite-r2.log` and `reports/report_35/results.xml`.
After the final shop-header, spacing and F2 adjustments, the four affected UI
suites passed another **56 cases**, zero errors/failures/orphans and exit
**0** (`reports/clarity/p7-final-ui-tests.log`, `report_36`). Subsequent changes
are capture/benchmark fixtures, CLI reporting and documentation.

The suites include content validation and cover save/load in node, fight,
reward, event, rest, shop and exit phases; deterministic active fights;
death, Watch and retreat; prestige; content revisions and expedition
promises. Generated-room policy coverage includes floors 1, 4, 10/11,
20/21, 30/31 and 61. Existing tier tests check repeating biomes and scaling
beyond the authored dungeon. The saved-room and physics tests described
above run against the final combined implementation.

The persistent-shop reproduction enters a shop, leaves, fights elsewhere,
returns, buys, saves and reloads, then returns with the stairs unlocked.
It asserts remaining stock, exact Coin, removal limits, unlocked exit and
no duplicate completion. Other cases cover independent shops, empty stock,
zero Coin, stale callbacks and once-only optional event/rest outcomes.

All three demos completed with exit **0**, using isolated data:

| Tool / arguments | Final observation | Local log |
| --- | --- | --- |
| `fight_demo.gd -- shambler bone_rat` | Autopilot wins in 6 turns with 69 HP; 50 simulations complete | `fight-demo.log` |
| `run_demo.gd -- 1 73019` | Watch on Floor 6, 69.2 Soul, 24 cards and 3 relics | `run-demo.log` |
| `campaign_demo.gd -- 73019 3` | Three runs, reach 9; save/reload succeeds | `campaign-demo.log` |

Logs are under `reports/clarity/`. The final 14-run / 48-simulation economy
batch and the 100-seed-per-profile/policy difficulty comparisons are recorded
under P2. Both optional-route policies terminate. The balance CLI now prints
its optional-room policy explicitly; it already used that policy for the
recorded batch. No price, reward or ghost formula was changed after it.

Reproduce using the recorded Godot binary and disposable XDG data. The test
wrapper performs an import before running scripts and owns its temporary
data directory. Each difficulty command below explicitly selects the original four profiles
and produces 1,200 held-out runs:

```sh
export GODOT_BIN=/home/usuario/.cache/ghost-guild-engine/4.7.2/Godot_v4.7.2-stable_linux.x86_64
tools/test.sh
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --headless --path . -s tools/difficulty_report.gd -- reports/clarity/review-safe.json 100 held_out safe 10 fresh_sexton,early_purchases,unlocked_hexer,later_cycle
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --headless --path . -s tools/difficulty_report.gd -- reports/clarity/review-all.json 100 held_out all 10 fresh_sexton,early_purchases,unlocked_hexer,later_cycle
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --headless --path . -s tools/balance_sim.gd -- 14 48
```

Raw telemetry and captures remain ignored under `reports/`; the aggregate CSV
is committed with a `keep` import. New GDScript UID sidecars are committed.
The final editor import completed with exit **0**, no warnings or errors
(`reports/clarity/final-import.log`).

### Native UI and world review

The 29-case native matrix produced 29 PNGs with exit **0** each. It covers
960×540 Spanish at 150% (Hero, upgrade, shop, event, Help, map and combat),
1080p English guild states, 2560×1080 English Hero at 125%, 720p Spanish
combat at 150% with reduced motion, and every one of the 14 room recipes.
Production roster captures pair Bone Rat/Mother of Bones, Spore Hound/The
Bloom and Cinder Hound/The First Flame at their boss floors.

Three additional native captures passed with exit **0**: a crowded Hero
inventory at its beginning and end, with all content cards/relics, 9,999-point
stats and five-digit HP; and an upgrade panel with 987,654,321 Soul and large
progression values. These are presentation stress fixtures, not obtainable
balance profiles. The compact views retain bounded scrolling, readable
numbers and G navigation. Keyboard focus, auto-scroll into view, mouse
inspection and input ownership are also covered by the game tests.

Captures live in `reports/clarity/native/` (`manifest.json` and numbered PNGs
00–31). `tools/hud_shot.gd` documents the reproducible modes; for example:

```sh
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --path . --rendering-method forward_plus --resolution 960x540 -s tools/hud_shot.gd -- reports/clarity/review-upgrade.png upgrade 45 960 540 1.5 es
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --path . --rendering-method forward_plus --resolution 960x540 -s tools/hud_shot.gd -- reports/clarity/review-crowded.png hero_crowded 45 960 540 1.5 es reduced bottom
```

The capture matrix logs X11 `ERROR: NO GRAB` when an unfocused window requests
mouse capture. Those runs still produced their images and exited 0; there
were no script errors. This diagnostic is recorded rather than counted as a
successful interactive mouse session. No novice usability rate follows from
screenshots or synthetic input tests.

### Native performance

Final `hybrid_bench.gd` run: Godot 4.7.2 `ed1daf0bf`, Vulkan Forward+, NVIDIA
GeForce RTX 4070 Laptop GPU, Intel Core i7-14700HX, 1920×1080, VSync disabled.
Each scene warms for three seconds and samples 180 frames. The benchmark now
includes the complete seven-display history wall and a dense authored
Floor-31 layout with five rooms, normal/elite/boss encounters and an active
Ossuary fight. All four measurements completed; process exit **0**, no script
or window-grab errors in this final run. Log: `final-benchmark-r2.log`.

| Scene | Median frame ms | p95 frame ms | Mean render CPU ms | Mean render GPU ms | Draw calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| Fresh Main Hall | 10.046 | 15.121 | 1.097 | 3.035 | 227 |
| Populated history wall | 8.272 | 14.383 | 1.118 | 3.040 | 268 |
| Hero preview | 9.987 | 15.017 | 1.107 | 3.144 | 345 |
| Dense Floor-31 combat | 7.919 | 13.604 | 2.236 | 7.201 | 616 |

The periodic process-time monitor reports means of 15.66–17.70 ms and is
recorded separately from sampled frame intervals. These are short-run
measurements on one machine, not proof of locked 60 FPS or lower-spec support.
An earlier three-scene pass ranged from 12.617 to 13.937 ms p95, illustrating
run-to-run variance; it is retained as `final-benchmark.log`.

After warming the panels, 50 Hero/ghost open-close cycles retained identical
counts: 717 nodes, 4,073 objects, 15 lights, 3 viewports, zero active previews
and zero orphans. The dense floor has 1,301 nodes and 38 lights; its new room
props do not add lights. The hall adds one unshadowed light. No additional
shadow-density option was needed for these measured fixtures.

```sh
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --path . --rendering-method forward_plus --resolution 1920x1080 -s tools/hybrid_bench.gd
```

### Waived player release requirement

**Waived on 2026-09-11 at the user's request. Participants: 0/5.** New-player
feedback no longer blocks this release. The original protocol remains available
for optional future sessions: use an isolated fresh save for each participant,
record each task as unaided, assisted or incomplete, and retain the player's
explanation and any misunderstanding:

1. Explain which effects Wit changes.
2. Select one Strike copy, predict its upgrade and say who keeps it.
3. Identify an elite and an event before committing, using the map and signs.
4. Leave a shop, resolve another room and return to its remaining stock.
5. Identify the next affordable permanent improvement after a run.

The original target was at least four of five unaided completions **per task**.
No sessions were conducted or success rate measured. The balance follow-up
supersedes the earlier 44.3% safe-route loss and adds a prepared late-cycle
comparison; those measurements do not establish novice comprehension.
