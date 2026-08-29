extends GdUnitTestSuite
## The hand is the one piece of the fight that did not move into 3D, so the
## arc that made it read as a hand of cards has to survive the port. `fan` is
## a pure function of a count and a rectangle, which is the part the 2D
## version could only be checked by eye.


func _area() -> Rect2:
	return Rect2(60.0, 0.0, 500.0, 360.0)


func _hand() -> HandView:
	var h: HandView = auto_free(HandView.new())
	h.bind(TestFixtures.content())
	add_child(h)
	h.size = Vector2(640.0, 360.0)
	return h


func _fight(cards: Array) -> FightState:
	var f := TestFixtures.bare_state()
	TestFixtures.give_hand(f, cards)
	return f


func test_one_card_sits_in_the_middle_and_does_not_tilt() -> void:
	var seats := HandView.fan(1, _area())
	assert_array(seats).has_size(1)
	var seat: Dictionary = seats[0]
	assert_float(float(seat["angle"])).is_equal(0.0)
	var centre_x := float(seat["position"].x) + HandView.card_size().x * 0.5
	assert_float(centre_x).is_equal_approx(_area().position.x + _area().size.x * 0.5, 0.5)


func test_the_fan_is_symmetric_about_its_centre() -> void:
	var seats := HandView.fan(5, _area())
	assert_array(seats).has_size(5)
	var first: Dictionary = seats[0]
	var last: Dictionary = seats[4]
	assert_float(float(first["angle"])).is_equal_approx(-float(last["angle"]), 0.0001)
	assert_float(float(first["position"].y)).is_equal_approx(float(last["position"].y), 0.01)
	var mid: Dictionary = seats[2]
	assert_float(float(mid["angle"])).is_equal_approx(0.0, 0.0001)


func test_the_outer_cards_tilt_outward_and_hang_lower() -> void:
	var seats := HandView.fan(5, _area())
	var left: Dictionary = seats[0]
	var mid: Dictionary = seats[2]
	var right: Dictionary = seats[4]
	assert_float(float(left["angle"])).is_less(0.0)
	assert_float(float(right["angle"])).is_greater(0.0)
	# "Lower" is a larger y in screen space -- the ends of a held fan drop.
	assert_float(float(left["position"].y)).is_greater(float(mid["position"].y))


func test_cards_never_overlap_closer_than_their_text_allows() -> void:
	# The old floor was three quarters of a card, which let the card in front
	# eat the rules text of the one behind it. A ten-card hand is where that
	# shows.
	var seats := HandView.fan(10, _area())
	for i in range(1, seats.size()):
		var step: float = float(seats[i]["position"].x) - float(seats[i - 1]["position"].x)
		assert_float(step).is_greater_equal(CardView.text_safe_step() * HandView.CARD_SCALE - 0.01)


func test_the_hand_stays_inside_the_area_it_was_given() -> void:
	var seats := HandView.fan(4, _area())
	for raw in seats:
		var seat: Dictionary = raw
		assert_float(float(seat["position"].x)).is_greater_equal(_area().position.x - 0.01)
		assert_float(float(seat["position"].y) + HandView.card_size().y).is_less_equal(_area().end.y + 0.01)


func test_an_empty_hand_seats_nobody() -> void:
	assert_array(HandView.fan(0, _area())).is_empty()


func test_it_builds_one_view_per_card_bound_to_that_card() -> void:
	var h := _hand()
	var f := _fight(["strike", "brace", "strike"])
	h.show_hand(f, {0: true, 2: true})
	assert_array(h.views).has_size(3)
	for i in 3:
		assert_int(h.views[i].hand_index).is_equal(i)
	assert_bool(h.views[0].playable).is_true()
	assert_bool(h.views[1].playable).is_false()


func test_a_shorter_hand_hides_the_views_it_no_longer_needs() -> void:
	# Hidden, not destroyed: a hand changes size every turn and rebuilding the
	# nodes each draw throws away the hover state and the fly-in with them.
	var h := _hand()
	h.show_hand(_fight(["strike", "brace", "strike"]), {})
	h.show_hand(_fight(["strike"]), {})
	assert_array(h.views).has_size(3)
	assert_int(h.visible_count()).is_equal(1)
	assert_bool(h.views[2].visible).is_false()


func test_pressing_a_card_reports_its_hand_index() -> void:
	var h := _hand()
	h.show_hand(_fight(["strike", "brace"]), {0: true, 1: true})
	var seen: Array = []
	h.card_pressed.connect(func(i: int) -> void: seen.append(i))
	h.views[1].press()
	assert_array(seen).is_equal([1])


func test_selecting_one_card_deselects_the_others() -> void:
	var h := _hand()
	h.show_hand(_fight(["strike", "brace"]), {0: true, 1: true})
	h.select(1)
	assert_int(h.selected).is_equal(1)
	assert_bool(h.views[1].selected).is_true()
	assert_bool(h.views[0].selected).is_false()
	h.select(-1)
	assert_bool(h.views[1].selected).is_false()


func test_the_hand_leaves_the_room_visible() -> void:
	# Cards were authored for a screen they owned. Over a live 3D room a
	# full-size five-card hand hides the enemies completely -- the fight
	# covering up the fight.
	var seats := HandView.fan(5, Rect2(0.0, 0.0, 640.0, 360.0))
	var top := 1e9
	for raw in seats:
		top = minf(top, float((raw as Dictionary)["position"].y))
	assert_float(top).override_failure_message("the hand reaches too far up the screen").is_greater(360.0 * 0.5)
	assert_float(HandView.card_size().y).is_less(CardView.CARD_SIZE.y)


func test_hovering_a_card_lifts_it_and_drops_the_last_one() -> void:
	var h := _hand()
	h.show_hand(_fight(["strike", "brace", "strike"]), {})
	h.hover(1)
	assert_int(h.hovered).is_equal(1)
	h.hover(2)
	assert_int(h.hovered).is_equal(2)
	h.hover(-1)
	assert_int(h.hovered).is_equal(-1)


func test_a_cleared_hand_forgets_what_was_hovered() -> void:
	var h := _hand()
	h.show_hand(_fight(["strike"]), {})
	h.hover(0)
	h.clear()
	assert_int(h.hovered).is_equal(-1)


func test_cards_are_not_left_touching_edge_to_edge() -> void:
	# A step capped at the card's own width leaves a five-card hand mushy at
	# rest, however good the hover is.
	var seats := HandView.fan(5, Rect2(60.0, 0.0, 500.0, 360.0))
	for i in range(1, seats.size()):
		var step: float = float(seats[i]["position"].x) - float(seats[i - 1]["position"].x)
		assert_float(step).is_greater(HandView.card_size().x * 1.05)


func test_the_hand_leaves_room_for_the_vitals_and_the_end_turn_button() -> void:
	# A guessed gutter put the vitals plate straight over the first card.
	var h := _hand()
	assert_float(h.hand_area().position.x).is_greater_equal(HeroPanel.PANEL_SIZE.x)
	assert_float(h.hand_area().end.x).is_less(640.0)
