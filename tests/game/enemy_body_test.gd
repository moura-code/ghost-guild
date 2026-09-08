extends GdUnitTestSuite
## The thing standing in the room. Its mesh is a stand-in -- there is still no
## rigged enemy model, which is the open question from stage 0 -- so what is
## asserted here is everything the rest of the fight depends on: that a body
## exists per enemy, that it is a distinct size per enemy, that a camera ray
## can hit it, and that it stops being a target when it dies.


func _def(id: String) -> EnemyDef:
	return TestFixtures.content().enemies[id]


func _body(id: String = "shambler", index: int = 0) -> EnemyBody:
	var b: EnemyBody = auto_free(EnemyBody.create(_def(id), index))
	add_child(b)
	return b


func test_a_body_carries_the_index_the_engine_knows_it_by() -> void:
	assert_int(_body("bone_rat", 2).index).is_equal(2)


func test_two_enemy_kinds_are_visibly_different_creatures() -> void:
	# A rat and the boss must not be the same silhouette. The stand-in reads
	# size off hp, so this survives whatever mesh replaces it as long as the
	# replacement is bound to the same number.
	var rat := EnemyBody.stand_in_height(_def("bone_rat"))
	var boss := EnemyBody.stand_in_height(_def("mother_of_bones"))
	assert_float(boss).is_greater(rat * 1.4)


func test_even_the_smallest_enemy_is_big_enough_to_aim_at() -> void:
	for id in ["bone_rat", "grave_wisp", "skull_stack"]:
		assert_float(EnemyBody.stand_in_height(_def(id))).is_greater_equal(EnemyBody.MIN_HEIGHT)


func test_the_biggest_enemy_still_fits_under_the_ceiling() -> void:
	assert_float(EnemyBody.stand_in_height(_def("mother_of_bones"))).is_less(Kit.WALL_H)


func test_the_head_point_is_where_a_number_should_appear() -> void:
	var b := _body("shambler")
	var head := b.head_point()
	assert_float(head.y).is_greater(EnemyBody.stand_in_height(_def("shambler")) * 0.5)
	assert_float(head.y).is_less_equal(EnemyBody.stand_in_height(_def("shambler")) + 0.4)


func test_a_body_can_be_hit_by_a_camera_ray() -> void:
	var b := _body()
	assert_int(b.collision_layer).is_equal(EnemyBody.LAYER_ENEMY)
	var shape: CollisionShape3D = b.get_node("Shape")
	assert_object(shape.shape).is_not_null()


func test_recoil_flinches_and_settles() -> void:
	# The flinch is one number the pose reads, not a tween racing the idle for
	# the same node position, so this is the number to look at.
	var b := _body()
	b.recoil(8)
	assert_float(b.hurt_level()).is_greater(0.0)
	await await_millis(500)
	assert_float(b.hurt_level()).override_failure_message(
		"it is still flinching half a second later").is_equal(0.0)


func test_a_harder_blow_flinches_harder() -> void:
	var light := _body()
	light.recoil(4)
	var heavy := _body()
	heavy.recoil(30)
	assert_float(heavy.hurt_level()).is_greater(light.hurt_level())


func test_a_dead_body_stops_being_a_target() -> void:
	var b := _body()
	assert_bool(b.dying).is_false()
	b.die()
	assert_bool(b.dying).is_true()
	assert_int(b.collision_layer).is_equal(0)


func test_equipment_and_eye_sockets_fade_with_the_corpse() -> void:
	var body := _body("hollow_knight")
	assert_int(body._detail_meshes.size()).is_greater(0)
	body.die()
	await await_millis(1200)
	assert_float(body.mesh_material().albedo_color.a).is_equal(0.0)
	for mesh in body._detail_meshes:
		assert_float(mesh.transparency).override_failure_message(
			"%s remains visible after the corpse fades" % mesh.name).is_equal(1.0)


func test_a_floating_wisp_can_be_targeted_at_its_visible_core() -> void:
	var body := _body("grave_wisp")
	var height := EnemyBody.stand_in_height(_def("grave_wisp"))
	var origin := Vector3(0, EnemyShape.hover(EnemyShape.Kind.WISP) + height * 0.58, -3)
	await await_idle_frame()
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, 0, 6), EnemyBody.LAYER_ENEMY)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	assert_object(hit.get("collider")).is_equal(body)


func test_dying_twice_is_not_two_deaths() -> void:
	var b := _body()
	b.die()
	await await_millis(200)
	var falling := b.fallen_level()
	assert_float(falling).is_greater(0.0)
	b.die()
	assert_float(b.fallen_level()).override_failure_message(
		"the second death restarted the fall").is_equal(falling)


func test_a_body_goes_down_and_stays_down() -> void:
	var b := _body()
	b.die()
	await await_millis(1200)
	assert_float(b.fallen_level()).is_equal(1.0)
	var settled := b.pose_offset()
	await await_millis(200)
	assert_vector(b.pose_offset()).override_failure_message(
		"a dead thing is still breathing").is_equal_approx(settled, Vector3.ONE * 0.001)
	assert_float(settled.y).override_failure_message(
		"it died standing up").is_less(0.0)


func test_highlighting_is_something_you_can_see_and_turn_off() -> void:
	var b := _body()
	var plain := b.mesh_material().emission_energy_multiplier
	b.set_highlight(true)
	assert_float(b.mesh_material().emission_energy_multiplier).is_greater(plain)
	b.set_highlight(false)
	assert_float(b.mesh_material().emission_energy_multiplier).is_equal_approx(plain, 0.001)
