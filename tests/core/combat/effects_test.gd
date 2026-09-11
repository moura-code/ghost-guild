extends GdUnitTestSuite

const HERO := {"kind": "hero"}


func _ctx(target: int = 0, card_target: String = "enemy", tags: Array = [], is_attack: bool = true, x: int = 0) -> Dictionary:
	return {"target": target, "card_target": card_target, "tags": tags, "is_attack": is_attack, "x": x}


func _card_effects(id: String, upgraded: bool = false) -> Array:
	var def: CardDef = TestFixtures.content().cards[id]
	return def.effects_for(upgraded)


func test_attack_damage_scales_with_might_and_buff() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.stats["might"] = 2
	s.statuses["might_buff"] = 1
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx(0, "enemy", ["bone"]))
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 9)
	var ev: Dictionary = TestFixtures.events_of(s, "damage")[0]
	assert_int(ev["amount"]).is_equal(9)
	assert_int(ev["blocked"]).is_equal(0)


func test_multi_hit_and_upgrade() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	EffectResolver.resolve(s, _card_effects("reaping", true), HERO, _ctx())
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 15)
	assert_array(TestFixtures.events_of(s, "damage")).has_size(3)


func test_weak_hero_deals_less_vulnerable_enemy_takes_more() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	s.statuses["weak"] = 1
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 4)
	s.statuses.erase("weak")
	s.enemies[0].statuses["vulnerable"] = 1
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 4 - 9)


func test_skill_damage_ignores_might_and_weak() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	s.stats["might"] = 5
	s.statuses["weak"] = 1
	EffectResolver.resolve(s, _card_effects("ashes"), HERO, _ctx(0, "all_enemies", ["ember"], false))
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 3)
	assert_int(s.enemies[0].status("burn")).is_equal(2)


func test_holy_affinity_against_undead_and_not_flesh() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "crypt_spider"])
	EffectResolver.resolve(s, _card_effects("hallowed_strike"), HERO, _ctx(0, "enemy", ["bone", "holy"]))
	assert_bool(s.enemies[0].alive).is_false()
	assert_int(s.enemies[0].hp).is_equal(0)
	assert_array(TestFixtures.events_of(s, "enemy_died")).has_size(1)
	EffectResolver.resolve(s, _card_effects("hallowed_strike"), HERO, _ctx(1, "enemy", ["bone", "holy"]))
	assert_int(s.enemies[1].hp).is_equal(18 - 12)


func test_poison_stacks_use_affinity_and_wit() -> void:
	var s := TestFixtures.bare_state(["crypt_spider", "bone_rat"])
	s.stats["wit"] = 2
	EffectResolver.resolve(s, _card_effects("plague_vial"), HERO, _ctx(0, "enemy", ["poison"], false))
	assert_int(s.enemies[0].status("poison")).is_equal(9)
	EffectResolver.resolve(s, _card_effects("plague_vial"), HERO, _ctx(1, "enemy", ["poison"], false))
	assert_int(s.enemies[1].status("poison")).is_equal(6)


func test_block_scales_with_wit_and_absorbs() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.stats["wit"] = 2
	EffectResolver.resolve(s, _card_effects("brace"), HERO, _ctx(-1, "self", ["shield"], false))
	assert_int(s.hero_block).is_equal(7)
	EffectResolver.hit_hero(s, 10, 0, true)
	assert_int(s.hero_block).is_equal(0)
	assert_int(s.hero_hp).is_equal(67)
	var ev: Dictionary = TestFixtures.events_of(s, "damage")[0]
	assert_int(ev["blocked"]).is_equal(7)
	assert_int(ev["amount"]).is_equal(3)


func test_enemy_block_absorbs_hero_damage() -> void:
	var s := TestFixtures.bare_state(["shambler"])
	s.enemies[0].block = 4
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.enemies[0].block).is_equal(0)
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 2)


func test_enemy_weak_and_hero_vulnerable() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].statuses["weak"] = 1
	EffectResolver.hit_hero(s, 10, 0, true)
	assert_int(s.hero_hp).is_equal(63)
	s.enemies[0].statuses.erase("weak")
	s.statuses["vulnerable"] = 1
	EffectResolver.hit_hero(s, 10, 0, true)
	assert_int(s.hero_hp).is_equal(48)


