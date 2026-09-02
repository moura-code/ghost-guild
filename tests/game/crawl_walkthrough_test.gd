extends GdUnitTestSuite
## The chain no other suite covers: real key presses -> the physics server ->
## an Area3D overlap -> focus -> interact -> a panel on screen.
##
## Every link here is one the headless suite CAN exercise (physics and
## Input.action_press both work), and every one of them is a link that has
## broken at least once in this pivot without a single test noticing.

const TMP := "user://test_saves/crawl_walkthrough_test.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_CFG))


func after_test() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(action)


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 4
	return g


const TMP_CFG := "user://test_saves/crawl_walkthrough_test.cfg"


func _crawl(g: GameRoot) -> Crawl:
	var c: Crawl = auto_free(Crawl.new())
	c.game = g
	# These are the game's tests, not the menu's: start already playing.
	c.show_title = false
	# Set before the tree sees it, like `game`: otherwise the crawl reads and
	# writes the developer's real settings.cfg.
	c.settings_path = TMP_CFG
	add_child(c)
	c.bind(g)
	return c


## Stands the player a few metres short of a station and walks it in.
func _walk_into(c: Crawl, id: String) -> void:
	var station := c.guild.station(id)
	var at := station.global_position
	c.player.place_at(at + Vector3(0.0, 0.0, 3.2), 0.0)
	await await_millis(150)
	Input.action_press("move_forward")
	await await_millis(900)
	Input.action_release("move_forward")
	await await_millis(120)


func test_you_can_walk_across_the_guild_and_the_floor_holds_you_up() -> void:
	var c := _crawl(_game())
	c.player.place_at(c.guild.spawn_point(), 0.0)
	await await_millis(200)
	var from := c.player.position
	Input.action_press("move_forward")
	await await_millis(700)
	Input.action_release("move_forward")
	assert_float(c.player.position.distance_to(from)).override_failure_message(
		"the player did not move").is_greater(1.0)
	assert_bool(c.player.is_on_floor()).override_failure_message(
		"the player fell through the guild floor").is_true()


func test_walking_into_a_station_focuses_it_and_says_what_it_does() -> void:
	var c := _crawl(_game())
	await _walk_into(c, GuildRoom.DESK)
	assert_object(c.focused).override_failure_message("walked in and nothing focused").is_not_null()
	assert_str(c.focused.id).is_equal(GuildRoom.DESK)
	assert_bool(c.prompts.has_prompt()).is_true()


func test_pressing_e_where_you_are_standing_opens_that_panel() -> void:
	var c := _crawl(_game())
	await _walk_into(c, GuildRoom.TABLE)
	if c.focused == null:
		fail("never reached the table")
		return
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	c._unhandled_input(press)
	assert_bool(c.panel_open()).override_failure_message("E opened nothing").is_true()
	assert_bool(c.player.frozen).is_true()
	assert_bool(c.hud.pointer_free).is_true()


func test_escape_closes_the_panel_and_gives_you_your_body_back() -> void:
	var c := _crawl(_game())
	await _walk_into(c, GuildRoom.CIRCLE)
	if c.focused == null:
		fail("never reached the circle")
		return
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	c._unhandled_input(press)
	assert_bool(c.panel_open()).is_true()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	# The body sees it first and must not act on it while frozen.
	c.player._unhandled_input(escape)
	c._unhandled_input(escape)
	assert_bool(c.panel_open()).is_false()
	assert_bool(c.player.frozen).is_false()
	assert_bool(c.hud.pointer_free).is_false()


func test_you_cannot_walk_out_through_a_guild_wall() -> void:
	var c := _crawl(_game())
	# Face the near wall and push into it for a second and a half.
	c.player.place_at(Kit.cell_to_world(Vector2i(2, GuildRoom.DEPTH)), 0.0)
	await await_millis(150)
	Input.action_press("move_back")
	await await_millis(1400)
	Input.action_release("move_back")
	var cell := Kit.world_to_cell(c.player.position)
	assert_bool(c.guild.layout.is_walkable(cell.x, cell.y)).override_failure_message(
		"walked out of the guild to %s" % cell).is_true()


func test_you_cannot_walk_into_the_well() -> void:
	# The builder's ground slab runs under the whole room, so without the well
	# head the player strolls out over the shaft on invisible collision.
	var c := _crawl(_game())
	var well := Kit.cell_to_world(GuildRoom.WELL_CELL)
	c.player.place_at(well + Vector3(0.0, 0.0, 3.4), 0.0)
	await await_millis(150)
	Input.action_press("move_forward")
	await await_millis(1400)
	Input.action_release("move_forward")
	var cell := Kit.world_to_cell(c.player.position)
	assert_vector(cell).override_failure_message("fell down the well").is_not_equal(GuildRoom.WELL_CELL)
	assert_bool(c.player.is_on_floor()).is_true()


## Escape used to mean three different things depending on which node saw the
## key first. Now it means one thing: close the topmost thing that can be
## closed, and if nothing is open, pause.
func _escape(c: Crawl) -> void:
	var key := InputEventAction.new()
	key.action = "ui_cancel"
	key.pressed = true
	c.player._unhandled_input(key)
	c._unhandled_input(key)


