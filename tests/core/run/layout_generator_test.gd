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


func _walled(seed: int, node_count: int = 3) -> FloorLayout:
	var layout := _carved(seed, node_count + 2)
	LayoutGenerator.add_walls(layout)
	LayoutGenerator.assign_roles(layout, node_count, Rng.new(seed))
	return layout


func test_no_walkable_cell_ever_touches_the_void() -> void:
	for seed in 12:
		var layout := _walled(seed)
		for y in layout.height:
			for x in layout.width:
				if not layout.is_walkable(x, y):
					continue
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						assert_int(layout.cell(x + dx, y + dy)).is_not_equal(FloorLayout.Cell.VOID)


func test_walls_only_go_where_they_are_needed() -> void:
	var layout := FloorLayout.create(10, 10)
	layout.set_cell(5, 5, FloorLayout.Cell.FLOOR)
	LayoutGenerator.add_walls(layout)
	assert_int(layout.cell(4, 4)).is_equal(FloorLayout.Cell.WALL)
	assert_int(layout.cell(6, 5)).is_equal(FloorLayout.Cell.WALL)
	assert_int(layout.cell(5, 5)).is_equal(FloorLayout.Cell.FLOOR)
	assert_int(layout.cell(0, 0)).is_equal(FloorLayout.Cell.VOID)
	assert_int(layout.cell(3, 5)).is_equal(FloorLayout.Cell.VOID)


func test_the_stairs_are_never_where_you_came_in() -> void:
	for seed in 12:
		var layout := _walled(seed)
		assert_int(layout.entry_room).is_equal(0)
		assert_int(layout.stairs_room).is_not_equal(layout.entry_room)
		assert_bool(layout.stairs_room >= 0).is_true()


func test_every_encounter_gets_a_room_of_its_own() -> void:
	for seed in 12:
		var layout := _walled(seed)
		assert_array(layout.node_rooms).has_size(3)
		var seen: Dictionary = {}
		for raw in layout.node_rooms:
			var room := int(raw)
			assert_bool(seen.has(room)).is_false()
			seen[room] = true
			assert_int(room).is_not_equal(layout.entry_room)
			assert_int(room).is_not_equal(layout.stairs_room)


func test_the_stairs_go_in_the_room_furthest_from_the_door() -> void:
	var layout := _walled(5)
	var entry := layout.room_center(layout.entry_room)
	var stairs := layout.room_center(layout.stairs_room)
	var furthest := absi(stairs.x - entry.x) + absi(stairs.y - entry.y)
	for i in layout.rooms.size():
		var c := layout.room_center(i)
		assert_bool(absi(c.x - entry.x) + absi(c.y - entry.y) <= furthest).is_true()


func test_torches_hang_on_walls_that_face_a_walkable_cell() -> void:
	for seed in 8:
		var layout := LayoutGenerator.generate(3, Rng.new(seed))
		assert_array(layout.torch_anchors).is_not_empty()
		for raw in layout.torch_anchors:
			var at: Vector2i = raw
			assert_int(layout.cell(at.x, at.y)).is_equal(FloorLayout.Cell.WALL)
			var faces_floor: bool = layout.is_walkable(at.x + 1, at.y) \
				or layout.is_walkable(at.x - 1, at.y) \
				or layout.is_walkable(at.x, at.y + 1) \
				or layout.is_walkable(at.x, at.y - 1)
			assert_bool(faces_floor).is_true()


func test_ghosts_stand_anywhere_but_the_way_in() -> void:
	var layout := LayoutGenerator.generate(3, Rng.new(2))
	assert_array(layout.ghost_anchors).has_size(layout.rooms.size() - 1)
	var entry := layout.room_center(layout.entry_room)
	for raw in layout.ghost_anchors:
		var at: Vector2i = raw
		assert_bool(at == entry).is_false()
		assert_bool(layout.is_walkable(at.x, at.y)).is_true()


func test_a_generated_floor_is_whole() -> void:
	for seed in 20:
		var layout := LayoutGenerator.generate(3, Rng.new(seed))
		assert_array(layout.rooms).has_size(5)
		var seen := layout.reachable_from(layout.room_center(layout.entry_room))
		assert_bool(seen.has(layout.room_center(layout.stairs_room))).is_true()
		for i in 3:
			assert_bool(seen.has(layout.room_center(layout.room_of_node(i)))).is_true()


func test_generation_is_deterministic_and_varies_by_seed() -> void:
	var a := LayoutGenerator.generate(3, Rng.new(6))
	var b := LayoutGenerator.generate(3, Rng.new(6))
	assert_bool(a.cells == b.cells).is_true()
	assert_array(a.rooms).is_equal(b.rooms)
	assert_array(a.node_rooms).is_equal(b.node_rooms)
	assert_int(a.stairs_room).is_equal(b.stairs_room)
	var seen: Dictionary = {}
	for seed in 20:
		seen[str(LayoutGenerator.generate(3, Rng.new(seed)).rooms)] = true
	assert_int(seen.size()).is_greater(1)


func test_a_run_asks_its_floor_for_a_shape() -> void:
	var run := TestFixtures.new_run(1, 1)
	var once := RunEngine.layout_for(run)
	var twice := RunEngine.layout_for(run)
	assert_array(once.rooms).is_equal(twice.rooms)
	assert_array(once.node_rooms).has_size(run.nodes.size())
	run.floor = 2
	assert_bool(RunEngine.layout_for(run).rooms == once.rooms).is_false()
