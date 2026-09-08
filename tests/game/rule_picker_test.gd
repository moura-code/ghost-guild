extends GdUnitTestSuite
## The beat where dying becomes a choice about something other than timing.
##
## The selection logic is what is worth asserting: it is ordered, it is
## capped, it is reversible, and picking nothing is a legal answer. Whether
## the list reads well is a question only looking at it answers.

const TMP := "user://test_saves/rule_picker_test.json"


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	return g


func _picker(g: GameRoot, already: Array = []) -> RulePicker:
	var p: RulePicker = auto_free(RulePicker.new())
	add_child(p)
	p.bind(g, already)
	return p


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func test_it_offers_every_rule_the_game_has() -> void:
	var g := _game()
	var p := _picker(g)
	assert_int(p.rule_ids().size()).is_equal(g.content.rules.size())
	for id in g.content.rules:
		assert_array(p.rule_ids()).contains([String(id)])


func test_the_list_is_in_a_stable_order() -> void:
	# Dictionary order depends on which file a rule was loaded from, so the
	# list would reshuffle the day a second rules file is added.
	var p := _picker(_game())
	var ids := p.rule_ids()
	var sorted := ids.duplicate()
	sorted.sort()
	assert_array(ids).is_equal(sorted)


func test_picking_is_ordered_and_the_order_is_visible() -> void:
	# The number IS the feature: without it the player picked a set and the
	# game read an ordered list.
	var p := _picker(_game())
	p.toggle("hold_the_line")
	p.toggle("strike_first")
	assert_array(p.chosen).is_equal(["hold_the_line", "strike_first"])
	assert_int(p.position_of("hold_the_line")).is_equal(1)
	assert_int(p.position_of("strike_first")).is_equal(2)
	assert_int(p.position_of("nurse_the_wound")).is_equal(0)


func test_picking_the_same_rule_again_takes_it_back() -> void:
	var p := _picker(_game())
	p.toggle("strike_first")
	p.toggle("hold_the_line")
	p.toggle("strike_first")
	assert_array(p.chosen).is_equal(["hold_the_line"])
	assert_int(p.position_of("hold_the_line")).is_equal(1)


func test_a_fourth_pick_does_nothing_rather_than_replacing_a_choice() -> void:
	# Silently pushing out the choice they made two clicks ago is worse than
	# doing nothing they can see.
	var p := _picker(_game())
	for id in ["strike_first", "hold_the_line", "nurse_the_wound", "spend_everything"]:
		p.toggle(id)
	assert_array(p.chosen).is_equal(["strike_first", "hold_the_line", "nurse_the_wound"])
	assert_int(p.chosen.size()).is_equal(PriorityRules.MAX)


func test_a_full_picker_greys_the_rest_instead_of_hiding_them() -> void:
	# The player should be able to see what they are trading away by keeping
	# the three they have.
	var p := _picker(_game())
	for id in ["strike_first", "hold_the_line", "nurse_the_wound"]:
		p.toggle(id)
	var greyed := 0
	for id in p.rule_ids():
		var button: Button = p._rows[id]
		assert_bool(button.visible).override_failure_message("%s vanished" % id).is_true()
		if button.disabled:
			greyed += 1
		else:
			assert_int(p.position_of(id)).is_greater(0)
	assert_int(greyed).is_equal(p.rule_ids().size() - PriorityRules.MAX)


func test_it_opens_on_what_the_hero_already_chose() -> void:
	# A hero can take the watch after having been given rules another way,
	# and the picker is also the place they are reviewed.
	var g := _game()
	var p := _picker(g, ["break_them_first", "spend_everything"])
	assert_array(p.chosen).is_equal(["break_them_first", "spend_everything"])


func test_it_ignores_rules_that_no_longer_exist() -> void:
	var p := _picker(_game(), ["no_such_rule", "strike_first"])
	assert_array(p.chosen).is_equal(["strike_first"])


func test_choosing_nothing_is_a_legal_answer() -> void:
	# A locked confirm button on a screen the player reached by choosing to
	# die would be the cruellest possible place to put a modal.
	var g := _game()
	var p := _picker(g)
	assert_bool(p._confirm.disabled).is_false()
	assert_str(p._summary.text).is_equal(g.text("ui.watch.none"))
	var heard: Array = []
	p.confirmed.connect(func(ids: Array) -> void: heard.append(ids))
	p._confirm.pressed.emit()
	assert_int(heard.size()).is_equal(1)
	assert_array(heard[0]).is_empty()


func test_confirming_reports_the_order_the_player_built() -> void:
	var p := _picker(_game())
	p.toggle("poison_before_blades")
	p.toggle("save_your_strength")
	var heard: Array = []
	p.confirmed.connect(func(ids: Array) -> void: heard.append(ids))
	p._confirm.pressed.emit()
	assert_array(heard[0]).is_equal(["poison_before_blades", "save_your_strength"])


func test_what_it_reports_is_a_copy() -> void:
	# The picker stays alive behind the panel. A caller that held the same
	# array would watch the run's doctrine change under it.
	var p := _picker(_game())
	p.toggle("strike_first")
	var heard: Array = []
	p.confirmed.connect(func(ids: Array) -> void: heard.append(ids))
	p._confirm.pressed.emit()
	p.toggle("hold_the_line")
	assert_array(heard[0]).is_equal(["strike_first"])
