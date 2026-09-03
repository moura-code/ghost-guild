class_name Seance
extends RefCounted
## Soul sinks between runs (spec §5.5, §3.2): echoes, Calls, Tend and Mend.
## Every mutator returns {ok, cost, reason}.
##
## Tending is three things that share a name and a price curve. Clearing
## restless is the cheap one and the campaign's first is free. Sharpening a
## card and handing over a relic are the two that make a ghost permanently
## worth more, and both re-price the ghost through `CampaignEngine.strength_for`
## -- which blends the ghost's *measured* record with a fresh simulation, so
## the spec's "measured stats are kept as the baseline and the simulated delta
## is applied" is not a special case here, it is what pricing a ghost has
## always done.


static func echo_count(c: Campaign) -> int:
	var n := 0
	for g in c.ladder.ghosts:
		if g.kind == "echo":
			n += 1
	return n


static func echo_cost(c: Campaign) -> float:
	var b := c.balance()
	return float(b.get("echo_base_cost", 50)) * pow(float(b.get("echo_cost_growth", 1.15)), echo_count(c))


static func call_cost(c: Campaign) -> float:
	return echo_cost(c) * float(c.balance().get("call_cost_factor", 0.25))


static func tend_cost(c: Campaign, ghost: Ghost) -> float:
	if c.onboarding.free_tend_available:
		return 0.0
	return _tend_curve(c.balance(), ghost.floor)


## Sharpening one card. Dearer than clearing restless, because restless is a
## debt and this is an improvement.
static func upgrade_cost(c: Campaign, ghost: Ghost) -> float:
	var b := c.balance()
	return _tend_curve(b, ghost.floor) * float(b.get("tend_upgrade_mult", 2.5))


## Handing a ghost a relic out of the compendium. The dearest of the three:
## a relic fires in every fight the ghost will ever have.
static func relic_cost(c: Campaign, ghost: Ghost) -> float:
	var b := c.balance()
	return _tend_curve(b, ghost.floor) * float(b.get("tend_relic_mult", 6.0))


static func _tend_curve(b: Dictionary, floor: int) -> float:
	return float(b.get("tend_base_cost", 20)) * pow(float(b.get("tend_cost_growth", 1.3)), floor)


static func mend_cost(c: Campaign) -> float:
	var b := c.balance()
	var discount := float(c.modifiers()["mend_discount"])
	return float(b.get("mend_base_cost", 15)) * pow(float(b.get("mend_cost_growth", 1.3)), c.hero.camp) * (1.0 - discount)


static func echo_strength(c: Campaign, source: Ghost, floor: int) -> float:
	# An echo of a ghost fights the way that ghost fights: the rules travel
	# with the copy, or an echo is a different fighter wearing its deck.
	var sim := Strength.simulate(c.content, CampaignEngine.blessed_snapshot(c, source), c.biome_at(floor), floor, hash([c.campaign_seed, "echo", source.id, floor]), c.sim_fights, source.rules)
	var simulated := Strength.from_stats(float(sim["win_rate"]), float(sim["avg_turns"]), c.balance())
	return float(c.balance().get("echo_factor", 0.75)) * minf(source.strength, simulated)


static func create_echo(c: Campaign, source_id: int, floor: int, now: int) -> Dictionary:
	var source := c.ladder.find(source_id)
	var cost := echo_cost(c)
	if source == null or not source.is_true():
		return {"ok": false, "cost": cost, "reason": "source"}
	if floor < 1 or floor > c.ladder.waypoint():
		return {"ok": false, "cost": cost, "reason": "floor"}
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	var echo := source.clone_as_echo(floor, now)
	c.ladder.add(echo)
	echo.strength = echo_strength(c, source, floor)
	CampaignEngine.refresh_rate(c)
	c.emit({"type": "echo_placed", "id": echo.id, "source": source.id, "floor": floor, "strength": echo.strength, "cost": cost})
	return {"ok": true, "cost": cost, "reason": "", "ghost_id": echo.id}


static func call_echo(c: Campaign, echo_id: int, floor: int) -> Dictionary:
	var echo := c.ladder.find(echo_id)
	var cost := call_cost(c)
	if echo == null or echo.kind != "echo":
		return {"ok": false, "cost": cost, "reason": "echo"}
	if floor < 1 or floor > c.ladder.waypoint():
		return {"ok": false, "cost": cost, "reason": "floor"}
	var source := c.ladder.find(echo.source_id)
	if source == null:
		return {"ok": false, "cost": cost, "reason": "source"}
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	echo.floor = floor
	echo.strength = echo_strength(c, source, floor)
	CampaignEngine.refresh_rate(c)
	c.emit({"type": "echo_called", "id": echo.id, "floor": floor, "strength": echo.strength, "cost": cost})
	return {"ok": true, "cost": cost, "reason": ""}


