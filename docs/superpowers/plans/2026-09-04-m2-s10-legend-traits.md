# M2 Stage 10 — A Legend that does something

Spec §6.1. The half of prestige that shipped as a label.

## Why this, now

Stage 7 forged Legends and gave them a Blessing. It also gave each one a
`trait_tag`, chosen from the dominant archetype of the decks it merged, saved
it, printed it on the Hall screen — and nothing read it. A player who spent a
whole cycle on Poison got a Legend called Poison that did exactly what a
Legend called Bone did.

The spec is specific about both halves: "a **trait** from the dominant
archetype (a Poison Legend makes the hero's Poison cards apply +1 stack). One
Legend can be invoked per run as an extra relic."

## What a trait is

Content, not code. `data/traits/base.json` keys one trait to each card tag the
game uses, with a four-op vocabulary — `status`, `damage`, `block`, `draw` —
each of which is a place the resolver already computes a number.

The narrowness is the design. A trait boosts **one kind of effect** on cards
carrying **its own tag**, so it is legible on the card in your hand: you can
see which of your cards it applies to. A Poison trait that also improved your
Block cards would be a global modifier wearing a tag's name.

`validator.gd` refuses two traits on one tag, and `traits_test` asserts that
every tag the shipped cards actually carry has one — the failure that catches
is silent by nature: a cycle spent on a tag nobody authored a trait for buys
the player nothing and never errors.

## Invocation

`Campaign.invoked_legend` holds an **id**, not an index. The Hall lists the
merged oldest first, so an index would silently re-point the invocation at
somebody else's grave the next time the guild prestiges.

The choice is refused while a run is live, because a run snapshots the trait
at the door the same way it snapshots the Blessing and the claimed pools. A
run is a closed system that replays from its seed; swapping Legends mid-run
would put a number on the screen the fights already fought were not using.

The button lives on the Legend's own row in the Hall rather than in a picker
somewhere else, because the thing you are choosing between is the epitaphs.

## The identity

`Traits.bonus(null, ...)` is zero for every op, and a campaign with no Legends
invokes nobody. The three demos and the balance sim are byte-identical, which
is the criterion this codebase uses for "the feature is absent when it is
absent". Prestige is the one system that multiplies everything, which makes it
the one that most needs to vanish completely at zero.

## Self-review

The risk was scope creep in the vocabulary: traits are exactly the sort of
feature that grows an op per idea until nobody can balance it. Four ops, one
per place the resolver already had a number, and a closed list the validator
enforces.

The second risk is that the end-to-end claim is never actually tested — that
the arithmetic is checked and the wiring is not. So the last two tests play a
real Poison card at a real enemy through the real resolver with and without
the Legend, and assert the difference is exactly one stack; and play a Strike
under a Poison Legend and assert nothing changed.

1189 tests green.
