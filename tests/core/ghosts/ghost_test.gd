extends GdUnitTestSuite


func _outcome(kind: String, floor: int, killer: String = "", cause: String = "") -> Dictionary:
	return {"kind": kind, "floor": floor, "killer": killer, "cause": cause, "coin": 0, "soul_from_coin": 0.0, "soul": 0.0, "hero_hp": 0, "stat_bonus": {"wit": 1}}


func test_ghost_from_a_watch() -> void:
	var hero := TestFixtures.hero("Maren")
	hero.upgrade_card(1)
	hero.relics.append("bone_charm")
	var measured := {"fights": 2, "wins": 2, "win_rate": 1.0, "avg_turns": 4.0}
	var g := Ghost.from_run(hero, _outcome("watch", 4), measured, 1000)
	assert_str(g.name).is_equal("Maren")
	assert_str(g.class_id).is_equal("sexton")
	assert_int(g.floor).is_equal(4)
	assert_str(g.kind).is_equal("true")
	assert_str(g.cause).is_equal("watch")
	assert_bool(g.prepared).is_true()
	assert_bool(g.restless).is_false()
	assert_int(g.created_at).is_equal(1000)
	assert_array(g.deck).has_size(10)
	assert_bool(g.deck[0].upgraded).is_true()
	assert_array(g.relics).is_equal(["sextons_lantern", "bone_charm"])
	assert_int(g.stats["wit"]).is_equal(1)
	assert_int(g.max_hp).is_equal(70)
	assert_dict(g.measured).is_equal(measured)
	assert_str(g.epitaph_key).is_equal("epitaph.watch")
	assert_str(g.epitaph(TestFixtures.content())).is_equal("Maren took the watch on Floor 4")
	hero.deck.clear()
	assert_array(g.deck).has_size(10)


func test_ghost_from_a_death_names_the_killer() -> void:
	var g := Ghost.from_run(TestFixtures.hero("Osk"), _outcome("death", 7, "ossuary_warden", "hero_died"), {"fights": 3, "wins": 2, "win_rate": 0.6667, "avg_turns": 5.0}, 5)
	assert_bool(g.restless).is_true()
	assert_bool(g.prepared).is_false()
	assert_str(g.killer).is_equal("ossuary_warden")
	assert_str(g.epitaph(TestFixtures.content())).is_equal("Osk fell to Ossuary Warden on Floor 7")
	var stalled := Ghost.from_run(TestFixtures.hero("Edda"), _outcome("death", 3, "", "turn_cap"), {"fights": 1, "wins": 0, "win_rate": 0.0, "avg_turns": 0.0}, 5)
	assert_str(stalled.epitaph_key).is_equal("epitaph.death_unknown")
	assert_str(stalled.epitaph(TestFixtures.content())).is_equal("Edda fell on Floor 3")


func test_founder() -> void:
	var g := Ghost.founder(TestFixtures.content(), 42)
	assert_str(g.name).is_equal("Ilse")
	assert_int(g.floor).is_equal(1)
	assert_str(g.cause).is_equal("founder")
	assert_bool(g.fixed_strength).is_true()
	assert_float(g.strength).is_equal(40.0)
	assert_array(g.deck).has_size(10)
	assert_str(g.epitaph(TestFixtures.content())).is_equal("Ilse founded the guild and holds Floor 1")
	var snap := g.snapshot()
	assert_int(snap.hp).is_equal(70)
	assert_array(snap.deck).has_size(10)


func test_echo_clone_links_to_its_source() -> void:
	var g := Ghost.from_run(TestFixtures.hero("Wren"), _outcome("watch", 6), {"fights": 1, "wins": 1, "win_rate": 1.0, "avg_turns": 3.0}, 1)
	g.id = 9
	g.strength = 30.0
	var e := g.clone_as_echo(2, 77)
	assert_str(e.kind).is_equal("echo")
	assert_int(e.source_id).is_equal(9)
	assert_int(e.floor).is_equal(2)
	assert_int(e.created_at).is_equal(77)
	assert_bool(e.prepared).is_false()
	assert_bool(e.restless).is_false()
	assert_array(e.deck).has_size(10)
	assert_int(e.id).is_equal(0)
	g.restless = true
	var r := g.clone_as_echo(1, 78)
	assert_bool(r.restless).is_true()
	assert_bool(r.prepared).is_false()


func test_json_round_trip() -> void:
	var hero := TestFixtures.hero("Tobiah")
	hero.upgrade_card(2)
	var g := Ghost.from_run(hero, _outcome("death", 5, "bone_rat", "hero_died"), {"fights": 2, "wins": 1, "win_rate": 0.5, "avg_turns": 6.0}, 123)
	g.id = 3
	g.strength = 12.5
	var back := Ghost.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert_int(back.id).is_equal(3)
	assert_str(back.name).is_equal("Tobiah")
	assert_int(back.floor).is_equal(5)
	assert_str(back.kind).is_equal("true")
	assert_str(back.killer).is_equal("bone_rat")
	assert_bool(back.restless).is_true()
	assert_int(back.created_at).is_equal(123)
	assert_float(back.strength).is_equal(12.5)
	assert_bool(back.deck[1].upgraded).is_true()
	assert_int(back.deck[9].uid).is_equal(10)
	assert_int(back.measured["fights"]).is_equal(2)
	assert_float(back.measured["win_rate"]).is_equal(0.5)
	assert_int(back.stats["wit"]).is_equal(1)
	assert_str(back.epitaph_key).is_equal("epitaph.death")
