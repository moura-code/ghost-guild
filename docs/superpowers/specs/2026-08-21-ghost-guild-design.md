# Ghost Guild — Game Design & Architecture Spec

**Version:** 2 (revised 2026-08-21 after a four-lens design review: idle, deckbuilder, first hour, commercial) · **Status:** approved for planning · **Engine:** Godot 4.3+ (GDScript) · **Target:** commercial Steam release, Early Access first

## 0. One-line pitch

Every hero you lose becomes a ghost that farms the floor it died on, forever. Push deeper, then choose where to die.

A card-battling roguelite where the living hero is the roguelite and the dead are the idle game.

## 1. Design pillars

1. **Death converts, never subtracts.** Every run end — death, Take the Watch, retreat — becomes something permanent. Prestige honors the dead instead of deleting them: the Hall keeps every epitaph.
2. **Hands at the frontier.** Manual play is only required *past* your reach. Everything within reach can run itself: Descent skips it, Expeditions farm it.
3. **The number is the graveyard.** Progress is a ladder full of your own dead, each one still working, and it never reads zero.
4. **Where you die is a decision, and the numbers agree.** Deeper must pay more for a deck that can handle it; shallow must pay more for a deck that cannot. The balance simulator enforces this as an invariant (§12).
5. **The ghost fights as you fought.** A true ghost's strength is measured from how the player actually played that deck on that floor, not guessed by a bot.
6. **Readable numbers.** Stats 0–20, fights 3–6 turns, currency shown with short suffixes; the economy stays below 1e100 by design.

## 2. Constraints and goals

- Commercial Steam release. Early Access at $7–8, 1.0 at $9.99. Positioned idle-first ("an idle game where the idle part is your dead heroes") because the look caps the price at the idle band. The Steam page is drafted at the end of M1 and goes live early in M2, with the vertical slice as the Next Fest demo. No web build: only the Steam demo counts and Godot's web export costs more than it returns.
- Solo developer, no art skills: icon-and-typography aesthetic (§9). The capsule and first screenshot are the ghost-filled tower, not cards.
- Godot 4.3+, GDScript with static typing everywhere. GdUnit4 for tests.
- Offline progress from day one. Steam achievements and cloud saves in M3.
- English and Spanish at launch; every player-facing string is a translation key.
- **Launch scope (minimum sellable):** 2 classes, 3 biomes with tier cycling, ~100 cards, 25 relics, 30 enemies, 15 events, 40 upgrades, hauntings, one prestige layer plus four chapters, Expeditions, offline, Steam integration. Everything else is post-launch (§11).

## 3. Core loop

Three clocks: a **turn** (seconds, playing cards), a **run** (5–40 minutes — player-chosen length, since a run can be one floor), the **campaign** (days to weeks).

### 3.1 The dungeon

- An infinite descent in biomes of 10 floors. Three hand-authored biomes at launch (working names): Catacombs (floors 1–10, undead), Fungal Deep (11–20, flesh and fungal), The Kiln (21–30, constructs and fire). Floors 31+ cycle the biomes at tier 2, 3, … with one mutation modifier per tier. Additional biomes are data and slot in post-launch.
- A floor is a short procedural path of 3 nodes drawn from {fight, fight, elite, event, rest, shop} by per-biome pattern tables, then the floor exit. On every 10th floor the last node is the biome boss.
- Enemy scaling defaults: HP ×1.06 per floor, damage ×1.04 per floor, plus a jump per tier. The balance simulator tunes these against the hero power curve (§4.4) so that a hero with a deck typical of floor f fights 3–6 turns on floor f.

### 3.2 A run

