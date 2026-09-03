# M3 Stage 1 — The Chronicle

Spec §6.2. Ink has existed since Legends shipped and bought nothing.

## Why a second layer at all

The first prestige layer makes numbers bigger. That is what a Blessing is, and
a game whose only permanent progression is a multiplier runs out of things to
say after the third cycle. §6.2's answer is a currency that only a rite
produces — one Ink per cycle — spent on Chapters that change *what a cycle is*
rather than how big it is.

The Chronicle opens at five Legends, because a mechanic that only pays across
cycles is noise until the player has run several. It says so with the count
rather than by hiding: a currency accruing with nothing to spend it on is
worse than a locked shelf.

## The four Chapters

- **Deeper Roots** — each cycle's Founder stands three floors deeper per level.
  A reset that starts you further down is the clearest possible statement that
  the layer above the reset is real.
- **The Breeding Dark** — every floor spawns 10% more per level. It multiplies
  the `ghost_spawn` upgrade rather than replacing it: a guild with both gets
  both.
- **Old Blood** — a tenth of your Soul survives the rite per level, capped
  short of 1.0 so the rite never stops being a reset.
- **Depth Seals** — the one that is not a passive number.

## Depth Seals

Opt-in difficulty that multiplies yield: a Seal makes every enemy 25% bigger
per level and makes anything you leave down there worth 45% more. The yield
step is deliberately steeper than the difficulty step, because an opt-in
difficulty that pays less than not opting in is a feature nobody has, and a
test asserts exactly that for every seal level.

The seal rides on the **ghost**, not on its strength. Applying the multiplier
once at placement would have been simpler and wrong: a later Tend re-prices
the ghost through `strength_for`, and would have quietly washed the seal off
the thing the player took a risk for.

It is set in the Hall rather than on the Ladder, because setting one is a
prestige-layer decision — the guild betting a cycle's dead — and because the
Chronicle is what sells it.

## The identity, again

A guild with no Chapters has `founder_floor` 1, `spawn` 1.0, `soul_kept` 0.0,
no seals, and `seal_scaling(0) == seal_yield(0) == 1.0`. The run demo and the
fight demo are byte-identical to `204bfd8`, the campaign demo is unchanged
since the balance pass, and `balance_sim` still exits 0.

## What the renders caught

Six Legends and a Chronicle under them is taller than a 360-pixel frame, and
the half that went off the bottom was the half with the buttons on it. The
Hall scrolls now. `hud_shot` grew a `shot_scroll` flag that fires **after**
the frame wait, because a `ScrollContainer` clamps `scroll_vertical` to zero
until its content has been laid out — so a shot that asks before the wait
photographs the top of the screen and reports success.

1241 tests green.
