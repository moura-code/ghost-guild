class_name Crawl
extends Node3D
## The scene root, and the only file under game/world/ that talks to
## GameRoot. It reads the run, builds the floor that run is on, puts the
## player in the entry room, and turns "the player walked in here" into a
## RunEngine action. Nothing under it ever writes to RunState (spec §4).

signal floor_built(floor: int)

var game: GameRoot
var layout: FloorLayout
var player: Player
var markers: Array[EncounterMarker] = []
var stairs: EncounterMarker

var _world: Node3D
var _autopilot := RunAutopilot.new()
var _fight_autopilot := Autopilot.new()


## Picks up the autoload only if nobody has claimed this node already. Tests
## assign `game` before adding the crawl to the tree, which is what keeps the
## suite off the real save file -- the autoload boots against
## SaveGame.DEFAULT_PATH.
func _ready() -> void:
	if game != null:
		return
	var autoload := get_node_or_null("/root/Game")
	if autoload is GameRoot:
		bind(autoload as GameRoot)


func bind(g: GameRoot) -> void:
	game = g
	if not g.is_booted:
		var result := g.boot()
		if not bool(result["ok"]):
			push_error("crawl: boot failed: %s" % result["reason"])
			return
	if g.campaign.run == null:
		g.start_run(1)
	_settle_to_node()
	build_floor()


func build_floor() -> void:
	var run := game.campaign.run
	if run == null:
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

	print("crawl: floor %d, %d rooms, %d encounters left" % [run.floor, layout.rooms.size(), markers.size()])
	floor_built.emit(run.floor)


func _on_marker_entered(index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "node":
		return
	game.run_action({"kind": "enter", "index": index})
	# STAGE 2 SCAFFOLDING. Walking into a room puts the run into "fight",
	# "reward", "event", "rest" or "shop", and stage 2 has no screen for any
	# of them, so the autopilot plays them out. Stage 3 replaces this with the
	# fight staged where you are standing; stage 4 with the other rooms.
	_settle_to_node()
	for m in markers:
		var marker: EncounterMarker = m
		if run.is_resolved(marker.index):
			marker.resolve()
	_refresh_stairs()


func _on_stairs_entered(_index: int) -> void:
	var run := game.campaign.run
	if run == null or run.phase != "exit":
		return
	if not RunEngine.can_push(run):
		# STAGE 2 SCAFFOLDING: the bottom of the biome. Stage 4 owns the real
		# exit decision (push / retreat / watch); here it just banks and
		# starts again so the loop can be walked.
		game.run_action({"kind": "retreat"})
		game.finish_run()
		game.start_run(1)
		_settle_to_node()
		build_floor()
		return
	game.run_action({"kind": "push"})
	_settle_to_node()
	build_floor()


## A floor cannot be built while the run is offering descent cards, and stage
## 2 has no draft screen. The autopilot picks, exactly as the demos do.
func _settle_to_node() -> void:
	var run := game.campaign.run
	var guard := 0
	while run != null and not run.is_over() and run.phase != "node" and run.phase != "exit" and guard < 200:
		guard += 1
		if run.phase == "fight":
			_play_fight(run)
			continue
		var action := _autopilot.choose(run)
		if action.is_empty():
			break
		game.run_action(action)


func _play_fight(run: RunState) -> void:
	for action in _fight_autopilot.choose_turn(run.fight):
		if run.phase != "fight":
			break
		game.run_action(action)


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
