extends GdUnitTestSuite


func _start(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1, relics: Array = []) -> FightState:
	var hero := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	if not relics.is_empty():
		hero.relics.clear()
		for r in relics:
			hero.relics.append(String(r))
	return CombatEngine.start_fight(TestFixtures.content(), hero, enemy_ids, floor, Rng.new(seed))


func _play(s: FightState, def_id: String, target: int = -1) -> Array:
	for i in s.hand.size():
		if s.hand[i].def_id == def_id:
			return CombatEngine.apply(s, {"kind": "play", "hand_index": i, "target": target})
	fail("card not in hand: " + def_id)
	return []


func _end(s: FightState) -> Array:
	return CombatEngine.apply(s, {"kind": "end_turn"})


func test_start_fight_sets_up_turn_one() -> void:
	var s := _start()
	assert_str(s.phase).is_equal("player")
	assert_int(s.turn).is_equal(1)
	assert_int(s.energy).is_equal(3)
	assert_int(s.hero_block).is_equal(3)
	assert_array(s.hand).has_size(5)
	assert_array(s.draw_pile).has_size(5)
	assert_str(s.enemies[0].next_move).is_not_equal("")
	assert_array(TestFixtures.events_of(s, "fight_start")).has_size(1)
	assert_array(TestFixtures.events_of(s, "relic_triggered")).has_size(1)
	assert_array(TestFixtures.events_of(s, "turn_start")).has_size(1)
	assert_array(TestFixtures.events_of(s, "card_drawn")).has_size(5)


func test_focus_thresholds_raise_energy_and_draw() -> void:
	var hero := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	hero.stats["focus"] = 6
	var s := CombatEngine.start_fight(TestFixtures.content(), hero, ["bone_rat"], 1, Rng.new(1))
	assert_int(s.max_energy).is_equal(4)
	assert_int(s.energy).is_equal(4)
	assert_int(s.draw_per_turn).is_equal(6)
	assert_array(s.hand).has_size(6)


func test_legal_actions_respect_energy_and_targets() -> void:
	var s := _start(["bone_rat", "bone_rat"])
	TestFixtures.give_hand(s, ["strike", "brace", "bone_wall", "reaping"])
	s.energy = 1
	assert_array(CombatEngine.legal_actions(s)).has_size(4)
	s.energy = 3
	assert_array(CombatEngine.legal_actions(s)).has_size(7)
	s.enemies[1].alive = false
	assert_array(CombatEngine.legal_actions(s)).has_size(5)


func test_play_card_costs_energy_and_discards() -> void:
	var s := _start()
	TestFixtures.give_hand(s, ["strike", "brace"])
	var events := _play(s, "strike", 0)
	assert_int(s.energy).is_equal(2)
	assert_array(s.hand).has_size(1)
	assert_array(s.discard_pile).has_size(1)
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 6)
	assert_str(events[0]["type"]).is_equal("card_played")
	assert_int(s.cards_played_this_turn).is_equal(1)


func test_exhaust_and_power_go_to_exhaust_pile() -> void:
	var s := _start()
	TestFixtures.give_hand(s, ["exhume", "vigil"])
	TestFixtures.fill_draw(s, ["strike", "strike"])
	_play(s, "exhume")
	assert_array(s.exhaust_pile).has_size(1)
	assert_array(s.hand).has_size(3)
	_play(s, "vigil")
	assert_array(s.exhaust_pile).has_size(2)
	assert_int(s.hero_status("vigil")).is_equal(3)
	assert_array(TestFixtures.events_of(s, "card_exhausted")).has_size(2)


func test_bleed_hurts_hero_on_attack_cards_only() -> void:
	var s := _start()
	s.statuses["bleed"] = 2
	TestFixtures.give_hand(s, ["strike", "brace"])
	_play(s, "strike", 0)
	assert_int(s.hero_hp).is_equal(68)
	_play(s, "brace")
	assert_int(s.hero_hp).is_equal(68)


func test_end_turn_enemy_acts_and_new_turn_begins() -> void:
	var s := _start(["shambler"])
	assert_str(s.enemies[0].next_move).is_equal("lurch")
	var events := _end(s)
	assert_int(s.hero_hp).is_equal(66)
	assert_int(s.turn).is_equal(2)
	assert_int(s.energy).is_equal(3)
	assert_int(s.hero_block).is_equal(0)
	assert_array(s.hand).has_size(5)
	assert_array(s.discard_pile).has_size(5)
	assert_str(s.enemies[0].next_move).is_equal("lurch")
	var types: Array = []
	for ev in events:
		types.append(ev["type"])
	assert_array(types).contains(["turn_end", "enemy_move", "turn_start"])


