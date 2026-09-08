extends GdUnitTestSuite
## Boxy empty rooms read as a prototype however good the lighting is. Placement
## is a pure function of the layout and a seeded Rng, so a floor is dressed the
## same way every time you walk back into it.


func _layout() -> FloorLayout:
	return LayoutGenerator.generate(3, Rng.new(7))


func _plan(seed: int = 4) -> Array:
	return Dressing.plan(_layout(), Rng.new(seed))


func test_every_prop_in_the_catalogue_actually_exists_on_disk() -> void:
	for id in Dressing.CATALOGUE:
		assert_object(Dressing.scene_for(String(id))).override_failure_message(
			"no model for %s" % id).is_not_null()


func test_a_floor_gets_dressed() -> void:
	assert_array(_plan()).is_not_empty()


func test_the_same_seed_dresses_the_same_room_the_same_way() -> void:
	var a := _plan(11)
	var b := _plan(11)
	assert_int(a.size()).is_equal(b.size())
	for i in a.size():
		assert_str(String(a[i]["id"])).is_equal(String(b[i]["id"]))
		assert_vector(a[i]["cell"] as Vector2i).is_equal(b[i]["cell"] as Vector2i)


func test_different_seeds_dress_differently() -> void:
	var a := _plan(1)
	var b := _plan(2)
	var same := a.size() == b.size()
	if same:
		for i in a.size():
			if String(a[i]["id"]) != String(b[i]["id"]) or (a[i]["cell"] as Vector2i) != (b[i]["cell"] as Vector2i):
				same = false
				break
	assert_bool(same).is_false()


func test_nothing_stands_in_the_middle_of_a_room() -> void:
	# The centre is where a fight stages and where a ghost stands. A statue
	# inside the enemy is the bug this rule exists to stop.
	var layout := _layout()
	var centres: Array = []
	for room in layout.rooms.size():
		centres.append(layout.room_center(room))
	for entry in Dressing.plan(layout, Rng.new(9)):
		assert_bool(centres.has(entry["cell"] as Vector2i)).override_failure_message(
			"a prop is standing on a room centre").is_false()


func test_nothing_is_placed_inside_stone() -> void:
	var layout := _layout()
	for entry in Dressing.plan(layout, Rng.new(3)):
		var cell: Vector2i = entry["cell"]
		assert_bool(layout.is_walkable(cell.x, cell.y)).override_failure_message(
			"a prop is inside a wall at %s" % cell).is_true()


func test_a_prop_is_nudged_off_the_grid_but_stays_in_its_cell() -> void:
	for entry in _plan(6):
		var offset: Vector2 = entry["offset"]
		assert_float(absf(offset.x)).is_less_equal(Dressing.JITTER + 0.001)
		assert_float(absf(offset.y)).is_less_equal(Dressing.JITTER + 0.001)


func test_a_room_is_dressed_but_not_filled() -> void:
	var layout := _layout()
	var per_room: Dictionary = {}
	for entry in Dressing.plan(layout, Rng.new(5)):
		for room in layout.rooms.size():
			var rect := layout.room_rect(room)
			var cell: Vector2i = entry["cell"]
			if cell.x >= int(rect["x"]) and cell.x < int(rect["x"]) + int(rect["w"]) \
				and cell.y >= int(rect["y"]) and cell.y < int(rect["y"]) + int(rect["h"]):
				per_room[room] = int(per_room.get(room, 0)) + 1
	for room in per_room:
		assert_int(int(per_room[room])).is_less_equal(Dressing.PER_ROOM)


func test_the_big_things_are_solid_and_the_small_ones_are_not() -> void:
	# Walking through a statue is worse than bumping into one; tripping on an
	# urn is worse than walking over it.
	assert_bool(bool(Dressing.CATALOGUE["gothic_statue"]["solid"])).is_true()
	assert_bool(bool(Dressing.CATALOGUE["ceramic_vase_01"]["solid"])).is_false()


func test_spawning_builds_a_prop_where_the_plan_said() -> void:
	var entry := {"id": "gothic_statue", "cell": Vector2i(4, 5), "offset": Vector2.ZERO, "yaw": 0.0}
	var prop: Node3D = auto_free(Dressing.spawn(entry))
	add_child(prop)
	assert_object(prop).is_not_null()
	assert_vector(prop.position).is_equal_approx(Kit.cell_to_world(Vector2i(4, 5)), Vector3.ONE * 0.01)
	assert_object(prop.get_node_or_null("Solid")).is_not_null()


func test_a_prop_that_is_not_in_the_catalogue_thins_the_room_rather_than_crashing() -> void:
	assert_object(Dressing.spawn({"id": "no_such_prop", "cell": Vector2i.ZERO})).is_null()


func test_nothing_is_placed_where_the_player_has_to_be_able_to_stand() -> void:
	# A solid prop dropped beside a station walls the player out of the thing
	# the room exists for, and that is exactly what happened the first time
	# this ran: a barrel blocked the guild table.
	var layout := _layout()
	var keep := [layout.room_center(0), layout.room_center(1)]
	for entry in Dressing.plan(layout, Rng.new(8), keep):
		var cell: Vector2i = entry["cell"]
		for raw in keep:
			var clear: Vector2i = raw
			assert_float(float(absi(cell.x - clear.x) + absi(cell.y - clear.y))).override_failure_message(
				"a prop is on or beside a cell that must stay clear").is_greater(1.0)
