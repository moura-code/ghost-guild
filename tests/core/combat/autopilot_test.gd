extends GdUnitTestSuite


func _start(enemy_ids: Array = ["bone_rat"], floor: int = 1, seed: int = 1) -> FightState:
	var hero := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	return CombatEngine.start_fight(TestFixtures.content(), hero, enemy_ids, floor, Rng.new(seed))


func _run_turn(ap: Autopilot, s: FightState) -> void:
	for action in ap.choose_turn(s):
		if s.is_over():
			return
		CombatEngine.apply(s, action)


func test_takes_lethal() -> void:
	var s := _start(["bone_rat"])
	s.enemies[0].hp = 6
	TestFixtures.give_hand(s, ["brace", "brace", "strike"])
	var ap := Autopilot.new()
	var seq := ap.choose_turn(s)
	assert_str(seq[seq.size() - 1]["kind"]).is_equal("end_turn")
	_run_turn(ap, s)
	assert_str(s.phase).is_equal("won")


func test_prefers_full_block_over_chip_damage() -> void:
	var s := _start(["shambler"])
	s.hero_block = 0
	s.enemies[0].next_move = "lurch"
	TestFixtures.give_hand(s, ["brace", "brace", "strike"])
	s.energy = 2
	var ap := Autopilot.new()
	_run_turn(ap, s)
	assert_int(s.hero_hp).is_equal(70)


func test_plays_draw_card_to_find_more_damage() -> void:
	var s := _start(["shambler"])
	s.enemies[0].next_move = "brace"
	TestFixtures.give_hand(s, ["exhume", "strike"])
	TestFixtures.fill_draw(s, ["strike", "strike"])
	var ap := Autopilot.new()
	_run_turn(ap, s)
	assert_int(s.enemies[0].hp).is_equal(30 - 12)


func test_is_deterministic() -> void:
	var a := _start(["bone_rat", "shambler"], 3, 9)
	var b := _start(["bone_rat", "shambler"], 3, 9)
	var ap := Autopilot.new()
	var seq_a := ap.choose_turn(a)
	var seq_b := ap.choose_turn(b)
	assert_array(seq_a).is_equal(seq_b)


func test_choose_turn_does_not_mutate_state() -> void:
	var s := _start(["bone_rat"])
	var hand_before := s.hand.size()
	var energy_before := s.energy
	var events_before := s.events.size()
	Autopilot.new().choose_turn(s)
	assert_int(s.hand.size()).is_equal(hand_before)
	assert_int(s.energy).is_equal(energy_before)
	assert_int(s.events.size()).is_equal(events_before)


func test_search_is_bounded() -> void:
	var s := _start(["bone_rat", "bone_rat", "bone_rat"])
	var ids: Array = []
	for i in 10:
		ids.append("bone_shard")
	TestFixtures.give_hand(s, ids)
	var ap := Autopilot.new()
	ap.choose_turn(s)
	assert_int(ap.last_explored).is_less_equal(Autopilot.MAX_SEQUENCES)
	assert_int(ap.last_explored).is_greater(1)


func test_incoming_damage_reads_intents() -> void:
	var s := _start(["bone_rat", "shambler"])
	s.enemies[0].next_move = "gnaw"
	s.enemies[1].next_move = "brace"
	assert_int(Autopilot.incoming_damage(s)).is_equal(6)


func test_play_fight_wins_easy_fight_quickly() -> void:
	var s := _start(["bone_rat"], 1, 4)
	var result := Autopilot.new().play_fight(s)
	assert_bool(result["won"]).is_true()
	assert_int(result["turns"]).is_less_equal(6)
	assert_int(result["hp"]).is_greater(50)


func test_play_fight_always_terminates() -> void:
	for seed in [1, 2, 3]:
		var s := _start(["ossuary_warden"], 1, seed)
		var result := Autopilot.new().play_fight(s)
		assert_bool(s.is_over()).is_true()
		assert_int(result["turns"]).is_less_equal(30)


func test_does_not_suicide_on_mutual_kill() -> void:
	var s := _start(["bone_rat"])
	s.hero_hp = 3
	s.enemies[0].hp = 6
	s.enemies[0].statuses["thorns"] = 3
	TestFixtures.give_hand(s, ["strike", "brace"])
	var ap := Autopilot.new()
	_run_turn(ap, s)
	assert_str(s.phase).is_not_equal("lost")
	assert_int(s.hero_hp).is_greater(0)
