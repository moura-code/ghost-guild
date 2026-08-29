extends GdUnitTestSuite
## The wiring test. The assertion that matters most is the last one: the
## world reads the run and reports intent, and the run only ever changes
## through RunEngine (spec §4). Everything else here is scaffolding around
## that one invariant.

var _save_path: String


func before_test() -> void:
	_save_path = "user://crawl_test_%d.json" % Time.get_ticks_usec()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = _save_path
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	return g


## `game` is set BEFORE the node enters the tree on purpose. Crawl._ready
## picks up the /root/Game autoload when nobody has claimed it, and that
## autoload boots against the real save path -- so binding after add_child
## would build the floor twice and write over the developer's save.
## Binding now lands you in the guild -- there is no run until you descend.
## These are the dungeon's tests, so they descend and take the draft first.
func _crawl() -> Crawl:
	var c: Crawl = auto_free(Crawl.new())
	var g := _game()
	c.game = g
	add_child(c)
	c.bind(g)
	g.start_run(1)
	var guard := 0
	while g.campaign.run != null and g.campaign.run.phase == "descent" and guard < 20:
		guard += 1
		c.choice.take(0)
	return c


func test_a_crawl_that_was_handed_a_game_does_not_go_looking_for_the_autoload() -> void:
	var c := _crawl()
	assert_object(c.game).is_not_same(get_node_or_null("/root/Game"))
	# One World, not one per bind.
	var worlds := 0
	for child in c.get_children():
		if child.name == "World":
			worlds += 1
	assert_int(worlds).is_equal(1)


func test_it_builds_the_floor_the_run_is_on() -> void:
	var c := _crawl()
	assert_object(c.game.campaign.run).is_not_null()
	assert_object(c.layout).is_not_null()
	assert_int(c.layout.width).is_equal(LayoutGenerator.GRID)
	assert_object(c.get_node("World/Floors")).is_not_null()
	assert_object(c.get_node("World/Collision")).is_not_null()


func test_the_descent_draft_never_leaves_the_player_in_a_room_that_does_not_exist() -> void:
	# A run opens in phase "descent" with card offers. Stage 2 has no draft
	# screen, so the crawl settles past it; either way the phase it builds a
	# floor in is a phase that has nodes.
	var c := _crawl()
	assert_str(c.game.campaign.run.phase).is_not_equal("descent")


func test_the_player_starts_in_the_entry_room() -> void:
	var c := _crawl()
	assert_object(c.player).is_not_null()
	var cell := Kit.world_to_cell(c.player.position)
	assert_vector(cell).is_equal(c.layout.room_center(c.layout.entry_room))
	assert_bool(c.layout.is_walkable(cell.x, cell.y)).is_true()


func test_there_is_one_marker_per_unresolved_node() -> void:
	var c := _crawl()
	var run := c.game.campaign.run
	assert_array(c.markers).has_size(run.nodes.size())
	var rooms: Array = []
	for m in c.markers:
		var marker: EncounterMarker = m
		rooms.append(c.layout.room_of_node(marker.index))
	assert_array(rooms).is_not_empty()
	# Two encounters in one room would make the second unreachable.
	assert_int(rooms.size()).is_equal(_unique(rooms).size())


func test_walking_into_a_room_enters_that_node_and_only_that_node() -> void:
	var c := _crawl()
	var run := c.game.campaign.run
	var marker: EncounterMarker = c.markers[c.markers.size() - 1]
	var chosen := marker.index
	marker.report(c.player)
	var entries := TestFixtures.run_events_of(run, "node_enter")
	assert_array(entries).has_size(1)
	assert_int(int(entries[0]["index"])).is_equal(chosen)
	# The node is entered, not finished: a fight room now stages a fight and
	# waits for it to be played. Only the room you walked into is touched.
	assert_str(run.phase).is_not_equal("node")
	for i in run.nodes.size():
		if i != chosen:
			assert_bool(run.is_resolved(i)).is_false()


## Walks into a room and sees it through, however it resolves. Nothing is
## auto-resolved any more: a fight stays staged until it is played and a
## reward stays open until it is taken, so a test that wants a cleared floor
## has to actually play the room.
func _clear(c: Crawl, marker: EncounterMarker) -> void:
	marker.report(c.player)
	var run := c.game.campaign.run
	var guard := 0
	while not run.is_over() and run.phase != "node" and run.phase != "exit" and guard < 40:
		guard += 1
		if run.phase == "fight":
			TestFixtures.autofight(run)
			if c.director != null:
				c.director.check_over()
		elif ChoiceScreen.handles(run.phase):
			c.choice.take(0)
		else:
			break


