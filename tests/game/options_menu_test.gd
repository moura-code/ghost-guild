extends GdUnitTestSuite
## Every control applies live: a sensitivity you can only judge after closing
## the menu is a sensitivity you will get wrong three times before you get it
## right.


func _options(s: Settings = null) -> OptionsMenu:
	var m: OptionsMenu = auto_free(OptionsMenu.new())
	add_child(m)
	m.build(TestFixtures.content(), s if s != null else Settings.defaults())
	return m


func test_it_offers_the_five_things_worth_offering() -> void:
	var m := _options()
	for id in ["sensitivity", "fov", "master_volume"]:
		assert_bool(m.sliders.has(id)).override_failure_message("no slider for %s" % id).is_true()
	for id in ["invert_y", "fullscreen"]:
		assert_bool(m.checks.has(id)).override_failure_message("no toggle for %s" % id).is_true()


func test_the_sliders_open_where_the_settings_already_are() -> void:
	var s := Settings.defaults()
	s.sensitivity = 1.7
	s.fov = 100.0
	var m := _options(s)
	assert_float(float((m.sliders["sensitivity"] as HSlider).value)).is_equal_approx(1.7, 0.001)
	assert_float(float((m.sliders["fov"] as HSlider).value)).is_equal_approx(100.0, 0.001)


func test_a_slider_cannot_be_dragged_out_of_range() -> void:
	var m := _options()
	var slider: HSlider = m.sliders["sensitivity"]
	assert_float(slider.min_value).is_equal_approx(Settings.SENSITIVITY_MIN, 0.001)
	assert_float(slider.max_value).is_equal_approx(Settings.SENSITIVITY_MAX, 0.001)


func test_moving_a_control_changes_the_settings_and_says_so() -> void:
	var s := Settings.defaults()
	var m := _options(s)
	var heard: Array = []
	m.changed.connect(func(out: Settings) -> void: heard.append(out.sensitivity))
	(m.sliders["sensitivity"] as HSlider).value = 2.2
	assert_float(s.sensitivity).is_equal_approx(2.2, 0.001)
	assert_array(heard).is_not_empty()


func test_toggling_invert_reaches_the_settings() -> void:
	var s := Settings.defaults()
	var m := _options(s)
	(m.checks["invert_y"] as CheckBox).button_pressed = true
	assert_bool(s.invert_y).is_true()


func test_back_says_so() -> void:
	var m := _options()
	var closed := [0]
	m.closed.connect(func() -> void: closed[0] += 1)
	for child in m.find_children("*", "Button", true, false):
		if (child as Button).text == TestFixtures.content().text("ui.menu.back"):
			(child as Button).emit_signal("pressed")
	assert_int(int(closed[0])).is_equal(1)
