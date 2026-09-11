# Player clarity: balance and progression follow-up

Validated 2026-09-11 against content revision `clarity-2026-09-10-r4` and
Godot 4.7.2, official `ed1daf0bf001b61586d9930840f2f1394092c079`.
This follows the [implementation record](2026-09-09-player-clarity-validation.md)
and addresses its early attrition and underprepared later-profile gaps.
The five-player usability gate remains open; the user has no new-player
feedback yet.

## Final tuning

Only three enemy values change from the previously pushed `r2` content:

| Value | Roadmap baseline | Previous r2 | Current r4 |
| --- | ---: | ---: | ---: |
| Bone Rat HP | 14 | 18 | 17 |
| Bone Rat Bite damage | 5 | 6 | 5 |
| Shambler HP | 24 | 30 | 27 |

Grave Wisp keeps its increased 18 HP. Enemy schedules, Gnaw's two 3-damage
hits, all other enemy values, encounter groups, starter decks, prices, healing,
rewards and scaling formulas remain at the previous implementation's values.
There is no player-dependent difficulty adjustment.

The development diagnostics identified repeated damage from durable pairs
across Floors 2–4. Lowering Bite reduces accumulated damage; the HP changes
preserve enemy actions while avoiding an abrupt early attack threshold.
With the authored floor scaling, a Floor-2 rat now has 18 HP instead of 19:
three unmodified Strikes can defeat it. Relative to the original roadmap
baseline, the enemies still have more HP and early groups still combine threats.

Candidate changes were first compared on the original 30 development seeds.
The two-value intermediate candidate (`r3`, never pushed as game content)
reached the band on the first new validation set but still produced 37.1%
median loss on the old reference set. A further development comparison tested
the rat's 1-HP adjustment. Final values were frozen before the separate
`confirmation` set was run. No values were changed in response to confirmation
results. Trial logs and JSON remain under `reports/clarity/2026-09-10/`.

## Profiles, seeds and reporting

The original fresh Sexton, 70-Soul early-purchase Sexton, unlocked Hexer and
underprepared Floor-31 profiles are retained. `prepared_cycle` adds a second
Floor-31 Sexton with the same three-level Might/Wit/Vigor/Focus purchases,
all three biome card pools claimed, and two Legends each made from 1,600
merged strength. The production Legend formula yields 2× per Legend and a
combined 4× blessing. This is a legal synthetic progression profile, not an
observed player's save or an estimate of the time needed to earn it. The
normal Descent draft runs for both later profiles.

Reporting now records engine hash, content revision, seed base/stride, resolved
profile definitions, entry floor, blessing, claimed pools, enemy rosters and
first-fight wins. Checkpoints and opening-turn windows follow the entry floor:
Floor 4 / Floors 2–4 for fresh builds, Floor 34 / Floors 32–34 for later builds.
Deaths and checkpoint sample counts remain separate from survivor HP losses.
The original Floor-4 fields remain available for historical comparisons.
Quantiles use the lower empirical index `floor((n - 1) * p)`.

| Set | Seed formula | Profiles | Seeds/profile/policy | Final runs, both routes |
| --- | --- | ---: | ---: | ---: |
| Development | `73019 + i * 7919` | 5 | 30 | 900 |
| Original reference (`held_out`) | `970003 + i * 7919` | 4 | 100 | 2,400 |
| Final confirmation | `3000001 + i * 7919` | 5 | 100 | 3,000 |

The intermediate `validation` set starts at `1900001`; it is retained in the
tool and trial reports but was not reused as the final independent check.
Tests verify that all four sets are disjoint over their first 100 seeds.
Safe skips optional elites; all visits every optional room once. All **6,300
final reported runs terminated**. These are forced-push diagnostics with a
ten-floor span and a voluntary retreat at the cap, not human retreat choices.

The committed [CSV](2026-09-10-difficulty-summary.csv) has 84 summaries for
those six final report files, including HP loss, gross damage, healing,
blocking, enemy actions, Coin spending, turns, deaths and depth distributions.
`tools/difficulty_summary.py` regenerates it from the JSON reports.

## Opening and permanent growth

On both the original reference set and the new confirmation set, fresh
safe-route defensive play reaches a **34.3% median Floor-4 HP loss**, with
100/100 reaching that exit. The original `r2` reference result was 44.3%.
The safe-route comparison now supports the unchanged provisional 15–35% band.
Normal fights remain longer than the original baseline's roughly two turns.

Final confirmation set, 100 runs per row:

