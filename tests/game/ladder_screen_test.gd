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
