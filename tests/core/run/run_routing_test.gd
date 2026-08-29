extends GdUnitTestSuite


func test_a_fresh_floor_has_nothing_resolved() -> void:
	var run := TestFixtures.new_run(1, 1)
	assert_int(run.next_unresolved()).is_equal(0)
	for i in run.nodes.size():
		assert_bool(run.is_resolved(i)).is_false()


func test_resolving_moves_the_next_unresolved_forward() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(0)
	assert_bool(run.is_resolved(0)).is_true()
	assert_int(run.next_unresolved()).is_equal(1)
	run.resolve(2)
	assert_int(run.next_unresolved()).is_equal(1)
	run.resolve(1)
	assert_int(run.next_unresolved()).is_equal(-1)


func test_flags_resize_to_whoever_wrote_the_nodes_last() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(0)
	run.nodes = [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}]
	assert_bool(run.is_resolved(0)).is_true()
	assert_bool(run.is_resolved(3)).is_false()
	assert_int(run.next_unresolved()).is_equal(1)


func test_out_of_range_flags_are_ignored() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(-1)
	run.resolve(99)
	assert_bool(run.is_resolved(-1)).is_false()
	assert_bool(run.is_resolved(99)).is_false()
	assert_int(run.next_unresolved()).is_equal(0)


func test_resolved_flags_survive_a_save_round_trip() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.resolve(1)
	var back := RunState.from_dict(TestFixtures.content(), run.to_dict())
	assert_bool(back.is_resolved(0)).is_false()
	assert_bool(back.is_resolved(1)).is_true()
	assert_int(back.next_unresolved()).is_equal(0)


func test_every_unresolved_node_is_on_offer() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	assert_array(RunEngine.legal_actions(run)).is_equal([
		{"kind": "enter", "index": 0},
		{"kind": "enter", "index": 1},
		{"kind": "enter", "index": 2},
	])


func test_a_floor_can_be_walked_out_of_order() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter", "index": 2})
	assert_int(run.node_index).is_equal(2)
	RunEngine.apply(run, {"kind": "rest_heal"})
	assert_bool(run.is_resolved(2)).is_true()
	assert_str(run.phase).is_equal("node")
	assert_array(RunEngine.legal_actions(run)).is_equal([
		{"kind": "enter", "index": 0},
		{"kind": "enter", "index": 1},
	])


func test_the_stairs_wait_until_every_room_is_done() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	for index in [1, 0, 2]:
		assert_str(run.phase).is_equal("node")
		RunEngine.apply(run, {"kind": "enter", "index": index})
		RunEngine.apply(run, {"kind": "rest_heal"})
	assert_str(run.phase).is_equal("exit")
	assert_array(TestFixtures.run_events_of(run, "floor_cleared")).has_size(1)


func test_a_bare_enter_still_takes_the_next_one() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_int(run.node_index).is_equal(0)
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "enter"})
	assert_int(run.node_index).is_equal(1)


func test_a_resolved_or_missing_room_cannot_be_entered() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}, {"kind": "rest"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	assert_str(run.phase).is_equal("node")
	RunEngine.apply(run, {"kind": "enter", "index": 7})
	assert_str(run.phase).is_equal("node")
