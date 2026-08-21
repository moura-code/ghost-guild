# Ghost Guild — Game Design & Architecture Spec

**Date:** 2026-08-21 · **Status:** draft for review · **Engine:** Godot 4.3+ (GDScript) · **Target:** commercial Steam release

## 0. One-line pitch

A card-battling roguelite where every hero who dies becomes a ghost that keeps farming the floor they fell on — forever. The living hero is the roguelite; the dead are the idle game.

## 1. Design pillars

1. **Death converts, never subtracts.** Every run end — death, Take the Watch, retreat — turns into something permanent. Nothing is ever lost.
2. **Hands at the frontier.** Manual play only happens where you have never been; everything behind you runs itself.
3. **The number is the graveyard.** Progress is visible as a ladder full of your own dead, each one still working.
4. **Where you die is a decision.** Floor depth, floor saturation and deck–floor affinity make "where" a puzzle, not a default.
5. **Readable numbers.** Stats 0–20, fights 3–6 turns, currency shown with short suffixes; the economy stays below 1e100 by design.

## 2. Constraints and goals

- Commercial Steam release (Windows first; web export for a demo). Weeks of play at launch; months through post-launch layers.
- Solo developer, no art skills: icon-and-typography aesthetic (§9).
- Godot 4.3+, GDScript with static typing everywhere. GdUnit4 for tests.
- Offline progress from day one. Steam achievements and cloud saves in milestone 3.
- English and Spanish at launch; every player-facing string is a translation key.

## 3. Core loop

Three clocks: a **turn** (seconds, playing cards), a **run** (15–40 minutes, pushing the frontier), the **campaign** (days to weeks: ghosts accumulate, the economy grows, you prestige).

### 3.1 The dungeon

- An infinite descent in biomes of 10 floors. Five hand-authored biomes at launch (working names): Catacombs (floors 1–10, Bone), Fungal Deep (11–20, Spore), The Kiln (21–30, Ember), Drowned Halls (31–40, Brine), Clockwork Vaults (41–50, Rust). Floors 51+ cycle the same biomes at tier 2, 3, … with mutation modifiers, so depth never ends.
- A floor is a short procedural path of 3 nodes drawn from {fight, fight, elite, event, rest, shop} by per-biome pattern tables, then the floor exit. On every 10th floor the last node is the biome boss.
- Enemy scaling defaults: HP ×1.06 per floor, damage ×1.04 per floor, plus a jump per biome tier. All curves are tuned by the balance simulator (§10).

### 3.2 A run

1. **Descend.** Choose an entry floor from 1 to the hero's *reach* = max(waypoint, hero camp). The **waypoint** is the floor of the deepest *true* ghost (echoes do not count). The **camp** is the floor the hero last retreated from. For every biome passed on the way down, the player takes one pick-of-three from that biome's unlocked card pool — the *Descent draft*, standing in for the floors skipped. The run begins at the first node of the entry floor.
2. **Floor loop.** Play the floor's 3 nodes (§4), take the exit, repeat. Each fight won drops Coin (run-only) and soul_per_kill(floor) Soul.
3. **Exit decision**, at every floor exit. The screen shows the projected *marginal* yield of a ghost with the current deck on this floor and an estimate for the next floor (§5.3).
   - **Push** — continue to the next floor.
   - **Retreat** — costs 1 Resolve; unavailable at 0. The run ends; the hero survives with deck, relics and stats and heals fully at the guild; camp = this floor; Coin converts to Soul.
   - **Take the Watch** — the run ends; a *prepared* ghost (+25% strength) is placed on this floor; Coin converts to Soul.
   - **Death** (losing a fight, at any node) — a *restless* ghost (−30% strength until tended) is placed on the floor where the hero fell; Coin converts to Soul.
4. **Between runs.** Ghosts produce (§5). The player spends Soul and Essence on upgrades, tending and echoes. If the hero became a ghost, a new hero is created.

Every run is push-your-luck: one more floor means a richer ghost; one floor too many means a restless one, and the end of that hero's arc.

### 3.3 Heroes

