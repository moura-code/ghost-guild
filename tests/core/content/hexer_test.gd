extends GdUnitTestSuite
## The Hexer (spec §3.4): Poison and Weak, attrition.
##
## The claim that matters is not that the Hexer is good. It is that the Hexer
## and the Sexton are good at *different things*, because a second class that
## is simply better or simply worse is a patch note rather than a choice --
## and because "unlocked by the first true ghost in the Fungal Deep" only
## reads as a reward if the thing it unlocks is what the Deep asks for.


func _content() -> Content:
	return Content.load_from("res://data")


func _starter(c: Content, class_id: String) -> HeroSnapshot:
	return Hero.create(c, class_id, "Tester", {}, 1).snapshot()


## Win rate for a starting deck of `class_id` on `floor`, same seed both ways.
func _rate(c: Content, class_id: String, floor: int) -> float:
	var biome := Biomes.for_floor(c, floor)
	var sim := Strength.simulate(c, _starter(c, class_id), biome, floor, 31337, 40)
	return float(sim["win_rate"])


# ------------------------------------------------------------- the shape

func test_it_is_locked_behind_the_deep() -> void:
	var c := _content()
	assert_str(Classes.locked_behind(c, "hexer")).is_equal("fungal_deep")
	assert_str(Classes.locked_behind(c, Classes.starting(c))).is_equal("")


func test_it_pays_for_attrition_in_health() -> void:
	# Outlasting is only a plan if it costs something up front.
	var c := _content()
	var hexer: ClassDef = c.classes["hexer"]
	var sexton: ClassDef = c.classes["sexton"]
	assert_int(hexer.base_hp).is_less(sexton.base_hp)


func test_its_deck_is_poison_and_weak_rather_than_bone() -> void:
	var c := _content()
	var tags: Dictionary = {}
	for card_id in (c.classes["hexer"] as ClassDef).starting_deck:
		for tag in (c.cards[card_id] as CardDef).tags:
			tags[tag] = int(tags.get(tag, 0)) + 1
	assert_int(int(tags.get("poison", 0))).is_greater(0)
	assert_int(int(tags.get("bone", 0))).is_equal(0)


func test_its_pool_leans_the_way_the_class_does() -> void:
	# A class pool that does not lean is a second neutral pool.
	var c := _content()
	var leaning := 0
	var total := 0
	for id in c.cards:
		var card: CardDef = c.cards[id]
		if card.pool != "hexer":
			continue
		total += 1
		if card.tags.has("poison") or card.tags.has("weak"):
			leaning += 1
	assert_int(total).is_greater_equal(12)
	assert_int(leaning * 2).override_failure_message(
		"only %d of %d Hexer cards are Poison or Weak" % [leaning, total]) \
		.is_greater_equal(total)


# ------------------------------------------------------------ the contrast

func test_each_class_is_the_better_one_somewhere() -> void:
	# The Hexer poisons Flesh in the Deep; the Sexton can face Constructs
	# in the Kiln. The revised Catacombs have tied starter win rates. If one class won both, the other would be a strictly worse
	# way to play and the unlock would be an upgrade rather than a choice.
	var c := _content()
	var starting := Classes.starting(c)
	var upstairs := _rate(c, starting, 21) - _rate(c, "hexer", 21)
	var downstairs := _rate(c, "hexer", 14) - _rate(c, starting, 14)
	assert_float(upstairs).override_failure_message(
		"the Hexer is at least as good as the %s in the Kiln (%+.2f)" \
		% [starting, upstairs]).is_greater(0.0)
	assert_float(downstairs).override_failure_message(
		"the %s is at least as good as the Hexer in the Deep (%+.2f)" \
		% [starting, downstairs]).is_greater(0.0)
