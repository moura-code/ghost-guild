# Ghost Guild: integrate the 2D interface and 3D world

Date: 2026-09-06. Status: implementation plan; new work below is pending.

Build one game with first-person exploration, visible enemies and ghosts, and a clear 2D interface for cards and management. Preserve the playable 2D edition as a reference. Use the newer combat, economy, content and progression on `3d-pivot` as the foundation.

This document records completed work separately from proposed changes. Preparing this plan does not merge branches, change saves, or implement the features below.

## 1. Baseline and completed improvements

The comparison uses these committed versions. Paths in the implementation sections refer to `3d-pivot` unless explicitly marked as legacy or new.

| Baseline | Commit | Role |
| --- | --- | --- |
| `main` | `5200eda1607c8a76e4ddd475d983c1c7d211123c` | Playable 2D edition, including its recent interface and model-preview improvements. |
| `3d-pivot` | `1e8f8bfb29cdb81970ed554d16733d0695d437df` | First-person game and the implementation base for this plan. |

### Already integrated on the 3D branch

- [x] Card combat, runs, ghost production, upgrades, onboarding and campaign saves carried forward through `core/`, `data/` and `GameRoot`.
- [x] A generated walkable dungeon, first-person movement, encounter rooms, a walkable guild and a well containing ghost figures.
- [x] 2D cards, vitals and enemy information over the 3D combat scene.
- [x] Existing choice, exit, epitaph, hero, ladder, guild, séance and offline-summary interfaces hosted over the world. The Hall adds the newer progression interface.
- [x] Additional progression on the 3D branch: the Hexer, Fungal Deep and Kiln, expeditions, priority rules, deeper floor cycles, Legends, hauntings, tending and the Chronicle. Preserve their current rules and unlocks.
- [x] A version-1-to-version-2 save migration that fills a run's resolved-node flags. This is a starting point for migration testing, not proof that every legacy campaign state imports correctly.

### Recent UI and art work to retain

| Completed work | Where it exists | Integration treatment |
| --- | --- | --- |
| Live crypt and hero previews; a selected-floor view with residents and production | `main`, `5200eda`; `game/art/crypt_view.gd`, `crypt_models.gd`, legacy hero and ladder screens | Adapt the interaction and layout ideas to the current 3D assets and deeper progression. |
| Larger 2D navigation, clearer wallet and hero presentation, improved card focus/hover | `main`, `5200eda` | Reuse useful layout and navigation behavior through the current theme. |
| Sharper Inter/Cinzel text, larger card rules, compact vitals, clearer enemy health and intent, improved title and hero screens | `3d-pivot`, `1e8f8bf` | Retain and extend for responsive panels. |
| Stable hand hover, card stacking and large-hand layout | `3d-pivot`, `1e8f8bf` | Preserve when adding keyboard focus and inspection. |
| Articulated creature anatomy, eight-legged spiders, segmented grubs, armor, weapons and biome details across the 30-enemy roster | `3d-pivot`, `1e8f8bf` | Use the production rigs for combat and future previews. |
| Shrouded ghosts with hollow hoods, eyes, sleeves, state colors, independent rising/bobbing and complete fades | `3d-pivot`, `1e8f8bf` | Share the same ghost identity and appearance across the world and management views. |
| Better combat camera framing, creature hitboxes and equipment death fades | `3d-pivot`, `1e8f8bf` | Retain; verify with additional overlay and targeting cases. |
| Creature-gallery and deterministic HUD capture tools; updated art and attribution records | `3d-pivot`, `1e8f8bf` | Extend for the hybrid review captures. |

Recorded validation for `1e8f8bf`: 716 test cases in the game suite passed, and native renders of the roster and main screens were reviewed. A Godot crash during headless shutdown was also reproduced on the earlier, unchanged `c0d0cf3`. Record assertion results and process exit status separately. These are previous results; no runtime tests were rerun to prepare this document.

## 2. Player experience and scope

