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
		assert_bool(m._tab_bar._items.has(id)).is_true()


func test_pressing_a_tab_switches_the_visible_screen() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	m._tab_bar.tab_pressed.emit("guild")
	# The swap happens behind a wipe, so wait for the wipe rather than
	# hoping one idle frame covers it -- it does not, under load.
	await get_tree().create_timer(Transition.DEFAULT_SECONDS + 0.2).timeout
	assert_str(m.current_tab).is_equal("guild")
	assert_bool((m._screens["guild"] as Control).visible).is_true()
	assert_bool((m._screens["ladder"] as Control).visible).is_false()
	# The nav lights the active destination and slides its marker there.
	assert_str(m._tab_bar.current).is_equal("guild")


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


## The 3D pivot moved the entry point to res://game/crawl.tscn. This scene
## still loads and this screen still works -- it is deleted when the 3D screen
## that replaces it exists, not before -- but it is no longer what boots.
func test_the_main_scene_still_loads_even_though_it_no_longer_boots() -> void:
	var packed: PackedScene = load("res://game/main.tscn")
	assert_object(packed).is_not_null()
	assert_str(ProjectSettings.get_setting("application/run/main_scene", "")).is_not_equal("res://game/main.tscn")


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
	var bal := g.campaign.balance()
	var before := g.campaign.ladder.floor_output(1, bal, g.campaign.modifiers())
	# "ghost_strength" (not the brief's "ghost_spawn"): global_spawn only raises
	# floor 1's saturation ceiling (64.8 -> 71.28/h), and the lone Founder's 40
	# strength sits under both, so output stays 52/h either way -- see the
	# task-11 report. global_strength scales the ghost directly (52 -> 57.2/h),
	# which is what this test means to exercise.
	g.buy_upgrade("ghost_strength")
	await await_idle_frame()
	var after := g.campaign.ladder.floor_output(1, bal, g.campaign.modifiers())
	assert_float(after).is_not_equal(before)
	# And the shaft behind the Guild has been rebound with it.
	var ladder: LadderScreen = m._screens["ladder"]
	assert_int(ladder._tower.floors).is_equal(g.campaign.biome().last_floor)


func test_starting_a_run_replaces_the_tabs_with_the_run_view() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_bool(m._run_view.visible).is_false()
	assert_bool(m._tab_bar.visible).is_true()

	g.start_run(1)
	await await_idle_frame()
	assert_bool(m._run_view.visible).is_true()
	assert_bool(m._tab_bar.visible).is_false()


func test_banking_a_run_returns_to_the_tabs() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	var run := g.start_run(1)
	run.hero.resolve = 1
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "retreat"})
	g.finish_run()
	await await_idle_frame()
	assert_bool(m._run_view.visible).is_false()
	assert_bool(m._tab_bar.visible).is_true()


func test_a_death_shows_the_epitaph_before_the_guild_comes_back() -> void:
	var g := _game()
	var m := _main(g)
	m._epitaph.paced = false
	await await_idle_frame()
	var result := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	m._on_run_finished(result)
	await await_idle_frame()
	assert_bool(m._epitaph.visible).is_true()
	assert_bool(m._tab_bar.visible).is_false()
	assert_bool(m._run_view.visible).is_false()

	m._epitaph._dismiss.emit_signal("pressed")
	await await_idle_frame()
	assert_bool(m._epitaph.visible).is_false()
	assert_bool(m._tab_bar.visible).is_true()


func test_a_retreat_skips_the_epitaph_entirely() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	var run := g.start_run(1)
	run.hero.resolve = 1
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "retreat"})
	var result := g.finish_run()
	m._on_run_finished(result)
	await await_idle_frame()
	assert_bool(m._epitaph.visible).is_false()
	assert_bool(m._tab_bar.visible).is_true()


func test_the_atmosphere_sits_behind_everything() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_object(m._atmosphere).is_not_null()
	assert_int(m.get_child(0).get_instance_id()).is_equal(m._atmosphere.get_instance_id())
	assert_int(m._atmosphere.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_the_ground_darkens_as_the_hero_descends() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	assert_float(m._atmosphere.depth).is_equal(0.0)
	var run := g.start_run(1)
	run.floor = g.campaign.biome().last_floor
	m._refresh_run_visibility()
	await await_idle_frame()
	assert_float(m._atmosphere.depth).is_equal(1.0)


func test_the_ground_lifts_again_back_in_the_guild() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	var run := g.start_run(1)
	run.floor = 8
	m._refresh_run_visibility()
	assert_float(m._atmosphere.depth).is_greater(0.0)
	run.hero.resolve = 1
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "retreat"})
	g.finish_run()
	await await_idle_frame()
	assert_float(m._atmosphere.depth).is_equal(0.0)


## The wallet is shell furniture, not Ladder furniture. Before the visual
## overhaul it was built inside LadderScreen, so the Guild and the Séance --
## the only two screens in the game where Soul is spent -- showed the player
## no balance at all. Affordability was inferable only from a greyed button.
func test_the_wallet_is_visible_on_every_idle_tab() -> void:
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	for tab in ["ladder", "guild", "seance", "hero"]:
		m._apply_tab(tab)
		await await_idle_frame()
		assert_bool(m._wallet.visible) \
			.override_failure_message("no Soul balance on the %s tab" % tab) \
			.is_true()
		assert_bool(m._wallet.is_visible_in_tree()).is_true()


func test_the_wallet_goes_away_underground() -> void:
	# The tabs are the guild, and you are not in the guild while you are
	# down a hole: the run owns the whole window.
	var g := _game()
	var m := _main(g)
	await await_idle_frame()
	g.start_run(1)
	await await_idle_frame()
	assert_bool(m._wallet.visible).is_false()
