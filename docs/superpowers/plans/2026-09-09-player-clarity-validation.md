# Player clarity and world implementation evidence

Implementation follows [the roadmap](2026-09-08-player-clarity-progression-and-world.md).
The initial implementation was saved in `c3aa83a`; completion and verification
are delivered in subsequent commits. This record distinguishes automated
results from the new-player release gate, which still needs human participants.

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

## Remaining release evidence

Core migration and layout sweeps, final difficulty/economy comparisons,
Main Hall completion and native performance review are in progress.
Five novice playtests have not been conducted. No novice success rate,
lower-spec performance or locked-60-FPS claim is made.


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
