extends GdUnitTestSuite
## The kit is where "asset flip" is prevented or caused. The assertions that
## matter are not about looks -- they are that every surface in the game
## repeats its texture every TEXEL metres, whatever the surface's size, and
## that everyone shares one material so the whole crypt grades as one thing.


func _metres_per_repeat(m: StandardMaterial3D, span: Vector2) -> Vector2:
	return Vector2(span.x / m.uv1_scale.x, span.y / m.uv1_scale.y)


func test_every_material_carries_its_four_maps() -> void:
	for m in [Kit.floor_material(), Kit.wall_material(), Kit.ceiling_material()]:
		assert_object(m.albedo_texture).is_not_null()
		assert_object(m.normal_texture).is_not_null()
		assert_object(m.roughness_texture).is_not_null()
		assert_object(m.ao_texture).is_not_null()


func test_the_whole_kit_shares_one_texel_density() -> void:
	# A floor cell is CELL x CELL; a wall face is CELL wide and WALL_H tall.
	# Both must come out at TEXEL metres per repeat, which is why the wall
	# does not simply reuse the floor's uv1_scale.
	var floor_span := _metres_per_repeat(Kit.floor_material(), Vector2(Kit.CELL, Kit.CELL))
	var wall_span := _metres_per_repeat(Kit.wall_material(), Vector2(Kit.CELL, Kit.WALL_H))
	for span in [floor_span, wall_span]:
		assert_float(span.x).is_equal_approx(Kit.TEXEL, 0.001)
		assert_float(span.y).is_equal_approx(Kit.TEXEL, 0.001)


func test_materials_and_meshes_are_shared_not_rebuilt() -> void:
	# 500+ cells per floor. A material per cell is 500 shader instances and a
	# MultiMesh that cannot batch at all.
	assert_object(Kit.floor_material()).is_same(Kit.floor_material())
	assert_object(Kit.wall_material()).is_same(Kit.wall_material())
	assert_object(Kit.floor_mesh()).is_same(Kit.floor_mesh())
	assert_object(Kit.wall_mesh()).is_same(Kit.wall_mesh())


func test_the_floor_and_wall_meshes_are_one_cell_across() -> void:
	# Approx, not exact: a mesh size is a Vector3, whose components are 32-bit,
	# and 3.2 is not the same number in 32 bits as it is in the 64-bit const.
	assert_float(Kit.floor_mesh().size.x).is_equal_approx(Kit.CELL, 0.0001)
	assert_float(Kit.floor_mesh().size.y).is_equal_approx(Kit.CELL, 0.0001)
	assert_float(Kit.wall_mesh().size.x).is_equal_approx(Kit.CELL, 0.0001)
	assert_float(Kit.wall_mesh().size.y).is_equal_approx(Kit.WALL_H, 0.0001)
	assert_float(Kit.wall_mesh().size.z).is_equal_approx(Kit.CELL, 0.0001)


func test_cell_and_world_are_the_same_place_read_two_ways() -> void:
	for c in [Vector2i(0, 0), Vector2i(7, 3), Vector2i(23, 23)]:
		assert_vector(Kit.world_to_cell(Kit.cell_to_world(c))).is_equal(c)


func test_a_point_inside_a_cell_reads_as_that_cell() -> void:
	var middle := Kit.cell_to_world(Vector2i(5, 6)) + Vector3(Kit.CELL * 0.4, 1.7, -Kit.CELL * 0.4)
	assert_vector(Kit.world_to_cell(middle)).is_equal(Vector2i(5, 6))


func test_the_stone_is_grey_so_the_light_can_be_the_colour() -> void:
	# The CC0 sets are warm sandstone, and under warm torchlight that made every
	# pixel in the game a value of the same orange. Tinting the albedo cool-grey
	# pulls the colour out of the texture so it comes from the lighting: warm
	# where the torches reach, cold in the fill, contrast between them.
	#
	# Every biome, including the one that is about fire: the Kiln's heat comes
	# from its torches and from its accent in the fog, and a warm albedo on top
	# of that is how a biome turns into one colour.
	for biome in Kit.BIOME_STONE:
		for m in [Kit.wall_material(biome), Kit.floor_material(biome), Kit.ceiling_material(biome)]:
			assert_float(m.albedo_color.b).override_failure_message(
				"%s is tinted warm, so it can only ever be orange" % biome) 				.is_greater_equal(m.albedo_color.r)
			assert_float(m.albedo_color.r).is_less(1.0)


func test_each_biome_is_made_of_its_own_stone() -> void:
	# The Deep shipped with the Catacombs' walls and floor, and the only thing
	# that said "somewhere else" was the colour of the air twenty metres away.
	# No two biomes share a surface: the moment one does, the cheap fix for the
	# next biome is to share two.
	for surface in ["wall", "floor", "ceiling"]:
		var seen: Array[String] = []
		for biome in Kit.BIOME_STONE:
			var set_name := String(Kit.BIOME_STONE[biome][surface])
			assert_bool(seen.has(set_name)).override_failure_message(
				"%s uses %s for its %s, and so does another biome" % [biome, set_name, surface]) \
				.is_false()
			seen.append(set_name)


func test_a_biome_with_no_stone_yet_still_gets_a_room() -> void:
	# The content and the materials do not have to land in the same commit.
	assert_dict(Kit.stone_for("nowhere_yet")).is_equal(Kit.stone_for(Kit.HOME_STONE))
	assert_object(Kit.wall_material("nowhere_yet")).is_not_null()


func test_one_texel_density_across_every_biome() -> void:
	# The single discipline that stops mixed CC0 sources reading as an asset
	# flip (spec §7). A second biome is exactly where it would slip.
	for biome in Kit.BIOME_STONE:
		var floor_span := _metres_per_repeat(Kit.floor_material(biome), Vector2(Kit.CELL, Kit.CELL))
		var wall_span := _metres_per_repeat(Kit.wall_material(biome), Vector2(Kit.CELL, Kit.WALL_H))
		var ceiling_span := _metres_per_repeat(Kit.ceiling_material(biome), Vector2(Kit.CELL, Kit.CELL))
		for span in [floor_span, wall_span, ceiling_span]:
			assert_float(span.x).override_failure_message(
				"%s is not at one texel density" % biome).is_equal_approx(Kit.TEXEL, 0.001)
			assert_float(span.y).is_equal_approx(Kit.TEXEL, 0.001)


func test_every_biome_the_kit_names_has_its_files_on_disk() -> void:
	for biome in Kit.BIOME_STONE:
		var stone: Dictionary = Kit.BIOME_STONE[biome]
		for surface in ["wall", "floor", "ceiling"]:
			for map in ["color", "normal", "roughness", "ao"]:
				var path := "%s%s/%s.jpg" % [Kit.MAT_ROOT, String(stone[surface]), map]
				assert_bool(ResourceLoader.exists(path)).override_failure_message(
					"missing %s" % path).is_true()
