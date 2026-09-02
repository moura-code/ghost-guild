# M2 Stage 3 — The Fungal Deep

Spec §2, §5.6, §7. The second biome, the floors below ten, and the first thing
the player earns by *standing somewhere* rather than by spending.

## Why this, now

The game has one biome. Every run is the Catacombs, every ghost stands in the
Catacombs, `reach` is capped at ten and the exit screen stops offering to push
at floor ten because there is nowhere to push to. The descent is the game's
spine and it currently ends after ten vertebrae.

It is also the stage that unblocks the most of what is left. Biome claims
(§5.6) need two biomes to mean anything. The Hexer is unlocked by the first
true ghost in the Fungal Deep. Tier cycling needs a floor-to-biome map that
does not exist yet. And expeditions, which shipped last stage, currently
simulate every ghost against the Catacombs no matter what floor it stands on —
a bug that only becomes visible once a second biome exists.

## What is actually wrong today

`Campaign.biome_id` and `RunState.biome_id` are single strings, set once. Every
one of these reads the *campaign's* biome while being handed a *floor*:

- `Seance.create_echo` — an echo placed on floor 15 is priced against Catacombs
  enemies.
- `Expeditions.plan` and `Expeditions.launch` — same, for the floor it sends to.
- `YieldSimulator` — same, for every ghost on the ladder.
- `CampaignEngine.strength_for` — same.

None of these are wrong yet, because there is only one biome. All four become
wrong the moment there are two, and none of them would fail a test, because
the test fixtures also have one biome. So the map comes first and the content
comes second.

## Batches

### Batch A — a floor knows which biome it is in

**Files:** `core/content/biomes.gd` (new), `core/campaign.gd`,
`core/campaign_engine.gd`, `core/run/run_state.gd`, `core/run/run_engine.gd`,
`core/economy/seance.gd`, `core/economy/expeditions.gd`,
`core/ghosts/yield_simulator.gd`, tests.

`Biomes.for_floor(content, floor)` maps a floor to the biome whose authored
range contains it, and `Biomes.depth(content)` is the deepest authored floor.
`Campaign.biome()` and `RunState.biome()` take a floor and stop being fields;
every caller listed above passes the floor it already has.

`RunEngine.can_push` compares against `Biomes.depth` rather than the current
biome's last floor, so a run that clears floor 10 is offered floor 11 — into
a different biome, mid-run, which is the whole point of a descent.

Tier cycling (§2, floors past the authored end) is **not** in this batch. The
map is written so that adding it is a change to one function, but a tier needs
a mutation modifier to mean anything and that is its own stage.

Behaviour at floors 1–10 must be identical: the demos are the check.

### Batch B — the Fungal Deep exists

**Files:** `data/biomes/fungal_deep.json` (new), `data/enemies/fungal_deep.json` (new),
`data/cards/fungal_deep.json` (new), `data/strings/en.csv`, `data/affinity.json`,
tests.

Ten enemies (eight regular, one elite, one boss), tagged Flesh and Fungal, on
floors 11–20 in three encounter bands. Ten cards in the `fungal_deep` pool.

The biome has to *play* differently, not just look different. The Catacombs are
undead: single big hits, summons, and Holy is strong against them. The Deep is
flesh and fungal: it applies statuses to the hero and rewards Poison, which is
already ×1.5 into Flesh and ×0 into Construct in `affinity.json`. So the Deep
is where a Poison deck comes alive and where a pure Bone deck starts to
struggle — which is also the argument for the Hexer being unlocked here.

### Batch C — you claim a biome by standing in it

**Files:** `core/content/biomes.gd`, `core/run/run_state.gd`,
`core/run/run_engine.gd`, `core/campaign_engine.gd`, `game/hud/`, tests.

A biome is claimed when a true ghost stands on one of its floors. **Derived,
not stored** — a stored claim can disagree with the ladder, and the ladder is
the truth. `Biomes.claimed(content, ladder)` reads it off the ghosts.

A claim unlocks that biome's card pool for the Descent draft and for shops,
everywhere, not only while you are in that biome (§5.6): the reward for
reaching the Deep is that Deep cards start showing up in your Catacombs runs.
Pools reach the run through `RunState.claimed_pools`, set at `start_run`, so
the run stays a closed system that replays from its seed.

### Batch D — you can see which biome you are in

**Files:** `game/world/crawl.gd`, `game/theme/grade.gd`, `game/widgets/tower_view.gd`,
`game/hud/prompts.gd`, tests, one rendered shot.

`Palette.BIOME_ACCENTS` already holds the three accents the spec names (ivory,
violet, orange) and nothing reads them. The grade, the fog and the floor
banner take the accent of the floor's biome, and the ladder tower draws its
colour bands, which §9 calls the capsule image.

## Self-review

The risk in Batch A is silent: replacing a field with a lookup is exactly the
kind of change that keeps every test green while quietly changing which enemy
table a projection reads. So the check is the demos — byte-identical output at
floors 1–10 — plus a test that pins `for_floor` at every boundary, including
floor 0 and a floor past the end, which are the two the callers can actually
produce (a ghost on floor 0 does not exist, but `reach` arithmetic can ask).

