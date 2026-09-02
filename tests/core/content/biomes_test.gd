extends GdUnitTestSuite
## Which biome a floor is in (spec §2), and which biomes the guild has claimed
## (spec §5.6).
##
## The map is the load-bearing part. Every projection in the game -- an echo's
## strength, an expedition's survival, a ghost's yield -- is handed a floor and
## has to price it against the right enemy table. They all read the campaign's
## one biome before this existed, which was invisible while there was only one.


func _content() -> Content:
	return Content.load_from("res://data")


func _ladder(content: Content, floors: Array, kind: String = "true") -> Ladder:
	var l := Ladder.new()
	var n := 0
	for floor in floors:
		n += 1
		var hero := Hero.create(content, "sexton", "G%d" % n, {}, 1)
		var g := Ghost.from_expedition(hero, int(floor), 0)
		l.add(g.clone_as_echo(int(floor), 0) if kind == "echo" else g)
	return l


# --------------------------------------------------------------- the map

func test_a_floor_lands_in_the_biome_that_authored_it() -> void:
	var c := _content()
	assert_str(Biomes.for_floor(c, 1).id).is_equal("catacombs")
	assert_str(Biomes.for_floor(c, 10).id).is_equal("catacombs")


func test_the_boundaries_are_where_the_data_says_they_are() -> void:
	# Every biome's own first and last floor resolves to itself, whatever the
	# data eventually says they are. Off-by-one here misprices a whole floor.
	var c := _content()
	for id in c.biomes:
		var b: BiomeDef = c.biomes[id]
		assert_str(Biomes.for_floor(c, b.first_floor).id).is_equal(b.id)
		assert_str(Biomes.for_floor(c, b.last_floor).id).is_equal(b.id)


func test_a_floor_off_either_end_still_answers() -> void:
	# `reach` arithmetic and a corrupt save can both hand this a floor that no
	# biome authored. Returning null would push the crash somewhere else.
	var c := _content()
	assert_str(Biomes.for_floor(c, 0).id).is_equal("catacombs")
	assert_str(Biomes.for_floor(c, -5).id).is_equal("catacombs")
	assert_object(Biomes.for_floor(c, 9999)).is_not_null()
	assert_str(Biomes.for_floor(c, 9999).id).is_equal(Biomes.deepest(c).id)


func test_the_dungeon_is_as_deep_as_the_biomes_authored() -> void:
	var c := _content()
	var deepest := 0
	for id in c.biomes:
		deepest = maxi(deepest, (c.biomes[id] as BiomeDef).last_floor)
	assert_int(Biomes.depth(c)).is_equal(deepest)


func test_the_biomes_cover_the_dungeon_with_no_gap_and_no_overlap() -> void:
	# A gap silently sends a floor to the wrong table; an overlap makes the
	# answer depend on dictionary order, which is not a thing to depend on.
	var c := _content()
	var seen: Dictionary = {}
	for id in c.biomes:
		var b: BiomeDef = c.biomes[id]
		for floor in range(b.first_floor, b.last_floor + 1):
			assert_bool(seen.has(floor)).override_failure_message(
				"floor %d is in two biomes" % floor).is_false()
			seen[floor] = b.id
	for floor in range(1, Biomes.depth(c) + 1):
		assert_bool(seen.has(floor)).override_failure_message(
			"floor %d is in no biome" % floor).is_true()


# ------------------------------------------------------------- the claims

func test_a_biome_is_claimed_by_a_true_ghost_standing_in_it() -> void:
	var c := _content()
	var claimed := Biomes.claimed(c, _ladder(c, [3]))
	assert_array(claimed).contains(["catacombs"])


func test_an_unvisited_biome_is_not_claimed() -> void:
	var c := _content()
	var claimed := Biomes.claimed(c, _ladder(c, [3]))
	for id in c.biomes:
		if id != "catacombs":
			assert_array(claimed).not_contains([id])


func test_an_echo_does_not_claim_anything() -> void:
	# Spec §5.6: the *first true ghost* claims a biome. An echo is a copy you
	# paid for, and letting it claim would make the claim purchasable.
	var c := _content()
	assert_array(Biomes.claimed(c, _ladder(c, [3], "echo"))).is_empty()


func test_an_empty_ladder_claims_nothing() -> void:
	assert_array(Biomes.claimed(_content(), Ladder.new())).is_empty()


func test_claims_come_back_in_a_stable_order() -> void:
	# They end up in a run's pool list, and a run has to replay from its seed.
	var c := _content()
	var l := _ladder(c, [8, 2, 5])
	assert_array(Biomes.claimed(c, l)).is_equal(Biomes.claimed(c, l))
