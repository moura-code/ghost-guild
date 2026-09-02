class_name Seance
extends RefCounted
## Soul sinks between runs (spec §5.5, §3.2): echoes, Calls, a minimal Tend
## that clears restless, and Mend. Every mutator returns {ok, cost, reason}.


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
	var b := c.balance()
	return float(b.get("tend_base_cost", 20)) * pow(float(b.get("tend_cost_growth", 1.3)), ghost.floor)


static func mend_cost(c: Campaign) -> float:
	var b := c.balance()
	var discount := float(c.modifiers()["mend_discount"])
	return float(b.get("mend_base_cost", 15)) * pow(float(b.get("mend_cost_growth", 1.3)), c.hero.camp) * (1.0 - discount)


static func echo_strength(c: Campaign, source: Ghost, floor: int) -> float:
	# An echo of a ghost fights the way that ghost fights: the rules travel
	# with the copy, or an echo is a different fighter wearing its deck.
	var sim := Strength.simulate(c.content, source.snapshot(), c.biome(), floor, hash([c.campaign_seed, "echo", source.id, floor]), c.sim_fights, source.rules)
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
