# Hybrid integration evidence

Implementation and review: 2026-09-06 through 2026-09-08. Engine pinned to
`4.7.2.stable.official.ed1daf0bf`, Linux x86_64. This record accompanies
[the integration plan](2026-09-06-hybrid-2d-3d-integration.md) and
[launch, controls and save instructions](../../controls-and-saves.md).

The implementation checkout is `/home/usuario/Escritorio/ghost-guild-hybrid`.
Raw logs, result JSON and native PNGs from September 7–8 are retained locally
under its ignored `reports/hybrid-final/`. They are review artifacts, not game
assets. Earlier `/tmp` artifacts were cleared by a machine restart; their
original baseline results below are distinguished from the retained rerun.

## M0: preserved editions and baseline

- `2d-legacy` and `archive/2d-2026-09-06` preserve `5200eda1607c8a76e4ddd475d983c1c7d211123c`.
  `archive/3d-2026-09-06` preserves `1e8f8bfb29cdb81970ed554d16733d0695d437df`.
  Names were unused before creation. `hybrid-integration` started at that
  verified 3D head. The original checkout and its untracked user plan were
  left intact during implementation.
- Linux launch profiles isolate the legacy and hybrid user directories.
  Linux/Windows test wrappers allocate disposable directories and import
  before GdUnit. Native tools use synthetic campaigns and separate review data.
  No personal campaign was used as a fixture or migration target.
- Original baseline import succeeded. Core/game: **1,269 cases, 0 errors,
  2 failures, 0 skipped, 0 orphans**. Both failures were missing Spanish
  `ui.menu.kicker` / `ui.menu.premise` rows, now supplied. Runner status 100
  was followed by process abort 134 during disposal.
- Original baseline native guild/title, hero, ladder, séance, Hall, fight,
  reward, exit and Watch images were written. Exit/Watch then aborted during
  shutdown. The September 7 detached-baseline rerun retains guild, hero,
  upgrades and exit PNGs: import and the first three captures exited 0;
  `baseline-exit.log` records PNG success followed by SIGABRT (subprocess -6).
  This reproduces the historical problem on unchanged `1e8f8bf`.
- `deferred-items.md` was audited against current code; obsolete missing
  content, animation, balance, accrual and worker-preview entries were closed.

## M1–M4: delivered interface and world links

`Crawl` owns the panel return stack, movement, pointer and visibility policy.
Stations, G and five visible tabs reuse persistent management panels. Required
choices remain underneath help/pause; staging and killing animations suspend
and resume once. Hidden fight controls reject actions. Idle economy timing
continues through `GameRoot` while presentation is paused.

The shared scroll host and preferred-width column reflow at compact sizes.
UI scale and language apply to the live caller and persist outside campaign
data. Hand cards retain stable instances; an explicit focus route reaches
enemy tags and End Turn. Model/tag/keyboard targeting calls the same validated
action. Full card/pile inspection copies current data, sorts composition,
explains statuses and never reveals shuffle order or consumes RNG.

Sexton and Hexer have distinct procedural models. Hero and ghost previews use
their own World3D, one unshadowed key light and a disabled render target when
hidden. Ghost identity, production and selected-floor data come from the
campaign. Numeric Soul ticks leave the world figures and long lists intact.
The ledger supports deep cycling floors; ghosts beyond the well's 60-floor
render limit are identified explicitly rather than drawn at a false depth.

The map reads the generated floor and resolved-node flags. Its marker only
updates the compass. World cell centres and map clicks share the same
conversion. E opens the same ghost details by id with a ray that checks
distance and intervening walls. Dungeon inspection cannot spend or mutate guild state.

## M5: campaign preservation

Eleven synthetic version-1 fixtures were serialized with the archived 2D
implementation (seed 73019, timestamp 1000): guild, descent, node, fight,
reward, event, shop, rest, exit, ended and completed. See the fixture README
for provenance and the reproduction script. They migrate idempotently and
reconstruct a valid world position and interface from the logical phase.

Schema 3 adds exact combat piles, enemies, turn values and decimal-string RNG
stream snapshots. Version-1/2 serializers had already reduced an active fight
to an unresolved node; that historical restart behavior is preserved. A
current fight round-trip also compares the next turn's events and RNG state.

Import validates nested shapes and content references before typed loading,
copies into a new slot and preserves both source and current campaign. Future
schemas are rejected. Missing/corrupt primaries recover through both backup
levels and report recovery. Writes validate a flushed temporary file before
atomic replacement; only valid backups are rotated. Failed-write tests retain
the old primary/backups. Fixed-clock import/load/save tests prove offline
accrual is banked once. Invalid existing saves block automatic overwrites.

