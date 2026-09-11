extends GdUnitTestSuite
## Stage 4: the floor is played, not skipped. Every phase a run can be in has
## a host, and the autopilot scaffolding that stood in for them is gone -- so
## the assertion that matters is that nothing falls through.

const TMP := "user://test_saves/crawl_loop_test.json"


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


## Binding lands you in the guild; descending is what starts a run. These
## tests are about the floor loop, so they descend immediately.
func _crawl(g: GameRoot) -> Crawl:
	var c: Crawl = auto_free(Crawl.new())
	c.game = g
	# These are the game's tests, not the menu's: start already playing.
	c.show_title = false
	add_child(c)
	c.bind(g)
	g.start_run(1)
	return c


func test_the_descent_draft_is_offered_rather_than_picked_for_you() -> void:
	var g := _game()
	var c := _crawl(g)
	var run := g.campaign.run
	if run.phase != "descent":
		return  # This hero drew no descent offers.
	assert_bool(c.choice.visible).is_true()
	assert_bool(c.panel_open()).is_true()
	# Nothing was drafted behind the player's back.
	assert_array(TestFixtures.run_events_of(run, "draft_pick")).is_empty()


func test_taking_the_draft_offers_puts_you_on_a_floor() -> void:
	var g := _game()
	var c := _crawl(g)
	var run := g.campaign.run
	var guard := 0
	while run.phase == "descent" and guard < 20:
		guard += 1
		c.choice.take(0)
	assert_str(run.phase).is_equal("node")
	assert_object(c.layout).is_not_null()
	assert_bool(c.panel_open()).is_false()


## Gets a crawl onto a walkable floor whatever the draft did.
func _on_floor(g: GameRoot) -> Crawl:
	var c := _crawl(g)
	var run := g.campaign.run
	var guard := 0
	while run.phase == "descent" and guard < 20:
		guard += 1
		c.choice.take(0)
	return c


func test_whatever_room_you_walk_into_something_hosts_it() -> void:
	# Deliberately does not guess from the node's kind: "elite" and "boss" are
	# fights too, and a test that hard-codes the three fight kinds goes stale
	# the day a fourth is added. The phase the engine lands in is the truth.
	var g := _game()
	var c := _on_floor(g)
	var run := g.campaign.run
	(c.markers[0] as EncounterMarker).report(c.player)
	if run.phase == "fight":
		assert_object(c.director).is_not_null()
		assert_int(c.director.hand.visible_count()).is_greater(0)
		# A fight leaves you in your body, fenced into the room -- once the
		# hero has finished stepping up to what they are fighting.
		await await_millis(800)
		assert_bool(c.player.frozen).is_false()
		assert_object(c.director.get_node_or_null("Ring")).is_not_null()
	else:
		assert_bool(ChoiceScreen.handles(run.phase)).override_failure_message("phase %s had no host" % run.phase).is_true()
		assert_bool(c.choice.visible).is_true()
		# A panel holds you still: walking away from an unchosen reward would
		# strand the run in a phase with nothing to do.
		assert_bool(c.player.frozen).is_true()


func test_a_fight_room_still_stages_a_fight_and_its_reward_is_a_panel() -> void:
	var g := _game()
	var c := _on_floor(g)
	var run := g.campaign.run
	for m in c.markers.duplicate():
		var marker: EncounterMarker = m
		if String(run.nodes[marker.index].get("kind", "")) != "fight":
			continue
		marker.report(c.player)
		assert_object(c.director).is_not_null()
		TestFixtures.autofight(run)
		c.director.check_over()
		if run.is_over():
			return
		# A won fight hands you a reward, and the reward is something you pick.
		assert_bool(run.phase == "node" or ChoiceScreen.handles(run.phase)).is_true()
		if ChoiceScreen.handles(run.phase):
			assert_bool(c.choice.visible).is_true()
		return