| Activity | Intended experience |
| --- | --- |
| Explore | Walk through the 3D dungeon with the existing movement, compass and room interactions. |
| Fight | See the creatures in the room while reading and playing 2D cards. Selection, targeting, status and turn ownership stay clear. |
| Manage the guild | Walk to a station or open the same management interface through quick navigation while in the guild. |
| Inspect a hero or ghost | Read the 2D details beside a preview built from the current model system. The preview represents the selected record. |
| Plan a descent | Use the tower, floor details and existing reach rules from a guild panel. |
| Navigate a floor | Open a 2D schematic of the current 3D layout with the player's position, encounter states and stairs. |
| Return after a run | Preserve the death/Watch sequence, ghost creation, rewards and offline production; show the resulting campaign state consistently in every view. |

One campaign drives all of these views. Keep the current card rules, encounter requirements, production formulas, class unlocks and prestige rules. Presentation movement in combat continues to have no effect on damage, range or enemy turns.

This plan changes the earlier pivot decision that guild navigation must always require walking: quick access will be available inside the guild. The walkable guild remains part of the experience. Update the pivot design's navigation and reversibility sections when implementing that change.

A complete switchable 2D dungeon mode, tactical positioning rules, new classes/biomes, multiplayer and a renderer replacement are outside this integration. Full controller support and key rebinding are follow-up features; this delivery must support mouse use and ordinary keyboard focus throughout its panels.

## 3. What to reuse, adapt and replace

| Area | Source and action |
| --- | --- |
| Game rules and content | Keep `3d-pivot/core/` and `data/`. Route new actions through `GameRoot`; preserve the newer content and bug fixes. |
| World and combat presentation | Keep `Crawl`, `DungeonBuilder`, `GuildRoom`, `FightDirector`, `EnemyBody`, `CreatureRig`, `CreatureDetails` and `GhostFigure`. |
| Existing panels | Extend `game/hud/` and shared widgets. Keep one instance of each management screen with its scroll/selection state. |
| Quick navigation | Adapt the legacy `NavBar` concept into a new guild navigation widget. Use the current theme and include the Hall. |
| Hero/floor previews | Adapt the legacy `CryptView` concept into one reusable preview component backed by current production models. |
| Floor map | Build from current `FloorLayout` and resolved-node data. The old `FloorMapScreen` assumed a different navigation model and cannot be restored unchanged. |
| Decorative UI | Retain compatible icons, fonts and panel furniture. Remove redundant decorative backdrops only after replacement screens are reviewed. |
| Legacy scene shell | Preserve `main.gd`, `MainScreen`, `RunRouter`, the old fight screen and old world shaders in the legacy edition. The hybrid boots `game/crawl.tscn`. |

Review the `5200eda` changes individually. A whole-commit cherry-pick would also bring older screen assumptions and `project.godot` settings into a substantially different application.

## 4. Shared interface and input contract

`Crawl` remains the scene coordinator. Introduce a small UI-context helper if needed to represent the active panel and its return context. `HudRoot` lays out and displays the interface; `GameRoot` owns access to campaign actions. Panels and 3D interactions call the same methods. A second campaign, economy loop or combat controller is unnecessary.

The current code has several ownership points to reconcile: `Crawl.open/close_panel`, `HudRoot.show_panel`, `Player._unhandled_input`, and `FightDirector` cursor/movement changes. In particular, restoring every closed panel to free exploration is insufficient when returning to a fight or an unresolved choice. These are code-review findings to cover with reproductions and regression tests.

### Default controls for the integrated game

| Input | Context and behavior |
| --- | --- |
| WASD / Shift / mouse | Existing exploration movement, sprint and look. Management and inspection overlays block movement and look. |
| E | Use the focused guild station; inspect a focused ghost during dungeon exploration. Resolve one target per input event. |
| G | Open/close guild management while in the guild; remember the last management tab. |
| I | Open the hero/deck inspection view from unobstructed guild or dungeon exploration. Dungeon inspection is read-only. |
| M | Open/close the floor map during unobstructed dungeon exploration. |
| F1 | Open controls/help as an overlay and return to the previous context when closed. |
| Left click | Existing card play and UI activation; targeted cards can select an enemy through its model or its information tag. |
| Tab / Shift+Tab / Enter | Move visible UI focus and activate the focused control; provide a usable focus route to cards, targets and End Turn. |
| Escape | Cancel an active card-target selection first; otherwise close an optional detail/panel, or open pause. A mandatory run choice opens pause without dismissing that choice. Options/help return to their actual caller. |

