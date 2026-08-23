extends GdUnitTestSuite


func _row(c: Campaign, floor: int) -> FloorRow:
	var r: FloorRow = auto_free(FloorRow.new())
	add_child(r)
	r.size = Vector2(420.0, FloorRow.ROW_HEIGHT)
	r.bind(c, floor)
	return r


func test_the_founder_floor_shows_ghosts_output_and_saturation() -> void:
	var c := TestFixtures.campaign()
	var r := _row(c, 1)
	await await_idle_frame()
	assert_int(r.floor_number).is_equal(1)
	assert_float(r.output_per_hour).is_equal_approx(52.0, 0.0001)
	assert_float(r.saturation).is_greater(0.0)
	assert_int(r._marks.get_child_count()).is_equal(1)
	assert_str(r._output.text).is_equal("52/h")
	assert_bool(r.is_waypoint).is_true()


func test_an_empty_floor_shows_no_ghosts_and_no_numbers() -> void:
	var c := TestFixtures.campaign()
	var r := _row(c, 5)
	await await_idle_frame()
	assert_int(r._marks.get_child_count()).is_equal(0)
	assert_str(r._output.text).is_equal("")
	assert_str(r._farmed.text).is_equal("")
	assert_bool(r.is_waypoint).is_false()


func test_the_band_takes_the_biome_accent() -> void:
	var c := TestFixtures.campaign()
	var r := _row(c, 1)
	await await_idle_frame()
	assert_that(r.accent).is_equal(Palette.biome_accent("catacombs"))


func test_rebinding_replaces_the_marks_rather_than_stacking_them() -> void:
	var c := TestFixtures.campaign()
	var r := _row(c, 1)
	await await_idle_frame()
	r.bind(c, 1)
	await await_idle_frame()
	r.bind(c, 1)
	await await_idle_frame()
	assert_int(r._marks.get_child_count()).is_equal(1)


func test_a_crowded_floor_caps_the_marks_and_counts_the_rest() -> void:
	var c := TestFixtures.campaign()
	var founder := c.ladder.ghosts[0]
	for i in range(FloorRow.MAX_MARKS + 3):
		var echo := founder.clone_as_echo(1, 1000)
		c.ladder.add(echo)
	var r := _row(c, 1)
	await await_idle_frame()
	assert_int(r._marks.get_child_count()).is_equal(FloorRow.MAX_MARKS)
	assert_str(r._overflow.text).is_equal("+4")


func test_it_draws_at_zero_size_without_crashing() -> void:
	var c := TestFixtures.campaign()
	var r: FloorRow = auto_free(FloorRow.new())
	add_child(r)
	r.size = Vector2.ZERO
	r.bind(c, 1)
	r.queue_redraw()
	await await_idle_frame()
	assert_int(r.floor_number).is_equal(1)
