extends GdUnitTestSuite

const TMP := "user://test_saves/ladder_screen_test.json"


func _game() -> GameRoot:
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = TMP
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	g.campaign.sim_fights = 4
	return g


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for suffix in ["", ".bak1", ".bak2"]:
		DirAccess.remove_absolute(TMP + suffix)


func _screen(g: GameRoot) -> LadderScreen:
	var s: LadderScreen = auto_free(LadderScreen.new())
	add_child(s)
	s.size = Vector2(480.0, 520.0)
	s.bind(g)
	return s


func test_the_tower_has_one_row_per_floor_of_the_biome() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_int(s._tower.floors).is_equal(Biomes.depth(g.content))
	# The shaft narrows with depth: that is what makes it read as going
	# away from the viewer rather than down a page.
	assert_float(s._tower.chamber_rect(10).size.x).is_less(s._tower.chamber_rect(1).size.x)
	# And darkens.
	assert_float(s._tower.light_at(10)).is_less(s._tower.light_at(1))


func test_the_founder_stands_on_the_top_row() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var bal := g.campaign.balance()
	var mods := g.campaign.modifiers()
	assert_float(g.campaign.ladder.floor_output(1, bal, mods)).is_greater(0.0)
	assert_float(g.campaign.ladder.floor_output(2, bal, mods)).is_equal(0.0)
	# One ghost mark stands on floor 1 and nothing stands below it.
	assert_int((s._tower._marks[1] as Array).size()).is_equal(1)
	assert_int((s._tower._marks[2] as Array).size()).is_equal(0)


func test_placing_an_echo_refreshes_the_tower() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	g.campaign.soul = 500.0
	var r := g.create_echo(g.campaign.ladder.ghosts[0].id, 1)
	assert_bool(r["ok"]).is_true()
	await await_idle_frame()
	assert_int((s._tower._marks[1] as Array).size()).is_equal(2)


func test_binding_twice_does_not_connect_the_signals_twice() -> void:
	var g := _game()
	var s := _screen(g)
	s.bind(g)
	await await_idle_frame()
	assert_int(g.ladder_changed.get_connections().size()).is_equal(1)
	assert_int(s._tower.floors).is_equal(Biomes.depth(g.content))


func test_the_premise_line_says_plainly_what_a_ghost_is() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var founder := g.campaign.ladder.ghosts[0]
	assert_str(s._premise.text).contains(founder.name)
	assert_str(s._premise.text).contains("Floor 1")
	assert_str(s._premise.text).contains("Soul")


func test_the_premise_follows_the_deepest_ghost() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	TestFixtures.end_at_exit(g.campaign, 3, "watch", 1000)
	s.refresh()
	await await_idle_frame()
	assert_str(s._premise.text).contains("Floor 3")


func test_the_hint_says_to_wait_when_nothing_is_affordable() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._hint.text).is_equal(g.text("ui.hint.wait"))


func test_the_hint_says_to_spend_once_an_upgrade_is_affordable() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	g.campaign.soul = 1000.0
	s.refresh()
	await await_idle_frame()
	assert_str(s._hint.text).is_equal(g.text("ui.hint.spend"))


func test_the_hint_flips_as_soul_accrues_without_a_rebind() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._hint.text).is_equal(g.text("ui.hint.wait"))
	# 20 Soul buys vigor; an hour of the Founder earns 52.
	g.clock = func() -> int: return 1000 + 3600
	g.soul_changed.emit(g.displayed_soul(), g.campaign.rate_per_hour)
	assert_str(s._hint.text).is_equal(g.text("ui.hint.spend"))


func test_the_ladder_offers_a_descent() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_str(s._descend.text).is_equal(g.text("ui.descend"))
	assert_bool(s._descend.disabled).is_false()
	s._descend.emit_signal("pressed")
	await await_idle_frame()
	assert_object(g.campaign.run).is_not_null()
	assert_int(g.campaign.run.floor).is_equal(1)


func test_the_descent_button_is_unavailable_while_a_run_is_live() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	g.start_run(1)
	s.refresh()
	await await_idle_frame()
	assert_bool(s._descend.disabled).is_true()


func test_the_entry_floor_is_bounded_by_reach() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	assert_float(s._entry.min_value).is_equal(1.0)
	assert_float(s._entry.max_value).is_equal(float(CampaignEngine.reach(g.campaign)))
	assert_bool(s._entry.editable).is_false()

	g.campaign.record_depth = 4
	s.refresh()
	await await_idle_frame()
	assert_float(s._entry.max_value).is_equal(4.0)
	assert_bool(s._entry.editable).is_true()


func test_descending_uses_the_chosen_entry_floor() -> void:
	var g := _game()
	g.campaign.record_depth = 3
	var s := _screen(g)
	await await_idle_frame()
	s._entry.value = 3.0
	s._descend.emit_signal("pressed")
	await await_idle_frame()
	assert_object(g.campaign.run).is_not_null()
	assert_int(g.campaign.run.entry_floor).is_equal(3)


