extends GdUnitTestSuite


func test_catalogue_and_saved_recipes_survive_a_content_update_without_rng_changes() -> void:
	var c := Content.load_from("res://data")
	assert_array(RoomPresets.validate(c)).is_empty()
	for biome in c.biomes:
		var count := 0
		for recipe in c.room_presets.values():
			if recipe["biome"] == biome:
				count += 1
		assert_int(count).is_greater_equal(6 if biome == "catacombs" else 4)
	var run := RunEngine.start_run(c, Hero.create(c, "sexton", "Saved"), 1, 199, true)
	var saved := run.to_dict()
	var layout := RunEngine.layout_for(run).to_dict()
	for recipe in c.room_presets.values():
		recipe["composition"] = "furnace"
		recipe["weight"] = 20
	var back := RunState.from_dict(c, saved)
	assert_dict(RunEngine.layout_for(back).to_dict()).is_equal(layout)
	RunEngine.apply(run, {"kind": "enter", "index": 0})
	RunEngine.apply(back, {"kind": "enter", "index": 0})
	assert_dict(run.fight.to_dict()).is_equal(back.fight.to_dict())


func test_recipe_validation_rejects_unsupported_anchors_budgets_and_dimensions() -> void:
	var c := Content.load_from("res://data")
	var recipe: Dictionary = c.room_presets.values()[0]
	for pair in [["weight", "many"], ["ambient_budget", 9], ["light_budget", 1], ["prop_sockets", "center"], ["roles", ["trap"]], ["max_size", 2]]:
		var invalid := recipe.duplicate(true)
		invalid[pair[0]] = pair[1]
		assert_bool(RoomPresets.valid_recipe(invalid)).is_false()


func test_presets_respect_role_dimensions_and_floor_repeat_limits_over_100_seeds() -> void:
	var c := TestFixtures.content()
	for seed in 100:
		for floor in [1, 11, 21]:
			var nodes := FloorGenerator.generate(c, Biomes.for_floor(c, floor), floor, Rng.new(seed))
			var layout := LayoutGenerator.generate_current(nodes, Rng.new(seed))
			var presets := RoomPresets.choose(c, layout, nodes, Biomes.for_floor(c, floor).id, Rng.new(seed))
			for i in nodes.size():
				var room := layout.room_of_node(i)
				var id: String = presets[room]
				assert_str(id).is_not_equal("neutral")
				var recipe: Dictionary = c.room_presets[id]
				assert_bool(recipe["roles"].has(nodes[i]["kind"])).is_true()
				assert_int(presets.count(id)).is_less_equal(recipe["repeat_limit"])
