extends SceneTree
## Headless demo: one narrated autopilot fight plus a 50-fight summary.
## Usage: godot --headless --path . -s tools/fight_demo.gd -- [enemy_id ...]


func _init() -> void:
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var enemy_ids: Array = []
	for a in args:
		enemy_ids.append(String(a))
	if enemy_ids.is_empty():
		enemy_ids = ["bone_rat", "bone_rat"]
	for id in enemy_ids:
		if not content.enemies.has(id):
			printerr("unknown enemy: " + String(id))
			quit(1)
			return
	var hero := HeroSnapshot.starter(content, "sexton")
	var s := CombatEngine.start_fight(content, hero, enemy_ids, 1, Rng.new(1))
	var ap := Autopilot.new()
	var result := ap.play_fight(s)
	for ev in s.events:
		print(JSON.stringify(ev))
	print("RESULT won=%s turns=%d hp=%d" % [str(result["won"]), int(result["turns"]), int(result["hp"])])
	var stats := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), enemy_ids, 1, 7, 50)
	print("SIM fights=%d win_rate=%.2f avg_turns=%.1f avg_hp_left=%.1f" % [int(stats["fights"]), float(stats["win_rate"]), float(stats["avg_turns"]), float(stats["avg_hp_left"])])
	quit(0)
