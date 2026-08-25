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


## The focus rule (visual-overhaul spec §3.2). Every screen declares where
## its content lives and the ground falls away outside it, which is what
## gives a screen a subject. Asserted on the shader parameter, never on the
## render: appearance is judged from the contact sheet, not from a test.
func test_no_focus_declared_lights_the_whole_frame() -> void:
	var a := _atmos()
	await await_idle_frame()
	# A screen that declares nothing must look exactly as it did before the
	# focus rule existed, or adding it silently darkens twelve screens.
	assert_float(a._material.get_shader_parameter("focus_strength")).is_equal(0.0)


func test_a_focus_rect_reaches_the_shader_as_a_normalised_centre() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.focus_on(Rect2(Vector2(320.0, 180.0), Vector2(640.0, 360.0)))
	var centre: Vector2 = a._material.get_shader_parameter("focus_centre")
	assert_float(centre.x).is_equal_approx(0.5, 0.001)
	assert_float(centre.y).is_equal_approx(0.5, 0.001)
	assert_float(a._material.get_shader_parameter("focus_strength")).is_greater(0.0)


func test_an_off_centre_focus_moves_the_light_with_it() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.focus_on(Rect2(Vector2(0.0, 0.0), Vector2(320.0, 180.0)))
	var centre: Vector2 = a._material.get_shader_parameter("focus_centre")
	assert_float(centre.x).is_equal_approx(0.125, 0.001)
	assert_float(centre.y).is_equal_approx(0.125, 0.001)


func test_clearing_the_focus_restores_the_open_frame() -> void:
	var a := _atmos()
	await await_idle_frame()
	a.focus_on(Rect2(Vector2(100.0, 100.0), Vector2(200.0, 200.0)))
	a.clear_focus()
	assert_float(a._material.get_shader_parameter("focus_strength")).is_equal(0.0)


func test_a_focus_set_before_layout_survives_being_resized() -> void:
	# Screens declare their focus in _build(), before the container has sized
	# them. If the rect is normalised once and forgotten, every screen focuses
	# on the wrong place at the size it actually renders at.
	var a: Atmosphere = auto_free(Atmosphere.new())
	add_child(a)
	a.focus_on(Rect2(Vector2(0.0, 0.0), Vector2(64.0, 36.0)))
	a.size = Vector2(1280.0, 720.0)
	await await_idle_frame()
	var centre: Vector2 = a._material.get_shader_parameter("focus_centre")
	assert_float(centre.x).is_equal_approx(0.025, 0.001)
	assert_float(centre.y).is_equal_approx(0.025, 0.001)


## The lantern is a flame, not a bulb (visual-overhaul spec §3.2). Driven
## from GDScript rather than from TIME in the shader so the range is a rule
## a test can hold: a light that occasionally drops to nothing reads as a
## rendering fault, and one that never moves reads as a screenshot.
func test_the_lantern_flickers_without_ever_going_out() -> void:
	var a := _atmos()
	await await_idle_frame()
	var seen: Array[float] = []
	for i in 60:
		a._advance_flicker(0.05)
		var f: float = a._material.get_shader_parameter("flicker")
		assert_float(f).is_between(Atmosphere.FLICKER_MIN, Atmosphere.FLICKER_MAX)
		seen.append(f)
	var lowest: float = seen.min()
	var highest: float = seen.max()
	assert_float(highest - lowest) \
		.override_failure_message("the lantern is a bulb: it never moved") \
		.is_greater(0.02)


func test_the_flicker_is_deterministic_for_a_given_elapsed_time() -> void:
	# No engine randomness: two atmospheres advanced the same way agree, so
	# a screenshot of the same frame is the same screenshot.
	var a := _atmos()
	var b := _atmos()
	await await_idle_frame()
	for i in 12:
		a._advance_flicker(0.05)
		b._advance_flicker(0.05)
	assert_float(a._material.get_shader_parameter("flicker")) \
		.is_equal(b._material.get_shader_parameter("flicker"))
