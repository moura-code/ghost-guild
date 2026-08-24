extends GdUnitTestSuite


func _atmos() -> Atmosphere:
	var a: Atmosphere = auto_free(Atmosphere.new())
	add_child(a)
	a.size = Vector2(1280.0, 720.0)
	return a


func test_the_shader_loads_and_is_applied_to_the_ground() -> void:
	var a := _atmos()
	await await_idle_frame()
	assert_object(a._material).is_not_null()
	assert_object(a._material.shader).is_not_null()
	assert_object(a._ground.material).is_same(a._material)


func test_depth_runs_from_the_surface_to_the_bottom_of_the_biome() -> void:
	var a := _atmos()
	a.set_floor(1, 10)
	assert_float(a.depth).is_equal(0.0)
	a.set_floor(10, 10)
	assert_float(a.depth).is_equal(1.0)
	a.set_floor(6, 10)
	assert_float(a.depth).is_equal_approx(5.0 / 9.0, 0.0001)


func test_a_one_floor_biome_does_not_divide_by_zero() -> void:
	var a := _atmos()
	a.set_floor(1, 1)
	assert_float(a.depth).is_equal(0.0)


func test_depth_reaches_the_shader() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.set_floor(10, 10)
	assert_float(float(a._material.get_shader_parameter("depth"))).is_equal(1.0)


func test_depth_is_clamped_however_it_is_set() -> void:
	var a := _atmos()
	a.depth = 4.0
	assert_float(a.depth).is_equal(1.0)
	a.depth = -2.0
	assert_float(a.depth).is_equal(0.0)


func test_deeper_floors_are_stiller() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.set_floor(1, 10)
	var shallow := a._motes.amount
	a.set_floor(10, 10)
	assert_int(a._motes.amount).is_less(shallow)
	assert_int(a._motes.amount).is_greater(0)


func test_the_accent_follows_the_biome() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.set_accent(Palette.biome_accent("catacombs"))
	assert_that(a._material.get_shader_parameter("accent")).is_equal(Palette.biome_accent("catacombs"))


func test_the_motes_fill_the_screen_they_are_given() -> void:
	var a := _atmos()
	await await_idle_frame()
	assert_that(a._motes.emission_rect_extents).is_equal(Vector2(640.0, 360.0))
	assert_that(a._motes.position).is_equal(Vector2(640.0, 360.0))


func test_a_pulse_swells_the_underlight_and_settles_back() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.pulse(1.0)
	await await_idle_frame()
	assert_float(float(a._material.get_shader_parameter("glow_pulse"))).is_greater(0.0)
	await get_tree().create_timer(1.3).timeout
	assert_float(float(a._material.get_shader_parameter("glow_pulse"))).is_equal_approx(0.0, 0.01)


func test_it_never_eats_a_click() -> void:
	var a := _atmos()
	await await_idle_frame()
	assert_int(a.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(a._ground.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