func test_win_fires_fight_end_relics_and_stops_play() -> void:
	var s := _start(["bone_rat"], 1, 1, ["ossuary_key"])
	s.hero_hp = 60
	TestFixtures.give_hand(s, ["strike", "strike", "strike"])
	_play(s, "strike", 0)
	_play(s, "strike", 0)
	assert_str(s.phase).is_equal("player")
	_play(s, "strike", 0)
	assert_str(s.phase).is_equal("won")
	assert_int(s.hero_hp).is_equal(64)
	assert_array(TestFixtures.events_of(s, "fight_won")).has_size(1)
	assert_array(CombatEngine.legal_actions(s)).is_empty()
	assert_array(_end(s)).is_empty()


func test_loss_when_hero_dies() -> void:
	var s := _start(["shambler"])
	s.hero_hp = 1
	_end(s)
	assert_str(s.phase).is_equal("lost")
	assert_str(TestFixtures.events_of(s, "fight_lost")[0]["reason"]).is_equal("hero_died")


func test_retain_and_reshuffle_across_turns() -> void:
	var s := _start(["bone_rat"])
	TestFixtures.give_hand(s, ["shroud"])
	s.draw_pile.clear()
	for i in 3:
		s.discard_pile.append(s.new_card("strike"))
	_end(s)
	assert_array(s.hand).has_size(4)
	assert_str(s.hand[0].def_id).is_equal("shroud")
	assert_array(TestFixtures.events_of(s, "reshuffle")).has_size(1)


func test_turn_cap_loses_the_fight() -> void:
	var s := _start(["bone_rat"])
	s.hero_hp = 100000
	s.hero_max_hp = 100000
	s.enemies[0].hp = 1000000
	for i in 40:
		if s.is_over():
			break
		_end(s)
	assert_str(s.phase).is_equal("lost")
	assert_int(s.turn).is_equal(30)
	assert_str(TestFixtures.events_of(s, "fight_lost")[0]["reason"]).is_equal("turn_cap")


func test_summon_during_enemy_turn() -> void:
	var s := _start(["mother_of_bones"])
	assert_str(s.enemies[0].next_move).is_equal("raise")
	_end(s)
	assert_array(s.enemies).has_size(2)
	assert_str(s.enemies[1].def_id).is_equal("bone_rat")


func test_x_cost_spends_all_energy() -> void:
	var content := Content.load_from("res://data")
	content.cards["fx_surge"] = CardDef.from_dict({"id": "fx_surge", "name": "x", "text": "x", "pool": "sexton", "type": "skill", "cost": "x", "rarity": "rare", "tags": ["draw"], "keywords": ["exhaust"], "target": "none", "effects": [{"op": "draw", "amount": "x"}]})
	var hero := HeroSnapshot.starter(content, "sexton")
	var s := CombatEngine.start_fight(content, hero, ["bone_rat"], 1, Rng.new(1))
	s.hand.clear()
	s.hand.append(s.new_card("fx_surge"))
	TestFixtures.fill_draw(s, ["strike", "strike", "strike", "strike"])
	assert_array(CombatEngine.legal_actions(s)).has_size(2)
	_play(s, "fx_surge")
	assert_int(s.energy).is_equal(0)
	assert_array(s.hand).has_size(3)
	assert_array(s.exhaust_pile).has_size(1)


func test_poison_kill_at_enemy_turn_start_wins() -> void:
	var s := _start(["bone_rat"])
	s.enemies[0].hp = 2
	s.enemies[0].statuses["poison"] = 3
	_end(s)
	assert_str(s.phase).is_equal("won")
	assert_int(s.hero_hp).is_equal(70)


func test_dead_target_falls_back_to_living_enemy() -> void:
	var s := _start(["bone_rat", "bone_rat"])
	TestFixtures.give_hand(s, ["strike"])
	s.enemies[0].alive = false
	_play(s, "strike", 0)
	assert_int(s.enemies[1].hp).is_equal(s.enemies[1].max_hp - 6)


func test_fight_start_is_the_first_event() -> void:
	var s := _start(["bone_rat", "shambler"])
	assert_str(s.events[0]["type"]).is_equal("fight_start")


func test_summoned_enemy_is_announced_before_its_intent() -> void:
	var s := _start(["mother_of_bones"])
	_end(s)
	var order: Array = []
	for ev in s.events:
		if int(ev.get("index", -1)) == 1 and ev["type"] in ["enemy_spawned", "enemy_intent", "summon"]:
			order.append(ev["type"])
	assert_array(order).is_equal(["enemy_spawned", "enemy_intent", "summon"])
	assert_str(s.events[1]["type"]).is_equal("enemy_spawned")


func test_turn_start_relic_energy_survives_the_refill() -> void:
	var content := Content.load_from("res://data")
	content.relics["fx_tempo"] = RelicDef.from_dict({"id": "fx_tempo", "name": "x", "text": "x", "hooks": {"on_turn_start": [{"op": "energy", "amount": 1}]}})
	var hero := HeroSnapshot.starter(content, "sexton")
	hero.relics = ["fx_tempo"] as Array[String]
	var s := CombatEngine.start_fight(content, hero, ["bone_rat"], 1, Rng.new(1))
	assert_int(s.energy).is_equal(4)
	_end(s)
	assert_int(s.energy).is_equal(4)
