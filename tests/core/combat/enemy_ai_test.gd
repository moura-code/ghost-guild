extends GdUnitTestSuite


func test_sequence_pattern_cycles() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	var moves: Array = []
	for i in 4:
		EnemyAI.choose_next_move(s, 0)
		moves.append(s.enemies[0].next_move)
		s.enemies[0].next_move = ""
	assert_array(moves).is_equal(["lurch", "lurch", "brace", "lurch"])
	assert_array(TestFixtures.events_of(s, "enemy_intent")).has_size(4)


func test_weighted_no_repeat_never_repeats() -> void:
	var s := TestFixtures.bare_state(["crypt_spider"])
	var last := ""
	for i in 30:
		EnemyAI.choose_next_move(s, 0)
		var move := s.enemies[0].next_move
		assert_str(move).is_not_equal(last)
		s.enemies[0].last_move = move
		last = move


func test_weighted_is_deterministic_per_seed() -> void:
	var a := TestFixtures.bare_state(["bone_rat"], 1, 11)
	var b := TestFixtures.bare_state(["bone_rat"], 1, 11)
	for i in 10:
		EnemyAI.choose_next_move(a, 0)
		EnemyAI.choose_next_move(b, 0)
		assert_str(a.enemies[0].next_move).is_equal(b.enemies[0].next_move)


func test_intent_shows_scaled_damage_with_buff() -> void:
	var s := TestFixtures.bare_state(["skull_stack"], 10)
	EnemyAI.choose_next_move(s, 0)
	assert_str(s.enemies[0].next_move).is_equal("reassemble")
	EnemyAI.execute_move(s, 0)
	assert_int(s.enemies[0].status("might_buff")).is_equal(1)
	EnemyAI.choose_next_move(s, 0)
	var intent := EnemyAI.intent_of(s, 0)
	assert_str(intent["kind"]).is_equal("attack")
	assert_int(intent["damage"]).is_equal(14)
	assert_int(intent["hits"]).is_equal(1)


func test_attack_moves_hit_hero() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(64)
	assert_str(s.enemies[0].last_move).is_equal("bite")
	assert_str(s.enemies[0].next_move).is_equal("")
	s.enemies[0].next_move = "gnaw"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(58)
	assert_array(TestFixtures.events_of(s, "enemy_move")).has_size(2)


func test_attack_with_status_poisons_hero() -> void:
	var s := TestFixtures.bare_state(["crypt_spider"])
	s.enemies[0].next_move = "sting"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(66)
	assert_int(s.hero_status("poison")).is_equal(3)


func test_block_buff_debuff_moves() -> void:
	var s := TestFixtures.bare_state(["hollow_knight", "grave_wisp", "bone_archer"])
	s.enemies[0].next_move = "guard"
	EnemyAI.execute_move(s, 0)
	assert_int(s.enemies[0].block).is_equal(10)
	s.enemies[1].next_move = "wail"
	EnemyAI.execute_move(s, 1)
	assert_int(s.hero_status("weak")).is_equal(1)
	s.enemies[2].next_move = "aim"
	EnemyAI.execute_move(s, 2)
	assert_int(s.enemies[2].status("might_buff")).is_equal(2)


func test_summon_adds_enemy_with_intent_up_to_cap() -> void:
	var s := TestFixtures.bare_state(["mother_of_bones"], 3)
	s.enemies[0].next_move = "raise"
	EnemyAI.execute_move(s, 0)
	assert_array(s.enemies).has_size(2)
	assert_str(s.enemies[1].def_id).is_equal("bone_rat")
	assert_int(s.enemies[1].hp).is_equal(Scaling.enemy_hp(18, 3, TestFixtures.content().balance))
	assert_str(s.enemies[1].next_move).is_not_equal("")
	assert_array(TestFixtures.events_of(s, "summon")).has_size(1)
	for i in 4:
		s.enemies[0].next_move = "raise"
		EnemyAI.execute_move(s, 0)
	assert_array(s.enemies).has_size(5)
	assert_array(TestFixtures.events_of(s, "summon_failed")).has_size(1)


func test_dead_enemy_does_not_act() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].alive = false
	s.enemies[0].next_move = "bite"
	EnemyAI.execute_move(s, 0)
	assert_int(s.hero_hp).is_equal(70)


func test_bleeding_enemy_hurts_itself_when_attacking() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].statuses["bleed"] = 2
	s.enemies[0].next_move = "gnaw"
	EnemyAI.execute_move(s, 0)
	assert_int(s.enemies[0].hp).is_equal(16)


func test_enemy_move_intent_has_the_same_shape_as_enemy_intent() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	EnemyAI.choose_next_move(s, 0)
	var telegraphed: Dictionary = TestFixtures.events_of(s, "enemy_intent")[0]["intent"]
	EnemyAI.execute_move(s, 0)
	var executed: Dictionary = TestFixtures.events_of(s, "enemy_move")[0]["intent"]
	assert_dict(executed).is_equal(telegraphed)
