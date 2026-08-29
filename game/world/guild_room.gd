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
## The well is both the view down and the way down: spec §8 says looking into
## it shows the tower of your dead and walking into it starts the descent.
## They are the same object seen two ways, so it is one station, not two.
const WELL := "well"

## In cells, like a dungeon floor, so the kit's metres stay the only metres.
const WIDTH := 9
const DEPTH := 9
## The well is a hole in the middle of the floor.
const WELL_CELL := Vector2i(4, 4)
## Waist-high, so you lean over it rather than see over it.
const WELL_RIM := 0.85
const WELL_THICK := 0.35

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
	LayoutGenerator.add_walls(l)
	# The well is punched AFTER the wall pass, or add_walls sees a void cell
	# surrounded by floor and fills it in -- which turns the well into a solid
	# pillar in the middle of the room. A hole has to stay a hole.
	l.set_cell(WELL_CELL.x, WELL_CELL.y, FloorLayout.Cell.VOID)
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
		WELL: WELL_CELL,
	}


static func spawn_cell() -> Vector2i:
	return Vector2i(WIDTH / 2 + 1, DEPTH)


func build(campaign: Campaign) -> void:
	layout = plan()
	DungeonBuilder.build(layout, self)
	add_child(Grade.world_environment_guild())

	var cells := station_cells()
	for id in [TABLE, CIRCLE, DESK, WELL]:
		var reach := 2.4 if id == WELL else Interactable.REACH
		var it := Interactable.create(String(id), Kit.cell_to_world(cells[id]), "ui.use.%s" % id, reach)
		add_child(it)
		stations.append(it)
		_by_id[id] = it
		if id != WELL:
			add_child(_plinth(Kit.cell_to_world(cells[id]), String(id)))

	_build_well_head()
	_patch_ceiling_over_the_well()

	well = WellView.new()
	well.name = "Well"
	well.position = Kit.cell_to_world(WELL_CELL)
	add_child(well)
	well.build(campaign)


## A waist-high ring of stone around the hole. It is what makes the well a
## well: you can lean over it and look down, and you cannot walk into it. It
## also does the job the missing floor tile would otherwise leave undone --
## the builder's ground slab runs under the whole room, so without the rim the
## player would stand on invisible collision in mid-air over the shaft.
func _build_well_head() -> void:
	var body := StaticBody3D.new()
	body.name = "WellHead"
	body.collision_layer = DungeonBuilder.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)

	var centre := Kit.cell_to_world(WELL_CELL)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.34, 0.31)
	m.roughness = 0.92
	var half := Kit.CELL * 0.5
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		# A segment runs across the side it sits on: thin along the direction
		# it faces, a full cell wide the other way.
		var size := Vector3(Kit.CELL, WELL_RIM, WELL_THICK) if step.x == 0 else Vector3(WELL_THICK, WELL_RIM, Kit.CELL)
		var at := centre + Vector3(float(step.x) * (half - WELL_THICK * 0.5), WELL_RIM * 0.5, float(step.y) * (half - WELL_THICK * 0.5))

		var box := BoxMesh.new()
		box.size = size
		var inst := MeshInstance3D.new()
		inst.mesh = box
		inst.material_override = m
		inst.position = at
		body.add_child(inst)

		var shape := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		# Full height on the collider even though the stone is waist-high: the
		# rim has to stop a body, and a 0.9 m box is something a character
		# controller will climb given a running start.
		solid.size = Vector3(size.x, Kit.WALL_H, size.z)
		shape.shape = solid
		shape.position = Vector3(at.x, Kit.WALL_H * 0.5, at.z)
		body.add_child(shape)


## The builder gives a ceiling tile to every FLOOR cell, and the well is not
## one, so without this there is a square hole in the ceiling directly above
## the well -- a skylight in a crypt.
func _patch_ceiling_over_the_well() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(Kit.CELL, Kit.CELL)
	var inst := MeshInstance3D.new()
	inst.name = "CeilingPatch"
	inst.mesh = plane
	inst.material_override = Kit.ceiling_material()
	inst.position = Kit.cell_to_world(WELL_CELL) + Vector3(0.0, Kit.WALL_H, 0.0)
	inst.rotation = Vector3(PI, 0.0, 0.0)
	add_child(inst)


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
	m.albedo_color = Color(0.30, 0.26, 0.22)
	m.roughness = 0.9
	# Barely lit, and warm rather than cold: enough to be picked out from
	# across a dark room, not enough to read as a lightbox.
	m.emission_enabled = true
	m.emission = Color(0.90, 0.72, 0.45)
	m.emission_energy_multiplier = 0.045
	var inst := MeshInstance3D.new()
	inst.name = "Plinth_" + id
	inst.mesh = box
	inst.material_override = m
	inst.position = at + Vector3(0.0, 0.45, 0.0)
	return inst
