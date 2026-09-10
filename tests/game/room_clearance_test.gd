extends GdUnitTestSuite


func test_100_seeds_keep_required_routes_services_and_combat_centers_clear_of_solid_props() -> void:
	var c := TestFixtures.content()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	for seed in 100:
		var floor: int = [1, 10, 11, 20, 21, 30][seed % 6]
		var nodes := FloorGenerator.generate(c, Biomes.for_floor(c, floor), floor, Rng.new(seed))
		var layout := LayoutGenerator.generate_current(nodes, Rng.new(seed))
		layout.presets = RoomPresets.choose(c, layout, nodes, Biomes.for_floor(c, floor).id, Rng.new(seed))
		layout.preset_recipes = RoomPresets.freeze(c, layout.presets)
		var world := Node3D.new()
		add_child(world)
		var composition := RoomComposition.build(world, layout, c)
		var budget := 0
		for recipe in layout.preset_recipes:
			budget += int(recipe.get("ambient_budget", 0))
		assert_int(composition._animated.size()).is_less_equal(budget)
		for i in nodes.size():
			if nodes[i]["kind"] == "shop":
				RoomSigns.merchant(world, Kit.cell_to_world(RoomSigns.service_cell(layout, layout.room_of_node(i))), c)
		await get_tree().physics_frame
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = DungeonBuilder.LAYER_WORLD
		var walkable := layout.to_dict()
		var physical := FloorLayout.from_dict(walkable)
		for y in layout.height:
			for x in layout.width:
				if not layout.is_walkable(x, y):
					continue
				query.transform = Transform3D(Basis.IDENTITY, Kit.cell_to_world(Vector2i(x, y)) + Vector3.UP * 0.95)
				if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
					physical.set_cell(x, y, FloorLayout.Cell.VOID)
		for i in nodes.size():
			var room := layout.room_of_node(i)
			var center := layout.room_center(room)
			assert_bool(physical.is_walkable(center.x, center.y)).override_failure_message("staging blocked seed %d room %d" % [seed, i]).is_true()
			if not nodes[i]["required"]:
				var rect := layout.room_rect(room)
				for y in range(rect["y"], rect["y"] + rect["h"]):
					for x in range(rect["x"], rect["x"] + rect["w"]):
						physical.set_cell(x, y, FloorLayout.Cell.VOID)
			if nodes[i]["kind"] == "shop":
				var counter := Kit.cell_to_world(RoomSigns.service_cell(layout, room))
				query.transform = Transform3D(Basis.IDENTITY, counter + Vector3(0, 0.95, -1.2))
				assert_array(world.get_world_3d().direct_space_state.intersect_shape(query, 1)).is_empty()
		var seen := physical.reachable_from(layout.room_center(layout.entry_room))
		assert_bool(seen.has(layout.room_center(layout.stairs_room))).override_failure_message("stairs blocked seed %d" % seed).is_true()
		for i in nodes.size():
			if nodes[i]["required"]:
				assert_bool(seen.has(layout.room_center(layout.room_of_node(i)))).override_failure_message("required path crosses optional trigger seed %d" % seed).is_true()
		world.free()
