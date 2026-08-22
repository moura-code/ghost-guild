extends GdUnitTestSuite


func test_starter_hero_snapshot() -> void:
	var h := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	assert_str(h.class_id).is_equal("sexton")
	assert_array(h.deck).has_size(10)
	assert_str(h.deck[0].def_id).is_equal("strike")
	assert_int(h.deck[9].uid).is_equal(10)
	assert_array(h.relics).is_equal(["sextons_lantern"])
	assert_int(h.max_hp).is_equal(70)
	assert_int(h.hp).is_equal(70)
	assert_int(h.stats["focus"]).is_equal(0)


func test_max_hp_formula_and_clone() -> void:
	assert_int(HeroSnapshot.max_hp_for(70, 4)).is_equal(82)
	var h := HeroSnapshot.starter(TestFixtures.content(), "sexton")
	var c := h.clone()
	c.deck.clear()
	c.stats["might"] = 5
	assert_array(h.deck).has_size(10)
	assert_int(h.stats["might"]).is_equal(0)


func test_card_instance_round_trip() -> void:
	var card := CardInstance.new(7, "strike", true)
	var back := CardInstance.from_dict(card.to_dict())
	assert_int(back.uid).is_equal(7)
	assert_str(back.def_id).is_equal("strike")
	assert_bool(back.upgraded).is_true()


func test_scaling_curves() -> void:
	var b := TestFixtures.content().balance
	assert_int(Scaling.enemy_hp(14, 1, b)).is_equal(14)
	assert_int(Scaling.enemy_hp(14, 10, b)).is_equal(24)
	assert_int(Scaling.enemy_damage(5, 1, b)).is_equal(5)
	assert_int(Scaling.enemy_damage(5, 10, b)).is_equal(7)


func test_bare_state_spawns_scaled_enemies() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "shambler"], 10)
	assert_array(s.enemies).has_size(2)
	assert_int(s.enemies[0].hp).is_equal(24)
	assert_int(s.enemies[1].hp).is_equal(41)
	assert_array(s.living_enemy_indices()).is_equal([0, 1])
	assert_bool(s.all_enemies_dead()).is_false()


func test_draw_then_reshuffle_from_discard() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.fill_draw(s, ["strike", "brace", "strike"])
	var drawn := s.draw(5)
	assert_array(drawn).has_size(3)
	assert_array(s.hand).has_size(3)
	assert_array(s.draw_pile).is_empty()
	assert_array(TestFixtures.events_of(s, "reshuffle")).is_empty()
	s.discard_hand()
	assert_array(s.discard_pile).has_size(3)
	s.draw(2)
	assert_array(s.hand).has_size(2)
	assert_array(s.draw_pile).has_size(1)
	assert_array(s.discard_pile).is_empty()
	assert_array(TestFixtures.events_of(s, "reshuffle")).has_size(1)


func test_draw_respects_hand_limit() -> void:
	var s := TestFixtures.bare_state()
	var ids: Array = []
	for i in 12:
		ids.append("strike")
	TestFixtures.fill_draw(s, ids)
	s.draw(12)
	assert_array(s.hand).has_size(10)
	assert_array(TestFixtures.events_of(s, "hand_full")).has_size(1)


func test_discard_hand_keeps_retain_cards() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.give_hand(s, ["strike", "shroud"])
	s.discard_hand()
	assert_array(s.hand).has_size(1)
	assert_str(s.hand[0].def_id).is_equal("shroud")
	assert_array(s.discard_pile).has_size(1)


func test_new_card_uids_are_unique() -> void:
	var s := TestFixtures.bare_state()
	var a := s.new_card("strike")
	var b := s.new_card("strike")
	assert_int(a.uid).is_not_equal(b.uid)


func test_might_and_wit_include_buffs() -> void:
	var s := TestFixtures.bare_state()
	s.stats["might"] = 2
	s.stats["wit"] = 1
	s.statuses["might_buff"] = 3
	s.statuses["wit_buff"] = 2
	assert_int(s.might()).is_equal(5)
	assert_int(s.wit()).is_equal(3)
	assert_int(s.hero_status("weak")).is_equal(0)


func test_clone_is_independent() -> void:
	var s := TestFixtures.bare_state(["bone_rat"], 1, 5)
	TestFixtures.give_hand(s, ["strike", "brace"])
	s.statuses["weak"] = 1
	var c := s.clone()
	c.hand.clear()
	c.enemies[0].hp -= 5
	c.enemies[0].statuses["vulnerable"] = 2
	c.statuses["weak"] = 9
	c.stats["might"] = 4
	assert_array(s.hand).has_size(2)
	assert_int(s.enemies[0].hp).is_equal(14)
	assert_int(s.enemies[0].status("vulnerable")).is_equal(0)
	assert_int(s.hero_status("weak")).is_equal(1)
	assert_int(s.stats["might"]).is_equal(0)
	assert_array(c.events).is_empty()
	assert_int(s.rng.randi_range("deck", 0, 100000)).is_equal(c.rng.randi_range("deck", 0, 100000))
