class_name BalanceSim
extends RefCounted
## The balance simulator (spec §10, §12): plays autopilot runs that always
## push, measures the deck a hero typically has at each floor, and checks
## the M1 invariants — deeper pays, watch beats the corpse, first purchase
## early. Watch vs. corpse+echo is evaluated as marginal yields on a
## Founder-seeded ladder, with the corpse's echo placed on its best floor
## ≤ f (shallower floors assumed no harder than f). Retreat-vs-push is
## reported, not asserted (no EV model in M1).

var content: Content
## Enough samples to be measuring the economy rather than the sampler.
##
## These were 4 and 12, and at those counts `deeper_pays` reported a failure
## for months that was not one: floor 7 came out 1.5% under floor 6 because
## four runs and twelve fights is not enough to price a deck, and the whole
## invariant is a statement about a curve. At 14 and 48 the curve is stable,
## the invariant passes, and the run takes about forty-five seconds -- which
## is the right trade for the one tool in the repo whose job is to be right.
var runs: int = 14
var sim_fights: int = 48
var seed_base: int = 1


static func is_non_decreasing(values: Array) -> bool:
	for i in range(1, values.size()):
		if float(values[i]) < float(values[i - 1]):
			return false
	return true


func sample_runs() -> Dictionary:
	var samples: Array = []
	var per_run: Array = []
	for i in runs:
		var hero := Hero.create(content, Classes.starting(content), "Sim%d" % i)
		var run := RunEngine.start_run(content, hero, 1, hash([seed_base, "balance", i]), true)
		var ap := RunAutopilot.new()
		ap.survival_samples = 1
		var guard := 0
		while not run.is_over() and guard < 10000:
			guard += 1
			if run.phase == "fight":
				for action in ap.fight_ap.choose_turn(run.fight):
					if run.phase != "fight":
						break
					RunEngine.apply(run, action)
			elif run.phase == "exit":
				var optional := ap._next_room(run)
				if not optional.is_empty():
					RunEngine.apply(run, optional)
					continue
				var snap := run.hero_snapshot()
				snap.hp = snap.max_hp
				samples.append({"run": i, "floor": run.floor, "snapshot": snap, "measured": run.stats.measured(run.floor)})
				RunEngine.apply(run, {"kind": "push" if RunEngine.can_push(run) else "watch"})
			else:
				RunEngine.apply(run, ap.choose(run))
		var outcome := run.outcome
		per_run.append({"run": i, "death_floor": int(outcome.get("floor", 0)), "kind": String(outcome.get("kind", "")), "first_run_soul": float(outcome.get("soul", 0.0))})
	return {"samples": samples, "per_run": per_run}


func floor_table(sampled: Dictionary) -> Dictionary:
	var balance := content.balance
	var by_floor := {}
	for s in sampled["samples"]:
		var floor := int(s["floor"])
		var sim := Strength.simulate(content, s["snapshot"], Biomes.for_floor(content, floor), floor, hash([seed_base, "balance_strength", int(s["run"]), floor]), sim_fights)
		var strength := Strength.of_ghost_stats(s["measured"], sim, balance)
		var row: Dictionary = by_floor.get(floor, {"samples": 0, "strength": 0.0})
		row["samples"] = int(row["samples"]) + 1
		row["strength"] = float(row["strength"]) + strength
		by_floor[floor] = row
	var prepared := 1.0 + float(balance.get("prepared_bonus", 0.25))
	var restless := 1.0 - float(balance.get("restless_penalty", 0.3))
	var echo := float(balance.get("echo_factor", 0.75))
	var mods := {"global_strength": 1.0, "global_spawn": 1.0, "restless_penalty": float(balance.get("restless_penalty", 0.3))}
	for floor in by_floor:
		var row: Dictionary = by_floor[floor]
		var s := float(row["strength"]) / int(row["samples"])
		row["strength"] = s
		var f := int(floor)
		var ladder := Ladder.new()
		ladder.add(Ghost.founder(content, 0))
		row["yield_watch"] = ladder.marginal_yield(f, s * prepared, balance, mods)
		var corpse := ladder.marginal_yield(f, s * restless, balance, mods)
		var corpse_ghost := Ghost.new()
		corpse_ghost.floor = f
		corpse_ghost.strength = s * restless
		ladder.add(corpse_ghost)
		var best_echo := 0.0
		for g in range(1, f + 1):
			best_echo = maxf(best_echo, ladder.marginal_yield(g, s * restless * echo, balance, mods))
		row["yield_corpse_plus_echo"] = corpse + best_echo
	return by_floor


func report() -> Dictionary:
	var sampled := sample_runs()
	var floors := floor_table(sampled)
	var keys: Array = floors.keys()
	keys.sort()
	var yields: Array = []
	var watch_ok := true
	var watch_detail := ""
	for f in keys:
		var row: Dictionary = floors[f]
		yields.append(float(row["yield_watch"]))
		var ok := float(row["yield_watch"]) > float(row["yield_corpse_plus_echo"])
		watch_ok = watch_ok and ok
		watch_detail += "f%d watch %.2f vs corpse+echo %.2f%s; " % [int(f), float(row["yield_watch"]), float(row["yield_corpse_plus_echo"]), "" if ok else " FAIL"]
	var deeper_ok := is_non_decreasing(yields)
	var deeper_detail := "prepared yield per floor: " + str(yields) + (" (floors sampled: %s)" % str(keys))
	var founder_rate := Ladder.output_for(float(content.balance.get("founder_strength", 40)), 1, content.balance)
	var first_soul := 0.0
	if not sampled["per_run"].is_empty():
		first_soul = float(sampled["per_run"][0]["first_run_soul"])
	var twenty_minutes := founder_rate / 3.0 + first_soul
	var cheapest := INF
	for id in content.upgrades:
		var def: UpgradeDef = content.upgrades[id]
		cheapest = minf(cheapest, def.base_cost)
	var first_ok := twenty_minutes >= cheapest
	var first_detail := "Soul after 20 min: founder %.1f + first run %.1f = %.1f vs cheapest upgrade %.1f" % [founder_rate / 3.0, first_soul, twenty_minutes, cheapest]
	return {
		"optional_policy": "all (each room once)",
		"floors": floors,
		"per_run": sampled["per_run"],
		"invariants": {
			"deeper_pays": {"ok": deeper_ok, "detail": deeper_detail},
			"watch_beats_corpse": {"ok": watch_ok, "detail": watch_detail},
			"first_purchase_early": {"ok": first_ok, "detail": first_detail},
		},
		"retreat_note": "invariant 3 (retreat costs) is not asserted in M1: it needs an expected-value model of Mend versus pushing that the spec does not define",
	}


func all_ok(rep: Dictionary) -> bool:
	var inv: Dictionary = rep["invariants"]
	for key in inv:
		if not bool(inv[key]["ok"]):
			return false
	return true
