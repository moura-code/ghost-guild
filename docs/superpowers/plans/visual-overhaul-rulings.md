# Visual overhaul — ruling ledger

Calls made on Joao's behalf while executing
`2026-08-24-visual-overhaul.md`. Visible so they can be reversed.

## 1. Generated art ships, and Steam must be told

**Ruled 2026-08-24, by Joao directly.** Asked where new art should come from,
Joao chose "code-drawn base, generated card/enemy art on top" over the
previews-only rule that had held until then.

Consequence: `assets/icons/{card_art,enemies,relics}/*.png` are SDXL base 1.0
outputs and go in the build. **Steam's AI-content disclosure is now mandatory
for this game.** Recorded in `ATTRIBUTION.md` and pinned by a test, because
the one way this goes wrong is quietly.

Reversing it means deleting those PNGs; the loader falls straight back to the
CC BY glyphs and nothing else breaks.

## 2. The palette was rewritten rather than extended

The old ramp was six purples between 4% and 42% luminance. Adding to it would
have kept the fog. `theme_test.gd` now asserts the *rules* — the ladder
climbs, it spans more than 0.80, light is warm, ghost cyan is the only cool
accent — rather than the specific values, so the values stay tunable.

Anything that looked deliberately purple now looks deliberately warm-lit.
That is the intended change, not a regression.

## 3. Edge pillars stopped glowing

`crypt.gdshader` brightened the outer 13% of the frame by 60%. On almost
every screen those two vertical bands were the brightest pixels in the
window. They fall into shadow now. If the frame reads as too dark at the
edges, the lever is `pillar * 0.80` rather than going back to brightening.

## 4. One rank of arches, not two

The second rank sat behind the first at low contrast and read as a rendering
artifact. Removed. The remaining rank is a genuine hole with a warm lit edge,
where before an opening was only 26% darker than the wall it was cut into.

## 5. Cards grew instead of their text shrinking

`ashes`, `death_knell` and `hallowed_strike` had their rules text cut off
mid-sentence. The card is 158x252 now rather than 158x232, sized from the
font to fit four lines. The alternative — shrinking the type — would have
made every card harder to read to fix three.

Knock-on: the fight's End Turn reservation dropped from 170px to 150px so a
five-card hand still fans without covering its own text.

## 6. The wallet moved out of the Ladder

Soul, rate and reach were built inside `LadderScreen`. They are `WalletBar`
now, mounted by `MainScreen` above every tab, because the Guild and the
Séance — the only two screens where Soul is spent — showed no balance at all.
Seven tests moved with the widget into `wallet_bar_test.gd`.

## 7. Two hero-screen tests were rewritten, not deleted

`test_the_deck_lists_every_card_grouped_with_a_count` and
`test_upgraded_cards_are_marked` asserted the old text-list deck. The deck is
card faces now, so both were rewritten against the new representation and a
third was added for the repeat-count badge. Grouping behaviour is unchanged
and still asserted — a thirty-card deck still reads as a dozen entries.

## 8. Not done, and why

- **Sound.** Still unscoped anywhere, and after this work it is the largest
  remaining gap in how the game feels. It needs its own spec; it is out of
  scope here by §6 of the design.
- **The Guild screen** was left alone. It was the one screen the review did
  not fault: icon plates, pip levels and prices already read as a system.
- **`deferred-items.md`'s two balance findings** are untouched. This plan
  changes no content values.
