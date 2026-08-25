extends GdUnitTestSuite
## Drawn decor. The review that produced the visual overhaul found half the
## screens were a small island of content in a large empty field -- the
## Séance was a black box with two numbers in one corner. Props are what
## fills that space without an artist.
##
## Tested for geometry and determinism, never for pixels: that a prop stays
## inside the box it was given, and that the same seed lays out the same way
## twice so a screenshot of the same frame is the same screenshot.


func _prop(p: Prop) -> Prop:
	auto_free(p)
	add_child(p)
	return p


func test_every_kind_has_a_factory_that_produces_something_with_size() -> void:
	# Drives over the enum, so adding a Kind without a factory fails here
	# rather than drawing nothing on some screen months later.
	for kind in Prop.Kind.values():
		var p := _prop(Prop.of(kind))
		assert_int(p.kind).is_equal(kind)
		assert_float(p.size.x) \
			.override_failure_message("kind %d has no width" % kind).is_greater(0.0)
		assert_float(p.size.y) \
			.override_failure_message("kind %d has no height" % kind).is_greater(0.0)


func test_scattered_props_keep_their_pieces_inside_their_own_box() -> void:
	# A bone pile that draws outside its rect lands on top of the text the
	# screen put next to it.
	for kind in [Prop.Kind.BONES, Prop.Kind.RUBBLE]:
		var p := _prop(Prop.of(kind))
		p.size = Vector2(120.0, 40.0)
		for point in p.scatter():
			assert_bool(Rect2(Vector2.ZERO, p.size).has_point(point)) \
				.override_failure_message("kind %d scattered %s outside %s" % [kind, point, p.size]) \
				.is_true()


func test_the_same_seed_scatters_the_same_way_twice() -> void:
	var a := _prop(Prop.of(Prop.Kind.BONES, 7))
	var b := _prop(Prop.of(Prop.Kind.BONES, 7))
	a.size = Vector2(100.0, 30.0)
	b.size = Vector2(100.0, 30.0)
	assert_array(a.scatter()).is_equal(b.scatter())


func test_a_different_seed_scatters_differently() -> void:
	# Otherwise every bone pile in the game is the same bone pile.
	var a := _prop(Prop.of(Prop.Kind.BONES, 1))
	var b := _prop(Prop.of(Prop.Kind.BONES, 2))
	a.size = Vector2(100.0, 30.0)
	b.size = Vector2(100.0, 30.0)
	assert_array(a.scatter()).is_not_equal(b.scatter())


func test_a_collapsed_prop_scatters_nothing_rather_than_dividing_by_zero() -> void:
	# Control re-clamps `size` up to `custom_minimum_size`, so a prop can only
	# actually reach zero once its minimum is cleared -- which is exactly what
	# a container with no room left to give it does.
	var p := _prop(Prop.of(Prop.Kind.RUBBLE))
	p.custom_minimum_size = Vector2.ZERO
	p.size = Vector2.ZERO
	assert_that(p.size).is_equal(Vector2.ZERO)
	assert_array(p.scatter()).is_empty()


func test_a_candle_flame_moves_but_never_gutters_out() -> void:
	var p := _prop(Prop.of(Prop.Kind.CANDLE))
	var seen: Array[float] = []
	for i in 40:
		p.advance(0.06)
		assert_float(p.flame()).is_between(Prop.FLAME_MIN, 1.0)
		seen.append(p.flame())
	assert_float(seen.max() - seen.min()) \
		.override_failure_message("the flame is painted on") \
		.is_greater(0.05)


func test_props_take_their_colour_from_the_palette() -> void:
	# The no-colour-literals-outside-Palette rule, held where it is easiest
	# to break it: decor is exactly the sort of thing that grows hex codes.
	var p := _prop(Prop.of(Prop.Kind.CHAIN))
	assert_that(p.tint).is_equal(Palette.STONE_EDGE)
	var candle := _prop(Prop.of(Prop.Kind.CANDLE))
	assert_that(candle.tint).is_equal(Palette.LANTERN)


func test_a_container_cannot_stretch_a_prop_out_of_shape() -> void:
	# A VBox fills its children by default, which turned an 18px candle into
	# a 140px one and its halo into a grey plate across the screen. Decor has
	# proportions; layout is not entitled to them.
	var box := VBoxContainer.new()
	auto_free(box)
	add_child(box)
	box.size = Vector2(400.0, 300.0)
	var candle := Prop.of(Prop.Kind.CANDLE)
	var wanted := candle.size
	box.add_child(candle)
	await await_idle_frame()
	assert_that(candle.size) \
		.override_failure_message("the container stretched the candle to %s" % candle.size) \
		.is_equal(wanted)
