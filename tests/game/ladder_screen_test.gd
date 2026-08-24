extends GdUnitTestSuite

const TMP := "user://test_saves/ladder_screen_test.json"


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


func _screen(g: GameRoot) -> LadderScreen:
	var s: LadderScreen = auto_free(LadderScreen.new())
	add_child(s)
	s.size = Vector2(480.0, 520.0)
	s.bind(g)
	return s


func test_the_tower_has_one_row_per_floor_of_the_biome() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_int(s._rows.size()).is_equal(g.campaign.biome().last_floor)
	assert_int(s._rows[0].floor_number).is_equal(1)
	assert_int(s._rows[9].floor_number).is_equal(10)


func test_the_founder_stands_on_the_top_row() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_float(s._rows[0].output_per_hour).is_greater(0.0)
	assert_bool(s._rows[0].is_waypoint).is_true()
	assert_float(s._rows[1].output_per_hour).is_equal(0.0)


func test_the_header_shows_soul_rate_and_reach() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._rate.text).is_equal("52/h")
	assert_str(s._reach.text).is_equal("1")
	assert_str(s._soul.text).is_equal(Num.short(g.displayed_soul()))


func test_soul_ticking_updates_the_header_without_rebinding_the_tower() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var before := s._rows[0].saturation
	g.clock = func() -> int: return 1000 + 3600
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	assert_str(s._soul.text).is_equal("52")
	assert_float(s._rows[0].saturation).is_equal(before)


func test_placing_an_echo_refreshes_the_tower() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	g.campaign.soul = 500.0
	var r := g.create_echo(g.campaign.ladder.ghosts[0].id, 1)
	assert_bool(r["ok"]).is_true()
	await await_idle_frame()
	assert_int(s._rows[0]._marks.get_child_count()).is_equal(2)


func test_binding_twice_does_not_connect_the_signals_twice() -> void:
	var g := _game()
	var s := _screen(g)
	s.bind(g)
	await await_idle_frame()
	assert_int(g.ladder_changed.get_connections().size()).is_equal(1)
	assert_int(s._rows.size()).is_equal(g.campaign.biome().last_floor)


func test_the_premise_line_says_plainly_what_a_ghost_is() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var founder := g.campaign.ladder.ghosts[0]
	assert_str(s._premise.text).contains(founder.name)
	assert_str(s._premise.text).contains("Floor 1")
	assert_str(s._premise.text).contains("Soul")


func test_the_premise_follows_the_deepest_ghost() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	TestFixtures.end_at_exit(g.campaign, 3, "watch", 1000)
	s.refresh()
	await await_idle_frame()
	assert_str(s._premise.text).contains("Floor 3")


func test_the_header_numbers_explain_themselves_on_hover() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str((s._soul.get_parent() as Control).tooltip_text).is_equal(g.text("ui.tip.soul"))
	assert_str((s._rate.get_parent() as Control).tooltip_text).is_equal(g.text("ui.tip.per_hour"))
	assert_str((s._reach.get_parent() as Control).tooltip_text).is_equal(g.text("ui.tip.reach"))
	assert_str((s._soul.get_parent() as Control).tooltip_text).is_not_equal("ui.tip.soul")


func test_the_hint_says_to_wait_when_nothing_is_affordable() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._hint.text).is_equal(g.text("ui.hint.wait"))


func test_the_hint_says_to_spend_once_an_upgrade_is_affordable() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	g.campaign.soul = 1000.0
	s.refresh()
	await await_idle_frame()
	assert_str(s._hint.text).is_equal(g.text("ui.hint.spend"))


func test_the_hint_flips_as_soul_accrues_without_a_rebind() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._hint.text).is_equal(g.text("ui.hint.wait"))
	# 20 Soul buys vigor; an hour of the Founder earns 52.
	g.clock = func() -> int: return 1000 + 3600
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	assert_str(s._hint.text).is_equal(g.text("ui.hint.spend"))


func test_the_ladder_offers_a_descent() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._descend.text).is_equal(g.text("ui.descend"))
	assert_bool(s._descend.disabled).is_false()
	s._descend.emit_signal("pressed")
	await await_idle_frame()
	assert_object(g.campaign.run).is_not_null()
	assert_int(g.campaign.run.floor).is_equal(1)


func test_the_descent_button_is_unavailable_while_a_run_is_live() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	g.start_run(1)
	s.refresh()
	await await_idle_frame()
	assert_bool(s._descend.disabled).is_true()