Display these bindings in the game using InputMap-derived labels. Quick navigation has visible buttons inside the management interface, so tabs are also usable with the mouse.

### State rules

- Guild shortcuts and world stations open the same management screen with the same unlock restrictions. Guild mutations remain unavailable during a run.
- Combat resumes with its hand, free card cursor, selection and existing movement policy restored. Exploration resumes with captured look. Closing an overlay never advances a turn.
- Pause preserves the active choice or fight. Suspend combat interaction and presentation playback while paused, and resume the pending sequence exactly once. Preserve elapsed-time accounting for the idle economy.
- A click, Enter press or Escape event has one owner. Hidden UI, the player and the fight director cannot also consume it.
- Encounter staging and other delayed callbacks must recheck the current context before releasing movement or changing the pointer.
- Required choices, death and floor transitions cannot be bypassed with shortcuts. If the run changes while an overlay is open, invalidate stale targets and return to the valid current phase.

## 5. Milestones and acceptance checks

Each milestone ends in a runnable build and a short record of changed behavior, checks and captures. Add regression tests for state transitions and data integrity; use native visual review for purely visual adjustments.

### M0 — Preserve the editions and establish the baseline

- [ ] Preserve the playable 2D snapshot at `5200eda` as `2d-legacy` and an archive tag, checking that the intended names are unused. Preserve the 3D baseline commit as well.
- [ ] Start `hybrid-integration` from the verified current `3d-pivot` head. Bring this plan into that branch. Keep the user's active 2D checkout usable; use an isolated worktree while it is being played.
- [ ] Give legacy play, hybrid development and automated tests separate user-data directories. Tests and screenshot tools use disposable saves; campaign migration operates on copies.
- [ ] Record import/startup, core and game-suite results, and native captures of guild, hero, ladder, séance, Hall, combat, choices, exit and death. Recheck the known shutdown issue separately if it recurs.
- [ ] Audit the current deferred-items document against newer code before treating an old entry as an open defect. Several entries describe superseded milestones.

Primary files/tools: Git refs, `project.godot`, `tools/test.cmd`, `tools/hud_shot.gd`, `tools/creature_shot.gd` and the launch environment. Add a small Linux launch/test wrapper only if needed to make save isolation and commands repeatable.

Acceptance: both original commits remain recoverable; development cannot overwrite the 2D playtest or existing 3D campaign; baseline evidence identifies actual failures separately from historical notes.

### M1 — Connect guild navigation and make UI ownership consistent

- [ ] Add `game/hud/guild_nav.gd` and its UID. Tabs: Depths, Hero, Upgrades/Expeditions, Séance and Hall. Display locked features with the existing requirements.
- [ ] Route G, the navigation buttons and `GuildRoom` stations to the same existing panel instances. Include a visible Close/Return action; retain the selected floor and each panel's scroll position.
- [ ] Centralize pointer, movement, HUD visibility and return-context decisions. Keep that helper local to presentation; do not turn it into a second run state machine.
- [ ] Implement guild, hero-inspection, help and pause controls, including pause over rewards/exit/death screens, options returning to their caller, and correct combat restoration. Add M and dungeon-ghost inspection when those features land in M4; show their help prompts only when usable.
- [ ] Prevent delayed fight staging, animation completion or a hidden button from restoring input to the wrong context.
- [ ] Add the controls/help panel and teach G, E and Escape at the first relevant interaction. Existing onboarding unlocks remain authoritative.

Primary files: `game/world/crawl.gd`, `player.gd`, `guild_room.gd`, `game/hud/hud_root.gd`, `pause_menu.gd`, `options_menu.gd`, `game/fight/fight_director.gd`, `project.godot`, and new navigation/help/context code as needed.

Checks: extend `crawl_guild_test.gd`, `crawl_walkthrough_test.gd`, `crawl_loop_test.gd`, `fight_director_test.gd` and HUD/pause tests. Cover opening a panel while moving, rapid open/close, pause during fight staging, pause during a killing animation, returning to a multi-enemy selection, and pausing an unresolved reward. Prove that each action applies once.

Acceptance: a player can manage the guild through stations or quick tabs, then descend and finish a fight without losing the cursor, moving behind a panel or skipping a choice.