1. **Descend.** Choose an entry floor from 1 to the hero's **reach** = max(waypoint, camp, record depth). The **waypoint** is the floor of the deepest standing true ghost. The **camp** is the floor this hero last retreated from. The **record depth** is the deepest floor any hero has ever cleared; it persists across prestige. For every floor skipped, the hero takes one pick-of-three from that floor's biome pool — the *Descent draft*. Picks are granted once per floor per hero, so re-descending to camp gives no new picks. The auto-draft upgrade resolves picks with the hero's priority rules (§3.3) in one click. The run begins at the first node of the entry floor.
2. **Floor loop.** Play the floor's 3 nodes (§4), take the exit, repeat. Every fight won gives a pick-of-three card reward (skippable), Coin (run-only) and soul_per_kill(floor) Soul. Elites add a relic. Bosses give a rare pick and a relic.
3. **Exit decision**, at every floor exit. The screen shows the projected marginal yield of a ghost here — *measured* from this run's fights on this floor (§5.2) — an estimate for the next floor, and the estimated chance of surviving the next floor — the share of simulated descents in which the current deck clears the next floor's nodes without dying.
   - **Push** — continue.
   - **Retreat** — costs 1 Resolve; unavailable at 0. The run ends; the hero keeps deck, relics, stats *and current HP*; camp = this floor; Coin converts to Soul. Healing is not free: **Mend** at the guild costs Soul scaled by the camp floor, or the hero heals at rest nodes next run.
   - **Take the Watch** — the run ends; a *prepared* ghost (+25% strength) stands on this floor; the player sets its priority rules; Coin converts to Soul. Locked until the player's first death (§3.4).
   - **Death** (losing a fight, at any node) — a *restless* ghost (−30% until tended) stands on the floor where the hero fell; Coin converts to Soul. The very first tend of the campaign is free.
4. **Between runs.** Ghosts produce (§5). Spend Soul on upgrades, echoes, re-placing echoes, tending, Mend and Expeditions. If the hero became a ghost, a new one is created.

Push-your-luck is real only if the exit numbers are honest, which is why they are measured (pillar 5) and why the simulator asserts that deeper pays (pillar 4).

### 3.3 Heroes

- One living hero at a time (a roster is a post-launch chapter).
- Created with: a class, a generated name (renameable), the class starting deck (10 cards), the class relic, base stats plus permanent meta stat upgrades, Resolve = max Resolve (1 base, upgradeable to 4).
- Heroes keep deck, relics, stats, HP and camp between runs until they become a ghost. A hero's arc is 1–5 runs ending on a floor of the player's choosing — or not.
- **Priority rules.** When a hero Takes the Watch (and for auto-draft and Expeditions), the player orders up to three rules from a data-defined list — "Poison before attacks", "Powers on turn 1", "Block only against lethal", "Save energy for X-cost", "Draw before attacking", … — that bias the autopilot (§4.3). Choosing how your ghost will fight is the build-expression beat of dying.
- An epitaph is generated when a hero becomes a ghost: "Maren took the watch on Floor 14", "Osk fell to the Ossuary Warden on Floor 17".

### 3.4 Onboarding — the first twenty minutes

- **Second zero:** the ladder already holds the **Founder**, a ghost on floor 1 with an epitaph ("Ilse, who founded the guild, holds Floor 1"), ticking Soul. The loop is visible before it is explained.
- **First run:** Take the Watch is locked. The hero descends until they die (or retreat). Card rewards after every fight keep it from being a starter-deck slog.
- **First death:** epitaph screen; the ghost slides into its row, restless; a free Tend is offered and the number rises on screen; the rite unlocks — "Next time, take the watch before you fall."
- **Second run:** the exit screen now shows Take the Watch with its projected yield. The first death was the lesson; the second is the choice.
- Every cycle after prestige also starts with a Founder (the Legend "leaves someone behind"), so the ladder never reads zero.

### 3.5 Expeditions — the idle ghost source (M2)

