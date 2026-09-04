class_name Crawl
extends Node3D
## The scene root, and the only file under game/ that talks to GameRoot.
##
## Two places, one root: the guild when there is no run, the crypt when there
## is. Nothing under it ever writes to RunState -- the one channel is
## GameRoot.run_action (spec §4).
##
## Every phase has a host and nothing resolves behind the player's back: a
## fight is staged in the room, and reward, event, rest, shop, the descent
## draft, the exit decision, the four guild stations and the epitaph are all
## panels on the HUD over whichever place is live.

signal floor_built(floor: int)
signal place_changed(place: int)

enum Place { NONE, GUILD, DUNGEON }

var game: GameRoot
var place: int = Place.NONE
var layout: FloorLayout
var player: Player
var hud: HudRoot
var prompts: Prompts
var crosshair: Crosshair
var compass: Compass
var director: FightDirector
var guild: GuildRoom
var choice: ChoiceScreen
var exit_panel: ExitScreen
## Soul, income and reach, over every screen where any of the three is
## earned, spent or looked at.
##
## It was written for the 2D shell, mounted by the shell, and then the
## pivot rebuilt the shell as a room and left it behind -- so the number
## this whole game is about was not on screen anywhere. You could tell an
## upgrade was unaffordable only by noticing its button was grey.
var wallet: WalletBar
var epitaph: EpitaphScreen
var title: TitleMenu
var pause: PauseMenu
var options: OptionsMenu
var settings: Settings
## Where settings are read from and written to. Overridable for the same
## reason save_path is: a test that writes the real file changes the
## developer's mouse sensitivity.
var settings_path: String = Settings.PATH
## Off for tests, which want the game already running rather than a menu.
var show_title: bool = true
var markers: Array[EncounterMarker] = []
var stairs: EncounterMarker
## The station the player is standing in, or null.
var focused: Interactable
## Whichever panel currently owns the screen, or null.
var panel: Control

## True only when this crawl picked up the /root/Game autoload, i.e. it is the
## shipped scene rather than one a test built. Saving on quit is the autoload
## owner's job and nobody else's.
var manages_quit: bool = false
## Injectable so a test can exercise the close path without killing the runner.
var quit_action: Callable = func() -> void: get_tree().quit()

var _world: Node3D
var _built_floor: int = -1
## The biome the last announced floor was in, so crossing into a new one can
## be announced and walking down inside one cannot.
var _announced_biome: String = ""
var _stations: Dictionary = {}
var _mourning: bool = false
var _had_save: bool = false
var _options_came_from_title: bool = false


## Picks up the autoload only if nobody has claimed this node already. Tests
## assign `game` before adding the crawl to the tree, which is what keeps the
## suite off the real save file -- the autoload boots against
## SaveGame.DEFAULT_PATH.
func _ready() -> void:
	if game != null:
		return
	var autoload := get_node_or_null("/root/Game")
	if autoload is GameRoot:
		manages_quit = true
		get_tree().auto_accept_quit = false
		bind(autoload as GameRoot)


func bind(g: GameRoot) -> void:
	game = g
	# Settings before boot: the language is one of them, and content is
	# loaded once, during boot, in whatever language it is told.
	settings = Settings.load_from(settings_path)
	g.locale = settings.locale
	if not g.is_booted:
		var result := g.boot()
		if not bool(result["ok"]):
			push_error("crawl: boot failed: %s" % result["reason"])
			return
	_had_save = SaveGame.exists(g.save_path)
	_build_hud()
	if not g.run_changed.is_connected(_sync):
		g.run_changed.connect(_sync)
	_sync()
	# After `_sync`, because `_sync` is what builds the player. `apply`
	# guards on null, so calling it before meant sensitivity, invert and
	# field of view were silently thrown away on every launch.
	settings.apply(player)
	if show_title:
		# Built AFTER _sync, so the world behind the title is the world you are
		# about to walk back into rather than an empty frame.
		title.build(g.content, _had_save)
		open(title)
	else:
		_maybe_show_offline()