| Build / policy | Route | Reach F4 | Median F4 loss | Mean F2–4 normal-win turns | Mean ending depth |
| --- | --- | ---: | ---: | ---: | ---: |
| Fresh / attack-first | safe | 72 | 65.7% | 3.18 | 5.21 |
| Fresh / defensive | safe | 100 | 34.3% | 4.46 | 7.22 |
| Fresh / lookahead | safe | 100 | 28.6% | 3.60 | 8.08 |
| Early purchases / defensive | safe | 100 | 20.5% | 3.76 | 8.08 |
| Early purchases / lookahead | safe | 100 | 19.2% | 3.00 | 8.89 |
| Fresh / defensive | all | 98 | 41.4% | 4.43 | 6.97 |
| Early purchases / defensive | all | 100 | 23.3% | 3.73 | 8.12 |
| Early purchases / lookahead | all | 100 | 20.5% | 2.97 | 9.19 |

All three fresh policies win their first fight in all 100 confirmation runs;
later losses still depend strongly on decisions. Early purchases reduce
mean safe-route checkpoint loss by 36.0% for defensive play and 26.8% for
lookahead, and normal-win turns by 15.7% / 16.6%. The extra elite risk remains
visible in the all-route results and is not folded into the ordinary safe-route
target. Survivor medians alone would hide the attack-first deaths; the CSV
retains their counts and distributions.

## Later-cycle comparison

With lookahead on confirmation safe routes, the old 1.25× profile clears
Floor 31 in 13/100 runs and ends at mean depth 31.13. The prepared 4× profile
clears it in **99/100**, ends at mean depth **33.44** (p10/median/p90:
32/33/35), and reaches the Floor-34 exit in 21/100. Its Floors 32–34 normal
wins average **4.49 turns**. The coarse defensive policy averages 6.17 turns;
the full distributions remain available rather than implying every policy
meets the approximate 3–6-turn aim.

This demonstrates a usable later entry and a moving frontier for an explicitly
prepared build. It does not establish the pacing of every prestige cycle or
justify changing the late-biome scaling in this opening-focused pass.

## Compatibility, economy and checks

The content revision uses the existing once-per-revision cache migration.
New regression cases load an `r2` fight with a 30-HP Shambler and an 18-HP rat:
the complete saved fight, including HP, deck and RNG, remains identical.
Subsequent Bite actions use 5 damage; newly spawned enemies use 27/17 HP.
The `r2` catch-up case separately verifies old-rate offline income, source
before linked-echo repricing, fixed Founders and expedition promises, and no
second accrual/repricing on another load.

The final full suite passed **1,327 cases in 129 suites**, zero errors,
failures, flaky/skipped cases or orphans, process exit **0**. Evidence:
`reports/clarity/2026-09-10/full-suite-r4.log` and
`reports/report_41/results.xml`. Combat effect tests now check fixed damage
deltas independently of the enemy's starting HP; spawn/damage regressions
also verify the revised authored values.

The final **14-run / 48-simulation economy check passed**, process exit **0**:
prepared Watch yield rises from 55.81 on Floor 1 to 779.11 on Floor 9 and beats
corpse-plus-echo at every sampled floor. First-run rewards plus 20 minutes
of Founder income total **69.6 Soul**, above the cheapest 20-Soul purchase.
Log: `balance-final-r4.log`; the repeated final process statuses are stored in
`final-process-status.json` alongside it.

The fight, run and campaign demos also completed with exit **0**. The fight
fixture wins in five turns with 65 HP, its 50 simulations finish, the run demo
takes Watch at Floor 7 for 97.7 Soul, and the three-run campaign saves and
reloads successfully. Native 1280×720 `fight-r4.png` shows the revised HP and
intents in the real combat HUD, with exit **0** and no script/window-grab
errors. Existing room architecture and performance evidence remain applicable;
this follow-up changes combat values and diagnostics.
The final editor import exited **0** without warnings or errors. CSV checks
confirm 84 rows, 6,300 samples and only the final revision in the committed
summary (`final-import-r4.log`).

## Reproduction and remaining player check

Use the pinned binary with isolated data, after an import. Each confirmation
command runs 1,500 cases; generated reports and captures remain ignored.
The CSV has a committed `keep` import and the new test has its UID sidecar.

```sh
export GODOT_BIN=/home/usuario/.cache/ghost-guild-engine/4.7.2/Godot_v4.7.2-stable_linux.x86_64
tools/test.sh
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --headless --path . -s tools/difficulty_report.gd -- reports/clarity/review-safe.json 100 confirmation safe 10
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --headless --path . -s tools/difficulty_report.gd -- reports/clarity/review-all.json 100 confirmation all 10
python3 tools/difficulty_summary.py --out reports/clarity/review-summary.csv reports/clarity/review-safe.json reports/clarity/review-all.json
XDG_DATA_HOME=/tmp/ghost-guild-review "$GODOT_BIN" --headless --path . -s tools/balance_sim.gd -- 14 48
```

New-player participation is still **0/5**. The existing five-task protocol
for Wit, a specific Strike upgrade, room identification, shop revisits and
the next permanent improvement still requires at least four unaided successes
per task. Simulation and native captures do not satisfy that human gate.
