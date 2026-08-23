extends GdUnitTestSuite


func _autopilot() -> RunAutopilot:
	var ap := RunAutopilot.new()
	ap.survival_samples = 3
	return ap


func test_choices_per_phase() -> void:
	var ap := _autopilot()
	var run := TestFixtures.new_run(2, 1)
	var pick := ap.choose(run)
	assert_str(pick["kind"]).is_equal("draft_pick")
	var best: String = pick["card"]
	for id in run.descent_offers[0]["cards"]:
		var card: CardDef = TestFixtures.content().cards[id]
		var chosen: CardDef = TestFixtures.content().cards[best]
		assert_float(chosen.ai_value).is_greater_equal(card.ai_value)
	RunEngine.apply(run, pick)
	assert_str(ap.choose(run)["kind"]).is_equal("enter")
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	run.hero.hp = 20
	assert_str(ap.choose(run)["kind"]).is_equal("rest_heal")
	run.hero.hp = 70
	assert_str(ap.choose(run)["kind"]).is_equal("rest_upgrade")
	TestFixtures.set_nodes(run, [{"kind": "shop"}])
	RunEngine.apply(run, {"kind": "enter"})
	assert_str(ap.choose(run)["kind"]).is_equal("leave")
	run.coin = 60
	assert_str(ap.choose(run)["kind"]).is_equal("buy_card")


func test_play_run_ends_every_run_within_the_slice() -> void:
	for seed in [1, 2, 3]:
		var run := TestFixtures.new_run(1, seed, true)
		var outcome := _autopilot().play_run(run)
		assert_bool(run.is_over()).is_true()
		assert_bool(["death", "retreat", "watch"].has(outcome["kind"])).is_true()
		assert_int(outcome["floor"]).is_between(1, 10)
		assert_array(TestFixtures.run_events_of(run, "run_end")).has_size(1)


func test_runs_are_deterministic_for_a_seed() -> void:
	var a := TestFixtures.new_run(1, 6, true)
	var b := TestFixtures.new_run(1, 6, true)
	var oa := _autopilot().play_run(a)
	var ob := _autopilot().play_run(b)
	assert_dict(oa).is_equal(ob)
	assert_array(a.events).is_equal(b.events)
	assert_int(a.hero.deck.size()).is_equal(b.hero.deck.size())


func test_locked_watch_with_no_resolve_still_ends_at_the_last_floor() -> void:
	var run := TestFixtures.new_run(1, 2, false)
	run.hero.resolve = 0
	run.hero.hp = 100000
	run.hero.max_hp = 100000
	var ap := _autopilot()
	ap.push_threshold = 0.0
	ap.survival_samples = 1
	var outcome := ap.play_run(run)
	assert_str(outcome["kind"]).is_equal("watch")
	assert_int(outcome["floor"]).is_equal(10)