# ---------------------------------------------------------------- the screen

## How much room the wallet takes at the top, and how far down the panels
## that show it start.
const WALLET_HEIGHT := 30.0


## The screens that show the wallet: the five the guild opens, which are
## the only ones where Soul is earned, spent or looked at. A run's own
## panels do not -- a reward screen with a Soul counter on it is asking the
## player to do arithmetic in the middle of a fight.
static func wants_wallet(screen: Control) -> bool:
	return screen is LadderScreen or screen is GuildScreen \
		or screen is SeanceScreen or screen is HeroScreen or screen is HallScreen


func _build_hud() -> void:
	if hud != null:
		return
	hud = HudRoot.new()
	hud.name = "Hud"
	add_child(hud)

	prompts = Prompts.new()
	hud.ui.add_child(prompts)

	wallet = WalletBar.new()
	wallet.name = "Wallet"
	wallet.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wallet.offset_top = 2.0
	wallet.offset_bottom = WALLET_HEIGHT
	wallet.visible = false
	hud.ui.add_child(wallet)

	crosshair = Crosshair.new()
	hud.ui.add_child(crosshair)

	compass = Compass.new()
	hud.ui.add_child(compass)

	# Built once and toggled, not rebuilt per phase: a shop refreshes on every
	# purchase, and rebuilding the panel each time would throw away the scroll
	# position along with the node.
	choice = ChoiceScreen.new()
	_host(choice)
	exit_panel = ExitScreen.new()
	exit_panel.decided.connect(_on_exit_decided)
	_host(exit_panel)
	epitaph = EpitaphScreen.new()
	epitaph.dismissed.connect(_on_epitaph_dismissed)
	_host(epitaph)

	title = TitleMenu.new()
	title.continued.connect(_leave_title)
	title.started_new.connect(_start_new_guild)
	title.options_requested.connect(_open_options)
	title.quit_requested.connect(_quit)
	_host(title)

	pause = PauseMenu.new()
	pause.resumed.connect(close_panel)
	pause.options_requested.connect(_open_options)
	pause.abandon_requested.connect(_abandon_run)
	pause.quit_requested.connect(_quit)
	_host(pause)

	options = OptionsMenu.new()
	options.closed.connect(_open_pause)
	options.changed.connect(_on_settings_changed)
	_host(options)

	for id in [GuildRoom.TABLE, GuildRoom.CIRCLE, GuildRoom.DESK, GuildRoom.HALL,
			GuildRoom.WELL]:
		var screen := _guild_panel(String(id))
		_stations[id] = screen
		_host(screen)

	hud.set_pointer(false)


## The four guild stations open the four panels that already existed. They are
## kept rather than rewritten: the spec's argument for cards in 2D -- "a card
## rendered in perspective is a card you cannot read" -- is an argument about
## text and choice, and a ladder of twenty ghosts is the same object.
func _guild_panel(id: String) -> Control:
	match id:
		GuildRoom.TABLE:
			return GuildScreen.new()
		GuildRoom.CIRCLE:
			return SeanceScreen.new()
		GuildRoom.DESK:
			return HeroScreen.new()
		GuildRoom.HALL:
			return HallScreen.new()
		_:
			return LadderScreen.new()


func _host(screen: Control) -> void:
	# A screen that centres itself keeps its own rect. The pause menu, the
	# title and the options are authored as small carved cards -- stretching
	# them to the full frame made the first thing the player ever sees a
	# 640x360 stone plate with four buttons along the top of it.
	if not screen.has_meta("keeps_own_rect"):
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Below the wallet, for the screens that show one.
		if wants_wallet(screen):
			screen.offset_top = WALLET_HEIGHT
	screen.visible = false
	hud.ui.add_child(screen)


