# Ghost Guild: player clarity, progression and a more readable world

Created: 2026-09-08. Finalized: 2026-09-09.
Status (2026-09-10): implementation and automated validation complete;
new-player release gate pending. See the
[implementation evidence](2026-09-09-player-clarity-validation.md) and
[held-out difficulty summary](2026-09-09-difficulty-summary.csv).
Checked items record delivered code or completed checks, not novice acceptance.
The P2 defensive-policy HP-loss deviation still needs player review.
Baseline: hybrid `main` at `a3c72df`. This plan follows the
[hybrid integration](2026-09-06-hybrid-2d-3d-integration.md) and its
[validation record](2026-09-06-hybrid-validation.md).

The playtest finding is specific: **a fresh campaign reached Floor 4 while
taking almost no damage**. Treat that as an early-game balance problem to
investigate, not as evidence that late-game upgrades are too strong. No new
balance measurements were run while preparing this plan.

The next release should make this loop understandable and rewarding:
**read a threat → make a build or route decision → feel its consequences →
turn the run into lasting progress → return stronger**. The interface,
difficulty, shop, room identities and guild should reinforce that same loop.

## 1. Design decisions

1. **Difficulty belongs to depth and chosen risk.** Keep authored depth/tier
   scaling and explicit challenges such as Seals. Do not raise enemy stats
   automatically in response to purchased upgrades, time played or recent
   wins. Earlier floors becoming easier is part of the incremental reward;
   the frontier is where difficulty should remain.
2. **Early play must require decisions, not unavoidable damage.** A good
   block, kill or status sequence can produce a flawless fight. Repeated
   flawless floors with a starter deck and weak decisions should be unusual.
   Do not force a death to teach the ghost economy.
3. **Explain a decision where it is made.** Show the object being changed,
   before/after effects, cost, benefit recipient and duration before the
   player spends or commits. A glossary supports these explanations.
4. **Rooms are places with persistent state.** Visiting, completing an
   encounter and exhausting a service are different things. Returning to a
   shop must preserve stock; returning to a cleared fight must not respawn it.
5. **Room identity is shared across the world and UI.** A doorway sign, map
   icon, compass marker and interaction prompt must describe the same node.
   Use shape, text and color together.
6. **Main Hall means the walkable guild hub.** Its visual pass also improves
   the Hall of Legends station, but does not replace the useful guild tabs.
   The guild's appearance should reflect earned progress without adding a
   separate decoration currency or another progression grind.

## 2. What already exists, and the actual gaps

| Area | Current implementation | Work required |
| --- | --- | --- |
| Help and inspection | F1 controls, hero/ghost details, card/pile inspector, UI scale, EN/ES and reduced motion | Explain stats, keywords, upgrade scope and concrete consequences; improve discoverability and compact layouts. |
| Card upgrades | `rest_upgrade` changes one card UID; the button says `Sharpen {card}` | Identify that card and show the upgraded result before committing. Distinguish it from permanent guild upgrades and ghost tending. |
| Difficulty | Floor growth, enemy moves, encounters, tiers, mutations and Legends already exist | Add early-run measurements and tune the starter challenge and power curve together. |
| Balance checks | `BalanceSim` checks deeper yields, prepared Watch versus corpse/echo and early purchase affordability | It does not establish that fresh-campaign combat is challenging. Keep it and add a separate difficulty report. |
| Map | M opens a full-floor schematic with numbered rooms, completion flags, player arrow and compass marking | Make M visible in exploration; add room types, risk/reward descriptions, service availability and matching doorway indicators. |
| Room types | Normal fights, elites, bosses, events, rest and shops are already generated | Give them distinct identities and clear completion/visit policies. Make optional risk explicit in a later milestone. |
| Shop | `RunEngine._apply_shop("leave")` clears `run.shop` and resolves the node; `EncounterMarker` fires once | Persist shops per room and allow deliberate interaction on each visit, including after stairs unlock. |
| Rooms | `LayoutGenerator` makes rectangular rooms and corridors; `Dressing` selects three generic props per room | Add authored room compositions and biome-specific activity while preserving navigation and combat space. |
| Guild | A fixed room with five stations, well and basic props | Give it an authored composition, architectural detail, distinct station areas and visible campaign history. |

