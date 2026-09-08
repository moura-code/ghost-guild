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
	var light := rig.light(0)
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
	var a := rig.light(0)
	var b := rig.light(1)
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
	var dim := rig.light(0)
	var bright := rig.light(1)
	for i in 5:
		await await_idle_frame()
	assert_float(bright.light_energy / maxf(dim.light_energy, 0.0001)).is_equal_approx(8.0, 0.01)


func test_a_rig_with_nothing_in_it_is_quiet() -> void:
	var rig := _rig()
	for i in 3:
		await await_idle_frame()
	assert_bool(is_instance_valid(rig)).is_true()


# --------------------------------------------------------------- the crackle

func test_a_torch_is_heard_from_where_it_is_burning() -> void:
	# The whole point of the batch: the room's own sound arrives from a place.
	# A 2D crackle would be a torch across the hall as loud as one at your
	# elbow, which is worse than silence because it is actively wrong.
	var rig := _rig()
	rig.adopt(_light(Vector3(6.0, 2.0, 0.0), 3.6))
	var voice: AudioStreamPlayer3D = rig.voice(0)
	assert_object(voice).override_failure_message("the torch makes no sound").is_not_null()
	assert_object(voice.stream).is_not_null()
	assert_vector(voice.global_position).is_equal_approx(Vector3(6.0, 2.0, 0.0), Vector3.ONE * 0.01)


func test_the_crackle_loops_rather_than_burning_out() -> void:
	# Godot's wav importer ignores edit/loop_mode for these files, so the loop
	# has to be set at runtime -- and a torch that stops after six seconds is
	# a room that goes quiet while you are standing in it.
	var rig := _rig()
	rig.adopt(_light(Vector3.ZERO, 3.6))
	var wav: AudioStreamWAV = rig.voice(0).stream
	assert_int(wav.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(wav.loop_end).is_greater(0)


func test_a_torch_across_the_floor_cannot_be_heard() -> void:
	# Twenty audible torches is a wall of noise. The reach is a few cells, so
	# walking a corridor is walking past them one at a time.
	var rig := _rig()
	rig.adopt(_light(Vector3.ZERO, 3.6))
	var voice := rig.voice(0)
	assert_float(voice.max_distance).is_greater(Kit.CELL)
	assert_float(voice.max_distance).is_less(Kit.CELL * 8.0)


func test_two_torches_do_not_crackle_in_unison() -> void:
	# The same six-second loop started at the same instant on twenty players
	# combs into a single voice with a flanged edge on it, which is the exact
	# sound of "one script is driving all of these".
	var rig := _rig()
	rig.adopt(_light(Vector3(0.0, 2.0, 0.0), 3.6))
	rig.adopt(_light(Vector3(9.0, 2.0, -12.0), 3.6))
	assert_float(absf(rig.voice_offset(0) - rig.voice_offset(1))) \
		.override_failure_message("both torches started at the same place in the loop") \
		.is_greater(0.2)


func test_the_crackle_is_on_the_bus_that_has_the_room_on_it() -> void:
	var rig := _rig()
	rig.adopt(_light(Vector3.ZERO, 3.6))
	assert_str(rig.voice(0).bus).is_equal(Sfx.BUS_AMBIENCE)
