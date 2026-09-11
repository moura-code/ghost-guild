extends GdUnitTestSuite


func test_history_uses_existing_achievements_and_survives_prestige() -> void:
	var c := TestFixtures.campaign()
	# The Founder already claims the Catacombs for a fresh guild.
	assert_array(GuildHistory.entries(c)).has_size(1)
	assert_str(GuildHistory.entries(c)[0]["key"]).is_equal("catacombs")
	for floor in [14, 24]:
		var ghost := Ghost.from_expedition(c.hero, floor, 1000)
		ghost.fixed_strength = true
		ghost.strength = 180
		c.ladder.add(ghost)
	c.expedition_counter = 2
	var before := c.to_dict()
	var entries := GuildHistory.entries(c)
	assert_dict(c.to_dict()).is_equal(before)
	assert_int(entries.size()).is_greater_equal(3)
	assert_bool(CampaignEngine.prestige(c, 1000)["ok"]).is_true()
	var after := GuildHistory.entries(c)
	for entry in entries:
		assert_bool(after.has(entry)).is_true()
	assert_int(after.filter(func(e: Dictionary) -> bool: return e["kind"] == "legend").size()).is_equal(1)
	assert_array(c.ladder.ghosts).has_size(1)


func test_decorated_hall_keeps_a_capsule_route_to_every_station_and_well() -> void:
	var room: GuildRoom = auto_free(GuildRoom.new())
	add_child(room)
	room.build(TestFixtures.campaign())
	await get_tree().physics_frame
	var grid := GuildRoom.plan()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = DungeonBuilder.LAYER_WORLD
	for y in grid.height:
		for x in grid.width:
			if not grid.is_walkable(x, y):
				continue
			query.transform = Transform3D(Basis.IDENTITY, Kit.cell_to_world(Vector2i(x, y)) + Vector3.UP * 0.95)
			if not room.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				grid.set_cell(x, y, FloorLayout.Cell.VOID)
	var seen := grid.reachable_from(GuildRoom.spawn_cell())
	for id in GuildRoom.station_cells():
		var cell: Vector2i = GuildRoom.station_cells()[id]
		assert_bool(seen.has(cell + Vector2i.DOWN)).override_failure_message("blocked guild destination: " + id).is_true()
