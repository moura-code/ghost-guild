class_name Legends
extends RefCounted
## The prestige arithmetic (spec §6.1, §4.4).
##
## Everything here is pure and total, and the first property is the one the
## rest of the codebase is built on: **a guild with no Legends has a blessing
## of exactly 1.0**, so every number in the game is byte-identical to what it
## was until the player asks for a prestige. Prestige is the one feature that
## multiplies everything, which makes it the one that most needs to be an
## identity at zero.


## The floor a true ghost has to be standing on before the guild may prestige.
## Spec §6.1: 15, then 30, then 45 -- so the first one lands within the first
## few hours and each one after is a real climb.
static func threshold(content: Content, legends_owned: int) -> int:
	var step := int(content.balance.get("legend_threshold_step", 15))
	return step * (legends_owned + 1)


## Everything the ladder is worth, merged. True ghosts, expedition ghosts and
## echoes alike (§6.1): a prestige that left echoes standing would let a player
## bank them across cycles, which is the one way to make the reset free.
static func mass(ladder: Ladder) -> float:
	var total := 0.0
	for g in ladder.ghosts:
		total += maxf(0.0, (g as Ghost).strength)
	return total


## `1 + k * sqrt(mass / M0)` (§6.1).
##
## The square root is what stops a prestige layer becoming the only thing that
## matters: quadrupling the mass doubles what the Legend adds, so a tenth cycle
## is worth about three times a first rather than a thousand times.
static func multiplier(content: Content, merged_mass: float) -> float:
	if merged_mass <= 0.0:
		return 1.0
	var k := float(content.balance.get("legend_k", 0.5))
	var m0 := maxf(1.0, float(content.balance.get("legend_mass_scale", 400.0)))
	return 1.0 + k * sqrt(merged_mass / m0)


## What every Legend the guild has is worth together. They multiply: two
## Legends worth 1.5 and 1.2 are worth 1.8, not 2.7.
static func blessing(legends: Array) -> float:
	var out := 1.0
	for l in legends:
		out *= maxf(1.0, (l as Legend).multiplier)
	return out


## The archetype the dead actually played: the most common card tag across
## every merged deck. Ties break alphabetically, because this ends up on a
## permanent record and must not depend on dictionary order.
static func dominant_tag(content: Content, ladder: Ladder) -> String:
	var counts: Dictionary = {}
	for g in ladder.ghosts:
		for card in (g as Ghost).deck:
			var def_id := (card as CardInstance).def_id
			if not content.cards.has(def_id):
				continue
			for tag in (content.cards[def_id] as CardDef).tags:
				counts[tag] = int(counts.get(tag, 0)) + 1
	var names: Array = counts.keys()
	names.sort()
	var best := ""
	var most := 0
	for tag in names:
		if int(counts[tag]) > most:
			most = int(counts[tag])
			best = String(tag)
	return best


## Merges a ladder into a Legend. Does not touch the ladder -- see
## `CampaignEngine.prestige`, which owns what is kept and what is reset.
static func forge(content: Content, ladder: Ladder, cycle: int, now: int) -> Legend:
	var l := Legend.new()
	l.cycle = cycle
	l.mass = mass(ladder)
	l.multiplier = multiplier(content, l.mass)
	l.trait_tag = dominant_tag(content, ladder)
	l.created_at = now
	var deepest := 0
	for g in ladder.ghosts:
		var ghost := g as Ghost
		l.epitaphs.append({
			"name": ghost.name,
			"floor": ghost.floor,
			"epitaph": ghost.epitaph(content),
		})
		if ghost.floor > deepest:
			deepest = ghost.floor
			l.name = ghost.name
	return l
