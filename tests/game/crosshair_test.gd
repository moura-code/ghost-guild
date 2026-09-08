extends GdUnitTestSuite


func _crosshair() -> Crosshair:
	var c: Crosshair = auto_free(Crosshair.new())
	add_child(c)
	c.size = Vector2(640.0, 360.0)
	return c


func test_it_rests_closed() -> void:
	assert_float(_crosshair().openness).is_equal(0.0)


func test_a_target_opens_it_and_losing_the_target_closes_it() -> void:
	var c := _crosshair()
	c.set_target(true)
	await await_millis(200)
	assert_float(c.openness).is_equal_approx(1.0, 0.05)
	c.set_target(false)
	await await_millis(200)
	assert_float(c.openness).is_equal_approx(0.0, 0.05)


func test_openness_never_leaves_its_range() -> void:
	var c := _crosshair()
	c.openness = 4.0
	assert_float(c.openness).is_equal(1.0)
	c.openness = -4.0
	assert_float(c.openness).is_equal(0.0)


func test_it_never_swallows_a_click_meant_for_a_card() -> void:
	assert_int(_crosshair().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
