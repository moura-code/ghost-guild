extends GdUnitTestSuite

const TMP := "user://test_saves/exit_screen_test.json"


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


## A run parked at a floor exit, which is the state this screen renders.
func _at_exit(g: GameRoot, floor: int = 1) -> RunState:
	var run := g.start_run(1)
	run.floor = floor
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	return run


func _screen(g: GameRoot, run: RunState) -> ExitScreen:
	var s: ExitScreen = auto_free(ExitScreen.new())
	s.threaded = false
	add_child(s)
	s.size = Vector2(720.0, 480.0)
	s.bind(g, run)
	return s


func test_it_lands_on_the_exit_phase_and_titles_the_floor() -> void:
	var g := _game()
	var run := _at_exit(g, 2)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_str(run.phase).is_equal("exit")
	assert_str(s._title.text).contains("2")
	assert_str(s._title.text).is_not_equal("ui.exit.title")


func test_it_shows_the_three_numbers_once_the_reckoning_lands() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_bool(s.pending).is_false()
	assert_str(s._here.text).contains("/h")
	assert_str(s._next.text).contains("/h")
	assert_str(s._survival.text).contains("%")
	assert_str(s._note.text).is_equal("")


func test_the_yield_numbers_are_marginal_and_positive() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_float(float(s.numbers["here"])).is_greater(0.0)
	assert_float(float(s.numbers["next"])).is_greater(0.0)


func test_a_pending_reckoning_shows_a_waiting_state_and_locks_the_choice() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s: ExitScreen = auto_free(ExitScreen.new())
	s.threaded = false
	add_child(s)
	# Render the waiting state directly: bind() computes inline and clears it.
	s.game = g
	s.run = run
	s._build()
	s.pending = true
	s._refresh_labels()
	s._refresh_buttons()
	await await_idle_frame()
	assert_str(s._here.text).is_equal(g.text("ui.exit.pending"))
	assert_bool(s._push.disabled).is_true()
	assert_bool(s._retreat.disabled).is_true()


func test_the_watch_is_locked_until_the_first_death() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_bool(g.campaign.onboarding.watch_unlocked).is_false()
	assert_bool(s._watch.visible).is_true()
	assert_bool(s._watch.disabled).is_true()
	assert_str(s._watch.text).is_equal(g.text("ui.exit.watch_locked"))


func test_the_watch_opens_once_the_rite_is_unlocked() -> void:
	var g := _game()
	g.campaign.onboarding.watch_unlocked = true
	var run := _at_exit(g)
	run.watch_unlocked = true
	var s := _screen(g, run)
	await await_idle_frame()
	assert_bool(s._watch.disabled).is_false()
	assert_str(s._watch.text).is_equal(g.text("ui.exit.watch"))


func test_pushing_moves_the_run_to_the_next_floor() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s := _screen(g, run)
	await await_idle_frame()
	var before := run.floor
	s._push.emit_signal("pressed")
	await await_idle_frame()
	assert_int(run.floor).is_equal(before + 1)
	assert_bool(run.is_over()).is_false()


func test_retreating_ends_the_run() -> void:
	var g := _game()
	var run := _at_exit(g)
	run.hero.resolve = 1
	var s := _screen(g, run)
	await await_idle_frame()
	var decisions: Array[String] = []
	s.decided.connect(func(kind: String) -> void: decisions.append(kind))
	s._retreat.emit_signal("pressed")
	await await_idle_frame()
	assert_bool(run.is_over()).is_true()
	assert_str(String(run.outcome["kind"])).is_equal("retreat")
	assert_str(decisions[0]).is_equal("retreat")


func test_retreat_is_refused_with_no_resolve_left() -> void:
	var g := _game()
	var run := _at_exit(g)
	run.hero.resolve = 0
	var s := _screen(g, run)
	await await_idle_frame()
	assert_bool(s._retreat.disabled).is_true()


func test_the_last_floor_of_the_biome_cannot_be_pushed_past() -> void:
	var g := _game()
	var run := _at_exit(g, g.campaign.biome().last_floor)
	var s := _screen(g, run)
	await await_idle_frame()
	assert_bool(bool(s.numbers["summary"]["can_push"])).is_false()
	assert_bool(s._push.visible).is_false()
	# The reading has nothing to show, and the note says why.
	assert_str(s._next.text).is_equal("—")
	assert_str(s._note.text).is_equal(g.text("ui.exit.no_push"))
	assert_str(s._note.text).is_not_equal("ui.exit.no_push")


func test_reckon_reads_without_mutating_the_run() -> void:
	var g := _game()
	var run := _at_exit(g)
	var floor_before := run.floor
	var hp_before := run.hero.hp
	var phase_before := run.phase
	var soul_before := g.campaign.soul
	ExitScreen.reckon(g.campaign, run, 2)
	assert_int(run.floor).is_equal(floor_before)
	assert_int(run.hero.hp).is_equal(hp_before)
	assert_str(run.phase).is_equal(phase_before)
	assert_float(g.campaign.soul).is_equal(soul_before)


func test_the_odds_colour_themselves() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s := _screen(g, run)
	await await_idle_frame()
	# This is the number the decision hangs on, so it should read before it
	# is parsed. Drive each band directly rather than hunting for a floor
	# that happens to produce one.
	for band in [[0.2, Palette.DANGER], [0.55, Palette.PREPARED], [0.9, Palette.GOOD]]:
		s.numbers["summary"]["survival"] = float(band[0])
		s._refresh_labels()
		assert_that(s._survival.get_theme_color("font_color")).is_equal(band[1])
