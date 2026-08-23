extends GdUnitTestSuite


func _run() -> RunState:
	var run := RunState.new()
	run.content = TestFixtures.content()
	run.hero = Hero.create(TestFixtures.content(), "sexton", "Tester")
	run.run_seed = 5
	run.biome_id = "catacombs"
	return run


func _events_of(run: RunState, type: String) -> Array:
	var out: Array = []
	for ev in run.events:
		if ev["type"] == type:
			out.append(ev)
	return out


func test_heal_damage_and_percent() -> void:
	var run := _run()
	run.hero.hp = 60
	RunEffects.apply(run, [{"op": "heal", "amount": 15}])
	assert_int(run.hero.hp).is_equal(70)
	assert_int(_events_of(run, "hero_healed")[0]["amount"]).is_equal(10)
	RunEffects.apply(run, [{"op": "damage", "amount": 25}])
	assert_int(run.hero.hp).is_equal(45)
	RunEffects.apply(run, [{"op": "heal_percent", "amount": 30}])
	assert_int(run.hero.hp).is_equal(66)
	RunEffects.apply(run, [{"op": "damage", "amount": 100}])
	assert_int(run.hero.hp).is_equal(0)


func test_coin_and_soul_clamp_at_zero() -> void:
	var run := _run()
	RunEffects.apply(run, [{"op": "coin", "amount": 40}, {"op": "coin", "amount": -15}])
	assert_int(run.coin).is_equal(25)
	RunEffects.apply(run, [{"op": "coin", "amount": -100}])
	assert_int(run.coin).is_equal(0)
	RunEffects.apply(run, [{"op": "soul", "amount": 2}])
	assert_float(run.soul).is_equal_approx(2.0, 0.0001)
	assert_array(_events_of(run, "coin_changed")).has_size(3)


func test_cards_relics_stats_and_max_hp() -> void:
	var run := _run()
	RunEffects.apply(run, [{"op": "add_card", "card": "bone_spear"}])
	assert_str(run.hero.deck[10].def_id).is_equal("bone_spear")
	assert_int(_events_of(run, "card_gained")[0]["uid"]).is_equal(11)
	RunEffects.apply(run, [{"op": "relic", "relic": "bone_charm"}, {"op": "relic", "relic": "bone_charm"}])
	assert_array(run.hero.relics).is_equal(["sextons_lantern", "bone_charm"])
	assert_array(_events_of(run, "relic_already_owned")).has_size(1)
	RunEffects.apply(run, [{"op": "stat", "stat": "wit", "amount": 1}, {"op": "stat", "stat": "wit", "amount": 2}])
	assert_int(run.stat_bonus["wit"]).is_equal(3)
	assert_int(run.hero.stats["wit"]).is_equal(0)
	assert_int(run.hero_snapshot().stats["wit"]).is_equal(3)
	run.hero.hp = 65
	RunEffects.apply(run, [{"op": "max_hp", "amount": 5}])
	assert_int(run.hero.max_hp).is_equal(75)
	assert_int(run.hero.hp).is_equal(70)


func test_state_helpers() -> void:
	var run := _run()
	assert_str(run.biome().id).is_equal("catacombs")
	assert_int(run.sub_rng("x", 1).randi_range("a", 0, 1000)).is_equal(run.sub_rng("x", 1).randi_range("a", 0, 1000))
	assert_int(run.sub_rng("x", 1).randi_range("a", 0, 100000)).is_not_equal(run.sub_rng("x", 2).randi_range("a", 0, 100000))
	assert_dict(run.current_node()).is_empty()
	run.nodes = [{"kind": "rest"}]
	assert_str(run.current_node()["kind"]).is_equal("rest")
	assert_bool(run.is_over()).is_false()
	run.phase = "ended"
	assert_bool(run.is_over()).is_true()
