extends SceneTree
## Run this script with the preserved 5200eda project, never a personal save.
## godot --headless --path <2d-legacy> -s <this-script> -- <output-directory>

func _init() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	DirAccess.make_dir_recursive_absolute(out)
	var content := Content.load_from("res://data")
	var c := CampaignEngine.new_campaign(content, 73019, 1000)
	c.sim_fights = 2
	c.soul = 1234.5
	c.onboarding.watch_unlocked = true
	c.record_depth = 3
	CampaignEngine.buy_upgrade(c, "vigor")
	_write(c, out, "guild")
	var run := CampaignEngine.start_run(c, 3, 1000)
	_write(c, out, "descent")
	var pilot := RunAutopilot.new()
	while run.phase == "descent":
		RunEngine.apply(run, pilot.choose(run))
	run.nodes = [{"kind": "fight", "enemies": ["bone_rat"]}, {"kind": "event", "event": String(content.events.keys()[0])}, {"kind": "shop"}, {"kind": "rest"}]
	run.node_index = 0
	run.phase = "node"
	_write(c, out, "node")
	RunEngine.apply(run, {"kind": "enter"})
	_write(c, out, "fight")
	while run.phase == "fight":
		for action in pilot.fight_ap.choose_turn(run.fight):
			if run.phase == "fight":
				RunEngine.apply(run, action)
	_write(c, out, "reward")
	RunEngine.apply(run, {"kind": "skip_card"})
	for phase in ["event", "shop", "rest"]:
		RunEngine.apply(run, {"kind": "enter"})
		_write(c, out, phase)
		RunEngine.apply(run, {"kind": "choose", "index": 0} if phase == "event" else {"kind": "leave"} if phase == "shop" else {"kind": "rest_heal"})
	_write(c, out, "exit")
	RunEngine.apply(run, {"kind": "watch"})
	_write(c, out, "ended")
	CampaignEngine.finish_run(c, 1000)
	_write(c, out, "completed")
	quit()


func _write(c: Campaign, out: String, phase: String) -> void:
	var file := FileAccess.open(out.path_join(phase + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(c.to_dict(), "\t"))
	file.close()
	print("legacy fixture: ", phase)