## 3. Delivery order

Sizes are relative scope, not calendar estimates. Each milestone ends with a
playable build, focused evidence and a short playtest before expanding it.

| Milestone | Deliverable | Priority / size | Dependencies |
| --- | --- | --- | --- |
| P0 | Reproducible fresh-campaign and progression baselines | First / small | Current hybrid |
| P1 | Understandable stats, cards, Forge and purchases | First / medium | P0 definitions and examples |
| P2 | First early-difficulty pass | First / medium | P0; P1 explanations before player review |
| P3 | Shared room identities, typed map and doorway signs | Next / medium | P1 interaction language |
| P4 | Persistent shops and deliberate optional-room decisions | Next / large | P3; migration design before state changes |
| P5 | Room presets and environmental life | Then / large | P3 room roles; P4 interaction/clearance contracts |
| P6 | Authored Main Hall and progression displays | Then / medium–large | P1 station language; reusable P5 art/material work |
| P7 | Combined progression, economy, usability and performance pass | Release gate / medium | P1–P6 |

**First playable improvement: P0–P2.** Fix the confusing decisions and trivial
opening before a large art pass. Typed map indicators can then ship before
the larger shop-state change. Sketch one room and the hall composition early,
but expand the visual library only after their playable layouts work.

## P0 — Establish the progression baseline

- [x] Record a reproducible fresh Sexton profile: no purchased upgrades,
  no Legends, default starting deck/relic, entry Floor 1. Add separate profiles
  for several affordable early purchases, an unlocked Hexer and a later cycle.
  Compare profiles on the same seeds without merging their saves.
- [x] Add a local difficulty-report tool, initially reading existing combat
  events. Record starting/ending HP, gross damage taken, blocked damage,
  healing, turns, enemy actions, reward choices, room order, Coin spending,
  death/retreat depth and permanent upgrades. Net HP alone can conceal damage
  restored by healing. Keep diagnostic data separate from ghost-strength
  statistics and avoid changing the production formula to collect telemetry.
- [x] Use a fixed development seed set and a separate held-out set. Start
  with 30 seeds per profile for iteration and 100 for release comparisons,
  reporting sample counts and distributions. Keep seeds and the 4.7.2 engine
  fixed; optimize the reporting tool before reducing meaningful samples.
- [x] Compare the existing lookahead autopilot with simple attack-first and
  defense-aware policies.
- [ ] Add human playtests: autopilot success is not a substitute for a new
  player's understanding or decisions. See the pending P7 participant gate.
- [x] Capture the present first-run experience, current upgrade decisions,
  map discovery, shop leave/re-entry attempt and room/hall appearance.

Files: `tools/balance_sim.gd`, proposed `tools/difficulty_report.gd`,
`core/combat/autopilot.gd`, `core/run/run_autopilot.gd`, existing combat events,
`core/run/run_stats.gd`, `tools/hud_shot.gd`.

Acceptance: a difficulty change can be compared against the same starter
build, enemies and seeds, separately from stronger permanent progression.

## P1 — Explain builds and purchases at the point of use

- [x] Add a shared explanation source for stats and mechanics, used by the
  hero sheet, upgrade plaques, cards, Forge/rest and a searchable or grouped
  help glossary. Show explanations on keyboard focus as well as mouse hover;
  provide click-to-open details so essential information is not hover-only.
- [x] Describe stats accurately. Might adds to effects marked as scaling with
  Might. Wit adds to marked Block and status effects, not every Skill or every
  status. Vigor currently gives 3 maximum HP per point. Focus has thresholds:
  draw at 3/9 and Energy at 6/12. Show the current benefit and next threshold;
  read these values from content rather than duplicating constants in UI text.
- [x] Annotate affected card effects visibly: for example, `Brace: 5 Block
  + 2 from Wit = 7 before other modifiers`. Separate authored rules from
  current modifiers. For conditional or complex cards, show the full rules
  and explain the condition rather than promising an incorrect exact result.