## A panel takes the screen, the cursor and the body at the same time, so "the
## mouse is free" and "the player cannot walk off mid-choice" can never
## disagree.
func open(screen: Control) -> void:
	panel = screen
	for child in hud.ui.get_children():
		if child is Control and child != prompts and child != wallet:
			(child as Control).visible = child == screen
	if wallet != null:
		wallet.visible = screen != null and wants_wallet(screen)
		if wallet.visible:
			wallet.bind(game)
	if player != null:
		player.frozen = screen != null
		player.look_enabled = screen == null
	hud.set_pointer(screen != null)
	hud.set_dim(screen != null)
	if crosshair != null:
		# No reticle while a panel owns the cursor: you are pointing at a
		# button, not at the room.
		crosshair.visible = screen == null
	if compass != null:
		compass.visible = screen == null
	if screen != null:
		prompts.clear_prompt()
		# A floor announcement still fading when a panel opens ends up printed
		# across it. So does the objective line, which is anchored to the top
		# of the screen and was landing across the exit screen's own title.
		prompts.hush()
		prompts.clear_objective()
		prompts.clear_rule()


func close_panel() -> void:
	open(null)
	_refresh_prompt()
	_refresh_objective()


func panel_open() -> bool:
	return panel != null and is_instance_valid(panel) and panel.visible


# ------------------------------------------------------------------ the loop

## The one place that decides where the player is and what they are looking
## at. Driven by GameRoot.run_changed, so a panel that applies an action
## re-hosts itself without knowing anything about the world behind it.
func _sync() -> void:
	if game.campaign == null or _mourning:
		return
	var run := game.campaign.run
	if run == null:
		_enter_guild()
		return
	if run.is_over():
		_end_run()
		return
	_enter_dungeon(run)


func _enter_dungeon(run: RunState) -> void:
	if place != Place.DUNGEON:
		_leave_guild()
		place = Place.DUNGEON
		_built_floor = -1
		# A new descent names where it is arriving, even when that is the
		# biome the last one ended in.
		_announced_biome = ""
		place_changed.emit(place)
	if run.phase == "fight":
		# The director owns the screen and the body while a fight is staged.
		# It is created by _on_marker_entered immediately after the action
		# that put the run in this phase, so there is nothing to do here.
		return
	# A fight that has ended but is still settling keeps the screen. The run
	# leaves the fight phase on the frame the killing card is played, which
	# is before the blow has been animated; hosting the reward panel here
	# hid the fight HUD and then freed it mid-animation. `fight_finished`
	# calls back into `_sync` when the last event has played.
	if director != null and not director.is_settled():
		return
	if ChoiceScreen.handles(run.phase):
		# Includes "descent", which happens before there is a floor to stand
		# in: start_run leaves `nodes` empty until the last offer is taken.
		choice.bind(game, run)
		open(choice)
		return
	close_panel()
	if layout == null or _built_floor != run.floor:
		build_floor()
	else:
		_close_room()


func build_floor() -> void:
	var run := game.campaign.run
	if run == null or run.nodes.is_empty():
		return
	if _world != null:
		# Renamed before it goes, because queue_free is deferred: for the rest
		# of this frame the old floor is still a child, and add_child would
		# rename the NEW one to dodge the collision, leaving get_node("World")
		# pointing at the floor that is on its way out.
		_world.name = "OldWorld"
		_world.queue_free()
	markers.clear()
	stairs = null

	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	layout = RunEngine.layout_for(run)
	_built_floor = run.floor
	DungeonBuilder.build(layout, _world, run.biome().id)
	_world.add_child(Grade.world_environment(grade_depth(run.content, run.floor), run.biome().id))
	_dress()
	_place_player(_stand_in(layout.entry_room), _open_facing(layout.room_center(layout.entry_room)))

	# Your dead are standing on the floor they died on, in the corridors you
	# walk back down. This is the pivot's first pillar (spec §2.1) and the
	# layout already emits the anchors, so it is nearly free.
	_place_ghosts(run)

	for i in run.nodes.size():
		if run.is_resolved(i):
			continue
		var marker := EncounterMarker.create(i, layout.room_rect(layout.room_of_node(i)))
		marker.entered.connect(_on_marker_entered)
		_world.add_child(marker)
		markers.append(marker)

	stairs = EncounterMarker.create(-1, layout.room_rect(layout.stairs_room))
	stairs.name = "Stairs"
	stairs.entered.connect(_on_stairs_entered)
	_world.add_child(stairs)
	_refresh_stairs()
	_refresh_marks()
	_refresh_objective()

	prompts.announce(floor_banner(run))
	print("crawl: floor %d, %d rooms, %d encounters left" % [run.floor, layout.rooms.size(), markers.size()])
	floor_built.emit(run.floor)


