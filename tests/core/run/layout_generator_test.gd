extends GdUnitTestSuite


func _placed(seed: int, count: int = 5) -> FloorLayout:
	var layout := FloorLayout.create(LayoutGenerator.GRID, LayoutGenerator.GRID)
	LayoutGenerator.place_rooms(layout, count, Rng.new(seed))
	return layout


func test_it_places_every_room_it_was_asked_for() -> void:
	for seed in 12:
		assert_array(_placed(seed).rooms).has_size(5)


func test_rooms_stay_inside_the_grid() -> void:
	for seed in 12:
		var layout := _placed(seed)
		for raw in layout.rooms:
			var r: Dictionary = raw
			assert_bool(int(r["x"]) >= 0).is_true()
			assert_bool(int(r["y"]) >= 0).is_true()
			assert_bool(int(r["x"]) + int(r["w"]) <= layout.width).is_true()
			assert_bool(int(r["y"]) + int(r["h"]) <= layout.height).is_true()
			assert_bool(int(r["w"]) >= LayoutGenerator.ROOM_MIN).is_true()
			assert_bool(int(r["h"]) <= LayoutGenerator.ROOM_MAX).is_true()


func test_rooms_never_overlap_or_touch() -> void:
	for seed in 12:
		var rooms := _placed(seed).rooms
		for i in rooms.size():
			for j in range(i + 1, rooms.size()):
				var a: Dictionary = rooms[i]
				var b: Dictionary = rooms[j]
				var apart_x: bool = int(a["x"]) + int(a["w"]) < int(b["x"]) or int(b["x"]) + int(b["w"]) < int(a["x"])
				var apart_y: bool = int(a["y"]) + int(a["h"]) < int(b["y"]) or int(b["y"]) + int(b["h"]) < int(a["y"])
				assert_bool(apart_x or apart_y).is_true()


func test_placement_is_deterministic_and_varies_by_seed() -> void:
	assert_array(_placed(4).rooms).is_equal(_placed(4).rooms)
	var seen: Dictionary = {}
	for seed in 20:
		seen[str(_placed(seed).rooms)] = true
	assert_int(seen.size()).is_greater(1)


func _carved(seed: int, count: int = 5) -> FloorLayout:
	var layout := _placed(seed, count)
	LayoutGenerator.carve_rooms(layout)
	LayoutGenerator.connect_rooms(layout, Rng.new(seed))
	return layout


func test_carving_makes_every_room_cell_walkable() -> void:
	var layout := _placed(3)
	LayoutGenerator.carve_rooms(layout)
	for raw in layout.rooms:
		var r: Dictionary = raw
		for y in range(int(r["y"]), int(r["y"]) + int(r["h"])):
			for x in range(int(r["x"]), int(r["x"]) + int(r["w"])):
				assert_bool(layout.is_walkable(x, y)).is_true()


func test_a_corridor_is_carved_in_two_straight_legs() -> void:
	var layout := FloorLayout.create(10, 10)
	LayoutGenerator.carve_corridor(layout, Vector2i(1, 1), Vector2i(4, 3), true)
	for x in range(1, 5):
		assert_bool(layout.is_walkable(x, 1)).is_true()
	for y in range(1, 4):
		assert_bool(layout.is_walkable(4, y)).is_true()
	assert_bool(layout.is_walkable(1, 3)).is_false()


func test_every_room_can_be_reached_from_every_other() -> void:
	for seed in 12:
		var layout := _carved(seed)
		var seen := layout.reachable_from(layout.room_center(0))
		for i in layout.rooms.size():
			assert_bool(seen.has(layout.room_center(i))).is_true()


func test_reachability_stops_at_rock() -> void:
	var layout := FloorLayout.create(10, 10)
	layout.set_cell(1, 1, FloorLayout.Cell.FLOOR)
	layout.set_cell(1, 2, FloorLayout.Cell.FLOOR)
	layout.set_cell(5, 5, FloorLayout.Cell.FLOOR)
	var seen := layout.reachable_from(Vector2i(1, 1))
	assert_int(seen.size()).is_equal(2)
	assert_bool(seen.has(Vector2i(5, 5))).is_false()
	assert_dict(layout.reachable_from(Vector2i(9, 9))).is_empty()