### M2 — Make the 2D layer comfortable over the 3D scene

- [ ] Establish shared panel margins, title/close placement, wallet spacing, button states and tooltip styling through `UiTheme`, `ScreenLayout` and `HudRoot`.
- [ ] Replace fixed layouts that clip with responsive columns and bounded scrolling. Preserve focus and selection when content refreshes. Update stale comments that still describe old card dimensions/reference layouts.
- [ ] Keep cards, enemy tags, vitals and End Turn in separate readable regions. Reserve space for selected-card text and target feedback without covering all the creatures.
- [ ] Add a full card inspection view and accessible deck/draw/discard inspection using actual fight data. Show draw-pile composition without revealing hidden shuffle order, and never consume RNG during inspection. Preserve the existing single-enemy automatic targeting behavior.
- [ ] Make enemy tags selectable through the same target action as models. Show valid target feedback on the tag and body; reject dead/stale targets and blocked clicks.
- [ ] Ensure card costs, modified values, status explanations and invalid-action reasons come from current content/combat helpers. Keep engine results authoritative; describe any future damage preview as a preview until it matches all modifiers.
- [ ] Show reward, shop, rest and exit consequences clearly, with the current deck/health/resources where relevant. Do not recreate the older floor-10 caps or progression assumptions.
- [ ] Add UI-scale settings. Apply them immediately and persist them in `Settings`, separately from campaign data. The complete reduced-motion setting lands with its world and interface behavior in M6.
- [ ] Add English and Spanish keys for new text; check long translations, numeric growth and tooltips. Preserve the established icon family and font pairing.

Primary files: `game/hud/hand_view.gd`, `enemy_tag.gd`, `hero_screen.gd`, `choice_screen.gd`, `exit_screen.gd`, `hall_screen.gd`, `game/widgets/card_view.gd`, `hero_panel.gd`, `wallet_bar.gd`, `game/theme/ui_theme.gd`, `screen_layout.gd`, `game/settings.gd`, `data/strings/en.csv`, `es.csv`, and new inspection widgets.

Checks: existing card/hand/tag/hero/choice/exit/Hall/settings tests plus focused inspection and keyboard-route regressions. Native review at 1280×720 and 1920×1080, with 960×540 as the compact layout and 2560×1080 as the wide layout. Review 100%, 125% and 150% UI settings; use reflow/scrolling where needed. At 1280×720 target at least 16 effective pixels for body text and 18 for enlarged card rules. Assess readability in the actual render, not only from font constants.

Acceptance: no clipped primary actions; every card can be inspected; targets are usable by model, tag and keyboard focus; dense/translated panels remain usable; switching panels does not reset a long list on every Soul tick.

**First playable integration:** M0–M2 deliver the 3D game with convenient 2D guild navigation, reliable controls and readable combat. The remaining milestones complete the model previews, map, campaign import and presentation work.

### M3 — Share models between management and the world

- [ ] Add `game/widgets/model_preview.gd` with its UID: an isolated `SubViewport`/`World3D`, a controlled camera and consistent lighting. Render only while visible; start with one active preview per open panel.
- [ ] Build preview instances from the same visual factories as the world. Keep them free of campaign actions, encounter collision and gameplay audio. Never reparent a live world actor into the preview.
- [ ] Replace the 3D branch hero sheet's static figure with a class-aware model. Add `game/art/hero_figure.gd` and its UID, reusing rig/material helpers where appropriate. Give the Sexton and Hexer distinct silhouettes tied to their established class/relic identities.
- [ ] Adapt the legacy hero layout: model and identity/stats beside each other, deck below, and class/unlock choices preserved. On small windows the preview shrinks or collapses before the text becomes unreadable.
- [ ] Adapt the legacy selected-floor panel to show residents, production, haunting state and descent eligibility next to the current tower. Keep support for cycling biomes and floors beyond thirty.
- [ ] Add a ghost detail view keyed by `ghost_id`: name, floor, kind/state, deck, strength, relevant production information and a preview. Keep displayed calculated values sourced from the current economy helpers.
- [ ] Preserve `CreatureRig`/`CreatureDetails` anatomy and `GhostFigure` colors, shrouds and fade behavior. Reuse the preview mechanism for selected creatures where it helps inspection; keep full roster browsing as a later optional feature.

