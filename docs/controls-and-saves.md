# Playing the hybrid and the preserved 2D edition

Use Godot **4.7.2**. The hybrid boots `game/crawl.tscn` with Forward+ and native
3D rendering. `HudRoot` scales the 2D interface independently.

## Launch with separate saves

From the hybrid checkout:

```sh
export GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64
tools/launch.sh
```

The Linux wrapper defaults to the `hybrid` profile. Its user data lives under
`~/.local/share/ghost-guild-editions/hybrid/godot/app_userdata/Ghost Guild/`.
Set `GG_PROFILE` for another independent profile, or `GG_DATA_ROOT` for an
explicit user-data root. A direct Godot/editor launch still uses Godot's
historical default directory; use the wrapper for edition isolation.

The preserved edition is `2d-legacy` at `5200eda`, also named by
`archive/2d-2026-09-06`. This session keeps the original `ghost-guild` checkout
on that branch. From the hybrid checkout, launch that original directory with:

```sh
GG_PROFILE=legacy GG_PROJECT_ROOT=../ghost-guild tools/launch.sh
```

On a fresh clone, create a separate checkout first:

```sh
git worktree add ../ghost-guild-2d 2d-legacy
GG_PROFILE=legacy GG_PROJECT_ROOT=../ghost-guild-2d tools/launch.sh
```

A separate profile initially has no campaign. Existing default-directory saves
are left in place. To continue an old 2D playtest in an isolated legacy profile,
copy its `saves` directory into that profile after closing the game. For hybrid
play, use the copy-import flow below instead.

On Windows, use separate `APPDATA` directories for each edition when launching
Godot. `tools/test.cmd` already gives each test run a disposable `APPDATA`.

## Controls

| Input | Action |
| --- | --- |
| WASD / Shift / mouse | Walk, sprint, look during exploration. |
| E | Use the focused guild station or inspect a focused dungeon ghost. |
| G | Open/close guild management, remembering the last tab. |
| I | Inspect hero and deck from exploration; dungeon inspection is read-only. |
| M | Show the current floor map during exploration. Click a walkable location to mark the compass. |
| F1 | Help, returning to the panel or fight underneath. |
| Left click / Enter | Activate controls, play a card, or choose an enemy target by its model/tag. |
| Tab / Shift+Tab | Move focus through controls, cards, targets and End Turn. |
| Right click / F on a card | Inspect full card text. |
| Escape | Cancel targeting first; close optional panels; otherwise pause. Required choices stay underneath pause. |

The management tabs and their Close button are also usable with the mouse.
Combat movement is atmospheric: it does not change range, damage or turns.
Deck/draw/discard/hand and status buttons use the live fight. Draw inspection
shows sorted composition, never the hidden shuffle order.

Options stores 100–150% UI scale, English/Spanish and reduced motion alongside
sensitivity, field of view, volume and window mode. Dense panels scroll and
follow keyboard focus. F1 displays bindings from the current InputMap.

## Import and continue campaigns

Open **Campaigns / Import** from the title or Options. Import a selected JSON
save into a new `import_N` slot, then choose Continue for that slot. The list
shows hero identity and campaign seed. The source and the previous campaign
remain separate. Import never combines resources, ghosts or progression.

Schema 3 stores exact combat piles, enemies, turn state and RNG streams.
Historical version-1/2 fight saves had already discarded the in-progress fight
and stored an unresolved node; those resume at that encounter, with the old
serialization's restart behavior. Other supported phases reconstruct a safe
room from the logical floor and open the corresponding interface. Older
executables are not promised to understand schema 3.

Imports validate structure and content before loading. Future versions are
rejected. A corrupt or missing primary can recover from `.bak1`, then `.bak2`;
the UI reports recovery. Writes validate a temporary file before atomically
replacing the primary and rotate only valid backups. Offline production is
banked to the imported slot once using the recorded timestamp.

## Repeatable checks

```sh
tools/test.sh tests/core tests/game
GG_PROFILE=review tools/launch.sh -s tools/hud_shot.gd -- /tmp/hybrid.png hero 90 1280 720 1.25 es
GG_PROFILE=review tools/launch.sh -s tools/hybrid_bench.gd
```

Tests own disposable saves and import the project before running GdUnit4.
Capture and benchmark tools create synthetic campaigns. See
`docs/superpowers/plans/2026-09-06-hybrid-validation.md` for results and limits.
