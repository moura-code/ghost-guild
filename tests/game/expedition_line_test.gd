extends GdUnitTestSuite
## One expedition slot: who is in the field, or the button that fills it.


func _content() -> Content:
	return TestFixtures.content()


func _line() -> ExpeditionLine:
	var l: ExpeditionLine = auto_free(ExpeditionLine.new())
	# The game's own theme, or every measurement here is Godot's 16px default
	# rather than the 8px the HUD is authored at.
	l.theme = UiTheme.build()
	add_child(l)
	return l


func _expedition(seconds: int = 600) -> Expedition:
	var e := Expedition.new()
	e.id = 3
	e.started_at = 1000
	e.seconds = seconds
	e.survival = 0.8
	var hero := Hero.create(_content(), "sexton", "Wren", {}, 1)
	e.ghost = Ghost.from_expedition(hero, 4, 1000)
	return e


func test_an_empty_slot_offers_to_send_somebody() -> void:
	var l := _line()
	l.bind(_content(), null, 1000)
	await await_idle_frame()
	assert_bool(l._send.visible).is_true()
	assert_bool(l._bar.visible).is_false()
	assert_float(l._mark.modulate.a).is_equal(0.0)
	assert_str(l._name.text).is_equal(_content().text("ui.expedition.none"))


func test_a_filled_slot_says_who_went_and_how_deep() -> void:
	var l := _line()
	var e := _expedition()
	l.bind(_content(), e, 1000)
	await await_idle_frame()
	assert_bool(l._send.visible).is_false()
	assert_float(l._mark.modulate.a).is_equal(1.0)
	assert_str(l._name.text).contains("Wren")
	assert_str(l._name.text).contains("4")
	assert_str(l.tooltip_text).contains("takes the watch")


func test_it_counts_down_rather_than_up() -> void:
	var l := _line()
	var e := _expedition(600)
	l.bind(_content(), e, 1000)
	var early := l._detail.text
	l.bind(_content(), e, 1000 + 480)
	assert_str(l._detail.text).is_not_equal(early)
	assert_str(l._detail.text).contains("2m")


func test_the_bar_fills_as_the_clock_runs() -> void:
	var l := _line()
	var e := _expedition(600)
	l.bind(_content(), e, 1000)
	assert_float(l._progress).is_equal(0.0)
	l.bind(_content(), e, 1300)
	assert_float(l._progress).is_equal_approx(0.5, 0.001)
	l.bind(_content(), e, 99_999)
	assert_float(l._progress).is_equal(1.0)


func test_both_states_are_the_same_row() -> void:
	# An open slot and a filled one sit next to each other. Different heights
	# is what made the first version of this band twice as tall as it needed.
	var filled := _line()
	filled.bind(_content(), _expedition(), 1000)
	var open := _line()
	open.bind(_content(), null, 1000)
	await await_idle_frame()
	assert_float(open.get_combined_minimum_size().y).is_equal(
		filled.get_combined_minimum_size().y)


func test_pressing_send_reports_it_and_nothing_else() -> void:
	var l := _line()
	l.bind(_content(), null, 1000)
	var fired := [0]
	l.send_pressed.connect(func() -> void: fired[0] += 1)
	l._send.pressed.emit()
	assert_int(fired[0]).is_equal(1)