func test_thorns_both_ways_ignore_block() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].statuses["thorns"] = 3
	s.hero_block = 10
	EffectResolver.resolve(s, _card_effects("strike"), HERO, _ctx())
	assert_int(s.hero_hp).is_equal(67)
	assert_int(s.hero_block).is_equal(10)
	s.statuses["thorns"] = 2
	s.enemies[0].block = 5
	EffectResolver.hit_hero(s, 1, 0, true)
	assert_int(s.enemies[0].hp).is_equal(s.enemies[0].max_hp - 6 - 2)
	assert_int(s.enemies[0].block).is_equal(5)


func test_all_enemies_targeting_and_self_override() -> void:
	var s := TestFixtures.bare_state(["bone_rat", "bone_rat"])
	EffectResolver.resolve(s, _card_effects("censer_smoke"), HERO, _ctx(-1, "all_enemies", ["shield"], false))
	assert_int(s.hero_block).is_equal(4)
	assert_int(s.enemies[0].status("weak")).is_equal(1)
	assert_int(s.enemies[1].status("weak")).is_equal(1)
	EffectResolver.resolve(s, _card_effects("requiem"), HERO, _ctx(-1, "all_enemies", ["bone"]))
	assert_bool(s.all_enemies_dead()).is_true()


func test_self_targeted_status_lands_on_hero() -> void:
	var s := TestFixtures.bare_state()
	EffectResolver.resolve(s, _card_effects("vigil"), HERO, _ctx(-1, "self", ["shield"], false))
	assert_int(s.hero_status("vigil")).is_equal(3)
	EffectResolver.resolve(s, _card_effects("sharpen_spade"), HERO, _ctx(-1, "self", ["bone"], false))
	assert_int(s.might()).is_equal(2)


func test_draw_energy_heal_and_x() -> void:
	var s := TestFixtures.bare_state()
	TestFixtures.fill_draw(s, ["strike", "strike", "strike", "strike"])
	s.hero_hp = 60
	EffectResolver.resolve(s, _card_effects("lantern_oil"), HERO, _ctx(-1, "none", ["draw"], false))
	assert_int(s.energy).is_equal(4)
	assert_array(s.hand).has_size(1)
	EffectResolver.resolve(s, [{"op": "draw", "amount": "x"}], HERO, _ctx(-1, "none", [], false, 2))
	assert_array(s.hand).has_size(3)
	EffectResolver.resolve(s, _card_effects("second_wind", true), HERO, _ctx(-1, "self", [], false))
	assert_int(s.hero_hp).is_equal(69)
	EffectResolver.resolve(s, _card_effects("second_wind"), HERO, _ctx(-1, "self", [], false))
	assert_int(s.hero_hp).is_equal(70)


func test_exhaust_self_add_card_and_coin() -> void:
	var s := TestFixtures.bare_state()
	var ctx := _ctx(-1, "none", [], false)
	EffectResolver.resolve(s, [{"op": "exhaust_self"}, {"op": "add_card", "card": "bone_shard", "where": "hand"}, {"op": "add_card", "card": "strike", "where": "draw"}, {"op": "add_card", "card": "brace", "where": "discard"}, {"op": "coin", "amount": 10}], HERO, ctx)
	assert_bool(ctx["exhaust"]).is_true()
	assert_str(s.hand[0].def_id).is_equal("bone_shard")
	assert_str(s.draw_pile[0].def_id).is_equal("strike")
	assert_str(s.discard_pile[0].def_id).is_equal("brace")
	assert_int(TestFixtures.events_of(s, "coin")[0]["amount"]).is_equal(10)


func test_direct_damage_and_kill() -> void:
	var s := TestFixtures.bare_state(["bone_rat"])
	s.enemies[0].block = 50
	EffectResolver.direct_damage_enemy(s, 0, 18, "poison")
	assert_bool(s.enemies[0].alive).is_false()
	s.hero_block = 50
	EffectResolver.direct_damage_hero(s, 70, "burn")
	assert_int(s.hero_hp).is_equal(0)
