extends GdUnitTestSuite
## The 3D animator is the 2D one with different hands. The pacing -- one beat
## per blow, hit-stop on a heavy hit, numbers staggered so a multi-hit does
## not stack on one pixel -- is what made fights feel like fights, and it is
## presentation-neutral, so it is carried over intact and asserted the same
## way. What is new is that a blow now also moves the body that took it, and
## that anchors are re-asked every beat because a recoiling body has moved.

const HERO_AT := Vector2(100.0, 300.0)
const ENEMY_AT := Vector2(320.0, 140.0)


class FakeBody:
	extends Node3D
	var hits: Array = []
	var died: int = 0

	func recoil(amount: int) -> void:
		hits.append(amount)

	func die() -> void:
		died += 1


var _bodies: Dictionary = {}


func before_test() -> void:
	_bodies = {}


func _animator() -> FightAnimator3D:
	var a: FightAnimator3D = auto_free(FightAnimator3D.new())
	a.bind(TestFixtures.content(), null)
	add_child(a)
	a.size = Vector2(640.0, 360.0)
	a.anchors_supplier = func() -> Dictionary: return {"hero": HERO_AT, 0: ENEMY_AT}
	a.body_supplier = func(i: int) -> Node3D: return _bodies.get(i, null)
	return a


func _body(index: int) -> FakeBody:
	var b: FakeBody = auto_free(FakeBody.new())
	add_child(b)
	_bodies[index] = b
	return b


func _settle(beats: int = 3) -> void:
	await get_tree().create_timer(FightAnimator3D.BEAT * float(beats) + 0.05).timeout


func test_damage_to_an_enemy_spawns_the_number_in_red() -> void:
	var a := _animator()
	a.play([{"type": "damage", "target": "enemy", "index": 0, "amount": 7}])
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(1)
	assert_str(a.last_spawned[0].text).is_equal("7")
	assert_that(a.last_spawned[0].get_theme_color("font_color")).is_equal(Palette.DANGER)


func test_a_blow_moves_the_body_that_took_it() -> void:
	var a := _animator()
	var body := _body(0)
	a.play([{"type": "damage", "target": "enemy", "index": 0, "amount": 9}])
	await await_idle_frame()
	assert_array(body.hits).is_equal([9])


func test_a_death_puts_the_body_down() -> void:
	var a := _animator()
	var body := _body(0)
	a.play([{"type": "enemy_died", "index": 0}])
	await await_idle_frame()
	assert_int(body.died).is_equal(1)


func test_block_healing_and_status_each_get_their_own_colour() -> void:
	var a := _animator()
	a.play([
		{"type": "block_gained", "target": "hero", "amount": 5},
		{"type": "heal", "target": "hero", "amount": 3},
		{"type": "status_applied", "target": "hero", "status": "weak", "stacks": 2},
	])
	await _settle()
	assert_int(a.last_spawned.size()).is_equal(3)
	assert_that(a.last_spawned[0].get_theme_color("font_color")).is_equal(Palette.SOUL)
	assert_that(a.last_spawned[1].get_theme_color("font_color")).is_equal(Palette.GOOD)
	assert_that(a.last_spawned[2].get_theme_color("font_color")).is_equal(Palette.PREPARED)


func test_a_fully_absorbed_hit_still_says_so() -> void:
	var a := _animator()
	a.play([{"type": "damage", "target": "hero", "amount": 0}])
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(1)
	assert_str(a.last_spawned[0].text).is_equal(TestFixtures.content().text("ui.fight.blocked"))


func test_zero_gains_are_not_worth_a_number() -> void:
	var a := _animator()
	a.play([
		{"type": "block_gained", "target": "hero", "amount": 0},
		{"type": "heal", "target": "hero", "amount": 0},
		{"type": "status_applied", "target": "hero", "status": "weak", "stacks": 0},
	])
	await _settle()
	assert_array(a.last_spawned).is_empty()


func test_only_damage_to_the_hero_asks_for_a_shake() -> void:
	assert_float(FightAnimator3D.shake_for([{"type": "damage", "target": "enemy", "index": 0, "amount": 30}])).is_equal(0.0)
	assert_float(FightAnimator3D.shake_for([{"type": "damage", "target": "hero", "amount": 4}])).is_greater(0.0)


