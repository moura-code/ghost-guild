class_name CampaignEngine
extends RefCounted
## Every transition of a Campaign: creation, heroes, runs, production
## ticks and upgrades. Static functions that mutate the campaign in place;
## Seance owns echoes, Calls, Tend and Mend.


static func new_campaign(content: Content, campaign_seed: int, now: int) -> Campaign:
	var c := Campaign.new()
	c.content = content
	c.campaign_seed = campaign_seed
	c.created_at = now
	c.last_tick = now
	c.ladder.add(Ghost.founder(content, now))
	c.onboarding.founder_seeded = true
	new_hero(c, now)
	refresh_rate(c)
	c.emit({"type": "campaign_start", "seed": campaign_seed, "at": now})
	return c


static func new_hero(c: Campaign, now: int) -> Hero:
	c.hero_counter += 1
	var mods := c.modifiers()
	var hero_name := Hero.generate_name(c.sub_rng("names", c.hero_counter))
	var hero := Hero.create(c.content, "sexton", hero_name, mods["stats"], 1 + int(mods["max_resolve_bonus"]))
	hero.id = c.hero_counter
	c.hero = hero
	c.emit({"type": "hero_created", "id": hero.id, "name": hero.name, "at": now})
	return hero


static func reach(c: Campaign) -> int:
	var camp := c.hero.camp if c.hero != null else 0
	return maxi(1, maxi(c.ladder.waypoint(), maxi(camp, c.record_depth)))


static func start_run(c: Campaign, entry_floor: int, now: int) -> RunState:
	if c.run != null:
		if not c.run.is_over():
			push_error("start_run: a run is already in progress")
			return c.run
		push_error("start_run: the previous run has not been banked; call finish_run first")
		return null
	var deepest := mini(reach(c), Biomes.depth(c.content))
	if entry_floor < 1 or entry_floor > deepest:
		push_error("start_run: entry floor %d outside 1..%d" % [entry_floor, deepest])
		return null
	tick(c, now)
	c.run_counter += 1
	var run_seed := hash([c.campaign_seed, "run", c.run_counter])
	c.run = RunEngine.start_run(c.content, c.hero, entry_floor, run_seed,
		c.onboarding.watch_unlocked, Biomes.claimed_pools(c.content, c.ladder))
	c.emit({"type": "run_started", "run": c.run_counter, "entry_floor": entry_floor, "seed": run_seed, "at": now})
	return c.run


static func finish_run(c: Campaign, now: int) -> Dictionary:
	if c.run == null or not c.run.is_over():
		push_error("finish_run: no finished run")
		return {}
	tick(c, now)
	var outcome := c.run.outcome
	var kind := String(outcome.get("kind", "death"))
	var floor := int(outcome.get("floor", 1))
	var soul := float(outcome.get("soul", 0.0))
	c.soul += soul
	c.emit({"type": "soul_banked", "amount": soul, "total": c.soul})
	var cleared := floor - 1 if kind == "death" else floor
	c.record_depth = maxi(c.record_depth, cleared)
	var result := {"kind": kind, "floor": floor, "soul": soul, "ghost_id": 0, "epitaph": "", "new_hero": false, "rite_events": []}
	if kind == "death" or kind == "watch":
		var ghost := Ghost.from_run(c.hero, outcome, c.run.stats.measured(floor), now)
		c.ladder.add(ghost)
		ghost.strength = strength_for(c, ghost)
		result["ghost_id"] = ghost.id
		result["epitaph"] = ghost.epitaph(c.content)
		c.emit({"type": "ghost_placed", "id": ghost.id, "floor": ghost.floor, "strength": ghost.strength, "epitaph": result["epitaph"], "cause": ghost.cause})
		var rite := c.onboarding.on_run_end(outcome)
		for ev in rite:
			c.emit(ev.duplicate())
		result["rite_events"] = rite
		new_hero(c, now)
		result["new_hero"] = true
	c.run = null
	refresh_rate(c)
	c.emit({"type": "run_finished", "kind": kind, "floor": floor, "soul": soul, "at": now})
	return result