An upgrade in the Descent group. The guild sends an **expedition hero** — a fresh hero with the class starting deck and meta slots — who descends under the autopilot with auto-draft to the deepest floor within reach where its projected survival stays above a threshold, then Takes the Watch (unprepared: no +25%). Expeditions resolve over real time, about 2 minutes per floor, offline included; they are deterministic from a seed, so the game resolves them on load. One expedition at a time (more through upgrades). Expedition ghosts are true ghosts and can raise the waypoint up to reach, but only manual play extends reach and only manual play earns the prepared bonus.

## 4. Combat

Slay-the-Spire-style turn-based card combat tuned for 3–6-turn fights.

### 4.1 Rules and data

- **Turn:** draw 5, gain 3 Energy (base), play cards, end turn; enemies execute their telegraphed intents. Unplayed cards discard; the discard reshuffles when the draw pile empties. Block resets each turn. HP persists across fights within a run.
- **Cards:** id, name key, pool (class, biome or neutral), type (Attack / Skill / Power), cost (0–3 or X), rarity, tags (archetypes: Bone, Shield, Poison, Ember, Draw, …), effect ops, an upgraded variant, keywords (exhaust, retain), and an `ai_value` hint.
- **Effect ops** (launch set, deliberately small): damage, block, apply_status, draw, energy, heal, exhaust_self, add_card, and a `scale` modifier that adds a stat to an amount.
- **Statuses:** Poison (deals its stacks at turn start, then −1), Bleed (on attacking), Burn (at turn end), Weak (−25% damage dealt), Vulnerable (+50% damage taken), Might and Wit buffs, Thorns, Regen.
- **Enemies:** id, biome, tags (Flesh, Undead, Fungal, Construct, Deep), HP, moves with intents (attack n×k, block, buff, debuff, summon), a pattern (sequence, weighted random or conditional), elite and boss variants. Ten per biome. Tag–archetype interactions create affinity: Poison ×0 against Construct, ×1.5 against Flesh. A ghost's **archetype** is the most common tag in its deck.
- **Relics:** passive run modifiers with trigger hooks (on_fight_start, on_turn_start, on_card_played, on_damage_taken, on_fight_end, on_floor_enter). 25 at launch; 6 in the slice.
- **Nodes:** fight (card pick, Coin, Soul); elite (plus a relic); event (authored text, 2–3 choices with effects); rest (heal 30% or upgrade a card); shop (Coin: cards, one relic, one card removal).
- **Determinism:** all randomness comes from a seeded RNG with named streams. The combat engine is pure — (state, action) → (state, events) — so the same code drives the interactive fight, the ghost simulator, Expeditions, balance tools and tests.

### 4.2 RPG stats (0–20, on the hero card)

- **Might** — +1 damage per hit on Attack cards.
- **Wit** — +1 potency to statuses applied and to Skill-based block.
- **Vigor** — +3 max HP per point, on top of the class base HP (Sexton 70).
- **Focus** — thresholds: +1 draw at 3, +1 energy at 6, +1 draw at 9, +1 energy at 12.
- Sources: class base, permanent meta upgrades (small), in-run relics and events (temporary).

### 4.3 Autopilot

A one-turn lookahead, not a greedy pick: enumerate the playable card sequences within the turn's energy (hand of 5, duplicate cards collapsed, at most 200 sequences), apply each with the pure engine, score the resulting state — lethal, damage dealt, block against incoming, statuses applied, cards drawn, energy left, HP — and play the best. The ghost's priority rules adjust the scoring weights, so draw, setup and X-cost cards are played the way their owner intended. Deterministic for a seed; fights are capped at 30 turns. Used for next-floor projections, echoes, tending deltas, Expeditions, auto-draft and the balance simulator.

### 4.4 Hero power curve

Sources of hero power, in order of magnitude: card rewards and Descent picks (deck quality), in-run relics, stats, meta starting-deck slots, and the **Legend's Blessing** — every Legend's multiplier (§6.1) applies to hero damage dealt and block gained, not only to ghosts. Without the Blessing, hero power caps at roughly 7× while enemies at floor 60 have 33× HP; with it, each cycle's threshold stays reachable. The balance simulator asserts that a hero at cycle c with typical meta clears that cycle's prestige threshold with 3–6-turn fights (§12).

