extends GdUnitTestSuite


func _balance() -> Dictionary:
	return TestFixtures.content().balance


func _mods() -> Dictionary:
	return {"global_strength": 1.0, "global_spawn": 1.0, "restless_penalty": 0.3}


func _ghost(floor: int, strength: float, prepared: bool = false, restless: bool = false, kind: String = "true") -> Ghost:
	var g := Ghost.new()
	g.name = "G%d" % floor
	g.floor = floor
	g.strength = strength
	g.prepared = prepared
	g.restless = restless
	g.kind = kind
	return g


func test_curves() -> void:
	assert_float(Ladder.spawn_rate(1, _balance())).is_equal_approx(64.8, 0.0001)
	assert_float(Ladder.spawn_rate(10, _balance())).is_equal_approx(129.5355, 0.001)
	assert_float(Ladder.soul_per_kill(1, _balance())).is_equal_approx(1.3, 0.0001)


func test_output_soft_cap() -> void:
	assert_float(Ladder.output_for(40.0, 1, _balance())).is_equal_approx(52.0, 0.0001)
	assert_float(Ladder.output_for(100.0, 1, _balance())).is_equal_approx(95.68, 0.0001)
	assert_float(Ladder.output_for(0.0, 1, _balance())).is_equal(0.0)
	assert_float(Ladder.output_for(100.0, 1, _balance(), 2.0)).is_equal_approx(130.0, 0.0001)


func test_effective_strength_multipliers() -> void:
	assert_float(Ladder.effective_strength(_ghost(1, 30.0, true), _balance(), _mods())).is_equal_approx(37.5, 0.0001)
	assert_float(Ladder.effective_strength(_ghost(1, 30.0, false, true), _balance(), _mods())).is_equal_approx(21.0, 0.0001)
	var mods := {"global_strength": 1.2, "global_spawn": 1.0, "restless_penalty": 0.1}
	assert_float(Ladder.effective_strength(_ghost(1, 30.0, false, true), _balance(), mods)).is_equal_approx(32.4, 0.0001)


func test_add_find_remove_and_floors() -> void:
	var ladder := Ladder.new()
	var a := ladder.add(_ghost(3, 10.0))
	var b := ladder.add(_ghost(1, 5.0))
	assert_int(a.id).is_equal(1)
	assert_int(b.id).is_equal(2)
	assert_int(ladder.next_ghost_id).is_equal(3)
	assert_object(ladder.find(2)).is_same(b)
	assert_object(ladder.find(9)).is_null()
	assert_array(ladder.floors()).is_equal([1, 3])
	assert_array(ladder.on_floor(3)).has_size(1)
	assert_bool(ladder.remove(1)).is_true()
	assert_bool(ladder.remove(1)).is_false()
	assert_array(ladder.ghosts).has_size(1)


func test_floor_math_and_marginal_yield() -> void:
	var ladder := Ladder.new()
	assert_float(ladder.marginal_yield(1, 40.0, _balance(), _mods())).is_equal_approx(52.0, 0.0001)
	ladder.add(_ghost(1, 64.8))
	assert_float(ladder.floor_strength(1, _balance(), _mods())).is_equal_approx(64.8, 0.0001)
	assert_float(ladder.saturation(1, _balance(), _mods())).is_equal_approx(1.0, 0.0001)
	assert_float(ladder.floor_output(1, _balance(), _mods())).is_equal_approx(84.24, 0.0001)
	assert_float(ladder.marginal_yield(1, 40.0, _balance(), _mods())).is_equal_approx(13.0, 0.0001)
	ladder.add(_ghost(3, 20.0))
	assert_float(ladder.total_output(_balance(), _mods())).is_equal_approx(84.24 + 20.0 * 2.197, 0.001)
	var spawny := {"global_strength": 1.0, "global_spawn": 2.0, "restless_penalty": 0.3}
	assert_float(ladder.saturation(1, _balance(), spawny)).is_equal_approx(0.5, 0.0001)


func test_waypoint_counts_true_ghosts_only() -> void:
	var ladder := Ladder.new()
	assert_int(ladder.waypoint()).is_equal(0)
	ladder.add(_ghost(2, 1.0))
	ladder.add(_ghost(6, 1.0, false, false, "echo"))
	assert_int(ladder.waypoint()).is_equal(2)
	ladder.add(_ghost(4, 1.0, true))
	assert_int(ladder.waypoint()).is_equal(4)


func test_round_trip() -> void:
	var ladder := Ladder.new()
	ladder.add(Ghost.founder(TestFixtures.content(), 9))
	ladder.add(_ghost(5, 12.5, true))
	var back := Ladder.from_dict(JSON.parse_string(JSON.stringify(ladder.to_dict())))
	assert_array(back.ghosts).has_size(2)
	assert_int(back.next_ghost_id).is_equal(3)
	assert_str(back.ghosts[0].name).is_equal("Ilse")
	assert_int(back.ghosts[1].id).is_equal(2)
	assert_float(back.ghosts[1].strength).is_equal(12.5)
	assert_int(back.waypoint()).is_equal(5)
