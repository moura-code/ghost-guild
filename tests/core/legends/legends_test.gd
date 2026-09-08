extends GdUnitTestSuite
## The prestige arithmetic (spec §6.1, §4.4).
##
## The property that matters most is the first one: a guild with no Legends is
## a guild whose every number is exactly what it was. Prestige is the one
## feature in the game that multiplies everything, so it has to be an identity
## until the player asks for it.


func _content() -> Content:
	return Content.load_from("res://data")


func _ladder(c: Content, floors: Array, deck: Array = []) -> Ladder:
	var l := Ladder.new()
	for floor in floors:
		var hero := Hero.create(c, "sexton", "G%d" % int(floor), {}, 1)
		if not deck.is_empty():
			hero.deck.clear()
			for card_id in deck:
				hero.add_card(String(card_id))
		var g := Ghost.from_expedition(hero, int(floor), 0)
		g.strength = 100.0
		g.fixed_strength = true
		l.add(g)
	return l


# ------------------------------------------------------------ the identity

func test_a_guild_with_no_legends_changes_nothing() -> void:
	assert_float(Legends.blessing([])).is_equal(1.0)


func test_the_first_threshold_is_floor_fifteen() -> void:
	var c := _content()
	assert_int(Legends.threshold(c, 0)).is_equal(15)


func test_the_threshold_rises_by_itself_every_cycle() -> void:
	# Spec §6.1: 15, 30, 45, ...
	var c := _content()
	for cycle in range(0, 6):
		assert_int(Legends.threshold(c, cycle)).is_equal(15 * (cycle + 1))


# ---------------------------------------------------------------- the merge

func test_it_takes_every_ghost_you_have() -> void:
	# True, expedition and echo alike (§6.1). A prestige that left echoes
	# standing would let a player bank them across cycles.
	var c := _content()
	var l := _ladder(c, [4, 9])
	var echo := l.add((l.ghosts[0] as Ghost).clone_as_echo(3, 0))
	echo.strength = 40.0
	assert_float(Legends.mass(l)).is_equal_approx(240.0, 0.001)


func test_a_bigger_ladder_makes_a_bigger_legend() -> void:
	var c := _content()
	var small := Legends.multiplier(c, Legends.mass(_ladder(c, [3])))
	var large := Legends.multiplier(c, Legends.mass(_ladder(c, [3, 6, 9, 12])))
	assert_float(large).is_greater(small)


func test_it_grows_with_the_root_so_the_tenth_cycle_is_not_the_thousandth() -> void:
	# `1 + k * sqrt(mass / M0)`: quadrupling the mass doubles what is added,
	# which is what stops a prestige layer becoming the only thing that matters.
	var c := _content()
	var one := Legends.multiplier(c, 1000.0) - 1.0
	var four := Legends.multiplier(c, 4000.0) - 1.0
	assert_float(four).is_equal_approx(one * 2.0, 0.001)


func test_an_empty_ladder_still_makes_a_legend_worth_nothing_extra() -> void:
	var c := _content()
	assert_float(Legends.multiplier(c, 0.0)).is_equal(1.0)


func test_legends_stack_by_multiplying() -> void:
	var a := Legend.new()
	a.multiplier = 1.5
	var b := Legend.new()
	b.multiplier = 1.2
	assert_float(Legends.blessing([a, b])).is_equal_approx(1.8, 0.0001)


# --------------------------------------------------------------- the trait

func test_the_trait_comes_from_what_the_dead_actually_played() -> void:
	var c := _content()
	var poisonous := _ladder(c, [5], ["plague_vial", "plague_vial", "creeping_rot", "shovel_swing"])
	assert_str(Legends.dominant_tag(c, poisonous)).is_equal("poison")


func test_a_ladder_of_nobody_has_no_trait() -> void:
	assert_str(Legends.dominant_tag(_content(), Ladder.new())).is_empty()


func test_the_trait_is_stable_when_two_tags_tie() -> void:
	# It ends up on a permanent record, so it cannot depend on iteration order.
	var c := _content()
	var l := _ladder(c, [5], ["shovel_swing", "plague_vial"])
	assert_str(Legends.dominant_tag(c, l)).is_equal(Legends.dominant_tag(c, l))


# ---------------------------------------------------------------- the record

func test_a_legend_keeps_the_epitaph_of_everyone_in_it() -> void:
	# "The Hall keeps every merged epitaph -- the Legend is a memorial, not a
	# deletion." It is the whole emotional argument of the feature.
	var c := _content()
	var l := _ladder(c, [4, 9, 14])
	var legend := Legends.forge(c, l, 1, 500)
	assert_array(legend.epitaphs).has_size(3)
	assert_str(String(legend.epitaphs[0]["name"])).is_not_empty()
	assert_int(int(legend.epitaphs[0]["floor"])).is_greater(0)


func test_a_legend_survives_a_save() -> void:
	var c := _content()
	var legend := Legends.forge(c, _ladder(c, [4, 9]), 2, 777)
	var back := Legend.from_dict(legend.to_dict())
	assert_int(back.cycle).is_equal(legend.cycle)
	assert_float(back.multiplier).is_equal_approx(legend.multiplier, 0.0001)
	assert_float(back.mass).is_equal_approx(legend.mass, 0.0001)
	assert_str(back.trait_tag).is_equal(legend.trait_tag)
	assert_array(back.epitaphs).has_size(legend.epitaphs.size())
	assert_str(back.name).is_equal(legend.name)


func test_it_is_named_after_the_deepest_of_them() -> void:
	# A Legend is made of people. It should be called after one.
	var c := _content()
	var legend := Legends.forge(c, _ladder(c, [4, 17, 9]), 1, 500)
	assert_str(legend.name).is_equal("G17")
