extends GdUnitTestSuite
## Carved stone furniture. Joao's verdict on the interface after the light
## and art passes was "not looking good, not like a real game" -- and the
## cause was that every interactive element was a Godot Control wearing a
## StyleBoxFlat: rounded rectangles, hairline borders, flat fills. That is
## the universal "this is a UI toolkit" tell and no amount of card art fixes
## it, because it is the frame around the art.
##
## These tests hold the rules the furniture has to keep. Appearance is still
## judged from the contact sheet; what is asserted here is that nothing has
## quietly gone back to being a rounded rectangle.


func test_the_theme_has_no_rounded_rectangles_left_in_it() -> void:
	# The single most recognisable app-not-game signal. Carved stone has
	# corners; a UI toolkit has a corner radius.
	var t := UiTheme.build()
	var offenders: Array[String] = []
	for type_name in t.get_stylebox_type_list():
		for box_name in t.get_stylebox_list(type_name):
			var box := t.get_stylebox(box_name, type_name)
			var flat := box as StyleBoxFlat
			if flat == null:
				continue
			var radius := maxi(maxi(flat.corner_radius_top_left, flat.corner_radius_top_right),
				maxi(flat.corner_radius_bottom_left, flat.corner_radius_bottom_right))
			if radius > 0:
				offenders.append("%s/%s r=%d" % [type_name, box_name, radius])
	assert_array(offenders) \
		.override_failure_message("rounded rectangles are back: %s" % ", ".join(offenders)) \
		.is_empty()


func test_buttons_and_panels_are_carved_stone() -> void:
	var t := UiTheme.build()
	for pair in [["normal", "Button"], ["hover", "Button"], ["pressed", "Button"],
			["panel", "PanelContainer"]]:
		var box := t.get_stylebox(String(pair[0]), String(pair[1]))
		assert_object(box as StoneBox) \
			.override_failure_message("%s/%s is not carved" % [pair[1], pair[0]]) \
			.is_not_null()


func test_a_pressed_button_is_actually_depressed() -> void:
	# The bevel inverts: light moves to the bottom edge, so the slab reads as
	# having been pushed into the wall rather than merely recoloured.
	var t := UiTheme.build()
	var rest := t.get_stylebox("normal", "Button") as StoneBox
	var down := t.get_stylebox("pressed", "Button") as StoneBox
	assert_bool(rest.pressed).is_false()
	assert_bool(down.pressed).is_true()


func test_carved_stone_reserves_room_for_its_own_bevel() -> void:
	# Content drawn over the bevel reads as text falling off the edge of the
	# plaque, so the box has to own that margin.
	var box := StoneBox.new()
	box.bevel = 4.0
	var margins := box.get_minimum_size()
	assert_float(margins.x).is_greater_equal(box.bevel * 2.0)
	assert_float(margins.y).is_greater_equal(box.bevel * 2.0)


func test_the_lit_edge_is_warmer_than_the_shadowed_one() -> void:
	# The room is lit by lanterns from above. A bevel lit cold reads as
	# plastic, which is the thing this whole layer exists to stop being.
	var box := StoneBox.new()
	assert_float(box.lit.r).is_greater(box.lit.b)
	assert_float(Palette.luma(box.lit)).is_greater(Palette.luma(box.shade))


func test_a_box_smaller_than_its_own_bevel_still_renders() -> void:
	# Godot hands a StyleBox whatever rect the container computed, including a
	# degenerate one mid-layout. A bevel wider than the box would draw its own
	# edges past each other; this renders one for real and lets a script error
	# in _draw fail the test.
	var box := StoneBox.new()
	box.bevel = 12.0
	var panel: Panel = auto_free(Panel.new())
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = Vector2(2.0, 2.0)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(is_instance_valid(panel)).is_true()
	assert_that(panel.size).is_equal(Vector2(2.0, 2.0))
