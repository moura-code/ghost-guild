extends GdUnitTestSuite


func _panel() -> HeroPanel:
	var p: HeroPanel = auto_free(HeroPanel.new())
	add_child(p)
	p.size = HeroPanel.PANEL_SIZE
	return p


func _fight(hp: int = 70, block: int = 0, energy: int = 3) -> FightState:
	var s := TestFixtures.bare_state(["bone_rat"], 1, 1)
	s.hero_hp = hp
	s.hero_max_hp = 70
	s.hero_block = block
	s.energy = energy
	s.max_energy = 3
	s.turn = 2
	return s


func test_it_reads_back_hp_block_and_energy() -> void:
	var p := _panel()
	p.bind(TestFixtures.content(), _fight(42, 6, 2))
	await await_idle_frame()
	assert_int(p.hp).is_equal(42)
	assert_int(p.block).is_equal(6)
	assert_int(p.energy).is_equal(2)
	assert_str(p._hp_text.text).is_equal("42/70")


func test_the_shield_only_appears_when_there_is_block() -> void:
	var p := _panel()
	p.bind(TestFixtures.content(), _fight(70, 0))
	await await_idle_frame()
	assert_bool(p._shield.visible).is_false()
	p.bind(TestFixtures.content(), _fight(70, 9))
	await await_idle_frame()
	assert_bool(p._shield.visible).is_true()
	assert_str(p._shield_text.text).is_equal("9")


func test_the_colour_warns_as_health_falls() -> void:
	var p := _panel()
	p.bind(TestFixtures.content(), _fight(70))
	assert_that(p._hp_colour()).is_equal(Palette.BONE)
	p.bind(TestFixtures.content(), _fight(30))
	assert_that(p._hp_colour()).is_equal(Palette.PREPARED)
	p.bind(TestFixtures.content(), _fight(10))
	assert_that(p._hp_colour()).is_equal(Palette.DANGER)


func test_losing_health_flashes_the_bar_and_the_flash_fades() -> void:
	var p := _panel()
	p.bind(TestFixtures.content(), _fight(70))
	await await_idle_frame()
	assert_float(p._flash).is_equal(0.0)
	p.bind(TestFixtures.content(), _fight(50))
	assert_float(p._flash).is_greater(0.0)
	await get_tree().create_timer(0.7).timeout
	assert_float(p._flash).is_equal_approx(0.0, 0.02)


func test_gaining_health_does_not_flash() -> void:
	var p := _panel()
	p.bind(TestFixtures.content(), _fight(30))
	await await_idle_frame()
	p.bind(TestFixtures.content(), _fight(60))
	assert_float(p._flash).is_equal(0.0)


func test_status_icons_appear_and_are_pooled() -> void:
	var p := _panel()
	var s := _fight()
	s.statuses = {"poison": 3, "weak": 1}
	p.bind(TestFixtures.content(), s)
	await await_idle_frame()
	var shown := 0
	for child in p._status_row.get_children():
		if (child as TextureRect).visible:
			shown += 1
	assert_int(shown).is_equal(2)

	var s2 := _fight()
	s2.statuses = {"poison": 1}
	p.bind(TestFixtures.content(), s2)
	await await_idle_frame()
	var shown2 := 0
	for child in p._status_row.get_children():
		if (child as TextureRect).visible:
			shown2 += 1
	assert_int(shown2).is_equal(1)


func test_a_zero_stack_status_is_not_shown() -> void:
	var p := _panel()
	var s := _fight()
	s.statuses = {"poison": 0}
	p.bind(TestFixtures.content(), s)
	await await_idle_frame()
	for child in p._status_row.get_children():
		assert_bool((child as TextureRect).visible).is_false()


func test_it_draws_at_zero_size_without_crashing() -> void:
	var p: HeroPanel = auto_free(HeroPanel.new())
	add_child(p)
	p.size = Vector2.ZERO
	p.bind(TestFixtures.content(), _fight())
	p._bar.queue_redraw()
	p._orbs.queue_redraw()
	await await_idle_frame()
	assert_int(p.hp).is_equal(70)
