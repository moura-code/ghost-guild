extends GdUnitTestSuite
## What a card is worth to a particular fighter.
##
## The property that matters is the one auto-draft exists for: the SAME card
## is worth different amounts under different doctrines. If it is not, then
## "the auto-draft upgrade resolves picks with the hero's priority rules" is
## a sentence about nothing.


func _content() -> Content:
	return TestFixtures.content()


func _weights(rules: Array = []) -> Dictionary:
	return PriorityRules.weights_for(Autopilot.default_weights(), rules, _content())


func _card(id: String) -> CardDef:
	return _content().cards[id]


func test_a_card_that_does_more_is_worth_more() -> void:
	var w := _weights()
	assert_float(CardValue.raw_value(_card("strike"), w)) \
		.is_greater(0.0)
	# The same card upgraded hits harder, so it is worth more.
	assert_float(CardValue.raw_value(_card("strike"), w, true)) \
		.is_greater_equal(CardValue.raw_value(_card("strike"), w))


func test_value_is_per_energy_not_per_card() -> void:
	# A draft compares cards that are not the same size. An 18-damage 3-cost
	# and a 6-damage 1-cost are the same card at two scales, and a raw total
	# would take the expensive one every time.
	var w := _weights()
	var strike := _card("strike")
	assert_float(CardValue.of(strike, w)) \
		.is_equal_approx(CardValue.raw_value(strike, w) / CardValue.energy_price(strike), 0.001)


func test_a_free_card_is_not_infinitely_good() -> void:
	# Dividing by a cost of zero is the obvious bug here, and it would make
	# every zero-cost card the only card auto-draft ever takes.
	var zero := CardDef.new()
	zero.cost = 0
	zero.effects = [{"op": "damage", "amount": 4}]
	var value := CardValue.of(zero, _weights())
	assert_bool(is_finite(value)).override_failure_message("a free card scored %f" % value).is_true()
	assert_float(value).is_less(1000.0)


func test_a_blocker_is_worth_more_to_a_fighter_told_to_hold_the_line() -> void:
	# The whole point of the module.
	var strike_first := _weights(["strike_first"])
	var hold := _weights(["hold_the_line"])
	var brace := _card("brace")
	assert_float(CardValue.of(brace, hold)) \
		.override_failure_message("doctrine changed nothing about a block card") \
		.is_greater(CardValue.of(brace, strike_first))


func test_an_attack_is_worth_more_to_a_fighter_told_to_strike_first() -> void:
	var strike_first := _weights(["strike_first"])
	var hold := _weights(["hold_the_line"])
	assert_float(CardValue.of(_card("strike"), strike_first)) \
		.is_greater(CardValue.of(_card("strike"), hold))


func test_a_poison_card_answers_to_the_poison_rule() -> void:
	var plain := _weights()
	var poisoner := _weights(["poison_before_blades"])
	var vial := _card("plague_vial")
	assert_float(CardValue.of(vial, poisoner)).is_greater(CardValue.of(vial, plain))


func test_a_draw_card_is_worth_nothing_extra_until_a_rule_asks_for_it() -> void:
	# `cards_drawn` is zero in the default table by design -- it is a term a
	# rule turns on. A draw effect must therefore score exactly its authored
	# value by default and more once the rule is chosen.
	var plain := _weights()
	var drawer := _weights(["draw_before_striking"])
	var card := CardDef.new()
	card.cost = 1
	card.effects = [{"op": "draw", "amount": 2}]
	assert_float(CardValue.raw_value(card, plain)).is_equal(0.0)
	assert_float(CardValue.raw_value(card, drawer)).is_greater(0.0)


func test_hitting_everything_beats_hitting_one_thing() -> void:
	var w := _weights()
	var single := CardDef.new()
	single.effects = [{"op": "damage", "amount": 6, "target": "target"}]
	var sweep := CardDef.new()
	sweep.effects = [{"op": "damage", "amount": 6, "target": "all_enemies"}]
	assert_float(CardValue.raw_value(sweep, w)).is_greater(CardValue.raw_value(single, w))


