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
