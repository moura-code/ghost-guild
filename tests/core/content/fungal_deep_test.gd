extends GdUnitTestSuite
## The Fungal Deep (spec §2): floors 11-20, flesh and fungal.
##
## A second biome that is the first one with different names is not a second
## biome. These are the mechanical claims the Deep makes -- that it fights by
## attrition rather than by a bigger number, and that the affinity table
## (Poison x1.5 into Flesh, x0 into Construct) therefore means something --
## asserted rather than asserted-in-a-design-document.


func _content() -> Content:
	return Content.load_from("res://data")


func _biome(c: Content) -> BiomeDef:
	return c.biomes["fungal_deep"]


func _snapshot(c: Content, deck: Array) -> HeroSnapshot:
	var hero := Hero.create(c, "sexton", "Tester", {}, 1)
	hero.deck.clear()
	for id in deck:
		hero.add_card(String(id))
	return hero.snapshot()


## Ten cards, so both decks are the same size and only their contents differ.
const POISON_DECK := ["plague_vial", "plague_vial", "cutting_fungus", "cutting_fungus",
	"rupture", "spore_cloud", "bone_wall", "bone_wall", "shovel_swing", "shovel_swing"]
const BONE_DECK := ["shovel_swing", "shovel_swing", "reaping", "reaping",
	"bone_spear", "bone_shard", "bone_wall", "bone_wall", "shovel_swing", "reaping"]


# --------------------------------------------------------------- the shape

func test_the_deep_holds_the_floors_below_the_catacombs() -> void:
	var c := _content()
	var deep := _biome(c)
	var cata: BiomeDef = c.biomes["catacombs"]
	assert_int(deep.first_floor).is_equal(cata.last_floor + 1)
	assert_str(Biomes.for_floor(c, 11).id).is_equal("fungal_deep")
	assert_str(Biomes.for_floor(c, 20).id).is_equal("fungal_deep")


func test_every_encounter_it_names_exists_and_is_of_this_biome() -> void:
	var c := _content()
	for band in _biome(c).encounters:
		for group in band["groups"]:
			for enemy_id in group:
				var def: EnemyDef = c.enemies.get(String(enemy_id))
				assert_object(def).override_failure_message(
					"unknown enemy %s" % enemy_id).is_not_null()
				assert_str(def.biome).is_equal("fungal_deep")


func test_every_floor_of_the_deep_has_something_to_fight() -> void:
	# A band with a gap in it generates a fight node with an empty group.
	var c := _content()
	var deep := _biome(c)
	for floor in range(deep.first_floor, deep.last_floor + 1):
		assert_array(FloorGenerator.groups_for(deep, floor)).override_failure_message(
			"floor %d has no encounter table" % floor).is_not_empty()


# ------------------------------------------------------------ the character

func test_it_is_flesh_and_fungus_rather_than_more_undead() -> void:
	# Poison is x1.5 into Flesh and Holy x1.5 into Undead. A "flesh biome"
	# whose enemies are mostly tagged undead is the Catacombs with new art.
	var c := _content()
	var flesh := 0
	var total := 0
	for id in c.enemies:
		var def: EnemyDef = c.enemies[id]
		if def.biome != "fungal_deep":
			continue
		total += 1
		if def.tags.has("flesh") or def.tags.has("fungal"):
			flesh += 1
	assert_int(total).is_greater_equal(10)
	assert_int(flesh).is_equal(total)


func test_it_fights_by_wearing_you_down() -> void:
	# The Catacombs hit harder; the Deep makes the hits land harder. At least
	# a third of its enemies apply vulnerable or bleed, which the Catacombs
	# never do.
	var c := _content()
	var attrition := 0
	var total := 0
	for id in c.enemies:
		var def: EnemyDef = c.enemies[id]
		if def.biome != "fungal_deep":
			continue
		total += 1
		for move_id in def.moves:
			var status := String((def.moves[move_id] as Dictionary).get("status", ""))
			if status == "vulnerable" or status == "bleed":
				attrition += 1
				break
	assert_int(attrition * 3).override_failure_message(
		"only %d of %d Deep enemies wear the hero down" % [attrition, total]) \
		.is_greater_equal(total)


func test_poison_is_worth_more_down_here_than_bone_is() -> void:
	# The reason the Deep exists as a *place* rather than as a floor range:
	# it is where a Poison deck starts to pay and a pure Bone deck starts to
	# struggle, which is also the argument for the Hexer being unlocked here.
	# Asserted as a *contrast* rather than as an absolute: the same two decks
	# are within noise of each other in the Catacombs (measured -0.02) and the
	# Deep opens a gap that widens with depth (+0.17, +0.33, +0.50 at floors
	# 12, 14 and 18). A biome is a place when the deck you brought matters.
	var c := _content()
	var here := _edge(c, _biome(c), 14)
	var there := _edge(c, c.biomes["catacombs"], 9)
	assert_float(here).override_failure_message(
		"poison's edge is %+.2f in the Deep and %+.2f in the Catacombs -- " \
		% [here, there] + "the affinity table is decorative").is_greater(there + 0.15)


## How much better a Poison deck does than a Bone deck of the same size on
## this floor. Positive means Poison is ahead.
func _edge(c: Content, biome: BiomeDef, floor: int) -> float:
	var poison := Strength.simulate(c, _snapshot(c, POISON_DECK), biome, floor, 4242, 40)
	var bone := Strength.simulate(c, _snapshot(c, BONE_DECK), biome, floor, 4242, 40)
	return float(poison["win_rate"]) - float(bone["win_rate"])
