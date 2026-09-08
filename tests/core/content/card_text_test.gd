extends GdUnitTestSuite
## What a card says it does (see `CardText`).


func _content() -> Content:
	return Content.load_from("res://data")


func test_a_card_reads_out_its_own_numbers() -> void:
	var c := _content()
	var wall: CardDef = c.cards["bone_wall"]
	assert_str(CardText.of(c, wall, false)).is_equal("Gain 11 Block.")


func test_an_upgraded_card_reads_out_the_upgraded_numbers() -> void:
	# It used to read out the base ones. Every upgraded card in the game was
	# wrong about itself, quietly, on the table.
	var c := _content()
	var wall: CardDef = c.cards["bone_wall"]
	var base := CardText.of(c, wall, false)
	var better := CardText.of(c, wall, true)
	assert_str(better).is_not_equal(base)
	assert_str(better).contains(str(int((wall.upgrade_effects[0] as Dictionary)["amount"])))


func test_hits_come_after_the_amount_because_the_words_do() -> void:
	var c := _content()
	assert_str(CardText.of(c, c.cards["rat_swarm"], false)).is_equal("Deal 2 damage 4 times.")


func test_every_card_says_what_it_does() -> void:
	# The guard the whole thing exists for. Thirty-two cards shipped reading
	# "Gain {0} Block and {1} Thorns." because they were authored with
	# placeholders and nothing substituted them.
	var c := _content()
	var broken: Array[String] = []
	for id in c.cards:
		var def: CardDef = c.cards[id]
		for upgraded in [false, true]:
			var text := CardText.of(c, def, upgraded)
			if text.contains("{") or text.contains("}"):
				broken.append("%s%s: %s" % [id, "+" if upgraded else "", text])
	assert_array(broken).override_failure_message(
		"cards with an unresolved placeholder:\n  %s" % "\n  ".join(broken)).is_empty()


func test_a_card_whose_numbers_change_says_so() -> void:
	# The precise version of "no number is written into the string": if the
	# upgrade changes what the card does, the card has to read differently.
	# A literal in the text passes silently right up until someone upgrades it.
	#
	# Deliberately not a digit hunt -- Hallowed Strike's "50% more against the
	# undead" is a fact about the affinity table, not one of the card's own
	# numbers, and a blunter test called it a bug.
	var c := _content()
	var silent: Array[String] = []
	for id in c.cards:
		var def: CardDef = c.cards[id]
		if CardText.numbers(def, false) == CardText.numbers(def, true):
			continue
		if CardText.of(c, def, false) == CardText.of(c, def, true):
			silent.append("%s: %s" % [id, c.text(def.text_key)])
	assert_array(silent).override_failure_message(
		"cards that read the same upgraded as they do unupgraded:
  %s" \
		% "
  ".join(silent)).is_empty()


func test_a_placeholder_with_no_number_is_left_visible() -> void:
	# Better a card that is obviously wrong than one quietly missing a word.
	assert_str(CardText.fill("Deal {0}, then {1}.", [7] as Array[int])) \
		.is_equal("Deal 7, then {1}.")
