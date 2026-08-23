extends GdUnitTestSuite

const ROOT := "res://tests/fixtures/content_ok"


func test_loads_all_types_without_errors() -> void:
	var c := Content.load_from(ROOT)
	assert_array(c.load_errors).is_empty()
	assert_int(c.cards.size()).is_equal(3)
	assert_int(c.enemies.size()).is_equal(2)
	assert_int(c.relics.size()).is_equal(1)
	assert_int(c.classes.size()).is_equal(1)
	assert_int(c.biomes.size()).is_equal(1)
	assert_int(c.events.size()).is_equal(1)


func test_card_def_fields() -> void:
	var c := Content.load_from(ROOT)
	var strike: CardDef = c.cards["fx_strike"]
	assert_str(strike.type).is_equal("attack")
	assert_int(strike.cost).is_equal(1)
	assert_str(strike.target).is_equal("enemy")
	assert_array(strike.tags).contains(["bone"])
	assert_int(strike.effects.size()).is_equal(1)
	assert_str(strike.effects[0]["op"]).is_equal("damage")
	assert_int(strike.effects_for(true)[0]["amount"]).is_equal(9)
	assert_int(strike.cost_for(true)).is_equal(1)
	assert_float(strike.ai_value).is_equal(6.0)


func test_x_cost_and_upgrade_cost() -> void:
	var c := Content.load_from(ROOT)
	var surge: CardDef = c.cards["fx_surge"]
	assert_int(surge.cost).is_equal(-1)
	assert_int(surge.cost_for(false)).is_equal(-1)
	assert_int(surge.cost_for(true)).is_equal(0)
	assert_bool(surge.has_keyword("exhaust")).is_true()
	assert_array(surge.effects_for(true)).is_equal(surge.effects)


func test_enemy_def_fields() -> void:
	var c := Content.load_from(ROOT)
	var rat: EnemyDef = c.enemies["fx_rat"]
	assert_int(rat.hp).is_equal(14)
	assert_str(rat.kind).is_equal("regular")
	assert_bool(rat.moves.has("bite")).is_true()
	assert_int(rat.moves["bite"]["damage"]).is_equal(5)
	assert_str(rat.pattern["kind"]).is_equal("sequence")
	var boss: EnemyDef = c.enemies["fx_boss"]
	assert_str(boss.kind).is_equal("boss")
	assert_bool(boss.pattern["no_repeat"]).is_true()


func test_relic_class_biome_fields() -> void:
	var c := Content.load_from(ROOT)
	var relic: RelicDef = c.relics["fx_lantern"]
	assert_bool(relic.hooks.has("on_fight_start")).is_true()
	var klass: ClassDef = c.classes["fx_class"]
	assert_int(klass.base_hp).is_equal(70)
	assert_array(klass.starting_deck).has_size(3)
	assert_str(klass.relic).is_equal("fx_lantern")
	var biome: BiomeDef = c.biomes["fx_biome"]
	assert_int(biome.first_floor).is_equal(1)
	assert_int(biome.last_floor).is_equal(10)
	assert_int(biome.encounters.size()).is_equal(1)
	assert_array(biome.boss).is_equal(["fx_boss"])
	assert_int(biome.node_patterns.size()).is_equal(2)


func test_affinity_balance_and_strings() -> void:
	var c := Content.load_from(ROOT)
	assert_float(c.affinity["poison"]["flesh"]).is_equal(1.5)
	assert_float(c.balance["enemy_hp_growth"]).is_equal(1.06)
	assert_int(c.balance["turn_cap"]).is_equal(30)
	assert_str(c.text("card.fx_strike.name")).is_equal("Strike")
	assert_str(c.text("card.fx_surge.text")).is_equal("Draw X cards. Exhaust.")
	assert_str(c.text("missing.key")).is_equal("missing.key")


func test_missing_root_reports_errors() -> void:
	var c := Content.load_from("res://tests/fixtures/does_not_exist")
	assert_array(c.load_errors).is_not_empty()


func test_duplicate_ids_are_load_errors() -> void:
	var c := Content.load_from("res://tests/fixtures/content_dup")
	var found := false
	for e in c.load_errors:
		if String(e).begins_with("duplicate id 'fx_dup'"):
			found = true
	assert_bool(found).is_true()
	assert_int(c.cards.size()).is_equal(1)


func test_event_def_fields() -> void:
	var c := Content.load_from(ROOT)
	var ev: EventDef = c.events["fx_well"]
	assert_str(ev.name_key).is_equal("event.fx_well.name")
	assert_str(ev.biome).is_equal("fx_biome")
	assert_int(ev.choices.size()).is_equal(2)
	assert_str(ev.choices[0]["id"]).is_equal("drink")
	assert_str(ev.choices[0]["text"]).is_equal("event.fx_well.drink")
	assert_int(ev.choices[0]["effects"][0]["amount"]).is_equal(10)
	assert_array(ev.choices[1]["effects"]).is_empty()