func test_a_buff_on_yourself_reads_from_the_hero_table() -> void:
	var w := _weights()
	var card := CardDef.new()
	card.effects = [{"op": "apply_status", "status": "might_buff", "stacks": 2, "target": "self"}]
	var hero_w: Dictionary = w["hero_status"]
	assert_float(CardValue.raw_value(card, w)) \
		.is_equal_approx(2.0 * float(hero_w["might_buff"]), 0.001)


func test_no_card_is_ever_worth_a_negative_amount() -> void:
	# A card with a downside would otherwise score below "no card at all",
	# and auto-draft has to take one of the three.
	var w := _weights()
	for id in _content().cards:
		assert_float(CardValue.of(_content().cards[id], w)) \
			.override_failure_message("%s scored negative" % id).is_greater_equal(0.0)


func test_an_x_cost_card_is_finite() -> void:
	# `cost: "x"` and `amount: "x"` are both strings in the data, and both
	# reach arithmetic.
	var w := _weights()
	var card := CardDef.new()
	card.cost = CardDef.COST_X
	card.effects = [{"op": "damage", "amount": "x"}]
	assert_bool(is_finite(CardValue.of(card, w))).is_true()
	assert_float(CardValue.of(card, w)).is_greater(0.0)


func test_the_best_of_three_is_an_index_into_what_was_offered() -> void:
	var content := _content()
	var w := _weights()
	var offers: Array = ["brace", "strike", "brace"]
	var at := CardValue.best(content, offers, w)
	assert_int(at).is_between(0, offers.size() - 1)


func test_a_tie_goes_to_the_first_so_a_draft_replays() -> void:
	var content := _content()
	assert_int(CardValue.best(content, ["strike", "strike", "strike"], _weights())).is_equal(0)


func test_an_offer_full_of_cards_that_do_not_exist_still_picks_something() -> void:
	# Content moves. Auto-draft must never return -1 into an array index.
	assert_int(CardValue.best(_content(), ["nope", "also_nope"], _weights())).is_equal(0)
	assert_int(CardValue.best(_content(), [], _weights())).is_equal(0)


func test_auto_draft_takes_a_card_from_the_offer_it_was_given() -> void:
	# The wire the whole batch exists for. One pick per skipped floor,
	# resolved while the game is closed.
	var content := _content()
	var hero := Hero.create(content, "sexton", "Maren")
	var biome: BiomeDef = content.biomes["catacombs"]
	var offers := DescentDraft.offers(content, hero, biome, 5, 99)
	assert_int(offers.size()).is_greater(0)
	for offer in offers:
		var cards: Array = offer["cards"]
		var at := DescentDraft.auto_pick(content, cards, [])
		assert_int(at).is_between(0, cards.size() - 1)


func test_two_doctrines_do_not_always_draft_the_same_card() -> void:
	# Across a whole descent's worth of offers, an attacker and a defender
	# must disagree at least once -- otherwise the rules are decorative here.
	var content := _content()
	var hero := Hero.create(content, "sexton", "Maren")
	var biome: BiomeDef = content.biomes["catacombs"]
	var disagreed := false
	for run_seed in [1, 7, 13, 21]:
		for offer in DescentDraft.offers(content, hero, biome, 10, run_seed):
			var cards: Array = offer["cards"]
			if DescentDraft.auto_pick(content, cards, ["strike_first"]) \
					!= DescentDraft.auto_pick(content, cards, ["hold_the_line"]):
				disagreed = true
				break
	assert_bool(disagreed).override_failure_message("doctrine never changed a pick").is_true()


func test_the_same_doctrine_drafts_the_same_card_every_time() -> void:
	# Expeditions resolve from a seed on load; a draft that wobbled would make
	# the same absence produce a different ghost.
	var content := _content()
	var hero := Hero.create(content, "sexton", "Maren")
	var biome: BiomeDef = content.biomes["catacombs"]
	for offer in DescentDraft.offers(content, hero, biome, 8, 5):
		var cards: Array = offer["cards"]
		var first := DescentDraft.auto_pick(content, cards, ["poison_before_blades"])
		assert_int(DescentDraft.auto_pick(content, cards, ["poison_before_blades"])).is_equal(first)