Primary files: new preview/hero/detail components, `game/hud/hero_screen.gd`, `ladder_screen.gd`, `seance_screen.gd`, `game/widgets/tower_view.gd`, `ghost_line.gd`, and current creature/ghost visual factories. Legacy references: `main:game/art/crypt_view.gd`, `main:game/screens/hero_screen.gd`, `main:game/screens/ladder_screen.gd`.

Checks: selected record and preview identity agree; changing selection releases the old visual; hiding the panel stops preview rendering; repeated openings leave no orphan nodes or accumulating lights/viewports. Review both hero classes, all ghost states and a floor above thirty.

Acceptance: the useful live-preview ideas from `main` are present with the newer models, data and progression. Changing a preview cannot change the campaign or disturb a fight.

### M4 — Link the tower, ghosts and dungeon map

- [ ] Add `game/hud/floor_map.gd` and its UID. Draw the current `FloorLayout.cells`, rooms, `node_rooms`, entry and stairs; derive encounter completion from the current run.
- [ ] Use a full-floor schematic for the initial delivery. Include the player position/orientation and a legend. This requires no new exploration-save schema or duplicate floor generator.
- [ ] Allow a map click to select a navigation marker for the existing compass. It must not enter/resolve a room, teleport the player or unlock the stairs.
- [ ] Keep the map available during exploration. Required choices and fights retain their own interface; M cannot bypass them. Closing the map returns the same body and camera to exploration.
- [ ] Add focused ghost interaction in the world, opening the same detail view by `ghost_id`. Dungeon ghost inspection is read-only; spending and tending remain guild actions.
- [ ] Keep tower selection, ghost list selection and well highlights consistent for visible floors. For floors beyond the well's render range, show their exact ledger data and an explicit deeper-floor indicator instead of presenting the wrong floor as the real location.
- [ ] Refresh visible figures and panels from existing campaign signals after tending, echo changes, returning expeditions and a new death. Avoid rebuilding the entire dungeon or well for numeric-only ticks.

Primary files: new map/detail interaction code, `game/hud/compass.gd`, `prompts.gd`, `ladder_screen.gd`, `game/world/crawl.gd`, `interactable.gd`, `ghost_figure.gd`, `well_view.gd`. Read `core/run/floor_layout.gd` and `run_state.gd` without mutating them from the UI.

Checks: map and world agree for the same seed, player coordinates scale correctly, resolved nodes and stairs match the run, and marker selection leaves serialized campaign state unchanged. Verify ghosts at floors 1, 30, 31 and beyond the current 60-floor well display limit.

Acceptance: the player can connect a ledger entry to a ghost in the world and use the map to find the next room without creating a second navigation simulation.

### M5 — Bring legacy campaigns forward safely

- [ ] Capture synthetic version-1 fixtures from the preserved 2D implementation at guild, descent draft, node, fight, reward, event/shop/rest, exit and completed-run boundaries. Do not commit a user's personal campaign.
- [ ] Verify the existing version-2 migration against those fixtures and current campaign defaults: hero/deck/relic identity, resources, upgrades, ghost records, reach, unresolved nodes and newer unlock/progression fields.
- [ ] Verify that a loaded active phase gets the correct 3D room and interface. Reconstruct a safe player position from the logical run; exact old first-person coordinates do not exist in a 2D save.
- [ ] Add an explicit legacy-save import entry to the title/options flow. Import a selected file into a separate campaign slot; show its identity and retain the source and the current campaign. Do not combine two campaigns' currencies, ghosts or progression.
- [ ] Add only the slot-selection plumbing needed for importing and continuing those campaigns. Retain the existing `slot1` default for current players; normal 2D/3D views inside one campaign always use the same active slot.
- [ ] Validate file shape and content references, reject unsupported future versions clearly, and report backup recovery. Audit the loader's behavior when the primary is missing but a backup exists.
- [ ] Harden saves with a temporary write and validation before committing the replacement and rotating valid backups. Ensure a failed write leaves the last playable save recoverable.
- [ ] Test offline catch-up with fixed timestamps and prove it is applied once across import, load and subsequent save. Bump the schema only if persisted data changes; UI settings stay in `Settings`.