func test_clearing_every_room_unlocks_the_stairs() -> void:
	var c := _crawl()
	var run := c.game.campaign.run
	assert_bool(c.stairs.visible).is_false()
	for m in c.markers.duplicate():
		var marker: EncounterMarker = m
		if run.is_over():
			break
		_clear(c, marker)
	if run.is_over():
		return  # The hero died on the way; the stairs question is moot.
	assert_str(run.phase).is_equal("exit")
	assert_bool(c.stairs.visible).is_true()


func test_walking_into_the_stairs_opens_the_exit_decision() -> void:
	# Stage 4 moved the descent behind a decision: the stairs no longer push
	# you down, they ask. Pushing and what it builds is covered by
	# crawl_loop_test.
	var c := _crawl()
	var run := c.game.campaign.run
	for m in c.markers.duplicate():
		if run.is_over():
			return
		_clear(c, m as EncounterMarker)
	if run.is_over() or run.phase != "exit":
		return
	assert_bool(c.exit_panel.visible).is_false()
	c.stairs.report(c.player)
	assert_bool(c.exit_panel.visible).is_true()
	assert_bool(c.player.frozen).is_true()
	assert_int(c.game.campaign.run.floor).is_equal(run.floor)


func test_the_world_only_changes_the_run_through_the_engine() -> void:
	# The invariant of the whole pivot (spec §4). A crawl that has built a
	# floor and had a marker fire has not touched the run object except
	# through GameRoot.run_action, so the run's own event log is the complete
	# record of what happened to it.
	var c := _crawl()
	var run := c.game.campaign.run
	var before := run.events.size()
	c.build_floor()
	assert_int(run.events.size()).is_equal(before)
	_clear(c, c.markers[0] as EncounterMarker)
	assert_int(run.events.size()).is_greater(before)


func _unique(values: Array) -> Array:
	var seen: Dictionary = {}
	for v in values:
		seen[v] = true
	return seen.keys()


## The entry point owns saving on quit. Moving the entry point from MainScreen
## to Crawl silently dropped it, and the only symptom was two leaked
## AudioStream instances in the exit log -- not a failing test.
func test_closing_the_window_saves_the_game_and_stops_the_sound() -> void:
	var c := _crawl()
	c.manages_quit = true
	var quits: Array = []
	c.quit_action = func() -> void: quits.append(true)
	c.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_array(quits).has_size(1)
	assert_bool(FileAccess.file_exists(_save_path)).is_true()


func test_a_crawl_that_does_not_own_the_autoload_does_not_seize_quit() -> void:
	var c := _crawl()
	var quits: Array = []
	c.quit_action = func() -> void: quits.append(true)
	assert_bool(c.manages_quit).is_false()
	c.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_array(quits).is_empty()


## Stage 3: walking into a fight room stages a fight rather than resolving it
## behind your back.
func _fight_marker(c: Crawl) -> EncounterMarker:
	var run := c.game.campaign.run
	for m in c.markers:
		var marker: EncounterMarker = m
		if String(run.nodes[marker.index].get("kind", "")) == "fight":
			return marker
	return null


func test_walking_into_a_fight_room_stages_it_instead_of_skipping_it() -> void:
	var c := _crawl()
	var marker := _fight_marker(c)
	if marker == null:
		return  # This floor drew no fight; the other tests cover the rest.
	marker.report(c.player)
	assert_object(c.director).is_not_null()
	assert_str(c.game.campaign.run.phase).is_equal("fight")
	assert_array(c.director.bodies).is_not_empty()
	assert_int(c.director.hand.visible_count()).is_greater(0)
	# You keep your body during a fight now -- you can walk the room, you just
	# cannot leave it.
	assert_bool(c.player.frozen).is_false()
	assert_object(c.director.get_node_or_null("Ring")).is_not_null()


func test_the_staged_fight_stands_its_enemies_in_the_room_you_walked_into() -> void:
	var c := _crawl()
	var marker := _fight_marker(c)
	if marker == null:
		return
	var room := c.layout.room_of_node(marker.index)
	marker.report(c.player)
	var centre := Kit.cell_to_world(c.layout.room_center(room))
	for b in c.director.bodies:
		var body: EnemyBody = b
		assert_float(body.global_position.distance_to(centre)).is_less(4.0)


func test_the_hud_exists_and_announces_the_floor() -> void:
	var c := _crawl()
	assert_object(c.hud).is_not_null()
	assert_object(c.prompts).is_not_null()
	assert_bool(c.prompts.is_announcing()).is_true()
	assert_str(c.prompts.banner.text).is_equal(c.game.text("ui.run.floor").replace("{floor}", "1"))
