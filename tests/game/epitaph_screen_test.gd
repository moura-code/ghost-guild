extends GdUnitTestSuite

const TMP := "user://test_saves/epitaph_screen_test.json"


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


func _screen(g: GameRoot, result: Dictionary, paced: bool = false) -> EpitaphScreen:
	var s: EpitaphScreen = auto_free(EpitaphScreen.new())
	s.paced = paced
	add_child(s)
	s.size = Vector2(720.0, 520.0)
	s.bind(g, result)
	return s


func test_only_a_run_that_left_a_ghost_earns_the_beat() -> void:
	assert_bool(EpitaphScreen.should_show({})).is_false()
	assert_bool(EpitaphScreen.should_show({"kind": "retreat", "ghost_id": 0})).is_false()
	assert_bool(EpitaphScreen.should_show({"kind": "death", "ghost_id": 3})).is_true()


func test_a_death_names_the_hero_and_reads_their_epitaph() -> void:
	var g := _game()
	var name_before := g.campaign.hero.name
	var result := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	var s := _screen(g, result)
	await await_idle_frame()
	assert_str(s._name.text).is_equal(name_before)
	assert_str(s._epitaph.text).is_equal(String(result["epitaph"]))
	assert_str(s._epitaph.text).contains(name_before)
	assert_str(s._epitaph.text).contains("2")


func test_it_says_where_they_now_stand_and_what_they_brought_home() -> void:
	var g := _game()
	var result := TestFixtures.die_on_floor(g.campaign, 3, 1000)
	var s := _screen(g, result)
	await await_idle_frame()
	assert_str(s._floor.text).contains("3")
	assert_str(s._floor.text).is_not_equal("ui.epitaph.stands")
	assert_str(s._soul.text).contains(Num.short(float(result["soul"])))


func test_the_ghost_mark_shows_a_restless_death() -> void:
	var g := _game()
	var result := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	var s := _screen(g, result)
	await await_idle_frame()
	assert_bool(s._mark.restless).is_true()
	assert_that(s._mark.body_color()).is_equal(Palette.RESTLESS)


func test_the_first_death_carries_the_rite_and_a_later_one_does_not() -> void:
	var g := _game()
	var first := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	var s := _screen(g, first)
	await await_idle_frame()
	assert_str(s._rite.text).is_equal(g.text("ui.epitaph.rite"))
	assert_bool(s._rite.visible).is_true()
	assert_int(s.stage_count()).is_equal(5)

	var second := TestFixtures.die_on_floor(g.campaign, 2, 2000)
	var s2 := _screen(g, second)
	await await_idle_frame()
	assert_str(s2._rite.text).is_equal("")
	assert_bool(s2._rite.visible).is_false()
	assert_int(s2.stage_count()).is_equal(4)


func test_unpaced_it_shows_everything_at_once() -> void:
	var g := _game()
	var result := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	var s := _screen(g, result)
	await await_idle_frame()
	assert_int(s.stage).is_equal(s.stage_count())
	assert_bool(s._name.visible).is_true()
	assert_bool(s._arrival.visible).is_true()
	assert_bool(s._dismiss.visible).is_true()


func test_paced_it_withholds_the_dismiss_button_until_the_beat_has_played() -> void:
	var g := _game()
	var result := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	var s := _screen(g, result, true)
	await await_idle_frame()
	assert_int(s.stage).is_equal(1)
	assert_bool(s._name.visible).is_true()
	assert_bool(s._epitaph.visible).is_false()
	assert_bool(s._dismiss.visible).is_false()


func test_an_impatient_player_can_skip_to_the_end() -> void:
	var g := _game()
	var result := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	var s := _screen(g, result, true)
	await await_idle_frame()
	s.reveal_all()
	assert_bool(s._dismiss.visible).is_true()
	assert_int(s.stage).is_equal(s.stage_count())


func test_dismissing_reports_once() -> void:
	var g := _game()
	var result := TestFixtures.die_on_floor(g.campaign, 2, 1000)
	var s := _screen(g, result)
	var seen := [0]
	s.dismissed.connect(func() -> void: seen[0] += 1)
	s._dismiss.emit_signal("pressed")
	await await_idle_frame()
	assert_int(seen[0]).is_equal(1)


func test_taking_the_watch_leaves_a_prepared_ghost_not_a_restless_one() -> void:
	var g := _game()
	g.campaign.onboarding.watch_unlocked = true
	var result := TestFixtures.end_at_exit(g.campaign, 2, "watch", 1000)
	var s := _screen(g, result)
	await await_idle_frame()
	assert_bool(s._mark.restless).is_false()
	assert_bool(s._mark.prepared).is_true()
	assert_str(s._epitaph.text).contains("watch")
