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


func test_a_tablet_shows_the_name_and_the_cost_and_tells_the_rest_on_hover() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var plaque: UpgradePlaque = s.rows["vigor"]
	assert_str(plaque._name.text).is_equal(g.text("upgrade.vigor.name"))
	assert_str(plaque._button.text).is_equal("20")
	assert_str(plaque.tooltip_text).contains(g.text("upgrade.vigor.text"))


func test_rows_are_disabled_while_the_player_cannot_afford_them() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_bool((s.rows["vigor"] as UpgradePlaque)._button.disabled).is_true()
	g.campaign.soul = 1000.0
	s.refresh()
	assert_bool((s.rows["vigor"] as UpgradePlaque)._button.disabled).is_false()


func test_pressing_buy_spends_soul_and_raises_the_level() -> void:
	var g := _game()
	var s := _screen(g)
	g.campaign.soul = 1000.0
	s.refresh()
	await await_idle_frame()
	(s.rows["vigor"] as UpgradePlaque)._button.emit_signal("pressed")
	await await_idle_frame()
	assert_int(g.campaign.upgrades.level("vigor")).is_equal(1)
	assert_float(g.campaign.soul).is_equal_approx(980.0, 0.001)
	# Levels are pips now, not text: a filled row says "nearly maxed" at a
	# glance where "1/3" has to be read.
	assert_int((s.rows["vigor"] as UpgradePlaque)._level).is_equal(1)
	assert_int((s.rows["vigor"] as UpgradePlaque)._max_level).is_equal(3)


func test_the_next_level_costs_more() -> void:
	var g := _game()
	var s := _screen(g)
	g.campaign.soul = 1000.0
	s.refresh()
	(s.rows["vigor"] as UpgradePlaque)._button.emit_signal("pressed")
	await await_idle_frame()
	assert_str((s.rows["vigor"] as UpgradePlaque)._button.text).is_equal("32")


func test_a_maxed_upgrade_says_so_and_cannot_be_bought() -> void:
	var g := _game()
	var s := _screen(g)
	g.campaign.soul = 100000.0
	g.buy_upgrade("resolve")
	s.refresh()
	await await_idle_frame()
	var row: UpgradePlaque = s.rows["resolve"]
	assert_str(row._button.text).is_equal(g.text("ui.maxed"))
	assert_bool(row._button.disabled).is_true()
	assert_int(row._level).is_equal(1)
	assert_int(row._max_level).is_equal(1)


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
	assert_bool((s.rows["vigor"] as UpgradePlaque)._button.disabled).is_false()
	(s.rows["vigor"] as UpgradePlaque)._button.emit_signal("pressed")
	await await_idle_frame()
	# 5 Soul left: nothing else is affordable.
	assert_bool((s.rows["might"] as UpgradePlaque)._button.disabled).is_true()


## The Guild is a wall you look at, not a list you page through. Ten upgrades
## stacked as full-width rows in a scroll container is a settings menu no
## matter what the rows are made of -- carving them did not change that,
## because the problem was the list, not the row.
func test_every_upgrade_in_the_game_is_visible_without_scrolling() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	await await_idle_frame()
	assert_int(s.rows.size()).is_equal(g.content.upgrades.size())
	for id in s.rows:
		var plaque: UpgradePlaque = s.rows[id]
		assert_bool(plaque.is_visible_in_tree()) \
			.override_failure_message("%s is not on screen" % id).is_true()
	# Two group walls, and every tablet sits in one of them.
	for id in s.rows:
		var plaque: UpgradePlaque = s.rows[id]
		assert_object(plaque.get_parent() as HFlowContainer) \
			.override_failure_message("%s is still in a column" % id).is_not_null()


func test_the_wall_holds_a_whole_group_abreast() -> void:
	# If the wall is narrower than a group the flow wraps, which puts the
	# second group below the fold and the screen scrolls again.
	assert_float(GuildScreen.WALL_WIDTH).is_greater_equal(
		UpgradePlaque.COLUMNS * UpgradePlaque.PLAQUE_SIZE.x)


func test_both_groups_of_tablets_fit_the_window_without_scrolling() -> void:
	# Two group plates, each a header plus one row of tablets, has to clear
	# 720 minus the nav bar and the wallet above it.
	# In 640x360 units now, and measured against what the shell leaves: the
	# nav bar and the wallet above the body take roughly 70 of the 360.
	var group_height := 15.0 + UpgradePlaque.PLAQUE_SIZE.y + 30.0
	assert_float(2.0 * group_height).is_less(360.0 - 70.0)


## The tablets are a fixed height so the wall stays a wall, which means the
## description has a fixed number of lines to live in. Driven over every
## upgrade in the game, because it is always the wordiest one that breaks.
## The description moved off the tablet's face and onto its tooltip, so what
## has to be pinned is that every tablet still explains itself -- a wall of
## names with no way to find out what they do is worse than the list was.
func test_every_tablet_explains_itself_on_hover() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	for id in s.rows:
		var plaque: UpgradePlaque = s.rows[id]
		var def: UpgradeDef = g.content.upgrades[id]
		assert_str(plaque.tooltip_text) 			.override_failure_message("%s has no tooltip" % id) 			.contains(g.text(def.text_key))
		assert_int(plaque.mouse_filter).is_not_equal(Control.MOUSE_FILTER_IGNORE)
