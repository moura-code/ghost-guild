extends GdUnitTestSuite


func _biome() -> BiomeDef:
	return TestFixtures.content().biomes["catacombs"]


func test_floor_has_three_nodes_from_a_known_pattern() -> void:
	var nodes := FloorGenerator.generate(TestFixtures.content(), _biome(), 1, Rng.new(1))
	assert_array(nodes).has_size(3)
	var kinds: Array = []
	for node in nodes:
		kinds.append(node["kind"])
		assert_bool(["fight", "elite", "event", "rest", "shop"].has(node["kind"])).is_true()
	assert_bool(_biome().node_patterns.has(kinds)).is_true()


func test_fight_nodes_draw_from_the_floor_bucket() -> void:
	for seed in 12:
		var group := FloorGenerator.encounter_for(_biome(), 2, Rng.new(seed))
		assert_bool([["bone_rat"], ["bone_rat", "bone_rat"], ["grave_wisp"], ["shambler"]].has(group)).is_true()
	var deep := FloorGenerator.encounter_for(_biome(), 9, Rng.new(1))
	assert_bool([["hollow_knight"], ["plague_bearer", "bone_archer"], ["skull_stack", "crypt_spider"], ["shambler", "shambler", "bone_rat"]].has(deep)).is_true()


func test_last_floor_ends_with_the_boss() -> void:
	for seed in 6:
		var nodes := FloorGenerator.generate(TestFixtures.content(), _biome(), 10, Rng.new(seed))
		var last: Dictionary = nodes[2]
		assert_str(last["kind"]).is_equal("boss")
		assert_array(last["enemies"]).is_equal(["mother_of_bones"])
	var nodes9 := FloorGenerator.generate(TestFixtures.content(), _biome(), 9, Rng.new(1))
	assert_str(nodes9[2]["kind"]).is_not_equal("boss")


func test_generation_is_deterministic_per_seed() -> void:
	var a := FloorGenerator.generate(TestFixtures.content(), _biome(), 5, Rng.new(9))
	var b := FloorGenerator.generate(TestFixtures.content(), _biome(), 5, Rng.new(9))
	assert_array(a).is_equal(b)
	var seen := {}
	for seed in 20:
		seen[str(FloorGenerator.generate(TestFixtures.content(), _biome(), 5, Rng.new(seed)))] = true
	assert_int(seen.size()).is_greater(1)


func test_elite_nodes_use_the_elite_table() -> void:
	var found := false
	for seed in 30:
		for node in FloorGenerator.generate(TestFixtures.content(), _biome(), 4, Rng.new(seed)):
			if node["kind"] == "elite":
				found = true
				assert_array(node["enemies"]).is_equal(["ossuary_warden"])
	assert_bool(found).is_true()


func test_events_are_not_repeated_and_fall_back_to_rest() -> void:
	var content := TestFixtures.content()
	var first := FloorGenerator.pick_event(content, "catacombs", [], Rng.new(1))
	assert_bool(content.events.has(first)).is_true()
	var second := FloorGenerator.pick_event(content, "catacombs", [first], Rng.new(1))
	assert_str(second).is_not_equal(first)
	assert_str(FloorGenerator.pick_event(content, "catacombs", content.events.keys(), Rng.new(1))).is_equal("")
	var all_used: Array = content.events.keys()
	for seed in 30:
		for node in FloorGenerator.generate(content, _biome(), 3, Rng.new(seed), all_used):
			assert_str(node["kind"]).is_not_equal("event")


func test_event_nodes_carry_an_event_id() -> void:
	var found := false
	for seed in 30:
		for node in FloorGenerator.generate(TestFixtures.content(), _biome(), 3, Rng.new(seed)):
			if node["kind"] == "event":
				found = true
				assert_bool(TestFixtures.content().events.has(node["event"])).is_true()
	assert_bool(found).is_true()