- One living hero at a time (a roster is a layer-2 chapter, §6.2).
- A hero is created with: a class (unlocked), a generated name (renameable), the class starting deck (10 cards), the class relic, base stats plus permanent meta stat upgrades, and Resolve = max Resolve (1 base, upgradeable to 4).
- Heroes keep deck, relics, stats and camp between runs until they become a ghost. A hero's arc is 1–5 runs, ending on a floor of the player's choosing — or not.
- An epitaph is generated when a hero becomes a ghost: "Maren took the watch on Floor 14", "Osk fell to the Ossuary Warden on Floor 17".

## 4. Combat

Slay-the-Spire-style turn-based card combat tuned for 3–6 turn fights.

- **Turn:** draw 5, gain 3 Energy (base), play cards, end turn; enemies then execute their telegraphed intents. Unplayed cards are discarded; the discard pile reshuffles when the draw pile empties. Block resets each turn. HP persists across fights within a run.
- **Cards:** id, name key, pool (class, biome or neutral), type (Attack / Skill / Power), cost (0–3 or X), rarity (common / uncommon / rare), tags (archetypes: Bone, Shield, Poison, Ember, Draw, …), effect ops, an upgraded variant, keywords (exhaust, retain), and an `ai_value` hint for the autopilot.
- **Effect ops** (launch set, kept deliberately small): damage, block, apply_status, draw, energy, heal, exhaust_self, add_card, and a `scale` modifier that adds a stat to an amount. Complexity comes from combinations, not from the op list.
- **Statuses:** Poison (deals its stacks at turn start, then −1), Bleed (on attacking), Burn (at turn end), Weak (−25% damage dealt), Vulnerable (+50% damage taken), Might and Wit buffs, Thorns, Regen.
- **RPG stats** (0–20, shown on the hero card):
  - **Might** — +1 damage per hit on Attack cards.
  - **Wit** — +1 potency to statuses applied and to Skill-based block.
  - **Vigor** — +3 max HP per point, on top of the class base HP (Sexton 70).
  - **Focus** — thresholds: +1 draw at 3, +1 energy at 6, +1 draw at 9, +1 energy at 12.
  - Sources: class base, permanent meta upgrades (small), in-run relics and events (temporary).
- **Classes** (3 at launch): **Sexton** (Bone / Shield — block and undead synergies), **Hexer** (Poison / Weak — attrition), **Lampbearer** (Ember / Draw — burn and tempo). Each class is a starting deck, base stats, a class relic and a card pool. Classes are unlocked with biome Essence. The vertical slice ships the Sexton only.
- **Enemies:** id, biome, tags (Flesh, Undead, Fungal, Construct, Deep), HP, moves with intents (attack n×k, block, buff, debuff, summon), a pattern (sequence, weighted random or conditional), elite and boss variants. Tag–archetype interactions create affinity: e.g. Poison ×0 against Construct, ×1.5 against Flesh. A ghost's **archetype** is the most common tag among its deck's cards.
- **Relics:** passive run modifiers with trigger hooks (on_fight_start, on_turn_start, on_card_played, on_damage_taken, on_fight_end, on_floor_enter). About 40 at launch; 6 in the slice.
- **Nodes:** fight; elite (double reward); event (authored text, 2–3 choices with effects); rest (heal 30% or upgrade a card); shop (Coin: cards, one relic, one card removal).
- **Determinism:** all randomness comes from a seeded RNG with named streams. The combat engine is pure — (state, action) → (state, events) — so the same code drives the interactive fight, ghost yield simulation, balance tools and tests.
- **Autopilot** (the ghost brain; also produces the projected yield): a greedy policy — take lethal if available; if incoming damage exceeds current block, prefer block cards; otherwise play the affordable cards with the highest `ai_value`, with simple synergy bonuses. Deterministic for a given seed.

## 5. Ghosts and economy

### 5.1 Ghost record

Hero name, class, deck (card ids and upgrade flags), relics, stats snapshot, floor, kind (true, or echo of a ghost id), cause (watch or death), prepared and restless flags, created_at, epitaph, cached strength.

### 5.2 Strength (kills per hour)

