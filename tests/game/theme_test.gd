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


## The light model (visual-overhaul spec §3.1). These assert the *rules* the
## palette has to obey, because appearance cannot be asserted and the failure
## that produced this overhaul was a rule failure: every stone colour sat
## between 4% and 42% luminance, so nothing separated from anything.
func test_the_value_ladder_climbs_without_ties() -> void:
	var ladder := [Palette.ABYSS, Palette.STONE, Palette.STONE_RAISED,
		Palette.STONE_HIGH, Palette.STONE_EDGE, Palette.BONE]
	for i in range(1, ladder.size()):
		assert_float(Palette.luma(ladder[i])).is_greater(Palette.luma(ladder[i - 1]))


func test_the_value_ladder_spans_most_of_the_range() -> void:
	# The whole point of the overhaul. A palette whose darkest and lightest
	# are 40% apart renders as fog no matter what is drawn with it.
	assert_float(Palette.luma(Palette.BONE) - Palette.luma(Palette.ABYSS)).is_greater(0.80)


func test_light_is_warm_and_only_ghosts_are_cool() -> void:
	# Warm light against cold shadow is the contrast the art direction runs
	# on; a single hue is what it used to run on.
	assert_float(Palette.EDGE_LIGHT.r).is_greater(Palette.EDGE_LIGHT.b)
	assert_float(Palette.LANTERN.r).is_greater(Palette.LANTERN.b)
	# Ghost cyan is the only cool accent, so nothing competes with it.
	assert_float(Palette.GHOST.b).is_greater(Palette.GHOST.r)
	for c in [Palette.STONE, Palette.STONE_RAISED, Palette.STONE_HIGH, Palette.BONE]:
		assert_float((c as Color).b - (c as Color).r).is_less(0.10)


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


func test_hovering_a_button_lights_it_like_a_lantern() -> void:
	# Interactive things catch the warm light; ghost cyan stays reserved for
	# the dead, which are the only cool thing in the game.
	var t := UiTheme.build()
	assert_that(t.get_color("font_hover_color", "Button")).is_equal(Palette.LANTERN)
	var hover := t.get_stylebox("hover", "Button") as StyleBoxFlat
	assert_object(hover).is_not_null()
	assert_float(hover.border_color.r).is_greater(hover.border_color.b)
	var normal := t.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_float(Palette.luma(hover.bg_color)) \
		.override_failure_message("hover is not brighter than rest, so nothing happens on hover") \
		.is_greater(Palette.luma(normal.bg_color))
