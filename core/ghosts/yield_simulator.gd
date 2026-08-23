class_name YieldSimulator
extends RefCounted
## The exit screen's numbers (spec §3.2): the marginal yield of a prepared
## ghost with this deck here (measured this run, blended with a simulation)
## and the same simulated for the next floor preview the ghost at full HP
## (ghosts fight rested); the survival chance keeps the hero's current HP.


static func strength_here(c: Campaign, run: RunState) -> float:
	var measured := run.stats.measured(run.floor)
	var snap := run.hero_snapshot()
	snap.hp = snap.max_hp
	var sim := Strength.simulate(c.content, snap, c.biome(), run.floor, hash([c.campaign_seed, "yield", c.run_counter, run.floor]), c.sim_fights)
	return Strength.of_ghost_stats(measured, sim, c.balance())


static func strength_at(c: Campaign, run: RunState, floor: int) -> float:
	var snap := run.hero_snapshot()
	snap.hp = snap.max_hp
	var sim := Strength.simulate(c.content, snap, c.biome(), floor, hash([c.campaign_seed, "yield", c.run_counter, floor]), c.sim_fights)
	return Strength.from_stats(float(sim["win_rate"]), float(sim["avg_turns"]), c.balance())


static func exit_numbers(c: Campaign, run: RunState, samples: int = -1) -> Dictionary:
	var out := RunEngine.exit_summary(run, samples)
	var prepared := 1.0 + float(c.balance().get("prepared_bonus", 0.25))
	var mods := c.modifiers()
	var here := strength_here(c, run)
	out["strength_here"] = here
	out["yield_here"] = c.ladder.marginal_yield(run.floor, here * prepared, c.balance(), mods)
	if bool(out["can_push"]):
		var next := strength_at(c, run, run.floor + 1)
		out["strength_next"] = next
		out["yield_next"] = c.ladder.marginal_yield(run.floor + 1, next * prepared, c.balance(), mods)
	else:
		out["strength_next"] = -1.0
		out["yield_next"] = -1.0
	return out