func test_a_chosen_floor_survives_a_refresh() -> void:
	var g := _game()
	g.campaign.record_depth = 5
	var s := _screen(g)
	await await_idle_frame()
	s._entry.value = 4.0
	s.refresh()
	await await_idle_frame()
	assert_float(s._entry.value).is_equal(4.0)


func test_clicking_a_reachable_floor_sets_the_entry() -> void:
	var g := _game()
	g.campaign.record_depth = 4
	var s := _screen(g)
	await await_idle_frame()
	s._tower.floor_clicked.emit(3)
	assert_float(s._entry.value).is_equal(3.0)


func test_clicking_below_your_reach_does_nothing() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var before := s._entry.value
	s._tower.floor_clicked.emit(9)
	assert_float(s._entry.value).is_equal(before)


func test_the_shaft_knows_which_floor_a_point_is_in() -> void:
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	# Size it explicitly: the shaft divides its own height into chambers, so
	# a zero-height tower cannot answer this question.
	var h := s._tower.chamber_height()
	assert_float(h).is_greater(0.0)
	assert_int(s._tower._floor_at(Vector2(100.0, h * 0.5))).is_equal(1)
	assert_int(s._tower._floor_at(Vector2(100.0, h * 4.5))).is_equal(5)
	assert_int(s._tower._floor_at(Vector2(100.0, h * 9.5))).is_equal(10)
	assert_int(s._tower._floor_at(Vector2(100.0, -20.0))).is_equal(0)


## The shaft's perspective is the only thing that says "down" (spec §9). The
## masonry fill for unexcavated floors was drawn gutter-to-gutter instead of
## into the tapered chamber, which flattened floors 2-10 into one wall and is
## why the Ladder stopped reading as a tower.
func test_unexcavated_stone_is_cut_to_the_shaft_not_the_gutters() -> void:
	var g := _game()
	var s: LadderScreen = auto_free(LadderScreen.new())
	s.bind(g)
	add_child(s)
	await await_idle_frame()
	var tower := s._tower
	tower.size = Vector2(560.0, 380.0)
	for floor in [1, 5, 10]:
		assert_float(tower.solid_rect(floor).size.x) \
			.override_failure_message("floor %d's stone spills past the shaft" % floor) \
			.is_less_equal(tower.chamber_rect(floor).size.x)


func test_the_shaft_still_narrows_with_depth_where_it_is_undug() -> void:
	var g := _game()
	var s: LadderScreen = auto_free(LadderScreen.new())
	s.bind(g)
	add_child(s)
	await await_idle_frame()
	var tower := s._tower
	tower.size = Vector2(560.0, 380.0)
	assert_float(tower.solid_rect(10).size.x).is_less(tower.solid_rect(1).size.x)


## The Ladder is the store capsule, the first screenshot and the first three
## seconds of the trailer. Unreached floors are a promise; the ghosts you
## actually have are the subject, and the subject has to be the brightest
## thing on the screen.
func test_undug_rock_is_darker_than_the_chambers_you_have_reached() -> void:
	var g := _game()
	var s: LadderScreen = auto_free(LadderScreen.new())
	s.bind(g)
	add_child(s)
	await await_idle_frame()
	var tower := s._tower
	assert_float(Palette.luma(tower.undug_colour(10))) \
		.override_failure_message("the floors you cannot reach outshine the one you can") \
		.is_less(Palette.luma(tower.chamber_colour(1)))


func test_undug_rock_gets_darker_the_deeper_it_goes() -> void:
	var g := _game()
	var s: LadderScreen = auto_free(LadderScreen.new())
	s.bind(g)
	add_child(s)
	await await_idle_frame()
	var tower := s._tower
	assert_float(Palette.luma(tower.undug_colour(10))).is_less(Palette.luma(tower.undug_colour(2)))


func test_no_floor_of_the_shaft_is_a_hole() -> void:
	# The undug fade was a fixed step per floor written for a ten-floor shaft,
	# and it went negative at floor 16 the day the shaft became twenty deep --
	# a black rectangle in the middle of the game's own capsule image.
	var g := _game()
	var s := _screen(g)
	await await_idle_frame()
	var tower: TowerView = s._tower
	for floor in range(1, tower.floors + 1):
		assert_float(tower.solid_light(floor)).override_failure_message(
			"floor %d of %d has no light in it at all" % [floor, tower.floors]) \
			.is_greater(0.05)


func test_the_shaft_changes_colour_where_the_biome_does() -> void:
	# Spec §9's colour bands, which are most of what says the descent goes
	# somewhere rather than just down.
	var g := _game()
	assert_object(Palette.biome_accent(g.campaign.biome_at(1).id)) \
		.is_not_equal(Palette.biome_accent(g.campaign.biome_at(14).id))