- [x] Replace bare `Upgrade Strike`/`Sharpen Strike` choices with a card
  selection and comparison. Current content provides this example:

  > **Strike — Attack · 1 Energy**
  >
  > Base damage: **6 → 9**. Might scaling remains.
  >
  > Upgrade **one copy** in this hero's deck. Choose this instead of healing here.

  Show how many copies are upgraded/unupgraded, retain the selected UID, and
  use a distinct commit button after inspection. Also compare changes to cost,
  targets, keywords or statuses when those are what an upgrade changes.
- [x] Explain persistence: a sharpened card stays with the living hero across
  retreats and becomes part of that hero's ghost; it does not upgrade every
  Strike or every future hero. Permanent guild upgrades and tending a named
  ghost need equally explicit recipient/duration labels.
- [x] Keep prices, current currency and affordability reasons visible. Show
  locked requirements and capped upgrades with an explanation. In shops,
  display unaffordable inventory as disabled items instead of making it
  disappear because it is absent from `legal_actions`.
- [x] Add short, dismissible teaching moments for Energy/Block/intents, the
  first card upgrade, room signs and the first ghost. Explain Coin versus
  Soul and the death/Watch loop. Remember dismissed lessons separately from
  authoritative campaign unlocks; make them available again in Help.
- [x] Add a compact run recap showing reached depth, rewards banked, ghost
  contribution and one relevant affordable next upgrade. Keep buying voluntary.

Files: `game/hud/hero_screen.gd`, `card_inspector.gd`, `choice_screen.gd`,
`help_panel.gd`, `guild_screen.gd`, `seance_screen.gd`, `exit_screen.gd`,
`game/widgets/upgrade_plaque.gd`, `card_view.gd`, `core/content/card_text.gd`,
`card_def.gd`, EN/ES CSVs; proposed shared explanation/comparison helpers.

Acceptance: a new player can explain what Wit changes, identify Strike,
predict the selected upgrade's result and say who keeps it. Inspection,
cancel and help never spend, consume a rest choice or advance combat. Test
mixed duplicate card UIDs, cost-changing upgrades and the next Focus threshold.
Review keyboard use and compact Spanish at 150% UI scale; reduce preview
space before hiding the decision or forcing tiny text.

## P2 — Make the opening challenging and permanent growth visible

Tune the first biome before extending the new curve through every tier. The
likely contributors to investigate are early single-enemy groups, whether
they survive to act, their move schedules, starter damage/Block, the Sexton's
starting Block and the density of healing. These are hypotheses, not findings.

- [x] Establish the initial experience: Floor 1 teaches attacking and blocking;
  Floors 2–4 require target/defense decisions; Floors 5–9 add combinations and
  preparation pressure; Floor 10 tests a coherent build. Keep enemy intent
  understandable before increasing punishment.
- [x] Adjust early encounter composition and enemy actions first, then targeted
  HP/damage values and healing frequency. Avoid solving the entire problem
  with a global multiplier or making every fight last much longer. Use the
  existing enemies before creating new ones.
- [x] Make ignored threats matter: combinations such as an attacker plus a
  support enemy should reward target choice. Teach debuffs before stacking
  them. Optional elites later carry concentrated risk and better rewards.
- [x] Compare fresh and upgraded builds at equal depth and on equal seeds.
  Purchased power should reduce expected losses/turns and move the viable
  frontier outward. Retain reach, camp and Descent draft so players can move
  past mastered floors instead of repeating a compulsory opening grind.
- [x] Recheck early prices and earnings together with combat. Harder starts
  must still produce useful ghost income and a meaningful purchase within
  the existing 20-minute affordability bound. Preserve progression after
  failure and explain the benefit of returning stronger.
- [x] Make compatibility a gate for this first balance release. Preserve
  banked currency and saved combat HP, deck and RNG state. Record when revised
  rules begin affecting an active saved fight. Settle pending offline income
  once before changing cached production; retain fixed-strength founder and
  expedition promises. If non-fixed ghost strength is recalculated, do it once
  per content revision, sources before linked echoes. Test this with active
  expeditions and old saves before shipping P2, not only at P7.

Provisional tuning targets, to accept or revise explicitly after P0:

