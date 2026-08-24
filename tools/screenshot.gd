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

	var packed: PackedScene = load("res://game/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)

	for i in frames:
		await process_frame

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
	elif screen != "ladder":
		main.show_tab(screen)
