extends SceneTree
## Boots the real main scene, lets it settle, and writes a PNG of the
## viewport. This is how the look gets checked at all -- everything else in
## the project is verified by assertion, and layout cannot be.
##
##   godot --path . -s tools/screenshot.gd -- <out.png> [frames] [screen]
##   godot --path . -s tools/screenshot.gd -- <out_dir> all
##
## `screen` is a tab id (ladder, guild, seance, hero) or a run screen (fight,
## map, exit, ...), so any screen can be captured without a human clicking to
## it. `all` captures every screen in one launch and composes a labelled
## contact sheet, because a visual overhaul is judged by looking at all of it
## at once and twelve process launches is not a loop anyone runs.

## Capture order. `ladder_full` exists because the Ladder is the store page
## and the trailer opening, and the plain `ladder` shot is second-zero state --
## one ghost on floor one. Shooting only that is how the game's signature
## screen ended up being the one screen never seen populated.
const SCREENS := ["ladder", "ladder_full", "guild", "seance", "hero", "offline",
	"map", "fight", "reward", "shop", "event", "exit", "epitaph"]

const SHEET_COLS := 4
const THUMB := Vector2i(300, 169)
const PAD := 10
const LABEL_H := 20


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	var frames := 30
	var screen := "ladder"
	# `<out> [frames] [screen]` in either order after the path: typing a frame
	# count you do not care about just to reach the screen argument is a
	# papercut on the command that gets run most.
	for i in range(1, args.size()):
		var arg := String(args[i])
		if arg.is_valid_int():
			frames = int(arg)
		else:
			screen = arg

	if screen == "all":
		await _capture_all(out, frames)
		return

	var main := await _fresh(screen, frames)
	var err := _shoot(out)
	print("screenshot %s -> %s err=%d" % [screen, out, err])
	main.queue_free()
	quit(0 if err == OK else 1)


## Every screen, one launch. The scene is torn down and rebuilt between
## captures: the setups mutate the campaign -- starting runs, killing heroes --
## so reusing one instance would leak floor 3's corpse into floor 1's shot.
func _capture_all(out_dir: String, frames: int) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var written: Array[String] = []
	var failed := 0
	for screen in SCREENS:
		var main := await _fresh(screen, frames)
		var path := "%s/%s.png" % [out_dir, screen]
		var err := _shoot(path)
		if err == OK:
			written.append(path)
		else:
			failed += 1
			push_error("screenshot: %s failed err=%d" % [screen, err])
		print("  %s -> %s err=%d" % [screen, path, err])
		main.queue_free()
		# queue_free lands at the end of the frame; the next _fresh must not
		# add a second MainScreen while this one is still in the tree.
		await process_frame

	var sheet := "%s/sheet.png" % out_dir
	var sheet_err := await _contact_sheet(written, sheet, frames)
	print("contact sheet -> %s err=%d" % [sheet, sheet_err])
	print("captured %d/%d screens" % [written.size(), SCREENS.size()])
	quit(1 if failed > 0 or sheet_err != OK else 0)


## A clean game, set to `screen`, settled and ready to photograph.
func _fresh(screen: String, frames: int) -> Node:
	# A save left over from the last capture puts the game mid-run, so a tab
	# shot comes back showing whatever floor that run was on.
	DirAccess.remove_absolute(SaveGame.DEFAULT_PATH)
	_reset_game()
	_reset_window()

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
	return main


func _shoot(path: String) -> int:
	var image := root.get_texture().get_image()
	return image.save_png(path)


## `Game` is an autoload, so it outlives the MainScreen that was freed and
## carries its campaign -- and its half-finished run -- into the next capture.
## Un-booting it makes the next bind() load from the (just deleted) save and
## start a clean campaign.
func _reset_game() -> void:
	# Relative, not "/root/Game": an absolute path resolved from the tool's
	# own context is rejected before the main scene is in the tree.
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	game.is_booted = false
	game.campaign = null
	game.offline = {"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0}


func _reset_window() -> void:
	var want := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
		ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	if DisplayServer.window_get_size() != want:
		DisplayServer.window_set_size(want)


## Lays every capture out in a grid with its name under it. Built as a real
## scene and photographed rather than blitted, so the labels use the game's
## own font and the sheet is legible at a glance.
func _contact_sheet(paths: Array[String], out: String, frames: int) -> int:
	if paths.is_empty():
		return FAILED
	for child in root.get_children():
		child.queue_free()
	await process_frame

	var rows := int(ceil(float(paths.size()) / float(SHEET_COLS)))
	var cell := Vector2i(THUMB.x + PAD, THUMB.y + LABEL_H + PAD)
	var window := Vector2i(SHEET_COLS * cell.x + PAD, rows * cell.y + PAD)
	DisplayServer.window_set_size(window)

	var page := ColorRect.new()
	page.color = Color(0.02, 0.02, 0.03)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)

	for i in paths.size():
		var image := Image.new()
		if image.load(paths[i]) != OK:
			continue
		image.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		var at := Vector2(float(PAD + (i % SHEET_COLS) * cell.x),
			float(PAD + (i / SHEET_COLS) * cell.y))

		var thumb := TextureRect.new()
		thumb.texture = ImageTexture.create_from_image(image)
		thumb.position = at
		thumb.size = Vector2(THUMB)
		page.add_child(thumb)

		var label := Label.new()
		label.text = paths[i].get_file().get_basename()
		label.position = at + Vector2(0.0, float(THUMB.y) + 2.0)
		label.size = Vector2(float(THUMB.x), float(LABEL_H))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		page.add_child(label)

	for i in frames:
		await process_frame
	return _shoot(out)


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
		_enrich(game)
		main._offline.bind(game.content, {"elapsed": 30000, "counted": 28800, "capped": true, "soul": 4210.0})
		main._offline.visible = true
	elif screen == "ladder_full":
		_enrich(game)
		main.show_tab("ladder")
	elif screen != "ladder":
		main.show_tab(screen)
		_enrich(game)
		main.show_tab(screen)


## A campaign with dead on it. An empty ladder and no Soul shows nothing
## about how any of these screens compose.
func _enrich(game) -> void:
	game.campaign.soul = 2400.0
	TestFixtures.end_at_exit(game.campaign, 2, "watch", 1000)
	TestFixtures.die_on_floor(game.campaign, 4, 2000)
	TestFixtures.end_at_exit(game.campaign, 5, "watch", 3000)
	TestFixtures.die_on_floor(game.campaign, 6, 4000)
	game.campaign.soul = 2400.0
	game.campaign.hero.hp = 38
