extends GdUnitTestSuite
## The pivot's first pillar, made literal: your dead stand in the corridors
## you walk back down.


func _ghost(id: int = 7, floor: int = 4) -> Ghost:
	var g := Ghost.founder(TestFixtures.content(), 1000)
	g.id = id
	g.floor = floor
	return g


func _figure(at: Vector3 = Vector3.ZERO) -> GhostFigure:
	var f: GhostFigure = auto_free(GhostFigure.create(_ghost(), at))
	add_child(f)
	return f


func test_a_figure_knows_which_ghost_it_is_and_where_it_died() -> void:
	var f := _figure()
	assert_int(f.ghost_id).is_equal(7)
	assert_int(f.ghost_floor).is_equal(4)


func test_it_stands_on_the_floor_it_was_placed_on() -> void:
	var f := _figure(Vector3(6.0, 0.0, 9.0))
	assert_float(f.position.x).is_equal_approx(6.0, 0.001)
	assert_float(f.position.z).is_equal_approx(9.0, 0.001)


func test_you_walk_through_your_dead_rather_than_into_them() -> void:
	# A ghost with a collider is furniture.
	var f := _figure()
	for child in f.get_children():
		assert_bool(child is CollisionObject3D).override_failure_message("a ghost became solid").is_false()


func test_it_is_see_through_and_lit_from_inside() -> void:
	var f := _figure()
	assert_int(f.material().transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_float(f.material().albedo_color.a).is_less(1.0)
	assert_bool(f.material().emission_enabled).is_true()


func test_a_ghost_casts_no_shadow() -> void:
	var f := _figure()
	for name in ["Mesh", "Head"]:
		var mesh: MeshInstance3D = f.get_node(name)
		assert_int(mesh.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_the_head_point_is_where_a_name_would_go() -> void:
	var f := _figure(Vector3(0.0, 0.0, 0.0))
	assert_float(f.head_point().y).is_greater(GhostFigure.HEIGHT)


func test_rising_starts_below_the_floor_and_invisible() -> void:
	var f := _figure(Vector3(0.0, 0.0, 0.0))
	f.rise()
	assert_float(f.position.y).is_less(0.0)
	assert_float(f.material().albedo_color.a).is_equal(0.0)


func test_idle_drift_does_not_move_the_rise_target() -> void:
	var f := _figure(Vector3(2, 0.4, 3))
	f._process(0.2)
	assert_float(f.position.y).is_equal_approx(0.4, 0.0001)
	f.rise(1.0, 0.15)
	for mat in f._details:
		assert_float(mat.albedo_color.a).is_equal(0.0)
	assert_float(f._lamp.light_energy).is_equal(0.0)
	await await_millis(250)
	assert_float(f.position.y).is_equal_approx(0.4, 0.0001)
	assert_float(f.material().albedo_color.a).is_greater(0.0)
