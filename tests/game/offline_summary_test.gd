extends GdUnitTestSuite


func _content() -> Content:
	return TestFixtures.content()


func _panel(offline: Dictionary) -> OfflineSummary:
	var p: OfflineSummary = auto_free(OfflineSummary.new())
	add_child(p)
	p.bind(_content(), offline)
	return p


func test_it_reports_the_time_away_and_the_soul_earned() -> void:
	var p := _panel({"elapsed": 3660, "counted": 3660, "capped": false, "soul": 1250.0})
	await await_idle_frame()
	assert_str(p._away.text).contains("1h 1m")
	# The total counts up now, so read it once it has arrived rather than
	# on the frame the panel was bound.
	await get_tree().create_timer(OfflineSummary.COUNT_SECONDS + 0.3).timeout
	assert_str(p._earned.text).is_equal("1.25K")
	assert_bool(p._capped.visible).is_false()


func test_it_says_when_the_cap_cut_the_night_short() -> void:
	var p := _panel({"elapsed": 100000, "counted": 28800, "capped": true, "soul": 400.0})
	await await_idle_frame()
	assert_bool(p._capped.visible).is_true()
	# The time shown is the time that actually paid, not the time away.
	assert_str(p._away.text).contains("8h")


func test_it_is_not_worth_showing_for_a_blink() -> void:
	assert_bool(OfflineSummary.should_show({"elapsed": 0, "counted": 0, "capped": false, "soul": 0.0})).is_false()
	assert_bool(OfflineSummary.should_show({"elapsed": 30, "counted": 30, "capped": false, "soul": 0.4})).is_false()
	assert_bool(OfflineSummary.should_show({"elapsed": 600, "counted": 600, "capped": false, "soul": 8.0})).is_true()


func test_a_capped_return_is_always_worth_showing() -> void:
	assert_bool(OfflineSummary.should_show({"elapsed": 90000, "counted": 28800, "capped": true, "soul": 0.0})).is_true()


func test_dismiss_reports_once() -> void:
	var p := _panel({"elapsed": 3600, "counted": 3600, "capped": false, "soul": 52.0})
	var seen := [0]
	p.dismissed.connect(func() -> void: seen[0] += 1)
	p._button.emit_signal("pressed")
	await await_idle_frame()
	assert_int(seen[0]).is_equal(1)


func test_a_missing_key_falls_back_instead_of_crashing() -> void:
	var p := _panel({})
	await await_idle_frame()
	assert_str(p._earned.text).is_equal("0")
	assert_bool(p._capped.visible).is_false()


func test_the_title_comes_from_the_string_table() -> void:
	var c := _content()
	var p := _panel({"elapsed": 3600, "counted": 3600, "capped": false, "soul": 52.0})
	await await_idle_frame()
	assert_str(p._title.text).is_equal(c.text("ui.offline.title"))


## The payoff moment of an idle game. It was a dialog with an OK button; the
## number now counts from zero and Soul rises behind the card.
func test_the_total_counts_up_from_zero_rather_than_appearing() -> void:
	var s: OfflineSummary = auto_free(OfflineSummary.new())
	add_child(s)
	s.bind(TestFixtures.content(),
		{"elapsed": 30000, "counted": 28800, "capped": true, "soul": 4210.0})
	await await_idle_frame()
	# Mid-count it has not arrived: that is the whole point of it counting.
	assert_float(s._earned_ticker.value).is_less(4210.0)
	await get_tree().create_timer(OfflineSummary.COUNT_SECONDS + 0.3).timeout
	assert_float(s._earned_ticker.value).is_equal(4210.0)
	assert_str(s._earned.text).is_equal(Num.short(4210.0))


func test_soul_rises_behind_the_card() -> void:
	var s: OfflineSummary = auto_free(OfflineSummary.new())
	add_child(s)
	await await_idle_frame()
	assert_object(s._motes).is_not_null()
	assert_bool(s._motes.emitting).is_true()
	# Behind the card, or it draws over the number it is celebrating.
	assert_int(s.get_children().find(s._motes)).is_equal(0)


func _ghost(name: String, floor: int) -> Ghost:
	var hero := Hero.create(_content(), "sexton", name, {}, 1)
	return Ghost.from_expedition(hero, floor, 0)


func test_it_reports_the_ghosts_the_guild_placed_while_you_were_gone() -> void:
	var p := _panel({"elapsed": 7200, "counted": 7200, "capped": false, "soul": 90.0,
		"returned": [_ghost("Wren", 4), _ghost("Cass", 2)]})
	await await_idle_frame()
	assert_bool(p._returned_head.visible).is_true()
	assert_array(p._returned.get_children()).has_size(2)
	var first: HBoxContainer = p._returned.get_child(0)
	assert_str((first.get_child(1) as Label).text).contains("Wren")
	assert_str((first.get_child(1) as Label).text).contains("4")


func test_the_section_stays_out_of_the_way_when_nobody_was_sent() -> void:
	var p := _panel({"elapsed": 7200, "counted": 7200, "capped": false, "soul": 90.0})
	await await_idle_frame()
	assert_bool(p._returned_head.visible).is_false()
	assert_array(p._returned.get_children()).is_empty()


func test_a_ghost_arriving_is_worth_showing_however_little_it_earned() -> void:
	assert_bool(OfflineSummary.should_show({"elapsed": 300, "counted": 300,
		"capped": false, "soul": 0.1, "returned": [_ghost("Wren", 1)]})).is_true()


func test_rebinding_does_not_stack_the_same_arrivals_twice() -> void:
	var p := _panel({"elapsed": 60, "counted": 60, "capped": false, "soul": 1.0,
		"returned": [_ghost("Wren", 4)]})
	p.bind(_content(), {"elapsed": 60, "counted": 60, "capped": false, "soul": 1.0,
		"returned": [_ghost("Cass", 2)]})
	await await_idle_frame()
	assert_array(p._returned.get_children()).has_size(1)
