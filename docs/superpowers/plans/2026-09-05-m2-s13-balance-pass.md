# M2 Stage 13 — The first full balance pass

Spec §12. The simulator has been red since M1. It is green.

## What was red

Two of the three asserted invariants failed, and had failed on `main` for long
enough that `CLAUDE.md` told future sessions to ignore the exit code and diff
the output instead. That is a broken instrument being worked around rather
than fixed, and it hides every real regression behind a known one.

## `deeper_pays` was never a balance failure

> **Deeper pays:** for a deck typical of depth f, the marginal yield of a
> prepared ghost rises with f.

Reported yields were `[61.6, 132.5, 189.9, 241.3, 334.0, 455.1, 448.2, 567.9,
720.3]` — monotonic except floor 7, which came out **1.5% under floor 6**.

That is not an economy. It is four runs and twelve simulated fights trying to
price a deck. Re-running the same content at 14 runs and 48 fights makes the
curve monotonic with nothing changed:
`[59.2, 137.3, 193.0, 248.9, 342.0, 468.4, 485.9, 621.5, 769.5]`.

So the fix is the sampler, not the balance. `BalanceSim`'s defaults are 14 and
48 now. The run takes about forty-five seconds, which is the right trade for
the one tool in the repo whose entire job is to be right about numbers.

## `watch_beats_corpse` was a real one

> **Watch beats the corpse:** on any floor, Take the Watch yields more than
> dying there and echoing the corpse anywhere.

This failed on floors 2, 3 and 4 — and it failed *structurally*, not narrowly.
The reason is the saturation curve doing its job: a big strength on one
shallow floor overflows the floor's cap and earns a quarter rate beyond it,
while a corpse plus an echo puts two bodies on two floors and both earn full
value. Placement beats quality in the shallow end.

The Watch cannot answer that by placement — the ghost stands where you died.
So the answer had to be in the numbers, and modelling the whole space found
one lever that carries it: **`restless_penalty`, 0.3 → 0.5.**

At −30%, a restless corpse plus a 75% echo of it out-earned a +25% prepared
ghost. At −50% it does not, on any floor, with margins from 18% at floor 2 to
43% at floor 9. Nothing else moved: `prepared_bonus` stays at the authored
0.25 and `echo_factor` stays at the 75% §5.5 names explicitly.

It is also the right knob to have turned. Restless is what happens when you
die badly, and the game's whole identity is that dying *deliberately* is
better. A −30% penalty was saying it was not. The change also makes Tend —
which clears restless — worth what it costs for the first time.

## What moved

Only the campaign demo, and only the yields of restless ghosts. The run demo,
the fight demo and the balance sim's own curve are byte-identical. That is the
shape a deliberate balance change should have: exactly the thing that was
re-priced, and nothing else.

`upgrades_test` repeated the authored `0.3` in two assertions. It reads the
value out of `balance.json` now — those assertions were about whether an
upgrade had been applied, not about what the default happened to be.

## Self-review

The risk was tuning until the assertion passed. So the search was done
against a model of the invariant with the typical strengths held fixed —
back-solved out of the simulator's own output — over the whole parameter
space, which is what showed that `restless_penalty` carries it alone and that
`prepared_bonus` barely moves it. A one-number change with a reason beats
three numbers that happened to work.

1220 tests green, and `balance_sim` exits 0.
