extends GdUnitTestSuite
## When your dead start agreeing with each other (spec §5.6).


func _content() -> Content:
	return TestFixtures.content()


## A ghost whose deck is `count` copies of one card, so its archetype is that
## card's tag and nothing else.
func _ghost(card_id: String, floor: int, strength: float = 40.0) -> Ghost:
	var g := Ghost.founder(_content(), 1000)
	g.deck.clear()
	for i in 4:
		g.deck.append(CardInstance.new(i + 1, card_id))
	g.floor = floor
	g.strength = strength
	g.fixed_strength = true
	g._archetype = ""
	return g


func _ladder(ghosts: Array) -> Ladder:
	var l := Ladder.new()
	for g in ghosts:
		l.add(g as Ghost)
	return l


func _balance() -> Dictionary:
	return _content().balance


# ------------------------------------------------------------- the threshold

func test_two_matching_ghosts_are_just_two_ghosts() -> void:
	var l := _ladder([_ghost("strike", 3), _ghost("strike", 3)])
	assert_float(Hauntings.spawn_bonus(_content(), l, 3, _balance())).is_equal(1.0)
	assert_dict(Hauntings.describe(_content(), l, 3, _balance())).is_empty()


func test_three_of_a_kind_is_a_haunting() -> void:
	var l := _ladder([_ghost("strike", 3), _ghost("strike", 3), _ghost("strike", 3)])
	# +15% per matching ghost: three of them is +45%.
	assert_float(Hauntings.spawn_bonus(_content(), l, 3, _balance())) \
		.is_equal_approx(1.45, 0.0001)
	var told := Hauntings.describe(_content(), l, 3, _balance())
	assert_int(int(told["count"])).is_equal(3)
	assert_float(float(told["bonus"])).is_equal_approx(0.45, 0.0001)


func test_a_haunting_stops_growing_at_the_cap() -> void:
	var many: Array = []
	for i in 12:
		many.append(_ghost("strike", 4))
	var l := _ladder(many)
	assert_float(Hauntings.spawn_bonus(_content(), l, 4, _balance())) \
		.override_failure_message("twelve of your dead is a different game") \
		.is_equal_approx(1.75, 0.0001)


func test_the_curve_can_be_read_without_a_ladder() -> void:
	var b := _balance()
	assert_float(Hauntings.bonus_for(0, b)).is_equal(1.0)
	assert_float(Hauntings.bonus_for(2, b)).is_equal(1.0)
	assert_float(Hauntings.bonus_for(3, b)).is_greater(1.0)
	assert_float(Hauntings.bonus_for(4, b)).is_greater(Hauntings.bonus_for(3, b))
	assert_float(Hauntings.bonus_for(99, b)).is_equal(Hauntings.bonus_for(50, b))


# ------------------------------------------------------------- who counts

func test_the_biggest_group_on_the_floor_is_the_one_that_haunts() -> void:
	var l := _ladder([
		_ghost("wither", 5), _ghost("wither", 5), _ghost("wither", 5), _ghost("wither", 5),
		_ghost("strike", 5), _ghost("strike", 5), _ghost("strike", 5)])
	var told := Hauntings.on_floor(_content(), l, 5)
	assert_int(int(told["count"])).is_equal(4)
	assert_str(String(told["tag"])).is_equal("poison")


func test_a_ghost_with_no_deck_haunts_nothing() -> void:
	var empty := Ghost.founder(_content(), 1000)
	empty.deck.clear()
	empty.floor = 2
	empty._archetype = ""
	var l := _ladder([empty, _ghost("strike", 2), _ghost("strike", 2)])
	assert_float(Hauntings.spawn_bonus(_content(), l, 2, _balance())).override_failure_message(
		"a ghost with nothing in its hands made up the numbers").is_equal(1.0)


func test_ghosts_on_other_floors_are_on_other_floors() -> void:
	var l := _ladder([_ghost("strike", 1), _ghost("strike", 2), _ghost("strike", 3)])
	for floor in [1, 2, 3]:
		assert_float(Hauntings.spawn_bonus(_content(), l, floor, _balance())).is_equal(1.0)


