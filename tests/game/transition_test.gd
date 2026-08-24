extends GdUnitTestSuite

const TMP := "user://test_saves/transition_test.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 2
	return g


func _main(g: GameRoot) -> MainScreen:
	var m: MainScreen = auto_free(MainScreen.new())
	m.bind(g)
	add_child(m)
	m.size = Vector2(1280.0, 720.0)
	return m


func test_a_wipe_covers_the_screen_and_reports_its_midpoint() -> void:
	var t: Transition = auto_free(Transition.new())
	add_child(t)
	t.size = Vector2(1280.0, 720.0)
	await await_idle_frame()
	assert_bool(t.visible).is_false()
	var hits := [0]
	t.midpoint.connect(func() -> void: hits[0] += 1)
	t.play(0.12)
	assert_bool(t.visible).is_true()
	assert_bool(t.is_playing()).is_true()
	await get_tree().create_timer(0.25).timeout
	assert_int(hits[0]).is_equal(1)
	assert_bool(t.visible).is_false()
	assert_float(t.modulate.a).is_equal_approx(0.0, 0.01)


func test_outside_the_tree_it_reports_the_midpoint_immediately() -> void:
	var t: Transition = auto_free(Transition.new())
	var hits := [0]
	t.midpoint.connect(func() -> void: hits[0] += 1)
	t.play()
	assert_int(hits[0]).is_equal(1)


func test_it_never_eats_a_click() -> void:
	var t: Transition = auto_free(Transition.new())
	assert_int(t.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_switching_tabs_actually_plays_a_wipe() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_bool(m._transition.is_inside_tree()).is_true()
	(m._buttons["guild"] as Button).emit_signal("pressed")
	assert_bool(m._transition.is_playing()).is_true()


func test_the_screen_actually_swaps_once_the_wipe_reaches_its_midpoint() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	(m._buttons["seance"] as Button).emit_signal("pressed")
	await get_tree().create_timer(Transition.DEFAULT_SECONDS + 0.15).timeout
	assert_str(m.current_tab).is_equal("seance")
	assert_bool((m._screens["seance"] as Control).visible).is_true()
	assert_bool((m._screens["ladder"] as Control).visible).is_false()


func test_reselecting_the_open_tab_does_not_wipe() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	(m._buttons["ladder"] as Button).emit_signal("pressed")
	assert_bool(m._transition.is_playing()).is_false()
	assert_bool((m._screens["ladder"] as Control).visible).is_true()
