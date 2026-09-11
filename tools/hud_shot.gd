extends SceneTree
## Screenshots the REAL game -- the real Crawl, the real HUD, over the real 3D
## room -- in whichever state you ask for. The corridor shot in crawl_shot.gd
## proves the world looks right; this is the only thing that shows what the
## player is actually looking at, which is a different question and the one
## that was never asked.
##
##   godot --path . --rendering-method forward_plus --resolution 1280x720 \
##         -s tools/hud_shot.gd -- <out.png> <mode> [frames] [width height] [ui_scale] [locale]
##
## Modes: walk, minimap, fight, reward, guild, panel, expedition, offline, exit, watch,
## deep, kiln, tier2, tier2fight, creatures, ladder, ladderdeep, seance, hero,
## hexer, hall, title, help, options, ghost, map, death, watch_result, inspector,
## pause, hover, rest, upgrade, shop, event, new_event, hero_crowded, panel_wealthy,
## guild_progressed, guild_prestige,
## room:<preset_id>, roster. Roster additionally takes [entry_floor] [enemy_id ...].
## Other modes accept [reduced|normal] [top|bottom] after locale.
##
## Runs against a throwaway save, so it never touches the player's campaign.

const SAVE := "user://saves/_hud_shot.json"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://hud.png"
	var mode: String = String(args[1]) if args.size() > 1 else "walk"
	var frames := int(args[2]) if args.size() > 2 and String(args[2]).is_valid_int() else 30

	await process_frame
	var win := SubViewport.new()
	win.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(win)
	win.size = Vector2i(int(args[3]), int(args[4])) if args.size() > 4 else Vector2i(1280, 720)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	_clear_save()

	var game := GameRoot.new()
	game.clock = func() -> int: return 1720000042
	game.save_path = SAVE
	game.autosave_seconds = 0.0
	win.add_child(game)

	var crawl := Crawl.new()
	crawl.set_meta("shot_mode", mode)
	if mode == "roster":
		crawl.set_meta("shot_cast", Array(args.slice(8)))
	crawl.game = game
	crawl.show_title = mode == "title"
	crawl.settings_path = SAVE + ".cfg"
	var shot_settings := Settings.new()
	shot_settings.ui_scale = float(args[5]) if args.size() > 5 else 1.0
	shot_settings.locale = String(args[6]) if args.size() > 6 else "en"
	shot_settings.minimap = mode == "minimap"
	shot_settings.reduced_motion = args.size() > 7 and String(args[7]) == "reduced"
	if mode.begins_with("room:"):
		shot_settings.dismissed_lessons = ["combat", "upgrade", "rooms", "ghost"]
	shot_settings.save(crawl.settings_path)
	win.add_child(crawl)
	crawl.bind(game)
	if mode == "roster":
		for enemy_id in args.slice(8):
			if not game.content.enemies.has(enemy_id):
				push_error("Unknown roster enemy: " + enemy_id)
				game.sfx.release()
				quit(1)
				return

	match mode:
		"guild_progressed", "guild_prestige":
			for depth in [4, 14, 24]:
				var ghost := Ghost.from_expedition(game.campaign.hero, depth, 1000)
				ghost.strength = 180
				ghost.fixed_strength = true
				game.campaign.ladder.add(ghost)
			game.campaign.record_depth = 24
			game.campaign.expedition_counter = 7
			if mode == "guild_prestige":
				game.prestige()
			crawl.guild.well.refresh(game.campaign)
			crawl.guild.refresh_history(game.campaign)
		"guild", "title":
			pass
		"offline":
			# A night away that finished an expedition, which is the version
			# of this screen with something on it worth reading.
			var hero := Hero.create(game.content, "sexton", "Halvard", {}, 1)
			game.offline = {"elapsed": 30_000, "counted": 28_800, "capped": true,
				"soul": 1840.0, "returned": [Ghost.from_expedition(hero, 4, 0)]}
			crawl._maybe_show_offline()
			crawl.set_meta("shot_scroll", true)
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
			# Enough closed cycles for the Chronicle to be open, and Ink to spend
			# in it: a locked shelf is not the state worth looking at.
			for extra in range(2, 7):
				var older := Legend.new()
				older.id = extra
				older.cycle = extra
				older.name = "Cycle%d" % extra
				older.multiplier = 1.0 + 0.08 * float(extra)
				older.trait_tag = "poison" if extra % 2 == 0 else "shield"
				game.campaign.legends.append(older)
			game.campaign.ink = 7
			game.campaign.chapters = {"breeding_dark": 1, "depth_seals": 1}
			# The Chronicle is the half of this screen the shot is about, and the
			# Hall above it is four plates tall.
			crawl.set_meta("shot_scroll", true)
			var wall := crawl.guild.station(GuildRoom.HALL)
			wall.enter(crawl.player)
			wall.use()
		"seance":
			# Three of your own on the ladder, one of them restless and the guild
			# holding Soul: the state where every tend on the row is offered.
			for floor in [1, 3, 6]:
				var lost := Hero.create(game.content, "sexton", "Kept%d" % floor, {}, 1)
				var laid := game.campaign.ladder.add(Ghost.from_expedition(lost, floor, 0))
				laid.kind = "true"
				laid.fixed_strength = false
				laid.strength = 60.0 + float(floor) * 12.0
			game.campaign.ladder.ghosts[1].restless = true
			game.campaign.compendium = ["bone_charm", "cracked_hourglass"] as Array[String]
			game.campaign.soul = 6000.0
			game.campaign.record_depth = 8
			var circle := crawl.guild.station(GuildRoom.CIRCLE)
			circle.enter(crawl.player)
			circle.use()
		"hero", "hexer", "hero_crowded":
			# The Deep claimed, so the class row has one open and one taken.
			var deep := Hero.create(game.content, "sexton", "Deepwalker", {}, 1)
			game.campaign.ladder.add(Ghost.from_expedition(deep, 14, 0))
			if mode == "hexer":
				game.choose_class("hexer")
			if mode == "hero_crowded":
				for stat in game.campaign.hero.stats:
					game.campaign.hero.stats[stat] = 9999
				game.campaign.hero.hp = 12345
				game.campaign.hero.max_hp = 30067
				game.campaign.hero.camp = 999
				for card_id in game.content.cards:
					game.campaign.hero.add_card(String(card_id))
				for relic_id in game.content.relics:
					if not game.campaign.hero.relics.has(relic_id):
						game.campaign.hero.relics.append(String(relic_id))
				crawl.set_meta("shot_scroll", true)
			var desk := crawl.guild.station(GuildRoom.DESK)
			desk.enter(crawl.player)
			desk.use()
		"ladder", "ladderdeep":
			# A ghost standing in each biome, so the shaft has all its bands.
			# `ladderdeep` is the same screen past the authored dungeon, where
			# the drawn window has left the surface behind.
			var deep_run := mode == "ladderdeep"
			# Three on one floor in the shallow shot, because a haunting (§5.6) is
			# the one thing on this screen a still frame has to be able to show.
			var standing: Array = [4, 14, 26, 34, 42] if deep_run else [4, 14, 14, 14, 26]
			for floor in standing:
				var walker := Hero.create(game.content, "sexton", "Deep%d" % floor, {}, 1)
				game.campaign.ladder.add(Ghost.from_expedition(walker, floor, 0))
			game.campaign.record_depth = 44 if deep_run else 28
			var well := crawl.guild.station(GuildRoom.WELL)
			well.enter(crawl.player)
			well.use()
			if deep_run:
				(crawl.panel as LadderScreen).select_floor(42)
		"panel", "expedition", "panel_wealthy":
			if mode == "panel_wealthy":
				game.campaign.soul = 987654321
				game.campaign.record_depth = 9876
				for id in ["might", "wit", "focus", "vigor"]:
					game.campaign.upgrades.levels[id] = 99
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
		"help":
			crawl.help.build(game.content, true, true)
			crawl.overlay(crawl.help)
		"options":
			crawl._open_options()
		"ghost":
			crawl.inspect_ghost(game.campaign.ladder.ghosts[0].id)
		"rest", "upgrade", "shop", "event", "new_event":
			_descend(game, crawl)
			var run := game.campaign.run
			run.nodes = [{"kind": "rest" if mode == "upgrade" else ("event" if mode == "new_event" else mode), "event": "silent_bell" if mode == "new_event" else "whispering_well"}]
			run.node_index = 0
			run.phase = "node"
			run.hero.hp -= 7
			run.coin = 25
			_snapshot_layout(run)
			crawl.build_floor()
			game.run_action({"kind": "enter", "index": 0})
			await process_frame
			await process_frame
			if mode == "upgrade":
				crawl.choice.select_action({"kind": "rest_upgrade", "uid": run.hero.deck[0].uid})
		"map":
			_descend(game, crawl, 31)
			crawl.floor_map.bind(crawl.layout, game.campaign.run, crawl.player.global_position, crawl.player.rotation.y)
			crawl.overlay(crawl.floor_map)
		"death":
			_descend(game, crawl)
			await _pick_a_fight(game, crawl)
			crawl.director.fight().hero_hp = 1
			crawl.director.end_turn()
		"exit", "watch", "watch_result":
			_descend(game, crawl)
			await _to_the_exit(game, crawl)
			if mode == "watch_result":
				game.run_action({"kind": "watch"})
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
			if mode == "roster" and args.size() > 7:
				entry = int(args[7])
			if mode == "deep":
				entry = 11
			elif mode == "kiln":
				entry = 24
			elif mode == "tier2" or mode == "tier2fight":
				entry = Biomes.depth(game.content) + 4
			if mode.begins_with("room:"):
				var recipe: Dictionary = game.content.room_presets[mode.trim_prefix("room:")]
				entry = 11 if recipe["biome"] == "fungal_deep" else (21 if recipe["biome"] == "the_kiln" else 1)
			_descend(game, crawl, entry)
			if mode.begins_with("room:"):
				var id := mode.trim_prefix("room:")
				var recipe: Dictionary = game.content.room_presets[id]
				var run := game.campaign.run
				run.nodes = [{"kind": recipe["roles"][0], "enemies": ["bone_rat"], "required": true, "event": "whispering_well"}]
				run.phase = "node"
				var layout := LayoutGenerator.generate_current(run.nodes, Rng.new(701))
				layout.presets = ["neutral", "neutral", "neutral"]
				layout.presets[layout.room_of_node(0)] = id
				layout.preset_recipes = RoomPresets.freeze(game.content, layout.presets)
				run.layout_snapshot = layout.to_dict()
				crawl.build_floor()
				for marker in crawl.markers:
					marker.monitoring = false
				var room := layout.room_rect(layout.room_of_node(0))
				var center := Kit.cell_to_world(layout.room_center(layout.room_of_node(0)))
				crawl.player.place_at(center + Vector3(0, 0, room["h"] * Kit.CELL * 0.5 - 2.6), 0)
				crawl.player.camera.rotation.x = -0.03
			if mode in ["fight", "tier2fight", "creatures", "inspector", "pause", "roster", "hover"]:
				await _pick_a_fight(game, crawl)
				if mode == "inspector":
					crawl._inspect_pile("draw")
				elif mode == "pause":
					crawl._open_pause()
				elif mode == "hover":
					crawl.director.hand.hover(2)
			elif mode == "reward":
				await _pick_a_fight(game, crawl)
				TestFixtures_autofight(game.campaign.run)
				if crawl.director != null:
					crawl.director.check_over()

	for _i in frames:
		await process_frame
	if mode != "roster" and args.size() > 8 and String(args[8]) in ["top", "bottom"]:
		crawl.set_meta("shot_scroll", String(args[8]) == "bottom")
	# A scrolling panel has no content height until it has been laid out, so
	# a shot that wants the bottom of one has to ask after the wait, not
	# before it -- `scroll_vertical` is clamped to zero until then.
	if bool(crawl.get_meta("shot_scroll", false)) and crawl.panel != null:
		var sc := (crawl._frames[crawl.panel] as PanelFrame).scroll
		if sc is ScrollContainer:
			(sc as ScrollContainer).scroll_vertical = 100000
		for _j in 6:
			await process_frame
	await process_frame
	if crawl.panel != null:
		var frame: PanelFrame = crawl._frames[crawl.panel]
		var focus := win.gui_get_focus_owner()
		print("panel scroll=%d focus=%s" % [frame.scroll.scroll_vertical, str(focus.get_path()) if focus != null else "none"])
	var err := win.get_texture().get_image().save_png(out)
	print("hud_shot[%s] -> %s err=%d" % [mode, out, err])
	crawl.queue_free()
	if game.sfx != null:
		game.sfx.release()
	game.queue_free()
	await process_frame
	await process_frame
	_clear_save()
	quit(0 if err == OK else 1)