func test_a_bigger_hit_shakes_harder_but_the_shake_is_capped() -> void:
	var small := FightAnimator3D.shake_for([{"type": "damage", "target": "hero", "amount": 3}])
	var big := FightAnimator3D.shake_for([{"type": "damage", "target": "hero", "amount": 9}])
	assert_float(big).is_greater(small)
	assert_float(FightAnimator3D.shake_for([{"type": "damage", "target": "hero", "amount": 999}])).is_equal(FightAnimator3D.SHAKE_MAX)


func test_the_shake_signal_fires_for_a_hero_hit() -> void:
	var a := _animator()
	var asked: Array = []
	a.shake_requested.connect(func(s: float) -> void: asked.append(s))
	a.play([{"type": "damage", "target": "hero", "amount": 6}])
	await await_idle_frame()
	assert_array(asked).has_size(1)
	assert_float(float(asked[0])).is_equal_approx(6.0 * FightAnimator3D.SHAKE_PER_DAMAGE, 0.001)


func test_several_hits_on_one_target_are_staggered_not_stacked() -> void:
	var a := _animator()
	a.play([
		{"type": "damage", "target": "enemy", "index": 0, "amount": 2},
		{"type": "damage", "target": "enemy", "index": 0, "amount": 3},
	])
	await _settle()
	assert_int(a.last_spawned.size()).is_equal(2)
	assert_float(a.last_spawned[0].position.y).is_not_equal(a.last_spawned[1].position.y)


func test_an_event_with_no_anchor_spawns_nothing_rather_than_crashing() -> void:
	var a := _animator()
	a.anchors_supplier = func() -> Dictionary: return {}
	a.play([{"type": "damage", "target": "enemy", "index": 4, "amount": 5}])
	await _settle()
	assert_array(a.last_spawned).is_empty()


func test_anchors_are_asked_for_again_every_beat() -> void:
	# A body that recoiled has moved, so an anchor read once up front puts the
	# second number of a turn where the first one was.
	var a := _animator()
	var asked := [0]
	a.anchors_supplier = func() -> Dictionary:
		asked[0] += 1
		return {"hero": HERO_AT, 0: ENEMY_AT}
	a.play([
		{"type": "damage", "target": "enemy", "index": 0, "amount": 2},
		{"type": "damage", "target": "hero", "amount": 3},
	])
	await _settle()
	assert_int(int(asked[0])).is_greater_equal(2)


func test_a_turn_of_hits_lands_as_a_sequence_not_a_burst() -> void:
	# The combat engine resolves an entire enemy phase inside one apply() and
	# hands back a flat array. Three enemies attacking must not land in the
	# same rendered frame.
	var a := _animator()
	a.play([
		{"type": "damage", "target": "hero", "amount": 3},
		{"type": "damage", "target": "hero", "amount": 4},
		{"type": "damage", "target": "hero", "amount": 5},
	])
	await await_idle_frame()
	assert_int(a.last_spawned.size()).is_equal(1)
	await _settle(4)
	assert_int(a.last_spawned.size()).is_equal(3)


func test_each_hit_is_reported_as_it_lands() -> void:
	var a := _animator()
	var landed: Array = []
	a.hit_landed.connect(func(e: Dictionary) -> void: landed.append(int(e.get("amount", -1))))
	a.play([
		{"type": "damage", "target": "hero", "amount": 3},
		{"type": "damage", "target": "hero", "amount": 4},
	])
	await await_idle_frame()
	assert_array(landed).is_equal([3])
	await _settle(3)
	assert_array(landed).is_equal([3, 4])


func test_it_says_when_it_is_done() -> void:
	var a := _animator()
	var done := [0]
	a.finished.connect(func() -> void: done[0] += 1)
	a.play([{"type": "damage", "target": "hero", "amount": 2}])
	await _settle(3)
	assert_int(int(done[0])).is_equal(1)
	assert_bool(a.is_playing()).is_false()


func test_an_empty_turn_is_finished_immediately() -> void:
	var a := _animator()
	var done := [0]
	a.finished.connect(func() -> void: done[0] += 1)
	a.play([])
	await await_idle_frame()
	assert_int(int(done[0])).is_equal(1)
