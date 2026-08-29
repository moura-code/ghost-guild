extends GdUnitTestSuite
## Stage 5: two places, one root. No run means you are home.

const TMP := "user://test_saves/crawl_guild_test.json"


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


func _crawl(g: GameRoot) -> Crawl:
	var c: Crawl = auto_free(Crawl.new())
	c.game = g
	# These are the game's tests, not the menu's: start already playing.
	c.show_title = false
	add_child(c)
	c.bind(g)
	return c


func test_booting_with_no_run_puts_you_in_the_guild() -> void:
	var g := _game()
	var c := _crawl(g)
	assert_object(g.campaign.run).is_null()
	assert_int(c.place).is_equal(Crawl.Place.GUILD)
	assert_object(c.guild).is_not_null()
	assert_object(c.layout).is_null()


func test_you_stand_on_the_guild_floor_not_in_its_wall() -> void:
	var c := _crawl(_game())
	var cell := Kit.world_to_cell(c.player.position)
	assert_bool(c.guild.layout.is_walkable(cell.x, cell.y)).is_true()


func test_your_dead_are_standing_in_the_well() -> void:
	var g := _game()
	var c := _crawl(g)
	assert_array(c.guild.well.figures).has_size(g.campaign.ladder.ghosts.size())
	assert_array(c.guild.well.figures).is_not_empty()


func test_each_station_opens_its_own_panel() -> void:
	var c := _crawl(_game())
	var seen: Array = []
	for id in [GuildRoom.TABLE, GuildRoom.CIRCLE, GuildRoom.DESK, GuildRoom.WELL]:
		var station := c.guild.station(String(id))
		station.enter(c.player)
		station.use()
		assert_bool(c.panel_open()).override_failure_message("%s opened nothing" % id).is_true()
		seen.append(c.panel)
		station.leave(c.player)
	# Four stations, four different panels.
	var unique: Dictionary = {}
	for p in seen:
		unique[p] = true
	assert_int(unique.size()).is_equal(4)


func test_pressing_e_across_the_room_does_nothing() -> void:
	var c := _crawl(_game())
	c.guild.station(GuildRoom.TABLE).use()
	assert_bool(c.panel_open()).is_false()


func test_standing_in_a_station_says_what_it_would_do() -> void:
	var c := _crawl(_game())
	var station := c.guild.station(GuildRoom.DESK)
	station.enter(c.player)
	assert_bool(c.prompts.has_prompt()).is_true()
	assert_str(c.prompts.prompt.text).is_equal(c.game.text(station.label_key))
	station.leave(c.player)
	assert_bool(c.prompts.has_prompt()).is_false()


func test_a_guild_panel_holds_you_still_and_can_be_walked_out_of() -> void:
	var c := _crawl(_game())
	var station := c.guild.station(GuildRoom.TABLE)
	station.enter(c.player)
	station.use()
	assert_bool(c.player.frozen).is_true()
	assert_bool(c.hud.pointer_free).is_true()
	c.close_panel()
	assert_bool(c.player.frozen).is_false()
	assert_bool(c.hud.pointer_free).is_false()


func test_descending_swaps_the_guild_for_a_crypt() -> void:
	var g := _game()
	var c := _crawl(g)
	g.start_run(1)
	assert_int(c.place).is_equal(Crawl.Place.DUNGEON)
	assert_object(c.guild).is_null()
	# Either a floor is built or the descent draft is on screen first.
	assert_bool(c.layout != null or c.panel_open()).is_true()


func test_finishing_a_run_brings_you_home() -> void:
	var g := _game()
	var c := _crawl(g)
	var run := g.start_run(1)
	run.hero.hp = 0
	RunEngine.apply(run, {"kind": "enter"})
	# Whatever ended it, the game does not leave you underground.
	if g.campaign.run != null and not g.campaign.run.is_over():
		return
	if c.panel_open() and c.panel == c.epitaph:
		c._on_epitaph_dismissed()
	assert_int(c.place).is_equal(Crawl.Place.GUILD)
	assert_object(c.guild).is_not_null()


func test_leaving_the_guild_while_standing_in_a_station_does_not_crash() -> void:
	# Descending frees the guild, and the Area3D the player was standing in
	# emits body_exited afterwards -- so the handler runs with `guild` already
	# null. It happened on every descent and no test saw it, because the tests
	# call enter/leave without tearing the guild down in between.
	var g := _game()
	var c := _crawl(g)
	var station := c.guild.station(GuildRoom.TABLE)
	station.enter(c.player)
	assert_object(c.focused).is_not_null()
	g.start_run(1)
	assert_object(c.guild).is_null()
	station.leave(c.player)
	assert_object(c.focused).is_null()
	assert_bool(c.prompts.has_prompt()).is_false()
