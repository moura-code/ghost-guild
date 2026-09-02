extends GdUnitTestSuite
## "The ghost fights as you fought" (spec §5.2), for the half of it that was
## never true.
##
## A true ghost already inherited the hero's *measured* win rate and turn
## count. Everything else it does -- echoes, next-floor projections, tending
## deltas, the number on the exit screen -- is a simulation, and every one of
## those simulations was played by one autopilot with one hard-coded table.
## These are the tests that the rules actually reach them.

const TMP := "user://test_saves/ghost_rules_test.json"


func _content() -> Content:
	return TestFixtures.content()


func _hero(rules: Array[String] = []) -> Hero:
	var h := Hero.create(_content(), "sexton", "Maren")
	h.rules = rules.duplicate()
	return h


func test_a_hero_starts_with_no_rules_at_all() -> void:
	# The identity, at the only place it can leak: if a fresh hero were given
	# a default rule, every existing measurement of the game would move.
	assert_array(_hero().rules).is_empty()


func test_the_ghost_inherits_how_its_hero_fought() -> void:
	var hero := _hero(["strike_first", "finish_the_wounded"])
	var g := Ghost.from_run(hero, {"kind": "watch", "floor": 4}, {"fights": 2, "wins": 2, "win_rate": 1.0, "avg_turns": 3.0}, 100)
	assert_array(g.rules).is_equal(["strike_first", "finish_the_wounded"])


func test_the_ghost_keeps_its_own_copy() -> void:
	# The hero lives on after a retreat and can be given different rules. A
	# ghost that shared the array would silently change how it fights.
	var hero := _hero(["strike_first"])
	var g := Ghost.from_run(hero, {"kind": "watch", "floor": 1}, {}, 0)
	hero.rules.append("hold_the_line")
	assert_array(g.rules).is_equal(["strike_first"])


func test_rules_survive_a_save_and_a_load() -> void:
	var hero := _hero(["poison_before_blades", "spend_everything"])
	var g := Ghost.from_run(hero, {"kind": "watch", "floor": 6}, {}, 0)
	assert_array(Ghost.from_dict(g.to_dict()).rules).is_equal(g.rules)
	assert_array(Hero.from_dict(hero.to_dict()).rules).is_equal(hero.rules)


func test_an_echo_fights_the_way_the_ghost_it_copies_fights() -> void:
	# An echo wearing the deck but not the doctrine is a different fighter.
	var hero := _hero(["break_them_first"])
	var g := Ghost.from_run(hero, {"kind": "watch", "floor": 3}, {}, 0)
	assert_array(g.clone_as_echo(5, 10).rules).is_equal(["break_them_first"])


func test_rules_actually_reach_the_fight() -> void:
	# The whole point. Two ghosts with the same deck on the same floor with
	# the same seed, differing only in doctrine, must not fight identically --
	# otherwise all of this is bookkeeping.
	var content := _content()
	var hero := _hero()
	var snap := hero.snapshot()
	var biome: BiomeDef = content.biomes["catacombs"]
	var plain := Strength.simulate(content, snap, biome, 3, 4242, 12)
	var ruled := Strength.simulate(content, snap, biome, 3, 4242, 12,
		["trade_blood_for_ground", "strike_first", "spend_everything"])
	assert_bool(plain["win_rate"] != ruled["win_rate"] or plain["avg_turns"] != ruled["avg_turns"]) \
		.override_failure_message("doctrine changed nothing: %s vs %s" % [plain, ruled]) \
		.is_true()


func test_no_rules_simulates_exactly_as_it_always_did() -> void:
	# Passing an empty rule list must take the same path as passing nothing,
	# to the last decimal -- every existing caller passes nothing.
	var content := _content()
	var snap := _hero().snapshot()
	var biome: BiomeDef = content.biomes["catacombs"]
	assert_dict(Strength.simulate(content, snap, biome, 2, 99, 8, [])) \
		.is_equal(Strength.simulate(content, snap, biome, 2, 99, 8))


func test_a_simulation_with_doctrine_still_ends() -> void:
	# Every rule combination has to leave the autopilot able to finish a
	# fight. A rule set that makes it stall turns a yield preview into a hang.
	var content := _content()
	var snap := _hero().snapshot()
	var biome: BiomeDef = content.biomes["catacombs"]
	var ids: Array = content.rules.keys()
	ids.sort()
	for id in ids:
		var r := Strength.simulate(content, snap, biome, 2, 7, 3, [String(id)])
		assert_int(int(r["fights"])).override_failure_message("'%s' never finished" % id).is_equal(3)


func test_taking_the_watch_records_the_rules_you_chose() -> void:
	var content := _content()
	var hero := _hero()
	var run := RunEngine.start_run(content, hero, "catacombs", 1, 5, true)
	run.phase = "exit"
	RunEngine.apply(run, {"kind": "watch", "rules": ["hold_the_line", "nurse_the_wound"]})
	assert_array(run.hero.rules).is_equal(["hold_the_line", "nurse_the_wound"])
	assert_str(String(run.outcome["kind"])).is_equal("watch")


func test_taking_the_watch_without_choosing_keeps_what_the_hero_had() -> void:
	# Not everything that ends a run goes through the picker -- a retreat, a
	# death, an autopilot run. None of those may wipe the hero's doctrine.
	var content := _content()
	var hero := _hero(["strike_first"])
	var run := RunEngine.start_run(content, hero, "catacombs", 1, 5, true)
	run.phase = "exit"
	RunEngine.apply(run, {"kind": "watch"})
	assert_array(run.hero.rules).is_equal(["strike_first"])


func test_a_watch_that_names_nonsense_is_cleaned_not_trusted() -> void:
	# The action comes from the UI, and the UI is the least trustworthy caller
	# there is. Four rules, a duplicate and a rule that does not exist.
	var content := _content()
	var run := RunEngine.start_run(content, _hero(), "catacombs", 1, 5, true)
	run.phase = "exit"
	RunEngine.apply(run, {"kind": "watch",
		"rules": ["strike_first", "strike_first", "no_such_rule", "hold_the_line", "nurse_the_wound", "spend_everything"]})
	assert_array(run.hero.rules).is_equal(["strike_first", "hold_the_line", "nurse_the_wound"])
