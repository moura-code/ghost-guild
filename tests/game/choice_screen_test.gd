extends GdUnitTestSuite

const TMP := "user://test_saves/choice_screen_test.json"


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


func _at(g: GameRoot, node: Dictionary) -> RunState:
	var run := g.start_run(1)
	TestFixtures.set_nodes(run, [node])
	RunEngine.apply(run, {"kind": "enter"})
	return run


func _screen(g: GameRoot, run: RunState) -> ChoiceScreen:
	var s: ChoiceScreen = auto_free(ChoiceScreen.new())
	add_child(s)
	s.size = Vector2(720.0, 480.0)
	s.bind(g, run)
	return s


func test_it_handles_exactly_the_four_non_fight_nodes() -> void:
	assert_bool(ChoiceScreen.handles("reward")).is_true()
	assert_bool(ChoiceScreen.handles("event")).is_true()
	assert_bool(ChoiceScreen.handles("rest")).is_true()
	assert_bool(ChoiceScreen.handles("shop")).is_true()
	assert_bool(ChoiceScreen.handles("descent")).is_true()
	assert_bool(ChoiceScreen.handles("fight")).is_false()
	assert_bool(ChoiceScreen.handles("node")).is_false()
	assert_bool(ChoiceScreen.handles("exit")).is_false()


func test_rest_offers_healing_and_a_card_to_sharpen() -> void:
	var g := _game()
	var run := _at(g, {"kind": "rest"})
	run.hero.hp -= 5
	var s := _screen(g, run)
	await await_idle_frame()
	assert_str(run.phase).is_equal("rest")
	assert_str(s._title.text).is_equal(g.text("ui.run.phase.rest"))
	assert_int(s._actions.size()).is_greater(1)
	var heal := s.label_for({"kind": "rest_heal"})
	assert_str(heal).contains("5")
	assert_str(heal).is_not_equal("ui.choice.rest_heal")


func test_resting_actually_heals_the_hero() -> void:
	var g := _game()
	var run := _at(g, {"kind": "rest"})
	run.hero.hp = 10
	var s := _screen(g, run)
	await await_idle_frame()
	var heal_index := _index_of(s, "rest_heal")
	assert_int(heal_index).is_greater_equal(0)
	s._buttons[heal_index].emit_signal("pressed")
	await await_idle_frame()
	assert_int(run.hero.hp).is_greater(10)


func test_an_event_shows_its_authored_text_and_choices() -> void:
	var g := _game()
	var run := _at(g, {"kind": "event", "event": "whispering_well"})
	var s := _screen(g, run)
	await await_idle_frame()
	assert_str(run.phase).is_equal("event")
	var def: EventDef = g.content.events[run.event_id]
	assert_str(s._context.text).is_equal(g.text(def.text_key))
	assert_str(s._context.text).is_not_equal(def.text_key)
	assert_int(s._actions.size()).is_equal(def.choices.size())
	assert_str(s._buttons[0].text).is_equal(g.text(String(def.choices[0]["text"])))


func test_choosing_an_event_option_resolves_it() -> void:
	var g := _game()
	var run := _at(g, {"kind": "event", "event": "whispering_well"})
	var s := _screen(g, run)
	await await_idle_frame()
	s._buttons[0].emit_signal("pressed")
	await await_idle_frame()
	assert_str(run.phase).is_not_equal("event")


func test_the_shop_shows_the_purse_and_prices_every_item() -> void:
	var g := _game()
	var run := _at(g, {"kind": "shop"})
	run.coin = 500
	var s := _screen(g, run)
	s.refresh()
	await await_idle_frame()
	assert_str(run.phase).is_equal("shop")
	assert_str(s._context.text).contains("500")
	var buy := s.label_for({"kind": "buy_card", "card": String(run.shop["cards"][0])})
	assert_str(buy).contains(str(int(run.shop["card_price"])))


func test_a_shop_you_cannot_afford_only_offers_the_door() -> void:
	var g := _game()
	var run := _at(g, {"kind": "shop"})
	run.coin = 0
	var s := _screen(g, run)
	s.refresh()
	await await_idle_frame()
	assert_int(s._actions.size()).is_equal(1)
	assert_str(s._buttons[0].text).is_equal(g.text("ui.choice.leave"))


func test_leaving_the_shop_moves_the_run_on() -> void:
	var g := _game()
	var run := _at(g, {"kind": "shop"})
	run.coin = 0
	var s := _screen(g, run)
	s.refresh()
	await await_idle_frame()
	s._buttons[0].emit_signal("pressed")
	await await_idle_frame()
	assert_str(run.phase).is_not_equal("shop")


