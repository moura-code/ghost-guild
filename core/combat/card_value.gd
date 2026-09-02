class_name CardValue
extends RefCounted
## What a card is worth to a particular fighter.
##
## Auto-draft "resolves picks with the hero's priority rules" (spec §3.2), so a
## card cannot have one value: a block card is worth more to a ghost told to
## hold the line than to one told to strike first. This scores a card's
## authored effects against an `Autopilot` weight table -- the same table
## `PriorityRules` bends -- so "how good is this card" and "how does this
## fighter play" are one answer instead of two.
##
## **Estimated, not simulated.** The honest way to value a card is to play
## fights with and without it, and that costs seconds per pick. Auto-draft
## resolves one pick per skipped floor, offline, on load; it has to be cheap.
## What it loses is synergy -- this cannot know that a card is good *because*
## of another card -- and `ai_value` is the authored counterweight: it is the
## designer saying what the estimator cannot see.

## How much of the score comes from the card's authored `ai_value` rather than
## from its effects. The effects are what a doctrine has an opinion about; the
## authored number is what the estimator is blind to.
const AI_WEIGHT := 1.4

## A card that costs nothing is not infinitely good. Efficiency is value per
## energy, and a zero-cost card is priced as this fraction of one energy --
## it still occupies a draw.
const FREE_COST := 0.55

## An X-cost card scales with whatever energy is left. Priced as an average
## turn's spare energy rather than as free.
const X_COST := 2.0


## The card's worth per energy spent, under `weights`.
##
## Divided by cost, because a draft compares cards that are not the same size:
## an 18-damage 3-cost and a 6-damage 1-cost are the same card at different
## scales, and a raw total would take the expensive one every time.
static func of(def: CardDef, weights: Dictionary, upgraded: bool = false) -> float:
	var raw := raw_value(def, weights, upgraded)
	return raw / energy_price(def, upgraded)


## The sum of what the card does, before cost.
static func raw_value(def: CardDef, weights: Dictionary, upgraded: bool = false) -> float:
	var total := def.ai_value * AI_WEIGHT
	for raw in def.effects_for(upgraded):
		if raw is Dictionary:
			total += _effect_value(raw as Dictionary, weights, def)
	return maxf(total, 0.0)


static func energy_price(def: CardDef, upgraded: bool = false) -> float:
	var cost := def.cost_for(upgraded)
	if cost == CardDef.COST_X:
		return X_COST
	return maxf(float(cost), FREE_COST)


## The best of `offers` under `weights`, as an index. Ties go to the earliest,
## so a draft is reproducible from a seed and not from dictionary order.
static func best(content: Content, offers: Array, weights: Dictionary) -> int:
	var best_at := -1
	var best_score := -INF
	for i in offers.size():
		var id := String(offers[i])
		if not content.cards.has(id):
			continue
		var score := of(content.cards[id], weights)
		if score > best_score:
			best_score = score
			best_at = i
	return maxi(best_at, 0)


## One effect, in the same currency the autopilot scores a turn in.
##
## `"x"` amounts are the X-cost cards, whose size is not knowable here; they
## are priced at `X_COST` worth of whatever they do, which is the same
## assumption `energy_price` makes on the other side of the division.
static func _effect_value(effect: Dictionary, weights: Dictionary, def: CardDef) -> float:
	var op := String(effect.get("op", ""))
	var amount := _amount(effect.get("amount", 0))
	# An effect on every enemy is worth more than one on a single target, and a
	# draft cannot know how many enemies a floor puts in front of you. Two is
	# the shape of most groups in the slice.
	var spread := 2.0 if String(effect.get("target", "")) == "all_enemies" else 1.0
	match op:
		"damage":
			return amount * float(weights.get("damage", 1.0)) * spread
		"block":
			return amount * float(weights.get("block_useful", 1.0))
		"heal":
			return amount * float(weights.get("heal", 1.0))
		"draw":
			return amount * float(weights.get("cards_drawn", 0.0))
		"energy":
			# Energy gained is the opposite of energy left over, and the sign of
			# `energy_left` says which way the doctrine leans on holding it.
			return amount * absf(float(weights.get("energy_left", 0.2))) * 4.0
		"apply_status":
			var stacks := _amount(effect.get("stacks", 1))
			var status := String(effect.get("status", ""))
			var group := "hero_status" if String(effect.get("target", "")) == "self" else "enemy_status"
			var table: Dictionary = weights.get(group, {})
			return stacks * float(table.get(status, 1.0)) * (spread if group == "enemy_status" else 1.0)
		"coin":
			# Coin is a run resource, not a fight one, so no doctrine has an
			# opinion about it. A flat, small, doctrine-blind number.
			return amount * 0.25
		"add_card", "exhaust_self":
			# Both are shape rather than output; `ai_value` is where the
			# designer says whether the shape is good.
			return 0.0
	return 0.0


static func _amount(value: Variant) -> float:
	if value is float or value is int:
		return float(value)
	# "x" -- an X-cost card's size, unknowable here and priced to match the
	# energy it is assumed to cost.
	return X_COST
