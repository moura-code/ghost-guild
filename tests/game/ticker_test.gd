extends GdUnitTestSuite
## Numbers that count rather than snap. A value that jumps reads as a field
## being overwritten; a value that climbs reads as earnings. The Ladder's
## Soul counter already did this by hand -- Ticker is that behaviour pulled
## out so Coin, HP, yield and the offline total can have it too.
##
## Tested for state, never for interpolation: that it arrives, that it
## arrives exactly, and that it survives the things that kill tweens.


func _label() -> Label:
	var l: Label = auto_free(Label.new())
	add_child(l)
	return l


func test_a_ticker_arrives_at_exactly_its_target() -> void:
	var l := _label()
	var t := Ticker.new(l, Num.short)
	t.to(100.0)
	await get_tree().create_timer(t.seconds + 0.2).timeout
	assert_float(t.value).is_equal(100.0)
	assert_str(l.text).is_equal(Num.short(100.0))


func test_the_first_value_lands_without_counting() -> void:
	# Opening a screen must not animate every number up from zero; the count
	# is for a change the player caused, not for the screen appearing.
	var l := _label()
	var t := Ticker.new(l, Num.short)
	t.set_now(4210.0)
	assert_float(t.value).is_equal(4210.0)
	assert_str(l.text).is_equal(Num.short(4210.0))


func test_retargeting_mid_flight_lands_on_the_new_value() -> void:
	var l := _label()
	var t := Ticker.new(l, Num.short)
	t.to(1000.0)
	await get_tree().create_timer(0.05).timeout
	t.to(50.0)
	await get_tree().create_timer(t.seconds + 0.2).timeout
	assert_float(t.value) \
		.override_failure_message("a second target stacked instead of replacing") \
		.is_equal(50.0)
	assert_str(l.text).is_equal(Num.short(50.0))


func test_a_ticker_counts_down_as_well_as_up() -> void:
	var l := _label()
	var t := Ticker.new(l, Num.short)
	t.set_now(80.0)
	t.to(20.0)
	await get_tree().create_timer(t.seconds + 0.2).timeout
	assert_float(t.value).is_equal(20.0)


func test_a_freed_label_does_not_take_the_ticker_with_it() -> void:
	# Screens are rebuilt and rebound constantly; a ticker still counting
	# toward a label that has been freed must not crash the frame.
	var l := Label.new()
	add_child(l)
	var t := Ticker.new(l, Num.short)
	t.to(500.0)
	l.free()
	await get_tree().create_timer(t.seconds + 0.2).timeout
	assert_float(t.value).is_equal(500.0)


func test_the_formatter_is_used_rather_than_str() -> void:
	var l := _label()
	var t := Ticker.new(l, Num.rate)
	t.set_now(52.0)
	assert_str(l.text).is_equal("52/h")


func test_a_target_it_is_already_at_is_not_worth_animating() -> void:
	var l := _label()
	var t := Ticker.new(l, Num.short)
	t.set_now(7.0)
	t.to(7.0)
	assert_bool(t.is_counting()).is_false()