func test_a_card_reward_names_its_cards_and_lets_you_refuse() -> void:
	var g := _game()
	var run := _at(g, {"kind": "fight", "enemies": ["bone_rat"]})
	TestFixtures.autofight(run)
	assert_str(run.phase).is_equal("reward")
	var s := _screen(g, run)
	await await_idle_frame()
	var offered: Array = run.reward.get("cards", [])
	assert_int(s._actions.size()).is_equal(offered.size() + 1)
	assert_str(s.option_label(s._actions.size() - 1)).is_equal(g.text("ui.choice.skip"))
	for i in offered.size():
		var def: CardDef = g.content.cards[String(offered[i])]
		assert_str(s.option_label(i)).is_equal(g.text(def.name_key))
	# ...and each offer is a card face, not a row of text.
	assert_int(_visible_cards(s)).is_equal(offered.size())


func test_taking_a_reward_card_puts_it_in_the_deck() -> void:
	var g := _game()
	var run := _at(g, {"kind": "fight", "enemies": ["bone_rat"]})
	TestFixtures.autofight(run)
	var s := _screen(g, run)
	await await_idle_frame()
	var before := run.hero.deck.size()
	s._cards[0].press()
	await await_idle_frame()
	assert_int(run.hero.deck.size()).is_equal(before + 1)


func test_options_are_pooled_across_refreshes() -> void:
	var g := _game()
	var run := _at(g, {"kind": "rest"})
	var s := _screen(g, run)
	await await_idle_frame()
	var first: Button = s._buttons[0]
	s.refresh()
	s.refresh()
	await await_idle_frame()
	assert_object(s._buttons[0]).is_same(first)


func _visible_cards(s: ChoiceScreen) -> int:
	var n := 0
	for card in s._cards:
		if card.visible:
			n += 1
	return n


func _index_of(s: ChoiceScreen, kind: String) -> int:
	for i in s._actions.size():
		if String(s._actions[i].get("kind", "")) == kind:
			return i
	return -1


func test_the_descent_draft_offers_one_pick_per_skipped_floor() -> void:
	var g := _game()
	# Reach floor 3 so a descent from 3 skips floors 1 and 2.
	g.campaign.record_depth = 3
	var run := g.start_run(3)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_str(run.phase).is_equal("descent")
	var offer: Dictionary = run.descent_offers[0]
	assert_str(s._context.text).contains(str(int(offer["floor"])))
	assert_str(s._context.text).is_not_equal("ui.descent.offer")
	# One button per offered card, plus the refusal.
	assert_int(s._actions.size()).is_equal(int(offer["cards"].size()) + 1)
	var def: CardDef = g.content.cards[String(offer["cards"][0])]
	assert_str(s.option_label(0)).is_equal(g.text(def.name_key))
	assert_str(s.option_label(s._actions.size() - 1)).is_equal(g.text("ui.choice.skip"))


func test_taking_a_draft_pick_puts_the_card_in_the_deck() -> void:
	var g := _game()
	g.campaign.record_depth = 3
	var run := g.start_run(3)
	var s := _screen(g, run)
	await await_idle_frame()
	var before := run.hero.deck.size()
	s._cards[0].press()
	await await_idle_frame()
	assert_int(run.hero.deck.size()).is_equal(before + 1)


func test_the_draft_ends_and_the_run_begins_on_the_entry_floor() -> void:
	var g := _game()
	g.campaign.record_depth = 3
	var run := g.start_run(3)
	var s := _screen(g, run)
	await await_idle_frame()
	var guard := 0
	while run.phase == "descent" and guard < 20:
		s.refresh()
		s.take(0)
		guard += 1
	assert_str(run.phase).is_equal("node")
	assert_int(run.floor).is_equal(3)


func test_an_event_is_titled_with_its_own_name() -> void:
	# It said "An event". The one encounter in the run that is hand-authored
	# and has a name was being labelled with the name of its phase.
	var g := _game()
	var run := _at(g, {"kind": "event", "event": "whispering_well"})
	var s := _screen(g, run)
	await await_idle_frame()
	var def: EventDef = g.content.events["whispering_well"]
	assert_str(s._title.text).is_equal(g.text(def.name_key))
	assert_str(s._title.text).is_not_equal(g.text("ui.run.phase.event"))


func test_a_shop_still_uses_its_phase_heading() -> void:
	# Only an authored encounter has a name of its own; a shop is a shop.
	var g := _game()
	var run := _at(g, {"kind": "shop"})
	var s := _screen(g, run)
	await await_idle_frame()
	assert_str(s._title.text).is_equal(g.text("ui.run.phase.shop"))