func test_no_phase_of_a_whole_floor_falls_through_without_a_host() -> void:
	var g := _game()
	var c := _on_floor(g)
	var run := g.campaign.run
	var guard := 0
	while not run.is_over() and run.phase != "exit" and guard < 60:
		guard += 1
		match run.phase:
			"node":
				var next := run.next_unresolved()
				var marker: EncounterMarker = null
				for m in c.markers:
					if (m as EncounterMarker).index == next:
						marker = m
				assert_object(marker).override_failure_message("no marker for node %d" % next).is_not_null()
				marker.report(c.player)
			"fight":
				assert_object(c.director).is_not_null()
				TestFixtures.autofight(run)
				c.director.check_over()
			_:
				assert_bool(ChoiceScreen.handles(run.phase)).override_failure_message("phase %s had no host" % run.phase).is_true()
				assert_bool(c.choice.visible).is_true()
				c.choice.take(0)
	assert_int(guard).is_less(60)


func test_the_stairs_open_the_exit_decision_and_pushing_builds_the_next_floor() -> void:
	var g := _game()
	var c := _on_floor(g)
	var run := g.campaign.run
	var guard := 0
	while not run.is_over() and run.phase != "exit" and guard < 60:
		guard += 1
		match run.phase:
			"node":
				for m in c.markers:
					if (m as EncounterMarker).index == run.next_unresolved():
						(m as EncounterMarker).report(c.player)
						break
			"fight":
				TestFixtures.autofight(run)
				c.director.check_over()
			_:
				c.choice.take(0)
	if run.is_over() or run.phase != "exit":
		return
	assert_bool(c.stairs.monitoring).is_true()
	c.stairs.report(c.player)
	assert_bool(c.exit_panel.visible).is_true()
	if not RunEngine.can_push(run):
		return
	var started := run.floor
	# The button, not the callback. The callback is what the panel tells the
	# crawl AFTER it has applied the decision, and calling it directly was
	# quietly asserting that applying an exit twice is fine -- which is what
	# hid `push_error("expected enter, got push")` on every descent.
	c.exit_panel._push.pressed.emit()
	assert_int(g.campaign.run.floor).is_equal(started + 1)
	assert_bool(c.panel_open()).is_false()
	assert_str(g.campaign.run.phase).is_equal("node")


func test_minimap_tracks_exploration_without_mutating_the_run() -> void:
	var g := _game()
	var c := _on_floor(g)
	assert_bool(c.minimap.visible).is_false()
	c.settings.minimap = true
	c._apply_input_context()
	var before := JSON.stringify(g.campaign.run.to_dict())
	var at := Kit.cell_to_world(c.layout.room_center(c.layout.entry_room))
	c.player.position = at
	c.player.rotation.y = 0.6
	c._process(0.11)
	assert_bool(c.minimap.visible).is_true()
	assert_int(c.minimap.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_object(c.minimap.layout).is_same(c.layout)
	assert_vector(c.minimap.player_at).is_equal(at)
	assert_float(c.minimap.player_yaw).is_equal_approx(0.6, 0.001)
	c._open_map()
	assert_bool(c.minimap.visible).is_false()
	var target := c.layout.room_center(c.layout.stairs_room)
	c.floor_map.select_cell(target)
	c.close_panel()
	assert_bool(c.minimap.visible).is_true()
	assert_vector(c.minimap.marker).is_equal(target)
	assert_str(JSON.stringify(g.campaign.run.to_dict())).is_equal(before)
	c._open_pause()
	assert_bool(c.minimap.visible).is_false()
	c.close_panel()
	var fight_index := -1
	for i in g.campaign.run.nodes.size():
		if g.campaign.run.nodes[i]["kind"] in ["fight", "elite", "boss"]:
			fight_index = i
			break
	assert_int(fight_index).is_greater_equal(0)
	g.run_action({"kind": "enter", "index": fight_index})
	assert_bool(c.minimap.visible).is_false()
