# M2 · Stage 1 — The Ghost Fights As You Fought

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Executed
> inline, TDD, one commit per batch.

**Goal:** Priority rules — the one M1 item the plan explicitly deferred
(spec §11, "Out of scope: priority rules"), and the mechanic the game's own
sentence is about. Right now a ghost farms; it does not fight *like you*.

**Spec:** `docs/superpowers/specs/2026-08-21-ghost-guild-design.md` §3.3, §4.3,
§5.1, §5.2, §7. **Predecessor:** `2026-09-01-3d-s8-occupied.md`.

**Baseline:** 864 tests, 90 suites, green. `core/` untouched since stage 7, so the
three demos are the ones stage 7 signed off.

---

## Why this, and why now

M2's list is Hexer, two biomes, Expeditions, priority rules, Legends, tending,
hauntings, auto-draft, content volume, a balance pass. Priority rules come first
for three reasons:

1. **They are the game's sentence.** §5.2 is titled *"the ghost fights as you
   fought"*, and today it is only half true: a true ghost inherits the hero's
   measured win rate and turn count, but every simulated fight it will ever run —
   echoes, projections, tending deltas, the next-floor number on the exit screen —
   is played by one autopilot with one hard-coded weight table. Every ghost in the
   game fights identically.
2. **They are the beat that makes dying a choice.** §3.3 calls picking them "the
   build-expression beat of dying". Take the Watch currently asks nothing of the
   player except *when*.
3. **They unblock four later items.** Auto-draft, Expeditions, tending deltas and
   the balance simulator all take "the hero's priority rules" as an input in the
   spec. Every one of them is cheaper after this than before it.

## The constraint that shapes the whole stage

`tools/balance_sim.gd`, `run_demo` and `campaign_demo` must stay **byte-identical**
(CLAUDE.md). That is not an obstacle here, it is the design:

> **An empty rule list is the identity.** Rules compose over the existing weight
> table; new score terms are added with a default weight of **0.0**. Nothing in the
> game has rules until a player picks some, so nothing measurable changes until
> then. Verified by re-running all three demos and diffing.

## Batches

### Batch A — a rule is content

**Files:** `core/content/rule_def.gd` (new), `core/content/content.gd`,
`core/content/validator.gd`, `data/rules/base.json` (new),
`data/strings/en.csv`, tests.

Twelve rules, as data, in the shape §7 asks for: an id, a name key, a text key and
a set of weight adjustments. Validated like everything else — unknown weight key is
an error, and **`death` and `lethal` are not adjustable at all**, because those two
are what stop the autopilot walking into a loss and the 30-turn fight cap depends
on them.

### Batch B — rules bend the scorer

**Files:** `core/combat/priority_rules.gd` (new), `core/combat/autopilot.gd`, tests.

- `PriorityRules.weights_for(base, ids, content)` — pure. `base * Π mul + Σ add`
  per key, so the arithmetic is order-independent *within* a rule set.
- **Order still matters, deliberately.** §3.3 says the player *orders* up to three.
  Position gives an influence factor, so the first pick bends the scorer hardest
  and the same three rules in a different order make a different ghost.
- Two new score terms, both defaulting to **0.0**: `cards_drawn` and
  `powers_played`. §3.3's own examples ("Draw before attacking", "Powers on turn 1")
  cannot be expressed without them, and at 0.0 they change nothing.

### Batch C — a ghost carries them

**Files:** `core/ghosts/ghost.gd`, `core/run/hero.gd`, `core/ghosts/strength.gd`,
`core/ghosts/yield_simulator.gd`, `core/save/save_game.gd`, `core/run/run_engine.gd`,
tests.

Rules on the hero, inherited by the ghost, round-tripped through the save, and
actually used by every simulated fight the ghost runs.

### Batch D — the beat where you choose

**Files:** `game/hud/exit_screen.gd`, `game/hud/rule_picker.gd` (new),
`game/hud/ladder_screen.gd`, tests.

The picker on Take the Watch, and the rules visible on a ghost afterwards — a
choice you cannot see the consequence of is a choice the player will not make twice.

---

## Self-review

The risk in this stage is not the code, it is silently changing the balance of a
game that has a tuned simulator. That is why the identity property is stated up
front, why the new terms default to zero, and why the demos are diffed rather than
eyeballed. The second risk is a rule that makes the autopilot suicidal and blows
the fight cap; that is why `death` and `lethal` are un-adjustable and why
`hp_lost` and `unblocked` are clamped to stay penalties.

---

## Executed — all four batches

**915 tests, 94 suites, green** (from 864 / 90).

| Batch | What landed |
|---|---|
| **A · a rule is content** | `RuleDef`, `data/rules/base.json` with the twelve rules §7 asks for, their strings, the loader hook, and `ContentValidator._rule` — which rejects an unknown weight, a non-numeric adjustment, a rule that changes nothing, and any rule that names `death` or `lethal`. |
| **B · rules bend the scorer** | `PriorityRules.weights_for` — `base × Π mul + Σ add` per weight, with a per-position influence so the *order* the player chose is part of the answer. Dotted paths reach nested weights and `hero_status.*` lifts a whole group. `Autopilot.default_weights()` and `Autopilot.with_rules()`. |
| **C · a ghost carries them** | Rules on `Hero`, inherited by `Ghost.from_run`, carried by `clone_as_echo`, round-tripped through both saves, and threaded into `Strength.simulate` — so `CampaignEngine` (a ghost's own strength), `Seance` (an echo), and `YieldSimulator` (the exit screen's two numbers) all simulate the fighter rather than a generic one. The `watch` action takes them and normalizes them. |
| **D · the beat where you choose** | `RulePicker` — twelve numbered rows, greying out at three, opening on whatever the hero already had, with "choose nothing" a legal answer that is stated rather than a locked button. It is a second face on `ExitScreen`, not a new panel, so Escape and the HUD stack are unchanged. `GhostLine` shows a ghost's orders afterwards. |

### The identity property, verified

`campaign_demo` and `balance_sim`: **byte-identical.** `run_demo` differs by exactly
one line, and it is additive:

```
- {"choice":"watch","floor":8,"type":"exit_decision"}
+ {"choice":"watch","floor":8,"rules":[],"type":"exit_decision"}
```

The event now reports the doctrine that was chosen. That field was left
unconditional rather than emitted only when non-empty: hiding a real, intended
change behind a conditional to preserve a hash is how a regression criterion stops
being one. The simulation itself is untouched, which is what the other two demos
say.

### What was found on the way

- `_apply_exit` never received the action, only its `kind`, so the exit decisions
  were the one branch of `RunEngine` that structurally could not carry a payload.
- Setting `Autopilot.weights` from a shared `const` would have let one ghost edit
  how every other ghost fights. It is a factory function for that reason.
- A rule set is capped by *ignoring* a fourth pick rather than pushing the first
  one out. Silently replacing a choice made two clicks ago is worse than doing
  nothing the player can see.

### Still open in M2

Hexer · Fungal Deep and The Kiln · biome claims · Expeditions · Legends and the
Blessing · tending beyond restless · hauntings · auto-draft · content to launch
volume · the first full balance pass. Auto-draft and Expeditions both take "the
hero's priority rules" as an input, and both are cheaper now than they were.
