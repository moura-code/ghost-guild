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
