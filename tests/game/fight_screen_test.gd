extends GdUnitTestSuite

const TMP := "user://test_saves/fight_screen_test.json"


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
	g.campaign.sim_fights = 4
	return g


## A run parked in a one-enemy fight, which is the state the screen renders.
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


func test_it_shows_one_view_per_enemy_and_one_card_per_hand_slot() -> void:
	var g := _game()
	var run := _fight(g, ["bone_rat", "bone_rat"])
	var s := _screen(g, run)
	await await_idle_frame()
	assert_int(s._enemy_views.size()).is_equal(2)
	assert_int(s._card_views.size()).is_equal(run.fight.hand.size())
	assert_int(run.fight.hand.size()).is_greater(0)


func test_an_enemy_shows_its_name_hp_and_telegraphed_intent() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	var def: EnemyDef = g.content.enemies[run.fight.enemies[0].def_id]
	assert_str(view._name.text).is_equal(g.text(def.name_key))
	assert_str(view._hp.text).contains(str(run.fight.enemies[0].hp))
	assert_str(view._intent.text).is_not_equal("")
	assert_str(view._intent.text).is_not_equal("ui.fight.intent.unknown")


func test_a_card_shows_its_cost_name_and_text() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var card := run.fight.hand[0]
	var def: CardDef = g.content.cards[card.def_id]
	assert_str(s._card_views[0]._name.text).contains(g.text(def.name_key))
	assert_str(s._card_views[0]._text.text).is_equal(g.text(def.text_key))
	assert_str(s._card_views[0]._cost.text).is_equal(str(def.cost_for(card.upgraded)))


func test_an_attack_needs_a_target_and_a_self_card_does_not() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var attack := _find_card(g, run, "enemy")
	var selfish := _find_card(g, run, "self")
	assert_int(attack).is_greater_equal(0)
	assert_int(selfish).is_greater_equal(0)
	assert_bool(bool(s._playable[attack])).is_true()
	assert_bool(bool(s._playable[selfish])).is_false()


func test_clicking_an_attack_selects_it_and_prompts_for_a_target() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var attack := _find_card(g, run, "enemy")
	var before := run.fight.enemies[0].hp
	s._card_views[attack].press()
	await await_idle_frame()
	assert_int(s.selected_index).is_equal(attack)
	assert_str(s._prompt.text).is_equal(g.text("ui.fight.pick_target"))
	assert_int(run.fight.enemies[0].hp).is_equal(before)


func test_clicking_the_enemy_then_lands_the_hit() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var attack := _find_card(g, run, "enemy")
	var before := run.fight.enemies[0].hp
	var energy_before := run.fight.energy
	s._card_views[attack].press()
	s._enemy_views[0].press()
	await await_idle_frame()
	assert_int(run.fight.enemies[0].hp).is_less(before)
	assert_int(run.fight.energy).is_less(energy_before)
	assert_int(s.selected_index).is_equal(-1)


func test_clicking_a_self_card_resolves_without_a_target() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var selfish := _find_card(g, run, "self")
	var energy_before := run.fight.energy
	s._card_views[selfish].press()
	await await_idle_frame()
	assert_int(run.fight.energy).is_less(energy_before)
	assert_int(run.fight.hero_block).is_greater(0)


func test_clicking_a_selected_card_again_deselects_it() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var attack := _find_card(g, run, "enemy")
	s._card_views[attack].press()
	assert_int(s.selected_index).is_equal(attack)
	s._card_views[attack].press()
	await await_idle_frame()
	assert_int(s.selected_index).is_equal(-1)
	assert_str(s._prompt.text).is_equal("")


func test_an_unaffordable_card_cannot_be_selected() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	run.fight.energy = 0
	s.refresh()
	await await_idle_frame()
	assert_int(s._playable.size()).is_equal(0)
	s._card_views[0].press()
	await await_idle_frame()
	assert_int(s.selected_index).is_equal(-1)
	assert_bool(s._card_views[0].playable).is_false()


func test_ending_the_turn_lets_the_enemy_act() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var turn_before := run.fight.turn
	s._end_turn.emit_signal("pressed")
	await await_idle_frame()
	assert_int(run.fight.turn).is_greater(turn_before)


func test_the_screen_reports_when_the_fight_leaves_the_fight_phase() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var ended := [0]
	s.fight_ended.connect(func() -> void: ended[0] += 1)
	# Kill the enemy outright, then play anything to let the engine resolve.
	run.fight.enemies[0].hp = 1
	var attack := _find_card(g, run, "enemy")
	s._card_views[attack].press()
	s._enemy_views[0].press()
	await await_idle_frame()
	assert_str(run.phase).is_not_equal("fight")
	assert_int(ended[0]).is_equal(1)


func test_the_hero_vitals_read_back_the_fight_state() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_str(s._vitals.text).contains("%d/%d" % [run.fight.hero_hp, run.fight.hero_max_hp])
	assert_str(s._vitals.text).contains(str(run.fight.energy))
	assert_str(s._piles.text).contains(str(run.fight.draw_pile.size()))


## Finds a hand index whose card targets `target`, or -1.
func _find_card(g: GameRoot, run: RunState, target: String) -> int:
	for i in run.fight.hand.size():
		var def: CardDef = g.content.cards[run.fight.hand[i].def_id]
		if def.target == target:
			return i
	return -1
