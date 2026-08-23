extends GdUnitTestSuite


func _balance() -> Dictionary:
	return TestFixtures.content().balance


func test_seconds_per_kill_and_strength() -> void:
	assert_float(Strength.seconds_per_kill(1.0, 4.0, _balance())).is_equal_approx(60.0, 0.0001)
	assert_float(Strength.from_stats(1.0, 4.0, _balance())).is_equal_approx(60.0, 0.0001)
	assert_float(Strength.seconds_per_kill(0.5, 4.0, _balance())).is_equal_approx(240.0, 0.0001)
	assert_float(Strength.from_stats(0.5, 4.0, _balance())).is_equal_approx(15.0, 0.0001)
	assert_float(Strength.from_stats(0.0, 4.0, _balance())).is_equal(0.0)
	assert_bool(is_inf(Strength.seconds_per_kill(0.0, 4.0, _balance()))).is_true()


func test_blend_weights_by_sample_size() -> void:
	var measured := {"fights": 2, "wins": 2, "win_rate": 1.0, "avg_turns": 4.0}
	var simulated := {"fights": 50, "wins": 25, "win_rate": 0.5, "avg_turns": 6.0}
	var b := Strength.blend(measured, simulated, _balance())
	assert_float(b["weight"]).is_equal_approx(0.4, 0.0001)
	assert_float(b["win_rate"]).is_equal_approx(0.7, 0.0001)
	assert_float(b["avg_turns"]).is_equal_approx(5.2, 0.0001)
	var none := Strength.blend({"fights": 0, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}, simulated, _balance())
	assert_float(none["weight"]).is_equal(0.0)
	assert_float(none["win_rate"]).is_equal_approx(0.5, 0.0001)


func test_blend_ignores_measured_turns_without_wins() -> void:
	var measured := {"fights": 3, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}
	var simulated := {"fights": 50, "wins": 50, "win_rate": 1.0, "avg_turns": 5.0}
	var b := Strength.blend(measured, simulated, _balance())
	assert_float(b["weight"]).is_equal_approx(0.5, 0.0001)
	assert_float(b["win_rate"]).is_equal_approx(0.5, 0.0001)
	assert_float(b["avg_turns"]).is_equal_approx(5.0, 0.0001)
	assert_float(Strength.of_ghost_stats(measured, simulated, _balance())).is_equal_approx(3600.0 / 260.0, 0.001)


func test_groups_for_reads_the_right_bucket() -> void:
	var biome: BiomeDef = TestFixtures.content().biomes["catacombs"]
	assert_array(FloorGenerator.groups_for(biome, 2)).has_size(4)
	assert_array(FloorGenerator.groups_for(biome, 5)[1]).is_equal(["skull_stack"])
	assert_array(FloorGenerator.groups_for(biome, 12)[0]).is_equal(["hollow_knight"])
	var groups := FloorGenerator.groups_for(biome, 1)
	groups[0].append("ghoul")
	assert_array(FloorGenerator.groups_for(biome, 1)[0]).is_equal(["bone_rat"])


func test_simulate_is_deterministic_and_sane() -> void:
	var content := TestFixtures.content()
	var biome: BiomeDef = content.biomes["catacombs"]
	var snap := TestFixtures.hero().snapshot()
	var a := Strength.simulate(content, snap, biome, 1, 7, 10)
	var b := Strength.simulate(content, snap, biome, 1, 7, 10)
	assert_dict(a).is_equal(b)
	assert_int(a["fights"]).is_equal(10)
	assert_float(a["win_rate"]).is_greater_equal(0.5)
	assert_float(a["avg_turns"]).is_between(1.0, 30.0)
	var deep := Strength.simulate(content, snap, biome, 10, 7, 4)
	assert_float(deep["win_rate"]).is_less_equal(a["win_rate"])
	assert_int(Strength.simulate(content, snap, biome, 1, 7)["fights"]).is_equal(50)
