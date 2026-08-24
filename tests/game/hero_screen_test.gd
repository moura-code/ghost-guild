extends GdUnitTestSuite

const TMP := "user://test_saves/hero_screen_test.json"


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 4
	return g


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _screen(g: GameRoot) -> HeroScreen:
	var s: HeroScreen = auto_free(HeroScreen.new())
	add_child(s)
	s.size = Vector2(480.0, 520.0)
	s.bind(g)
	return s


func test_it_names_the_hero_and_their_class() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._name.text).is_equal(g.campaign.hero.name)
	assert_str(s._class.text).is_equal(g.text("class.sexton.name"))


func test_vitals_show_hp_resolve_and_camp() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var hero := g.campaign.hero
	assert_str(s._vitals.text).contains("%d/%d" % [hero.hp, hero.max_hp])
	assert_str(s._vitals.text).contains("%d/%d" % [hero.resolve, hero.max_resolve])
	assert_str(s._vitals.text).contains("%s %d" % [g.text("ui.camp"), hero.camp])


func test_the_four_stats_each_get_a_row() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	for stat in ["might", "wit", "vigor", "focus"]:
		assert_bool(s._stats.has(stat)).is_true()
		assert_str((s._stats[stat] as Label).text).is_equal(str(g.campaign.hero.stats[stat]))


func test_the_deck_lists_every_card_grouped_with_a_count() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	# The sexton starting deck is 5x strike, 4x brace, 1x last_rites: three
	# groups, not ten lines.
	assert_int(s._deck.get_child_count()).is_equal(3)
	var expected := "%d× %s" % [5, g.text("card.strike.name")]
	var found := false
	for child in s._deck.get_children():
		if (child as Label).text == expected:
			found = true
	assert_bool(found).is_true()


func test_buying_a_stat_upgrade_updates_the_hero_screen() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var before := int(g.campaign.hero.stats["vigor"])
	g.campaign.soul = 1000.0
	g.buy_upgrade("vigor")
	await await_idle_frame()
	assert_int(int(g.campaign.hero.stats["vigor"])).is_equal(before + 1)
	assert_str((s._stats["vigor"] as Label).text).is_equal(str(before + 1))


func test_upgraded_cards_are_marked() -> void:
	var g := _game()
	var hero := g.campaign.hero
	hero.upgrade_card(hero.deck[0].uid)
	var s := _screen(g)
	await await_idle_frame()
	var marker := g.text("ui.upgraded")
	var found := false
	for child in s._deck.get_children():
		if (child as Label).text.contains(marker):
			found = true
	assert_bool(found).is_true()


func test_a_hero_with_no_relics_says_none() -> void:
	var g := _game()
	g.campaign.hero.relics.clear()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._relics.text).is_equal(g.text("ui.none"))


func test_binding_twice_does_not_connect_the_signals_twice() -> void:
	var g := _game()
	var s := _screen(g)
	s.bind(g)
	await await_idle_frame()
	assert_int(g.hero_changed.get_connections().size()).is_equal(1)
