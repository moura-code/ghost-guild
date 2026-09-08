extends GdUnitTestSuite


func _balance() -> Dictionary:
	return TestFixtures.content().balance


func test_soul_and_coin_curves() -> void:
	assert_float(Rewards.soul_for(1, _balance())).is_equal_approx(1.3, 0.0001)
	assert_float(Rewards.soul_for(3, _balance())).is_equal_approx(2.197, 0.0001)
	assert_int(Rewards.coin_for("fight", 1, _balance())).is_equal(12)
	assert_int(Rewards.coin_for("fight", 10, _balance())).is_equal(30)
	assert_int(Rewards.coin_for("elite", 1, _balance())).is_equal(24)
	assert_int(Rewards.coin_for("boss", 1, _balance())).is_equal(36)


func test_pool_cards_filters_by_pool_and_rarity() -> void:
	var ids := Rewards.pool_cards(TestFixtures.content(), ["sexton"], ["rare"])
	assert_array(ids).is_equal(["bulwark", "requiem", "second_wind"])
	assert_array(Rewards.pool_cards(TestFixtures.content(), ["nowhere"], ["common"])).is_empty()


func test_card_offer_is_distinct_non_basic_and_deterministic() -> void:
	var content := TestFixtures.content()
	var a := Rewards.card_offer(content, ["sexton", "catacombs"], Rng.new(3), _balance())
	var b := Rewards.card_offer(content, ["sexton", "catacombs"], Rng.new(3), _balance())
	assert_array(a).has_size(3)
	assert_array(a).is_equal(b)
	assert_bool(a[0] != a[1] and a[1] != a[2] and a[0] != a[2]).is_true()
	for id in a:
		var card: CardDef = content.cards[id]
		assert_str(card.rarity).is_not_equal("basic")
		assert_bool(card.pool == "sexton" or card.pool == "catacombs").is_true()


func test_card_offer_rare_only_and_short_pools() -> void:
	var content := TestFixtures.content()
	var rares := Rewards.card_offer(content, ["sexton", "catacombs"], Rng.new(1), _balance(), 3, true)
	assert_array(rares).has_size(3)
	for id in rares:
		var card: CardDef = content.cards[id]
		assert_str(card.rarity).is_equal("rare")
	var few := Rewards.card_offer(content, ["sexton"], Rng.new(1), _balance(), 5, true)
	assert_array(few).has_size(3)


func test_rarity_weights_favour_commons() -> void:
	var content := TestFixtures.content()
	var commons := 0
	for seed in 40:
		var offer := Rewards.card_offer(content, ["sexton", "catacombs"], Rng.new(seed), _balance())
		var card: CardDef = content.cards[offer[0]]
		if card.rarity == "common":
			commons += 1
	assert_int(commons).is_greater(20)


func test_relic_offer_skips_owned() -> void:
	var content := TestFixtures.content()
	var all: Array = content.relics.keys()
	var five: Array = all.duplicate()
	five.erase("grave_coin")
	assert_str(Rewards.relic_offer(content, five, Rng.new(1))).is_equal("grave_coin")
	assert_str(Rewards.relic_offer(content, all, Rng.new(1))).is_equal("")
	var any := Rewards.relic_offer(content, [], Rng.new(2))
	assert_bool(content.relics.has(any)).is_true()


func test_run_stats_measure_per_floor() -> void:
	var s := RunStats.new()
	s.record(3, true, 4)
	s.record(3, true, 6)
	s.record(3, false, 30)
	s.record(4, false, 2)
	var m3 := s.measured(3)
	assert_int(m3["fights"]).is_equal(3)
	assert_int(m3["wins"]).is_equal(2)
	assert_float(m3["win_rate"]).is_equal_approx(0.6667, 0.001)
	assert_float(m3["avg_turns"]).is_equal_approx(5.0, 0.0001)
	assert_float(s.measured(4)["avg_turns"]).is_equal(0.0)
	assert_int(s.measured(9)["fights"]).is_equal(0)


func test_run_stats_round_trip() -> void:
	var s := RunStats.new()
	s.record(2, true, 5)
	s.record(2, false, 7)
	var back := RunStats.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_dict(back.measured(2)).is_equal(s.measured(2))
	assert_bool(back.floors.has(2)).is_true()


func test_a_class_relic_is_never_offered_as_loot() -> void:
	# A Sexton handed the Hexer's Thimble is being given another class's
	# identity as a drop, and the class that owns it already starts with it.
	var content := TestFixtures.content()
	var class_relics: Array = []
	for class_id in content.classes:
		class_relics.append((content.classes[class_id] as ClassDef).relic)
	assert_array(class_relics).is_not_empty()
	for seed_value in range(40):
		var got := Rewards.relic_offer(content, [], Rng.new(seed_value))
		assert_bool(class_relics.has(got)).override_failure_message(
			"offered the class relic %s" % got).is_false()
