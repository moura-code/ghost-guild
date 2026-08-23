extends GdUnitTestSuite


func test_accrue_integrates_real_time() -> void:
	var r := Production.accrue(60.0, 1800, 8.0)
	assert_int(r["elapsed"]).is_equal(1800)
	assert_int(r["counted"]).is_equal(1800)
	assert_bool(r["capped"]).is_false()
	assert_float(r["soul"]).is_equal_approx(30.0, 0.0001)


func test_accrue_caps_offline_time() -> void:
	var r := Production.accrue(10.0, 10 * 3600, 8.0)
	assert_int(r["counted"]).is_equal(8 * 3600)
	assert_bool(r["capped"]).is_true()
	assert_float(r["soul"]).is_equal_approx(80.0, 0.0001)
	var longer := Production.accrue(10.0, 10 * 3600, 24.0)
	assert_bool(longer["capped"]).is_false()
	assert_float(longer["soul"]).is_equal_approx(100.0, 0.0001)


func test_accrue_never_goes_backwards() -> void:
	var r := Production.accrue(60.0, -50, 8.0)
	assert_int(r["elapsed"]).is_equal(0)
	assert_float(r["soul"]).is_equal(0.0)
	assert_float(Production.accrue(0.0, 3600, 8.0)["soul"]).is_equal(0.0)


func test_rate_reads_the_ladder() -> void:
	var ladder := Ladder.new()
	var balance := TestFixtures.content().balance
	var mods := {"global_strength": 1.0, "global_spawn": 1.0, "restless_penalty": 0.3}
	assert_float(Production.rate_per_hour(ladder, balance, mods)).is_equal(0.0)
	ladder.add(Ghost.founder(TestFixtures.content(), 1))
	assert_float(Production.rate_per_hour(ladder, balance, mods)).is_equal_approx(52.0, 0.0001)
