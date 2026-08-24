extends GdUnitTestSuite
## The fight's reactions. Tested for state, not pixels: that a hit puts the
## view into its reacting state and that the state resolves, not that a
## tween interpolated correctly — that is Godot's job, not this project's.

const TMP := "user://test_saves/fight_feel_test.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 2
	return g


func _fight(g: GameRoot, enemies: Array = ["bone_rat"]) -> RunState:
	var run := g.start_run(1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": enemies}])
	RunEngine.apply(run, {"kind": "enter"})
	return run


func _screen(g: GameRoot, run: RunState) -> FightScreen:
	var s: FightScreen = auto_free(FightScreen.new())
	add_child(s)
	s.size = Vector2(960.0, 600.0)
	s.bind(g, run)
	return s


func test_a_hit_squashes_the_enemy_and_flashes_it() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	view.react_hit(8)
	# The squash is applied immediately; the tween springs it back.
	assert_that(view.scale).is_not_equal(Vector2.ONE)
	assert_float(view.scale.x).is_greater(1.0)
	assert_float(view.scale.y).is_less(1.0)


func test_the_squash_springs_back_to_rest() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	view.react_hit(8)
	await get_tree().create_timer(0.6).timeout
	assert_float(view.scale.x).is_equal_approx(1.0, 0.02)
	assert_float(view.scale.y).is_equal_approx(1.0, 0.02)


func test_a_bigger_hit_squashes_harder() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	view.react_hit(2)
	var small := view.scale.x
	view.react_hit(20)
	assert_float(view.scale.x).is_greater(small)


func test_death_fades_the_enemy_rather_than_blinking_it_out() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	view.react_death()
	await get_tree().create_timer(0.6).timeout
	assert_float(view.modulate.a).is_less(1.0)
	assert_float(view.scale.y).is_less(1.0)


func test_playing_a_card_makes_the_enemy_react() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var attack := -1
	for i in run.fight.hand.size():
		var def: CardDef = g.content.cards[run.fight.hand[i].def_id]
		if def.target == "enemy":
			attack = i
			break
	assert_int(attack).is_greater_equal(0)
	var view := s._enemy_views[0]
	s._card_views[attack].press()
	s._enemy_views[0].press()
	assert_that(view.scale).is_not_equal(Vector2.ONE)


func test_a_playable_card_lifts_under_the_cursor_and_settles_back() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var card := s._card_views[0]
	card.playable = true
	var rest := card._rest_y
	assert_float(rest).is_greater(0.0)
	card._on_hover(true)
	await get_tree().create_timer(0.15).timeout
	assert_float(card.position.y).is_equal_approx(rest - CardView.HOVER_LIFT, 0.5)
	card._on_hover(false)
	await get_tree().create_timer(0.15).timeout
	assert_float(card.position.y).is_equal_approx(rest, 0.5)


func test_an_unaffordable_card_does_not_lift() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	run.fight.energy = 0
	s.refresh()
	await await_idle_frame()
	var card := s._card_views[0]
	assert_bool(card.playable).is_false()
	var rest := card._rest_y
	card._on_hover(true)
	await get_tree().create_timer(0.15).timeout
	assert_float(card.position.y).is_equal_approx(rest, 0.5)


func test_a_flown_card_is_restored_when_its_slot_is_reused() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var card := s._card_views[0]
	card.fly_out(Vector2(900.0, 560.0))
	await get_tree().create_timer(0.35).timeout
	assert_float(card.modulate.a).is_less(1.0)
	var spun := card.rotation
	# Rebinding the slot must clear the fade and the fly-out spin, or the
	# hand fills up with ghosts of played cards. Rotation returns to the
	# card's place in the fan, which is a small angle, not zero.
	s.refresh()
	await await_idle_frame()
	assert_float(card.modulate.a).is_equal(1.0)
	assert_float(card.rotation).is_not_equal(spun)
	assert_float(absf(card.rotation)).is_less(0.4)


func test_reacting_outside_the_tree_is_a_no_op_not_a_crash() -> void:
	var view: EnemyView = auto_free(EnemyView.new())
	view.react_hit(10)
	view.react_death()
	assert_that(view.scale).is_equal(Vector2.ONE)


func test_the_hand_is_fanned_not_stacked_in_a_row() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_int(run.fight.hand.size()).is_greater(2)
	var first := s._card_views[0]
	var last := s._card_views[run.fight.hand.size() - 1]
	# Cards march rightward...
	assert_float(last.position.x).is_greater(first.position.x)
	# ...tilt in opposite directions around the middle...
	assert_float(first.rotation).is_less(0.0)
	assert_float(last.rotation).is_greater(0.0)
	# ...and the edges of the fan sit lower than its centre.
	var middle := s._card_views[run.fight.hand.size() / 2]
	assert_float(first.position.y).is_greater(middle.position.y)


func test_a_hovered_card_lifts_out_of_the_fan_and_draws_over_its_neighbours() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var card := s._card_views[1]
	card.playable = true
	card._on_hover(true)
	assert_int(card.z_index).is_greater(0)
	await get_tree().create_timer(0.2).timeout
	assert_float(card.scale.x).is_greater(1.0)
	card._on_hover(false)
	await get_tree().create_timer(0.2).timeout
	assert_int(card.z_index).is_equal(0)
	assert_float(card.scale.x).is_equal_approx(1.0, 0.02)


func test_every_card_has_an_art_slot_filled_with_a_stand_in() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	for i in run.fight.hand.size():
		var card := s._card_views[i]
		assert_object(card._art).is_not_null()
		assert_that(card._art.custom_minimum_size).is_equal(CardView.ART_SIZE)
		assert_object(card._art_image.texture) 			.override_failure_message("card %d has an empty art slot" % i).is_not_null()


func test_the_layout_puts_the_hero_low_and_the_enemies_high() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_float(s._enemy_row.global_position.y).is_less(s._hero.global_position.y)
	assert_float(s._hero.global_position.x).is_less(s._end_turn.global_position.x)


func test_resizing_re_fans_the_hand() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var before := s._card_views[0].position
	s.size = Vector2(1400.0, 800.0)
	await await_idle_frame()
	assert_that(s._card_views[0].position).is_not_equal(before)


func test_enemies_breathe_while_they_live() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	assert_bool(view.idling).is_true()
	var first := view.scale.x
	await get_tree().create_timer(0.5).timeout
	assert_float(view.scale.x).is_not_equal(first)
	# But only just: a breathe that reads as a pulse is a distraction.
	assert_float(absf(view.scale.x - 1.0)).is_less(0.05)


func test_the_dead_do_not_breathe() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	view.react_death()
	assert_bool(view.idling).is_false()
	await get_tree().create_timer(0.7).timeout
	# The death pose survives: without the guard the idle swell reclaims the
	# scale as soon as the tween ends and the corpse sits back up.
	assert_float(view.scale.y).is_less(1.0)


func test_a_row_of_enemies_does_not_breathe_in_lockstep() -> void:
	var g := _game()
	var run := _fight(g, ["bone_rat", "bone_rat", "bone_rat"])
	var s := _screen(g, run)
	await await_idle_frame()
	await get_tree().create_timer(0.3).timeout
	assert_float(s._enemy_views[0].scale.x).is_not_equal(s._enemy_views[1].scale.x)


func test_a_new_turn_is_announced_and_the_hand_is_dealt() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_int(s._last_turn).is_equal(run.fight.turn)
	# Ending the turn announces the enemy, then the new turn announces back.
	s._end_turn.emit_signal("pressed")
	await await_idle_frame()
	assert_str(s._banner.text).is_not_equal("")
	assert_bool(s._banner.is_announcing()).is_true()


func test_the_first_paint_does_not_announce() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	# Opening a fight should not fire a banner for turn 1 arriving.
	assert_bool(s._banner.is_announcing()).is_false()
	assert_float(s._banner.modulate.a).is_equal(0.0)


func test_a_dealt_card_arrives_at_its_place_in_the_fan() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var card := s._card_views[0]
	var home := card._rest_position
	card.fly_in(Vector2(30.0, 560.0), 0.0)
	assert_that(card.position).is_not_equal(home)
	await get_tree().create_timer(0.5).timeout
	assert_float(card.position.x).is_equal_approx(home.x, 1.0)
	assert_float(card.modulate.a).is_equal_approx(1.0, 0.02)
