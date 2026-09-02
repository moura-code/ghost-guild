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
## Modes: walk, fight, reward, guild, panel, expedition, offline, exit, watch,
## deep, kiln, ladder, hero, hall.
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
		"hall":
			# One cycle already merged and the next rite open, which is the
			# state the screen has to be readable in.
			for floor in [6, 15]:
				var fallen := Hero.create(game.content, "sexton", "Fallen%d" % floor, {}, 1)
				var ghost := game.campaign.ladder.add(Ghost.from_expedition(fallen, floor, 0))
				ghost.strength = 180.0
				ghost.fixed_strength = true
			game.campaign.record_depth = 17
			game.prestige()
			for floor in [4, 16]:
				var again := Hero.create(game.content, "sexton", "Walker%d" % floor, {}, 1)
				var g2 := game.campaign.ladder.add(Ghost.from_expedition(again, floor, 0))
				g2.strength = 210.0
				g2.fixed_strength = true
			game.campaign.soul = 3400.0
			var wall := crawl.guild.station(GuildRoom.HALL)
			wall.enter(crawl.player)
			wall.use()
		"hero":
			# The Deep claimed, so the class row has one open and one taken.
			var deep := Hero.create(game.content, "sexton", "Deepwalker", {}, 1)
			game.campaign.ladder.add(Ghost.from_expedition(deep, 14, 0))
			var desk := crawl.guild.station(GuildRoom.DESK)
			desk.enter(crawl.player)
			desk.use()
		"ladder":
			# A ghost standing in each biome, so the shaft has both bands.
			for floor in [4, 14, 26]:
				var walker := Hero.create(game.content, "sexton", "Deep%d" % floor, {}, 1)
				game.campaign.ladder.add(Ghost.from_expedition(walker, floor, 0))
			game.campaign.record_depth = 28
			var well := crawl.guild.station(GuildRoom.WELL)
			well.enter(crawl.player)
			well.use()
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
			# `deep` walks the second biome instead of the first: the whole
			# point of a biome is that you can see which one you are in.
			var entry := 1
			if mode == "deep":
				entry = 11
			elif mode == "kiln":
				entry = 24
			_descend(game, crawl, entry)
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


func _descend(game: GameRoot, crawl: Crawl, entry: int = 1) -> void:
	if entry > 1:
		# Reach is what gates the entry floor, and reach is the deepest ghost.
		game.campaign.record_depth = entry
	game.start_run(entry)
	var guard := 0
	while game.campaign.run != null and game.campaign.run.phase == "descent" and guard < 40:
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
