extends SceneTree
## Local diagnostics, deliberately separate from RunStats and ghost strength.
## godot --headless --path . -s tools/difficulty_report.gd -- out.json [30|100] [development|held_out] [safe|all] [max_floor] [profiles_csv]

const PROFILES := {
	"fresh_sexton": {"class": "sexton", "upgrades": {}, "entry": 1, "blessing": 1.0},
	"early_purchases": {"class": "sexton", "upgrades": {"might": 1, "wit": 1, "vigor": 1}, "entry": 1, "blessing": 1.0},
	"unlocked_hexer": {"class": "hexer", "upgrades": {"might": 1, "wit": 1, "vigor": 1}, "entry": 1, "blessing": 1.0},
	"later_cycle": {"class": "sexton", "upgrades": {"might": 3, "wit": 3, "vigor": 3, "focus": 3}, "entry": 31, "blessing": 1.25},
}
const POLICIES := ["attack_first", "defense_aware", "lookahead"]


func _init() -> void:
	var engine := Engine.get_version_info()
	if engine.major != 4 or engine.minor != 7 or engine.patch != 2:
		push_error("Difficulty comparisons require Godot 4.7.2")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var destination := String(args[0]) if args.size() > 0 else "user://difficulty.json"
	var count := int(args[1]) if args.size() > 1 else 30
	var seed_set := String(args[2]) if args.size() > 2 else "development"
	var route := String(args[3]) if args.size() > 3 else "all"
	var limit := int(args[4]) if args.size() > 4 else 10
	var profiles: Array = Array(String(args[5]).split(",")) if args.size() > 5 else PROFILES.keys()
	if count <= 0 or not seed_set in ["development", "held_out"] or not route in ["safe", "all"] or limit < 1:
		push_error("Invalid difficulty-report arguments")
		quit(1)
		return
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		print(errors)
		quit(1)
		return
	var report := {"engine": Engine.get_version_info()["string"], "seed_set": seed_set,
		"samples_per_profile_policy": count, "optional_policy": route, "profiles": PROFILES,
		"clock": 1000, "max_floor": limit, "rows": [], "summaries": []}
	var terminated := true
	for profile in profiles:
		if not PROFILES.has(profile):
			push_error("Unknown profile: " + str(profile))
			quit(1)
			return
		for policy in POLICIES:
			var rows: Array = []
			for i in count:
				# Disjoint, versioned arithmetic sets; no engine-global RNG.
				var seed_value := (73019 if seed_set == "development" else 970003) + i * 7919
				var row := sample(content, String(profile), String(policy), route, seed_value, limit)
				terminated = terminated and row["terminated"]
				rows.append(row)
				report["rows"].append(row)
			var summary := summarize(rows)
			report["summaries"].append(summary)
			print(JSON.stringify(summary))
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("difficulty_report -> " + destination)
	quit(0 if terminated else 1)


static func sample(content: Content, profile: String, policy: String, route: String, seed_value: int, limit: int) -> Dictionary:
	var definition: Dictionary = PROFILES[profile]
	var upgrades := Upgrades.from_dict({"levels": definition["upgrades"]})
	var hero := Hero.create(content, definition["class"], profile, upgrades.modifiers(content)["stats"])
	var entry := int(definition["entry"])
	var run := RunEngine.start_run(content, hero, entry, seed_value, false, [], float(definition["blessing"]))
	var row := {"profile": profile, "policy": policy, "route": route, "seed": seed_value,
		"upgrades": definition["upgrades"].duplicate(), "starting_hero": hero.to_dict(),
		"starting_hp": hero.hp, "ending_hp": hero.hp, "gross_damage": 0, "blocked": 0,
		"healing": 0, "turns": 0, "enemy_actions": 0, "coin_spent": 0,
		"fights": [], "choices": [], "room_order": [], "floor_exits": [], "outcome": {}}
	var ap := RunAutopilot.new()
	var guard := 0
	while not run.is_over() and guard < 10000:
		guard += 1
		if run.phase == "fight":
			var fight := run.fight
			var before := fight.hero_hp
			var floor_value := run.floor
			var kind := String(run.current_node()["kind"])
			while run.phase == "fight":
				var actions := ap.fight_ap.choose_turn(fight) if policy == "lookahead" else simple_turn(fight, policy)
				for action in actions:
					if run.phase != "fight":
						break
					RunEngine.apply(run, action)
			var measured := fight_metrics(fight)
			measured.merge({"floor": floor_value, "kind": kind, "starting_hp": before,
				"ending_hp": fight.hero_hp, "won": fight.phase == "won", "turns": fight.turn})
			row["fights"].append(measured)
			for key in ["gross_damage", "blocked", "healing", "enemy_actions", "turns"]:
				row[key] += measured[key]
			continue
		var action: Dictionary
		if run.phase == "exit":
			# Existing builds require every node. Later room-aware builds expose
			# optional entries from exit; use only unvisited entries, never re-loop.
			if route in ["all", "safe"]:
				for candidate in RunEngine.legal_actions(run):
					if candidate.get("kind") == "enter" and not run.is_resolved(int(candidate["index"])):
						if route == "safe" and run.nodes[int(candidate["index"])].get("kind") == "elite" and not bool(run.nodes[int(candidate["index"])].get("required", true)):
							continue
						action = candidate
						break
			if action.is_empty():
				row["floor_exits"].append({"floor": run.floor, "hp": hero.hp, "max_hp": hero.max_hp,
					"gross_damage": row["gross_damage"], "healing": row["healing"]})
				action = {"kind": "retreat"} if run.floor >= entry + limit - 1 else {"kind": "push"}
		elif run.phase == "node":
			var options := RunEngine.legal_actions(run)
			for candidate in options:
				var index := int(candidate.get("index", -1))
				if candidate.get("kind") == "enter" and not run.is_resolved(index):
					if route == "safe" and String(run.nodes[index].get("kind", "")) == "elite" and not bool(run.nodes[index].get("required", true)):
						continue
					action = candidate
					break
		else:
			action = ap.choose(run)
		if action.is_empty():
			push_error("Difficulty policy stranded in " + run.phase)
			break
		if action.get("kind") == "enter":
			row["room_order"].append({"floor": run.floor, "index": action.get("index", 0)})
		var events := RunEngine.apply(run, action)
		for event in events:
			if event["type"] == "hero_healed":
				row["healing"] += int(event["amount"])
			if event["type"] == "hero_damaged":
				row["gross_damage"] += int(event["amount"])
			if event["type"] == "shop_buy":
				row["coin_spent"] += int(event["price"])
			if event["type"] in ["reward_taken", "reward_skipped", "event_choice", "shop_buy", "rest", "draft_pick"]:
				row["choices"].append(event.duplicate(true))
	row["ending_hp"] = hero.hp
	row["depth"] = run.floor
	row["outcome"] = run.outcome.duplicate(true)
	row["terminated"] = run.is_over()
	return row


