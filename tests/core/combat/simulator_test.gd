extends GdUnitTestSuite


func test_simulation_is_deterministic() -> void:
	var content := TestFixtures.content()
	var a := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["bone_rat", "bone_rat"], 2, 77, 10)
	var b := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["bone_rat", "bone_rat"], 2, 77, 10)
	assert_dict(a).is_equal(b)
	assert_int(a["fights"]).is_equal(10)


func test_starter_beats_floor_one_rats() -> void:
	var content := TestFixtures.content()
	var r := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["bone_rat"], 1, 5, 20)
	assert_float(r["win_rate"]).is_greater_equal(0.9)
	assert_float(r["avg_turns"]).is_between(1.0, 6.0)
	assert_int(r["wins"] + r["losses"]).is_equal(20)


func test_starter_struggles_against_boss() -> void:
	var content := TestFixtures.content()
	var r := FightSimulator.simulate(content, HeroSnapshot.starter(content, "sexton"), ["mother_of_bones"], 10, 5, 10)
	assert_float(r["win_rate"]).is_less(0.5)


func test_table_cycles_groups_and_hero_is_not_consumed() -> void:
	var content := TestFixtures.content()
	var hero := HeroSnapshot.starter(content, "sexton")
	hero.hp = 40
	var groups: Array = [["bone_rat"], ["shambler"], ["grave_wisp"]]
	var r := FightSimulator.simulate_table(content, hero, groups, 1, 3, 9)
	assert_int(r["fights"]).is_equal(9)
	assert_int(hero.hp).is_equal(40)
	assert_array(hero.deck).has_size(10)
