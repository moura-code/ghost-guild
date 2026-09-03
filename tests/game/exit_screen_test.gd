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


func test_the_deepest_authored_floor_still_offers_the_next_one() -> void:
	# It used to be the bottom of the dungeon. The biomes cycle now (§2), so
	# floor 30 is an ordinary floor with floor 31 under it, and the screen
	# offers the push like any other.
	var g := _game()
	var run := _at_exit(g, Biomes.depth(g.content))
	var s := _screen(g, run)
	await await_idle_frame()
	assert_bool(bool(s.numbers["summary"]["can_push"])).is_true()
	assert_bool(s._push.visible).is_true()
	assert_str(s._next.text).is_not_equal("—")


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


func test_the_measured_number_lands_before_the_simulated_ones() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s: ExitScreen = auto_free(ExitScreen.new())
	s.threaded = false
	add_child(s)
	s.game = g
	s.run = run
	s._build()
	# reckon_here is measured from the fights that just happened, so it is
	# available without simulating anything.
	s.numbers = ExitScreen.reckon_here(g.campaign, run)
	s._refresh_labels()
	await await_idle_frame()
	assert_str(s._here.text).contains("/h")
	# The two that need simulation are still waiting.
	assert_str(s._next.text).is_equal(g.text("ui.exit.pending"))
	assert_str(s._survival.text).is_equal(g.text("ui.exit.pending"))


func test_the_slow_half_fills_in_without_losing_the_fast_half() -> void:
	var g := _game()
	var run := _at_exit(g)
	var s: ExitScreen = auto_free(ExitScreen.new())
	s.threaded = false
	add_child(s)
	s.game = g
	s.run = run
	s._build()
	s.numbers = ExitScreen.reckon_here(g.campaign, run)
	var measured: float = s.numbers["here"]
	s._on_reckoned(ExitScreen.reckon_ahead(g.campaign, run, ExitScreen.PREVIEW_SAMPLES))
	await await_idle_frame()
	# Merging must not drop what already arrived.
	assert_float(float(s.numbers["here"])).is_equal(float(measured))
	assert_str(s._next.text).contains("/h")
	assert_str(s._survival.text).contains("%")


func test_the_preview_simulates_less_than_the_balance_tools() -> void:
	# The trade this screen makes: an estimate the player glances at does
	# not need the accuracy a balance invariant does.
	assert_int(ExitScreen.PREVIEW_FIGHTS) \
		.is_less(int(TestFixtures.content().balance.get("strength_sim_fights", 50)))
	assert_int(ExitScreen.PREVIEW_SAMPLES) \
		.is_less(int(TestFixtures.content().balance.get("survival_samples", 20)))


func test_the_preview_restores_the_campaign_fight_count() -> void:
	var g := _game()
	var run := _at_exit(g)
	var before := g.campaign.sim_fights
	var s := _screen(g, run)
	await await_idle_frame()
	# Trimming sim_fights for the preview must not leak into the campaign,
	# or every ghost placed afterwards would be measured with fewer fights.
	assert_int(g.campaign.sim_fights).is_equal(before)


# ------------------------------------------------- taking the watch, in order

func test_taking_the_watch_asks_how_before_it_ends_the_run() -> void:
	# The one thing this screen asks the player to author rather than read.
	# Ending the run on the first click would skip it entirely.
	var g := _game()
	g.campaign.onboarding.watch_unlocked = true
	var run := _at_exit(g)
	run.watch_unlocked = true
	var s := _screen(g, run)
	s._watch.pressed.emit()
	assert_bool(s._picker.visible).override_failure_message("no picker").is_true()
	assert_bool(s._face.visible).is_false()
	assert_str(run.phase).override_failure_message("the run ended before the choice").is_equal("exit")


func test_backing_out_of_the_picker_returns_the_numbers() -> void:
	var g := _game()
	g.campaign.onboarding.watch_unlocked = true
	var run := _at_exit(g)
	run.watch_unlocked = true
	var s := _screen(g, run)
	s._watch.pressed.emit()
	s._picker.cancelled.emit()
	assert_bool(s._picker.visible).is_false()
	assert_bool(s._face.visible).is_true()
	assert_str(run.phase).is_equal("exit")


func test_confirming_ends_the_run_with_the_rules_the_player_ordered() -> void:
	var g := _game()
	g.campaign.onboarding.watch_unlocked = true
	var run := _at_exit(g)
	run.watch_unlocked = true
	var s := _screen(g, run)
	var decided: Array[String] = []
	s.decided.connect(func(kind: String) -> void: decided.append(kind))
	s._watch.pressed.emit()
	s._picker.toggle("strike_first")
	s._picker.toggle("finish_the_wounded")
	s._picker._confirm.pressed.emit()
	assert_array(decided).is_equal(["watch"])
	assert_array(run.hero.rules).is_equal(["strike_first", "finish_the_wounded"])


func test_the_ghost_that_walks_away_from_this_screen_carries_them() -> void:
	# The whole chain: picker -> action -> hero -> ghost -> ladder.
	var g := _game()
	g.campaign.onboarding.watch_unlocked = true
	var run := _at_exit(g)
	run.watch_unlocked = true
	var s := _screen(g, run)
	s._watch.pressed.emit()
	s._picker.toggle("hold_the_line")
	s._picker._confirm.pressed.emit()
	# The screen ends the run; banking it is Crawl's job, and this is the
	# chain being tested rather than the screen alone.
	g.finish_run()
	var newest: Ghost = null
	for ghost in g.campaign.ladder.ghosts:
		if newest == null or ghost.id > newest.id:
			newest = ghost
	assert_object(newest).is_not_null()
	assert_array(newest.rules).override_failure_message("the ghost forgot its orders").is_equal(["hold_the_line"])


func test_rebinding_the_screen_puts_the_numbers_back_in_front() -> void:
	# The panel is built once and reused for every floor exit. A picker left
	# up would greet the player at the next exit instead of the readings.
	var g := _game()
	g.campaign.onboarding.watch_unlocked = true
	var run := _at_exit(g)
	run.watch_unlocked = true
	var s := _screen(g, run)
	s._watch.pressed.emit()
	s.bind(g, run)
	assert_bool(s._face.visible).is_true()
	assert_bool(s._picker.visible).is_false()
