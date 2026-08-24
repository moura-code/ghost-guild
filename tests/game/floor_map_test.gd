extends GdUnitTestSuite

const TMP := "user://test_saves/floor_map_test.json"


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


func _map(g: GameRoot) -> FloorMapScreen:
	var m: FloorMapScreen = auto_free(FloorMapScreen.new())
	add_child(m)
	m.size = Vector2(720.0, 200.0)
	m.bind(g, g.campaign.run)
	return m


func test_it_shows_one_marker_per_node_plus_the_exit() -> void:
	var g := _game()
	var run := g.start_run(1)
	var m := _map(g)
	await await_idle_frame()
	assert_int(m._marks.size()).is_equal(run.nodes.size() + 1)
	assert_str(m._marks[m._marks.size() - 1].text).is_equal(g.text("ui.node.exit"))


func test_each_marker_names_its_node_kind() -> void:
	var g := _game()
	var run := g.start_run(1)
	var m := _map(g)
	await await_idle_frame()
	for i in run.nodes.size():
		var kind := String(run.nodes[i]["kind"])
		assert_str(m._marks[i].text).is_equal(g.text("ui.node.%s" % kind))
		assert_str(m._marks[i].text).is_not_equal("ui.node.%s" % kind)


func test_the_current_node_is_the_one_you_can_enter() -> void:
	var g := _game()
	var run := g.start_run(1)
	var m := _map(g)
	await await_idle_frame()
	assert_int(m.current_index).is_equal(run.node_index)
	assert_str(m._enter.text).contains(g.text("ui.node.%s" % String(run.current_node()["kind"])))


func test_entering_advances_the_run_out_of_the_node_phase() -> void:
	var g := _game()
	var run := g.start_run(1)
	var m := _map(g)
	await await_idle_frame()
	assert_str(run.phase).is_equal("node")
	m._enter.emit_signal("pressed")
	await await_idle_frame()
	assert_str(run.phase).is_not_equal("node")


func test_the_marker_states_track_progress() -> void:
	var g := _game()
	var run := g.start_run(1)
	var m := _map(g)
	await await_idle_frame()
	assert_str(m.state_of(0)).is_equal("current")
	assert_str(m.state_of(1)).is_equal("ahead")
	run.node_index = 2
	m.bind(g, run)
	await await_idle_frame()
	assert_str(m.state_of(0)).is_equal("done")
	assert_str(m.state_of(2)).is_equal("current")
