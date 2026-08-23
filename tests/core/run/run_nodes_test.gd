extends GdUnitTestSuite


func test_event_choice_applies_effects_and_advances() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.hero.hp = 50
	TestFixtures.set_nodes(run, [{"kind": "event", "event": "whispering_well"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_str(run.phase).is_equal("event")
	assert_str(run.event_id).is_equal("whispering_well")
	assert_array(RunEngine.legal_actions(run)).has_size(3)
	RunEngine.apply(run, {"kind": "choose", "index": 1})
	assert_int(run.hero.hp).is_equal(43)
	assert_int(run.stat_bonus["wit"]).is_equal(1)
	assert_int(run.hero_snapshot().stats["wit"]).is_equal(1)
	assert_str(run.phase).is_equal("node")
	assert_int(run.node_index).is_equal(1)
	assert_str(run.event_id).is_equal("")
	var choice: Dictionary = TestFixtures.run_events_of(run, "event_choice")[0]
	assert_str(choice["choice"]).is_equal("offer")


func test_event_card_and_relic_effects() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "event", "event": "collapsed_crypt"}, {"kind": "event", "event": "lost_lantern"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "choose", "index": 0})
	assert_str(run.hero.deck[10].def_id).is_equal("bone_spear")
	assert_int(run.hero.hp).is_equal(62)
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "choose", "index": 0})
	assert_array(run.hero.relics).contains(["cracked_hourglass"])
	assert_str(run.phase).is_equal("exit")


func test_bad_event_choice_is_ignored() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "event", "event": "lost_lantern"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "choose", "index": 5})
	assert_str(run.phase).is_equal("event")
	assert_int(run.coin).is_equal(0)


func test_rest_heals_thirty_percent() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.hero.hp = 40
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_str(run.phase).is_equal("rest")
	RunEngine.apply(run, {"kind": "rest_heal"})
	assert_int(run.hero.hp).is_equal(61)
	assert_str(run.phase).is_equal("exit")
	assert_str(TestFixtures.run_events_of(run, "rest")[0]["choice"]).is_equal("heal")


func test_rest_upgrade_marks_a_card() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_array(RunEngine.legal_actions(run)).has_size(11)
	RunEngine.apply(run, {"kind": "rest_upgrade", "uid": 10})
	assert_bool(run.hero.find_card(10).upgraded).is_true()
	assert_int(run.hero.hp).is_equal(70)
	assert_str(run.phase).is_equal("exit")
	RunEngine.apply(TestFixtures.new_run(1, 1), {"kind": "rest_upgrade", "uid": 999})


func test_rest_upgrade_of_an_upgraded_card_is_refused() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.hero.upgrade_card(10)
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_array(RunEngine.legal_actions(run)).has_size(10)
	RunEngine.apply(run, {"kind": "rest_upgrade", "uid": 10})
	assert_str(run.phase).is_equal("rest")


func test_shop_stock_prices_and_purchases() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.coin = 200
	TestFixtures.set_nodes(run, [{"kind": "shop"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_str(run.phase).is_equal("shop")
	assert_array(run.shop["cards"]).has_size(3)
	assert_str(run.shop["relic"]).is_not_equal("")
	assert_array(RunEngine.legal_actions(run)).has_size(3 + 1 + 10 + 1)
	var card_id: String = run.shop["cards"][0]
	RunEngine.apply(run, {"kind": "buy_card", "card": card_id})
	assert_int(run.coin).is_equal(150)
	assert_str(run.hero.deck[10].def_id).is_equal(card_id)
	assert_array(run.shop["cards"]).has_size(2)
	RunEngine.apply(run, {"kind": "remove_card", "uid": 1})
	assert_int(run.coin).is_equal(75)
	assert_array(run.hero.deck).has_size(10)
	assert_object(run.hero.find_card(1)).is_null()
	RunEngine.apply(run, {"kind": "remove_card", "uid": 2})
	assert_array(run.hero.deck).has_size(10)
	RunEngine.apply(run, {"kind": "buy_relic"})
	assert_int(run.coin).is_equal(75)
	assert_array(run.hero.relics).has_size(1)
	assert_array(RunEngine.legal_actions(run)).has_size(2 + 1)
	RunEngine.apply(run, {"kind": "leave"})
	assert_str(run.phase).is_equal("exit")
	assert_dict(run.shop).is_empty()
	assert_array(TestFixtures.run_events_of(run, "shop_open")[0]["cards"]).has_size(3)


func test_shop_relic_purchase_and_determinism() -> void:
	var a := TestFixtures.new_run(1, 3)
	a.coin = 500
	TestFixtures.set_nodes(a, [{"kind": "shop"}])
	RunEngine.apply(a, {"kind": "enter"})
	var b := TestFixtures.new_run(1, 3)
	TestFixtures.set_nodes(b, [{"kind": "shop"}])
	RunEngine.apply(b, {"kind": "enter"})
	assert_dict(a.shop).is_equal(b.shop)
	var relic_id: String = a.shop["relic"]
	RunEngine.apply(a, {"kind": "buy_relic"})
	assert_int(a.coin).is_equal(350)
	assert_array(a.hero.relics).contains([relic_id])
	assert_str(a.shop["relic"]).is_equal("")
	assert_array(TestFixtures.run_events_of(a, "shop_buy")).has_size(1)
