extends GdUnitTestSuite
## The Kiln (spec §2): floors 21-30, constructs and fire.
##
## The Deep made the Hexer the answer to every floor past ten, which is the
## failure the Hexer stage was written to avoid arriving one biome later. The
## Kiln is where Poison stops working -- `affinity.json` has said Poison is
## ×0 into Construct since the slice and there have never been any constructs
## -- so it is where the Sexton comes back.


func _content() -> Content:
	return Content.load_from("res://data")


func _starter(c: Content, class_id: String) -> HeroSnapshot:
	return Hero.create(c, class_id, "Tester", {}, 1).snapshot()


func _rate(c: Content, class_id: String, floor: int) -> float:
	var sim := Strength.simulate(c, _starter(c, class_id),
		Biomes.for_floor(c, floor), floor, 31337, 40)
	return float(sim["win_rate"])


# --------------------------------------------------------------- the shape

func test_it_holds_the_floors_below_the_deep() -> void:
	var c := _content()
	assert_str(Biomes.for_floor(c, 21).id).is_equal("the_kiln")
	assert_str(Biomes.for_floor(c, 30).id).is_equal("the_kiln")
	assert_int(Biomes.depth(c)).is_equal(30)


func test_the_dungeon_is_three_biomes_deep_with_no_gap() -> void:
	# Spec §2: three hand-authored biomes at launch, ten floors each.
	var c := _content()
	assert_int(c.biomes.size()).is_equal(3)
	for floor in range(1, Biomes.depth(c) + 1):
		assert_object(Biomes.for_floor(c, floor)).is_not_null()


func test_everything_down_there_is_a_construct_or_on_fire() -> void:
	var c := _content()
	var total := 0
	for id in c.enemies:
		var def: EnemyDef = c.enemies[id]
		if def.biome != "the_kiln":
			continue
		total += 1
		assert_bool(def.tags.has("construct") or def.tags.has("fire")) \
			.override_failure_message("%s is neither construct nor fire" % id).is_true()
	assert_int(total).is_greater_equal(10)


func test_nothing_down_there_is_flesh() -> void:
	# The whole point: Poison is ×0 into Construct and ×1.5 into Flesh, so one
	# Flesh enemy in the Kiln would hand the Hexer a foothold in the biome
	# built to take it away.
	var c := _content()
	for id in c.enemies:
		var def: EnemyDef = c.enemies[id]
		if def.biome == "the_kiln":
			assert_bool(def.tags.has("flesh")).override_failure_message(
				"%s is Flesh, in the Kiln" % id).is_false()


func test_it_burns_and_it_holds() -> void:
	# Its own verbs, not the other biomes'. At least half its roster either
	# blocks or sets the hero on fire.
	var c := _content()
	var kiln := 0
	var burning_or_holding := 0
	for id in c.enemies:
		var def: EnemyDef = c.enemies[id]
		if def.biome != "the_kiln":
			continue
		kiln += 1
		for move_id in def.moves:
			var move: Dictionary = def.moves[move_id]
			if String(move.get("intent", "")) == "block" \
					or String(move.get("status", "")) == "burn":
				burning_or_holding += 1
				break
	assert_int(burning_or_holding * 2).override_failure_message(
		"only %d of %d Kiln enemies burn or hold" % [burning_or_holding, kiln]) \
		.is_greater_equal(kiln)


# ------------------------------------------------------------ the contrast

func test_poison_stops_working_down_here() -> void:
	var c := _content()
	var deep := _rate(c, "hexer", 14)
	var kiln := _rate(c, "hexer", 24)
	assert_float(kiln).override_failure_message(
		"the Hexer does as well in the Kiln (%.2f) as in the Deep (%.2f)" % [kiln, deep]) \
		.is_less(deep)


func test_every_class_is_the_best_one_somewhere() -> void:
	# The claim that makes a dungeon a journey rather than a list of floors,
	# and the one that fails loudly if a biome is merely harder. The Sexton
	# owns the Catacombs and the Kiln; the Hexer owns the Deep.
	var c := _content()
	var starting := Classes.starting(c)
	# The floor in each biome where a *starting* deck is still alive enough for
	# the comparison to mean anything. By floor 24 neither class clears a fight
	# with ten cards, and two zeroes are not a contrast.
	var rows := {
		"catacombs": {"floor": 8, "winner": starting},
		"fungal_deep": {"floor": 14, "winner": "hexer"},
		"the_kiln": {"floor": 21, "winner": starting},
	}
	var won: Dictionary = {}
	for biome in rows:
		var floor := int(rows[biome]["floor"])
		var expected := String(rows[biome]["winner"])
		var other := "hexer" if expected == starting else starting
		var margin := _rate(c, expected, floor) - _rate(c, other, floor)
		assert_float(margin).override_failure_message(
			"%s does not favour the %s on floor %d (%+.2f)" % [biome, expected, floor, margin]) \
			.is_greater(0.0)
		won[expected] = true
	assert_int(won.size()).override_failure_message(
		"one class wins everywhere, so the other is a worse way to play") \
		.is_equal(2)