func test_the_same_ladder_always_reports_the_same_haunting() -> void:
	# A tie between two archetypes has to break the same way every time, or a
	# save and a load disagree about what is standing on the floor.
	var l := _ladder([
		_ghost("wither", 7), _ghost("wither", 7), _ghost("wither", 7),
		_ghost("strike", 7), _ghost("strike", 7), _ghost("strike", 7)])
	var first := String(Hauntings.on_floor(_content(), l, 7)["tag"])
	for i in 5:
		assert_str(String(Hauntings.on_floor(_content(), l, 7)["tag"])).is_equal(first)


func test_only_haunted_floors_are_in_the_table() -> void:
	var l := _ladder([
		_ghost("strike", 1), _ghost("strike", 1), _ghost("strike", 1),
		_ghost("strike", 2)])
	var table := Hauntings.by_floor(_content(), l, _balance())
	assert_bool(table.has(1)).is_true()
	assert_bool(table.has(2)).override_failure_message(
		"a floor with one ghost on it is in the haunting table").is_false()


# --------------------------------------------------------- what it is worth

func test_a_haunting_raises_the_floor_rather_than_the_ghosts() -> void:
	# The whole design (§5.6): "synergy raises the floor's cap -- a bigger
	# floor -- rather than each ghost's strength". Buffing strength would be
	# worth nothing on a floor that is already saturated, which is exactly
	# where the player has been stacking their dead.
	var c := _content()
	var l := _ladder([_ghost("strike", 6, 400.0), _ghost("strike", 6, 400.0),
		_ghost("strike", 6, 400.0)])
	var plain: Dictionary = {"global_spawn": 1.0}
	var haunted: Dictionary = {"global_spawn": 1.0,
		"haunting": Hauntings.by_floor(c, l, c.balance)}
	assert_float(l.floor_strength(6, c.balance, haunted)).override_failure_message(
		"the haunting made the ghosts stronger").is_equal(
			l.floor_strength(6, c.balance, plain))
	assert_float(l.floor_output(6, c.balance, haunted)).override_failure_message(
		"a haunting on a saturated floor paid nothing").is_greater(
			l.floor_output(6, c.balance, plain))


func test_a_haunting_is_worth_most_where_the_dead_are_thickest() -> void:
	var c := _content()
	var thin := _ladder([_ghost("strike", 6, 5.0), _ghost("strike", 6, 5.0),
		_ghost("strike", 6, 5.0)])
	var thick := _ladder([_ghost("strike", 6, 900.0), _ghost("strike", 6, 900.0),
		_ghost("strike", 6, 900.0)])
	assert_float(_gain(c, thick, 6)).override_failure_message(
		"a haunting paid the same on an empty floor as on a full one") \
		.is_greater(_gain(c, thin, 6))


func test_an_unhaunted_ladder_pays_exactly_what_it_always_did() -> void:
	var c := _content()
	var l := _ladder([_ghost("strike", 8), _ghost("wither", 8)])
	var plain: Dictionary = {"global_spawn": 1.0}
	var withm: Dictionary = {"global_spawn": 1.0,
		"haunting": Hauntings.by_floor(c, l, c.balance)}
	assert_float(l.floor_output(8, c.balance, withm)).is_equal(
		l.floor_output(8, c.balance, plain))


func test_the_campaign_hands_the_ladder_its_hauntings() -> void:
	# The wiring, not the arithmetic: nothing else in the game passes the
	# table, so a `modifiers()` that forgot it would silently switch the
	# feature off everywhere at once.
	var c := TestFixtures.campaign()
	for i in 3:
		c.ladder.add(_ghost("strike", 4))
	assert_bool(c.modifiers().has("haunting")).is_true()
	assert_bool((c.modifiers()["haunting"] as Dictionary).has(4)).is_true()


func _gain(c: Content, l: Ladder, floor: int) -> float:
	var plain: Dictionary = {"global_spawn": 1.0}
	var haunted: Dictionary = {"global_spawn": 1.0,
		"haunting": Hauntings.by_floor(c, l, c.balance)}
	return l.floor_output(floor, c.balance, haunted) - l.floor_output(floor, c.balance, plain)