Primary files: `core/save/save_game.gd`, `core/campaign.gd`, relevant `from_dict` methods in run/hero/ghost code, `game/game.gd`, `game/hud/title_menu.gd`, `options_menu.gd`, and new import/slot UI plus synthetic fixtures.

Checks: extend `tests/core/save/save_game_test.gd`, run-save/campaign tests, and add load-to-scene regressions in the game suite. Include failed writes, corrupt primary, both backup levels, missing primary, future schema, repeated migration and an already-progressed 3D save.

Acceptance: a copied 2D campaign continues in the hybrid with coherent progress; a current 3D campaign round-trips unchanged; a failed import or write preserves existing progress. Import does not promise the older executable can read newer saves.

### M6 — Finish the art, world readability and performance pass

- [ ] Review every enemy in neutral light and its actual biome. Refine silhouettes, weapon/body clearance, contact with the floor, attack anticipation, impact and collapse where the review identifies a weakness.
- [ ] Keep a consistent material scale, stone/metal/bone treatment and shared color grade across portraits, cards, ghosts and the world. Improve lighting around important creatures and stations while retaining the crypt's darkness.
- [ ] Give the guild stations distinct, recognizable props matching the navigation icons: upgrade table, séance circle, hero desk, Hall and well. Check their collision and walking routes.
- [ ] Preserve and refine the death-to-ghost sequence. The new figure, epitaph, ledger entry and production change must describe the same hero and resolve once. Reduced motion shortens camera/ornamental movement without hiding results.
- [ ] Make focus, target and ghost states readable with labels/icons as well as color. Add and persist a reduced-motion setting covering camera shake, head bob, forced camera moves, panel/card transitions and preview animation; retain necessary impact feedback.
- [ ] Measure CPU/GPU frame times, draw calls, active lights, viewport cost and repeated-open memory behavior. Start with 60 FPS at 1080p on the current development machine as a target, recording hardware/renderer; establish a measured lower-spec target before claiming support.
- [ ] Reduce unnecessary shadow-casting lights and invisible preview updates, reuse shared meshes/materials, and update lists/figures incrementally. Profile simulation-driven preview stalls before introducing asynchronous work or changing simulation sample counts.
- [ ] Add a modest lower-cost visual preset if measurements justify it. Preserve the same gameplay; a full Compatibility-renderer edition is a separate task.
- [ ] Extend the existing screenshot tools to cover the hybrid screens and update `ART_BRIEF.md` and `ATTRIBUTION.md` for any added assets.

Primary files: `game/fight/creature_rig.gd`, `creature_details.gd`, `creature_pose.gd`, `enemy_body.gd`, `fight_animator_3d.gd`, `game/world/ghost_figure.gd`, `guild_room.gd`, `well_view.gd`, `player.gd`, `game/theme/grade.gd`, `game/settings.gd`, preview code and capture tools.

Acceptance: no new route obstructions or invisible targets; each enemy and station is recognizable at playing distance; motion options work; hidden previews have no ongoing render cost; performance findings include measured conditions and remaining limits.

### M7 — Validate the complete loop and promote the hybrid

- [ ] Complete the end-to-end scenarios in section 6 on fresh, migrated and current 3D campaigns, using isolated data directories.
- [ ] Run the full core and game suites after the final substantive changes, plus content validation and the headless demos/balance checks required by repository guidance. Keep RNG and timestamps fixed for comparisons.
- [ ] Review final native captures alongside the M0 baseline. Include the newest biome and deep progression; a successful first-floor fight alone is insufficient.
- [ ] Update the pivot design, controls documentation, art brief and outdated deferred entries to describe the delivered hybrid. Document launching the preserved 2D edition with separate saves.
- [ ] Ensure new `.gd` files have tracked `.gd.uid` sidecars and loader-read CSVs keep their existing `keep` imports. Exclude generated translation and cache files.
- [ ] Integrate the completed branch into `3d-pivot` with ordinary reviewed commits. Then prepare promotion to `main` while retaining the legacy refs and commit history.
- [ ] Resolve main/3D divergence explicitly: preserve the newer core, content, Forward+ settings and `crawl.tscn` entry point; account for each legacy-only change through the reuse matrix. Validate the resulting merge tree before pushing it. Avoid branch resets or force pushes.

