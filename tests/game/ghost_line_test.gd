extends GdUnitTestSuite
## One ghost in the Séance list. What is asserted here is the line the rule
## picker's whole promise rests on: that a player can see, afterwards, what
## they told this ghost to do. A choice you can never look at again is one
## nobody makes carefully a second time.


func _content() -> Content:
	return TestFixtures.content()


func _ghost(rules: Array[String] = []) -> Ghost:
	var hero := Hero.create(_content(), "sexton", "Maren")
	hero.rules = rules.duplicate()
	var g := Ghost.from_run(hero, {"kind": "watch", "floor": 4}, {}, 0)
	g.id = 7
	g.strength = 12.5
	return g


func _line(ghost: Ghost) -> GhostLine:
	var l: GhostLine = auto_free(GhostLine.new())
	add_child(l)
	l.bind(_content(), ghost, {"waypoint": 9, "echo_cost": 10.0, "call_cost": 5.0, "tend_cost": 0.0, "soul": 100.0})
	return l


func test_a_ghost_with_orders_says_what_they_were() -> void:
	var content := _content()
	var line := _line(_ghost(["strike_first", "finish_the_wounded"]))
	assert_bool(line._doctrine.visible).override_failure_message("the orders are invisible").is_true()
	var rule: RuleDef = content.rules["strike_first"]
	assert_str(line._doctrine.text).contains(content.text(rule.name_key))
	assert_str(line._doctrine.text).contains(content.text((content.rules["finish_the_wounded"] as RuleDef).name_key))


func test_the_order_it_shows_is_the_order_that_was_chosen() -> void:
	var content := _content()
	var first := GhostLine.doctrine_text(content, _ghost(["strike_first", "hold_the_line"]))
	var other := GhostLine.doctrine_text(content, _ghost(["hold_the_line", "strike_first"]))
	assert_str(first).is_not_equal(other)


func test_a_ghost_with_no_orders_gets_no_empty_line() -> void:
	# An always-present blank line under every ghost turns a list of people
	# into a list of gaps.
	var line := _line(_ghost())
	assert_str(line._doctrine.text).is_empty()
	assert_bool(line._doctrine.visible).is_false()


func test_a_rule_that_was_cut_from_the_game_is_simply_not_shown() -> void:
	# Content moves between saves. A ghost naming a rule that no longer exists
	# must still render, without printing a raw id at the player.
	var content := _content()
	var g := _ghost()
	g.rules = ["no_such_rule", "strike_first"]
	var text := GhostLine.doctrine_text(content, g)
	assert_str(text).is_not_empty()
	assert_str(text).not_contains("no_such_rule")
	assert_str(text).contains(content.text((content.rules["strike_first"] as RuleDef).name_key))


func test_a_ghost_that_names_only_cut_rules_shows_nothing() -> void:
	var g := _ghost()
	g.rules = ["gone", "also_gone"]
	assert_str(GhostLine.doctrine_text(_content(), g)).is_empty()
