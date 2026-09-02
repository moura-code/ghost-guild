extends GdUnitTestSuite


func _round_trip(run: RunState) -> RunState:
	var text := JSON.stringify(run.to_dict())
	return RunState.from_dict(TestFixtures.content(), JSON.parse_string(text))


func test_round_trip_between_nodes() -> void:
	var run := TestFixtures.new_run(2, 5)
	RunEngine.apply(run, {"kind": "draft_skip", "floor": 1})
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}, {"kind": "shop"}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "take_card", "card": run.reward["cards"][0]})
	run.stat_bonus["wit"] = 1
	var back := _round_trip(run)
	assert_int(back.run_seed).is_equal(5)
	assert_str(back.biome().id).is_equal("catacombs")
	assert_int(back.entry_floor).is_equal(2)
	assert_int(back.floor).is_equal(2)
	assert_str(back.phase).is_equal("node")
	assert_bool(back.is_resolved(0)).is_true()
	assert_int(back.next_unresolved()).is_equal(1)
	assert_array(back.nodes).is_equal(run.nodes)
	assert_int(back.fight_counter).is_equal(1)
	assert_int(back.coin).is_equal(run.coin)
	assert_float(back.soul).is_equal_approx(run.soul, 0.0001)
	assert_int(back.stat_bonus["wit"]).is_equal(1)
	assert_dict(back.stats.measured(2)).is_equal(run.stats.measured(2))
	assert_array(back.hero.deck).has_size(11)
	assert_int(back.hero.hp).is_equal(run.hero.hp)
	assert_bool(back.hero.picks_taken.has(1)).is_true()
	assert_bool(back.watch_unlocked).is_true()
	assert_array(back.events).is_empty()
	assert_object(back.fight).is_null()
	assert_dict(back.outcome).is_empty()


func test_resumed_run_replays_the_same_fight() -> void:
	var run := TestFixtures.new_run(1, 9)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["shambler"]}, {"kind": "rest"}])
	var back := _round_trip(run)
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(back, {"kind": "enter"})
	var a: Array = []
	for card in run.fight.hand:
		a.append(card.def_id)
	var b: Array = []
	for card in back.fight.hand:
		b.append(card.def_id)
	assert_array(a).is_equal(b)
	assert_str(run.fight.enemies[0].next_move).is_equal(back.fight.enemies[0].next_move)


func test_saving_during_a_fight_resumes_at_the_node_start() -> void:
	var run := TestFixtures.new_run(1, 4)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	var first_hand: Array = []
	for card in run.fight.hand:
		first_hand.append(card.def_id)
	RunEngine.apply(run, {"kind": "end_turn"})
	var d := run.to_dict()
	assert_str(d["phase"]).is_equal("node")
	assert_int(d["fight_counter"]).is_equal(0)
	var back := RunState.from_dict(TestFixtures.content(), JSON.parse_string(JSON.stringify(d)))
	assert_int(back.hero.hp).is_equal(70)
	RunEngine.apply(back, {"kind": "enter"})
	var hand: Array = []
	for card in back.fight.hand:
		hand.append(card.def_id)
	assert_array(hand).is_equal(first_hand)


func test_pending_offers_and_shop_survive() -> void:
	var run := TestFixtures.new_run(3, 2)
	var back := _round_trip(run)
	assert_str(back.phase).is_equal("descent")
	assert_array(back.descent_offers).has_size(2)
	assert_int(back.descent_offers[0]["floor"]).is_equal(1)
	assert_array(RunEngine.legal_actions(back)).has_size(4)
	var shop_run := TestFixtures.new_run(1, 2)
	shop_run.coin = 100
	TestFixtures.set_nodes(shop_run, [{"kind": "shop"}])
	RunEngine.apply(shop_run, {"kind": "enter"})
	var shop_back := _round_trip(shop_run)
	assert_str(shop_back.phase).is_equal("shop")
	assert_array(shop_back.shop["cards"]).is_equal(shop_run.shop["cards"])
	RunEngine.apply(shop_back, {"kind": "buy_card", "card": shop_back.shop["cards"][0]})
	assert_int(shop_back.coin).is_equal(50)


func test_outcome_round_trip_keeps_ints() -> void:
	var run := TestFixtures.new_run(1, 3)
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "watch"})
	var back := _round_trip(run)
	assert_str(back.outcome["kind"]).is_equal("watch")
	assert_int(back.outcome["floor"]).is_equal(1)
	assert_int(back.outcome["hero_hp"]).is_equal(70)
	assert_int(back.outcome["coin"]).is_equal(0)
