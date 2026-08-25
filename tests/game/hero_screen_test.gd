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


## The deck is shown as card faces now rather than as "5x Strike". Grouping
## is unchanged -- a thirty-card deck must still read as a dozen entries --
## but the entries are cards, because this is the screen where a player looks
## at what they have built.
func test_the_deck_shows_one_card_face_per_group() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	# The sexton starting deck is 5x strike, 4x brace, 1x last_rites: three
	# groups, not ten cards.
	assert_int(s._deck.get_child_count()).is_equal(3)
	var names: Array[String] = []
	for slot in s._deck.get_children():
		var card := (slot as Control).get_child(0) as CardView
		assert_object(card).override_failure_message("a deck slot holds no card").is_not_null()
		names.append(card._name.text)
	assert_array(names).contains([g.text("card.strike.name")])


func test_a_repeated_card_carries_its_count() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var badges: Array[String] = []
	for slot in s._deck.get_children():
		for child in (slot as Control).get_children():
			if child is Label:
				badges.append((child as Label).text)
	# Five Strikes and four Braces are badged; the lone Last Rites is not.
	assert_array(badges).contains(["x5", "x4"])
	assert_array(badges).not_contains(["x1"])


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
	for slot in s._deck.get_children():
		var card := (slot as Control).get_child(0) as CardView
		if card != null and card._name.text.contains(marker):
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


func test_relics_are_shown_as_objects_not_as_a_comma_list() -> void:
	# A relic rendered as a word in a comma-separated list has no more weight
	# than a footnote; the player is supposed to feel they are carrying it.
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_int(g.campaign.hero.relics.size()).is_greater(0)
	assert_int(s._relic_row.get_child_count()).is_equal(g.campaign.hero.relics.size())
	var first := s._relic_row.get_child(0) as Control
	assert_str(first.tooltip_text).is_not_empty()