## What the banner says on arriving at this floor.
##
## The biome's name only where it is news: on the first floor of a run and on
## the floor a descent crosses into a different biome. "Floor 4 · The
## Catacombs" nine times in a row is noise, and the one time it matters -- the
## step out of the Catacombs and into the Deep -- would read as more of it.
func floor_banner(run: RunState) -> String:
	var here := run.biome()
	var tier := run.tier()
	# Past the first cycle the biome alone no longer says where you are: the
	# Catacombs at tier 3 and the Catacombs at tier 1 are the same walls and
	# nothing like the same fight. The tier goes on every banner down there.
	if tier > 1:
		_announced_biome = here.id
		return game.text("ui.run.floor_tier") \
			.replace("{floor}", str(run.floor)) \
			.replace("{biome}", game.text(here.name_key)) \
			.replace("{tier}", str(tier))
	if here.id == _announced_biome:
		return game.text("ui.run.floor").replace("{floor}", str(run.floor))
	_announced_biome = here.id
	return game.text("ui.run.floor_biome") \
		.replace("{floor}", str(run.floor)) \
		.replace("{biome}", game.text(here.name_key))


## The rule in force on this floor, spelled out, or "" on the first tier.
##
## Shown as the objective line rather than the banner: the banner fades, and a
## rule you have to play around for ten floors is not an announcement.
func mutation_line(run: RunState) -> String:
	var rule := run.mutation()
	if rule == null:
		return ""
	return game.text("ui.run.mutation") \
		.replace("{name}", game.text(rule.name_key)) \
		.replace("{text}", game.text(rule.text_key))


## How deep the room should look, 0..1.
##
## It cycles with the biomes rather than running off the end (§2). Floor 34 is
## the Catacombs again and the Catacombs are the same walls in every cycle;
## lighting them like the bottom of the Kiln would leave every floor past
## thirty the same colour, and the colour bands are the only thing on screen
## that says which biome you are standing in. What makes a tier different is
## its rule, not its light.
##
## Pure, so the rule can be checked without building a floor.
static func grade_depth(content: Content, floor: int) -> float:
	return Grade.depth_of(Biomes.in_tier(content, floor), Biomes.depth(content))


## Props against the walls. A boxy empty room reads as a prototype however
## good the lighting is.
func _dress() -> void:
	var run := game.campaign.run
	# The entry room's centre is where you spawn, and a stairs room you cannot
	# cross is a floor you cannot leave.
	var keep_clear: Array = [layout.room_center(layout.entry_room), layout.room_center(layout.stairs_room)]
	for entry in Dressing.plan(layout, run.sub_rng("dressing", run.floor), keep_clear):
		var prop := Dressing.spawn(entry)
		if prop != null:
			_world.add_child(prop)


## Your dead stand on the floor they died on. Never in a room that still has
## an encounter in it: the ghost anchors are room centres and so is the fight
## staging, so a ghost would end up standing inside the thing you are fighting.
func _place_ghosts(run: RunState) -> void:
	var taken: Dictionary = {}
	for i in run.nodes.size():
		if not run.is_resolved(i):
			taken[layout.room_of_node(i)] = true
	var free: Array = []
	for anchor in layout.ghost_anchors:
		var cell: Vector2i = anchor
		var busy := false
		for room in taken:
			if layout.room_center(int(room)) == cell:
				busy = true
				break
		if not busy:
			free.append(cell)
	var here := game.campaign.ladder.on_floor(run.floor)
	for i in mini(here.size(), free.size()):
		_world.add_child(GhostFigure.create(here[i], Kit.cell_to_world(free[i])))


