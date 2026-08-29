extends GdUnitTestSuite
## The controller's maths are static functions on purpose: a headless suite
## cannot press a key or move a mouse, but it can check that "forward" is
## where you are looking and that a diagonal is not a speed boost. The rig
## itself is asserted structurally. Whether it *feels* right is a question
## only running the game answers.


func _player() -> Player:
	var p: Player = auto_free(Player.new())
	add_child(p)
	return p


func test_forward_is_where_you_are_looking() -> void:
	# -Z is forward in Godot.
	assert_vector(Player.wish_direction(Vector2(0.0, -1.0), 0.0)).is_equal_approx(Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001)
	assert_vector(Player.wish_direction(Vector2(0.0, -1.0), PI / 2.0)).is_equal_approx(Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.001)


func test_a_diagonal_is_not_a_speed_boost() -> void:
	assert_float(Player.wish_direction(Vector2(1.0, -1.0), 0.0).length()).is_equal_approx(1.0, 0.001)


func test_standing_still_is_no_direction_at_all() -> void:
	assert_vector(Player.wish_direction(Vector2.ZERO, 1.3)).is_equal(Vector3.ZERO)


func test_you_cannot_look_far_enough_up_to_see_behind_you() -> void:
	assert_float(Player.clamp_pitch(9.0)).is_equal(Player.PITCH_LIMIT)
	assert_float(Player.clamp_pitch(-9.0)).is_equal(-Player.PITCH_LIMIT)
	assert_float(Player.clamp_pitch(0.2)).is_equal(0.2)


func test_the_rig_is_a_capsule_with_a_head_a_camera_and_a_torch() -> void:
	var p := _player()
	assert_object(p.head).is_not_null()
	assert_object(p.camera).is_not_null()
	assert_object(p.torch).is_not_null()
	assert_float(p.head.position.y).is_equal_approx(Player.EYE, 0.0001)
	assert_object(p.camera.get_parent()).is_same(p.head)
	assert_object(p.torch.get_parent()).is_same(p.head)
	var shape: CollisionShape3D = p.get_node("Shape")
	assert_object(shape.shape).is_instanceof(CapsuleShape3D)


func test_the_player_is_on_the_player_layer_and_collides_with_the_world() -> void:
	var p := _player()
	assert_int(p.collision_layer).is_equal(Player.LAYER_PLAYER)
	assert_bool((p.collision_mask & DungeonBuilder.LAYER_WORLD) != 0).is_true()


func test_placing_the_player_sets_where_it_stands_and_which_way_it_faces() -> void:
	var p := _player()
	p.place_at(Vector3(9.0, 0.0, -4.0), PI)
	assert_vector(p.position).is_equal_approx(Vector3(9.0, 0.0, -4.0), Vector3.ONE * 0.001)
	assert_float(p.rotation.y).is_equal_approx(PI, 0.001)
	assert_float(p.head.rotation.x).is_equal(0.0)


func test_input_reads_zero_when_nothing_is_pressed() -> void:
	# The suite never presses a key, so this is the only honest assertion
	# about read_input(): it exists, it is typed, and it is quiet.
	assert_vector(_player().read_input()).is_equal(Vector2.ZERO)


func test_gravity_puts_the_player_on_the_ground() -> void:
	var p := _player()
	var ground: StaticBody3D = auto_free(StaticBody3D.new())
	ground.collision_layer = DungeonBuilder.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	cs.shape = box
	cs.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(cs)
	add_child(ground)
	p.place_at(Vector3(0.0, 2.5, 0.0), 0.0)
	await await_millis(600)
	assert_bool(p.is_on_floor()).override_failure_message("player never landed, y=%f" % p.position.y).is_true()
	assert_float(p.position.y).is_equal_approx(0.0, 0.15)
