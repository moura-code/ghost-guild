extends SceneTree
## Headless campaign demo: a few autopilot runs with the ghost economy
## between them, then a save/load round trip.
## Usage: godot --headless --path . -s tools/campaign_demo.gd -- [seed] [runs]


func _init() -> void:
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var runs := int(args[1]) if args.size() > 1 else 3
	var now := 1000
	var c := CampaignEngine.new_campaign(content, seed_value, now)
	print("campaign seed=%d founder=%s hero=%s rate=%.1f/h" % [seed_value, c.ladder.ghosts[0].name, c.hero.name, c.rate_per_hour])
	for i in runs:
		now += 600
		var entry := CampaignEngine.reach(c)
		var run := CampaignEngine.start_run(c, entry, now)
		var ap := RunAutopilot.new()
		ap.survival_samples = 4
		ap.play_run(run)
		var result := CampaignEngine.finish_run(c, now)
		print("run %d: entry %d -> %s at floor %d, soul +%.1f%s" % [i + 1, entry, String(result["kind"]), int(result["floor"]), float(result["soul"]), (" | " + String(result["epitaph"])) if String(result["epitaph"]) != "" else ""])
		_buy_cheapest(c)
		_echo_if_affordable(c, now)
		_print_ladder(c)
	var path := "user://saves/demo.json"
	var err := SaveGame.save(c, path)
	var back := SaveGame.load_campaign(content, path)
	print("save %s, reload %s, soul %.1f" % [error_string(err), "ok" if back != null and is_equal_approx(back.soul, c.soul) else "FAILED", c.soul])
	quit(0 if err == OK and back != null else 1)


func _buy_cheapest(c: Campaign) -> void:
	var best := ""
	var best_cost := INF
	for id in c.content.upgrades:
		var cost := c.upgrades.cost(c.content, id)
		if cost >= 0.0 and cost < best_cost:
			best_cost = cost
			best = String(id)
	if best != "" and c.soul >= best_cost:
		CampaignEngine.buy_upgrade(c, best)
		print("  bought %s for %.1f" % [best, best_cost])


func _echo_if_affordable(c: Campaign, now: int) -> void:
	var source: Ghost = null
	for g in c.ladder.ghosts:
		if g.kind == "true" and g.cause != "founder" and (source == null or g.strength > source.strength):
			source = g
	if source == null or c.soul < Seance.echo_cost(c):
		return
	var r := Seance.create_echo(c, source.id, c.ladder.waypoint(), now)
	if bool(r["ok"]):
		print("  echo of %s on floor %d for %.1f" % [source.name, c.ladder.waypoint(), float(r["cost"])])


func _print_ladder(c: Campaign) -> void:
	var mods := c.modifiers()
	for f in c.ladder.floors():
		print("  floor %2d: %d ghost(s), %3.0f%% farmed, %.1f soul/h" % [f, c.ladder.on_floor(f).size(), 100.0 * c.ladder.saturation(f, c.balance(), mods), c.ladder.floor_output(f, c.balance(), mods)])
	print("  soul %.1f, rate %.1f/h, reach %d, hero %s (%d/%d hp)" % [c.soul, c.rate_per_hour, CampaignEngine.reach(c), c.hero.name, c.hero.hp, c.hero.max_hp])