func test_escape_in_an_empty_room_pauses() -> void:
	var c := _crawl(_game())
	assert_bool(c.panel_open()).is_false()
	_escape(c)
	assert_object(c.panel).is_same(c.pause)
	assert_bool(c.player.frozen).is_true()


func test_escape_out_of_the_pause_menu_gives_you_the_game_back() -> void:
	var c := _crawl(_game())
	_escape(c)
	c.pause.press(PauseMenu.RESUME)
	assert_bool(c.panel_open()).is_false()
	assert_bool(c.player.frozen).is_false()
	assert_bool(c.hud.pointer_free).is_false()


func test_options_open_from_pause_and_escape_walks_back_up_one_level() -> void:
	var c := _crawl(_game())
	_escape(c)
	c.pause.press(PauseMenu.OPTIONS)
	assert_object(c.panel).is_same(c.options)
	_escape(c)
	# Back to the pause menu, not straight out into the room.
	assert_object(c.panel).is_same(c.pause)


func test_escape_over_a_guild_panel_closes_the_panel_first() -> void:
	var c := _crawl(_game())
	var station := c.guild.station(GuildRoom.DESK)
	station.enter(c.player)
	station.use()
	assert_bool(c.panel_open()).is_true()
	_escape(c)
	assert_bool(c.panel_open()).is_false()


func test_changing_a_setting_reaches_the_body_and_is_written_down() -> void:
	var c := _crawl(_game())
	_escape(c)
	c.pause.press(PauseMenu.OPTIONS)
	(c.options.sliders["sensitivity"] as HSlider).value = 2.0
	assert_float(c.player.sensitivity_scale).is_equal_approx(2.0, 0.001)
	assert_float(Settings.load_from(TMP_CFG).sensitivity).is_equal_approx(2.0, 0.001)


func test_a_panel_darkens_the_room_behind_it() -> void:
	var c := _crawl(_game())
	_escape(c)
	await await_millis(220)
	assert_float(c.hud.dim.color.a).is_greater(0.4)


func test_you_can_give_up_a_run_from_the_pause_menu() -> void:
	var g := _game()
	var c := _crawl(g)
	g.start_run(1)
	var guard := 0
	while g.campaign.run != null and g.campaign.run.phase == "descent" and guard < 20:
		guard += 1
		c.choice.take(0)
	assert_int(c.place).is_equal(Crawl.Place.DUNGEON)
	_escape(c)
	assert_bool(c.pause.buttons.has(PauseMenu.ABANDON)).is_true()
	c.pause.press(PauseMenu.ABANDON)
	# The engine ended it as a retreat, the epitaph did not fire (nobody was
	# left behind), and you are home.
	assert_int(c.place).is_equal(Crawl.Place.GUILD)
	assert_object(g.campaign.run).is_null()


func test_the_guild_pause_menu_has_nothing_to_give_up() -> void:
	var c := _crawl(_game())
	_escape(c)
	assert_bool(c.pause.buttons.has(PauseMenu.ABANDON)).is_false()


## The title is the one panel Escape cannot dismiss into a running game.
func _titled(g: GameRoot) -> Crawl:
	var c: Crawl = auto_free(Crawl.new())
	c.game = g
	c.settings_path = TMP_CFG
	add_child(c)
	c.bind(g)
	return c


func test_the_game_opens_on_its_title() -> void:
	var c := _titled(_game())
	assert_object(c.panel).is_same(c.title)
	assert_bool(c.player == null or c.player.frozen).is_true()


func test_escape_cannot_dismiss_the_title_into_a_running_game() -> void:
	var c := _titled(_game())
	_escape(c)
	assert_object(c.panel).is_same(c.title)


func test_continue_puts_you_in_the_world() -> void:
	var c := _titled(_game())
	c.title.press(TitleMenu.CONTINUE if c.title.buttons.has(TitleMenu.CONTINUE) else TitleMenu.NEW)
	assert_bool(c.panel_open()).is_false()
	assert_int(c.place).is_not_equal(Crawl.Place.NONE)


func test_a_new_guild_throws_the_old_one_away() -> void:
	var g := _game()
	var c := _titled(g)
	for i in 3:
		var ghost := Ghost.founder(g.content, 1000)
		ghost.floor = 2 + i
		g.campaign.ladder.add(ghost)
	var before := g.campaign.ladder.ghosts.size()
	c.title.press(TitleMenu.NEW)
	assert_int(g.campaign.ladder.ghosts.size()).is_less(before)
	assert_int(c.place).is_equal(Crawl.Place.GUILD)


func test_options_from_the_title_go_back_to_the_title() -> void:
	var c := _titled(_game())
	c.title.press(TitleMenu.OPTIONS)
	assert_object(c.panel).is_same(c.options)
	_escape(c)
	assert_object(c.panel).is_same(c.title)


func test_the_body_that_walks_the_guild_is_wired_to_the_sound_that_answers_it() -> void:
	# The one link in the footstep chain that is neither Stride's maths nor
	# Sfx's rotation: that Crawl actually connected the two. It has exactly one
	# failure mode -- silence -- and silence is the hardest bug to notice.
	var c := _crawl(_game())
	assert_object(c.player).is_not_null()
	assert_bool(c.player.footfall.is_connected(c.game.sfx.step)) \
		.override_failure_message("nothing is listening to the player's feet").is_true()
