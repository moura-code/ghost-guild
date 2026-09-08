extends GdUnitTestSuite
## The descent below thirty (spec §2): the biomes cycle, and each cycle is a
## tier.
##
## The property that has to hold before anything else: **tier 1 is the game
## that already exists.** Floors 1 to 30 must resolve to exactly the biome and
## exactly the scaling they always did, or this stage rebalances the whole game
## by accident.


func _content() -> Content:
	return Content.load_from("res://data")


# ------------------------------------------------------------ the identity

func test_the_first_tier_is_the_dungeon_as_it_was() -> void:
	var c := _content()
	for floor in range(1, Biomes.depth(c) + 1):
		assert_int(Biomes.tier_of(c, floor)).override_failure_message(
			"floor %d is not tier 1" % floor).is_equal(1)


func test_the_first_tier_scales_exactly_as_it_always_did() -> void:
	var c := _content()
	for floor in [1, 8, 15, 22, 30]:
		assert_int(Scaling.enemy_hp(20, floor, c.balance, 1)) \
			.is_equal(Scaling.enemy_hp(20, floor, c.balance))
		assert_int(Scaling.enemy_damage(9, floor, c.balance, 1)) \
			.is_equal(Scaling.enemy_damage(9, floor, c.balance))


# ----------------------------------------------------------------- the wrap

func test_the_floor_after_the_last_one_is_the_first_biome_again() -> void:
	var c := _content()
	var depth := Biomes.depth(c)
	assert_str(Biomes.for_floor(c, depth + 1).id).is_equal(Biomes.for_floor(c, 1).id)
	assert_int(Biomes.tier_of(c, depth + 1)).is_equal(2)


func test_every_floor_of_the_second_tier_matches_the_first() -> void:
	# The off-by-one that would put floor 31 in the Kiln crashes nothing.
	var c := _content()
	var depth := Biomes.depth(c)
	for floor in range(1, depth + 1):
		assert_str(Biomes.for_floor(c, floor + depth).id).override_failure_message(
			"floor %d is not floor %d one tier down" % [floor + depth, floor]) \
			.is_equal(Biomes.for_floor(c, floor).id)


func test_it_keeps_going_for_ever() -> void:
	var c := _content()
	var depth := Biomes.depth(c)
	assert_int(Biomes.tier_of(c, depth * 3 + 1)).is_equal(4)
	assert_str(Biomes.for_floor(c, depth * 9 + 4).id).is_equal(Biomes.for_floor(c, 4).id)


func test_a_floor_above_the_dungeon_is_still_the_first_tier() -> void:
	# `reach` arithmetic and a corrupt save can both hand this a zero.
	var c := _content()
	assert_int(Biomes.tier_of(c, 0)).is_equal(1)
	assert_int(Biomes.tier_of(c, -7)).is_equal(1)
	assert_str(Biomes.for_floor(c, 0).id).is_equal(Biomes.for_floor(c, 1).id)


# --------------------------------------------------------------- the teeth

func test_a_deeper_tier_hits_harder_than_the_per_floor_curve_alone() -> void:
	# Without a jump, floor 31 is barely harder than floor 30 and the loop has
	# no teeth at all -- you would simply walk into the next cycle.
	var c := _content()
	var depth := Biomes.depth(c)
	var last := Scaling.enemy_hp(20, depth, c.balance, 1)
	var first_of_next := Scaling.enemy_hp(20, depth + 1, c.balance, 2)
	assert_int(first_of_next).override_failure_message(
		"tier 2 opens softer than tier 1 closes").is_greater(last)


func test_the_jump_compounds_with_the_tier() -> void:
	var c := _content()
	var two := Scaling.enemy_hp(20, 31, c.balance, 2)
	var three := Scaling.enemy_hp(20, 31, c.balance, 3)
	assert_int(three).is_greater(two)
