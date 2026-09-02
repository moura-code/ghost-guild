extends GdUnitTestSuite
## The rig that carries the flicker. `Flame` is the maths; this is the wire,
## and the wire has failed before -- a floor's lights are freed while the
## frame driving them is still in flight, on every descent.


func _rig() -> Torches:
	var t: Torches = auto_free(Torches.new())
	add_child(t)
	return t


func _light(at: Vector3, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_energy = energy
	return l


func test_a_torch_adopted_into_the_rig_starts_to_move() -> void:
	var rig := _rig()
	rig.adopt(_light(Vector3(3.0, 2.0, 0.0), 3.6))
	var light: OmniLight3D = rig.get_child(0)
	var seen: Array[float] = []
	for i in 12:
		await await_idle_frame()
		seen.append(light.light_energy)
	var low := seen.min() as float
	var high := seen.max() as float
	assert_float(high - low).override_failure_message("the flame never moved").is_greater(0.0)
	assert_float(low).is_greater_equal(3.6 * Flame.LOW - 0.001)
	assert_float(high).is_less_equal(3.6 * Flame.HIGH + 0.001)


func test_two_torches_are_not_the_same_torch() -> void:
	var rig := _rig()
	rig.adopt(_light(Vector3(0.0, 2.0, 0.0), 3.6))
	rig.adopt(_light(Vector3(9.0, 2.0, -12.0), 3.6))
	var a: OmniLight3D = rig.get_child(0)
	var b: OmniLight3D = rig.get_child(1)
	var apart := 0.0
	for i in 20:
		await await_idle_frame()
		apart = maxf(apart, absf(a.light_energy - b.light_energy))
	assert_float(apart).override_failure_message("the whole room pulsed as one light").is_greater(0.01)


func test_the_flicker_scales_whatever_the_light_was_authored_at() -> void:
	# A dim torch and a bright one keep their ratio. Otherwise tuning one
	# means re-tuning the flicker for all of them.
	var rig := _rig()
	rig.adopt(_light(Vector3(0.0, 2.0, 0.0), 1.0))
	rig.adopt(_light(Vector3(0.0, 2.0, 0.0), 8.0))
	var dim: OmniLight3D = rig.get_child(0)
	var bright: OmniLight3D = rig.get_child(1)
	for i in 5:
		await await_idle_frame()
	assert_float(bright.light_energy / maxf(dim.light_energy, 0.0001)).is_equal_approx(8.0, 0.01)


func test_a_rig_with_nothing_in_it_is_quiet() -> void:
	var rig := _rig()
	for i in 3:
		await await_idle_frame()
	assert_bool(is_instance_valid(rig)).is_true()