Computed by the headless simulator when a ghost is placed and whenever its deck, relics, stats or floor change (tending, shifts) — never per tick. The simulator runs 50 fights of the ghost's deck against the floor's encounter table with the autopilot. Ghost-time: a turn is 10 s, the respawn wait is 20 s, and a lost fight costs 120 s of recovery (ghosts cannot die). strength = 3600 / E[ghost-seconds per kill]. Multipliers applied outside the simulation: prepared (+25%), restless (−30%), global ghost upgrades and Legends. Hauntings act on the floor's spawn_rate instead (§5.6).

### 5.3 Floor saturation

Each floor f has `spawn_rate(f) = 60 × 1.08^f` kills/hour and `soul_per_kill(f) = 1.10^f` (defaults). **Floor output per hour = min(spawn_rate, Σ strength of its ghosts) × soul_per_kill.** Saturation = Σ strength / spawn_rate, shown on the ladder as "% farmed". The marginal yield of a candidate ghost is output-with minus output-without; that is the number on the exit screen. Deep floors have far more spawn than any single ghost can use, but a deck that loses most fights there has tiny strength — so every deck has a natural best floor: the deepest one it still beats reliably.

### 5.4 Currencies

- **Soul** (universal). Sources: all ghosts; soul_per_kill per fight won during runs; Coin conversion at run end. Sinks: upgrades, echoes, tending, attuning.
- **Biome Essence** (five: Bone, Spore, Ember, Brine, Rust). Produced alongside Soul by ghosts in that biome at essence_per_kill(f); tier-2+ floors produce the same Essences faster. Sinks: unlock the biome's card pool for the Descent draft and shops, unlock classes, biome-specific upgrades. Not in the slice.
- **Coin.** Run-only; spent in shops; converts to Soul at run end so it is never wasted.
- **Ink.** One per Legend created; the layer-2 currency (§6.2).

### 5.5 Séance: echoes, tending, laying to rest

- **Echo:** a copy of a true ghost, placed on any floor ≤ waypoint, at 75% of the source's strength as simulated on the echo's own floor. Echoes stay linked to their source: tending the source updates all its echoes. Cost = 50 × 1.15^(echoes owned) Soul. Echoes are how the ghost count grows while the player is not running.
- **Tending:** spend Soul to upgrade a card in a ghost's deck or to add a relic from the compendium (relics found this cycle); the ghost re-simulates. Tending also clears the restless flag. Costs scale with the ghost's floor.
- **Lay to rest:** voluntarily move a ghost to the Ossuary. It still counts toward the next Legend. Never required. The waypoint is always computed from *standing* true ghosts, so laying the deepest one to rest lowers it.

### 5.6 Hauntings

A floor with three or more ghosts sharing an archetype forms a Haunting: +15% spawn_rate per matching ghost, capped at +75%. Synergy raises the floor's cap rather than each ghost's strength — a Haunting means "a bigger floor."

### 5.7 Dungeon shifts

Every 6 hours of real time, one random claimed floor in the deeper half of the ladder gains a shift modifier (an enemy resistance or an added enemy). Its ghosts re-simulate; output never drops below 50% of the pre-shift value. Fixes: **Attune** (a Soul cost that removes the penalty) or claim the floor again with a counter-deck. The ladder shows a badge and the offline summary lists shifts. Not in the slice.

### 5.8 Production and offline progress

Production is integrated by real time (rate × elapsed), never accumulated per frame. Rates are recomputed only when something changes. On load, elapsed time is capped by the offline cap (8 h base; upgrades to 24 h and 72 h). A "While you were away" summary lists Soul and Essence gained and any shifts.

### 5.9 Meta upgrades (Guild panel)

Groups, each with exponential costs (×1.6 per level default):

- **Hero:** Might / Wit / Vigor / Focus +1 (capped), max Resolve +1 (to 4), starting-deck slots (add a compendium card to the starting deck), a starting relic slot.
- **Ghosts:** global strength %, global spawn %, offline cap, restless penalty reduction, tending discount.
- **Descent:** auto-draft, an extra pick per biome, shop discount, starting Coin.
- **Séance:** echo discount, echo strength (75% → 90%).

