extends GdUnitTestSuite
## The guild is hand-placed, not generated: it is one room the player comes
## home to a thousand times, and a seeded home is not a home.


func _campaign() -> Campaign:
	return TestFixtures.campaign()


func _room() -> GuildRoom:
	var r: GuildRoom = auto_free(GuildRoom.new())
	add_child(r)
	r.build(_campaign())
	return r


func test_the_room_is_enclosed_except_for_the_well() -> void:
	var l := GuildRoom.plan()
	for y in l.height:
		for x in l.width:
			if not l.is_walkable(x, y):
				continue
			# Every walkable cell has geometry on all four sides, or you can
			# walk out of the guild into nothing. The well is the one hole,
			# and it is fenced by the well head rather than by the grid.
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var at := Vector2i(x + step.x, y + step.y)
				if at == GuildRoom.WELL_CELL:
					continue
				assert_int(l.cell(at.x, at.y)).override_failure_message(
					"void beside walkable cell %d,%d" % [x, y]).is_not_equal(FloorLayout.Cell.VOID)


func test_the_well_is_a_hole_and_not_a_pillar() -> void:
	# Punched after add_walls on purpose: a void cell ringed by floor gets
	# filled in by the wall pass, which turns the well into a solid pillar in
	# the middle of the room. This is the assertion that catches that.
	var l := GuildRoom.plan()
	assert_bool(l.is_walkable(GuildRoom.WELL_CELL.x, GuildRoom.WELL_CELL.y)).is_false()
	assert_int(l.cell(GuildRoom.WELL_CELL.x, GuildRoom.WELL_CELL.y)).is_equal(FloorLayout.Cell.VOID)


func test_the_well_head_fences_the_hole_on_all_four_sides() -> void:
	# The builder's ground slab runs under the whole room, so without the rim
	# the player walks out over the shaft on invisible collision.
	var r := _room()
	var head: StaticBody3D = r.get_node("WellHead")
	assert_int(head.collision_layer).is_equal(DungeonBuilder.LAYER_WORLD)
	var shapes := 0
	for child in head.get_children():
		if child is CollisionShape3D:
			shapes += 1
	assert_int(shapes).is_equal(4)


func test_the_ceiling_is_not_left_open_above_the_well() -> void:
	# Ceiling tiles follow floor cells, and the well is not one -- so without
	# a patch there is a skylight in a crypt.
	var r := _room()
	var patch: MeshInstance3D = r.get_node("CeilingPatch")
	assert_float(patch.position.y).is_equal_approx(Kit.WALL_H, 0.001)


func test_every_station_stands_somewhere_you_can_reach() -> void:
	var l := GuildRoom.plan()
	var reachable := l.reachable_from(GuildRoom.spawn_cell())
	for id in GuildRoom.station_cells():
		var cell: Vector2i = GuildRoom.station_cells()[id]
		if id == GuildRoom.WELL:
			continue
		assert_bool(reachable.has(cell)).override_failure_message("station %s is walled off" % id).is_true()


func test_you_spawn_inside_the_room() -> void:
	var l := GuildRoom.plan()
	assert_bool(l.is_walkable(GuildRoom.spawn_cell().x, GuildRoom.spawn_cell().y)).is_true()


func test_the_stations_all_have_their_own_id() -> void:
	var r := _room()
	assert_array(r.stations).has_size(4)
	var ids: Dictionary = {}
	for s in r.stations:
		ids[(s as Interactable).id] = true
	assert_int(ids.size()).is_equal(4)
	for id in [GuildRoom.TABLE, GuildRoom.CIRCLE, GuildRoom.DESK, GuildRoom.WELL]:
		assert_object(r.station(id)).override_failure_message("no station %s" % id).is_not_null()


func test_each_station_carries_a_line_that_resolves_to_real_words() -> void:
	var r := _room()
	for s in r.stations:
		var key: String = (s as Interactable).label_key
		assert_str(TestFixtures.content().text(key)).override_failure_message(
			"unresolved string %s" % key).is_not_equal(key)


func test_the_guild_is_brighter_and_clearer_than_the_first_floor() -> void:
	var guild := Grade.guild_environment()
	var crypt := Grade.environment(Grade.depth_of(1, 10))
	assert_float(guild.ambient_light_energy).is_greater(crypt.ambient_light_energy)
	assert_float(guild.fog_density).is_less(crypt.fog_density)
	# Still the same game: one tonemap for everything (spec §7).
	assert_int(guild.tonemap_mode).is_equal(crypt.tonemap_mode)


func test_the_well_is_built_and_standing_in_the_hole() -> void:
	var r := _room()
	assert_object(r.well).is_not_null()
	assert_vector(r.well.position).is_equal_approx(Kit.cell_to_world(GuildRoom.WELL_CELL), Vector3.ONE * 0.001)
