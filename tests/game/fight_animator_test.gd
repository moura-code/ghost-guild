extends GdUnitTestSuite

const HERO_AT := Vector2(100.0, 400.0)
const ENEMY_AT := Vector2(300.0, 80.0)


func _animator() -> FightAnimator:
	var a: FightAnimator = auto_free(FightAnimator.new())
	a.bind(TestFixtures.content())
	add_child(a)
	a.size = Vector2(960.0, 600.0)
	return a


func _anchors() -> Dictionary:
	return {"hero": HERO_AT, 0: ENEMY_AT}


func test_damage_to_an_enemy_spawns_the_number_in_red() -> void:
	var a := _animator()
	a.play([{"type": "damage", "target": "enemy", "index": 0, "amount": 7}], _anchors())
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(1)
	assert_str(a.last_spawned[0].text).is_equal("7")
	assert_that(a.last_spawned[0].get_theme_color("font_color")).is_equal(Palette.DANGER)


func test_block_healing_and_status_each_get_their_own_colour() -> void:
	var a := _animator()
	a.play([
		{"type": "block_gained", "target": "hero", "amount": 5},
		{"type": "heal", "target": "hero", "amount": 3},
		{"type": "status_applied", "target": "enemy", "index": 0, "status": "weak", "stacks": 2},
	], _anchors())
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(3)
	assert_str(a.last_spawned[0].text).is_equal("+5")
	assert_that(a.last_spawned[0].get_theme_color("font_color")).is_equal(Palette.SOUL)
	assert_str(a.last_spawned[1].text).is_equal("+3")
	assert_that(a.last_spawned[1].get_theme_color("font_color")).is_equal(Palette.GOOD)
	assert_str(a.last_spawned[2].text).is_equal(TestFixtures.content().text("status.weak.name"))
	assert_str(a.last_spawned[2].text).is_not_equal("status.weak.name")


func test_zero_amounts_are_not_worth_a_number() -> void:
	var a := _animator()
	a.play([
		{"type": "damage", "target": "hero", "amount": 0},
		{"type": "block_gained", "target": "hero", "amount": 0},
		{"type": "heal", "target": "hero", "amount": 0},
	], _anchors())
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(0)


func test_a_death_is_called_out() -> void:
	var a := _animator()
	a.play([{"type": "enemy_died", "index": 0, "enemy": "bone_rat"}], _anchors())
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(1)
	assert_str(a.last_spawned[0].text).is_equal(TestFixtures.content().text("ui.fight.slain"))


func test_only_damage_to_the_hero_asks_for_a_shake() -> void:
	assert_float(FightAnimator.shake_for([{"type": "damage", "target": "enemy", "index": 0, "amount": 20}])).is_equal(0.0)
	assert_float(FightAnimator.shake_for([{"type": "damage", "target": "hero", "amount": 10}])).is_greater(0.0)
	assert_float(FightAnimator.shake_for([{"type": "block_gained", "target": "hero", "amount": 10}])).is_equal(0.0)


func test_a_bigger_hit_shakes_harder_but_the_shake_is_capped() -> void:
	var small := FightAnimator.shake_for([{"type": "damage", "target": "hero", "amount": 4}])
	var large := FightAnimator.shake_for([{"type": "damage", "target": "hero", "amount": 12}])
	assert_float(large).is_greater(small)
	var absurd := FightAnimator.shake_for([{"type": "damage", "target": "hero", "amount": 9999}])
	assert_float(absurd).is_equal(FightAnimator.SHAKE_MAX)


func test_the_shake_signal_fires_for_a_hero_hit() -> void:
	var a := _animator()
	var shakes: Array[float] = []
	a.shake_requested.connect(func(strength: float) -> void: shakes.append(strength))
	a.play([{"type": "damage", "target": "hero", "amount": 8}], _anchors())
	await await_idle_frame()
	assert_int(shakes.size()).is_equal(1)
	assert_float(shakes[0]).is_greater(0.0)


func test_several_hits_in_one_action_are_staggered_not_stacked() -> void:
	var a := _animator()
	a.play([
		{"type": "damage", "target": "enemy", "index": 0, "amount": 3},
		{"type": "damage", "target": "enemy", "index": 0, "amount": 3},
	], _anchors())
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(2)
	assert_float(a.last_spawned[0].position.y).is_not_equal(a.last_spawned[1].position.y)


func test_an_event_with_no_anchor_spawns_nothing_rather_than_crashing() -> void:
	var a := _animator()
	a.play([{"type": "damage", "target": "enemy", "index": 4, "amount": 6}], {})
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(0)


func test_numbers_free_themselves_once_they_have_risen() -> void:
	var a := _animator()
	a.play([{"type": "damage", "target": "enemy", "index": 0, "amount": 5}], _anchors())
	await await_idle_frame()
	var number: FloatNumber = a.last_spawned[0]
	assert_bool(is_instance_valid(number)).is_true()
	# The tween outlives a frame; drive it past its lifetime.
	await get_tree().create_timer(FloatNumber.LIFETIME + 0.25).timeout
	assert_bool(is_instance_valid(number)).is_false()
	assert_int(a.get_child_count()).is_equal(0)
