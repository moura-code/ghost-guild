extends GdUnitTestSuite


func _run() -> RunState:
	var run := TestFixtures.new_run(1, 774)
	TestFixtures.set_nodes(run, [
		{"kind": "shop", "required": false},
		{"kind": "fight", "enemies": ["bone_rat"], "required": true},
		{"kind": "shop", "required": false},
		{"kind": "rest", "required": false},
		{"kind": "event", "event": "whispering_well", "required": false}])
	run.coin = 1000
	return run


func _enter(run: RunState, index: int) -> void:
	RunEngine.apply(run, {"kind": "enter", "index": index})


func test_shop_visit_fight_revisit_purchase_reload_after_stairs_unlock() -> void:
	var run := _run()
	_enter(run, 0)
	var stock := run.shop.duplicate(true)
	RunEngine.apply(run, {"kind": "leave"})
	_enter(run, 1)
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "skip_card"})
	assert_bool(run.exit_ready()).is_true()
	assert_str(run.phase).is_equal("exit")
	_enter(run, 0)
	assert_dict(run.shop).is_equal(stock)
	var card: String = stock["cards"][0]
	var coin := run.coin
	var action := {"kind": "buy_card", "card": card, "context": run.action_context()}
	RunEngine.apply(run, action)
	assert_int(run.coin).is_equal(coin - stock["card_price"])
	var bought := run.to_dict()
	RunEngine.apply(run, action)
	assert_dict(run.to_dict()).is_equal(bought)
	var loaded := RunState.from_dict(run.content, Content.normalize_json(JSON.parse_string(JSON.stringify(bought))))
	RunEngine.apply(loaded, {"kind": "leave"})
	_enter(loaded, 0)
	assert_dict(loaded.shop).is_equal(run.shop)
	assert_int(loaded.coin).is_equal(run.coin)
	assert_bool(loaded.exit_ready()).is_true()
	RunEngine.apply(run, {"kind": "leave"})
	assert_array(TestFixtures.run_events_of(run, "floor_cleared")).has_size(1)
	assert_bool(run.can_enter(1)).is_false()


func test_two_shops_have_independent_stock_and_removal_is_once_per_shop() -> void:
	var run := _run()
	_enter(run, 0)
	var first := run.shop.duplicate(true)
	RunEngine.apply(run, {"kind": "remove_card", "uid": run.hero.deck[0].uid})
	RunEngine.apply(run, {"kind": "leave"})
	_enter(run, 2)
	assert_array(run.shop["cards"]).is_not_equal(first["cards"])
	assert_bool(run.shop["removed"]).is_false()
	RunEngine.apply(run, {"kind": "leave"})
	_enter(run, 0)
	assert_bool(run.shop["removed"]).is_true()
	for action in RunEngine.legal_actions(run):
		assert_str(action["kind"]).is_not_equal("remove_card")


func test_sold_out_shop_keeps_empty_stock_and_zero_coin_never_buys() -> void:
	var run := _run()
	_enter(run, 0)
	for card in run.shop["cards"].duplicate():
		RunEngine.apply(run, {"kind": "buy_card", "card": card})
	RunEngine.apply(run, {"kind": "buy_relic"})
	RunEngine.apply(run, {"kind": "remove_card", "uid": run.hero.deck[0].uid})
	var stock := run.shop.duplicate(true)
	RunEngine.apply(run, {"kind": "leave"})
	_enter(run, 0)
	assert_dict(run.shop).is_equal(stock)
	assert_array(RunEngine.legal_actions(run)).contains_exactly([{"kind": "leave"}])
	run.coin = 0
	RunEngine.apply(run, {"kind": "leave"})
	_enter(run, 2)
	assert_array(RunEngine.legal_actions(run)).contains_exactly([{"kind": "leave"}])


func test_optional_services_work_once_after_required_fight_and_lethal_events_end() -> void:
	var run := _run()
	_enter(run, 1)
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "skip_card"})
	_enter(run, 3)
	RunEngine.apply(run, {"kind": "rest_heal"})
	assert_str(run.phase).is_equal("exit")
	assert_bool(run.can_enter(3)).is_false()
	run.hero.hp = 7
	_enter(run, 4)
	RunEngine.apply(run, {"kind": "choose", "index": 1})
	assert_str(run.outcome["kind"]).is_equal("death")
	var ended := run.to_dict()
	RunEngine.apply(run, {"kind": "choose", "index": 1})
	assert_dict(run.to_dict()).is_equal(ended)


func test_generated_floors_have_two_requirements_and_one_optional_room() -> void:
	var c := TestFixtures.content()
	for floor in [1, 4, 10, 11, 20, 21, 30, 31, 61]:
		for seed in 30:
			var nodes := FloorGenerator.generate(c, Biomes.for_floor(c, floor), floor, Rng.new(seed))
			assert_int(nodes.filter(func(n: Dictionary) -> bool: return n["required"]).size()).is_equal(2)
			assert_int(nodes.filter(func(n: Dictionary) -> bool: return not n["required"]).size()).is_equal(1)
