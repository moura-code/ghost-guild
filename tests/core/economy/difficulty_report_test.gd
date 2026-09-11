extends GdUnitTestSuite

const Report = preload("res://tools/difficulty_report.gd")


func test_prepared_profile_uses_earned_blessings_and_legal_upgrade_levels() -> void:
	var content := TestFixtures.content()
	var definition := Report.profile_definition(content, "prepared_cycle")
	assert_float(definition["blessing"]).is_equal(4.0)
	assert_array(definition["legend_masses"]).is_equal([1600.0, 1600.0])
	assert_array(definition["claimed_pools"]).has_size(3)
	for id in definition["upgrades"]:
		assert_int(definition["upgrades"][id]).is_less_equal((content.upgrades[id] as UpgradeDef).max_level)
	definition["claimed_pools"].clear()
	assert_array(Report.profile_definition(content, "prepared_cycle")["claimed_pools"]).has_size(3)
	assert_float(Report.profile_definition(content, "later_cycle")["blessing"]).is_equal(1.25)


func test_report_replays_a_seed_without_mutating_profile_or_content() -> void:
	var content := TestFixtures.content()
	var definition := Report.profile_definition(content, "early_purchases")
	var before := definition.duplicate(true)
	var balance_before := content.balance.duplicate(true)
	var deck_before := (content.classes["sexton"] as ClassDef).starting_deck.duplicate()
	var first := Report.sample(content, "early_purchases", "defense_aware", "safe", 73019, 1, definition)
	var second := Report.sample(content, "early_purchases", "defense_aware", "safe", 73019, 1, definition)
	assert_bool(first["terminated"]).is_true()
	assert_dict(first).is_equal(second)
	assert_dict(definition).is_equal(before)
	assert_dict(content.balance).is_equal(balance_before)
	assert_array((content.classes["sexton"] as ClassDef).starting_deck).is_equal(deck_before)
	assert_int(first["entry_floor"]).is_equal(1)
	assert_int(first["fights"].size()).is_equal(2)
	for fight in first["fights"]:
		assert_int(fight["enemies"].size()).is_greater(0)


func test_checkpoint_and_turn_window_follow_late_entry_without_hiding_deaths() -> void:
	var base := {"profile": "prepared_cycle", "policy": "lookahead", "route": "safe", "entry_floor": 31,
		"gross_damage": 45, "blocked": 100, "healing": 5, "turns": 10, "enemy_actions": 8, "depth": 34,
		"coin_spent": 50, "outcome": {"kind": "retreat"},
		"floor_exits": [{"floor": 34, "hp": 50, "max_hp": 100}],
		"fights": [{"floor": 31, "kind": "fight", "won": true, "turns": 2},
			{"floor": 32, "kind": "fight", "won": true, "turns": 3},
			{"floor": 34, "kind": "elite", "won": true, "turns": 5}]}
	var death := base.duplicate(true)
	death["outcome"] = {"kind": "death"}
	death["floor_exits"] = []
	death["fights"] = [{"floor": 31, "kind": "fight", "won": false, "turns": 2}]
	var report := Report.summarize([base, death])
	assert_int(report["n"]).is_equal(2)
	assert_int(report["deaths"]).is_equal(1)
	assert_int(report["first_fight_wins"]).is_equal(1)
	assert_int(report["checkpoint_floor"]).is_equal(34)
	assert_int(report["checkpoint_exit_net_loss_survivors"]["n"]).is_equal(1)
	assert_float(report["checkpoint_exit_net_loss_survivors"]["median"]).is_equal(0.5)
	assert_int(report["opening_normal_win_turns"]["n"]).is_equal(1)
	assert_float(report["opening_normal_win_turns"]["mean"]).is_equal(3.0)
	assert_int(report["floor4_exit_net_loss_survivors"]["n"]).is_zero()


func test_all_four_seed_sets_are_separate() -> void:
	var seen := {}
	for set_name in Report.SEED_BASES:
		for i in 100:
			var value := int(Report.SEED_BASES[set_name]) + i * Report.SEED_STRIDE
			assert_bool(seen.has(value)).is_false()
			seen[value] = set_name
	assert_int(seen.size()).is_equal(400)