## M6: native art and performance review

Guild props distinguish the anvil table, ledger desk, séance circle, Hall
monument and well. Existing walking/collision tests remain applicable. Death
keeps the fallen hero's identity through the figure, epitaph, ledger and
production; camera retreat is bounded by the room. Reduced motion suppresses
bob, shake, forced camera travel and ornamental UI/preview motion while
showing the combat and death results.

All 30 production enemy rigs were reviewed in six neutral galleries and
twelve actual-biome group captures (`catacombs`, `fungal_deep`, `the_kiln`,
entries 1/11/21). Existing spiders, segmented grubs, equipment and floor
contact were retained. Review found low creatures behind the hand and tall
intent tags near the edge: the camera now lowers its eye line for short
groups, fading that adjustment out for tall bosses, and tags stay bounded.
`fungal-framing`, `short-catacombs-final` and `kiln-boss-corrected` check those
extremes. Both heroes and true/echo/prepared/restless ghosts were reviewed.

Native UI review covers 960×540, 1280×720, 1920×1080 and **2560×1080**, plus
2560×1440, at 100%, 125% and 150%, in English and Spanish. Files include
`*-960-1.5-es`, `hero-1280-1-en`, `hexer-1280-1-en`, `hover-1280-1-en`,
`map-1280-1-en`, `help-1280-1-es`, `options-1280-1.5-es`,
`wide-selected-42`, `ghost-detail-final` and `offline-scroll-final`.
Dense panels scroll to primary actions; the compact offline acknowledgement
is fully reachable. Opening ghost details now focuses its heading so the
identity and model stay visible. Keyboard scroll following waits for container
layout and measures in local UI coordinates, keeping focused actions visible
under independent HUD scaling. Body text at 1280×720 is 16 effective pixels
or greater; enlarged card rules are 18, with full inspection available.
Baseline and hybrid hero/guild/upgrades/exit captures were compared directly.

September 7 benchmark, native 1920×1080, Forward+, Vulkan 1.4.329, Intel
Core i7-14700HX / NVIDIA RTX 4070 Laptop GPU, VSync disabled, three-second
warmup and 180 measured frames per scene (`benchmark-stable-1080.log`):

| Scene | Frame median / p95 (ms) | Render CPU / GPU mean (ms) | Draw calls | Video memory (MiB) | Lights / active previews |
| --- | --- | --- | --- | --- | --- |
| Guild | 9.239 / 16.489 | 0.964 / 2.252 | 135 | 267.2 | 10 / 0 |
| Hero preview | 8.194 / 16.249 | 0.912 / 2.194 | 230 | 282.7 | 11 / 1 |
| Floor-31, three-enemy fight | 8.144 / 17.551 | 2.306 / 3.458 | 528 | 390.0 | 26 / 0 |

The preview viewport alone averaged 0.225 ms CPU / 0.046 ms GPU. Fifty
open/close cycles retained exactly 613 nodes, 14 lights and three viewports,
with zero active hidden previews and zero orphans; object count decreased
from 3,987 to 3,845. These counts include persistent hidden panel instances.
The log's periodic `Performance.TIME_PROCESS` monitor is not a per-frame CPU
measurement; the table uses RenderingServer submission/GPU timing and wall
frame intervals instead. Simulation sample counts were unchanged.

These measurements show GPU headroom, so a lower-cost preset was not justified
for this machine. They do **not** establish stable 60 FPS in every scene:
the deep-fight p95 exceeds 16.67 ms. Lower-spec hardware remains unmeasured.
The final merge-tree benchmark is recorded in the delivery section below.

## M7: complete-loop coverage

The following are deterministic automated integration/core scenarios, paired
with native presentation review; screenshots alone are not gameplay evidence.