| Measure | Initial target / interpretation |
| --- | --- |
| Fresh-player first normal fight | Most coached novices survive; one mistake is recoverable. No prescribed damage or forced death. |
| Floors 2–4, fresh build | Normal wins usually take about 3–5 player turns; meaningful enemy actions occur before death. |
| Fresh full-health runs reaching Floor 4 | With ordinary decisions, a median 15–35% net HP loss by exit is a starting tuning band. Report healing, deaths and the share reaching that exit separately to avoid survivor bias. |
| Decision quality | Defense-aware play should lose less HP than blindly attacking over the seed batch. Skilled flawless fights remain valid. |
| First few meaningful purchases | At the same early depth, aim for roughly 20–35% less expected HP loss or a clear turn-count reduction, with a deeper viable frontier. Use purchase-specific expectations rather than requiring every upgrade to improve every metric. |
| Frontier ordinary fights | Preserve the existing approximate 3–6-turn goal; increasing depth should add pressure without routinely reaching the turn cap. |

Measured result: normal-win turns and the improvement from early purchases
are supported by the held-out report. Fresh safe-route lookahead reaches a
34.3% median Floor-4 loss, while the simple defensive policy reaches 44.3%,
above the provisional band. This deviation remains open for player review;
it is not an accepted change to the target. The synthetic later-cycle build
is underprepared and does not establish a viable Floor-31 frontier.

These are aggregate playtest targets, not per-fight rules or assertions that
punish excellent play. Do not tune only to the development seeds. Keep the
existing economy invariants and measure the actual manual-play experience.

Files: `data/biomes/catacombs.json`, `data/enemies/catacombs.json`,
`data/balance.json`, starter card/relic data if justified by measurements,
`core/combat/enemy_ai.gd`, `core/campaign_engine.gd`, ghost strength/cache and
save compatibility code where needed, difficulty report and balance tests.

Acceptance: the fresh opening demands decisions, several affordable purchases
make familiar floors noticeably easier, and the held-out report shows where
the next challenge moves. Record every changed balance value and its reason.

## P3 — Make the destination readable before commitment

- [x] Define one room presentation mapping from existing node kinds: label,
  icon, accent, risk/reward description and availability. Reuse the existing
  node-icon family; use the same mapping in map, compass, signs and prompts.
- [x] Add a visible `Map · M` exploration control and first-floor prompt. Extend
  the existing full-floor map with typed icons, a legend, current room/player,
  stairs, completion and marker selection. Reveal the floor layout and room
  types on entry so players can plan spending and risk; mark visited rooms
  separately. Keep event choices and shuffled rewards for their encounters.
  A minimap toggle is a later option if playtests still show frequent
  navigation interruptions.
- [x] Place readable signs before each trigger boundary and match their
  symbols to compass markers. A nearby prompt names the destination and its
  risk. Signs must be legible before automatic normal-combat entry occurs.
  Use explicit E engagement for elites, with a clear in-world commitment
  prompt, so reading an optional challenge cannot accidentally start it.
- [x] Represent completed encounters and reusable services separately. A
  cleared room gets a completion mark; an accessible shop remains on the map.
  Locked stairs explain remaining requirements rather than disappearing.

| Room | Identity and purpose | Intended final policy |
| --- | --- | --- |
| Normal combat | Crossed blades; enemy encounter, card reward, Coin/Soul | Required on the floor's main route; combat/reward happen once. |
| Elite | Distinct elite crest and `Elite`; stronger fight, extra Coin and a relic when available | Optional detour; explicit commitment, no respawn. Explain the actual reward rule, not an unconditional unique-relic promise. |
| `?` Event | Question mark and `Event`; a non-combat decision | Optional to enter; one outcome after choosing. `?` must not secretly mean an unannounced fight in this release. |
| Rest / Forge | Anvil/camp symbol; heal or sharpen one card | Optional service; one choice per room, not repeatable healing/upgrading. |
| Shop | Merchant/purse symbol; spend run Coin | Revisit while on this floor; finite stock and services. |
| Boss | Unique boss crest; biome milestone | Required on boss floors; once-only rewards. |
| Entry / stairs | Directional symbols and clear readiness | Safe navigation; stairs unlock from required encounters. |

P3 initially displays the current completion rules. P4 introduces the final
optional-room policy alongside the state changes needed to support it; do not
label an encounter optional while the old engine still requires it.