static func strength_for(c: Campaign, ghost: Ghost) -> float:
	if ghost.fixed_strength:
		return ghost.strength
	var sim := Strength.simulate(c.content, ghost.snapshot(), c.biome_at(ghost.floor), ghost.floor, hash([c.campaign_seed, "strength", ghost.id]), c.sim_fights, ghost.rules)
	return Strength.of_ghost_stats(ghost.measured, sim, c.balance())


static func refresh_rate(c: Campaign) -> void:
	c.rate_per_hour = Production.rate_per_hour(c.ladder, c.balance(), c.modifiers())


## Enough for a week of the fastest expeditions. A guard, not a limit:
## expeditions do not relaunch themselves, so the loop is bounded by how many
## are in flight, and this only catches a corrupted save.
const MAX_SEGMENTS := 512


## Production up to `now`, in segments.
##
## `Production.accrue` integrates ONE rate across a window. An expedition that
## landed three hours into an eight-hour absence changed the rate three hours
## in, so a single call underpays every offline session that resolved one --
## silently, by exactly what the new ghost would have earned. The window is
## therefore cut at every expedition that lands inside it: accrue, place the
## ghost, refresh the rate, continue.
##
## Two things the cap does NOT do, both deliberate:
##
## - It does not stop an expedition landing. The cap limits what the ladder
##   PAYS for an absence, not what happened during it; a player returning after
##   a week to find their expedition still in the field would be right to call
##   that a bug.
## - It is not applied per segment. A budget of `min(elapsed, cap)` seconds is
##   spent across the segments in order, so cutting a window into more pieces
##   can never pay more than leaving it whole -- which is exactly what a
##   per-segment cap would do.
static func tick(c: Campaign, now: int) -> Dictionary:
	var elapsed := maxi(0, now - c.last_tick)
	var cap_seconds := int(round(float(c.modifiers()["offline_cap_hours"]) * 3600.0))
	var budget := mini(elapsed, cap_seconds)
	var total := {"elapsed": elapsed, "counted": 0, "capped": elapsed > budget,
		"soul": 0.0, "returned": []}
	var at := c.last_tick
	var guard := 0
	while guard < MAX_SEGMENTS:
		guard += 1
		var due := Expeditions.next_due(c)
		if due < 0 or due > now or due <= at:
			break
		budget = _accrue_segment(c, due - at, budget, total)
		at = due
		total["returned"].append_array(Expeditions.resolve_due(c, due))
		refresh_rate(c)
	_accrue_segment(c, now - at, budget, total)
	c.last_tick = now
	return total


## Pays for `span` seconds at the current rate, out of `budget`, and returns
## what is left of the budget.
static func _accrue_segment(c: Campaign, span: int, budget: int, total: Dictionary) -> int:
	var counted := clampi(span, 0, budget)
	if counted <= 0:
		return budget
	c.soul += c.rate_per_hour * counted / 3600.0
	total["soul"] = float(total["soul"]) + c.rate_per_hour * counted / 3600.0
	total["counted"] = int(total["counted"]) + counted
	return budget - counted


static func buy_upgrade(c: Campaign, id: String) -> Dictionary:
	var price := c.upgrades.cost(c.content, id)
	if price < 0.0:
		return {"ok": false, "cost": price, "reason": "unavailable"}
	if not c.spend(price):
		return {"ok": false, "cost": price, "reason": "soul"}
	c.upgrades.buy(c.content, id)
	var def: UpgradeDef = c.content.upgrades[id]
	var amount := int(def.effect.get("amount", 0))
	match String(def.effect.get("kind", "")):
		"stat":
			var stat := String(def.effect.get("stat", ""))
			c.hero.stats[stat] = int(c.hero.stats.get(stat, 0)) + amount
			if stat == "vigor":
				c.hero.recompute_max_hp(c.content)
		"max_resolve":
			c.hero.max_resolve += amount
			c.hero.resolve += amount
	refresh_rate(c)
	c.emit({"type": "upgrade_bought", "id": id, "level": c.upgrades.level(id), "cost": price})
	return {"ok": true, "cost": price, "reason": ""}
