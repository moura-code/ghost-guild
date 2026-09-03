# M2 Stage 8 — Tier cycling

Spec §2, §6.1. Floor 31 and everything below it.

## Why this, now

Prestige shipped last stage and there is nowhere for it to send you. `can_push`
stops at floor 30, `Biomes.for_floor` clamps into the Kiln, and the reward for
merging your dead is that the same thirty floors get easier. §6.1 says the
opposite is the point: "because reach persists, the next cycle starts with a
Descent straight to the old frontier, **not a replay**."

The spec's answer (§2): "Floors 31+ cycle the biomes at tier 2, 3, … with one
mutation modifier per tier." So the descent is infinite, the biomes repeat, and
what makes tier 2 of the Catacombs different from tier 1 is a **mutation** — a
rule that applies to every fight on those floors.

`Biomes.for_floor` was written for this. Its docstring already says so:

> Tier cycling ... is deliberately not here. `for_floor` clamps into the
> deepest biome instead ... A tier without its mutation modifier is just the
> same floors again with a bigger number on them.

The mutation modifier is what this stage adds.

## What a tier is

`Biomes.depth` floors make one cycle. Floor 31 is Catacombs again at tier 2,
floor 61 at tier 3, and so on for ever.

Two things change with the tier:

1. **Scaling.** §2: "HP ×1.06 per floor, damage ×1.04 per floor, plus a jump
   per tier." The per-floor curve already compounds across the whole depth, so
   the tier jump is a separate multiplier on top — otherwise tier 2 floor 31 is
   barely harder than tier 1 floor 30 and the loop has no teeth.
2. **A mutation**, drawn per (biome, tier) from the campaign seed. One rule per
   biome per tier, so a cycle is a set of three mutations the player learns and
   plans around, and a *new* prestige re-rolls them — §6.1: "the dungeon
   regenerates with a new seed and a new mutation per biome."

Mutations are content, not code: a small vocabulary of effects the fight engine
already supports, authored in `data/mutations/`.

## Batches

### Batch A — the map goes on for ever

**Files:** `core/content/biomes.gd`, `core/run/run_engine.gd`,
`core/combat/scaling.gd`, `data/balance.json`, tests.

`Biomes.tier_of(content, floor)` and `for_floor` wrapping instead of clamping.
`can_push` unbounded. `Scaling` takes the tier.

Floors 1–30 must be byte-identical — tier 1 is the identity, the same way an
empty rule list and a guild with no Legends are.

### Batch B — the mutations

**Files:** `data/mutations/base.json` (new), `core/content/mutation_def.gd`
(new), `core/content/mutations.gd` (new), `core/content/validator.gd`,
`data/strings/en.csv`, tests.

A mutation is a named rule with a small effect vocabulary: enemies start with a
status, the hero starts with one, the hero draws one fewer, enemies have more
HP, block decays. Each is one hook the fight engine already has.

`Mutations.for_floor(content, floor, campaign_seed)` is deterministic from the
seed and the (biome, tier) pair, so the same cycle always has the same rules
and a new campaign has different ones.

### Batch C — you can see which floor you are on

**Files:** `core/combat/combat_engine.gd`, `game/world/crawl.gd`,
`game/hud/`, `game/widgets/tower_view.gd`, tests, renders.

The mutation applies at `start_fight`. The floor banner names the tier and the
mutation. The tower stops at the deepest floor worth drawing rather than at the
dungeon's depth, which is now infinite.

## Self-review

The risk in Batch A is the same silent one every map change has had: a wrapping
`for_floor` that is off by one puts floor 31 in the Kiln instead of the
Catacombs, and nothing crashes. So the boundaries are pinned floor by floor
across three tiers, and floors 1–30 are asserted identical to today.

The risk in Batch B is a mutation that is not a rule but a difficulty knob.
"Enemies have 30% more HP" is a bigger number; "every enemy starts with 3
Thorns" is something to play around. The vocabulary is chosen so that at least
most of them change what you *do*, and the test asserts that a majority are
behavioural rather than numeric.

The risk in Batch C is that an infinite tower cannot be drawn. It is bounded by
what the player can reach, not by the dungeon.

---

## Executed

All three batches.

### Batch A — the map goes on for ever

`Biomes.tier_of` and `in_tier`; `for_floor` wraps instead of clamping;
`Scaling` takes a tier and applies `tier_hp_jump ^ (tier-1)` on top of the
per-floor curve. `can_push` is unconditionally true.

Tier 1 is the identity everywhere — the boundaries are pinned floor by floor
across three tiers, the first thirty floors scale exactly as they always did,
and the three demos are unchanged.

**Removing the floor cap removed something else that was load-bearing.**
`can_watch` was `run.watch_unlocked or not can_push(run)` — the second half was
a safety valve saying "if there is nowhere left to go you may always take the
watch". There is always somewhere left to go now, so the valve is gone and the
rite is exactly what the onboarding says it is: earned by dying once. That is
the right rule, and it means a first-run hero with no Resolve has precisely one
exit action, which is pushing.

