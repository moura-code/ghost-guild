extends GdUnitTestSuite


func test_biome_accents_resolve_and_fall_back() -> void:
	assert_that(Palette.biome_accent("catacombs")).is_equal(Palette.BIOME_ACCENTS["catacombs"])
	assert_that(Palette.biome_accent("fungal_deep")).is_equal(Palette.BIOME_ACCENTS["fungal_deep"])
	assert_that(Palette.biome_accent("no_such_biome")).is_equal(Palette.BONE_DIM)


func test_text_and_ground_are_opaque_and_ghosts_are_translucent_cyan() -> void:
	assert_float(Palette.BONE.a).is_equal(1.0)
	assert_float(Palette.STONE.a).is_equal(1.0)
	assert_float(Palette.GHOST.a).is_less(1.0)
	assert_float(Palette.GHOST.b).is_greater(Palette.GHOST.r)


func test_the_theme_builds_with_the_stone_palette() -> void:
	var t := UiTheme.build()
	assert_object(t).is_not_null()
	assert_int(t.default_font_size).is_equal(UiTheme.FONT_BODY)
	assert_that(t.get_color("font_color", "Label")).is_equal(Palette.BONE)
	assert_object(t.get_stylebox("panel", "PanelContainer")).is_not_null()
	assert_object(t.get_stylebox("normal", "Button")).is_not_null()
	assert_object(t.get_stylebox("disabled", "Button")).is_not_null()


func test_panel_box_carries_the_colour_it_was_given() -> void:
	var sb := UiTheme.panel_box(Palette.STONE_RAISED)
	assert_that(sb.bg_color).is_equal(Palette.STONE_RAISED)
	assert_int(sb.border_width_left).is_equal(1)


func test_label_helpers_set_size_and_colour() -> void:
	var l: Label = auto_free(UiTheme.number("52/h"))
	assert_str(l.text).is_equal("52/h")
	assert_int(l.get_theme_font_size("font_size")).is_equal(UiTheme.FONT_NUMBER)
	var s: Label = auto_free(UiTheme.small("floor 1"))
	assert_int(s.get_theme_font_size("font_size")).is_equal(UiTheme.FONT_SMALL)