| Plan scenario | Evidence |
| --- | --- |
| Fresh guild, stations, quick tabs, draft and descent | `crawl_guild_test`, `crawl_walkthrough_test`, `hybrid_context_test` (same panels, velocity freeze, gates) |
| Floor/ghost inspection and deep identity | Hybrid preview-lifetime and floors 1/30/31/61/75 tests; map serialization comparisons; selected floor-42 native capture |
| Multi-enemy card, help/pause, targeting and End Turn | Hybrid staging/selection/keyboard/hidden-action regressions, existing fight/hand/tag suites |
| Killing action during pause | Hybrid animation-cursor suspension and exactly-once reward/fight-count checks |
| Reward, event, shop, rest, stairs | Crawl walkthrough/loop, choice/exit suites and all legacy phase fixtures |
| Retreat, death, prepared Watch | `crawl_loop_test`, `run_exit_test`, hybrid death/pause/ghost identity checks; native exit/death/Watch captures |
| Expedition arrives during management | Fixed-clock hybrid floor-7 selection/preview/well test; accrued Soul and returned ghost checked once |
| Tend, echoes, hauntings, Legends, Chronicle, prestige | Core economy/ghosts/legends suites; game séance/Hall/expedition tests; GameRoot mutation gates |
| 10/11, 20/21, 30/31 and beyond 60 | `deep_floors_test`, content `tiers_test`, hybrid deep-ledger checks, biome roster/map captures |
| New, migrated and existing campaign save/load | Core campaign/save/run-save suites; all fixture phases load to Crawl; current fight resumes without an extra turn |
| Resize, UI scale, language, keyboard | Hybrid persisted-caller and compact Spanish panel bounds/scroll tests; native size matrix |
| Repeated overlays, fights, travel, previews | Crawl loop/context suites with zero orphans; 50-cycle native counts above |

The September 7 full run passed **1,294 tests in 121 suites**, zero errors,
failures, skipped tests or orphans, process exit 0 (`full-suite.log`). Subsequent
context/offline regressions passed 34 tests, exit 0 (`final-context.log`).
The final merged-tree run below supersedes these interim results.

Required headless tools exited 0: `fight_demo.gd -- bone_rat hollow_knight`,
`run_demo.gd -- 1 42`, `campaign_demo.gd -- 42 3`, and
`balance_sim.gd -- 14 48`. All three balance invariants passed. The first
attempt gave demo arguments in the wrong format and was rejected with exit 1;
the retained `*-corrected.log` files are the valid runs. One final roster
capture also used an unknown enemy id; `kiln-boss-corrected` is its valid
replacement, and the tool now rejects unknown roster ids before staging.

## Legacy-only change audit and integration

`5200eda` is the sole legacy-only commit. Its 17 changed paths were reviewed
individually against the integration base; no whole-commit cherry-pick or
branch reset is used.

| Legacy path(s) | Delivered treatment |
| --- | --- |
| `data/strings/en.csv` | Replace the seven fixed-Catacombs/crypt headings with current localized navigation, identity and cycling-floor text. Retain all newer content keys. |
| `game/art/crypt_models.gd`, `.uid`, `crypt_view.gd`, `.uid` | Preserve on legacy refs; adapt the preview concept through production `HeroFigure`, `GhostFigure` and isolated `ModelPreview`. |
| `game/main.gd` | Preserve legacy shell only in its edition; hybrid coordination is `Crawl`. |
| `game/run/fight_screen.gd` | Preserve legacy scene only in its edition; use current `FightDirector`, hand and target tags. |
| `game/screens/hero_screen.gd` | Adapt model/stats/deck arrangement into current `game/hud/hero_screen.gd`, keeping the Hexer and unlock rules. |
| `game/screens/ladder_screen.gd` | Adapt selected-floor residents/output into current HUD with deep cycling floors and independent inspection/descent selection. |
| `game/theme/ui_theme.gd` | Retain newer 3D Inter/Cinzel theme and its existing focus/tooltip styles. |
| `game/widgets/card_view.gd` | Retain newer readable rules/hand sizing; add keyboard focus and copied-data inspection. |
| `game/widgets/enemy_view.gd` | Retire legacy panel with its shell; production body/tag selection provides the same action route. |
| `game/widgets/nav_bar.gd` | Replace with five-tab `GuildNav`, including Hall and a visible Return action. |
| `game/widgets/tower_view.gd` | Keep current deep-floor rendering, add selected-floor highlight and keyboard-accessible floor picker. |
| `game/widgets/wallet_bar.gd` | Keep current compact Soul/rate/reach layout, shared above management panels and updated on numeric signals. |
| `project.godot` | Retain Forward+, `crawl.tscn`, current 3D layers/input; native world rendering and separate responsive HUD scaling. |
| `tools/screenshot.gd` | Preserve the legacy capture tool on legacy refs and remove its obsolete hybrid copy/UID: it referenced the deleted shell and deleted the default save. Use isolated production HUD/creature tools for the hybrid. |

New GDScripts have UID sidecars; loader-read CSV imports remain `keep`.
Generated translations, reports and engine/cache files are excluded.

### Final delivery checks

Promotion and final merge-tree results are pending. Both preserved archive
commits remain unchanged; no remote push is part of this local implementation.
