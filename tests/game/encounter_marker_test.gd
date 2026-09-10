extends GdUnitTestSuite
## The marker is the whole "free movement" decision in one node: the player
## chooses a room by walking into it, and the only thing that leaves this
## node is an index. It never touches the run.


func _room() -> Dictionary:
	return {"x": 4, "y": 6, "w": 5, "h": 4}


func _marker(index: int = 1) -> EncounterMarker:
	var m: EncounterMarker = auto_free(EncounterMarker.create(index, _room()))
	add_child(m)
	return m


func test_it_sits_over_its_room() -> void:
	var m := _marker()
	var centre := Kit.cell_to_world(Vector2i(6, 8))
	assert_float(m.position.x).is_equal_approx(centre.x, 0.001)
	assert_float(m.position.z).is_equal_approx(centre.z, 0.001)
	var shape: BoxShape3D = (m.get_node("Shape") as CollisionShape3D).shape
	assert_float(shape.size.x).is_equal_approx(5.0 * Kit.CELL - 1.0, 0.001)
	assert_float(shape.size.z).is_equal_approx(4.0 * Kit.CELL - 1.0, 0.001)


func test_it_watches_the_player_and_nothing_else() -> void:
	var m := _marker()
	assert_int(m.collision_layer).is_equal(EncounterMarker.LAYER_INTERACTABLE)
	assert_int(m.collision_mask).is_equal(Player.LAYER_PLAYER)
	assert_bool(m.monitoring).is_true()


func test_walking_in_reports_which_node_it_is() -> void:
	var m := _marker(2)
	var seen: Array = []
	m.entered.connect(func(i: int) -> void: seen.append(i))
	m.report(auto_free(Player.new()))
	assert_array(seen).is_equal([2])


func test_it_reports_once_however_many_times_you_walk_through_it() -> void:
	var m := _marker()
	var seen: Array = []
	m.entered.connect(func(i: int) -> void: seen.append(i))
	var body: CharacterBody3D = auto_free(Player.new())
	m.report(body)
	m.report(body)
	m.report(body)
	assert_array(seen).has_size(1)


func test_a_resolved_marker_is_inert_and_invisible() -> void:
	var m := _marker()
	var seen: Array = []
	m.entered.connect(func(i: int) -> void: seen.append(i))
	m.resolve()
	m.report(auto_free(Player.new()))
	assert_array(seen).is_empty()
	assert_bool(m.resolved).is_true()
	assert_bool(m.monitoring).is_false()
	assert_bool(m.visible).is_false()


func test_elite_and_shop_require_engagement_and_closing_does_not_reopen() -> void:
	var run := TestFixtures.new_run()
	TestFixtures.set_nodes(run, [{"kind": "shop", "required": false}])
	var marker := _marker(0)
	marker.observe(run)
	var entries := []
	marker.entered.connect(func(index: int) -> void: entries.append(index))
	var player: Player = auto_free(Player.new())
	marker.report(player)
	assert_array(entries).is_empty()
	marker.engage()
	assert_array(entries).has_size(1)
	run.resolve(0)
	marker.observe(run)
	marker.report(player)
	assert_array(entries).has_size(1)
	marker.engage()
	assert_array(entries).has_size(2)


func test_even_room_trigger_stays_inside_its_physical_boundaries() -> void:
	var marker := _marker()
	var shape := marker.get_node("Shape") as CollisionShape3D
	assert_float(shape.position.z).is_equal(-Kit.CELL * 0.5)
	var end := marker.position.z + shape.position.z + (shape.shape as BoxShape3D).size.z * 0.5
	assert_float(end).is_equal((6 + 4 - 0.5) * Kit.CELL - 0.5)
