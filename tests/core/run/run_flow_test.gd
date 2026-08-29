extends GdUnitTestSuite


func test_start_run_at_floor_one_enters_the_floor() -> void:
	var run := TestFixtures.new_run(1, 1)
	assert_str(run.phase).is_equal("node")
	assert_int(run.floor).is_equal(1)
	assert_array(run.nodes).has_size(3)
	assert_array(run.descent_offers).is_empty()
	assert_int(run.hero.runs).is_equal(1)
	var types: Array = []
	for ev in run.events:
		types.append(ev["type"])
	assert_array(types).contains(["run_start", "floor_enter"])
	assert_array(RunEngine.legal_actions(run)).is_equal([
		{"kind": "enter", "index": 0},
		{"kind": "enter", "index": 1},
		{"kind": "enter", "index": 2},
	])


func test_descent_offers_one_pick_per_skipped_floor() -> void:
	var run := TestFixtures.new_run(3, 1)
	assert_str(run.phase).is_equal("descent")
	assert_array(run.descent_offers).has_size(2)
	assert_int(run.descent_offers[0]["floor"]).is_equal(1)
	assert_array(run.descent_offers[0]["cards"]).has_size(3)
	assert_array(RunEngine.legal_actions(run)).has_size(4)
	var card_id: String = run.descent_offers[0]["cards"][0]
	RunEngine.apply(run, {"kind": "draft_pick", "floor": 1, "card": card_id})
	assert_array(run.hero.deck).has_size(11)
	assert_str(run.hero.deck[10].def_id).is_equal(card_id)
	assert_bool(run.hero.picks_taken.has(1)).is_true()
	assert_str(run.phase).is_equal("descent")
	RunEngine.apply(run, {"kind": "draft_skip", "floor": 2})
	assert_bool(run.hero.picks_taken.has(2)).is_true()
	assert_str(run.phase).is_equal("node")
	assert_int(run.floor).is_equal(3)
	assert_array(TestFixtures.run_events_of(run, "draft_offer")).has_size(2)


func test_picks_are_granted_once_per_floor_per_hero() -> void:
	var hero := TestFixtures.hero()
	var first := TestFixtures.new_run(3, 1, true, hero)
	RunEngine.apply(first, {"kind": "draft_skip", "floor": 1})
	RunEngine.apply(first, {"kind": "draft_skip", "floor": 2})
	var second := TestFixtures.new_run(3, 2, true, hero)
	assert_array(second.descent_offers).is_empty()
	assert_str(second.phase).is_equal("node")
	assert_int(hero.runs).is_equal(2)


func test_draft_offers_are_deterministic_per_seed() -> void:
	var a := DescentDraft.offers(TestFixtures.content(), TestFixtures.hero(), TestFixtures.content().biomes["catacombs"], 4, 11)
	var b := DescentDraft.offers(TestFixtures.content(), TestFixtures.hero(), TestFixtures.content().biomes["catacombs"], 4, 11)
	assert_array(a).has_size(3)
	assert_array(a).is_equal(b)


func test_entering_a_fight_node_starts_a_fight() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}, {"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_str(run.phase).is_equal("fight")
	assert_str(run.fight.enemies[0].def_id).is_equal("bone_rat")
	assert_int(run.fight.hero_hp).is_equal(70)
	assert_int(run.fight.floor).is_equal(1)
	assert_int(run.fight_counter).is_equal(1)
	assert_array(RunEngine.legal_actions(run)).is_not_empty()
	assert_array(TestFixtures.run_events_of(run, "fight_begin")).has_size(1)


func test_apply_returns_combat_events_then_run_events() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	var events := RunEngine.apply(run, {"kind": "end_turn"})
	assert_array(events).is_not_empty()
	assert_str(events[0]["type"]).is_equal("turn_end")


func test_winning_a_fight_pays_and_offers_cards() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	assert_str(run.phase).is_equal("reward")
	assert_int(run.coin).is_equal(12)
	assert_float(run.soul).is_equal_approx(1.3, 0.0001)
	assert_array(run.reward["cards"]).has_size(3)
	for id in run.reward["cards"]:
		var card: CardDef = TestFixtures.content().cards[id]
		assert_str(card.rarity).is_not_equal("basic")
	assert_int(run.hero.hp).is_equal(run.fight.hero_hp)
	assert_dict(run.stats.measured(1)).contains_key_value("wins", 1)
	var result: Dictionary = TestFixtures.run_events_of(run, "fight_result")[0]
	assert_bool(result["won"]).is_true()
	assert_int(result["turns"]).is_equal(run.fight.turn)


func test_taking_a_reward_advances_to_the_next_node() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}, {"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	var card_id: String = run.reward["cards"][1]
	RunEngine.apply(run, {"kind": "take_card", "card": card_id})
	assert_array(run.hero.deck).has_size(11)
	assert_str(run.hero.deck[10].def_id).is_equal(card_id)
	assert_str(run.phase).is_equal("node")
	assert_bool(run.is_resolved(0)).is_true()
	assert_int(run.next_unresolved()).is_equal(1)
	assert_dict(run.reward).is_empty()


func test_skipping_a_reward_on_the_last_node_reaches_the_exit() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	RunEngine.apply(run, {"kind": "skip_card"})
	assert_str(run.phase).is_equal("exit")
	assert_array(TestFixtures.run_events_of(run, "floor_cleared")).has_size(1)


func test_elite_grants_a_relic_and_boss_offers_rares() -> void:
	var run := TestFixtures.new_run(1, 1)
	TestFixtures.set_nodes(run, [{"kind": "elite", "enemies": ["bone_rat"]}, {"kind": "boss", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	assert_array(run.hero.relics).has_size(2)
	assert_int(run.coin).is_greater_equal(24)
	RunEngine.apply(run, {"kind": "skip_card"})
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	assert_array(run.hero.relics).has_size(3)
	assert_int(run.coin).is_greater_equal(60)
	for id in run.reward["cards"]:
		var card: CardDef = TestFixtures.content().cards[id]
		assert_str(card.rarity).is_equal("rare")


func test_losing_a_fight_ends_the_run_in_death() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.hero.hp = 1
	run.coin = 30
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["shambler", "shambler", "shambler"]}])
	RunEngine.apply(run, {"kind": "enter"})
	TestFixtures.autofight(run)
	assert_str(run.phase).is_equal("ended")
	assert_bool(run.is_over()).is_true()
	assert_str(run.outcome["kind"]).is_equal("death")
	assert_str(run.outcome["killer"]).is_equal("shambler")
	assert_int(run.hero.hp).is_equal(0)
	assert_float(run.outcome["soul_from_coin"]).is_equal_approx(3.0, 0.0001)
	assert_dict(run.stats.measured(1)).contains_key_value("fights", 1)
	assert_array(RunEngine.legal_actions(run)).is_empty()
	assert_array(RunEngine.apply(run, {"kind": "enter"})).is_empty()
	assert_object(run.fight).is_null()
	assert_str(run.outcome["cause"]).is_equal("hero_died")


func test_killer_of_reads_the_last_hero_damage() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "shambler"])
	EffectResolver.hit_hero(s, 5, 1, true)
	assert_str(RunEngine.killer_of(s)).is_equal("shambler")
	EffectResolver.direct_damage_hero(s, 3, "poison")
	assert_str(RunEngine.killer_of(s)).is_equal("poison")
	assert_str(RunEngine.killer_of(TestFixtures.bare_state())).is_equal("")