func _clear_save() -> void:
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))


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
	_snapshot_layout(run)
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
	# One of each silhouette when the shot is about the creatures, so the
	# beast, the stack, the wisp and the hulk can be compared in one frame.
	var cast := ["bone_rat", "hollow_knight"]
	if crawl.has_meta("shot_cast"):
		cast = crawl.get_meta("shot_cast")
	if String(crawl.get_meta("shot_mode", "")) == "creatures":
		cast = ["bone_rat", "skull_stack", "grave_wisp", "ossuary_warden"]
	var kind := "fight"
	for id in cast:
		if (game.content.enemies[id] as EnemyDef).kind in ["elite", "boss"]:
			kind = (game.content.enemies[id] as EnemyDef).kind
	run.nodes = [{"kind": kind, "enemies": cast}]
	run.resolved = []
	run.node_index = 0
	run.phase = "node"
	_snapshot_layout(run)
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
	if (crawl.markers[0] as EncounterMarker).deliberate:
		(crawl.markers[0] as EncounterMarker).engage()
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


func _snapshot_layout(run: RunState) -> void:
	var layout := LayoutGenerator.generate_current(run.nodes, run.sub_rng("layout", run.floor))
	layout.presets = RoomPresets.choose(run.content, layout, run.nodes, run.biome().id, run.sub_rng("presets", run.floor))
	layout.preset_recipes = RoomPresets.freeze(run.content, layout.presets)
	run.layout_snapshot = layout.to_dict()
