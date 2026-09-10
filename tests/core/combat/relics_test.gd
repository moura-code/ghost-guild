extends GdUnitTestSuite


func test_fight_start_hooks() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "bone_rat"])
	s.relics = ["sextons_lantern", "bone_charm", "lead_censer"] as Array[String]
	Relics.fire(s, "on_fight_start")
	assert_int(s.hero_block).is_equal(3)
	assert_int(s.might()).is_equal(1)
	assert_int(s.enemies[0].status("weak")).is_equal(1)
	assert_int(s.enemies[1].status("weak")).is_equal(1)
	assert_array(TestFixtures.events_of(s, "relic_triggered")).has_size(3)


func test_fight_end_hooks_and_unrelated_hook() -> void:
	var s := TestFixtures.bare_state()
	s.hero_hp = 50
	s.relics = ["ossuary_key", "grave_coin"] as Array[String]
	Relics.fire(s, "on_turn_start")
	assert_int(s.hero_hp).is_equal(50)
	Relics.fire(s, "on_fight_end")
	assert_int(s.hero_hp).is_equal(54)
	assert_int(TestFixtures.events_of(s, "coin")[0]["amount"]).is_equal(10)


func test_draw_hook_draws_from_pile() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.fill_draw(s, ["strike", "brace"])
	s.relics = ["cracked_hourglass"] as Array[String]
	Relics.fire(s, "on_fight_start")
	assert_array(s.hand).has_size(1)


func test_unknown_relic_is_ignored() -> void:
	var s := TestFixtures.bare_state()
	s.relics = ["not_a_relic"] as Array[String]
	Relics.fire(s, "on_fight_start")
	assert_array(TestFixtures.events_of(s, "relic_triggered")).is_empty()


func test_on_damage_taken_fires_after_enemy_attack() -> void:
	var content := Content.load_from("res://data")
	content.relics["fx_shell"] = RelicDef.from_dict({"id": "fx_shell", "name": "x", "text": "x", "hooks": {"on_damage_taken": [{"op": "block", "amount": 2}]}})
	var s := TestFixtures.bare_state(["bone_rat"])
	s.content = content
	s.relics = ["fx_shell"] as Array[String]
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(64)
	assert_int(s.hero_block).is_equal(2)
	s.hero_block = 50
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_block).is_equal(44)