static func fight_metrics(fight: FightState) -> Dictionary:
	var row := {"gross_damage": 0, "blocked": 0, "healing": 0, "enemy_actions": 0}
	for event in fight.events:
		if event["type"] == "damage" and event.get("target") == "hero":
			row["gross_damage"] += int(event["amount"])
			row["blocked"] += int(event.get("blocked", 0))
		elif event["type"] == "heal" and event.get("target") == "hero":
			row["healing"] += int(event["amount"])
		elif event["type"] == "enemy_move":
			row["enemy_actions"] += 1
	return row


## Greedy policies use visible intents and one immediate card effect, no
## sequence search. Both spend spare Energy; defense stops buying excess Block.
static func simple_turn(fight: FightState, policy: String) -> Array:
	var s := fight.clone()
	var out: Array = []
	for _step in 30:
		if s.is_over():
			break
		var chosen := {}
		var best := -INF
		for action in CombatEngine.legal_actions(s):
			if action["kind"] != "play":
				continue
			var card := s.card_def(s.hand[int(action["hand_index"])])
			var score := card.ai_value * 0.01
			if card.type == "attack":
				score += 100.0
			if policy == "defense_aware":
				var next := s.clone()
				CombatEngine.apply(next, action)
				var needed := maxi(0, Autopilot.incoming_damage(s) - s.hero_block)
				var blocked := mini(needed, maxi(0, next.hero_block - s.hero_block))
				score += blocked * 30.0
				if next.all_enemies_dead():
					score += 10000.0
				if action.get("target", -1) >= 0:
					var target := int(action["target"])
					if not next.enemies[target].alive:
						score += 200.0
			if score > best:
				best = score
				chosen = action
		if chosen.is_empty():
			break
		out.append(chosen)
		CombatEngine.apply(s, chosen)
	out.append({"kind": "end_turn"})
	return out


static func distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in sorted:
		sum += float(value)
	return {"n": sorted.size(), "mean": sum / sorted.size(), "p10": sorted[int((sorted.size() - 1) * 0.1)],
		"median": sorted[int((sorted.size() - 1) * 0.5)], "p90": sorted[int((sorted.size() - 1) * 0.9)]}


static func summarize(rows: Array) -> Dictionary:
	var summary := {"profile": rows[0]["profile"], "policy": rows[0]["policy"], "route": rows[0]["route"], "n": rows.size(), "deaths": 0}
	for metric in ["gross_damage", "blocked", "healing", "turns", "enemy_actions", "depth", "coin_spent"]:
		summary[metric] = distribution(rows.map(func(row: Dictionary) -> Variant: return row[metric]))
	var losses: Array = []
	var ordinary_turns: Array = []
	for row in rows:
		if row["outcome"].get("kind") == "death":
			summary["deaths"] += 1
		for floor_exit in row["floor_exits"]:
			if floor_exit["floor"] == 4:
				losses.append(1.0 - float(floor_exit["hp"]) / float(floor_exit["max_hp"]))
				break
		for fight in row["fights"]:
			if fight["kind"] == "fight" and int(fight["floor"]) in [2, 3, 4] and fight["won"]:
				ordinary_turns.append(fight["turns"])
	summary["floor4_exit_net_loss_survivors"] = distribution(losses)
	summary["floor2_4_normal_win_turns"] = distribution(ordinary_turns)
	return summary
