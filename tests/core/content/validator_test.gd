extends GdUnitTestSuite

const ROOT := "res://tests/fixtures/content_ok"


func _ok() -> Content:
	return Content.load_from(ROOT)


func test_fixture_content_is_valid() -> void:
	assert_array(ContentValidator.validate(_ok())).is_empty()


func test_load_errors_are_reported() -> void:
	var c := _ok()
	c.load_errors.append("boom")
	assert_array(ContentValidator.validate(c)).contains(["boom"])


func test_unknown_effect_op_is_an_error() -> void:
	var c := _ok()
	var card: CardDef = c.cards["fx_strike"]
	card.effects = [{"op": "explode", "amount": 1}]
	var errors := ContentValidator.validate(c)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("fx_strike")
	assert_str(errors[0]).contains("explode")


func test_unknown_status_and_missing_add_card_are_errors() -> void:
	var c := _ok()
	var card: CardDef = c.cards["fx_brace"]
	card.effects = [{"op": "apply_status", "status": "confusion", "stacks": 1}]
	card.upgrade_effects = [{"op": "add_card", "card": "nope", "where": "hand"}]
	var errors := ContentValidator.validate(c)
	assert_int(errors.size()).is_equal(2)


func test_bad_card_type_target_rarity_keyword() -> void:
	var c := _ok()
	var card: CardDef = c.cards["fx_strike"]
	card.type = "spell"
	card.target = "everyone"
	card.rarity = "mythic"
	card.keywords = ["innate"]
	assert_int(ContentValidator.validate(c).size()).is_equal(4)


func test_missing_string_keys_are_errors() -> void:
	var c := _ok()
	c.strings.erase("card.fx_strike.name")
	c.strings.erase("enemy.fx_rat.name")
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_enemy_pattern_must_reference_moves() -> void:
	var c := _ok()
	var rat: EnemyDef = c.enemies["fx_rat"]
	rat.pattern = {"kind": "sequence", "moves": ["bite", "fly"]}
	var errors := ContentValidator.validate(c)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("fly")


func test_enemy_move_shapes() -> void:
	var c := _ok()
	var rat: EnemyDef = c.enemies["fx_rat"]
	rat.moves["bite"] = {"id": "bite", "intent": "attack"}
	rat.moves["hide"] = {"id": "hide", "intent": "dance"}
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_summon_must_reference_enemy_and_kind_must_be_known() -> void:
	var c := _ok()
	var boss: EnemyDef = c.enemies["fx_boss"]
	boss.moves["call"] = {"id": "call", "intent": "summon", "enemy": "dragon"}
	boss.kind = "legendary"
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_weighted_pattern_needs_positive_weights() -> void:
	var c := _ok()
	var boss: EnemyDef = c.enemies["fx_boss"]
	boss.pattern = {"kind": "weighted", "moves": [{"move": "crush", "weight": 0}]}
	assert_int(ContentValidator.validate(c).size()).is_equal(1)


func test_relic_hooks_and_effects() -> void:
	var c := _ok()
	var relic: RelicDef = c.relics["fx_lantern"]
	relic.hooks = {"on_sneeze": [{"op": "block", "amount": 1}], "on_fight_end": [{"op": "teleport"}]}
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_class_references() -> void:
	var c := _ok()
	var klass: ClassDef = c.classes["fx_class"]
	klass.starting_deck = ["fx_strike", "missing_card"]
	klass.relic = "missing_relic"
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_biome_references_and_patterns() -> void:
	var c := _ok()
	var biome: BiomeDef = c.biomes["fx_biome"]
	biome.encounters = [{"floors": [1, 9], "groups": [["fx_rat", "ghoul"]]}]
	biome.boss = ["nobody"] as Array[String]
	biome.node_patterns = [["fight", "fight", "casino"]]
	assert_int(ContentValidator.validate(c).size()).is_equal(3)


func test_empty_collections_are_errors() -> void:
	var c := _ok()
	var klass: ClassDef = c.classes["fx_class"]
	klass.starting_deck = [] as Array[String]
	var biome: BiomeDef = c.biomes["fx_biome"]
	biome.node_patterns = []
	biome.elites = []
	assert_int(ContentValidator.validate(c).size()).is_equal(3)


func test_event_rules() -> void:
	var c := _ok()
	var ev: EventDef = c.events["fx_well"]
	ev.choices = [
		{"id": "a", "text": "event.fx_well.drink", "effects": [{"op": "teleport"}]},
		{"id": "b", "text": "event.fx_well.leave", "effects": [{"op": "add_card", "card": "nope"}, {"op": "stat", "stat": "luck", "amount": 1}]},
		{"id": "", "text": "missing.key", "effects": [{"op": "relic", "relic": "nope"}]},
		{"id": "d", "text": "event.fx_well.leave", "effects": []},
	]
	assert_int(ContentValidator.validate(c).size()).is_equal(7)


func test_event_biome_must_exist_and_amounts_must_be_numbers() -> void:
	var c := _ok()
	var ev: EventDef = c.events["fx_well"]
	ev.biome = "moon"
	ev.choices[0]["effects"] = [{"op": "heal", "amount": "lots"}]
	assert_int(ContentValidator.validate(c).size()).is_equal(2)


func test_upgrade_rules() -> void:
	var c := _ok()
	var up: UpgradeDef = c.upgrades["fx_might"]
	up.group = "cosmic"
	up.effect = {"kind": "teleport", "amount": 1}
	up.max_level = 0
	up.base_cost = 0.0
	assert_int(ContentValidator.validate(c).size()).is_equal(4)


func test_upgrade_stat_effect_needs_a_known_stat() -> void:
	var c := _ok()
	var up: UpgradeDef = c.upgrades["fx_might"]
	up.effect = {"kind": "stat", "stat": "luck", "amount": "lots"}
	assert_int(ContentValidator.validate(c).size()).is_equal(2)
