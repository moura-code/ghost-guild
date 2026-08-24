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


## The fight anchors itself to its parent, so setting size on it directly
## is overridden by Godot on the next layout pass. It needs a sized parent.
func _screen(g: GameRoot, run: RunState) -> FightScreen:
	var frame: Control = auto_free(Control.new())
	frame.custom_minimum_size = Vector2(1280.0, 720.0)
	frame.size = Vector2(1280.0, 720.0)
	add_child(frame)
	var s := FightScreen.new()
	frame.add_child(s)
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


func test_the_hero_panel_reads_back_the_fight_state() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_int(s._hero.hp).is_equal(run.fight.hero_hp)
	assert_int(s._hero.max_hp).is_equal(run.fight.hero_max_hp)
	assert_int(s._hero.energy).is_equal(run.fight.energy)
	assert_int(s._hero.max_energy).is_equal(run.fight.max_energy)
	assert_str(s._hero._hp_text.text).is_equal("%d/%d" % [run.fight.hero_hp, run.fight.hero_max_hp])


func test_playing_a_card_spends_an_energy_orb() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var before := s._hero.energy
	var selfish := _find_card(g, run, "self")
	s._card_views[selfish].press()
	await await_idle_frame()
	assert_int(s._hero.energy).is_less(before)


func test_the_enemy_intent_carries_an_icon_and_a_number() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var view := s._enemy_views[0]
	assert_object(view._intent_icon.texture).is_not_null()
	assert_bool(view._intent_icon.visible).is_true()
	# The verb is the icon now; the text is just the number.
	assert_str(view._intent.text).is_not_equal("")
	assert_bool(view._intent.text.is_valid_int() or view._intent.text.contains("x")).is_true()


## Finds a hand index whose card targets `target`, or -1.
func _find_card(g: GameRoot, run: RunState, target: String) -> int:
	for i in run.fight.hand.size():
		var def: CardDef = g.content.cards[run.fight.hand[i].def_id]
		if def.target == target:
			return i
	return -1


func test_the_hand_stays_inside_the_window() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	# The bug this guards: the fight lived in a zero-height container, so
	# the fan computed a negative base line and dealt the whole hand above
	# the top of the screen. Every card must be on screen, bottom included.
	assert_float(s.size.y).is_greater(0.0)
	for i in run.fight.hand.size():
		var card := s._card_views[i]
		assert_float(card.position.y).is_greater_equal(0.0)
		assert_float(card.position.y + CardView.CARD_SIZE.y) 			.override_failure_message("card %d hangs off the bottom" % i) 			.is_less_equal(s.size.y)


func test_cards_are_the_size_they_are_supposed_to_be() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	# A wrapping Label with no width bound reports an enormous minimum, and
	# in a PanelContainer that became the card's height -- 469px observed,
	# against a 208px design.
	for i in run.fight.hand.size():
		assert_that(s._card_views[i].size).is_equal(CardView.CARD_SIZE)


func test_the_hand_clears_the_hero_panel() -> void:
	var g := _game()
	var run := _fight(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var hero_right := s._hero.position.x + HeroPanel.PANEL_SIZE.x
	for i in run.fight.hand.size():
		assert_float(s._card_views[i].position.x) 			.override_failure_message("card %d overlaps the hero panel" % i) 			.is_greater_equal(hero_right)
