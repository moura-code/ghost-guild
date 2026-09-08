extends SceneTree
## Headless demo: one autopilot run, narrated as JSON event lines.
## Usage: godot --headless --path . -s tools/run_demo.gd -- [entry_floor] [seed]


func _init() -> void:
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var entry := int(args[0]) if args.size() > 0 else 1
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var depth := Biomes.depth(content)
	if entry < 1 or entry > depth:
		printerr("entry floor must be 1..%d" % depth)
		quit(1)
		return
	var hero := Hero.create(content, Classes.starting(content), Hero.generate_name(Rng.new(seed_value)))
	var run := RunEngine.start_run(content, hero, entry, seed_value, true)
	var outcome := RunAutopilot.new().play_run(run)
	for ev in run.events:
		print(JSON.stringify(ev))
	print("OUTCOME %s floor=%d killer=%s soul=%.1f coin=%d deck=%d relics=%d hp=%d/%d" % [
		String(outcome["kind"]), int(outcome["floor"]), String(outcome["killer"]), float(outcome["soul"]),
		int(outcome["coin"]), hero.deck.size(), hero.relics.size(), hero.hp, hero.max_hp,
	])
	quit(0)