Files: `game/hud/floor_map.gd`, `compass.gd`, `prompts.gd`,
`game/world/crawl.gd`, `encounter_marker.gd`, `game/theme/icons.gd`,
`assets/icons/node/`; proposed shared room-presentation helper.

Acceptance: before committing, a player can distinguish a normal fight,
elite and event in the corridor and on the map. All views agree after a
purchase, encounter completion, reload and floor transition. Marking a map
destination remains read-only and consumes no gameplay RNG.

## P4 — Persistent shops and meaningful room choices

This milestone changes run state and saves. It must land before room presets
depend on new interaction anchors, and before final risk/reward tuning.

- [x] Introduce stable room identities on the current floor and explicit
  distinctions between visited, encounter resolved, required for exit and
  service available. Keep one authoritative record in `RunState`; geometry,
  map and panels observe it. Preserve current logical node identities.
- [x] Store shop inventory, remaining relic, prices and removal-used status
  per room. Generate stock once from a shop RNG derived from run, floor and
  room identity. Two shops must not share inventory or accidentally use an
  identical floor-only stream. Opening or closing never rerolls.
- [x] Build a small merchant area with a recognizable counter and E prompt.
  The player walks in, opens the shop, buys or inspects, closes it, leaves and
  can return. Closing while still in its trigger does not immediately reopen
  the panel. Counter interaction has one input owner.
- [x] Make close/leave return to exploration and retain stock. Allow re-entry
  both before and after stairs unlock, from the engine's applicable `node`
  and `exit` contexts. A subsequent visit cannot relock the stairs or emit
  duplicate completion rewards. Leaving the floor or ending the run closes
  that floor's shop permanently; no travel to previous floors is added.
- [x] Add complete item descriptions, prices, disabled affordability states,
  card/relic inspection and a deliberate card-removal selection. After any
  purchase, refresh currency and availability across every view once. A
  stale panel from another room/floor cannot apply an action.
- [x] Introduce explicit required encounters and optional detours in floor
  patterns. Use two required normal fights on a typical early floor plus
  one optional room; a required boss replaces a main-route fight on boss
  floors. Keep the first floor's teaching pattern controlled. Validate
  reward/room frequencies in P7; do not let a floor become only free services.
- [x] Make elites a voluntary risk/reward choice, with better Coin and the
  existing relic reward. Optional events/rest/shops do not prevent exit.
  Once a fight or event choice begins, preserve the current resolution rules.
  Layout generation must provide access to required rooms without forcing
  passage through an optional encounter's trigger volume.
- [x] Give early elites a recognizable tactical test using existing moves:
  coordinated enemies, a dangerous support target or a clearly signaled
  heavy attack. Preview the threat and reward category before engagement.
  Winning an elite should help prepare the next boss; a damaged or unfinished
  build should have a useful reason to take the safer route.
- [x] Rework the existing three Catacombs events around distinct decisions:
  recovery now versus a stat increase for this hero, HP for a build-changing
  card, and keeping an item versus taking Coin for a later shop. Use two or
  three readable choices with effect previews generated from their data,
  including capped healing, exact costs and who keeps the benefit. Provide
  a leave option when every other choice requires a sacrifice; identify a
  potentially lethal HP cost before commitment. No surprise combat.
- [x] Connect events to room planning: a visible upcoming shop makes a Coin
  outcome useful, while an elite makes healing or immediate deck strength
  attractive. Check that the same option does not dominate for healthy,
  damaged and different-stat builds. Persist the chosen outcome once and
  prevent reopening, repeated input or reload from granting it twice.
- [x] Update autopilot traversal explicitly: it must terminate, never loop
  through a reusable shop, and report which optional-room policy it uses.
  Keep human choice and simulation policies distinguishable in comparisons.

Save compatibility is part of this milestone. The baseline uses schema 3;
bump the current version when new room records are written, accounting for
any earlier P2 schema change, and add migrations/validation at the same time.
Copy an active old shop's remaining stock into its room record. A previously
closed schema-3 shop has already lost its inventory: mark it unavailable on
that existing floor rather than inventing fresh stock. New floors receive
the new visit policy. Preserve the old required-node policy for an active
legacy floor until it is left, so migration does not silently complete it.