### 4.5 Classes

**Sexton** (Bone / Shield — block and undead synergies): slice and launch. **Hexer** (Poison / Weak — attrition): launch, unlocked by the first true ghost in Fungal Deep. **Lampbearer** (Ember / Draw — burn and tempo): post-launch. Each class is a starting deck, base stats, a class relic and a card pool.

## 5. Ghosts and economy

### 5.1 Ghost record

Hero name, class, deck (card ids and upgrade flags), relics, stats snapshot, priority rules, floor, kind (true, expedition — which counts as true for the waypoint and as an echo source — or echo of a ghost id), cause (watch or death), prepared and restless flags, created_at, epitaph, measured stats (fights on this floor: count, wins, average turns), cached strength.

### 5.2 Strength (kills per hour) — "the ghost fights as you fought"

Ghost-time: a turn is 10 s, the respawn wait is 20 s, a lost fight costs 120 s of recovery (ghosts cannot die). strength = 3600 / E[ghost-seconds per kill].

- **True ghosts:** E[time per kill] is computed from the hero's *measured* win rate and average turns on that floor during the run, blended with a 50-fight autopilot simulation by sample size, weight w = n / (n + 3) on the measurement. A hero who cleared the floor's two fights in four turns each leaves a ghost that fights like that.
- **Simulation only** (autopilot with the ghost's priority rules): next-floor projections, echoes, tending deltas, Expeditions.
- Computed on placement and on change — never per tick. Multipliers applied outside: prepared (+25%), restless (−30%), global ghost upgrades, Legends. Hauntings act on spawn_rate (§5.6).

### 5.3 Floor saturation — soft cap

Each floor f has `spawn_rate(f) = 60 × 1.08^f` kills/hour and `soul_per_kill(f) = 1.3^f` (defaults). With S = Σ strength of the floor's ghosts:

**output/h = min(spawn_rate, S) × soul_per_kill + max(0, S − spawn_rate) × 0.25 × soul_per_kill**

Saturation = S / spawn_rate, shown as "% farmed". Beyond 100% a floor still pays a quarter rate ("hunting stragglers"), so strength upgrades, tending and Legends never read zero, while spreading across floors still wins. The marginal yield of a candidate ghost is output-with minus output-without; that is the number on the exit screen. Invariant (§12): for a deck typical of depth f, marginal yield rises with f.

### 5.4 Currencies

- **Soul** (universal). Sources: all ghosts; soul_per_kill per fight won in runs; Coin conversion at run end. Sinks: upgrades, echoes, Calls, tending, Mend, Expeditions.
- **Coin.** Run-only; shops; converts to Soul at run end.
- **Ink.** One per Legend created; the layer-2 currency (§6.2).
- **Biome claims** replace per-biome currencies: the first true ghost standing in a biome unlocks that biome's card pool for the Descent draft and shops, its biome upgrades, and (for Fungal Deep) the Hexer.

### 5.5 Séance: echoes, Calls, tending, laying to rest

- **Echo:** a copy of a true ghost, placed on any floor ≤ waypoint. Strength = 75% × min(the source's own strength, the source's deck simulated on the echo's floor) — an echo can never out-earn its source, so a deep restless death cannot be laundered into shallow income. Cost = 50 × 1.15^(echoes owned) Soul. Echoes stay linked to their source: tending the source updates all its echoes. Echoes are how the ghost count grows without a run.
- **Call:** re-place an echo on another floor for 25% of a new echo's cost. True ghosts stay where they fell. Every waypoint push, tend and new upgrade becomes a redeploy puzzle.
- **Tending:** spend Soul to upgrade a card in a ghost's deck or add a relic from the compendium; the ghost re-simulates (its measured stats are kept as the baseline and the simulated delta is applied). Tending also clears restless; the campaign's first tend is free. Costs scale with floor.
- **Lay to rest:** voluntarily move a ghost to the Ossuary. It still counts toward the next Legend. The waypoint is computed from standing true ghosts.

### 5.6 Hauntings (M2)

A floor with three or more ghosts sharing an archetype forms a Haunting: +15% spawn_rate per matching ghost, capped at +75%. Synergy raises the floor's cap — "a bigger floor" — rather than each ghost's strength.

### 5.7 Dungeon shifts — cut from launch

A maintenance tax in the launch design. Post-launch candidate, reframed as opportunity: a shifted floor pays +50% to a counter-archetype ghost.

### 5.8 Production, offline progress, Expeditions on load

Production is integrated by real time (rate × elapsed), never per frame; rates recompute only on change. On load, elapsed time is capped by the offline cap (8 h base; upgrades to 24 h and 72 h); in-flight Expeditions resolve deterministically for the elapsed time. A "While you were away" summary lists Soul gained and ghosts placed by Expeditions.

### 5.9 Meta upgrades (Guild panel)

Exponential costs (×1.6 per level default). Base costs are data, tuned by the simulator so the first upgrade is affordable within the first run's Soul.

- **Hero:** Might / Wit / Vigor / Focus +1 (capped), max Resolve +1 (to 4), starting-deck slots, a starting relic slot, Mend discount.
- **Ghosts:** global strength %, global spawn %, offline cap, restless penalty reduction, tending discount.
- **Descent:** auto-draft, Expedition unlock, expedition slots, expedition speed, shop discount, starting Coin.
- **Séance:** echo discount, echo strength (75% → 90%), Call discount.

## 6. Prestige

### 6.1 Layer 1 — The Dungeon Forgets (Legends)

Unlocked when a true ghost stands on floor 15; the threshold rises 15 per cycle (15, 30, 45, …), so the first prestige lands within the first few hours. The player triggers it at will. All ghosts — true, expedition, echoes, Ossuary — merge into one **Legend**: a permanent multiplier of 1 + k × sqrt(merged_mass / M0) applied to ghost strength *and* to hero damage and block (the Legend's Blessing, §4.4), plus a **trait** from the dominant archetype (a Poison Legend makes the hero's Poison cards apply +1 stack). One Legend can be invoked per run as an extra relic. **The Hall keeps every merged epitaph** — the Legend is a memorial, not a deletion. The dungeon regenerates with a new seed and a new mutation per biome. Kept: reach (record depth), unlocks, biome claims, upgrades, compendium, Legends, Ink. Reset: the ladder (a new Founder stands on floor 1), Soul, the waypoint. Because reach persists, the next cycle starts with a Descent straight to the old frontier, not a replay.

### 6.2 Layer 2 — The Chronicle

Unlocked at 5 Legends. Spend Ink on permanent **Chapters**. Launch: Deeper Roots (each cycle's Founder stands on floor 10), The Breeding Dark (+spawn on all floors), Old Blood (keep 10% of Soul across prestige), Depth Seals (opt-in difficulty modifiers that multiply yield). Post-launch: Two Heroes (a roster), Second Sight (two Legend slots).

### 6.3 Layer 3 — The Dungeon Dreams (post-launch)

Alternate dungeons with different biome sets and rule twists; a dungeon is data, so this is a content addition. Not designed further here.

## 7. Content model

JSON under `data/`, loaded at startup into typed definitions and validated: unique ids, resolving references, numbers in range, every string a translation key. A validation failure is a test failure. **Launch:** 2 classes, ~100 cards, 25 relics, 30 enemies (3 biomes), 15 events, 40 upgrade nodes, 4 chapters, ~12 priority rules. **Slice:** 1 class, 30 cards, 6 relics, 10 enemies (8 regular, 1 elite, 1 boss), 3 events, 10 upgrades. Translations in CSV (English, Spanish).

## 8. Technical architecture (Godot 4, GDScript)

Principle: **the simulation core has no Node dependencies.** RefCounted classes that run headless; the UI renders the engine's event stream and is never the source of truth.

```
core/      pure logic, no scene tree
  rng.gd                 seeded RNG with named streams
  content/               typed defs, loader, validator
  combat/                FightState, CombatEngine, EffectResolver, StatusSystem, EnemyAI, Autopilot (lookahead), PriorityRules
  run/                   RunState, Hero, RunStats (per-floor measurement), FloorGenerator, DescentDraft, Rewards
  ghosts/                Ghost, Ladder (soft-cap saturation), Strength (measured + simulated blend), YieldSimulator
  economy/               Wallet, Upgrades, Production (offline), Expeditions (deterministic scheduler), Prestige
  onboarding/            Founder seeding, first-death rite state
  save/                  SaveGame, migrations/
game/      scenes and UI, observing core through signals and events
  screens/               ladder (tower cross-section), descent, floor_map, fight, exit_decision, epitaph, offline_summary, guild, seance, hall, expeditions
  widgets/               card_view, floor_row, ghost_list, hero_card, intent_icon, number_label, rule_picker
  theme/                 theme.tres, fonts/, icons/
data/      JSON content by type (cards, enemies, relics, biomes, classes, events, upgrades, chapters, rules)
tools/     headless scripts run with `godot --headless -s`: balance_sim, yield_table, validate_content
tests/     GdUnit4 suites
```

- Combat engine API: `apply(state, action) -> (state, events)`. Events such as `{type: "damage", target, amount, source}` drive animations, logs and test assertions alike. RunStats listens to the same stream to measure fights per floor.
- Simulations run as `WorkerThreadPool` tasks; results cache on the ghost. Global multipliers apply outside the simulation, so buying an upgrade never re-simulates.
- Expeditions: a seed, a start time and a hero; resolution is a pure function of elapsed time, so load, offline and live play agree.
- Economy: rates recomputed on change; the ladder refreshes at 10 Hz from rate × elapsed.
- Save: `user://saves/slot1.json` with rotating backups, a `version` field and one migration per version. Autosave on run end, every purchase, every 60 s. Steam Cloud (GodotSteam) points at this directory in M3.
- Numbers: 64-bit doubles with a suffix formatter (K, M, B, T, then aa, ab, …); the economy stays below 1e100.
- Static typing everywhere; no per-frame allocations in the fight loop.

## 9. UI and aesthetic

Screens: Ladder (home), Descent, Floor map, Fight, Exit decision, Epitaph, Offline summary; panels: Guild, Séance, Hall of Legends, Hero, Expeditions.

- **Ladder:** drawn as a **tower cross-section** — stacked floors with biome color bands, ghost silhouettes standing in them, saturation as fill, output per hour, the waypoint marker, the Founder at the top. This is the capsule image, the first screenshot and the first three seconds of the trailer.
- **Exit decision:** three numbers the player learns to read — yield here, yield next floor, survival chance next floor — and the rule picker on Take the Watch.
- **Fight:** enemies across the top (icon, HP bar, intent), hero bottom-left (HP, Block, Energy, stats), hand along the bottom, piles in the corners. Every animation comes from the event stream: floating numbers, tweens, screen shake, CPUParticles2D.
- **Epitaph moment:** name, floor, epitaph, the ghost sliding into its row, the number starting to tick. The emotional beat of the game — give it time and sound. The trailer opens here.
- **Look:** near-black stone, bone-white text, one accent per biome (ivory, violet, orange), ghosts in translucent cyan with a slow float. A display serif for titles (Cinzel or IM Fell), a humanist sans for body and numbers (Inter). Icons from game-icons.net (CC BY 3.0, credited). Cards are typographic: cost bubble, icon, name, text, rarity edge. References: Cultist Simulator, Luck be a Landlord, A Dark Room.

## 10. Testing and balance

- GdUnit4 unit tests for everything in `core/`, deterministic through seeds: effect ops, statuses, enemy patterns, lookahead autopilot, priority rules, measured/simulated blending, soft-cap saturation math, echo cap, production and offline math, Expedition determinism, prestige math, onboarding state, save round-trips and migrations, content validation. Invariants: autopilot fights end within 30 turns; the economy never produces NaN or Inf.
- UI: smoke tests only.
- `tools/balance_sim.gd`: simulates runs at given meta levels and reports death-floor distributions, yield tables per archetype × floor, time-to-first-prestige, and **asserts the §12 invariants**. Run before every milestone; this is how every curve gets its real value. It tunes numbers; it cannot tune fun — card and enemy design get the most hand-iteration time of anything in the project.
- Core logic is developed test-first.

## 11. Milestones

**M1 — Vertical slice** (the first implementation plan). Proves that "dying on purpose to leave a ghost" is fun and that the first twenty minutes land.
Scope: Sexton; Catacombs floors 1–10 with boss; 30 cards, 10 enemies, 6 relics, 3 events, rest and shop nodes; card rewards after fights; the full run loop — Descent with one pick per skipped floor, floor loop, exit decision with measured yield, simulated next-floor yield and survival chance, Take the Watch, death, Retreat with Resolve (max 1, upgradeable to 2) and paid Mend; the Founder and the first-death rite; the Ladder as a tower cross-section with soft-cap saturation and Soul; echoes with the source cap, and Calls; a minimal Tend that clears restless (first one free); 10 upgrades including global spawn %; lookahead autopilot (priority rules deferred); offline progress; save and load; the intentional placeholder aesthetic; a Steam page draft.
Out of scope: priority rules, Expeditions, hauntings, tending beyond restless, laying to rest, prestige, second class, Steam integration, localization.
Success criteria: in a two-hour playtest, testers understand the ghost loop by the end of their first death, deliberately choose where to die by their third run, and want to check the ladder later; hour-one retention in the playtest above 60%; average run 5–30 minutes by the player's choice; a yield simulation completes in under 100 ms on a worker thread; the balance simulator passes the "deeper pays" invariant for floors 1–10.

**M2 — Full loop.** Hexer; Fungal Deep and The Kiln with tier cycling; biome claims; Expeditions; priority rules; Legends with the Blessing and reach persistence; tending; hauntings; auto-draft; content to launch volume; first full balance pass. Steam page live; the slice as the Next Fest demo.

**M3 — Early Access release.** The Chronicle (four chapters, Depth Seals); Steam integration (achievements, cloud saves); Spanish localization; polish; trailer opening on the epitaph beat.

**Post-launch.** Lampbearer, biomes 4–5, Two Heroes and Second Sight, shifts as opportunities, layer 3 dungeons.

## 12. Defaults and balance invariants

All numeric defaults (enemy scaling, spawn_rate, soul_per_kill, cost growth, echo cost, Legend k and M0, ghost-time constants, Expedition pace, survival threshold) are starting points for the simulator. The simulator must assert, and M1 must pass for floors 1–10:

1. **Deeper pays:** for a deck typical of depth f (produced by the simulator's own runs), the marginal yield of a prepared ghost rises with f.
2. **Watch beats the corpse:** on any floor, Take the Watch yields more than dying there and echoing the corpse anywhere.
3. **Retreat costs:** the expected value of retreating to Mend is below pushing for a hero with a positive survival estimate, except when HP is low.
4. **Cycle clearable:** a hero at cycle c with typical meta reaches the cycle's prestige threshold with 3–6-turn fights (M2 onward).
5. **First purchase early:** the Soul from the Founder plus the first run buys the first upgrade within 20 minutes.