The risk in Batch B is that the Deep is the Catacombs with different names. The
guard is mechanical rather than editorial: its encounters must apply statuses
the Catacombs never apply, and a Poison deck must measurably do better there
than a Bone deck, which `balance_sim` can be made to report.

The risk in Batch C is the claim being retroactive. A ghost already standing on
floor 12 from a previous session should claim the Deep the moment it loads,
which is what deriving from the ladder gives for free and what a stored flag
would not.

---

## Executed

All four batches.

### Batch A — the map

`Biomes.for_floor` / `depth` / `claimed`, and `biome_id` deleted from both the
Campaign and the RunState. The four projections the plan named as latently
wrong — `Seance.create_echo`, `Expeditions.plan` and `launch`, `YieldSimulator`,
`CampaignEngine.strength_for` — now price the floor they were handed rather than
the campaign's one biome, and `RunEngine.exit_summary` projects the *next*
floor's biome, which matters on exactly the one floor where the reading is most
load-bearing.

`can_push` compares against `Biomes.depth` rather than the current biome's last
floor, so clearing floor 10 offers floor 11. Tier cycling stays out: `for_floor`
clamps into the deepest biome instead, because a tier without its mutation
modifier is the same floors with a bigger number on them.

Demos byte-identical at floors 1–10, which was the whole check.

### Batch B — the biome

Ten enemies, ten cards, three encounter bands, an elite and a boss, twenty
icons fetched from game-icons.net and credited.

The Deep had to *play* differently, and that is asserted rather than asserted-
in-a-comment. Every Deep enemy is tagged Flesh or Fungal; at least a third of
them apply vulnerable or bleed, which no Catacombs enemy does. And the claim
the biome exists for, measured: the same Poison deck and Bone deck are within
noise of each other in the Catacombs (−0.02 win rate) and the Deep opens a gap
that widens with depth — **+0.17 at floor 12, +0.33 at 14, +0.50 at 18**. The
test asserts the *contrast* rather than the absolute, so it is a statement
about the biome rather than about two decks.

The elite table was trimmed from two groups to one after playing it: a
two-regular "elite" landing on floor 11 was a spike rather than a step. A fresh
hero entering at 11 now dies about half the time, against **six times out of
six** entering at floor 10 in the Catacombs — the Deep is not out of line, it
is a new biome after a boss floor.

### Batch C — the claims

Derived from the ladder, never stored, so a ghost already standing in the Deep
claims it the moment an old save is opened. `RunState.claimed_pools` is copied
in at `start_run` so the run stays a closed system that replays from its seed,
and `RunEngine.pools` is now public, deduplicated (a pool listed twice is a
pool with double the odds) and always includes the floor being stood on — the
first run into a new biome has to be able to offer its cards.

### Batch D — seeing it

`Grade.biome_tint` moves the fog and the fill toward the biome's accent,
measured **against the Catacombs' accent rather than against neutral**, so the
biome the entire game was graded and screenshotted in is an identity by
construction and every judgement already made about the look still holds. The
grade itself — tonemap, fog model, saturation, SSAO — is asserted identical
across biomes. The Kiln has no content and is tested anyway, so the biome that
ships last is not the one that discovers this function is wrong.

The floor banner names the biome only where that is news: the first floor of a
descent and the floor a run crosses into a different one. "Floor 4 · Catacombs"
nine times running is noise, and it would make the one time it matters read as
more of it.

### What only rendering found, again

**The ladder shaft had a black hole in it.** The undug rock's fade was written
as `0.34 - floor * 0.022` for a ten-floor shaft; at floor 16 it goes negative.
The day the shaft became twenty deep, the bottom four floors of the game's own
capsule image turned into a black rectangle. No test could see it — the one
test that touched `undug_colour` asserted only that it is darker than a lit
chamber, which a negative number satisfies enthusiastically. It is a fraction
of the shaft now, and `test_no_floor_of_the_shaft_is_a_hole` walks every floor.

**An unknown biome id tinted the air toward bone.** `Palette.biome_accent`
falls back to `BONE_DIM` for an unknown id, which is right for a label and
wrong for a light. Caught by the test that asserted an unknown biome changes
nothing, which is the kind of assertion that looks like paranoia until it fires.

### Notes for later

- The Deep uses the same stone kit and the same materials as the Catacombs.
  The accent, the fog and the name carry the difference; per-biome kit
  materials are the next real step and are an art job, not a code one.
- **Claiming a biome dilutes the class pool.** `Rewards.card_offer` takes the
  union of the pools it is given and weights only by rarity, so a Sexton who
  has claimed the Deep sees 17 class cards in 37 rather than in 27 — 63% down
  to 46%, and 36% once the Kiln lands. That is the shape §5.6 asks for (more
  cards is the reward) but it is also how a class stops feeling like a class.
  A per-pool weight belongs in the first full balance pass, not here.
- `data/affinity.json` still has only two rows. Poison×Flesh is doing all the
  work of making the Deep a different place; the Kiln will need Ember×Fungal
  and Poison×Construct to do the same for itself.
