extends GdUnitTestSuite
## The wallet above every idle tab. This lived inside LadderScreen, which is
## why the Guild and the Séance -- the two screens where Soul is actually
## spent -- had no way to show how much of it you had. These tests moved with
## the widget, and now cover it wherever it is mounted.

const TMP := "user://test_saves/wallet_bar_test.json"


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 4
	return g


func _wallet_bar(g: GameRoot) -> WalletBar:
	var w: WalletBar = auto_free(WalletBar.new())
	w.bind(g)
	add_child(w)
	return w


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func test_the_header_shows_soul_rate_and_reach() -> void:
	var g := _game()
	var s := _wallet_bar(g)
	await await_idle_frame()
	assert_str(s._rate.text).is_equal("52/h")
	assert_str(s._reach.text).is_equal("1")
	assert_str(s._soul.text).is_equal(Num.short(g.displayed_soul()))


func test_the_counter_runs_up_to_an_hour_of_earnings() -> void:
	var g := _game()
	var s := _wallet_bar(g)
	await await_idle_frame()
	g.clock = func() -> int: return 1000 + 3600
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	# The counter runs up to its value rather than snapping, so give the
	# count time to land before reading it.
	await get_tree().create_timer(0.8).timeout
	assert_str(s._soul.text).is_equal("52")


func test_the_header_numbers_explain_themselves_on_hover() -> void:
	var g := _game()
	var s := _wallet_bar(g)
	await await_idle_frame()
	assert_str((s._soul.get_parent() as Control).tooltip_text).is_equal(g.text("ui.tip.soul"))
	assert_str((s._rate.get_parent() as Control).tooltip_text).is_equal(g.text("ui.tip.per_hour"))
	assert_str((s._reach.get_parent() as Control).tooltip_text).is_equal(g.text("ui.tip.reach"))
	assert_str((s._soul.get_parent() as Control).tooltip_text).is_not_equal("ui.tip.soul")


func test_the_soul_counter_kicks_when_the_whole_number_climbs() -> void:
	var g := _game()
	var s := _wallet_bar(g)
	await await_idle_frame()
	# The first paint must not kick, or the screen jumps on open.
	assert_that(s._soul.scale).is_equal(Vector2.ONE)
	g.clock = func() -> int: return 1000 + 3600
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	assert_float(s._soul.scale.x).is_greater(1.0)


func test_the_counter_settles_back_after_the_kick() -> void:
	var g := _game()
	var s := _wallet_bar(g)
	await await_idle_frame()
	g.clock = func() -> int: return 1000 + 3600
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	await get_tree().create_timer(0.3).timeout
	assert_float(s._soul.scale.x).is_equal_approx(1.0, 0.02)


func test_a_tick_that_does_not_move_the_whole_number_does_not_kick() -> void:
	var g := _game()
	var s := _wallet_bar(g)
	await await_idle_frame()
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	assert_that(s._soul.scale).is_equal(Vector2.ONE)




func test_the_counter_runs_up_rather_than_snapping() -> void:
	var g := _game()
	var s := _wallet_bar(g)
	await await_idle_frame()
	g.clock = func() -> int: return 1000 + 3600
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	# Immediately after the value changes the counter has not arrived yet --
	# that is the whole point of it running up.
	assert_float(s._shown_soul).is_less(52.0)
	await get_tree().create_timer(0.8).timeout
	assert_float(s._shown_soul).is_equal_approx(52.0, 0.01)
