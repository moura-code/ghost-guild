extends GdUnitTestSuite
## The builder has no opinions about layout (spec §6): everything it produces
## is a function of the cells it was handed. So the assertions are all
## "the world contains exactly what the layout asked for", which is also the
## only thing a headless suite can honestly check about a 3D scene.


func _bar() -> FloorLayout:
	# Three wall cells in a row, one floor cell under them.
	var l := FloorLayout.create(6, 4)
	l.set_cell(1, 2, FloorLayout.Cell.FLOOR)
	for x in [1, 2, 3]:
		l.set_cell(x, 1, FloorLayout.Cell.WALL)
	return l


func _generated() -> FloorLayout:
	return LayoutGenerator.generate(3, Rng.new(7))


func test_a_run_of_wall_cells_becomes_one_box() -> void:
	var boxes := DungeonBuilder.wall_boxes(_bar())
	assert_array(boxes).has_size(1)
	assert_object(boxes[0]).is_equal(Rect2i(1, 1, 3, 1))


func test_every_wall_cell_is_covered_by_exactly_one_box() -> void:
	var layout := _generated()
	var covered: Dictionary = {}
	for raw in DungeonBuilder.wall_boxes(layout):
		var box: Rect2i = raw
		for x in range(box.position.x, box.position.x + box.size.x):
			var key := Vector2i(x, box.position.y)
			assert_bool(covered.has(key)).override_failure_message("cell %s covered twice" % key).is_false()
			covered[key] = true
	var walls := 0
	for y in layout.height:
		for x in layout.width:
			if layout.cell(x, y) == FloorLayout.Cell.WALL:
				walls += 1
				assert_bool(covered.has(Vector2i(x, y))).override_failure_message("cell %d,%d uncovered" % [x, y]).is_true()
	assert_int(covered.size()).is_equal(walls)


func test_it_instances_one_floor_and_one_ceiling_per_walkable_cell() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var counts := DungeonBuilder.build(layout, root)
	var walkable := 0
	for y in layout.height:
		for x in layout.width:
			if layout.is_walkable(x, y):
				walkable += 1
	assert_int(int(counts["floors"])).is_equal(walkable)
	var floors: MultiMeshInstance3D = root.get_node("Floors")
	var ceilings: MultiMeshInstance3D = root.get_node("Ceilings")
	assert_int(floors.multimesh.instance_count).is_equal(walkable)
	assert_int(ceilings.multimesh.instance_count).is_equal(walkable)


func test_a_floor_instance_sits_at_its_cell_and_the_ceiling_above_it() -> void:
	# Read from instance_transforms(), not from the MultiMesh: instance
	# transforms live on the RenderingServer, and a --headless run uses the
	# dummy driver, which hands back identity for every one of them. Asserting
	# the multimesh here would pass on any implementation at all.
	var placed := DungeonBuilder.instance_transforms(_bar())
	var floors: Array = placed["floors"]
	var ceilings: Array = placed["ceilings"]
	assert_array(floors).has_size(1)
	assert_vector((floors[0] as Transform3D).origin).is_equal_approx(Kit.cell_to_world(Vector2i(1, 2)), Vector3.ONE * 0.001)
	assert_float((ceilings[0] as Transform3D).origin.y).is_equal_approx(Kit.WALL_H, 0.001)
	# The ceiling faces down. Its up vector points at the floor, or the room
	# has a black lid.
	assert_float((ceilings[0] as Transform3D).basis.y.y).is_less(0.0)


func test_a_wall_stands_on_the_floor_rather_than_sinking_into_it() -> void:
	var placed := DungeonBuilder.instance_transforms(_bar())
	var walls: Array = placed["walls"]
	assert_array(walls).has_size(3)
	for raw in walls:
		var t: Transform3D = raw
		assert_float(t.origin.y).is_equal_approx(Kit.WALL_H * 0.5, 0.001)


func test_walls_collide_on_the_world_layer_and_mask_nothing() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var counts := DungeonBuilder.build(layout, root)
	var body: StaticBody3D = root.get_node("Collision")
	assert_int(body.collision_layer).is_equal(DungeonBuilder.LAYER_WORLD)
	# Static geometry never needs to detect anything; masking is what makes a
	# body ask the physics server about others, and 500 walls asking is a bill
	# for nothing.
	assert_int(body.collision_mask).is_equal(0)
	# One shape per merged wall run, plus the ground slab.
	assert_int(body.get_child_count()).is_equal(int(counts["boxes"]) + 1)


func test_the_ground_slab_spans_the_whole_grid() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	DungeonBuilder.build(layout, root)
	var slab: CollisionShape3D = root.get_node("Collision/Ground")
	var box: BoxShape3D = slab.shape
	assert_float(box.size.x).is_greater_equal(layout.width * Kit.CELL)
	assert_float(box.size.z).is_greater_equal(layout.height * Kit.CELL)
	assert_float(slab.position.y).is_less(0.0)


func test_a_torch_hangs_in_the_open_cell_in_front_of_its_wall() -> void:
	var layout := _generated()
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var counts := DungeonBuilder.build(layout, root)
	var torches: Torches = root.get_node("Torches")
	assert_int(torches.count()).is_equal(int(counts["torches"]))
	assert_int(torches.count()).is_greater(0)
	for i in torches.count():
		var light := torches.light(i)
		# A light left on the anchor sits inside the wall and lights it from
		# within, which reads as a glowing window floating in the stone.
		var cell := Kit.world_to_cell(light.position)
		assert_bool(layout.is_walkable(cell.x, cell.y)).override_failure_message("torch inside stone at %s" % cell).is_true()
		assert_bool(light.shadow_enabled).is_true()


func test_building_the_same_layout_twice_produces_the_same_world() -> void:
	var a: Node3D = auto_free(Node3D.new())
	var b: Node3D = auto_free(Node3D.new())
	add_child(a)
	add_child(b)
	assert_dict(DungeonBuilder.build(_generated(), a)).is_equal(DungeonBuilder.build(_generated(), b))