## 6. Prestige

### 6.1 Layer 1 — The Dungeon Forgets (Legends)

Unlocked when a true ghost stands on floor 30; the threshold rises each cycle (30, 45, 60, …). The player triggers it at will. All ghosts — true, echoes and Ossuary — merge into one **Legend**, which grants a permanent global ghost-strength multiplier of 1 + k × sqrt(merged_mass / M0) (merged_mass = Σ strength at merge; k and M0 tuned so repeated prestiges keep mattering) and a **trait** derived from the dominant archetype among the merged ghosts (e.g. a Poison Legend makes the hero's Poison cards apply +1 stack). One Legend can be *invoked* per run as an extra relic (more slots through layer 2). The dungeon regenerates with a new seed and a new mutation per biome for the cycle, so the best decks change. Kept: unlocks, upgrades, compendium, Legends, Ink. Reset: the ladder, Soul and Essence (an upgrade keeps a percentage), the waypoint — the stronger starting deck and the Legend multipliers make the early floors fast.

### 6.2 Layer 2 — The Chronicle

Unlocked at 5 Legends. Spend Ink on permanent **Chapters** that change the game's structure: Two Heroes (a roster; choose who descends), Deeper Roots (cycles start with the waypoint at floor 10), Second Sight (two Legend slots per run), The Breeding Dark (+spawn on all floors), Old Blood (keep 10% of Soul across prestige), Depth Seals (opt-in difficulty modifiers that multiply yield). About 12 chapters at launch.

### 6.3 Layer 3 — The Dungeon Dreams (post-launch)

Alternate dungeons with different biome sets and rule twists. A dungeon definition is data (§7), so this is a content addition, not a rewrite. Not designed further here.

## 7. Content model

JSON under `data/`, loaded at startup into typed definitions and validated: unique ids, resolving references, numbers in range, every string a translation key. A validation failure is a test failure. Launch volume: 3 classes, ~160 cards, ~40 relics, ~50 enemies across 5 biomes, ~30 events, ~60 upgrade nodes, ~12 chapters. Slice volume: 1 class, 25 cards, 6 relics, 10 enemies (8 regular, 1 elite, 1 boss), 3 events, 8 upgrades. Translations live in CSV (English, Spanish).

## 8. Technical architecture (Godot 4, GDScript)

Principle: **the simulation core has no Node dependencies.** It is RefCounted classes that run headless; the UI is a renderer of the engine's event stream and never the source of truth.

```
core/      pure logic, no scene tree
  rng.gd                 seeded RNG with named streams
  content/               typed defs, loader, validator
  combat/                FightState, CombatEngine, EffectResolver, StatusSystem, EnemyAI, Autopilot
  run/                   RunState, Hero, FloorGenerator, DescentDraft
  ghosts/                Ghost, Ladder (saturation math), YieldSimulator
  economy/               Wallet, Upgrades, Production (offline), Prestige
  save/                  SaveGame, migrations/
game/      scenes and UI, observing core through signals and events
  screens/               ladder, descent, floor_map, fight, exit_decision, epitaph, offline_summary, guild, seance, hall
  widgets/               card_view, floor_row, ghost_list, hero_card, intent_icon, number_label
  theme/                 theme.tres, fonts/, icons/
data/      JSON content by type (cards, enemies, relics, biomes, classes, events, upgrades, chapters)
tools/     headless scripts run with `godot --headless -s`: balance_sim, yield_table, validate_content
tests/     GdUnit4 suites
```

- Combat engine API: `apply(state, action) -> (state, events)`. Events such as `{type: "damage", target, amount, source}` drive animations, logs and test assertions alike.
- Yield simulations run as `WorkerThreadPool` tasks; results are cached on the ghost. Global multipliers (upgrades, Legends) and haunting spawn bonuses apply outside the simulation, so buying an upgrade never triggers a re-simulation.
- Economy: rates recomputed on change; the ladder UI refreshes at 10 Hz from rate × elapsed.
- Save: `user://saves/slot1.json` with rotating backups, a `version` field and one migration function per version. Autosave on run end, on every purchase, and every 60 s. Steam Cloud (GodotSteam) points at this directory in milestone 3.
- Numbers: 64-bit doubles with a suffix formatter (K, M, B, T, then aa, ab, …). The economy is designed to remain below 1e100.
- Static typing everywhere; no per-frame allocations in the fight loop.

## 9. UI and aesthetic

Screens: Ladder (home), Descent, Floor map, Fight, Exit decision, Epitaph, Offline summary; side panels: Guild, Séance, Hall of Legends, Hero.

- **Ladder row:** floor number, biome color band, archetype icons with ghost counts, saturation bar, output per hour, shift badge; a waypoint marker; the Descend button in the header next to Soul, Essences and the hero card.
- **Fight:** enemies across the top (icon, HP bar, intent), hero bottom-left (HP, Block, Energy, stats), hand along the bottom, piles in the corners. Every animation comes from the event stream: floating numbers, tweens, screen shake, CPUParticles2D.
- **Epitaph moment:** name, floor, epitaph, then the new ghost slides into its ladder row. This is the emotional beat of the game — give it time and sound.
- **Look:** near-black stone background, bone-white text, one accent per biome (ivory, violet, orange, teal, copper), ghosts in translucent cyan with a slow float. A display serif for titles (Cinzel or IM Fell), a humanist sans for body and numbers (Inter). Icons from game-icons.net (CC BY 3.0, credited). Cards are typographic: cost bubble, icon, name, text, rarity edge. References: Cultist Simulator, Luck be a Landlord, A Dark Room.

## 10. Testing and balance

- GdUnit4 unit tests for everything in `core/`, deterministic through seeds: effect ops, statuses, enemy patterns, saturation math, yield-simulator determinism, production and offline math, prestige math, save round-trips and migrations, content validation. Invariants: an autopilot fight ends within 30 turns; the economy never produces NaN or Inf.
- UI: smoke tests only (scenes instantiate and bind).
- `tools/balance_sim.gd`: simulates runs with the autopilot at given meta levels and reports death-floor distributions, yield tables per archetype × floor, and time-to-first-prestige, as CSV. Run before every milestone; this is how every curve in §3–§6 gets its real value.
- Core logic is developed test-first.

## 11. Milestones

**M1 — Vertical slice** (the first implementation plan). Proves that "dying on purpose to leave a ghost" is fun.
Scope: Sexton; Catacombs floors 1–10 with boss; 25 cards, 10 enemies, 6 relics, 3 events, rest and shop nodes; the full run loop — Descent (trivial at this depth), floor loop, exit decision with projected yield, Take the Watch, death, Retreat with Resolve (max 1, upgradeable to 2); the Ladder with saturation and Soul; echoes; a minimal Tend action that only clears restless; 8 upgrades; offline progress; save and load; the intentional placeholder aesthetic (palette, fonts, icons).
Out of scope: Essence, hauntings, shifts, tending beyond clearing restless, laying to rest, prestige, Steam, localization.
Success criteria: in a two-hour playtest, testers understand the ghost loop without explanation by their second run, deliberately choose where to die by their third, and say they want to come back to check the ladder; average run length 15–30 minutes; a yield simulation completes in under 100 ms.

**M2 — Full loop.** Remaining biomes and classes, Essence, tending, hauntings, shifts, Legends, auto-draft, content to launch volume, first full balance pass.

**M3 — Release.** The Chronicle, Steam integration (achievements, cloud saves), Spanish localization, polish, trailer and store page, web demo.

**Post-launch.** Layer 3 dungeons, more chapters, balance from telemetry and community.

## 12. Defaults to be confirmed by simulation

All numeric defaults above (enemy scaling, spawn_rate, soul_per_kill, upgrade and echo cost growth, Legend k and M0, ghost-time constants) are starting points for the balance simulator, not commitments. Two things to watch in M1: that echoes at 75% plus their cost curve leave true ghosts valuable (unique decks and tending propagation should ensure it), and that floors average under five minutes so runs stay inside 15–40 minutes.
