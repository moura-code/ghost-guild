extends GdUnitTestSuite
## Sound with a place in it. The suite has no ears, so what is asserted is
## everything up to the speaker: that a voice is put where the blow landed,
## that it is on the bus with the room on it, that the pool rotates rather
## than cutting itself off, and that every way of asking for nothing resolves
## to silence instead of to an error mid-fight.


func _pool() -> Voices3D:
	var v: Voices3D = auto_free(Voices3D.new())
	add_child(v)
	return v


func test_a_blow_is_heard_where_it_landed() -> void:
	var v := _pool()
	await await_idle_frame()
	v.play_at("hit_light", Vector3(2.0, 1.4, -5.0))
	var voice: AudioStreamPlayer3D = v.get_child(0)
	assert_vector(voice.global_position).is_equal_approx(Vector3(2.0, 1.4, -5.0), Vector3.ONE * 0.01)
	assert_object(voice.stream).is_not_null()


func test_the_room_is_on_the_wet_bus_and_falls_off_with_distance() -> void:
	var v := _pool()
	await await_idle_frame()
	for child in v.get_children():
		var voice: AudioStreamPlayer3D = child
		assert_str(voice.bus).is_equal(Sfx.BUS_WORLD)
		assert_float(voice.max_distance).is_greater(0.0)


func test_the_pool_rotates_so_a_flurry_does_not_cut_itself_off() -> void:
	# Two blows a beat apart on one voice is the second chopping the first,
	# which reads as the game dropping frames.
	var v := _pool()
	await await_idle_frame()
	v.play_at("hit_light", Vector3(1.0, 0.0, 0.0))
	v.play_at("hit_light", Vector3(-1.0, 0.0, 0.0))
	var first: AudioStreamPlayer3D = v.get_child(0)
	var second: AudioStreamPlayer3D = v.get_child(1)
	assert_float(first.global_position.x).is_equal_approx(1.0, 0.01)
	assert_float(second.global_position.x).is_equal_approx(-1.0, 0.01)


func test_a_heavy_blow_and_a_light_one_are_different_sounds() -> void:
	# The same threshold the animator uses for hit-stop and shake, so the ear
	# and the eye agree about which blows were the heavy ones.
	var v := _pool()
	await await_idle_frame()
	v.hit_at(Sfx.BIG_HIT, Vector3.ZERO)
	var heavy: AudioStream = (v.get_child(0) as AudioStreamPlayer3D).stream
	v.hit_at(1, Vector3.ZERO)
	var light: AudioStream = (v.get_child(1) as AudioStreamPlayer3D).stream
	assert_object(heavy).is_not_same(light)


func test_asking_for_a_sound_that_does_not_exist_is_silence() -> void:
	var v := _pool()
	await await_idle_frame()
	v.play_at("no_such_sound", Vector3.ZERO)
	assert_object((v.get_child(0) as AudioStreamPlayer3D).stream).is_null()


func test_a_muted_game_is_silent_here_too() -> void:
	# Two pools means two chances to miss the mute switch, which is why the
	# switch lives on Sfx and this one reads it.
	var v := _pool()
	var s: Sfx = auto_free(Sfx.new())
	add_child(s)
	await await_idle_frame()
	s.muted = true
	v.sfx = s
	v.play_at("hit_light", Vector3.ZERO)
	for child in v.get_children():
		assert_bool((child as AudioStreamPlayer3D).playing) \
			.override_failure_message("muted and still playing").is_false()


func test_a_pool_with_no_sfx_behind_it_still_works() -> void:
	# A director staged without sound still stages a fight.
	var v := _pool()
	await await_idle_frame()
	v.play_at("hit_light", Vector3.ZERO)
	assert_bool(is_instance_valid(v)).is_true()
