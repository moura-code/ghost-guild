extends GdUnitTestSuite
## How a ghost fights.
##
## The property that matters most here is the one that is easiest to lose: an
## empty rule list must leave the weight table byte-for-byte what it was. The
## balance simulator and both demos measure the autopilot, and every ghost in
## the game has no rules until a player picks some.


func _content() -> Content:
	return TestFixtures.content()


func _base() -> Dictionary:
	return Autopilot.default_weights()


func test_no_rules_is_the_table_it_started_with() -> void:
	# The identity. If this ever fails, the balance simulator is measuring a
	# different game than it was tuned against.
	var base := _base()
	assert_dict(PriorityRules.weights_for(base, [], _content())).is_equal(base)


func test_composing_never_edits_the_table_it_was_given() -> void:
	# The autopilot's defaults are shared. A ghost that edited them in place
	# would change how every other ghost in the game fights.
	var base := _base()
	var before := base.duplicate(true)
	PriorityRules.weights_for(base, ["strike_first"], _content())
	assert_dict(base).is_equal(before)


func test_a_rule_bends_what_it_names_and_nothing_else() -> void:
	var base := _base()
	var out := PriorityRules.weights_for(base, ["finish_the_wounded"], _content())
	assert_float(float(out["kill"])).is_greater(float(base["kill"]))
	assert_float(float(out["damage"])).is_less(float(base["damage"]))
	assert_float(float(out["heal"])).is_equal(float(base["heal"]))
	assert_float(float(out["block_useful"])).is_equal(float(base["block_useful"]))


func test_a_rule_reaches_into_a_nested_weight() -> void:
	var base := _base()
	var out := PriorityRules.weights_for(base, ["poison_before_blades"], _content())
	var before: Dictionary = base["enemy_status"]
	var after: Dictionary = out["enemy_status"]
	assert_float(float(after["poison"])).is_greater(float(before["poison"]))
	assert_float(float(after["vulnerable"])).is_equal(float(before["vulnerable"]))


func test_a_wildcard_lifts_a_whole_group() -> void:
	# "Powers first" cares about every buff there is, and listing six status
	# names in the data would mean editing the rule every time one is added.
	var base := _base()
	var out := PriorityRules.weights_for(base, ["powers_first"], _content())
	var before: Dictionary = base["hero_status"]
	var after: Dictionary = out["hero_status"]
	for status in before:
		assert_float(float(after[status])) \
			.override_failure_message("%s was not lifted" % status) \
			.is_greater(float(before[status]))


func test_an_add_can_turn_a_penalty_into_a_reward() -> void:
	# "Save your strength" is exactly this: leftover energy stops being waste
	# and starts being the point. A scheme with only multipliers cannot say it.
	var base := _base()
	assert_float(float(base["energy_left"])).is_less(0.0)
	var out := PriorityRules.weights_for(base, ["save_your_strength"], _content())
	assert_float(float(out["energy_left"])).is_greater(0.0)


func test_the_first_rule_bends_hardest() -> void:
	# The player ORDERS three rules (spec 3.3). If order did nothing, the
	# ordering would be a lie the UI told.
	var base := _base()
	var first := PriorityRules.weights_for(base, ["strike_first", "nurse_the_wound"], _content())
	var second := PriorityRules.weights_for(base, ["nurse_the_wound", "strike_first"], _content())
	assert_float(float(first["damage"])).is_not_equal(float(second["damage"]))
	assert_float(float(first["damage"])).is_greater(float(second["damage"]))


func test_two_rules_that_disagree_land_somewhere_between_them() -> void:
	# Strike first raises damage; hold the line lowers it. Together they must
	# not cancel to nonsense, and must not run away.
	var base := _base()
	var both := PriorityRules.weights_for(base, ["strike_first", "hold_the_line"], _content())
	var only_strike := PriorityRules.weights_for(base, ["strike_first"], _content())
	assert_float(float(both["damage"])).is_less(float(only_strike["damage"]))
	assert_float(float(both["damage"])).is_greater(0.0)


func test_a_fourth_rule_is_not_taken() -> void:
	var base := _base()
	var three := PriorityRules.weights_for(base, ["strike_first", "hold_the_line", "nurse_the_wound"], _content())
	var four := PriorityRules.weights_for(
		base, ["strike_first", "hold_the_line", "nurse_the_wound", "spend_everything"], _content())
	assert_dict(four).is_equal(three)


func test_a_rule_named_twice_counts_once() -> void:
	var base := _base()
	var once := PriorityRules.weights_for(base, ["strike_first"], _content())
	var twice := PriorityRules.weights_for(base, ["strike_first", "strike_first"], _content())
	assert_dict(twice).is_equal(once)


func test_a_rule_that_no_longer_exists_loads_anyway() -> void:
	# Content moves between saves. A save that names a cut rule has to load
	# with the rules that are left, not fail to load at all.
	var base := _base()
	var out := PriorityRules.weights_for(base, ["no_such_rule", "strike_first"], _content())
	assert_dict(out).is_equal(PriorityRules.weights_for(base, ["strike_first"], _content()))
	assert_array(PriorityRules.normalize_ids(["no_such_rule"], _content())).is_empty()


func test_nothing_can_make_the_autopilot_want_to_be_hit() -> void:
	# A positive hp_lost is a hero that seeks damage and a positive unblocked
	# is one that stands still to be hit. Either turns every fight into a
	# 30-turn cap hit, which is a hang with a stack trace on the end of it.
	var base := _base()
	var content := _content()
	for id in content.rules:
		for other in content.rules:
			var out := PriorityRules.weights_for(base, [id, other], content)
			for path in PriorityRules.NEVER_POSITIVE:
				assert_float(float(out[path])) \
					.override_failure_message("%s + %s made %s a reward" % [id, other, path]) \
					.is_less_equal(0.0)


func test_death_and_lethal_are_out_of_reach() -> void:
	# Not by clamping: by not being adjustable at all. The validator rejects a
	# rule that names either.
	assert_array(PriorityRules.ADJUSTABLE).not_contains(["death"])
	assert_array(PriorityRules.ADJUSTABLE).not_contains(["lethal"])
	var base := _base()
	var content := _content()
	for id in content.rules:
		var out := PriorityRules.weights_for(base, [id], content)
		assert_float(float(out["death"])).is_equal(float(base["death"]))
		assert_float(float(out["lethal"])).is_equal(float(base["lethal"]))


func test_every_shipped_rule_is_valid_content() -> void:
	# Twelve of them (spec 7). Each names a weight that exists, has both its
	# strings, and actually changes something.
	var content := _content()
	assert_int(content.rules.size()).is_equal(12)
	var base := _base()
	for id in content.rules:
		var rule: RuleDef = content.rules[id]
		assert_str(rule.name_key).is_not_empty()
		assert_str(rule.text_key).is_not_empty()
		assert_str(content.text(rule.name_key)).is_not_equal(rule.name_key)
		assert_str(content.text(rule.text_key)).is_not_equal(rule.text_key)
		assert_dict(PriorityRules.weights_for(base, [id], content)) \
			.override_failure_message("rule '%s' changes nothing" % id) \
			.is_not_equal(base)
