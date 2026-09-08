extends GdUnitTestSuite
## The rule in force on a floor (spec §2: "one mutation modifier per tier").
##
## Two properties. **Tier 1 has none** -- the first thirty floors are the game
## as authored, and a mutation there would rebalance everything ever measured
## by accident. And a mutation must be a *rule* rather than a difficulty knob:
## "enemies have 30% more HP" is a bigger number and changes nothing about how
## a fight is played; "every enemy starts with 3 Thorns" is something you have
## to play around.


func _content() -> Content:
	return Content.load_from("res://data")


func _fight(c: Content, floor: int, mutation: MutationDef) -> FightState:
	return CombatEngine.start_fight(c, HeroSnapshot.starter(c, Classes.starting(c)),
		["bone_rat"], floor, Rng.new(9), mutation)


# ------------------------------------------------------------ the identity

func test_the_authored_dungeon_has_no_mutations() -> void:
	var c := _content()
	for floor in range(1, Biomes.depth(c) + 1):
		assert_object(Mutations.for_floor(c, floor, 1234)).override_failure_message(
			"floor %d has a mutation, and the whole game was balanced without one" % floor) \
			.is_null()


func test_applying_nothing_does_nothing() -> void:
	var c := _content()
	var plain := _fight(c, 1, null)
	assert_int(plain.draw_per_turn).is_equal(
		int(c.balance.get("base_draw", 5)))


# ---------------------------------------------------------------- the draw

func test_every_floor_past_the_first_tier_has_a_rule() -> void:
	var c := _content()
	var depth := Biomes.depth(c)
	for floor in range(depth + 1, depth * 2 + 1):
		assert_object(Mutations.for_floor(c, floor, 77)).override_failure_message(
			"floor %d has no rule" % floor).is_not_null()


func test_one_rule_per_biome_per_tier() -> void:
	# A cycle is a set of rules the player learns, not a lottery per floor.
	var c := _content()
	var depth := Biomes.depth(c)
	var first := Mutations.for_floor(c, depth + 1, 77)
	for floor in range(depth + 1, depth + Biomes.for_floor(c, depth + 1).last_floor + 1):
		assert_str(Mutations.for_floor(c, floor, 77).id).override_failure_message(
			"floor %d has a different rule to the rest of its biome" % floor) \
			.is_equal(first.id)


func test_the_same_biome_one_cycle_deeper_can_be_different() -> void:
	var c := _content()
	var depth := Biomes.depth(c)
	var seen: Dictionary = {}
	for tier in range(2, 9):
		seen[Mutations.for_floor(c, depth * (tier - 1) + 1, 77).id] = true
	assert_int(seen.size()).override_failure_message(
		"the Catacombs have the same rule in every cycle").is_greater(1)


func test_it_is_the_same_dungeon_every_time_you_look_at_it() -> void:
	var c := _content()
	var floor := Biomes.depth(c) + 3
	assert_str(Mutations.for_floor(c, floor, 77).id) \
		.is_equal(Mutations.for_floor(c, floor, 77).id)


func test_another_guild_gets_another_dungeon() -> void:
	var c := _content()
	var depth := Biomes.depth(c)
	var mine: Array[String] = []
	var theirs: Array[String] = []
	for tier in range(2, 8):
		mine.append(Mutations.for_floor(c, depth * (tier - 1) + 1, 11).id)
		theirs.append(Mutations.for_floor(c, depth * (tier - 1) + 1, 5150).id)
	assert_array(mine).override_failure_message(
		"every campaign gets the same dungeon").is_not_equal(theirs)


# ----------------------------------------------------------- what they do

func test_a_rule_that_arms_the_enemies_arms_them() -> void:
	var c := _content()
	var thorned: MutationDef = c.mutations["thorned"]
	var s := _fight(c, 31, thorned)
	assert_int((s.enemies[0] as EnemyState).status("thorns")).is_equal(thorned.stacks)


func test_a_rule_that_hobbles_the_hero_hobbles_them() -> void:
	var c := _content()
	assert_int(_fight(c, 31, c.mutations["the_dark"]).draw_per_turn) \
		.is_less(_fight(c, 31, null).draw_per_turn)
	assert_int(_fight(c, 31, c.mutations["the_cold"]).hero_status("weak")).is_greater(0)


func test_a_rule_announces_itself() -> void:
	var c := _content()
	var s := _fight(c, 31, c.mutations["thorned"])
	var announced := 0
	for e in s.events:
		if String(e.get("type", "")) == "mutation":
			announced += 1
	assert_int(announced).is_equal(1)


func test_most_of_them_change_what_you_do_rather_than_how_long_it_takes() -> void:
	# The whole reason tier cycling was worth building: a tier that is only
	# a bigger number is the same floors again with a bigger number on them.
	var c := _content()
	var behavioural := 0
	for id in c.mutations:
		if (c.mutations[id] as MutationDef).behavioural:
			behavioural += 1
	assert_int(c.mutations.size()).is_greater_equal(6)
	assert_int(behavioural * 3).override_failure_message(
		"only %d of %d rules are rules; the rest are knobs" % [behavioural, c.mutations.size()]) \
		.is_greater_equal(c.mutations.size() * 2)