It also made `RunAutopilot` unbounded for a hero who cannot die. `max_floor`
bounds a simulation — and it is deliberately **advisory**: an autopilot that
refused to push at the cap would deadlock rather than terminate, so the cap
steers the choice and never removes the last option.

`CampaignEngine.start_run` also stopped capping the entry floor at the authored
depth. Reach is the only limit now, which is what reach was always for.

### Batch B — the mutations

Nine rules in `data/mutations/`, drawn per (biome, tier) from the campaign
seed, so a cycle is a set of three rules the player learns and a different
guild gets a different dungeon. Tier 1 has none, by construction.

Eight of the nine are **rules rather than knobs** — every enemy starts with 3
Thorns, you start every fight with 2 Weak, you draw one card fewer, you have
one more energy — and one is the numeric outlier. That ratio is asserted:
`test_most_of_them_change_what_you_do_rather_than_how_long_it_takes`. A tier
whose only difference is a bigger number is the same floors again with a
bigger number on them, which is the thing tier cycling was written to avoid.

### Batch C — you can see which floor you are on

The banner names the tier from cycle 2 down, because the Catacombs at tier 3
are the same walls and nothing like the same fight. The rule gets a line of its
own under the objective — it cannot share that line, which counts down as rooms
are cleared, while a rule you play around for ten floors does not. Amber rather
than red: it is a condition of the place, and a warning that shouts for ten
floors stops being read.

### Two things this cost, both worth naming

- **Two suites appeared to hang.** They did not: `can_push` becoming true made
  an unkillable test hero descend until the autopilot's 10000-iteration guard,
  fighting the whole way. The test's premise ("ends at the last floor") had
  been deleted by the feature, and so had `run_exit_test`'s. Both are rewritten
  around what is true now rather than patched.
- **`enemy_ai.gd` got a literal `\n` in the source** from a scripted edit and
  took the whole `core/combat` package down with a parse error, which surfaces
  as *unrelated* tests failing with "nonexistent function". Worth remembering:
  a Godot parse error in one file makes every `class_name` that depends on it
  vanish.

### Batch C, finished: the shaft has no bottom either

The banner and the rule line landed first. The tower did not, and it was the
half that was actually broken: `TowerView` drew floor 1 to `Biomes.depth`, so
a guild with reach 44 saw a fully lit thirty-floor shaft with no frontier line
on it, no rock under it, and no chamber for any ghost that had died below
thirty.

It draws a **window** now -- `first_drawn` to `last_drawn`, one authored
dungeon's worth of chambers plus the rock below them. Floor 1 stays at the top
for the whole of the authored game *and* for the rock under it, so the Founder
never falls off the top of the capsule image; past that the window slides down
and the surface leaves the frame, which is what a bottomless descent ought to
look like. Everything the shaft is drawn from -- the taper, the light, the
numbering, the hit test -- reads against the window rather than against floor
one.

The same assumption was in two more places, both found by asking what else had
been written against a dungeon with a bottom:

- **The well in the guild floor** drew `Biomes.depth` rings, so a ghost who
  died on floor 41 stood in a shaft that stopped at 30. It follows reach now,
  and `MAX_FLOORS` stopped being "a guard against corrupt data" and became the
  honest thing its own header always claimed: below it the shaft goes dark.
- **The colour grade** was `depth_of(floor, depth)`, which clamps -- so every
  floor from thirty down was lit like the bottom of the Kiln and the biome
  colour bands, the only thing on screen that says where you are, went one
  colour. `Crawl.grade_depth` cycles it with the biomes: the Catacombs are the
  same walls in every cycle, and what makes a tier different is its rule.

`Biomes.deepest` went with them. Nothing clamps into the deepest biome any
more and it had no other caller.

### Three things the renders caught

- **The rule sat on the banner.** Its line began one pixel inside where a
  floor announcement lands, so the two shared a strip of screen for the two
  seconds a banner is up. It sits under the banner now, and reads with it:
  "Floor 34, Catacombs, Tier 2", and then what that costs you.
- **Amber on lit sandstone is amber on amber.** The theme turns Label outlines
  off everywhere, and the world behind these lines is black rock in one room
  and a torch two feet from pale stone in the next. The rule is the exception
  that earns one -- the banner is a flourish and the objective is a reminder,
  but a standing rule you plan ten floors around has to be readable wherever
  it lands. (The objective still washes out on a bright wall. That is older
  than this stage and is its own job.)
- **The exit screen still had a reading for "you cannot go deeper"**: two
  em-dashes and a note saying *The biome ends here.* Unreachable since
  `can_push` became unconditional, and false besides. The note label went with
  it -- an always-empty line in a VBox is a gap in the layout.

### What was actually checked

1134 tests, no failures. The four demos -- balance sim, run demo, fight demo,
campaign demo -- are **byte-identical to 204bfd8**, which is the real
regression criterion for "tier 1 is the identity"; the balance sim still exits
1 on the same two untuned findings it exited 1 on before. `docs/shots/review/`
has `tier2`, `tier2fight`, `ladder` and `ladderdeep`, the last of which is the
one worth looking at: the biome colour bands restart at floor 31, so the cycle
is visible in the capsule image rather than only in the numbers.
