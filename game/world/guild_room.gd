class_name GuildRoom
extends Node3D
## The walkable guild: an upgrade table, a séance circle, the hero's desk, the
## ladder down, and the well you look into to see your dead.
##
## Hand-placed rather than generated. It is one room the player returns to a
## thousand times and it is the shot the store page opens on, so it is
## authored -- a seeded guild would be a different room every time you came
## home, which is the opposite of what a home is for.

## Stations, in the order they are placed. Ids are what Interactable reports
## and what Crawl matches on.
const TABLE := "table"
const CIRCLE := "circle"
const DESK := "desk"
const LADDER := "ladder"
const WELL := "well"

## In cells, like a dungeon floor, so the kit's metres stay the only metres.
const WIDTH := 9
const DEPTH := 9
## The well is a hole in the middle of the floor.
const WELL_CELL := Vector2i(4, 4)

var layout: FloorLayout
var stations: Array[Interactable] = []
var well: WellView

var _by_id: Dictionary = {}


## The guild's floor plan, as the same FloorLayout a dungeon uses -- so the
## same builder, the same kit and the same collision apply, and the guild
## cannot drift into a different physical scale from the crypt below it.
static func plan() -> FloorLayout:
	var l := FloorLayout.create(WIDTH + 2, DEPTH + 2)
	for y in range(1, DEPTH + 1):
		for x in range(1, WIDTH + 1):
			l.set_cell(x, y, FloorLayout.Cell.FLOOR)
	# The well: a hole you can look down and not walk into.
	l.set_cell(WELL_CELL.x, WELL_CELL.y, FloorLayout.Cell.VOID)
	LayoutGenerator.add_walls(l)
	l.rooms = [{"x": 1, "y": 1, "w": WIDTH, "h": DEPTH}]
	l.entry_room = 0
	l.stairs_room = 0
	# Torches on the four walls, so the room is lit in pools like everywhere
	# else rather than evenly like a menu.
	l.torch_anchors = [
		Vector2i(0, 3), Vector2i(0, DEPTH - 1),
		Vector2i(WIDTH + 1, 3), Vector2i(WIDTH + 1, DEPTH - 1),
		Vector2i(3, 0), Vector2i(WIDTH - 1, DEPTH + 1),
	]
	return l


## Where each station stands, in cells. Spread to the four sides so walking
## between them is walking across a room, not turning on the spot.
static func station_cells() -> Dictionary:
	return {
		TABLE: Vector2i(2, 2),
		CIRCLE: Vector2i(WIDTH - 1, 2),
		DESK: Vector2i(2, DEPTH - 1),
		LADDER: Vector2i(WIDTH - 1, DEPTH - 1),
		WELL: WELL_CELL,
	}


static func spawn_cell() -> Vector2i:
	return Vector2i(WIDTH / 2 + 1, DEPTH)


func build(campaign: Campaign) -> void:
	layout = plan()
	DungeonBuilder.build(layout, self)
	add_child(Grade.world_environment_guild())

	var cells := station_cells()
	for id in [TABLE, CIRCLE, DESK, LADDER, WELL]:
		var reach := 2.4 if id == WELL else Interactable.REACH
		var it := Interactable.create(String(id), Kit.cell_to_world(cells[id]), "ui.use.%s" % id, reach)
		add_child(it)
		stations.append(it)
		_by_id[id] = it
		if id != WELL:
			add_child(_plinth(Kit.cell_to_world(cells[id]), String(id)))

	well = WellView.new()
	well.name = "Well"
	well.position = Kit.cell_to_world(WELL_CELL)
	add_child(well)
	well.build(campaign)


func station(id: String) -> Interactable:
	return _by_id.get(id, null)


func spawn_point() -> Vector3:
	return Kit.cell_to_world(spawn_cell())


## Something to stand at. A station that is only a trigger volume is a station
## the player cannot see from across the room, which turns the guild into a
## hunt for invisible hotspots.
func _plinth(at: Vector3, id: String) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 0.9, 1.1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.34, 0.31, 0.28)
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = Color(0.55, 0.72, 0.90)
	m.emission_energy_multiplier = 0.10
	var inst := MeshInstance3D.new()
	inst.name = "Plinth_" + id
	inst.mesh = box
	inst.material_override = m
	inst.position = at + Vector3(0.0, 0.45, 0.0)
	return inst