## The card this ghost would sharpen next: the most valuable one it is still
## carrying un-upgraded.
##
## Chosen rather than picked. The interesting decision in tending is *which
## ghost and which of the three tends*, not which of eleven near-identical
## Strikes -- and a picker over a dead hero's deck would be a modal over a
## modal. The guild sharpens the best thing the ghost carries.
static func next_upgrade(c: Campaign, ghost: Ghost) -> CardInstance:
	var weights := PriorityRules.weights_for(Autopilot.default_weights(), ghost.rules, c.content)
	var best: CardInstance = null
	var most := -1.0
	for card in ghost.deck:
		var inst := card as CardInstance
		if inst.upgraded or not c.content.cards.has(inst.def_id):
			continue
		var worth := CardValue.of(c.content.cards[inst.def_id], weights, false)
		if worth > most:
			most = worth
			best = inst
	return best


## The relic this ghost would be handed next: the first one in the compendium
## it is not already carrying. Ordered by the compendium itself, which is the
## order the guild found them in.
static func next_relic(c: Campaign, ghost: Ghost) -> String:
	for relic in c.compendium:
		var id := String(relic)
		if c.content.relics.has(id) and not ghost.relics.has(id):
			return id
	return ""


## Sharpens the best card the ghost still carries un-upgraded (§5.5).
static func tend_upgrade(c: Campaign, ghost_id: int) -> Dictionary:
	var ghost := c.ladder.find(ghost_id)
	if ghost == null or not ghost.is_true():
		return {"ok": false, "cost": 0.0, "reason": "ghost"}
	var card := next_upgrade(c, ghost)
	if card == null:
		return {"ok": false, "cost": 0.0, "reason": "nothing_left"}
	var cost := upgrade_cost(c, ghost)
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	card.upgraded = true
	_reprice(c, ghost)
	c.emit({"type": "ghost_upgraded", "id": ghost.id, "card": card.def_id, "cost": cost})
	return {"ok": true, "cost": cost, "reason": "", "card": card.def_id}


## Hands the ghost a relic out of the compendium (§5.5).
static func tend_relic(c: Campaign, ghost_id: int) -> Dictionary:
	var ghost := c.ladder.find(ghost_id)
	if ghost == null or not ghost.is_true():
		return {"ok": false, "cost": 0.0, "reason": "ghost"}
	var relic := next_relic(c, ghost)
	if relic == "":
		return {"ok": false, "cost": 0.0, "reason": "nothing_left"}
	var cost := relic_cost(c, ghost)
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	ghost.relics.append(relic)
	_reprice(c, ghost)
	c.emit({"type": "ghost_relic", "id": ghost.id, "relic": relic, "cost": cost})
	return {"ok": true, "cost": cost, "reason": "", "relic": relic}


## Re-prices a ghost after its deck or its relics changed, and every echo of
## it with it. An echo is a copy of its source's *strength*, so a source that
## got better and echoes that did not would be the one place in the economy
## where a copy silently stops being a copy.
static func _reprice(c: Campaign, ghost: Ghost) -> void:
	# A tended ghost stops being priced by whatever it was priced by once.
	# The Founder is a flat number out of balance.json and an expedition ghost
	# was priced the hour it launched; sharpening either of them would take
	# the Soul and change nothing at all, which is the worst kind of bug --
	# the player is told it worked.
	ghost.fixed_strength = false
	ghost.strength = CampaignEngine.strength_for(c, ghost)
	for g in c.ladder.ghosts:
		var echo := g as Ghost
		if echo.kind == "echo" and echo.source_id == ghost.id:
			echo.deck = []
			for card in ghost.deck:
				echo.deck.append((card as CardInstance).clone())
			echo.relics = ghost.relics.duplicate()
			echo.strength = echo_strength(c, ghost, echo.floor)
	CampaignEngine.refresh_rate(c)


static func tend(c: Campaign, ghost_id: int) -> Dictionary:
	var ghost := c.ladder.find(ghost_id)
	if ghost == null or not ghost.is_true():
		return {"ok": false, "cost": 0.0, "reason": "ghost"}
	if not ghost.restless:
		return {"ok": false, "cost": 0.0, "reason": "not_restless"}
	var cost := tend_cost(c, ghost)
	if cost > 0.0 and not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	if cost == 0.0:
		c.onboarding.consume_free_tend()
	ghost.restless = false
	for g in c.ladder.ghosts:
		if g.kind == "echo" and g.source_id == ghost.id:
			g.restless = false
	CampaignEngine.refresh_rate(c)
	c.emit({"type": "ghost_tended", "id": ghost.id, "cost": cost})
	return {"ok": true, "cost": cost, "reason": ""}


static func mend(c: Campaign) -> Dictionary:
	if c.hero.hp >= c.hero.max_hp:
		return {"ok": false, "cost": 0.0, "reason": "healthy"}
	var cost := mend_cost(c)
	if not c.spend(cost):
		return {"ok": false, "cost": cost, "reason": "soul"}
	c.hero.hp = c.hero.max_hp
	c.emit({"type": "hero_mended", "cost": cost, "hp": c.hero.hp})
	return {"ok": true, "cost": cost, "reason": ""}
