extends GdUnitTestSuite

const TMP := "user://test_saves/guild_screen_test.json"


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


func _screen(g: GameRoot) -> GuildScreen:
	var s: GuildScreen = auto_free(GuildScreen.new())
	add_child(s)
	s.size = Vector2(480.0, 520.0)
	s.bind(g)
	return s


func test_every_upgrade_in_content_gets_a_row() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_int(s.rows.size()).is_equal(g.content.upgrades.size())
	assert_bool(s.rows.has("might")).is_true()
	assert_bool(s.rows.has("ghost_spawn")).is_true()


func test_a_row_shows_the_name_the_text_and_the_cost() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var row: UpgradeRow = s.rows["vigor"]
	assert_str(row._name.text).is_equal(g.text("upgrade.vigor.name"))
	assert_str(row._text.text).is_equal(g.text("upgrade.vigor.text"))
	assert_str(row._button.text).is_equal("20")


func test_rows_are_disabled_while_the_player_cannot_afford_them() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_bool((s.rows["vigor"] as UpgradeRow)._button.disabled).is_true()
	g.campaign.soul = 1000.0
	s.refresh()
	assert_bool((s.rows["vigor"] as UpgradeRow)._button.disabled).is_false()


func test_pressing_buy_spends_soul_and_raises_the_level() -> void:
	var g := _game()
	var s := _screen(g)
	g.campaign.soul = 1000.0
	s.refresh()
	await await_idle_frame()
	(s.rows["vigor"] as UpgradeRow)._button.emit_signal("pressed")
	await await_idle_frame()
	assert_int(g.campaign.upgrades.level("vigor")).is_equal(1)
	assert_float(g.campaign.soul).is_equal_approx(980.0, 0.001)
	assert_str((s.rows["vigor"] as UpgradeRow)._pips.text).is_equal("1/3")


func test_the_next_level_costs_more() -> void:
	var g := _game()
	var s := _screen(g)
	g.campaign.soul = 1000.0
	s.refresh()
	(s.rows["vigor"] as UpgradeRow)._button.emit_signal("pressed")
	await await_idle_frame()
	assert_str((s.rows["vigor"] as UpgradeRow)._button.text).is_equal("32")


func test_a_maxed_upgrade_says_so_and_cannot_be_bought() -> void:
	var g := _game()
	var s := _screen(g)
	g.campaign.soul = 100000.0
	g.buy_upgrade("resolve")
	s.refresh()
	await await_idle_frame()
	var row: UpgradeRow = s.rows["resolve"]
	assert_str(row._button.text).is_equal(g.text("ui.maxed"))
	assert_bool(row._button.disabled).is_true()
	assert_str(row._pips.text).is_equal("1/1")


func test_upgrades_are_grouped_hero_then_ghosts() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_int(s._groups.size()).is_equal(2)
	assert_str(s._group_order[0]).is_equal("hero")
	assert_str(s._group_order[1]).is_equal("ghosts")


func test_buying_refreshes_affordability_across_every_row() -> void:
	var g := _game()
	var s := _screen(g)
	g.campaign.soul = 25.0
	s.refresh()
	assert_bool((s.rows["vigor"] as UpgradeRow)._button.disabled).is_false()
	(s.rows["vigor"] as UpgradeRow)._button.emit_signal("pressed")
	await await_idle_frame()
	# 5 Soul left: nothing else is affordable.
	assert_bool((s.rows["might"] as UpgradeRow)._button.disabled).is_true()
