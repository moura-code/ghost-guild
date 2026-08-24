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


func _fight(g: GameRoot) -> RunState:
	var run := g.start_run(1)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
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
	# Rebinding the slot must clear the fade and the spin, or the hand would
	# fill up with ghosts of played cards.
	s.refresh()
	await await_idle_frame()
	assert_float(card.modulate.a).is_equal(1.0)
	assert_float(card.rotation).is_equal(0.0)


func test_reacting_outside_the_tree_is_a_no_op_not_a_crash() -> void:
	var view: EnemyView = auto_free(EnemyView.new())
	view.react_hit(10)
	view.react_death()
	assert_that(view.scale).is_equal(Vector2.ONE)
