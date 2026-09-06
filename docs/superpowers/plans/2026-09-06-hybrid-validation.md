# Hybrid integration evidence

Implementation worktree: `/home/usuario/Escritorio/ghost-guild-hybrid`, branch
`hybrid-integration`. The original checkout remains on the 2D `main` commit.

## M0 baseline

- Preserved `2d-legacy` and `archive/2d-2026-09-06` at `5200eda`; preserved
  `archive/3d-2026-09-06` at `1e8f8bf`. Names were unused. Development starts
  at the verified `3d-pivot` head `1e8f8bf`.
- Engine: `4.7.2.stable.official.ed1daf0bf`, Linux x86_64.
- Import succeeded. Core + game: 1,269 cases, 0 errors, 2 failures,
  0 skipped, 0 orphans. Both failures are missing Spanish rows for
  `ui.menu.kicker` and `ui.menu.premise`. Runner reports exit 100; process
  subsequently aborts with exit 134 during disposal.
- Native Forward+ captures: guild/title, hero, ladder, séance, Hall, combat,
  reward, exit and Watch. PNG writes succeeded. Exit and Watch processes
  subsequently aborted during shutdown; other captures exited 0.
- Raw evidence is in `/tmp/ghost-guild-hybrid-evidence/baseline/`, produced
  from a detached baseline worktree, with separate `XDG_DATA_HOME`.
- `tools/launch.sh` separates persistent edition profiles; `tools/test.sh`
  imports first and gives each invocation disposable user data.

Implementation and final verification results are recorded below as they land.
