# Ghost Guild: exploration, memory and voluntary challenges

Created: 2026-09-11. Status: implementation in progress.
Baseline: `de7526f` on hybrid `main`, Godot 4.7.2.

This continues the five useful later additions in the completed
[player clarity plan](2026-09-08-player-clarity-progression-and-world.md).
P0–P7 remain complete. New-player feedback is optional; automated checks
and native UI review provide the evidence for this follow-up. Each part below
is implemented, checked, committed and pushed before the next part begins.

## Design and scope

- Navigation aids are preferences stored beside the campaign. The full map,
  compass, signs and minimap share room identities and availability.
- New content uses the existing three biomes, event effects and safe room
  footprints. Saved active layouts and shop stock remain authoritative.
- Merchants have names and contextual dialogue, with identical prices and
  stock rules. Their presentation cannot consume combat or reward RNG.
- The encounter journal records actual decisions and outcomes, with bounded
  storage. It is separate from ghost-strength measurements and the Ink
  Chronicle. Reading it never advances a run or accrues rewards.
- Challenge rules are explicit, voluntary and fixed for a descent. Standard
  remains the default. Existing Depth Seals keep their current economy.
  The new vows offer a recorded accomplishment, without currency bonuses or
  changes to enemy scaling, simulations or production formulas.
- New classes/biomes, NPC pathfinding, ubiquitous loot containers, housing,
  tactical positioning, rebinding and renderer changes remain outside scope.

## D1 — Optional live minimap

- [ ] Add a saved Options preference, off by default, and a compact live
  dungeon schematic that does not capture input or pause exploration.
- [ ] Reuse the full map's geometry, room icons, completion/service state,
  stairs, player heading and selected destination. Hide it in the guild,
  combat and modal panels; keep it within the scaled HUD at compact sizes.
- [ ] Verify preference persistence, visibility, heading/marker updates and
  read-only behavior. Review compact EN/ES Options and exploration.

Files: `game/settings.gd`, `game/hud/options_menu.gd`, `floor_map.gd`, a shared
schematic control, `game/world/crawl.gd`, EN/ES strings and focused game tests.

## D2 — Three new events and three room compositions

- [ ] Author one event per biome, each with two meaningful alternatives and
  a free leave option. Reuse previewable existing effects; show exact costs
  and benefit duration. No surprise combat or repeatable rewards.
- [ ] Add one recognizable composition per biome using existing procedural
  props/materials, wall sockets, staging clearance and zero extra lights.
  Preserve frozen recipes on active floors and isolated presentation RNG.
- [ ] Validate content and translations, event affordability/once-only
  outcomes, preset selection and a 100-seed physical-clearance sweep.

Files: `data/events/`, `data/room_presets/`, `core/run/room_presets.gd`,
`game/world/room_composition.gd` (or its existing equivalent), strings/tests.

## D3 — Merchants with a remembered identity

- [ ] Give each biome an authored merchant name and voice. Show arrival,
  returning and depleted-stock dialogue in the shop panel, retaining the
  shared Shop label and inventory/price explanations.
- [ ] Derive identity from the saved room's biome; derive dialogue from its
  persisted visit/stock state. No additional rolls, discounts or offers.
- [ ] Verify leave/re-entry, save/load, multiple rooms, sold-out stock,
  unaffordable inventory, EN/ES and unchanged shop actions/RNG.

Files: a merchant presentation helper, `game/hud/choice_screen.gd`, strings,
shop/UI regression tests. Existing room records remain the source of truth.

## D4 — A bounded encounter journal

- [ ] Persist the latest 120 meaningful entries per campaign: fight results,
  event choices, rest decisions, shop purchases and run endings. Record floor,
  hero, relevant IDs and numerical outcomes; resolve language at display time.
- [ ] Expose a journal panel through a visible control and `J`, with newest
  entries first, a run/fight/decision filter, an empty state and readable
  summaries. Keep it available in the guild and during dungeon inspection.
- [ ] Add schema migration/defaults and strict bounded record validation.
  Record at authoritative transitions so reload/stale callbacks cannot add
  duplicates; retain partial active-run history across saves and prestige.
- [ ] Verify recording, cap eviction, migration/round trips, invalid saves,
  locale switching, filters and read-only panel behavior.

Files: journal model, `core/campaign.gd`, `core/campaign_engine.gd`,
`core/run/run_engine.gd`, save code, `game/game.gd`, journal panel,
`game/world/crawl.gd`, `project.godot`, strings and core/game tests.

## D5 — Explicit challenge vows and connected validation

- [ ] Add a pre-descent selector with Standard, No Sanctuary (rest healing
  disabled; sharpening and other healing remain) and Closed Purse (shop
  purchases/removal disabled; event trades remain). Explain that rewards
  are unchanged, and lock the selection for the active descent.
- [ ] Persist the selected/active vow with legacy Standard defaults. Enforce
  restrictions in the engine, keep leave/skip routes usable, and show the
  active rule in run context and journal endings. Keep Seals independent.
- [ ] Verify rejected direct/stale actions, save/reload, changing vows between
  runs, autopilot termination and standard-run compatibility.
- [ ] Run complete core/game suites, content validation and fight/run/campaign
  demos. Run economy invariants at existing sample counts and a held-out
  difficulty comparison for the expanded event pool. Review new UI at
  960×540/150% Spanish and a normal English viewport with reduced motion.
- [ ] Update controls, deferred items and the evidence below. Commit UID
  sidecars, preserve CSV `keep` imports, and exclude generated translations,
  test reports and capture caches.

Files: challenge rules/selector, campaign/run/save code, choice/run UI,
strings, demos/reports and relevant tests.

## Implementation evidence

This section is updated with each delivered part. Record test assertions and
process exit status separately; do not imply novice testing or lower-spec
performance certification from automated/native development checks.
