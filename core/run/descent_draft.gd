class_name DescentDraft
extends RefCounted
## One pick-of-three per skipped floor (spec §3.2), granted once per floor
## per hero: floors already offered to this hero are skipped.


## Which of `cards` a fighter with these `rules` would take (spec §3.2: the
## auto-draft upgrade resolves picks with the hero's priority rules).
##
## Estimated rather than simulated -- see `CardValue`. An expedition hero
## resolves one of these per skipped floor while the game is closed, so a pick
## that costs a fight is a pick that cannot be made.
static func auto_pick(content: Content, cards: Array, rules: Array) -> int:
	return CardValue.best(content, cards, PriorityRules.weights_for(
		Autopilot.default_weights(), rules, content))


## `pools` rather than a biome, because a descent to floor 14 skips floors in
## two of them and because a claimed biome opens its pool everywhere (§5.6).
## The caller knows which; this only deals the cards.
static func offers(content: Content, hero: Hero, pools: Array, entry_floor: int, run_seed: int) -> Array:
	var out: Array = []
	for f in range(1, entry_floor):
		if hero.picks_taken.has(f):
			continue
		var rng := Rng.new(hash([run_seed, "draft", f]))
		var cards := Rewards.card_offer(content, pools, rng, content.balance)
		out.append({"floor": f, "cards": cards.duplicate()})
	return out
