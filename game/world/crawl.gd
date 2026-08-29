class_name Crawl
extends Node3D
## The scene root, and the only file under game/world/ that talks to
## GameRoot. It reads the run, builds the floor that run is on, puts the
## player in the entry room, and turns "the player walked in here" into a
## RunEngine action. Nothing under it ever writes to RunState (spec §4).
##
## Every phase of a run has a host and nothing resolves behind the player's
## back: a fight is staged in the room, and reward, event, rest, shop and the
## descent draft are panels on the HUD over the room you are standing in. The
## stage 2 autopilot scaffolding is gone.

signal floor_built(floor: int)

var game: GameRoot
var layout: FloorLayout
var player: Player
var hud: HudRoot
var prompts: Prompts
var director: FightDirector
var choice: ChoiceScreen
var exit_panel: ExitScreen
var markers: Array[EncounterMarker] = []
var stairs: EncounterMarker

## True only when this crawl picked up the /root/Game autoload, i.e. it is the
## shipped scene rather than one a test built. Saving on quit is the autoload
## owner's job and nobody else's.
var manages_quit: bool = false
## Injectable so a test can exercise the close path without killing the runner.
var quit_action: Callable = func() -> void: get_tree().quit()

var _world: Node3D
var _built_floor: int = -1


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
	if g.campaign.run == null:
		g.start_run(1)
	if not g.run_changed.is_connected(_sync_phase):
		g.run_changed.connect(_sync_phase)
	_sync_phase()


func _build_hud() -> void:
	if hud != null:
		return
	hud = HudRoot.new()
	hud.name = "Hud"
	add_child(hud)

	prompts = Prompts.new()
	hud.ui.add_child(prompts)

	# Built once and toggled, not rebuilt per phase: a shop refreshes on every
	# purchase, and rebuilding the panel each time would throw away the scroll
	# position along with the node.
	choice = ChoiceScreen.new()
	choice.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice.visible = false
	hud.ui.add_child(choice)

	exit_panel = ExitScreen.new()
	exit_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	exit_panel.visible = false
	exit_panel.decided.connect(_on_exit_decided)
	hud.ui.add_child(exit_panel)

	hud.set_pointer(false)


## The one place that decides what the player is looking at, driven by
## GameRoot.run_changed -- so a panel that applies an action re-hosts itself
## without knowing anything about the world behind it.
func _sync_phase() -> void:
	var run := game.campaign.run
	if run == null:
		return
	if run.is_over():
		# STAGE 4 SCAFFOLDING: the death beat is stage 6 and the guild you
		# return to is stage 5. Until then a finished run banks and a new one
		# starts, so the loop stays walkable.
		game.finish_run()
		game.start_run(1)
		return
	if run.phase == "fight":
		# The director owns the screen and the body while a fight is staged.
		# It is created by _on_marker_entered immediately after the action
		# that put the run in this phase, so there is nothing to do here.
		return
	if ChoiceScreen.handles(run.phase):
		# Includes "descent", which happens before there is a floor to stand
		# in: start_run leaves `nodes` empty until the last offer is taken.
		_open(choice)
		return
	_close_panels()
	if layout == null or _floor_is_stale(run):
		build_floor()
	else:
		_close_room()


## The built world belongs to a different floor than the run is on. Compared
## by floor number rather than by identity because a floor is rebuilt only on
## a descent, and a descent is the only thing that changes it.
func _floor_is_stale(run: RunState) -> bool:
	return _built_floor != run.floor


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

	if player == null:
		player = Player.new()
		player.name = "Player"
		add_child(player)
	player.place_at(_stand_in(layout.entry_room), 0.0)

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

	if prompts != null:
		prompts.announce(game.text("ui.run.floor").replace("{floor}", str(run.floor)))
	print("crawl: floor %d, %d rooms, %d encounters left" % [run.floor, layout.rooms.size(), markers.size()])
	floor_built.emit(run.floor)


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
	_close_panels()
	director = FightDirector.new()
	director.name = "Fight"
	add_child(director)
	director.fight_finished.connect(_on_fight_finished, CONNECT_ONE_SHOT)
	director.begin(game, hud, player, _stand_in(layout.room_of_node(index)))


func _on_fight_finished() -> void:
	if director != null:
		director.queue_free()
		director = null
	_sync_phase()


func _on_stairs_entered(_index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "exit":
		return
	exit_panel.bind(game, run)
	_open(exit_panel)


func _on_exit_decided(kind: String) -> void:
	_close_panels()
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


## A panel takes the screen, the cursor and the body at the same time, so
## "the mouse is free" and "the player cannot walk off mid-choice" can never
## disagree.
func _open(panel: Control) -> void:
	var run := game.campaign.run
	if panel == choice and run != null:
		choice.bind(game, run)
	choice.visible = panel == choice
	exit_panel.visible = panel == exit_panel
	if player != null:
		player.frozen = true
		player.look_enabled = false
	hud.set_pointer(true)


func _close_panels() -> void:
	if choice != null:
		choice.visible = false
	if exit_panel != null:
		exit_panel.visible = false
	if player != null:
		player.frozen = false
		player.look_enabled = true
	if hud != null:
		hud.set_pointer(false)


func panel_open() -> bool:
	return (choice != null and choice.visible) or (exit_panel != null and exit_panel.visible)


## The centre of a room, on the floor. Room centres are always carved, so
## this is always somewhere you can stand.
func _stand_in(room_index: int) -> Vector3:
	return Kit.cell_to_world(layout.room_center(room_index))


func _refresh_stairs() -> void:
	if stairs == null:
		return
	var open := game.campaign.run != null and game.campaign.run.phase == "exit"
	stairs.visible = open
	stairs.monitoring = open
	if prompts != null:
		if open:
			prompts.show_prompt(game.text("ui.exit.push"))
		else:
			prompts.clear_prompt()


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
