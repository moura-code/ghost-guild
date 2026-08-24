extends SceneTree
## Boots the real main scene, lets it settle, and writes a PNG of the
## viewport. This is how the look gets checked at all -- everything else in
## the project is verified by assertion, and layout cannot be.
##
##   godot --path . -s tools/screenshot.gd -- <out.png> [frames] [screen]
##
## `screen` is a tab id (ladder, guild, seance, hero) or "fight" to descend
## into one, so any screen can be captured without a human clicking to it.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 30
	var screen: String = args[2] if args.size() > 2 else "ladder"

	# A save left over from the last capture puts the game mid-run, so a tab
	# shot comes back showing whatever floor that run was on.
	DirAccess.remove_absolute(SaveGame.DEFAULT_PATH)

	var packed: PackedScene = load("res://game/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)

	for i in frames:
		await process_frame

	# The "while you were away" modal covers whatever we came to look at.
	if screen != "offline" and main._offline != null:
		main._offline.visible = false

	_go(main, screen)
	for i in frames:
		await process_frame

	var image := root.get_texture().get_image()
	var err := image.save_png(out)
	print("screenshot %s -> %s (%dx%d) err=%d" % [screen, out, image.get_width(), image.get_height(), err])
	quit(0 if err == OK else 1)


func _go(main: Node, screen: String) -> void:
	var game = main.game
	if screen == "fight":
		var run = game.start_run(1)
		TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat", "shambler"]}])
		RunEngine.apply(run, {"kind": "enter"})
		main._refresh_run_visibility()
	elif screen == "exit":
		var run = game.start_run(1)
		run.floor = 3
		TestFixtures.set_nodes(run, [{"kind": "rest"}])
		RunEngine.apply(run, {"kind": "enter"})
		RunEngine.apply(run, {"kind": "rest_heal"})
		main._refresh_run_visibility()
	elif screen == "map":
		game.start_run(1)
		main._refresh_run_visibility()
	elif screen == "epitaph":
		var result = TestFixtures.die_on_floor(game.campaign, 3, 1000)
		main._epitaph.paced = false
		main._on_run_finished(result)
	elif screen == "reward":
		var run = game.start_run(1)
		TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
		RunEngine.apply(run, {"kind": "enter"})
		TestFixtures.autofight(run)
		main._refresh_run_visibility()
	elif screen == "shop":
		var run = game.start_run(1)
		run.coin = 400
		TestFixtures.set_nodes(run, [{"kind": "shop"}])
		RunEngine.apply(run, {"kind": "enter"})
		main._refresh_run_visibility()
	elif screen == "event":
		var run = game.start_run(1)
		TestFixtures.set_nodes(run, [{"kind": "event", "event": "whispering_well"}])
		RunEngine.apply(run, {"kind": "enter"})
		main._refresh_run_visibility()
	elif screen == "offline":
		main._offline.bind(game.content, {"elapsed": 30000, "counted": 28800, "capped": true, "soul": 4210.0})
		main._offline.visible = true
	elif screen != "ladder":
		# A rich campaign makes the guild and seance worth looking at: an
		# empty ladder and no Soul shows nothing about how they compose.
		game.campaign.soul = 2400.0
		TestFixtures.end_at_exit(game.campaign, 4, "watch", 1000)
		TestFixtures.die_on_floor(game.campaign, 6, 2000)
		game.campaign.soul = 2400.0
		game.campaign.hero.hp = 38
		main.show_tab(screen)
