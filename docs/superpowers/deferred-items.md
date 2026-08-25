# Deferred items and open balance findings

Recorded at the close of each milestone plan. Nothing here blocks the current
milestone; everything here is a real call someone has to make later. Delete a
line when it is done or when it stops being true.

## Open balance findings (M1-B2) — `tools/balance_sim.gd` exits 1 until these are tuned

These are content-tuning decisions, not code defects. The simulator is
deliberately failing so the numbers cannot quietly ship wrong.

1. **"Deeper pays" fails at floor 7.** A prepared ghost's marginal yield dips
   going 6 -> 7 even though `soul_per_kill` grows 1.3x per floor, because the
   Catacombs 7-10 encounter bracket is much harder than 4-6 for the typical
   deck, so the simulated win rate falls faster than the reward grows.
   Levers: an intermediate encounter bucket for floors 7-8, softer 7-10 groups,
   or steeper `soul_per_kill` growth. Deep-floor samples are also thin (runs
   die before reaching them), so re-measure with more runs after any change.

2. **"Taking the Watch beats dying" fails on floors 2-3.** The spec's own
   multipliers make this a knife edge: watch = 1.25*s versus corpse + echo =
   0.7*s + 0.75*0.7*s = 1.225*s. The soft cap then penalises one strong
   prepared ghost exactly where a typical deck already saturates a floor,
   while corpse + echo spread across two floors and escape the cap.
   Levers: prepared bonus above 25%, echo factor below 0.75, restless penalty
   above 30%, or charging the echo's Soul cost against the corpse branch.

## Deferred from M1-B2 (minor, per task)

- `Strength.simulate` treats any non-positive `fights` as the balance default;
  the floor-10-vs-floor-1 win-rate bound in its test is coarse.
- A killer id absent from content renders "fell to  on Floor N" instead of the
  unknown-killer epitaph. `Ghost.clone_as_echo`'s strength/fixed_strength reset
  and the founder's flags are untested.
- `Ladder.waypoint()` is untested for an echo-only ladder.
- `CampaignEngine.start_run`'s tri-state return (existing run / null / new run)
  is untested as a whole; `refresh_rate` runs for stat upgrades too;
  `buy_upgrade`'s match has no explicit `_` arm.
- `Seance.call_echo`'s missing-source branch is untested (unreachable today).
- `YieldSimulator` reads the biome from the campaign while a run's projections
  read it from the run. Identical today (one biome per campaign) - it diverges
  the moment a second biome exists. `strength_here`/`strength_at` share a seed
  tuple per floor.
- Save: `.bak2` content is not asserted; rotation happens before the new file
  opens, so a failed open loses the newest backup; `Campaign.to_dict`
  hardcodes `"version": 1` instead of `SaveGame.VERSION`.
- `BalanceSim`: `ap.survival_samples = 1` is dead configuration in
  `sample_runs`; `deeper_pays` runs over sampled floors only.

## Game feel — a scoped deliverable, not polish (added 2026-08-24)

The art direction is icon-and-typography by necessity (spec 2: solo dev, no
art skills), which means **motion carries the entire feel of the game**. This
is not a polish pass to fit in if there is time; it is the difference between
a spreadsheet and Balatro. Budget it explicitly.

- **Fight screen (M1-C2).** The combat engine already emits every event as
  `{type, target, amount, source}` specifically so the UI can animate from the
  stream. Use it: floating damage numbers, hit-stop on a big hit, screen shake
  scaled to damage, card tween into and out of the hand, `CPUParticles2D` on
  impact, block shimmering as it absorbs.
- **Numbers count, never snap.** Soul, HP, block and yield all tween to their
  new value. A number that jumps reads as a spreadsheet; a number that climbs
  reads as a game.
- **The epitaph beat (M1-C2).** Spec 9 calls this the emotional centre and the
  trailer opening. Give it real time: the name, the floor, the ghost sliding
  into its row, and the ladder's number starting to tick. Do not let it be a
  dialog box with an OK button.
- **The Ladder is the Steam capsule.** Ghosts drift on their own phase (built),
  but the tower also wants: a soft glow on a saturated floor, the waypoint
  marker animating when it moves, and a new ghost easing into place.
- ~~**Sound.**~~ Done 2026-08-25. Synthesised rather than sourced from a CC0
  library: `tools/audio/generate.py` builds eighteen effects from oscillators
  and noise, which suits the pixel-art direction better than samples would
  and leaves no licence to track. Wired through `Sfx` on the GameRoot; the
  fight drives it from the same event stream the animator uses, so what you
  see land is what you hear land. Still missing: ambient loops and music.

## Recommendations carried into M1-C / M2

- **Accrue-then-mutate rule.** Anything that changes the production rate must
  `tick` first. `finish_run` and `load_and_catch_up` now do. `Seance` and
  `buy_upgrade` do not take a `now`, so the UI must tick before calling them -
  either give them a `now` or make it an explicit UI convention.
- **Threading.** `CampaignEngine.finish_run` and the exit-decision numbers run
  a 50-fight simulation: 300 ms to 3 s single-threaded. Spec 11 wants yield
  simulation under 100 ms. Run them on `WorkerThreadPool` in the UI layer, or
  lower `Campaign.sim_fights` for live previews and use the full count only
  when banking a ghost.
- **Events.** `Campaign.events` grows without bound; the UI needs a drain API.
- **Localisation.** Epitaphs are baked strings; they should carry a key plus
  arguments so a translator can reorder them.
- **Multi-biome.** Add an `is_true_ghost` helper before Expeditions, and a
  single floor -> biome helper, before a second biome exists.
- **Ghost strength is intentionally not recomputed on load** - it is a record
  of how that hero actually fought, not a live value.

## Deferred from M1-A / M1-B1

- `EnemyAI.intent_of` ignores Weak and Vulnerable when predicting damage.
- Validator gaps: effect `scale`/`hits`, card pool and biome references, and
  empty encounter groups are unchecked.
- `hash()`-seeded RNG streams are not guaranteed stable across Godot upgrades.
  Expedition seeds saved in M2 would break; pin or version them there.
- `RunAutopilot` buys every affordable card (a 31-card deck by floor 7). The
  balance simulator needs a smarter purchase policy before its numbers are
  trustworthy for deck-quality questions.
