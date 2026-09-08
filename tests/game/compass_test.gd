extends GdUnitTestSuite
## The fix for the worst thing about playing the game: a 24x24 grid, three
## rooms, and no way to know where any of them were.
##
## The bearing is the one piece of maths here that can actually be wrong, so
## it is pure and it is where the assertions are.


func _at(x: float, z: float) -> Vector3:
	return Vector3(x, 0.0, z)


func test_dead_ahead_is_the_middle_of_the_strip() -> void:
	# Godot yaw 0 looks down -Z.
	assert_float(Compass.bearing_offset(Vector3.ZERO, 0.0, _at(0.0, -10.0))).is_equal_approx(0.0, 0.001)


func test_a_room_to_your_right_reads_to_the_right() -> void:
	var offset := Compass.bearing_offset(Vector3.ZERO, 0.0, _at(10.0, -10.0))
	assert_float(offset).override_failure_message("a room on the right did not read right").is_greater(0.0)


func test_a_room_to_your_left_reads_to_the_left() -> void:
	assert_float(Compass.bearing_offset(Vector3.ZERO, 0.0, _at(-10.0, -10.0))).is_less(0.0)


func test_turning_your_head_moves_the_mark_the_other_way() -> void:
	# Turn left towards a room on the left and it should slide towards centre.
	var before := Compass.bearing_offset(Vector3.ZERO, 0.0, _at(-10.0, -10.0))
	var after := Compass.bearing_offset(Vector3.ZERO, PI / 4.0, _at(-10.0, -10.0))
	assert_float(absf(after)).is_less(absf(before))


func test_facing_a_room_squarely_centres_it_whatever_the_yaw() -> void:
	for yaw in [0.0, 1.0, -2.2, 3.0]:
		var ahead := Vector3(-sin(yaw), 0.0, -cos(yaw)) * 12.0
		assert_float(Compass.bearing_offset(Vector3.ZERO, yaw, ahead)).override_failure_message(
			"yaw %f did not centre the room in front of it" % yaw).is_equal_approx(0.0, 0.01)


func test_a_room_behind_you_is_pinned_to_an_edge() -> void:
	assert_bool(Compass.is_pinned(Vector3.ZERO, 0.0, _at(0.0, 10.0))).is_true()
	assert_float(absf(Compass.bearing_offset(Vector3.ZERO, 0.0, _at(0.0, 10.0)))).is_equal(1.0)


func test_a_room_in_front_is_not_pinned() -> void:
	assert_bool(Compass.is_pinned(Vector3.ZERO, 0.0, _at(1.0, -10.0))).is_false()


func test_standing_on_the_target_does_not_divide_by_zero() -> void:
	assert_float(Compass.bearing_offset(Vector3.ZERO, 0.0, Vector3.ZERO)).is_equal(0.0)


func test_the_offset_never_leaves_the_strip() -> void:
	for angle in range(0, 360, 17):
		var t := deg_to_rad(float(angle))
		var to := Vector3(cos(t), 0.0, sin(t)) * 9.0
		var offset := Compass.bearing_offset(Vector3.ZERO, 0.6, to)
		assert_float(offset).is_between(-1.0, 1.0)


func test_the_stairs_do_not_look_like_an_encounter() -> void:
	assert_that(Compass.colour_for("stairs")).is_not_equal(Compass.colour_for("encounter"))
	assert_that(Compass.colour_for("ghost")).is_not_equal(Compass.colour_for("encounter"))


func test_it_never_swallows_a_click() -> void:
	var c: Compass = auto_free(Compass.new())
	add_child(c)
	assert_int(c.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_marks_can_be_set_and_read_back() -> void:
	var c: Compass = auto_free(Compass.new())
	add_child(c)
	c.set_marks([{"at": _at(3.0, 3.0), "kind": "stairs"}])
	assert_array(c.marks).has_size(1)
