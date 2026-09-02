# M2 · Stage 2 — The Guild Sends Someone Down

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Executed
> inline, TDD, one commit per batch.

**Goal:** Expeditions (spec §3.5) and the auto-draft they need (§3.2, §5.9). Ghost
Guild is pitched as "the living hero is the roguelite, dead heroes become idle-
farming ghosts" — and right now the *only* way a ghost ever comes into existence is
by a human playing a run. The idle half has no source.

**Spec:** §3.5, §3.2, §5.1, §5.8, §5.9, §12. **Predecessor:**
`2026-09-02-m2-s1-priority-rules.md`.

**Baseline:** 915 tests, 94 suites, green.

---

## Why this before the rest of M2

M2's remaining list is Hexer, two biomes, biome claims, Expeditions, Legends,
tending, hauntings, auto-draft, content volume, a balance pass.

- **Legends cannot land yet.** §6.1 unlocks prestige when a true ghost stands on
  floor 15, and the slice stops at floor 10. Prestige needs the biomes first.
- **The two biomes are content work**, and §10 says card and enemy design "get the
  most hand-iteration time of anything in the project" — that is the part that
  wants a designer at a keyboard, not a batch of generated JSON.
- **Expeditions work entirely inside the ten floors that exist**, are pure `core/`,
  and are specified precisely enough to build without guessing. They also turn the
  offline summary — which already exists and currently only ever reports Soul —
  into the "while you were away" screen §5.8 describes.

And auto-draft comes first because §3.5 says the expedition hero "descends under
the autopilot with auto-draft", so it is a dependency rather than a sibling.

## Batches

### Batch A — a card is worth something under a doctrine

**Files:** `core/combat/card_value.gd` (new), `core/run/descent_draft.gd`, tests.

Auto-draft "resolves picks with the hero's priority rules" (§3.2), so a card has to
be worth something *to a particular fighter*. `CardValue.of(def, weights, upgraded)`
scores a card's authored effects against an autopilot weight table: damage against
`damage`, block against `block_useful`, a status against that status's weight, a
draw against `cards_drawn`. Pure, and cheap — the alternative is simulating three
fights per pick per skipped floor, which is unaffordable offline.

`DescentDraft.auto_pick(content, offer, rules)` returns the index it would take.

### Batch B — an expedition is a record, and it is planned once

**Files:** `core/economy/expedition.gd` (new), `core/economy/expeditions.gd` (new),
`core/ghosts/ghost.gd`, tests.

The load-bearing decision: **all the expensive work happens at launch, none at
resolution.** An expedition stores the depth it will reach, the deck it carries and
the strength of the ghost it will leave. Launch is a click, so it can afford a
survival projection and a strength simulation; resolution happens on load, possibly
twenty-four times over an offline window, and must be bookkeeping only. The ghost is
placed with `fixed_strength`, which the Founder already uses for exactly this.

An expedition ghost is `kind = "expedition"` — §5.1 says it counts as true for the
waypoint and as an echo source — so `Ghost.is_true()` replaces the six scattered
`kind == "true"` checks. It is **not** prepared: §3.5 says only manual play earns
the +25%.

### Batch C — the clock, in segments

**Files:** `core/campaign.gd`, `core/campaign_engine.gd`, `core/economy/upgrades.gd`,
`data/upgrades/guild.json`, `core/content/validator.gd`, `data/strings/en.csv`, tests.

Three upgrades in the Descent group: `auto_draft`, `expedition`, `expedition_speed`.

And the part that is easy to get quietly wrong: **catch-up has to be piecewise.**
`Production.accrue` integrates one rate across the whole window, but an expedition
that landed three hours into an eight-hour absence changed the rate three hours in.
`tick` is segmented at every completion — accrue, place the ghost, refresh the rate,
continue — or the game silently underpays every offline session that resolved one.

### Batch D — you can see it, and you can see what it did

**Files:** `game/hud/guild_screen.gd`, `game/hud/offline_summary.gd`, tests.

Send an expedition from the guild's upgrade table; see how long it has left; and
have the offline summary report the ghosts it placed while the game was closed,
which is the screen §5.8 describes and the reason to open the game tomorrow.

---

## Self-review

The two risks are both about the clock. First, resolution must never need a
simulation, or loading after a long absence stalls; that is why launch does all the
work and the ghost's strength is fixed. Second, an idle game that miscounts offline
progress is a broken idle game, so the segmented tick is asserted directly: the same
elapsed window must pay the same Soul whether it is ticked in one call or in ten.

Expeditions do **not** auto-relaunch. §3.5 says one at a time; a guild that keeps
sending people would place several dozen ghosts across a single offline window,
which is unbounded growth in the save file for a floor that saturates anyway.

---

## Executed

All four batches. 976 tests pass (97 suites). `campaign_demo` and `balance_sim` are
byte-identical to the stage-1 baseline; `run_demo` differs only by the stage-1
`"rules":[]` field on `exit_decision`.

### What the plan got right

The launch/resolution split held exactly as designed. `test_resolution_does_not_simulate`
catches up thirty days of clock in under 120ms, because everything a returning
expedition needs — depth, deck, survival, strength — was decided when the player
clicked. And the segmented tick is asserted for the property it exists for: an hour
paid in one call and the same hour paid in ten agree to four decimal places, and the
cap is spent as one budget across the segments so cutting a window finer can never
pay more.

### What the plan missed, and only a screenshot found

Three things, all in Batch D, none of which any test was going to report:

**The Guild ran off the bottom of the screen — and had since Batch C.** The upgrade
wall was built to fit one frame with nothing to scroll, and that was true at ten
upgrades in two groups. Fourteen in three needs 507 logical pixels of the 360 there
are. Nothing errors when a panel overflows; it just draws past the frame. The wall
scrolls now and the expedition band is pinned above it, which is the right split
anyway: the band is the only thing on that screen that changes while you look at it.
`test_the_screen_stays_inside_the_frame_however_much_the_wall_holds` is the guard,
and it is written against the screen's minimum height rather than a plaque count, so
it stays true as content grows.

**`ui.group.descent` was rendering as its own key**, in 8px caps, as the heading of
the new group. `Content.text` returns the key when it is missing, which is the right
behaviour for a game that should not crash on a bad translation and the wrong
behaviour for catching one. `test_every_key_the_content_names_resolves` now walks
every `name_key` and `text_key` in the shipped content plus every upgrade group's
heading; it was verified by deleting the string and watching it fail.

**The band's first layout was twice as tall as what it said.** Two-line rows, a
full-width primary button on the empty slot, and the two states measuring different
heights, so the band twitched every time a slot filled. It is one line per slot now,
the same line in both states, with the row height pinned above the button's own
minimum — which is what `test_both_states_are_the_same_row` actually checks.

That is the third stage running where rendering the screen found something the suite
could not. It is now the rule rather than the exception: a screen is not done until
it has been looked at.

### Notes for later

- `GameRoot._land_due` runs at the 10 Hz refresh, so an expedition that finishes
  while the Guild is open lands while it is open. It is the first thing in the game
  that completes without the player doing anything, and everything else in the
  campaign settles because they acted.
- `Num.countdown` exists because `Num.duration` rounds to minutes: a clock the
  player is watching that reads "0m" for a whole minute looks stuck.
