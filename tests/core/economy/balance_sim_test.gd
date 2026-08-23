extends GdUnitTestSuite


func test_non_decreasing_helper() -> void:
	assert_bool(BalanceSim.is_non_decreasing([1.0, 2.0, 2.0, 5.0])).is_true()
	assert_bool(BalanceSim.is_non_decreasing([3.0, 2.0])).is_false()
	assert_bool(BalanceSim.is_non_decreasing([])).is_true()


func test_small_simulation_reports_every_section() -> void:
	var sim := BalanceSim.new()
	sim.content = TestFixtures.content()
	sim.runs = 2
	sim.sim_fights = 4
	sim.seed_base = 3
	var report := sim.report()
	assert_bool(report["floors"].has(1)).is_true()
	var floor1: Dictionary = report["floors"][1]
	assert_int(floor1["samples"]).is_equal(2)
	assert_float(floor1["strength"]).is_greater(0.0)
	assert_float(floor1["yield_watch"]).is_greater(0.0)
	assert_bool(report["invariants"].has("deeper_pays")).is_true()
	assert_bool(report["invariants"].has("watch_beats_corpse")).is_true()
	assert_bool(report["invariants"].has("first_purchase_early")).is_true()
	for key in report["invariants"]:
		assert_bool(report["invariants"][key].has("ok")).is_true()
		assert_str(report["invariants"][key]["detail"]).is_not_empty()
	assert_str(report["retreat_note"]).is_not_empty()
	var every_ok := bool(report["invariants"]["deeper_pays"]["ok"]) and bool(report["invariants"]["watch_beats_corpse"]["ok"]) and bool(report["invariants"]["first_purchase_early"]["ok"])
	assert_bool(sim.all_ok(report) == every_ok).is_true()


func test_sampling_is_deterministic() -> void:
	var a := BalanceSim.new()
	a.content = TestFixtures.content()
	a.runs = 1
	a.sim_fights = 2
	var b := BalanceSim.new()
	b.content = TestFixtures.content()
	b.runs = 1
	b.sim_fights = 2
	var ra := a.sample_runs()
	var rb := b.sample_runs()
	assert_int(ra["per_run"].size()).is_equal(1)
	assert_int(ra["per_run"][0]["death_floor"]).is_equal(rb["per_run"][0]["death_floor"])
	assert_int(ra["samples"].size()).is_equal(rb["samples"].size())
	assert_int(ra["samples"].size()).is_greater_equal(1)
