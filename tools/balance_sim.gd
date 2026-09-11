extends SceneTree
## Balance simulator: plays autopilot runs, prints the typical deck's ghost
## yield per floor and the spec §12 invariants. Exit 1 when an asserted
## invariant fails or the content is invalid.
## Usage: godot --headless --path . -s tools/balance_sim.gd -- [runs] [sim_fights]


func _init() -> void:
	var content := Content.load_from("res://data")
	var errors := ContentValidator.validate(content)
	if not errors.is_empty():
		for e in errors:
			printerr(e)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var sim := BalanceSim.new()
	sim.content = content
	sim.runs = int(args[0]) if args.size() > 0 else sim.runs
	sim.sim_fights = int(args[1]) if args.size() > 1 else sim.sim_fights
	var rep := sim.report()
	print("optional rooms: " + String(rep["optional_policy"]))
	var keys: Array = rep["floors"].keys()
	keys.sort()
	print("floor samples strength yield_watch yield_corpse+echo")
	for f in keys:
		var row: Dictionary = rep["floors"][f]
		print("%5d %7d %8.2f %11.2f %17.2f" % [int(f), int(row["samples"]), float(row["strength"]), float(row["yield_watch"]), float(row["yield_corpse_plus_echo"])])
	for r in rep["per_run"]:
		print("run %d: %s at floor %d, soul %.1f" % [int(r["run"]), String(r["kind"]), int(r["death_floor"]), float(r["first_run_soul"])])
	var inv: Dictionary = rep["invariants"]
	for key in inv:
		print("%s: %s — %s" % [key, "OK" if bool(inv[key]["ok"]) else "FAIL", String(inv[key]["detail"])])
	print("note: " + String(rep["retreat_note"]))
	quit(0 if sim.all_ok(rep) else 1)
