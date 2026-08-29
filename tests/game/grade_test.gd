extends GdUnitTestSuite
## "Depth is the threat" (spec §2.3) has to be measurable or it is a mood
## board. These are the numbers that make floor 20 feel unlike floor 2 before
## a card is played.


func test_depth_runs_from_the_surface_to_the_bottom_of_the_biome() -> void:
	assert_float(Grade.depth_of(1, 10)).is_equal(0.0)
	assert_float(Grade.depth_of(10, 10)).is_equal(1.0)
	assert_float(Grade.depth_of(6, 10)).is_equal_approx(5.0 / 9.0, 0.0001)


func test_a_one_floor_biome_does_not_divide_by_zero() -> void:
	assert_float(Grade.depth_of(1, 1)).is_equal(0.0)


func test_depth_is_clamped_however_it_is_asked_for() -> void:
	assert_float(Grade.depth_of(-4, 10)).is_equal(0.0)
	assert_float(Grade.depth_of(400, 10)).is_equal(1.0)


func test_the_deep_is_foggier_and_darker_than_the_surface() -> void:
	var top := Grade.environment(0.0)
	var bottom := Grade.environment(1.0)
	assert_float(bottom.fog_density).is_greater(top.fog_density)
	assert_float(bottom.ambient_light_energy).is_less(top.ambient_light_energy)


func test_every_floor_is_graded_the_same_way() -> void:
	# One tonemap for the whole game is what makes mixed CC0 sources look like
	# one game (spec §7). Depth changes the light, never the grade.
	for depth in [0.0, 0.5, 1.0]:
		var env := Grade.environment(depth)
		assert_int(env.tonemap_mode).is_equal(Environment.TONE_MAPPER_ACES)
		assert_bool(env.ssao_enabled).is_true()
		assert_bool(env.glow_enabled).is_true()
		assert_bool(env.fog_enabled).is_true()


func test_the_world_environment_carries_the_environment() -> void:
	var we: WorldEnvironment = auto_free(Grade.world_environment(0.4))
	assert_object(we.environment).is_not_null()
	assert_int(we.environment.tonemap_mode).is_equal(Environment.TONE_MAPPER_ACES)
