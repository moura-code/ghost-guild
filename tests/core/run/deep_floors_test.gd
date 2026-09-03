extends GdUnitTestSuite
## What a floor past the authored dungeon is actually made of (spec §2, §3.1).
##
## Everything a biome authors — its `first_floor`, its `last_floor`, its
## encounter buckets — was written when floor numbers stopped at thirty. The
## descent cycles for ever now, so an absolute floor has to be folded back
## into its own tier before it is compared against any of them.
##
## It was not, and both failures were silent. Floor 40 had no boss, so every
## cycle past the first lost its reward spine. And every floor past thirty
## matched no encounter bucket and fell through to the deepest one, so tier 2
## opened with the hardest Catacombs group at tier-2 scaling and floors 31-40
## had no encounter variety at all.


func _content() -> Content:
	return TestFixtures.content()


func _kinds(floor: int) -> Array[String]:
	var c := _content()
	var nodes := FloorGenerator.generate(c, Biomes.for_floor(c, floor), floor, Rng.new(7))
	var out: Array[String] = []
	for node in nodes:
		out.append(String(node.get("kind", "")))
	return out


## Whether any of `tries` seeds puts a boss on this floor. The pattern is
## drawn from the biome's table, so one seed proves nothing either way.
func _has_boss(floor: int, tries: int = 24) -> bool:
	var c := _content()
	for i in tries:
		var nodes := FloorGenerator.generate(c, Biomes.for_floor(c, floor), floor, Rng.new(i))
		for node in nodes:
			if String(node.get("kind", "")) == "boss":
				return true
	return false


# ------------------------------------------------------------------ the boss

func test_the_tenth_floor_of_every_cycle_has_a_boss() -> void:
	var depth := Biomes.depth(_content())
	for tier in range(1, 4):
		var last := depth * (tier - 1) + Biomes.for_floor(_content(), depth * (tier - 1) + 1).last_floor
		assert_bool(_has_boss(last)).override_failure_message(
			"floor %d closes a biome in tier %d and has no boss" % [last, tier]).is_true()


func test_the_deepest_floor_of_the_second_cycle_has_a_boss() -> void:
	# The one that was broken: floor 60 is the Kiln again and closed nothing.
	var depth := Biomes.depth(_content())
	assert_bool(_has_boss(depth * 2)).override_failure_message(
		"floor %d has no boss" % (depth * 2)).is_true()


func test_an_ordinary_deep_floor_still_has_no_boss() -> void:
	var depth := Biomes.depth(_content())
	assert_bool(_has_boss(depth + 3)).override_failure_message(
		"every floor of tier 2 is a boss floor").is_false()


# ------------------------------------------------------------- the encounters

func test_the_first_floor_of_a_cycle_fights_what_the_first_floor_fights() -> void:
	# Floor 31 is the Catacombs again. It used to draw `hollow_knight` -- the
	# floor 7-10 bucket -- at tier-2 scaling, which is a cliff, not a cycle.
	var c := _content()
	var depth := Biomes.depth(c)
	var shallow := FloorGenerator.groups_for(Biomes.for_floor(c, 1),
		Biomes.in_tier(c, 1))
	var next_cycle := FloorGenerator.groups_for(Biomes.for_floor(c, depth + 1),
		Biomes.in_tier(c, depth + 1))
	assert_array(next_cycle).override_failure_message(
		"floor %d does not fight what floor 1 fights" % (depth + 1)).is_equal(shallow)


func test_every_floor_of_the_second_cycle_matches_its_own_first() -> void:
	var c := _content()
	var depth := Biomes.depth(c)
	for floor in range(1, depth + 1):
		var here := FloorGenerator.groups_for(Biomes.for_floor(c, floor),
			Biomes.in_tier(c, floor))
		var deeper := FloorGenerator.groups_for(Biomes.for_floor(c, floor + depth),
			Biomes.in_tier(c, floor + depth))
		assert_array(deeper).override_failure_message(
			"floor %d fights a different table to floor %d" % [floor + depth, floor]) \
			.is_equal(here)


func test_a_deep_cycle_still_has_more_than_one_encounter_in_it() -> void:
	# The symptom of the fallback: ten floors that all drew the same bucket.
	var c := _content()
	var depth := Biomes.depth(c)
	var seen: Dictionary = {}
	for floor in range(depth + 1, depth + 11):
		seen[str(FloorGenerator.groups_for(Biomes.for_floor(c, floor),
			Biomes.in_tier(c, floor)))] = true
	assert_int(seen.size()).override_failure_message(
		"the first ten floors of tier 2 draw from one table").is_greater(1)


func test_the_authored_dungeon_is_untouched() -> void:
	# Tier 1 is the identity: `in_tier` is the floor itself for 1..depth.
	var c := _content()
	for floor in [1, 5, 12, 21, Biomes.depth(c)]:
		assert_int(Biomes.in_tier(c, floor)).is_equal(floor)


# ------------------------------------------------------------- a dead attacker

func test_a_volley_stops_when_the_thing_throwing_it_dies() -> void:
	# `volley` is three hits of three. With enough Thorns the archer dies on
	# the first, and the other two used to land anyway -- damage out of a
	# corpse, after `enemy_died` had already been emitted.
	var s := TestFixtures.bare_state(["bone_archer"])
	var enemy := s.enemies[0] as EnemyState
	enemy.hp = 1
	EffectResolver.apply_status(s, {"kind": "hero"}, "thorns", 50)
	s.hero_block = 0
	var hp_before := s.hero_hp
	# The archer aims before it shoots; this test is about the shooting.
	enemy.next_move = "volley"
	EnemyAI.execute_move(s, 0)
	assert_bool(enemy.alive).override_failure_message(
		"the thorns did not kill it, so this proves nothing").is_false()
	var lost := hp_before - s.hero_hp
	var note := "it landed %d damage and one hit is 3, so a corpse kept swinging" % lost
	assert_int(lost).override_failure_message(note).is_less_equal(3)


func test_a_corpse_does_not_apply_the_rider_on_its_own_move() -> void:
	# `cough` carries 2 Poison. A creature that dies to Thorns partway through
	# its own move should not finish it.
	var s := TestFixtures.bare_state(["plague_bearer"])
	var enemy := s.enemies[0] as EnemyState
	enemy.hp = 1
	EffectResolver.apply_status(s, {"kind": "hero"}, "thorns", 50)
	s.hero_block = 0
	var before := s.hero_status("poison")
	enemy.next_move = "cough"
	EnemyAI.execute_move(s, 0)
	assert_bool(enemy.alive).override_failure_message(
		"the thorns did not kill it, so this proves nothing").is_false()
	assert_int(s.hero_status("poison")).override_failure_message(
		"a corpse poisoned the hero on its way out").is_equal(before)


# ---------------------------------------------------------------- the reading

func test_the_survival_reading_is_measured_against_the_floor_you_will_fight() -> void:
	# It was measured without the tier's mutation, the invoked Legend or the
	# Seal -- the number the push decision hangs on, taken from an easier
	# fight than the one the player was about to walk into.
	var c := _content()
	var hero := TestFixtures.hero()
	var biome := Biomes.for_floor(c, 4)
	var snap := hero.snapshot()
	var plain := RunProjection.survival_chance(c, snap, biome, 4, 11, 6)
	var sealed := RunProjection.survival_chance(c, snap, biome, 4, 11, 6, null, null, null,
		Chronicle.seal_scaling(c, 3))
	assert_float(sealed).override_failure_message(
		"a triple-sealed floor projected the same odds as an unsealed one") \
		.is_less_equal(plain)
