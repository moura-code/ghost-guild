extends GdUnitTestSuite


func _run_at_exit(c: Campaign, floor: int) -> RunState:
	var run := CampaignEngine.start_run(c, 1, 1001)
	run.floor = floor
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "skip_card"})
	return run


func test_exit_numbers_extend_the_run_summary() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var run := _run_at_exit(c, 2)
	var n := YieldSimulator.exit_numbers(c, run, 2)
	assert_int(n["floor"]).is_equal(2)
	assert_int(n["next_floor"]).is_equal(3)
	assert_float(n["survival"]).is_between(0.0, 1.0)
	assert_float(n["strength_here"]).is_greater(0.0)
	assert_float(n["yield_here"]).is_greater(0.0)
	assert_float(n["strength_next"]).is_greater_equal(0.0)
	assert_float(n["yield_next"]).is_greater_equal(0.0)
	assert_bool(n["can_push"]).is_true()


func test_yield_is_marginal_over_the_ladder_and_prepared() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var run := _run_at_exit(c, 1)
	var strength := YieldSimulator.strength_here(c, run)
	var expected := c.ladder.marginal_yield(1, strength * 1.25, c.balance(), c.modifiers())
	var n := YieldSimulator.exit_numbers(c, run, 1)
	assert_float(n["yield_here"]).is_equal_approx(expected, 0.0001)
	assert_float(YieldSimulator.strength_here(c, run)).is_equal(strength)


func test_no_next_floor_past_the_slice() -> void:
	var c := TestFixtures.campaign(1, 1000)
	var run := _run_at_exit(c, 10)
	var n := YieldSimulator.exit_numbers(c, run, 1)
	assert_bool(n["can_push"]).is_false()
	assert_float(n["yield_next"]).is_equal(-1.0)
	assert_float(n["strength_next"]).is_equal(-1.0)