Acceptance: one tested hybrid becomes the normal development edition; the archived 2D edition remains playable and recoverable; documentation and saves identify which edition is being used.

## 6. End-to-end validation matrix

| Scenario | Required result |
| --- | --- |
| New campaign → guild station → quick tabs → descend | Both navigation routes use the same screens and resources; class/draft gates still apply. |
| Select each floor and a ghost → preview → close | Record, preview, tower selection and eligibility agree; no state changes from inspection. |
| Multi-enemy fight → select card → open help/pause → resume → target → End Turn | Cursor/focus return correctly; no lost selection, double action or accidental turn. |
| Last enemy dies while pause/help is requested | Animations, reward transition and teardown each complete once; mandatory rewards remain reachable. |
| Reward → event → shop → rest → stairs | Every phase has a usable panel and correct consequences; map/shortcuts cannot skip requirements. |
| Retreat, death and prepared Watch | Current results are preserved; hero, ghost, Soul, reach and the well/ledger refresh agree. |
| Expedition arrives while a management panel is open | Resources, countdowns and ghost views update without resetting selection or applying production twice. |
| Tend, echo changes, Legend/Chronicle use and prestige | Existing affordability, unlocks, accrual and reset rules remain intact across all views. |
| Floors 10/11, 20/21, 30/31 and beyond 60 | Current biome/tier logic survives; map and ledger show true depth despite bounded 3D well rendering. |
| Save/load at every supported run phase | Same logical run resumes in a valid 3D context; no duplicated rewards, turns or ghosts. |
| Resize, change UI scale/language, use keyboard focus | All primary actions remain reachable; previews do not crowd out readable text. |
| Repeat open/close, fight, travel and inspection cycles | No growing orphan-node count, duplicate signals, stuck overlays or accumulating previews/lights. |

Import the project before GdUnit's script runner after changing class-name scripts. Pin the project's Godot version for deterministic comparisons. Use the existing GdUnit command in `tools/test.cmd` or its equivalent on Linux, with `tests/core` and `tests/game` selected explicitly. Use `tools/fight_demo.gd`, `run_demo.gd`, `campaign_demo.gd` and `balance_sim.gd` under the isolated test environment. Baseline comparisons are against the 3D branch; the older 2D version has different content and rules.

A test report with passing assertions and a crashing process is recorded as such. Resolve the existing shutdown problem where practical; if it remains external to these changes, retain its reproduction and report it explicitly instead of presenting a clean test-process exit.

## 7. Delivery order and completion criteria

| Order | Deliverable | Depends on |
| --- | --- | --- |
| 1 | M0: preserved versions, isolated saves, baseline | Nothing |
| 2 | M1: shared navigation and input ownership | M0 |
| 3 | M2: readable panels, combat inspection and settings | M1 |
| 4 | M3: shared model previews and hero/ghost details | M1–M2 |
| 5 | M4: map and links between ghosts and management | M1, M3 |
| 6 | M5: tested legacy import and reliable saves | M0; final load-to-scene checks use M1–M4 |
| 7 | M6: art, motion and measured performance refinements | M2–M4 |
| 8 | M7: complete-loop validation and branch promotion | M0–M6 |

Save-fixture work can begin after M0; complete it before anyone uses the hybrid with their real legacy campaign. Art refinement can proceed once the shared preview/model boundaries exist. Neither changes the first playable target of M0–M2.

- [ ] All milestone acceptance checks have evidence, and completed checkboxes correspond to delivered behavior.
- [ ] The hybrid retains the newer progression and the useful 2D navigation/preview ideas without duplicate gameplay state.
- [ ] Guild management, combat, exploration and inspection have consistent controls and readable UI.
- [ ] The selected hero/ghost looks and identifies consistently in 2D panels and 3D views.
- [ ] New, migrated and existing 3D campaigns complete the full loop without loss or duplication.
- [ ] Art and performance changes have native captures and measurements, with any remaining limits recorded.
- [ ] The 2D edition is preserved; the final branch history and launch documentation make both editions recoverable.

Follow-ups after this integration: complete key rebinding/controller navigation, a full creature compendium, additional authored model detail, and any broader 2D-only or lower-renderer mode. Scope those from playtest findings after the hybrid loop is complete.
