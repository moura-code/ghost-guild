extends GdUnitTestSuite


func test_a_new_grid_is_solid_void() -> void:
	var layout := FloorLayout.create(6, 4)
	assert_int(layout.width).is_equal(6)
	assert_int(layout.height).is_equal(4)
	assert_int(layout.cells.size()).is_equal(24)
	for y in 4:
		for x in 6:
			assert_int(layout.cell(x, y)).is_equal(FloorLayout.Cell.VOID)


func test_cells_are_addressed_by_row() -> void:
	var layout := FloorLayout.create(6, 4)
	layout.set_cell(2, 3, FloorLayout.Cell.FLOOR)
	assert_int(layout.cell(2, 3)).is_equal(FloorLayout.Cell.FLOOR)
	assert_int(layout.cell(3, 2)).is_equal(FloorLayout.Cell.VOID)
	assert_bool(layout.is_walkable(2, 3)).is_true()
	assert_bool(layout.is_walkable(3, 2)).is_false()


func test_outside_the_grid_reads_as_solid_rock() -> void:
	var layout := FloorLayout.create(6, 4)
	assert_bool(layout.in_bounds(0, 0)).is_true()
	assert_bool(layout.in_bounds(6, 0)).is_false()
	assert_bool(layout.in_bounds(-1, 2)).is_false()
	assert_int(layout.cell(-1, -1)).is_equal(FloorLayout.Cell.VOID)
	assert_int(layout.cell(99, 99)).is_equal(FloorLayout.Cell.VOID)
	layout.set_cell(99, 99, FloorLayout.Cell.FLOOR)
	assert_int(layout.cells.size()).is_equal(24)


func test_a_room_reports_its_middle() -> void:
	var layout := FloorLayout.create(24, 24)
	layout.rooms = [{"x": 2, "y": 3, "w": 4, "h": 5}]
	var centre := layout.room_center(0)
	assert_int(centre.x).is_equal(4)
	assert_int(centre.y).is_equal(5)
	assert_int(int(layout.room_rect(0)["w"])).is_equal(4)


func test_missing_rooms_and_nodes_answer_without_crashing() -> void:
	var layout := FloorLayout.create(24, 24)
	assert_dict(layout.room_rect(0)).is_empty()
	assert_int(layout.room_center(0).x).is_equal(0)
	assert_int(layout.room_of_node(0)).is_equal(-1)


func test_a_room_rect_is_a_copy() -> void:
	var layout := FloorLayout.create(24, 24)
	layout.rooms = [{"x": 2, "y": 3, "w": 4, "h": 5}]
	var rect := layout.room_rect(0)
	rect["w"] = 99
	assert_int(int((layout.rooms[0] as Dictionary)["w"])).is_equal(4)


func test_nodes_map_to_rooms() -> void:
	var layout := FloorLayout.create(24, 24)
	layout.node_rooms = [2, 1, 3]
	assert_int(layout.room_of_node(0)).is_equal(2)
	assert_int(layout.room_of_node(2)).is_equal(3)
	assert_int(layout.room_of_node(9)).is_equal(-1)
