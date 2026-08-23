extends GdUnitTestSuite


func _with_ghost_on(floor: int, seed: int = 2) -> Campaign:
	var c := TestFixtures.campaign(seed, 1000)
	c.onboarding.watch_unlocked = true
	TestFixtures.end_at_exit(c, floor, "watch", 2000)
	return c


func test_costs() -> void:
	var c := TestFixtures.campaign()
	assert_float(Seance.echo_cost(c)).is_equal_approx(50.0, 0.0001)
	assert_float(Seance.call_cost(c)).is_equal_approx(12.5, 0.0001)
	var g := Ghost.new()
	g.floor = 3
	assert_float(Seance.tend_cost(c, g)).is_equal_approx(0.0, 0.0001)
	c.onboarding.free_tend_available = false
	assert_float(Seance.tend_cost(c, g)).is_equal_approx(43.94, 0.0001)
	c.hero.camp = 2
	assert_float(Seance.mend_cost(c)).is_equal_approx(25.35, 0.0001)
	c.upgrades.levels = {"mend_discount": 2}
	assert_float(Seance.mend_cost(c)).is_equal_approx(17.745, 0.0001)


func test_create_echo_rules() -> void:
	var c := _with_ghost_on(3)
	var source := c.ladder.ghosts[1]
	c.soul = 10.0
	assert_str(Seance.create_echo(c, source.id, 2, 3000)["reason"]).is_equal("soul")
	c.soul = 500.0
	assert_str(Seance.create_echo(c, 999, 2, 3000)["reason"]).is_equal("source")
	assert_str(Seance.create_echo(c, source.id, 4, 3000)["reason"]).is_equal("floor")
	assert_str(Seance.create_echo(c, source.id, 0, 3000)["reason"]).is_equal("floor")
	var before_rate := c.rate_per_hour
	var r := Seance.create_echo(c, source.id, 2, 3000)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(50.0, 0.0001)
	assert_float(c.soul).is_equal_approx(450.0, 0.0001)
	var echo := c.ladder.find(int(r["ghost_id"]))
	assert_str(echo.kind).is_equal("echo")
	assert_int(echo.source_id).is_equal(source.id)
	assert_int(echo.floor).is_equal(2)
	assert_float(echo.strength).is_less_equal(0.75 * source.strength + 0.0001)
	assert_float(echo.strength).is_greater(0.0)
	assert_float(c.rate_per_hour).is_greater(before_rate)
	assert_int(Seance.echo_count(c)).is_equal(1)
	assert_float(Seance.echo_cost(c)).is_equal_approx(57.5, 0.0001)
	assert_str(Seance.create_echo(c, echo.id, 1, 3000)["reason"]).is_equal("source")
	assert_int(c.ladder.waypoint()).is_equal(3)


func test_echo_never_out_earns_its_source() -> void:
	var c := _with_ghost_on(3)
	var source := c.ladder.ghosts[1]
	source.strength = 0.5
	assert_float(Seance.echo_strength(c, source, 1)).is_less_equal(0.375 + 0.0001)


func test_call_moves_an_echo() -> void:
	var c := _with_ghost_on(3)
	c.soul = 500.0
	var echo_id := int(Seance.create_echo(c, c.ladder.ghosts[1].id, 1, 3000)["ghost_id"])
	assert_str(Seance.call_echo(c, c.ladder.ghosts[1].id, 2)["reason"]).is_equal("echo")
	assert_str(Seance.call_echo(c, echo_id, 9)["reason"]).is_equal("floor")
	var r := Seance.call_echo(c, echo_id, 2)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(57.5 * 0.25, 0.0001)
	assert_int(c.ladder.find(echo_id).floor).is_equal(2)
	assert_array(c.ladder.on_floor(1)).has_size(1)


func test_tend_clears_restless_first_one_free() -> void:
	var c := TestFixtures.campaign(6, 1000)
	TestFixtures.die_on_floor(c, 1, 2000)
	TestFixtures.die_on_floor(c, 1, 3000)
	var first := c.ladder.ghosts[1]
	var second := c.ladder.ghosts[2]
	assert_bool(first.restless).is_true()
	c.soul = 500.0
	var echo_id := int(Seance.create_echo(c, first.id, 1, 4000)["ghost_id"])
	assert_bool(c.ladder.find(echo_id).restless).is_true()
	var rate_before := c.rate_per_hour
	var r := Seance.tend(c, first.id)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal(0.0)
	assert_bool(first.restless).is_false()
	assert_bool(c.ladder.find(echo_id).restless).is_false()
	assert_bool(c.onboarding.free_tend_available).is_false()
	assert_float(c.rate_per_hour).is_greater_equal(rate_before)
	assert_str(Seance.tend(c, first.id)["reason"]).is_equal("not_restless")
	c.soul = 0.0
	assert_str(Seance.tend(c, second.id)["reason"]).is_equal("soul")
	c.soul = 100.0
	var paid := Seance.tend(c, second.id)
	assert_bool(paid["ok"]).is_true()
	assert_float(paid["cost"]).is_equal_approx(26.0, 0.0001)
	assert_str(Seance.tend(c, 999)["reason"]).is_equal("ghost")


func test_mend_heals_for_soul() -> void:
	var c := TestFixtures.campaign()
	assert_str(Seance.mend(c)["reason"]).is_equal("healthy")
	c.hero.hp = 20
	c.hero.camp = 1
	c.soul = 1.0
	assert_str(Seance.mend(c)["reason"]).is_equal("soul")
	c.soul = 100.0
	var r := Seance.mend(c)
	assert_bool(r["ok"]).is_true()
	assert_float(r["cost"]).is_equal_approx(19.5, 0.0001)
	assert_int(c.hero.hp).is_equal(70)
	assert_float(c.soul).is_equal_approx(80.5, 0.0001)
