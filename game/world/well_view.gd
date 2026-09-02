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
const RING_RADIUS := 0.72
## The tower is a diorama, not a place: twenty floors have to fit down a
## three-metre shaft, so the figures on it are scaled the way a model railway
## scales people. Life-size ghosts fill the well and the depth stops reading.
const FIGURE_SCALE := 0.4
## How many floors are drawn. Below this the shaft just goes dark, which is
## more honest than a bottom.
## A guard against a corrupt content set, not a design limit: the well is as
## deep as the dungeon is, and the dungeon grew from ten floors to thirty over
## three stages. A shaft that stopped at twenty would quietly stop showing the
## ghosts standing in the biome the player just unlocked.
const MAX_FLOORS := 60

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
	_depth = clampi(Biomes.depth(campaign.content), 1, MAX_FLOORS)

	for floor in range(1, _depth + 1):
		var ring := _ring(floor)
		add_child(ring)
		rings.append(ring)
		var on_floor := campaign.ladder.on_floor(floor)
		for slot in on_floor.size():
			var figure := GhostFigure.create(on_floor[slot], ghost_point(floor, slot, on_floor.size()))
			figure.scale = Vector3.ONE * FIGURE_SCALE
			add_child(figure)
			figures.append(figure)

	add_child(_shaft())

	# A shaft that fades rather than ends. The dark at the bottom is the part
	# of the ladder you have not reached yet.
	var mouth := OmniLight3D.new()
	mouth.name = "Mouth"
	mouth.light_color = Color(0.62, 0.78, 0.95)
	# Dim and set low. Bright at the mouth washes the near stone flat and
	# hides the drop; the shaft should be lit by what is standing in it.
	mouth.light_energy = 0.5
	mouth.omni_range = 7.0
	mouth.position = Vector3(0.0, -3.2, 0.0)
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
	torus.outer_radius = RING_RADIUS + 0.16
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.34, 0.32, 0.30)
	m.roughness = 0.95
	var inst := MeshInstance3D.new()
	inst.name = "Ring%d" % floor
	inst.mesh = torus
	inst.material_override = m
	inst.position = Vector3(0.0, floor_y(floor), 0.0)
	return inst


## The walls of the shaft, seen from inside. Without them the hole shows the
## environment's background colour instead of stone, and a well you can see
## the void through is a hole in the level, not a well.
##
## One box with front faces culled rather than four planes: a box is one mesh,
## and the seams four planes leave at the corners are exactly the thing a
## player notices when leaning over an edge.
func _shaft() -> MeshInstance3D:
	var drop := FLOOR_DROP * float(maxi(1, _depth)) + FLOOR_DROP
	var box := BoxMesh.new()
	box.size = Vector3(Kit.CELL, drop, Kit.CELL)
	var m := Kit.wall_material().duplicate()
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	# The shaft is taller than a wall, so it needs its own uv scale or the
	# stone stretches down it. Same TEXEL, different span.
	m.uv1_scale = Vector3(Kit.CELL / Kit.TEXEL, drop / Kit.TEXEL, 1.0)
	var inst := MeshInstance3D.new()
	inst.name = "Shaft"
	inst.mesh = box
	inst.material_override = m
	inst.position = Vector3(0.0, -drop * 0.5, 0.0)
	return inst
