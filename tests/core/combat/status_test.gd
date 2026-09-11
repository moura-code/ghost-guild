extends GdUnitTestSuite


func test_hero_turn_start_order_and_block_reset() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "bone_rat"])
	s.hero_block = 9
	s.hero_hp = 50
	s.statuses = {"vigil": 3, "regen": 2, "poison": 4, "knell": 5}
	StatusSystem.hero_turn_start(s, true)
	assert_int(s.hero_block).is_equal(3)
	assert_int(s.hero_hp).is_equal(50 + 2 - 4)
	assert_int(s.hero_status("regen")).is_equal(1)
	assert_int(s.hero_status("poison")).is_equal(3)
	assert_int(s.hero_status("vigil")).is_equal(3)
	assert_int(s.hero_status("knell")).is_equal(5)
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 5)
	assert_int(s.enemies[1].hp).is_equal(s.enemies[1].max_hp - 5)


func test_hero_turn_start_can_keep_block() -> void:
	var s := TestFixtures.bare_state()
	s.hero_block = 3
	StatusSystem.hero_turn_start(s, false)
	assert_int(s.hero_block).is_equal(3)


func test_poison_ignores_block_and_can_kill_hero() -> void:
	var s := TestFixtures.bare_state()
	s.hero_block = 100
	s.hero_hp = 2
	s.statuses = {"poison": 2}
	StatusSystem.hero_turn_start(s, false)
	assert_int(s.hero_hp).is_equal(0)
	assert_int(s.hero_status("poison")).is_equal(1)


func test_hero_turn_end_burn_and_decays() -> void:
	var s := TestFixtures.bare_state()
	s.hero_hp = 50
	s.statuses = {"burn": 3, "weak": 1, "vulnerable": 2, "bleed": 1, "might_buff": 2, "thorns": 1}
	StatusSystem.hero_turn_end(s)
	assert_int(s.hero_hp).is_equal(47)
	assert_int(s.hero_status("burn")).is_equal(2)
	assert_int(s.hero_status("weak")).is_equal(0)
	assert_bool(s.statuses.has("weak")).is_false()
	assert_int(s.hero_status("vulnerable")).is_equal(1)
	assert_int(s.hero_status("bleed")).is_equal(0)
	assert_int(s.hero_status("might_buff")).is_equal(2)
	assert_int(s.hero_status("thorns")).is_equal(1)


func test_enemy_turn_start_resets_block_poison_regen() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	var e := s.enemies[0]
	e.block = 6
	e.hp = 10
	e.statuses = {"poison": 3, "regen": 2}
	StatusSystem.enemy_turn_start(s, 0)
	assert_int(e.block).is_equal(0)
	assert_int(e.hp).is_equal(10 - 3 + 2)
	assert_int(e.status("poison")).is_equal(2)
	assert_int(e.status("regen")).is_equal(1)


func test_enemy_poison_can_kill() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].hp = 3
	s.enemies[0].statuses = {"poison": 3}
	StatusSystem.enemy_turn_start(s, 0)
	assert_bool(s.enemies[0].alive).is_false()
	assert_array(TestFixtures.events_of(s, "enemy_died")).has_size(1)


func test_enemy_turn_end_burn_and_decays() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	var e := s.enemies[0]
	e.statuses = {"burn": 2, "weak": 2, "vulnerable": 1, "bleed": 3, "might_buff": 1}
	StatusSystem.enemy_turn_end(s, 0)
	assert_int(e.hp).is_equal(e.max_hp - 2)
	assert_int(e.status("burn")).is_equal(1)
	assert_int(e.status("weak")).is_equal(1)
	assert_int(e.status("vulnerable")).is_equal(0)
	assert_int(e.status("bleed")).is_equal(2)
	assert_int(e.status("might_buff")).is_equal(1)


func test_status_tick_events() -> void:
	var s := TestFixtures.bare_state()
	s.statuses = {"poison": 2, "burn": 1}
	StatusSystem.hero_turn_start(s, false)
	StatusSystem.hero_turn_end(s)
	var ticks := TestFixtures.events_of(s, "status_tick")
	assert_array(ticks).has_size(2)
	assert_str(ticks[0]["status"]).is_equal("poison")
	assert_str(ticks[1]["status"]).is_equal("burn")


func test_dead_enemy_is_skipped() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].alive = false
	s.enemies[0].statuses = {"poison": 5}
	StatusSystem.enemy_turn_start(s, 0)
	StatusSystem.enemy_turn_end(s, 0)
	assert_array(TestFixtures.events_of(s, "status_tick")).is_empty()


func test_decay_helper() -> void:
	var d := {"weak": 1, "burn": 3}
	StatusSystem.decay(d, "weak")
	StatusSystem.decay(d, "burn")
	StatusSystem.decay(d, "missing")
	assert_bool(d.has("weak")).is_false()
	assert_int(d["burn"]).is_equal(2)


func test_enemy_regen_heal_event_reports_actual_amount() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	var e := s.enemies[0]
	e.hp = e.max_hp - 2
	e.statuses = {"regen": 5}
	StatusSystem.enemy_turn_start(s, 0)
	assert_int(e.hp).is_equal(e.max_hp)
	var heals := TestFixtures.events_of(s, "heal")
	assert_array(heals).has_size(1)
	assert_int(heals[0]["amount"]).is_equal(2)
