extends GdUnitTestSuite
## The tower down the well: the one image that explains the game without a
## word.


func _campaign_with_dead(count: int) -> Campaign:
	var c := TestFixtures.campaign()
	for i in count:
		var g := Ghost.founder(TestFixtures.content(), 1000)
		g.floor = 2 + i
		c.ladder.add(g)
	return c


func _well(c: Campaign) -> WellView:
	var w: WellView = auto_free(WellView.new())
	add_child(w)
	w.build(c)
	return w


func test_the_tower_goes_down_not_up() -> void:
	assert_float(WellView.floor_y(1)).is_less(0.0)
	assert_float(WellView.floor_y(5)).is_less(WellView.floor_y(4))


func test_there_is_a_ring_for_every_floor_of_the_biome() -> void:
	var c := TestFixtures.campaign()
	var w := _well(c)
	assert_int(w.depth()).is_equal(Biomes.depth(c.content))
	assert_array(w.rings).has_size(w.depth())


func test_every_ghost_you_have_is_standing_down_there() -> void:
	var c := _campaign_with_dead(3)
	var w := _well(c)
	assert_array(w.figures).has_size(c.ladder.ghosts.size())


func test_a_ghost_stands_on_the_floor_it_died_on() -> void:
	var c := _campaign_with_dead(2)
	var w := _well(c)
	for f in w.figures:
		var figure: GhostFigure = f
		assert_float(figure.position.y).is_equal_approx(
			WellView.floor_y(figure.ghost_floor) + 0.1, 0.001)


func test_two_ghosts_on_one_floor_do_not_stand_inside_each_other() -> void:
	var a := WellView.ghost_point(3, 0, 2)
	var b := WellView.ghost_point(3, 1, 2)
	assert_float(a.distance_to(b)).is_greater(1.0)
	assert_float(a.y).is_equal_approx(b.y, 0.001)


func test_a_lone_ghost_on_a_floor_does_not_divide_by_zero() -> void:
	var p := WellView.ghost_point(2, 0, 0)
	assert_bool(is_finite(p.x)).is_true()
	assert_bool(is_finite(p.z)).is_true()


func test_a_ghost_deeper_than_the_tower_is_clamped_not_dropped() -> void:
	assert_int(WellView.clamp_floor(99, 10)).is_equal(10)
	assert_int(WellView.clamp_floor(0, 10)).is_equal(1)
	assert_int(WellView.clamp_floor(4, 10)).is_equal(4)


func test_the_founder_is_already_down_there_on_a_brand_new_campaign() -> void:
	# A new campaign seeds the ladder with a founder, so the very first time
	# you look down the well somebody is standing in it. That is the pitch
	# landing before the player has done anything.
	var c := TestFixtures.campaign()
	assert_array(c.ladder.ghosts).is_not_empty()
	var w := _well(c)
	assert_array(w.figures).has_size(c.ladder.ghosts.size())
	assert_array(w.rings).is_not_empty()


func test_a_shaft_is_built_even_with_nobody_in_it() -> void:
	var c := TestFixtures.campaign()
	c.ladder.ghosts.clear()
	var w := _well(c)
	assert_array(w.figures).is_empty()
	assert_array(w.rings).is_not_empty()


func test_the_shaft_has_walls_you_see_from_inside() -> void:
	# Without them the hole shows the environment's background colour, and a
	# well you can see the void through is a hole in the level.
	var w := _well(TestFixtures.campaign())
	var shaft: MeshInstance3D = w.get_node("Shaft")
	var m: StandardMaterial3D = shaft.material_override
	assert_int(m.cull_mode).is_equal(BaseMaterial3D.CULL_FRONT)
	# Deep enough to reach past the last ring.
	assert_float((shaft.mesh as BoxMesh).size.y).is_greater(absf(WellView.floor_y(w.depth())))
	# And still at the kit's one texel density (spec §7).
	assert_float((shaft.mesh as BoxMesh).size.y / m.uv1_scale.y).is_equal_approx(Kit.TEXEL, 0.01)


func test_the_tower_is_a_diorama_not_a_place() -> void:
	# Twenty floors have to fit down a three-metre shaft. Life-size ghosts
	# fill the well and the depth stops reading.
	var c := _campaign_with_dead(2)
	var w := _well(c)
	for f in w.figures:
		assert_float((f as GhostFigure).scale.x).is_less(1.0)
	# And they still fit inside the shaft's walls.
	for f in w.figures:
		var figure: GhostFigure = f
		assert_float(absf(figure.position.x)).is_less(Kit.CELL * 0.5)
		assert_float(absf(figure.position.z)).is_less(Kit.CELL * 0.5)
