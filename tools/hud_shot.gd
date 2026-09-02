extends SceneTree
## Screenshots the REAL game -- the real Crawl, the real HUD, over the real 3D
## room -- in whichever state you ask for. The corridor shot in crawl_shot.gd
## proves the world looks right; this is the only thing that shows what the
## player is actually looking at, which is a different question and the one
## that was never asked.
##
##   godot --path . --rendering-method forward_plus --resolution 1280x720 \
##         -s tools/hud_shot.gd -- <out.png> <mode> [frames]
##
## Modes: walk, fight, reward, guild, panel, expedition, offline, exit, watch.
##
## Runs against a throwaway save, so it never touches the player's campaign.

const SAVE := "user://saves/_hud_shot.json"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://hud.png"
	var mode: String = String(args[1]) if args.size() > 1 else "walk"
	var frames := int(args[2]) if args.size() > 2 and String(args[2]).is_valid_int() else 30

	await process_frame
	var win := get_root()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(1280, 720)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var game := GameRoot.new()
	game.save_path = SAVE
	game.autosave_seconds = 0.0
	win.add_child(game)

	var crawl := Crawl.new()
	crawl.game = game
	win.add_child(crawl)
	crawl.bind(game)

	match mode:
		"guild":
			pass
		"offline":
			# A night away that finished an expedition, which is the version
			# of this screen with something on it worth reading.
			var hero := Hero.create(game.content, "sexton", "Halvard", {}, 1)
			game.offline = {"elapsed": 30_000, "counted": 28_800, "capped": true,
				"soul": 1840.0, "returned": [Ghost.from_expedition(hero, 4, 0)]}
			crawl._maybe_show_offline()
		"panel", "expedition":
			if mode == "expedition":
				# One slot in the field and one open, which is the state the
				# band spends most of its life in.
				game.campaign.upgrades.levels["expedition"] = 1
				game.campaign.upgrades.levels["expedition_slots"] = 1
				game.campaign.sim_fights = 2
				game.content.balance["expedition_samples"] = 1
				game.content.balance["expedition_sim_fights"] = 2
				game.launch_expedition()
			var station := crawl.guild.station(GuildRoom.TABLE)
			station.enter(crawl.player)
			station.use()
		"exit", "watch":
			_descend(game, crawl)
			await _to_the_exit(game, crawl)
			if mode == "watch":
				# The picker, with a doctrine half chosen, which is the state
				# it spends most of its life in.
				crawl.exit_panel._watch.pressed.emit()
				crawl.exit_panel._picker.toggle("poison_before_blades")
				crawl.exit_panel._picker.toggle("finish_the_wounded")
		_:
			_descend(game, crawl)
			if mode == "fight":
				await _pick_a_fight(game, crawl)
			elif mode == "reward":
				await _pick_a_fight(game, crawl)
				TestFixtures_autofight(game.campaign.run)
				if crawl.director != null:
					crawl.director.check_over()

	for _i in frames:
		await process_frame
	await process_frame
	var err := win.get_texture().get_image().save_png(out)
	print("hud_shot[%s] -> %s err=%d" % [mode, out, err])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()


func _descend(game: GameRoot, crawl: Crawl) -> void:
	game.start_run(1)
	var guard := 0
	while game.campaign.run != null and game.campaign.run.phase == "descent" and guard < 20:
		guard += 1
		crawl.choice.take(0)


## A run parked at a floor exit with the watch already earned, which is the
## only state either of the two exit screens is ever seen in.
func _to_the_exit(game: GameRoot, crawl: Crawl) -> void:
	var run := game.campaign.run
	game.campaign.onboarding.watch_unlocked = true
	run.watch_unlocked = true
	run.floor = 4
	run.nodes = [{"kind": "rest"}]
	run.resolved = []
	run.node_index = 0
	run.phase = "node"
	crawl.build_floor()
	await process_frame
	# Through run_action, not RunEngine: the panel opens on `run_changed`, and
	# applying straight to the engine leaves the run at the exit with nobody
	# having been told.
	game.run_action({"kind": "enter"})
	game.run_action({"kind": "rest_heal"})
	await process_frame
	# The exit screen opens when the player walks into the stairs, not when the
	# phase changes -- so the shot has to walk in.
	crawl._on_stairs_entered(0)
	await process_frame


func _pick_a_fight(game: GameRoot, crawl: Crawl) -> void:
	var run := game.campaign.run
	run.nodes = [{"kind": "fight", "enemies": ["bone_rat", "hollow_knight"]}]
	run.resolved = []
	run.node_index = 0
	run.phase = "node"
	crawl.build_floor()
	await process_frame
	# Stand where the player would be standing: they walk IN, so they are just
	# inside the room's edge, not across the floor in the entry room. Staging
	# from the wrong place is how a shot lies about the composition.
	var room := crawl.layout.room_of_node(0)
	var centre := Kit.cell_to_world(crawl.layout.room_center(room))
	crawl.player.place_at(centre - Vector3(0.0, 0.0, Kit.CELL * 1.4), 0.0)
	await process_frame
	(crawl.markers[0] as EncounterMarker).report(crawl.player)
	await process_frame


## The fight autopilot, inlined -- tools cannot reach tests/helpers.
func TestFixtures_autofight(run: RunState) -> void:
	var ap := Autopilot.new()
	var guard := 0
	while run.phase == "fight" and guard < 200:
		guard += 1
		for action in ap.choose_turn(run.fight):
			if run.phase != "fight":
				break
			RunEngine.apply(run, action)
