extends GdUnitTestSuite


func _at_exit(floor: int = 1, run_seed: int = 1, watch_unlocked: bool = true) -> RunState:
	var run := TestFixtures.new_run(1, run_seed, watch_unlocked)
	run.floor = floor
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	run.hero.hp = 70
	RunEngine.apply(run, {"kind": "rest_heal"})
	return run


func test_exit_summary_and_legal_actions() -> void:
	var run := _at_exit(2)
	run.stats.record(2, true, 4)
	var summary := RunEngine.exit_summary(run, 3)
	assert_int(summary["floor"]).is_equal(2)
	assert_int(summary["next_floor"]).is_equal(3)
	assert_int(summary["measured"]["wins"]).is_equal(1)
	assert_float(summary["survival"]).is_between(0.0, 1.0)
	assert_bool(summary["can_push"]).is_true()
	assert_bool(summary["can_retreat"]).is_true()
	assert_bool(summary["can_watch"]).is_true()
	var kinds: Array = []
	for action in RunEngine.legal_actions(run):
		kinds.append(action["kind"])
	assert_array(kinds).is_equal(["push", "retreat", "watch"])


func test_push_enters_the_next_floor() -> void:
	var run := _at_exit(3)
	RunEngine.apply(run, {"kind": "push"})
	assert_int(run.floor).is_equal(4)
	assert_str(run.phase).is_equal("node")
	assert_array(run.nodes).has_size(3)
	assert_int(run.node_index).is_equal(0)
	assert_array(TestFixtures.run_events_of(run, "floor_enter")).has_size(2)
	assert_str(TestFixtures.run_events_of(run, "exit_decision")[0]["choice"]).is_equal("push")


func test_no_push_past_the_last_floor_but_watch_is_always_possible_there() -> void:
	var last := Biomes.depth(TestFixtures.content())
	var run := _at_exit(last, 1, false)
	var summary := RunEngine.exit_summary(run, 2)
	assert_bool(summary["can_push"]).is_false()
	assert_float(summary["survival"]).is_equal(-1.0)
	assert_bool(summary["can_watch"]).is_true()
	var kinds: Array = []
	for action in RunEngine.legal_actions(run):
		kinds.append(action["kind"])
	assert_array(kinds).is_equal(["retreat", "watch"])
	RunEngine.apply(run, {"kind": "push"})
	assert_str(run.phase).is_equal("exit")
	assert_int(run.floor).is_equal(last)


func test_retreat_spends_resolve_sets_camp_and_keeps_hp() -> void:
	var run := _at_exit(4)
	run.hero.hp = 33
	run.coin = 50
	run.soul = 5.0
	run.stat_bonus["wit"] = 2
	RunEngine.apply(run, {"kind": "retreat"})
	assert_str(run.phase).is_equal("ended")
	assert_str(run.outcome["kind"]).is_equal("retreat")
	assert_int(run.outcome["floor"]).is_equal(4)
	assert_int(run.hero.resolve).is_equal(0)
	assert_int(run.hero.camp).is_equal(4)
	assert_int(run.hero.hp).is_equal(33)
	assert_float(run.outcome["soul"]).is_equal_approx(10.0, 0.0001)
	assert_dict(run.stat_bonus).is_empty()
	assert_int(run.outcome["stat_bonus"]["wit"]).is_equal(2)


func test_retreat_needs_resolve() -> void:
	var run := _at_exit(2)
	run.hero.resolve = 0
	var kinds: Array = []
	for action in RunEngine.legal_actions(run):
		kinds.append(action["kind"])
	assert_array(kinds).is_equal(["push", "watch"])
	RunEngine.apply(run, {"kind": "retreat"})
	assert_str(run.phase).is_equal("exit")


func test_watch_is_locked_before_the_first_death() -> void:
	var run := _at_exit(2, 1, false)
	var kinds: Array = []
	for action in RunEngine.legal_actions(run):
		kinds.append(action["kind"])
	assert_array(kinds).is_equal(["push", "retreat"])
	RunEngine.apply(run, {"kind": "watch"})
	assert_str(run.phase).is_equal("exit")
	run.watch_unlocked = true
	RunEngine.apply(run, {"kind": "watch"})
	assert_str(run.outcome["kind"]).is_equal("watch")
	assert_int(run.hero.resolve).is_equal(1)
	assert_int(run.hero.camp).is_equal(0)


func test_survival_chance_is_deterministic_and_sensible() -> void:
	var content := TestFixtures.content()
	var biome: BiomeDef = content.biomes["catacombs"]
	var hero := TestFixtures.hero().snapshot()
	var easy := RunProjection.survival_chance(content, hero, biome, 1, 7, 6)
	var again := RunProjection.survival_chance(content, hero, biome, 1, 7, 6)
	assert_float(easy).is_equal(again)
	assert_float(easy).is_greater_equal(0.3)
	var deadly := RunProjection.survival_chance(content, hero, biome, 10, 7, 4)
	assert_float(deadly).is_less(0.5)
	assert_float(RunProjection.survival_chance(content, hero, biome, 1, 7, 0)).is_equal(0.0)


func test_simulate_floor_carries_hp_and_stops_on_a_loss() -> void:
	var content := TestFixtures.content()
	var biome: BiomeDef = content.biomes["catacombs"]
	var fresh := TestFixtures.hero().snapshot()
	var ok := RunProjection.simulate_floor(content, fresh, biome, 1, 3, Autopilot.new())
	assert_bool(ok == (fresh.hp > 0)).is_true()
	assert_int(fresh.hp).is_less_equal(70)
	var dying := TestFixtures.hero().snapshot()
	dying.hp = 1
	assert_bool(RunProjection.simulate_floor(content, dying, biome, 10, 3, Autopilot.new())).is_false()
	assert_int(dying.hp).is_equal(0)
