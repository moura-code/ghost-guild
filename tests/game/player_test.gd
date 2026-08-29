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


## The two below press real keys. The suite cannot move a mouse, but
## Input.action_press and the physics server both work under --headless, so
## "does WASD actually move the body, and do walls actually stop it" is
## answerable here rather than only by hand.
func _floor_under(p: Player) -> void:
	var ground: StaticBody3D = auto_free(StaticBody3D.new())
	ground.collision_layer = DungeonBuilder.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	cs.shape = box
	cs.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(cs)
	add_child(ground)


func test_holding_forward_walks_the_body_forward() -> void:
	var p := _player()
	_floor_under(p)
	p.place_at(Vector3.ZERO, 0.0)
	await await_millis(200)
	Input.action_press("move_forward")
	await await_millis(500)
	Input.action_release("move_forward")
	# -Z is forward, and half a second at 3.6 m/s is over a metre even with
	# the acceleration ramp.
	assert_float(p.position.z).override_failure_message("did not walk, z=%f" % p.position.z).is_less(-1.0)
	assert_float(absf(p.position.x)).is_less(0.05)


func test_a_wall_stops_you() -> void:
	var p := _player()
	_floor_under(p)
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	wall.collision_layer = DungeonBuilder.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, Kit.WALL_H, 1.0)
	cs.shape = box
	cs.position = Vector3(0.0, Kit.WALL_H * 0.5, -3.0)
	wall.add_child(cs)
	add_child(wall)
	p.place_at(Vector3.ZERO, 0.0)
	await await_millis(200)
	Input.action_press("move_forward")
	await await_millis(1200)
	Input.action_release("move_forward")
	# The wall's near face is at z = -2.5 and the capsule is RADIUS thick.
	assert_float(p.position.z).override_failure_message("walked through the wall, z=%f" % p.position.z).is_greater(-2.5 - Player.RADIUS - 0.1)
	assert_float(p.position.z).is_less(-1.0)


func test_escape_does_not_steal_the_cursor_back_from_a_panel() -> void:
	# _unhandled_input reaches children before parents, so a frozen body that
	# grabbed Escape here would recapture the cursor before Crawl saw the key
	# -- and a panel you cannot click is worse than a cursor you cannot free.
	var p := _player()
	p.frozen = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	p._unhandled_input(escape)
	assert_int(Input.get_mouse_mode()).is_equal(Input.MOUSE_MODE_VISIBLE)
