class_name WellView
extends Node3D
## The tower of floors, seen down the well in the guild floor.
##
## Spec §8: "Looking down the well shows the tower of floors with your ghosts
## standing on them." This is the Steam capsule shot and the first three
## seconds of the trailer, and it is the one image that explains the game
## without a word -- every ghost you see down there is a hero who died and
## kept working.

## Metres between one floor's ring and the next, going down.
const FLOOR_DROP := 2.6
const RING_RADIUS := 1.15
## How many floors are drawn. Below this the shaft just goes dark, which is
## more honest than a bottom.
const MAX_FLOORS := 20

var rings: Array[Node3D] = []
var figures: Array[GhostFigure] = []

var _depth: int = 0


## The y a floor's ring sits at, relative to the guild's floor. Pure so the
## tower's shape can be checked without building it.
static func floor_y(floor: int) -> float:
	return -FLOOR_DROP * float(maxi(1, floor))


## Where a ghost stands on its ring. Ghosts on the same floor spread around
## the ring instead of standing inside one another.
static func ghost_point(floor: int, slot: int, of: int) -> Vector3:
	var turn := TAU * float(slot) / float(maxi(1, of))
	return Vector3(cos(turn) * RING_RADIUS, floor_y(floor) + 0.1, sin(turn) * RING_RADIUS)


func build(campaign: Campaign) -> void:
	for child in get_children():
		child.queue_free()
	rings.clear()
	figures.clear()
	if campaign == null:
		return
	_depth = clampi(campaign.biome().last_floor, 1, MAX_FLOORS)

	for floor in range(1, _depth + 1):
		var ring := _ring(floor)
		add_child(ring)
		rings.append(ring)
		var on_floor := campaign.ladder.on_floor(floor)
		for slot in on_floor.size():
			var figure := GhostFigure.create(on_floor[slot], ghost_point(floor, slot, on_floor.size()))
			add_child(figure)
			figures.append(figure)

	# A shaft that fades rather than ends. The dark at the bottom is the part
	# of the ladder you have not reached yet.
	var mouth := OmniLight3D.new()
	mouth.name = "Mouth"
	mouth.light_color = Color(0.62, 0.78, 0.95)
	mouth.light_energy = 1.4
	mouth.omni_range = 5.0
	mouth.position = Vector3(0.0, -1.0, 0.0)
	add_child(mouth)


func depth() -> int:
	return _depth


## A ghost deeper than the drawn tower still has to be somewhere. Clamped to
## the bottom ring rather than dropped: a missing ghost is a player wondering
## where their dead went.
static func clamp_floor(floor: int, depth: int) -> int:
	return clampi(floor, 1, maxi(1, depth))


func _ring(floor: int) -> Node3D:
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS
	torus.outer_radius = RING_RADIUS + 0.35
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.28, 0.26)
	m.roughness = 0.95
	var inst := MeshInstance3D.new()
	inst.name = "Ring%d" % floor
	inst.mesh = torus
	inst.material_override = m
	inst.position = Vector3(0.0, floor_y(floor), 0.0)
	return inst
