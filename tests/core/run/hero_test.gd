extends GdUnitTestSuite


func test_create_starter_hero() -> void:
	var h := Hero.create(TestFixtures.content(), "sexton", "Maren")
	assert_str(h.name).is_equal("Maren")
	assert_str(h.class_id).is_equal("sexton")
	assert_array(h.deck).has_size(10)
	assert_int(h.deck[0].uid).is_equal(1)
	assert_int(h.deck[9].uid).is_equal(10)
	assert_str(h.deck[9].def_id).is_equal("last_rites")
	assert_int(h.next_uid).is_equal(11)
	assert_array(h.relics).is_equal(["sextons_lantern"])
	assert_int(h.max_hp).is_equal(70)
	assert_int(h.hp).is_equal(70)
	assert_int(h.resolve).is_equal(1)
	assert_int(h.max_resolve).is_equal(1)
	assert_int(h.camp).is_equal(0)
	assert_int(h.runs).is_equal(0)


func test_meta_stats_apply_at_creation() -> void:
	var h := Hero.create(TestFixtures.content(), "sexton", "Osk", {"vigor": 2, "might": 1}, 2)
	assert_int(h.stats["vigor"]).is_equal(2)
	assert_int(h.stats["might"]).is_equal(1)
	assert_int(h.max_hp).is_equal(76)
	assert_int(h.hp).is_equal(76)
	assert_int(h.resolve).is_equal(2)


func test_snapshot_copies_cards_and_adds_bonus_stats() -> void:
	var h := Hero.create(TestFixtures.content(), "sexton", "Ilse")
	h.hp = 50
	var s := h.snapshot({"might": 2, "vigor": 1})
	assert_int(s.stats["might"]).is_equal(2)
	assert_int(s.stats["wit"]).is_equal(0)
	assert_int(s.max_hp).is_equal(73)
	assert_int(s.hp).is_equal(50)
	assert_array(s.deck).has_size(10)
	s.deck[0].upgraded = true
	assert_bool(h.deck[0].upgraded).is_false()
	assert_int(h.stats["might"]).is_equal(0)


func test_card_operations() -> void:
	var h := Hero.create(TestFixtures.content(), "sexton", "Wren")
	var card := h.add_card("bone_spear")
	assert_int(card.uid).is_equal(11)
	assert_array(h.deck).has_size(11)
	assert_bool(h.upgrade_card(11)).is_true()
	assert_bool(h.upgrade_card(11)).is_false()
	assert_bool(h.find_card(11).upgraded).is_true()
	assert_bool(h.remove_card(3)).is_true()
	assert_array(h.deck).has_size(10)
	assert_object(h.find_card(3)).is_null()
	assert_bool(h.remove_card(3)).is_false()
	assert_bool(h.upgrade_card(999)).is_false()


func test_recompute_max_hp_keeps_gained_hp() -> void:
	var h := Hero.create(TestFixtures.content(), "sexton", "Edda")
	h.hp = 40
	h.stats["vigor"] = 3
	h.recompute_max_hp(TestFixtures.content())
	assert_int(h.max_hp).is_equal(79)
	assert_int(h.hp).is_equal(49)


func test_generated_names_are_deterministic_members_of_the_list() -> void:
	var a := Hero.generate_name(Rng.new(4))
	var b := Hero.generate_name(Rng.new(4))
	assert_str(a).is_equal(b)
	assert_bool(Hero.NAMES.has(a)).is_true()


func test_json_round_trip() -> void:
	var h := Hero.create(TestFixtures.content(), "sexton", "Maren", {"vigor": 1})
	h.id = 7
	h.upgrade_card(1)
	h.picks_taken[2] = true
	h.camp = 3
	h.resolve = 0
	h.runs = 2
	h.relics.append("bone_charm")
	var text := JSON.stringify(h.to_dict())
	var back := Hero.from_dict(JSON.parse_string(text))
	assert_int(back.id).is_equal(7)
	assert_str(back.name).is_equal("Maren")
	assert_array(back.deck).has_size(10)
	assert_bool(back.deck[0].upgraded).is_true()
	assert_int(back.deck[9].uid).is_equal(10)
	assert_int(back.max_hp).is_equal(73)
	assert_int(back.stats["vigor"]).is_equal(1)
	assert_bool(back.picks_taken.has(2)).is_true()
	assert_int(back.camp).is_equal(3)
	assert_int(back.resolve).is_equal(0)
	assert_int(back.runs).is_equal(2)
	assert_int(back.next_uid).is_equal(11)
	assert_array(back.relics).is_equal(["sextons_lantern", "bone_charm"])
