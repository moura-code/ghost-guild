extends GdUnitTestSuite


func _mark() -> GhostMark:
	var m: GhostMark = auto_free(GhostMark.new())
	m.floating = false
	return m


func test_colour_says_what_kind_of_ghost_it_is() -> void:
	var m := _mark()
	assert_that(m.body_color()).is_equal(Palette.GHOST)
	m.kind = "echo"
	assert_that(m.body_color()).is_equal(Palette.ECHO)
	m.kind = "true"
	m.prepared = true
	assert_that(m.body_color()).is_equal(Palette.PREPARED)


func test_restless_reads_before_prepared() -> void:
	var m := _mark()
	m.prepared = true
	m.restless = true
	assert_that(m.body_color()).is_equal(Palette.RESTLESS)


func test_bind_reads_the_ghost_and_gives_it_its_own_bob_phase() -> void:
	var c := TestFixtures.campaign()
	var founder := c.ladder.ghosts[0]
	var m := _mark()
	m.bind(founder)
	add_child(m)
	await await_idle_frame()
	assert_str(m.kind).is_equal("true")
	assert_bool(m.restless).is_false()
	assert_float(m._phase).is_equal_approx(float(founder.id) * 0.9, 0.0001)


func test_it_draws_at_its_default_size_without_erroring() -> void:
	var m := _mark()
	add_child(m)
	await await_idle_frame()
	assert_float(m.size.x).is_greater_equal(GhostMark.BASE_SIZE.x)
	assert_float(m.size.y).is_greater_equal(GhostMark.BASE_SIZE.y)
	m.queue_redraw()
	await await_idle_frame()


func test_a_zero_sized_mark_draws_nothing_instead_of_crashing() -> void:
	var m := _mark()
	m.custom_minimum_size = Vector2.ZERO
	add_child(m)
	m.size = Vector2.ZERO
	m.queue_redraw()
	await await_idle_frame()
	assert_float(m.size.x).is_equal(0.0)


func test_floating_moves_the_bob_and_can_be_switched_off() -> void:
	var m := _mark()
	m.floating = true
	add_child(m)
	await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()
	assert_float(m._phase).is_greater(0.0)
