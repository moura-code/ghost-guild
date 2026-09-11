extends GdUnitTestSuite

const EVENTS := ["silent_bell", "spore_press", "cooling_trough"]


func _at(id: String) -> RunState:
	var run := TestFixtures.new_run(1, 227)
	TestFixtures.set_nodes(run, [{"kind": "event", "event": id, "required": false}])
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	return run


func test_new_events_have_localized_previews_and_a_free_exit_in_each_biome() -> void:
	for locale in ["en", "es"]:
		var content := Content.load_from("res://data", locale)
		for id in EVENTS:
			var event: EventDef = content.events[id]
			assert_str(content.text(event.name_key)).is_not_equal(event.name_key)
			for choice in event.choices:
				assert_str(content.text(choice["text"])).is_not_equal(choice["text"])
			var run := _at(id)
			run.content = content
			assert_array(RunEngine.legal_actions(run)).contains({"kind": "choose", "index": 2})
			var hero := run.hero.to_dict()
			RunEngine.apply(run, {"kind": "choose", "index": 2})
			assert_dict(run.hero.to_dict()).is_equal(hero)
			assert_bool(run.can_enter(0)).is_false()
			assert_str(FloorGenerator.pick_event(content, event.biome, content.events.keys(), Rng.new(1))).is_empty()


func test_paid_outcomes_cannot_repeat_after_reload_or_with_stale_input() -> void:
	for id in EVENTS:
		var run := _at(id)
		run.coin = 100
		run.hero.hp -= 4
		var action := {"kind": "choose", "index": 0, "context": run.action_context()}
		RunEngine.apply(run, action)
		assert_int(run.coin).is_less(100)
		assert_int(run.hero.hp).is_less_equal(run.hero.max_hp)
		var saved := run.to_dict()
		var back := RunState.from_dict(run.content, Content.normalize_json(JSON.parse_string(JSON.stringify(saved))))
		RunEngine.apply(back, action)
		RunEngine.apply(back, {"kind": "enter", "index": 0})
		assert_dict(back.to_dict()).is_equal(saved)


func test_unaffordable_trade_is_inert_and_autopilot_chooses_an_available_option() -> void:
	for id in EVENTS:
		var run := _at(id)
		var before := run.to_dict()
		RunEngine.apply(run, {"kind": "choose", "index": 0})
		assert_dict(run.to_dict()).is_equal(before)
		var action := RunAutopilot.new().choose(run)
		assert_array(RunEngine.legal_actions(run)).contains(action)
		RunEngine.apply(run, action)
		assert_str(run.phase).is_not_equal("event")


func test_bell_health_cost_can_end_the_run_once() -> void:
	var run := _at("silent_bell")
	run.hero.hp = 6
	RunEngine.apply(run, {"kind": "choose", "index": 1})
	assert_str(run.outcome["kind"]).is_equal("death")
	assert_int(run.coin).is_equal(30)
	RunEngine.apply(run, {"kind": "choose", "index": 1})
	assert_array(TestFixtures.run_events_of(run, "run_end")).has_size(1)
