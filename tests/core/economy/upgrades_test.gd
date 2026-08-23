extends GdUnitTestSuite


func _content() -> Content:
	return TestFixtures.content()


func test_costs_grow_per_level() -> void:
	var def: UpgradeDef = _content().upgrades["might"]
	assert_float(Upgrades.cost_at(def, 0)).is_equal_approx(25.0, 0.0001)
	assert_float(Upgrades.cost_at(def, 1)).is_equal_approx(40.0, 0.0001)
	assert_float(Upgrades.cost_at(def, 2)).is_equal_approx(64.0, 0.0001)
	var u := Upgrades.new()
	assert_float(u.cost(_content(), "might")).is_equal_approx(25.0, 0.0001)
	assert_float(u.cost(_content(), "nothing")).is_equal(-1.0)


func test_buy_respects_soul_and_max_level() -> void:
	var u := Upgrades.new()
	assert_bool(u.can_buy(_content(), "resolve", 59.0)).is_false()
	assert_bool(u.can_buy(_content(), "resolve", 60.0)).is_true()
	assert_float(u.buy(_content(), "resolve")).is_equal_approx(60.0, 0.0001)
	assert_int(u.level("resolve")).is_equal(1)
	assert_bool(u.can_buy(_content(), "resolve", 100000.0)).is_false()
	assert_float(u.buy(_content(), "resolve")).is_equal(-1.0)
	assert_float(u.cost(_content(), "resolve")).is_equal(-1.0)
	assert_float(u.buy(_content(), "nothing")).is_equal(-1.0)


func test_modifiers_from_levels() -> void:
	var u := Upgrades.new()
	var base := u.modifiers(_content())
	assert_float(base["global_strength"]).is_equal(1.0)
	assert_float(base["global_spawn"]).is_equal(1.0)
	assert_float(base["restless_penalty"]).is_equal_approx(0.3, 0.0001)
	assert_float(base["offline_cap_hours"]).is_equal(8.0)
	assert_float(base["mend_discount"]).is_equal(0.0)
	assert_int(base["max_resolve_bonus"]).is_equal(0)
	assert_int(base["stats"]["might"]).is_equal(0)
	u.levels = {"might": 2, "vigor": 1, "resolve": 1, "ghost_strength": 3, "ghost_spawn": 1, "offline_cap": 1, "restless_relief": 2, "mend_discount": 2}
	var m := u.modifiers(_content())
	assert_int(m["stats"]["might"]).is_equal(2)
	assert_int(m["stats"]["vigor"]).is_equal(1)
	assert_int(m["stats"]["wit"]).is_equal(0)
	assert_int(m["max_resolve_bonus"]).is_equal(1)
	assert_float(m["global_strength"]).is_equal_approx(1.3, 0.0001)
	assert_float(m["global_spawn"]).is_equal_approx(1.1, 0.0001)
	assert_float(m["offline_cap_hours"]).is_equal_approx(24.0, 0.0001)
	assert_float(m["restless_penalty"]).is_equal_approx(0.1, 0.0001)
	assert_float(m["mend_discount"]).is_equal_approx(0.3, 0.0001)


func test_round_trip() -> void:
	var u := Upgrades.new()
	u.buy(_content(), "wit")
	u.buy(_content(), "wit")
	var back := Upgrades.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	assert_int(back.level("wit")).is_equal(2)
	assert_float(back.cost(_content(), "wit")).is_equal_approx(64.0, 0.0001)
