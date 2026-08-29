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
var director: FightDirector
var guild: GuildRoom
var choice: ChoiceScreen
var exit_panel: ExitScreen
var epitaph: EpitaphScreen
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
var _stations: Dictionary = {}
var _mourning: bool = false


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
	if not g.is_booted:
		var result := g.boot()
		if not bool(result["ok"]):
			push_error("crawl: boot failed: %s" % result["reason"])
			return
	_build_hud()
	if not g.run_changed.is_connected(_sync):
		g.run_changed.connect(_sync)
	_sync()
	_maybe_show_offline()


# ---------------------------------------------------------------- the screen

func _build_hud() -> void:
	if hud != null:
		return
	hud = HudRoot.new()
	hud.name = "Hud"
	add_child(hud)

	prompts = Prompts.new()
	hud.ui.add_child(prompts)

	crosshair = Crosshair.new()
	hud.ui.add_child(crosshair)

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

	for id in [GuildRoom.TABLE, GuildRoom.CIRCLE, GuildRoom.DESK, GuildRoom.WELL]:
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
		_:
			return LadderScreen.new()


func _host(screen: Control) -> void:
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	hud.ui.add_child(screen)


## A panel takes the screen, the cursor and the body at the same time, so "the
## mouse is free" and "the player cannot walk off mid-choice" can never
## disagree.
func open(screen: Control) -> void:
	panel = screen
	for child in hud.ui.get_children():
		if child is Control and child != prompts:
			(child as Control).visible = child == screen
	if player != null:
		player.frozen = screen != null
		player.look_enabled = screen == null
	hud.set_pointer(screen != null)
	if crosshair != null:
		# No reticle while a panel owns the cursor: you are pointing at a
		# button, not at the room.
		crosshair.visible = screen == null
	if screen != null:
		prompts.clear_prompt()
		# A floor announcement still fading when a panel opens ends up printed
		# across it.
		prompts.hush()


func close_panel() -> void:
	open(null)
	_refresh_prompt()


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
		place_changed.emit(place)
	if run.phase == "fight":
		# The director owns the screen and the body while a fight is staged.
		# It is created by _on_marker_entered immediately after the action
		# that put the run in this phase, so there is nothing to do here.
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
	DungeonBuilder.build(layout, _world)
	_world.add_child(Grade.world_environment(Grade.depth_of(run.floor, run.biome().last_floor)))
	_place_player(_stand_in(layout.entry_room))

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

	prompts.announce(game.text("ui.run.floor").replace("{floor}", str(run.floor)))
	print("crawl: floor %d, %d rooms, %d encounters left" % [run.floor, layout.rooms.size(), markers.size()])
	floor_built.emit(run.floor)


func _place_ghosts(run: RunState) -> void:
	var here := game.campaign.ladder.on_floor(run.floor)
	for i in mini(here.size(), layout.ghost_anchors.size()):
		var at := Kit.cell_to_world(layout.ghost_anchors[i])
		_world.add_child(GhostFigure.create(here[i], at))


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


func _on_exit_decided(kind: String) -> void:
	close_panel()
	if game.campaign.run == null:
		return
	game.run_action({"kind": kind})


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
	_place_player(guild.spawn_point())
	close_panel()
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

func _place_player(at: Vector3) -> void:
	if player == null:
		player = Player.new()
		player.name = "Player"
		add_child(player)
	player.place_at(at, 0.0)


## The centre of a room, on the floor. Room centres are always carved, so this
## is always somewhere you can stand.
func _stand_in(room_index: int) -> Vector3:
	return Kit.cell_to_world(layout.room_center(room_index))


## The reticle opens on anything you could act on: a station in the guild, a
## room you have not cleared, the stairs once they are open.
func _process(_delta: float) -> void:
	if crosshair == null or not crosshair.visible:
		return
	crosshair.set_target(focused != null or _looking_at_a_door())


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
	# Escape closes a panel before it does anything else. A panel you can only
	# leave by finishing it is a panel that traps the player.
	if event.is_action_pressed("ui_cancel") and panel_open() and _can_close(panel):
		close_panel()


## The guild's panels can be walked away from. A run's panels cannot: leaving
## a reward unchosen would strand the run in a phase with nothing to do.
func _can_close(screen: Control) -> bool:
	return screen != choice and screen != exit_panel and screen != epitaph


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
