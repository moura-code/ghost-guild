class_name EncounterMarker
extends Area3D
## A node's room, as a place you can walk into. Emits the node's index once
## and then waits to be told it is resolved.
##
## This is where the free-movement decision (spec §1.2) meets the pure
## simulation: the player picks the ORDER of the encounters by choosing which
## door to go through, and the only thing that crosses the boundary is an
## integer. The marker never touches RunState -- Crawl turns the index into a
## RunEngine action.

signal entered(index: int)

## Layer 3 of the project's physics layers, as a bit value.
const LAYER_INTERACTABLE := 4
const GLOW := Color(0.42, 0.72, 0.95)

var index: int = -1
var resolved: bool = false
var deliberate: bool = false
var reusable: bool = false
var available: bool = true
var nearby: bool = false
var kind: String = "fight"

var _fired: bool = false


static func create(node_index: int, room: Dictionary) -> EncounterMarker:
	var m := EncounterMarker.new()
	m.name = "Encounter%d" % node_index
	m.index = node_index
	m.collision_layer = LAYER_INTERACTABLE
	m.collision_mask = Player.LAYER_PLAYER
	var w := int(room.get("w", 1))
	var h := int(room.get("h", 1))
	var centre := Kit.cell_to_world(Vector2i(int(room.get("x", 0)) + w / 2, int(room.get("y", 0)) + h / 2))
	m.position = centre

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(w * Kit.CELL - 1.0, Kit.WALL_H, h * Kit.CELL - 1.0)
	shape.shape = box
	shape.position = Vector3(0.0, Kit.WALL_H * 0.5, 0.0)
	m.add_child(shape)

	# Stage 2 stand-in for the enemy that will be standing here in stage 3: a
	# cold light against the warm torches, so an unresolved room reads as
	# occupied from down the corridor.
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = GLOW
	light.light_energy = 1.6
	light.omni_range = Kit.CELL * 2.4
	light.position = Vector3(0.0, 1.2, 0.0)
	m.add_child(light)

	m.body_entered.connect(m.report)
	m.body_exited.connect(func(_body: Node3D) -> void: m.nearby = false)
	return m


## Separate from the signal handler so the suite can exercise it without a
## physics step: an Area3D only reports overlaps on its own schedule, and a
## test that has to wait for one is a test that fails on a slow machine.
func report(_body: Node3D) -> void:
	if not _body is Player:
		return
	nearby = true
	if deliberate or not available or resolved or _fired:
		return
	_fired = true
	entered.emit(index)


func resolve() -> void:
	resolved = true
	monitoring = false
	visible = false


func engage() -> void:
	if nearby and available and (reusable or not resolved):
		entered.emit(index)


func observe(run: RunState) -> void:
	kind = String(run.nodes[index]["kind"])
	deliberate = RoomPresentation.deliberate(kind)
	reusable = kind == "shop"
	resolved = run.is_resolved(index)
	available = run.can_enter(index)
	# Geometry stays present for signs; only automatic entry is switched off.
	monitoring = available
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_color = RoomPresentation.accent(kind)
		glow.light_energy = 0.5 if resolved else 0.9
