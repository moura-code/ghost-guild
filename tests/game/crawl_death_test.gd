extends GdUnitTestSuite
## Stage 6: the run ends, the world does not cut.
##
## The hero falls, a ghost rises where it fell, and the epitaph fades up over
## the room it died in -- the killer still standing there. This is the shot the
## trailer opens on (spec §8), so it is a sequence with beats and not a screen
## swap.

const TMP := "user://test_saves/crawl_death_test.json"


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


## Descends, gets onto a floor, then kills the hero in the room it is standing
## in -- through the engine, the way the game would.
func _die(g: GameRoot, c: Crawl) -> Dictionary:
	var run := g.start_run(1)
	var guard := 0
	while run.phase == "descent" and guard < 20:
		guard += 1
		c.choice.take(0)
	TestFixtures.set_nodes(run, [{"kind": "fight", "enemies": ["mother_of_bones", "mother_of_bones"]}])
	c.build_floor()
	run.hero.hp = 1
	(c.markers[0] as EncounterMarker).report(c.player)
	TestFixtures.autofight(run)
	if c.director != null:
		c.director.check_over()
	# Asserted rather than returned as a maybe: a hero on 1 hp against two
	# copies of the boss has to die, and if it ever stops dying these tests
	# would all pass by doing nothing.
	assert_bool(run.is_over()).override_failure_message("the hero survived a rigged death").is_true()
	return {"over": run.is_over()}


func test_a_death_raises_a_ghost_where_the_hero_fell() -> void:
	var g := _game()
	var c := _crawl(g)
	if not bool(_die(g, c)["over"]):
		return  # The hero survived; nothing to mourn.
	var risen: Array = []
	for child in c.get_node("World").get_children():
		if child is GhostFigure:
			risen.append(child)
	assert_array(risen).override_failure_message("nobody rose").is_not_empty()


func test_the_epitaph_comes_up_over_the_room_and_not_over_a_new_one() -> void:
	var g := _game()
	var c := _crawl(g)
	if not bool(_die(g, c)["over"]):
		return
	assert_object(c.panel).is_same(c.epitaph)
	assert_bool(c.epitaph.visible).is_true()
	# Still underground: the world does not cut away while you are being
	# mourned.
	assert_int(c.place).is_equal(Crawl.Place.DUNGEON)
	assert_object(c.guild).is_null()


func test_dismissing_the_epitaph_brings_you_home() -> void:
	var g := _game()
	var c := _crawl(g)
	if not bool(_die(g, c)["over"]):
		return
	c._on_epitaph_dismissed()
	assert_int(c.place).is_equal(Crawl.Place.GUILD)
	assert_object(c.guild).is_not_null()
	assert_bool(c.panel_open()).is_true()
	assert_object(c.panel).is_same(c.recap)
	c.close_panel()
	assert_bool(c.panel_open()).is_false()


func test_the_hero_you_just_lost_is_standing_in_the_well() -> void:
	var g := _game()
	var c := _crawl(g)
	if not bool(_die(g, c)["over"]):
		return
	var dead := g.campaign.ladder.ghosts.size()
	c._on_epitaph_dismissed()
	assert_array(c.guild.well.figures).has_size(dead)
	assert_int(dead).is_greater(1)


func test_a_retreat_is_not_a_death_and_earns_no_beat() -> void:
	# Nobody was left behind, so there is nothing to memorialise and nothing
	# rises.
	var g := _game()
	var c := _crawl(g)
	var run := g.start_run(1)
	var guard := 0
	while run.phase == "descent" and guard < 20:
		guard += 1
		c.choice.take(0)
	TestFixtures.set_nodes(run, [{"kind": "rest"}])
	c.build_floor()
	RunEngine.apply(run, {"kind": "enter"})
	RunEngine.apply(run, {"kind": "rest_heal"})
	g.run_action({"kind": "retreat"})
	assert_bool(run.is_over()).is_true()
	assert_bool(c.epitaph.visible).is_false()
	assert_int(c.place).is_equal(Crawl.Place.GUILD)


func test_the_beat_is_not_interrupted_by_the_run_changing_under_it() -> void:
	# finish_run fires run_changed, which re-enters _sync. Without the
	# mourning guard that would tear the epitaph down on the same frame it
	# went up, and the player would never see it.
	var g := _game()
	var c := _crawl(g)
	if not bool(_die(g, c)["over"]):
		return
	c._sync()
	c._sync()
	assert_bool(c.epitaph.visible).is_true()
	assert_int(c.place).is_equal(Crawl.Place.DUNGEON)
