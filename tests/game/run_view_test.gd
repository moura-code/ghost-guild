extends GdUnitTestSuite

const TMP := "user://test_saves/run_view_test.json"


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
	g.campaign.sim_fights = 4
	return g


func _view(g: GameRoot) -> RunView:
	var v: RunView = auto_free(RunView.new())
	add_child(v)
	v.size = Vector2(720.0, 520.0)
	v.bind(g)
	return v


func test_it_names_the_floor_and_the_phase() -> void:
	var g := _game()
	g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	assert_str(v._floor.text).contains("1")
	assert_str(v._phase.text).is_equal(g.text("ui.run.phase.%s" % g.campaign.run.phase))
	assert_str(v._phase.text).is_not_equal("ui.run.phase.%s" % g.campaign.run.phase)


func test_continue_advances_the_run_one_step() -> void:
	var g := _game()
	var run := g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	var before := run.phase
	v._continue.emit_signal("pressed")
	await await_idle_frame()
	assert_str(run.phase).is_not_equal(before)


func test_pressing_continue_repeatedly_finishes_the_run() -> void:
	var g := _game()
	var run := g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	# The Catacombs are ten floors; a starter Sexton dies well before the
	# autopilot runs out of legal moves, so this terminates.
	var guard := 0
	while not run.is_over() and guard < 4000:
		v._continue.emit_signal("pressed")
		guard += 1
	assert_bool(run.is_over()).is_true()
	assert_int(guard).is_less(4000)


func test_a_finished_run_offers_to_bank_itself() -> void:
	var g := _game()
	var run := g.start_run(1)
	run.hero.resolve = 1
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	RunEngine.apply(run, {"kind": "retreat"})
	var v := _view(g)
	await await_idle_frame()
	assert_str(v._continue.text).is_equal(g.text("ui.run.bank"))

	var banked := [{}]
	v.run_finished.connect(func(result: Dictionary) -> void: banked[0] = result)
	v._continue.emit_signal("pressed")
	await await_idle_frame()
	assert_str(String(banked[0]["kind"])).is_equal("retreat")
	assert_object(g.campaign.run).is_null()


func test_the_log_records_what_just_happened() -> void:
	var g := _game()
	g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	assert_str(v._log.text).is_equal("")
	v._continue.emit_signal("pressed")
	await await_idle_frame()
	assert_str(v._log.text).is_not_equal("")


func test_binding_twice_does_not_connect_the_signals_twice() -> void:
	var g := _game()
	g.start_run(1)
	var v := _view(g)
	v.bind(g)
	await await_idle_frame()
	assert_int(g.run_changed.get_connections().size()).is_equal(1)


func test_the_node_phase_shows_the_floor_map_instead_of_the_step_button() -> void:
	var g := _game()
	var run := g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	assert_str(run.phase).is_equal("node")
	assert_bool(v._map.visible).is_true()
	assert_bool(v._continue.visible).is_false()


func test_a_phase_without_a_screen_yet_still_offers_the_step_button() -> void:
	var g := _game()
	var run := g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	# Descent has no screen until Task 8, so it must fall through to Continue.
	run.phase = "descent"
	run.descent_offers = [{"floor": 1, "cards": ["strike"]}]
	v.refresh()
	await await_idle_frame()
	assert_bool(v._map.visible).is_false()
	assert_bool(v._fight.visible).is_false()
	assert_bool(v._choice.visible).is_false()
	assert_bool(v._exit.visible).is_false()
	assert_bool(v._continue.visible).is_true()


func test_the_fight_phase_shows_the_fight_screen() -> void:
	var g := _game()
	var run := g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["bone_rat"]}])
	g.run_action({"kind": "enter"})
	await await_idle_frame()
	assert_str(run.phase).is_equal("fight")
	assert_bool(v._fight.visible).is_true()
	assert_bool(v._map.visible).is_false()
	assert_bool(v._continue.visible).is_false()
	assert_int(v._fight._enemy_views.size()).is_equal(1)


func test_a_node_phase_shows_the_choice_screen() -> void:
	var g := _game()
	var run := g.start_run(1)
	var v := _view(g)
	await await_idle_frame()
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	g.run_action({"kind": "enter"})
	await await_idle_frame()
	assert_str(run.phase).is_equal("rest")
	assert_bool(v._choice.visible).is_true()
	assert_bool(v._continue.visible).is_false()


func test_the_exit_phase_shows_the_exit_screen() -> void:
	var g := _game()
	var run := g.start_run(1)
	var v := _view(g)
	v._exit.threaded = false
	await await_idle_frame()
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	g.run_action({"kind": "enter"})
	g.run_action({"kind": "rest_heal"})
	await await_idle_frame()
	assert_str(run.phase).is_equal("exit")
	assert_bool(v._exit.visible).is_true()
	assert_bool(v._continue.visible).is_false()
