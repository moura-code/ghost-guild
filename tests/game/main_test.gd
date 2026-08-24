extends GdUnitTestSuite

const TMP := "user://test_saves/main_test.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _game(now: int = 1000) -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return now
	add_child(g)
	return g


func _main(g: GameRoot) -> MainScreen:
	var m: MainScreen = auto_free(MainScreen.new())
	m.bind(g)
	add_child(m)
	m.size = Vector2(1280.0, 720.0)
	return m


func test_it_boots_the_game_and_opens_on_the_ladder() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_bool(g.is_booted).is_true()
	assert_str(m.current_tab).is_equal("ladder")
	assert_bool((m._screens["ladder"] as Control).visible).is_true()
	assert_bool((m._screens["guild"] as Control).visible).is_false()


func test_every_tab_has_a_button_and_a_screen() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	for id in ["ladder", "guild", "seance", "hero"]:
		assert_bool(m._screens.has(id)).is_true()
		assert_bool(m._buttons.has(id)).is_true()


func test_pressing_a_tab_switches_the_visible_screen() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	(m._buttons["guild"] as Button).emit_signal("pressed")
	await await_idle_frame()
	assert_str(m.current_tab).is_equal("guild")
	assert_bool((m._screens["guild"] as Control).visible).is_true()
	assert_bool((m._screens["ladder"] as Control).visible).is_false()
	assert_bool((m._buttons["guild"] as Button).button_pressed).is_true()
	assert_bool((m._buttons["ladder"] as Button).button_pressed).is_false()


func test_a_fresh_game_shows_no_offline_summary() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_bool(m._offline.visible).is_false()


func test_returning_after_a_night_shows_the_summary_until_dismissed() -> void:
	var first := _game()
	first.boot()
	first.campaign.soul = 100.0
	first.save()

	var second := _game(1000 + 7200)
	var m := _main(second)
	await await_idle_frame()
	assert_bool(m._offline.visible).is_true()
	m._offline._button.emit_signal("pressed")
	await await_idle_frame()
	assert_bool(m._offline.visible).is_false()


func test_the_theme_is_applied_at_the_root() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_object(m.theme).is_not_null()
	assert_int(m.theme.default_font_size).is_equal(UiTheme.FONT_BODY)


func test_the_main_scene_loads_and_is_the_project_entry_point() -> void:
	var packed: PackedScene = load("res://game/main.tscn")
	assert_object(packed).is_not_null()
	assert_str(ProjectSettings.get_setting("application/run/main_scene", "")).is_equal("res://game/main.tscn")


func test_it_does_not_seize_quit_handling_unless_it_owns_the_autoload() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_bool(m.manages_quit).is_false()


func test_closing_the_window_saves_then_quits_when_it_owns_the_autoload() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	# The test's GameRoot is pre-bound, so _ready never sets manages_quit --
	# set it by hand to exercise the owns-the-autoload path.
	m.manages_quit = true
	var quit_calls := [0]
	m.quit_action = func() -> void: quit_calls[0] += 1
	g.campaign.soul = 4242.0
	m.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_int(quit_calls[0]).is_equal(1)
	var reloaded := SaveGame.load_campaign(g.content, TMP)
	assert_float(reloaded.soul).is_equal(4242.0)


func test_buying_in_the_guild_updates_the_ladder_behind_it() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	g.campaign.soul = 1000.0
	var ladder: LadderScreen = m._screens["ladder"]
	var before := ladder._rows[0].output_per_hour
	# "ghost_strength" (not the brief's "ghost_spawn"): global_spawn only raises
	# floor 1's saturation ceiling (64.8 -> 71.28/h), and the lone Founder's 40
	# strength sits under both, so output stays 52/h either way -- see the
	# task-11 report. global_strength scales the ghost directly (52 -> 57.2/h),
	# which is what this test means to exercise.
	g.buy_upgrade("ghost_strength")
	await await_idle_frame()
	assert_float(ladder._rows[0].output_per_hour).is_not_equal(before)