Files: `core/run/run_state.gd`, `run_engine.gd`, `floor_generator.gd`,
`run_autopilot.gd`, `core/save/save_game.gd`, `save_validation.gd`,
`game/game.gd`, `game/world/crawl.gd`, `encounter_marker.gd`,
`game/hud/choice_screen.gd`, `data/events/catacombs.json`,
`core/content/event_def.gd` and event-effect validation; a dedicated shop
panel/interaction component if needed to keep the generic choice screen focused.

Acceptance: visit → leave → fight elsewhere → return → buy → save/load →
return again preserves stock, Coin and service limits. Repeated entry gives
no free relics, card removal, healing, rewards or rolls. Test multiple shops,
sold-out shops, insufficient Coin, optional choices after exit unlock, stale
callbacks and all migrated/current run phases. Stairs remain reachable.

## P5 — Room presets with purpose and environmental life

- [x] Add a data-driven room-preset catalogue with biome/role compatibility,
  supported dimensions, doorway anchors, clear walking lanes, combat staging
  area, ghost/service anchors, prop sockets and light/ambient budgets.
  Logical layout remains pure; scene/model references stay in presentation.
- [x] Start with six recognizable Catacombs compositions: burial aisle,
  collapsed vault, ossuary, ritual chamber, abandoned workroom and merchant
  alcove. Pair presets with compatible roles and sizes; keep a neutral fallback.
  Distinct silhouette, focal point and sightline should carry identity, not
  just a different crate position or wall color.
- [x] First reuse the existing connected room footprints. Architecture,
  alcoves, ceilings and props can vary around safe paths. Introduce new
  walkable shapes only after the logical grid/map and encounter volumes can
  represent them accurately. Keep the active renderer and movement rules.
- [x] Use weighted selection with repeat limits on a floor and variation
  across consecutive floors. Persist/version the active floor's chosen layout
  and presets, or retain its generator version, so loading after an update
  cannot move the room behind a saved logical encounter. Room dressing uses
  isolated RNG; it cannot change fights, offers or ghost production.
- [x] Add restrained activity: candle flicker, dust, dripping water, moving
  cloth, distant machinery, fungal pulses and sparse ghost routines. Use
  spatial ambient audio to establish place without masking interaction cues.
  Reduced motion and volume settings apply; distant effects stop updating.
- [x] Extend the approved preset format to Fungal Deep and Kiln with at least
  four recognizable compositions each before calling all-biome variety done.
  Keep elite/boss arenas large enough for their existing production models.
- [x] Check the actual walkable space after solid props, not only the original
  floor grid. Door-to-door lanes, shop counters, event anchors and the combat
  camera must remain usable. Fallback placement should be predictable.

Files: `core/run/layout_generator.gd`, `floor_layout.gd`,
`game/world/dungeon_builder.gd`, `dressing.gd`, `kit.gd`, `torches.gd`,
`game/theme/grade.gd`, capture tools; proposed `data/room_presets/`
and room-presentation builders. Update content validation for authored recipes.

Acceptance: a 100-seed sweep finds no unreachable required rooms, accidental
optional triggers, blocked service access or staging collisions. A short
native run shows clearly different room compositions. Presets remain stable
on reload and do not change the combat RNG/results for the same logical run.
Review every biome with its short enemies, tall bosses and UI overlays.

## P6 — A Main Hall that looks like the player's guild

- [x] Author the composition around the well: a clear arrival view, readable
  central landmark, contrasting warm station areas and a cold spectral shaft.
  Improve pillars, arches, floor borders, ceiling detail and depth around the
  hub without obscuring the five destinations.
- [x] Give each station a purposeful area: tools and embers for upgrades,
  books and class belongings for the hero desk, ritual objects for séance,
  named memorials for Legends, and a protected overlook for the well.
- [x] Add history through existing achievements: biome trophies, claimed
  banners, memorial inscriptions and expedition keepsakes. An early guild
  should already look cared for; later decorations make its history visible.
  Explain what earned a display. Keep permanent achievements distinct from
  ghost displays that legitimately change after prestige.
- [x] Use restrained ambient movement and sound, consistent materials and
  authored light placement. Reuse suitable existing assets, record attribution
  for additions and avoid multiplying shadow-casting lights for decoration.
