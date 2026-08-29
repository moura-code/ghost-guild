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


func test_recoil_moves_it_and_puts_it_back() -> void:
	var b := _body()
	var rest := b.body_offset()
	b.recoil(8)
	assert_float(b.body_offset().z).is_not_equal(rest.z)
	await await_millis(400)
	assert_vector(b.body_offset()).is_equal_approx(rest, Vector3.ONE * 0.02)


func test_a_dead_body_stops_being_a_target() -> void:
	var b := _body()
	assert_bool(b.dying).is_false()
	b.die()
	assert_bool(b.dying).is_true()
	assert_int(b.collision_layer).is_equal(0)


func test_dying_twice_is_not_two_deaths() -> void:
	var b := _body()
	b.die()
	var falling := b.rotation.x
	b.die()
	assert_float(b.rotation.x).is_equal(falling)


func test_highlighting_is_something_you_can_see_and_turn_off() -> void:
	var b := _body()
	var plain := b.mesh_material().emission_energy_multiplier
	b.set_highlight(true)
	assert_float(b.mesh_material().emission_energy_multiplier).is_greater(plain)
	b.set_highlight(false)
	assert_float(b.mesh_material().emission_energy_multiplier).is_equal_approx(plain, 0.001)
