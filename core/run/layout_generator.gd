class_name LayoutGenerator
extends RefCounted
## Builds a FloorLayout from a seed: place rooms, carve them, join them with
## corridors, ring the result in wall, hand out the roles, then dress it.
## Uses the "layout" rng stream only, so generating a floor's shape never
## disturbs the encounter or fight streams.

const STREAM := "layout"
const GRID := 24
## The grid is partitioned into BLOCKS_PER_SIDE^2 blocks of BLOCK cells and
## each room gets its own block, so rooms cannot overlap and placement cannot
## fail. Rejection sampling on an open grid can run out of attempts and quietly
## return a floor with a room missing, which would strand an encounter with no
## room to happen in -- a wrong answer rather than a crash, and the kind that
## only shows up on one seed in a hundred.
const BLOCK := 8
const BLOCKS_PER_SIDE := 3
const ROOM_MIN := 3
const ROOM_MAX := 6
## One cell of padding inside each block, so neighbouring rooms always have at
## least one solid cell between them and never share a wall.
const PAD := 1


static func place_rooms(layout: FloorLayout, count: int, rng: Rng) -> void:
	var slots: Array = []
	for by in BLOCKS_PER_SIDE:
		for bx in BLOCKS_PER_SIDE:
			slots.append(Vector2i(bx, by))
	rng.shuffle(STREAM, slots)
	var rooms: Array = []
	var span := BLOCK - PAD * 2
	for i in mini(count, slots.size()):
		var slot: Vector2i = slots[i]
		var w := rng.randi_range(STREAM, ROOM_MIN, mini(ROOM_MAX, span))
		var h := rng.randi_range(STREAM, ROOM_MIN, mini(ROOM_MAX, span))
		var x := slot.x * BLOCK + PAD + rng.randi_range(STREAM, 0, span - w)
		var y := slot.y * BLOCK + PAD + rng.randi_range(STREAM, 0, span - h)
		rooms.append({"x": x, "y": y, "w": w, "h": h})
	layout.rooms = rooms


static func carve_rooms(layout: FloorLayout) -> void:
	for raw in layout.rooms:
		var r: Dictionary = raw
		for y in range(int(r["y"]), int(r["y"]) + int(r["h"])):
			for x in range(int(r["x"]), int(r["x"]) + int(r["w"])):
				layout.set_cell(x, y, FloorLayout.Cell.FLOOR)


## Both legs are axis-aligned, so the walk below never moves diagonally and can
## never cut a one-cell diagonal gap you cannot walk through.
static func carve_corridor(layout: FloorLayout, a: Vector2i, b: Vector2i, horizontal_first: bool) -> void:
	var corner := Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
	_carve_line(layout, a, corner)
	_carve_line(layout, corner, b)


static func _carve_line(layout: FloorLayout, from: Vector2i, to: Vector2i) -> void:
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var at := from
	layout.set_cell(at.x, at.y, FloorLayout.Cell.FLOOR)
	while at != to:
		at += step
		layout.set_cell(at.x, at.y, FloorLayout.Cell.FLOOR)


## A chain through every room is what guarantees the floor is connected; the
## extra links are what make choosing a route a choice, rather than a single
## corridor with rooms hanging off it.
static func connect_rooms(layout: FloorLayout, rng: Rng) -> void:
	for i in range(1, layout.rooms.size()):
		carve_corridor(layout, layout.room_center(i - 1), layout.room_center(i), rng.randi_range(STREAM, 0, 1) == 0)
	if layout.rooms.size() < 4:
		return
	for _i in 2:
		var a := rng.randi_range(STREAM, 0, layout.rooms.size() - 1)
		var b := rng.randi_range(STREAM, 0, layout.rooms.size() - 1)
		if absi(a - b) < 2:
			continue
		carve_corridor(layout, layout.room_center(a), layout.room_center(b), rng.randi_range(STREAM, 0, 1) == 0)


## Any solid cell touching walkable floor becomes wall; everything else stays
## void and never gets geometry. Diagonals count: a corner left void is a gap
## you can see straight through in a first-person view, and it is exactly the
## seam a modular kit cannot hide. Run this after every corridor is carved, or
## a later corridor punches a hole through a wall ring already built.
static func add_walls(layout: FloorLayout) -> void:
	var around := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for y in layout.height:
		for x in layout.width:
			if layout.cell(x, y) != FloorLayout.Cell.VOID:
				continue
			for step in around:
				if layout.cell(x + step.x, y + step.y) == FloorLayout.Cell.FLOOR:
					layout.set_cell(x, y, FloorLayout.Cell.WALL)
					break


## You come in at the first room and the stairs go in the room furthest from
## it, so a floor has a direction even though you may walk it in any order.
## The encounters take the rooms in between, shuffled, so a room's size and
## shape never telegraph what is waiting in it.
static func assign_roles(layout: FloorLayout, node_count: int, rng: Rng) -> void:
	layout.entry_room = 0
	var entry := layout.room_center(0)
	var stairs := -1
	var furthest := -1
	for i in range(1, layout.rooms.size()):
		var c := layout.room_center(i)
		var distance := absi(c.x - entry.x) + absi(c.y - entry.y)
		if distance > furthest:
			furthest = distance
			stairs = i
	layout.stairs_room = stairs
	var free: Array = []
	for i in layout.rooms.size():
		if i != layout.entry_room and i != layout.stairs_room:
			free.append(i)
	rng.shuffle(STREAM, free)
	var out: Array = []
	for i in node_count:
		# generate() always places node_count + 2 rooms, so `free` has exactly
		# one room per node. The wrap is for a caller that asked for more nodes
		# than the 3x3 partition can seat: doubling up is bad, stranding an
		# encounter is worse.
		out.append(int(free[i % free.size()]) if not free.is_empty() else layout.entry_room)
	layout.node_rooms = out


## Torches hang on walls that face somewhere walkable, thinned to about one in
## five so a corridor is lit in pools rather than evenly. The dark between them
## is the difficulty made physical (spec §2), so the thinning is a design
## choice, not a performance one.
static func place_anchors(layout: FloorLayout, rng: Rng) -> void:
	var torches: Array = []
	for y in layout.height:
		for x in layout.width:
			if layout.cell(x, y) != FloorLayout.Cell.WALL:
				continue
			var faces_floor: bool = layout.is_walkable(x + 1, y) \
				or layout.is_walkable(x - 1, y) \
				or layout.is_walkable(x, y + 1) \
				or layout.is_walkable(x, y - 1)
			if faces_floor and rng.randi_range(STREAM, 0, 4) == 0:
				torches.append(Vector2i(x, y))
	layout.torch_anchors = torches
	var ghosts: Array = []
	for i in layout.rooms.size():
		if i != layout.entry_room:
			ghosts.append(layout.room_center(i))
	rng.shuffle(STREAM, ghosts)
	layout.ghost_anchors = ghosts


## Two rooms beyond the encounters: the one you come in by and the one the
## stairs are in. Biome dressing takes a parameter here when there is a second
## biome to dress; the floor number already reaches this through the seed.
static func generate(node_count: int, rng: Rng) -> FloorLayout:
	var layout := FloorLayout.create(GRID, GRID)
	place_rooms(layout, node_count + 2, rng)
	carve_rooms(layout)
	connect_rooms(layout, rng)
	add_walls(layout)
	assign_roles(layout, node_count, rng)
	place_anchors(layout, rng)
	return layout
