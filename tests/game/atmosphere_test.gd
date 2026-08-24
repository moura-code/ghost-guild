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
	a.set_biome("catacombs")
	assert_that(a._material.get_shader_parameter("accent")).is_equal(Palette.biome_accent("catacombs"))


func test_the_crypt_is_drawn_not_photographed() -> void:
	var a := _atmos()
	await await_idle_frame()
	# There is no backdrop image any more. An AI-generated still at low
	# alpha read as a rendering glitch on the warmed palette, so the shader
	# draws the room -- arches, pillars, floor -- procedurally instead.
	for child in a.get_children():
		assert_bool(child is TextureRect) 			.override_failure_message("a texture crept back into the atmosphere") 			.is_false()
	assert_object(a._material.shader).is_not_null()


func test_the_shader_knows_the_frame_it_is_drawing_into() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.set_biome("catacombs")
	# The arches are laid out about the centre in aspect-corrected space, so
	# a wide window must not stretch them into ovals.
	assert_float(float(a._material.get_shader_parameter("aspect"))) 		.is_equal_approx(1280.0 / 720.0, 0.01)


func test_depth_reaches_the_shader_as_the_hero_descends() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.set_biome("catacombs")
	a.set_floor(1, 10)
	assert_float(float(a._material.get_shader_parameter("depth"))).is_equal(0.0)
	a.set_floor(10, 10)
	assert_float(float(a._material.get_shader_parameter("depth"))).is_equal(1.0)
