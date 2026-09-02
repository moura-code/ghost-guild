class_name CardText
extends RefCounted
## What a card says it does, with its own numbers in it.
##
## Every card's rules text was written out with the numbers spelled into the
## string -- "Gain 11 Block." -- which has one bug in it and had grown a
## second:
##
## - **An upgraded card lied.** Bone Wall+ grants 18 Block and the card still
##   read "Gain 11 Block.", because the text is one string and the effects are
##   two lists. Every upgraded card in the game was wrong about itself.
## - **Placeholders rendered raw.** The Deep, the Hexer and the Kiln were
##   authored with `{0}`-style placeholders on the assumption that something
##   substituted them. Nothing did, so thirty-two cards read "Gain {0} Block
##   and {1} Thorns." on the table.
##
## So the numbers come out of the effects, in the order they are authored, and
## the string carries only the words. `{0}` is the first number the card's
## effects mention, `{1}` the second, and so on.
##
## What counts as a number, per effect and in this order: its `amount`, then
## its `stacks`, then its `hits` when there is more than one. That covers every
## op the validator allows, and the order is the order the words come in --
## "Deal {0} damage {1} times" rather than the other way round.
##
## Scaling is deliberately NOT applied. A card says what it does before Might
## and Wit, the way every card in the game has always said it, so the same
## card reads the same in a shop, in a reward and in a dead hero's deck.


## The numbers this card's effects mention, in authored order.
static func numbers(def: CardDef, upgraded: bool = false) -> Array[int]:
	var out: Array[int] = []
	for raw in def.effects_for(upgraded):
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		if e.has("amount") and not (e["amount"] is String):
			out.append(int(e["amount"]))
		if e.has("stacks") and not (e["stacks"] is String):
			out.append(int(e["stacks"]))
		var hits := int(e.get("hits", 1))
		if hits > 1:
			out.append(hits)
	return out


## The card's rules text, with its numbers in it.
static func of(content: Content, def: CardDef, upgraded: bool = false) -> String:
	return fill(content.text(def.text_key), numbers(def, upgraded))


## Substitutes `{0}`, `{1}`, ... A placeholder with no number behind it is left
## alone rather than blanked: a card whose text and effects disagree should be
## visibly wrong on the table and in `test_every_card_says_what_it_does`, not
## quietly missing a word.
static func fill(text: String, values: Array[int]) -> String:
	var out := text
	for i in values.size():
		out = out.replace("{%d}" % i, str(values[i]))
	return out