func test_turn_cap_loss_is_a_death_with_zero_hp() -> void:
	var run := TestFixtures.new_run(1, 1)
	run.hero.hp = 100000
	run.hero.max_hp = 100000
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	run.fight.enemies[0].hp = 1000000
	for i in 40:
		if run.phase != "fight":
			break
		RunEngine.apply(run, {"kind": "end_turn"})
	assert_str(run.phase).is_equal("ended")
	assert_str(run.outcome["kind"]).is_equal("death")
	assert_int(run.hero.hp).is_equal(0)
	assert_int(run.outcome["hero_hp"]).is_equal(0)
	assert_dict(run.stats.measured(1)).contains_key_value("fights", 1)
	assert_str(run.outcome["cause"]).is_equal("turn_cap")
	assert_str(run.outcome["killer"]).is_equal("")


## Giving up. A run you cannot leave is a run that traps the player, and
## "quit the game and never come back" is the workaround they use instead.
func test_you_can_give_up_from_any_phase() -> void:
	for phase in ["node", "reward", "rest", "shop", "event", "exit"]:
		var run := TestFixtures.new_run()
		TestFixtures.set_nodes(run, [{"kind": "rest"}])
		run.phase = phase
		RunEngine.apply(run, {"kind": "abandon"})
		assert_bool(run.is_over()).override_failure_message(
			"could not give up from phase %s" % phase).is_true()
		assert_str(String(run.outcome["kind"])).is_equal("retreat")


func test_you_can_give_up_in_the_middle_of_a_fight() -> void:
	var run := TestFixtures.new_run()
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_str(run.phase).is_equal("fight")
	RunEngine.apply(run, {"kind": "abandon"})
	assert_bool(run.is_over()).is_true()
	assert_object(run.fight).is_null()


func test_giving_up_keeps_what_you_banked_and_earns_nothing_new() -> void:
	var run := TestFixtures.new_run()
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	run.soul = 12.0
	run.coin = 30
	RunEngine.apply(run, {"kind": "abandon"})
	var rate := float(run.content.balance.get("coin_to_soul", 0.1))
	assert_float(float(run.outcome["soul"])).is_equal_approx(12.0 + 30.0 * rate, 0.001)


func test_giving_up_is_never_offered_to_the_autopilot() -> void:
	# If it were in legal_actions the balance simulator would start abandoning
	# runs, and every §12 invariant would be measuring a different game.
	# "shop" and "event" are left out: legal_actions reads run.shop and
	# run.event_id, which only a real node sets, so forcing the phase alone
	# would be testing the fixture rather than the engine.
	for phase in ["node", "reward", "rest", "exit"]:
		var run := TestFixtures.new_run()
		TestFixtures.set_nodes(run, [{"kind": "rest"}])
		run.phase = phase
		for action in RunEngine.legal_actions(run):
			assert_str(String(action.get("kind", ""))).is_not_equal("abandon")


func test_giving_up_twice_changes_nothing() -> void:
	var run := TestFixtures.new_run()
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "abandon"})
	var events := run.events.size()
	RunEngine.apply(run, {"kind": "abandon"})
	assert_int(run.events.size()).is_equal(events)
