class_name Dressing
extends RefCounted
## Props against the walls: statues, urns, barrels, rubble.
##
## Boxy empty rooms read as a prototype however good the lighting is, and the
## crypt had exactly one wall texture and nothing standing in it. These are
## CC0 Poly Haven models and they arrive at true scale -- a statue is 1.74 m,
## an urn is 0.4 m -- which is the "one physical scale" discipline (spec §7)
## paying off: nothing had to be resized to fit the kit.
##
## Placement is a pure function of the layout and a seeded Rng, so a floor is
## dressed the same way every time you walk back into it, and the whole thing
## can be checked without a window.

const ROOT := "res://assets/props/"

## `solid` props get a collider, because walking through a statue is worse
## than bumping into one. `radius` is the collider, `high` the height it
## occupies. `wall` props want their back to a wall; the rest are happy
## anywhere out of the middle of the room.
const CATALOGUE := {
	"gothic_statue": {"radius": 0.55, "high": 1.8, "solid": true, "wall": true, "weight": 2},
	"marble_bust_01": {"radius": 0.2, "high": 0.55, "solid": false, "wall": true, "weight": 2},
	"wooden_barrels_01": {"radius": 0.9, "high": 1.0, "solid": true, "wall": true, "weight": 2},
	"wooden_crate_01": {"radius": 0.45, "high": 0.4, "solid": true, "wall": false, "weight": 3},
	"ceramic_vase_01": {"radius": 0.14, "high": 0.4, "solid": false, "wall": true, "weight": 3},
	"antique_ceramic_vase_01": {"radius": 0.16, "high": 0.45, "solid": false, "wall": true, "weight": 3},
	"boulder_01": {"radius": 0.8, "high": 1.0, "solid": true, "wall": false, "weight": 2},
	"wooden_bucket_01": {"radius": 0.2, "high": 0.55, "solid": false, "wall": false, "weight": 3},
}

## Props per room. Enough that a room has something in it, few enough that it
## still reads as a crypt rather than a warehouse.
const PER_ROOM := 3
## How far from a cell's centre a prop may sit, in cells. Keeps it off the
## exact middle so it never lines up with the grid.
const JITTER := 0.22

static var _cache: Dictionary = {}


## One entry per prop: `{"id", "cell", "offset", "yaw"}`. Cells are grid cells;
## the offset is in cells and the yaw is radians.
##
## Never the centre of a room: that is where a fight stages and where a ghost
## stands, and a statue inside the enemy is the bug this rule exists to stop.
## `avoid` is a list of cells nothing may be placed on OR beside: the guild's
## stations, and anywhere else the player has to be able to reach. A solid
## prop dropped in a doorway is dressing that walls the player out of the
## thing the room exists for, and it is exactly what happened the first time
## this ran.
static func plan(layout: FloorLayout, rng: Rng, avoid: Array = []) -> Array:
	var out: Array = []
	var ids := weighted_ids()
	var blocked := _blocked(avoid)
	for room in layout.rooms.size():
		var centre := layout.room_center(room)
		var spots := _spots(layout, room, centre, blocked)
		rng.shuffle("dressing", spots)
		for i in mini(PER_ROOM, spots.size()):
			var spot: Dictionary = spots[i]
			var cell: Vector2i = spot["cell"]
			var id := String(ids[rng.randi_range("dressing", 0, ids.size() - 1)])
			# A prop that wants a wall and did not get one is swapped for one
			# that does not care, rather than dropped: a missing prop is a
			# thinner room for no reason the player can see.
			if bool(CATALOGUE[id]["wall"]) and not bool(spot["against_wall"]):
				id = _free_standing(ids, rng)
			out.append({
				"id": id,
				"cell": cell,
				"offset": Vector2(_spread(rng, JITTER), _spread(rng, JITTER)),
				"yaw": float(spot["yaw"]) + _spread(rng, 0.25),
			})
	return out


## The catalogue expanded by weight, so common dressing turns up more often
## than a gothic statue does.
static func weighted_ids() -> Array:
	var out: Array = []
	for id in CATALOGUE:
		for _i in int(CATALOGUE[id]["weight"]):
			out.append(id)
	out.sort()
	return out


static func scene_for(id: String) -> PackedScene:
	if _cache.has(id):
		return _cache[id]
	var packed: PackedScene = load(ROOT + id + "/" + id + ".gltf")
	_cache[id] = packed
	return packed


## Builds one prop. Returns null for an id that failed to load, so a missing
## download thins a room instead of taking the floor down with it.
static func spawn(entry: Dictionary) -> Node3D:
	var id := String(entry.get("id", ""))
	if not CATALOGUE.has(id):
		return null
	var packed := scene_for(id)
	if packed == null:
		return null
	var holder := Node3D.new()
	holder.name = "Prop_" + id
	var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
	var offset: Vector2 = entry.get("offset", Vector2.ZERO)
	holder.position = Kit.cell_to_world(cell) + Vector3(offset.x * Kit.CELL, 0.0, offset.y * Kit.CELL)
	holder.rotation.y = float(entry.get("yaw", 0.0))
	holder.add_child(packed.instantiate())

	var spec: Dictionary = CATALOGUE[id]
	if bool(spec["solid"]):
		var body := StaticBody3D.new()
		body.name = "Solid"
		body.collision_layer = DungeonBuilder.LAYER_WORLD
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = float(spec["radius"])
		cylinder.height = float(spec["high"])
		shape.shape = cylinder
		shape.position = Vector3(0.0, float(spec["high"]) * 0.5, 0.0)
		body.add_child(shape)
		holder.add_child(body)
	return holder


## Walkable cells in a room that are not its centre, with whether they have a
## wall at their back and which way that back faces.
static func _spots(layout: FloorLayout, room: int, centre: Vector2i, blocked: Dictionary = {}) -> Array:
	var rect := layout.room_rect(room)
	if rect.is_empty():
		return []
	var out: Array = []
	var sides: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(int(rect["y"]), int(rect["y"]) + int(rect["h"])):
		for x in range(int(rect["x"]), int(rect["x"]) + int(rect["w"])):
			var cell := Vector2i(x, y)
			if cell == centre or blocked.has(cell) or not layout.is_walkable(x, y):
				continue
			var back := Vector2i.ZERO
			for side in sides:
				if layout.cell(x + side.x, y + side.y) == FloorLayout.Cell.WALL:
					back = side
					break
			# Facing away from the wall it stands against.
			var yaw := atan2(float(-back.x), float(-back.y)) if back != Vector2i.ZERO else 0.0
			out.append({"cell": cell, "against_wall": back != Vector2i.ZERO, "yaw": yaw})
	return out


## Every avoided cell plus its four neighbours: standing next to a station is
## how you reach it, so the ring matters as much as the cell.
static func _blocked(avoid: Array) -> Dictionary:
	var out: Dictionary = {}
	var around: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for raw in avoid:
		var cell: Vector2i = raw
		for step in around:
			out[cell + step] = true
	return out


## Rng has randf but not randf_range, and adding one would be a core change
## for a presentation convenience.
static func _spread(rng: Rng, half: float) -> float:
	return (rng.randf("dressing") * 2.0 - 1.0) * half


static func _free_standing(ids: Array, rng: Rng) -> String:
	var free: Array = []
	for id in ids:
		if not bool(CATALOGUE[id]["wall"]):
			free.append(id)
	if free.is_empty():
		return String(ids[0])
	return String(free[rng.randi_range("dressing", 0, free.size() - 1)])