func _on_marker_entered(index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "node":
		return
	game.run_action({"kind": "enter", "index": index})
	if run.phase == "fight":
		_stage_fight(index)


## The fight happens where you are standing. The camera does not cut away.
func _stage_fight(index: int) -> void:
	if director != null:
		director.queue_free()
	open(null)
	director = FightDirector.new()
	director.name = "Fight"
	add_child(director)
	director.fight_finished.connect(_on_fight_finished, CONNECT_ONE_SHOT)
	director.begin(game, hud, player, _stand_in(layout.room_of_node(index)))


func _on_fight_finished() -> void:
	if director != null:
		director.queue_free()
		director = null
	_sync()


func _on_stairs_entered(_index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "exit":
		return
	exit_panel.bind(game, run)
	open(exit_panel)


## The panel applied the decision before it told anyone; this only takes the
## panel down.
##
## It used to apply the action a second time. For a watch or a retreat that was
## invisible -- the run was already over and `campaign.run` was already null, so
## the guard caught it -- but pushing to the next floor left the run in phase
## "node" and the second apply reached `push_error("expected enter, got push")`
## on every single descent. One owner per action: the screen that made the
## decision is the one that carries it, because it is also the only one that
## knows what was chosen with it.
func _on_exit_decided(_kind: String) -> void:
	close_panel()


## Marks every node the engine now considers resolved, and re-checks the
## stairs.
func _close_room() -> void:
	var run := game.campaign.run
	if run == null:
		return
	for m in markers:
		var marker: EncounterMarker = m
		if run.is_resolved(marker.index):
			marker.resolve()
	_refresh_stairs()
	_refresh_marks()
	_refresh_objective()


func _refresh_stairs() -> void:
	if stairs == null:
		return
	var open_now := game.campaign.run != null and game.campaign.run.phase == "exit"
	stairs.visible = open_now
	stairs.monitoring = open_now


# ----------------------------------------------------------------- the guild

func _enter_guild() -> void:
	if place == Place.GUILD and guild != null:
		guild.well.build(game.campaign)
		close_panel()
		return
	_leave_dungeon()
	place = Place.GUILD
	guild = GuildRoom.new()
	guild.name = "Guild"
	add_child(guild)
	guild.build(game.campaign)
	for s in guild.stations:
		var station: Interactable = s
		station.focused.connect(_on_station_focused)
		station.blurred.connect(_on_station_blurred)
		station.used.connect(_on_station_used)
	# Facing the well: it is the way down, the pitch image, and the only thing
	# in the room worth looking at first.
	var to_well := Kit.cell_to_world(GuildRoom.WELL_CELL) - guild.spawn_point()
	_place_player(guild.spawn_point(), atan2(-to_well.x, -to_well.z))
	close_panel()
	_refresh_marks()
	prompts.clear_objective()
	place_changed.emit(place)


func _leave_guild() -> void:
	if guild == null:
		return
	guild.queue_free()
	guild = null
	focused = null


func _leave_dungeon() -> void:
	if director != null:
		director.queue_free()
		director = null
	if _world != null:
		_world.name = "OldWorld"
		_world.queue_free()
		_world = null
	markers.clear()
	stairs = null
	layout = null
	_built_floor = -1


## Both guarded against a guild that is on its way out. Descending frees the
## guild, and the Area3D the player was standing in emits body_exited AFTER
## that -- on the frame the player stops overlapping it -- so the handler runs
## with `guild` already null. It happens every single time you take the well
## down, which is why it is worth a guard rather than an assert.
func _on_station_focused(_id: String) -> void:
	_refocus()


func _on_station_blurred(_id: String) -> void:
	_refocus()


func _refocus() -> void:
	focused = null
	if guild != null and is_instance_valid(guild):
		for s in guild.stations:
			if (s as Interactable).focus:
				focused = s
	_refresh_prompt()


func _on_station_used(id: String) -> void:
	var screen: Control = _stations.get(id, null)
	if screen == null:
		return
	if screen.has_method("bind"):
		screen.call("bind", game)
	open(screen)


func _refresh_prompt() -> void:
	if panel_open() or focused == null:
		prompts.clear_prompt()
		return
	prompts.show_prompt(game.text(focused.label_key))


func _maybe_show_offline() -> void:
	if not OfflineSummary.should_show(game.offline):
		return
	var summary := OfflineSummary.new()
	summary.dismissed.connect(close_panel)
	_host(summary)
	summary.bind(game.content, game.offline)
	open(summary)


# ------------------------------------------------------------------- the end

## A run that left a ghost earns the epitaph beat before the guild comes back.
## A retreat does not: nobody was left behind.
func _end_run() -> void:
	_mourning = true
	if director != null:
		director.queue_free()
		director = null
	var result := game.finish_run()
	if EpitaphScreen.should_show(result):
		_raise_the_dead()
		epitaph.bind(game, result)
		open(epitaph)
		return
	_mourning = false
	_enter_guild()


## The hero rises where it fell, and the epitaph fades up over it. This is the
## shot the trailer opens on (spec §8), so it is a sequence with beats and not
## a screen swap: the world stays, the killer stays, and the thing that stands
## up is the ghost you will walk past on the way down next time.
func _raise_the_dead() -> void:
	if _world == null or player == null or game.campaign.ladder.ghosts.is_empty():
		return
	var newest: Ghost = game.campaign.ladder.ghosts[game.campaign.ladder.ghosts.size() - 1]
	var figure := GhostFigure.create(newest, player.global_position)
	_world.add_child(figure)
	figure.rise()


func _on_epitaph_dismissed() -> void:
	_mourning = false
	open(null)
	_enter_guild()


# ------------------------------------------------------------------ plumbing

func _place_player(at: Vector3, yaw: float = 0.0) -> void:
	if player == null:
		player = Player.new()
		player.name = "Player"
		# The body counts its own footfalls; what one sounds like is the
		# HUD-side decision, so the wire is made here rather than in Player.
		if game != null and game.sfx != null:
			player.footfall.connect(game.sfx.step)
		add_child(player)
	player.place_at(at, yaw)


## Which way to face on arrival: down the longest open run from where you are
## standing. Spawning nose-to-the-wall is the first thing the player sees and
## it reads as the game being broken before they have taken a step.
func _open_facing(cell: Vector2i) -> float:
	var best := 0.0
	var best_run := -1
	var steps: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for step in steps:
		var run := 0
		var at := cell + step
		while layout.is_walkable(at.x, at.y) and run < 40:
			run += 1
			at += step
		if run > best_run:
			best_run = run
			# Godot yaw 0 looks down -Z, and +Y turns left.
			best = atan2(float(-step.x), float(-step.y))
	return best


## The centre of a room, on the floor. Room centres are always carved, so this
## is always somewhere you can stand.
func _stand_in(room_index: int) -> Vector3:
	return Kit.cell_to_world(layout.room_center(room_index))


## The reticle opens on anything you could act on: a station in the guild, a
## room you have not cleared, the stairs once they are open.
func _process(_delta: float) -> void:
	if player != null and compass != null and compass.visible:
		compass.look(player.global_position, player.rotation.y)
	if crosshair == null or not crosshair.visible:
		return
	crosshair.set_target(focused != null or _looking_at_a_door())


## What still wants something from you, as compass marks. The stairs only
## appear once they can actually be used: a mark pointing at a locked door is
## a mark that lies.
func _refresh_marks() -> void:
	if compass == null:
		return
	var out: Array = []
	if place == Place.GUILD and guild != null:
		for station in guild.stations:
			out.append({"at": (station as Interactable).position, "kind": "ghost"})
		compass.set_marks(out)
		return
	var run := game.campaign.run
	if run == null or layout == null:
		compass.set_marks([])
		return
	for i in run.nodes.size():
		if not run.is_resolved(i):
			out.append({"at": Kit.cell_to_world(layout.room_center(layout.room_of_node(i))), "kind": "encounter"})
	if run.phase == "exit":
		out.append({"at": Kit.cell_to_world(layout.room_center(layout.stairs_room)), "kind": "stairs"})
	compass.set_marks(out)


## The one line that says what the floor still wants. Without it the compass
## shows marks and never says what they are.
func _refresh_objective() -> void:
	if prompts == null or place != Place.DUNGEON:
		return
	var run := game.campaign.run
	if run == null:
		return
	prompts.show_rule(mutation_line(run))
	if run.phase == "exit":
		prompts.show_objective(game.text("ui.run.stairs_open"))
		return
	var left := 0
	for i in run.nodes.size():
		if not run.is_resolved(i):
			left += 1
	if left <= 0:
		prompts.clear_objective()
	elif left == 1:
		prompts.show_objective(game.text("ui.run.one_room_left"))
	else:
		prompts.show_objective(game.text("ui.run.rooms_left").replace("{n}", str(left)))


func _looking_at_a_door() -> bool:
	if player == null or player.camera == null or place != Place.DUNGEON:
		return false
	var space := get_world_3d().direct_space_state
	var from := player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_transform.basis.z * 6.0)
	query.collision_mask = EncounterMarker.LAYER_INTERACTABLE
	return not space.intersect_ray(query).is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not panel_open() and focused != null:
		focused.use()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	# ONE rule for Escape, because it used to mean three different things
	# depending on who saw the key first: close the topmost thing that can be
	# closed, and if nothing is open, pause.
	if not panel_open():
		_open_pause()
	elif panel == options:
		# Back to whichever menu opened the options, not straight into the room.
		if _options_came_from_title:
			title.build(game.content, _had_save)
			open(title)
		else:
			_open_pause()
	elif _can_close(panel):
		close_panel()


## A run's phase panels cannot be walked away from -- leaving a reward
## unchosen would strand the run in a phase with nothing to do -- but pausing
## over them is always allowed, which is what the pause branch above is for.
func _can_close(screen: Control) -> bool:
	return screen != choice and screen != exit_panel and screen != epitaph and screen != title


## Leaving the title is the moment the game actually begins: the offline
## summary belongs here, not on boot, or it fires behind the menu.
func _leave_title() -> void:
	close_panel()
	_maybe_show_offline()


## A new guild throws the campaign away and starts one. Destructive, so it is
## only reachable from the title -- never from the pause menu, where a
## mis-click would cost a player their whole ladder.
func _start_new_guild() -> void:
	close_panel()
	game.campaign = CampaignEngine.new_campaign(game.content, game.now(), game.now())
	place = Place.NONE
	_leave_dungeon()
	_leave_guild()
	game.save()
	_sync()


func _open_pause() -> void:
	pause.build(game.content, game.campaign != null and game.campaign.run != null)
	open(pause)


func _open_options() -> void:
	_options_came_from_title = panel == title
	options.build(game.content, settings)
	open(options)


func _on_settings_changed(s: Settings) -> void:
	s.apply(player)
	s.save(settings_path)
	# A language change reloads the content underneath everything, so the
	# menu that asked for it has to be rebuilt in the language it asked for.
	if game.content != null and game.content.locale != s.locale:
		if game.set_locale(s.locale):
			options.build(game.content, s)
			prompts.clear_objective()
			prompts.clear_rule()


## Giving up goes through RunEngine like everything else. The engine ends it
## as a retreat from whatever phase you were in, including mid-fight.
func _abandon_run() -> void:
	close_panel()
	var run := game.campaign.run
	if run == null or run.is_over():
		return
	game.run_action({"kind": "abandon"})
	_sync()


func _quit() -> void:
	if game != null and game.is_booted:
		game.save()
		if game.sfx != null:
			game.sfx.release()
	quit_action.call()


## The quit path used to live on MainScreen, which the pivot stopped booting.
## Without this the game does not save when you close the window, and the
## looping ambience is still playing when the tree comes down -- which is what
## the two leaked AudioStream instances at exit were.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not manages_quit:
		return
	if game != null and game.is_booted:
		game.save()
		if game.sfx != null:
			game.sfx.release()
	quit_action.call()