- [x] Preserve a fast route from spawn to every station and the well. Keep
  signs consistent with P1/P3 language and keep G navigation available.

Files: `game/world/guild_room.gd`, `well_view.gd`, `ghost_figure.gd`,
`game/theme/grade.gd`, `game/hud/hall_screen.gd`, props/materials,
`ART_BRIEF.md`, `ATTRIBUTION.md`.

Acceptance: the arrival view has a clear focal point, all stations are
recognizable without opening menus, and fresh/progressed/post-prestige guild
captures show appropriate history. No decorations obstruct walking,
interaction, the well or readable panels.

## P7 — Validate the connected experience

Rebalance after optional elites, repeat shops and clearer upgrade decisions
ship: all three change how much power a player acquires before the frontier.
The P2 values are an initial improvement, not a reason to skip this pass.

- [x] Repeat fresh and progressed profiles on held-out seeds. Report HP loss,
  healing, deaths, turns, optional-room choices, upgrade cadence and depth.
  Measure both safe and elite-heavy routes; skipping elites should be viable,
  while beating them should earn a worthwhile advantage.
- [x] Check that repeat shops permit useful planning without enabling free
  rerolls or turning early floors into purchase-driven triviality. Adjust
  stock/prices/encounter rewards together when the evidence calls for it.
- [x] Re-run the existing economy invariants at their meaningful sample counts.
  Repeat P2's compatibility checks: changed combat affects ghost simulations,
  projections, expeditions, tending and cached strength. Verify content
  revision handling, linked echoes and once-only offline accrual under the
  final balance, including a campaign that passed through the earlier release.
- [ ] Ask at least five new players to explain Wit, choose and describe a
  Strike upgrade, find an elite/event on the map, return to a shop and identify
  their next permanent improvement. Aim for four of five completing each
  without spoken assistance; record misunderstandings as revision work.
- [x] Test save/load at active fight, event, rest and shop boundaries; revisit
  after stairs unlock; death/Watch/retreat; prestige and floors 10/11, 20/21,
  30/31 and beyond 60. Confirm no reward, shop or offline duplication.
- [x] Run core/game suites, content validation, fight/run/campaign demos and
  `balance_sim`. Use isolated data, pinned Godot and fixed clocks/seeds. Record
  test assertions and process exit status separately.
- [x] Review native UI at 960×540 through 2560×1080, 100–150% scale, EN/ES,
  mouse/keyboard and reduced motion. Test expanded explanations, crowded
  inventories and large progression values without clipped primary actions.
- [x] Benchmark dense rooms and the decorated guild at 1080p on the recorded
  development hardware. Current p95 frame times already exceed 16.67 ms in
  some scenes: budget new props/lights/effects and optimize measured costs.
  If needed, add an effects/shadow-density preset with identical gameplay.
  Make no lower-spec or locked-60-FPS claim without measurements.

Release evidence: one before/after difficulty report, a fresh-versus-upgraded
comparison, a shop revisit/save reproduction, native room/hall captures,
usability observations, migration results and updated performance limits.
Commit new `.gd.uid` sidecars, preserve CSV `keep` imports and exclude generated
translations, local telemetry and capture caches.

## 4. Completion and scope boundaries

- [ ] A new player can understand the effects, costs and persistence of a
  decision before taking it.
- [x] Fresh early floors demand attention; earned upgrades visibly improve
  performance at the same depth without hidden difficulty compensation.
- [x] The map, signs and compass agree on room type, risk and availability.
- [x] Shops behave as persistent places; optional rooms and required encounters
  cannot be confused or exploited.
- [x] Rooms have recognizable variety and life; the Main Hall reflects the
  guild's purpose and earned history.
- [ ] The complete manual/idle loop, saves and performance retain evidence
  after all systems are combined. Automated loop/save/performance evidence is
  recorded; the new-player manual session gate remains open.

Useful later additions: a minimap preference, more event/preset content,
merchant personalities, a richer encounter journal and explicit optional
challenge modes. Defer new classes/biomes, a full NPC/pathfinding simulation,
loot containers everywhere, a separate housing economy, tactical positioning,
controller rebinding and a renderer replacement. They would widen this release
before its central decisions and progression are working well.
