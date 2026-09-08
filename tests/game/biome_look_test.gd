extends GdUnitTestSuite
## A biome you can see you are in (spec §9: one accent per biome).
##
## One grade for the whole game is the rule -- one tonemap, one fog model, one
## ambient, over every asset, because that is what makes mixed CC0 sources look
## like one game. What a biome changes is the colour of the air inside that
## grade, which is a different claim and the one worth asserting.


func _content() -> Content:
	return TestFixtures.content()


func test_the_catacombs_are_the_grade_the_game_was_built_in() -> void:
	# Every screenshot and every judgement about the look was made here, so
	# the biome tint has to be an identity for it by construction.
	var plain := Grade.environment(0.4)
	var home := Grade.environment(0.4, "catacombs")
	assert_float(home.fog_light_color.r).is_equal_approx(plain.fog_light_color.r, 0.0001)
	assert_float(home.fog_light_color.g).is_equal_approx(plain.fog_light_color.g, 0.0001)
	assert_float(home.fog_light_color.b).is_equal_approx(plain.fog_light_color.b, 0.0001)
	assert_float(home.ambient_light_color.b).is_equal_approx(plain.ambient_light_color.b, 0.0001)


func test_an_unknown_biome_changes_nothing() -> void:
	var plain := Grade.environment(0.4)
	var junk := Grade.environment(0.4, "no_such_biome")
	assert_float(junk.fog_light_color.b).is_equal_approx(plain.fog_light_color.b, 0.0001)


func test_the_deep_is_colder_and_more_violet_than_the_catacombs() -> void:
	var home := Grade.environment(0.6, "catacombs")
	var deep := Grade.environment(0.6, "fungal_deep")
	assert_float(deep.fog_light_color.b).override_failure_message(
		"the Deep's air is not any more violet than the Catacombs'") \
		.is_greater(home.fog_light_color.b)
	assert_float(deep.fog_light_color.g).is_less(home.fog_light_color.g)


func test_the_kiln_is_warmer_than_both() -> void:
	# It has no content yet, but its accent is authored and the grade has to
	# already do the right thing with it -- otherwise the biome that ships
	# last is the one that discovers this function is wrong.
	var deep := Grade.environment(0.6, "fungal_deep")
	var kiln := Grade.environment(0.6, "the_kiln")
	assert_float(kiln.fog_light_color.r).is_greater(deep.fog_light_color.r)
	assert_float(kiln.fog_light_color.b).is_less(deep.fog_light_color.b)


func test_the_grade_itself_is_the_same_everywhere() -> void:
	# The tint moves the light, never the grade. A biome that tonemapped
	# differently would be a different game rendered next to this one.
	var home := Grade.environment(0.5, "catacombs")
	var deep := Grade.environment(0.5, "fungal_deep")
	assert_int(deep.tonemap_mode).is_equal(home.tonemap_mode)
	assert_float(deep.tonemap_white).is_equal(home.tonemap_white)
	assert_float(deep.adjustment_saturation).is_equal(home.adjustment_saturation)
	assert_float(deep.adjustment_contrast).is_equal(home.adjustment_contrast)
	assert_float(deep.fog_density).is_equal(home.fog_density)
	assert_bool(deep.ssao_enabled).is_equal(home.ssao_enabled)


func test_the_light_stays_inside_the_range_a_colour_has() -> void:
	# The tint is an offset, and an offset can walk a channel off either end.
	for id in ["catacombs", "fungal_deep", "the_kiln"]:
		for depth in [0.0, 0.5, 1.0]:
			var env := Grade.environment(depth, id)
			for c in [env.fog_light_color, env.ambient_light_color]:
				for channel in [c.r, c.g, c.b]:
					assert_float(channel).override_failure_message(
						"%s at depth %.1f has a channel outside 0..1" % [id, depth]) \
						.is_between(0.0, 1.0)


func _crawl_banner(entry: int, floors: Array) -> Array:
	# The banner text for a run that starts at `entry` and walks `floors`.
	var g: GameRoot = auto_free(GameRoot.new())
	g.save_path = "user://test_saves/biome_look_test.json"
	g.autosave_seconds = 0.0
	g.clock = func() -> int: return 1000
	add_child(g)
	g.boot()
	var c: Crawl = auto_free(Crawl.new())
	c.game = g
	add_child(c)
	c.bind(g)
	var run := RunEngine.start_run(g.content, Hero.create(g.content, "sexton", "T"), entry, 4, true)
	var out: Array = []
	for floor in floors:
		run.floor = int(floor)
		out.append(c.floor_banner(run))
	return out


func test_the_banner_names_a_biome_only_where_that_is_news() -> void:
	var said := _crawl_banner(9, [9, 10, 11, 12])
	assert_str(String(said[0])).contains(_content().text("biome.catacombs.name"))
	assert_str(String(said[1])).not_contains(_content().text("biome.catacombs.name"))
	assert_str(String(said[2])).override_failure_message(
		"crossing into the Deep did not say so") \
		.contains(_content().text("biome.fungal_deep.name"))
	assert_str(String(said[3])).not_contains(_content().text("biome.fungal_deep.name"))
	for line in said:
		assert_str(String(line)).contains("Floor")

func test_the_second_cycle_is_lit_like_the_first() -> void:
	# Floor 34 is the Catacombs again (§2), and grading it like the bottom of the
	# Kiln would leave every floor past thirty the same colour -- the bands are
	# the only thing on screen saying which biome you are standing in.
	var c := _content()
	var depth := Biomes.depth(c)
	assert_float(Crawl.grade_depth(c, depth + 4)).is_equal(Crawl.grade_depth(c, 4))
	assert_float(Crawl.grade_depth(c, depth * 3 + 4)).is_equal(Crawl.grade_depth(c, 4))
	# And it still darkens as you descend inside a cycle.
	assert_float(Crawl.grade_depth(c, depth + 20)).is_greater(Crawl.grade_depth(c, depth + 4))
