extends GdUnitTestSuite
## The HUD carries one scale for the whole 2D layer, which is what lets thirty
## widgets authored against a 640x360 viewport keep working over a 3D world
## rendered at native resolution.


func _hud() -> HudRoot:
	var h: HudRoot = auto_free(HudRoot.new())
	add_child(h)
	return h


func test_the_reference_window_scales_by_a_whole_number() -> void:
	assert_float(HudRoot.scale_for(Vector2(1280, 720))).is_equal_approx(2.0, 0.001)
	assert_float(HudRoot.scale_for(Vector2(1920, 1080))).is_equal_approx(3.0, 0.001)


func test_an_odd_window_scales_fractionally_rather_than_leaving_bars() -> void:
	# The pixel-art direction needed integer scaling. It died with PaletteLayer,
	# and a 1600x900 window should fill rather than letterbox.
	assert_float(HudRoot.scale_for(Vector2(1600, 900))).is_equal_approx(2.5, 0.001)


func test_the_narrower_axis_decides() -> void:
	assert_float(HudRoot.scale_for(Vector2(2560, 720))).is_equal_approx(2.0, 0.001)


func test_a_window_smaller_than_the_reference_does_not_shrink_the_text() -> void:
	assert_float(HudRoot.scale_for(Vector2(320, 180))).is_equal_approx(1.0, 0.001)


func test_the_ui_covers_the_window_once_scaled() -> void:
	var h := _hud()
	h.fit(Vector2(1280, 720))
	assert_float(h.ui.scale.x).is_equal_approx(2.0, 0.001)
	assert_vector(h.ui.size).is_equal_approx(Vector2(640, 360), Vector2.ONE * 0.01)


func test_showing_a_panel_replaces_whatever_was_there() -> void:
	var h := _hud()
	var first: Control = Control.new()
	var second: Control = Control.new()
	h.show_panel(first)
	assert_object(h.panel).is_same(first)
	h.show_panel(second)
	await await_idle_frame()
	assert_object(h.panel).is_same(second)
	assert_bool(is_instance_valid(first)).is_false()


func test_clearing_the_panel_leaves_nothing_behind() -> void:
	var h := _hud()
	h.show_panel(Control.new())
	h.clear_panel()
	await await_idle_frame()
	assert_object(h.panel).is_null()
	assert_bool(h.has_panel()).is_false()


func test_the_pointer_is_free_when_a_panel_wants_it_and_captured_otherwise() -> void:
	# Asserted on the recorded intent, not on Input.get_mouse_mode: CAPTURED
	# does not stick under --headless because there is no window to capture a
	# cursor into, so the engine reads back VISIBLE whatever it was told.
	var h := _hud()
	h.set_pointer(true)
	assert_bool(h.pointer_free).is_true()
	h.set_pointer(false)
	assert_bool(h.pointer_free).is_false()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func test_showing_a_panel_frees_the_pointer_so_it_can_be_clicked() -> void:
	var h := _hud()
	h.set_pointer(false)
	h.show_panel(Control.new())
	assert_bool(h.pointer_free).is_true()


func test_a_panel_darkens_the_room_behind_it() -> void:
	# Bone-white text on bright ochre stone is legible in spite of the
	# background rather than because of it.
	var h := _hud()
	h.fit(Vector2(1280.0, 720.0))
	assert_float(h.dim.color.a).is_equal(0.0)
	h.set_dim(true)
	await await_millis(220)
	assert_float(h.dim.color.a).is_equal_approx(HudRoot.DIM_ALPHA, 0.05)
	h.set_dim(false)
	await await_millis(220)
	assert_float(h.dim.color.a).is_equal_approx(0.0, 0.05)


func test_the_dim_covers_the_whole_window_not_the_scaled_space() -> void:
	var h := _hud()
	h.fit(Vector2(1280.0, 720.0))
	assert_vector(h.dim.size).is_equal_approx(Vector2(1280.0, 720.0), Vector2.ONE * 0.01)


func test_the_dim_never_swallows_a_click() -> void:
	assert_int(_hud().dim.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
