extends GdUnitTestSuite
## Flicker, as maths.
##
## Torches are the only light in the game, so a torch that holds a constant
## energy freezes the entire image -- and a light with `randf()` on it is
## indistinguishable from a broken one. What is asserted here is that the
## flicker stays inside a stated band, that it is actually moving, and that
## twenty torches in a room do not pulse in unison, which is the single tell
## that reads as a fault in the build rather than as fire.


func test_a_flame_never_leaves_its_band() -> void:
	# The band is the whole safety property. A torch that dips to zero reads
	# as a bulb failing; one that doubles blows the tonemap out to white.
	for i in 2000:
		var scale := Flame.energy(i * 0.017, 0.0)
		assert_float(scale).is_between(Flame.LOW, Flame.HIGH)


func test_a_flame_actually_moves() -> void:
	var low := 99.0
	var high := -99.0
	for i in 2000:
		var scale := Flame.energy(i * 0.017, 0.0)
		low = minf(low, scale)
		high = maxf(high, scale)
	# It has to use most of the band it is given, or the constant it replaced
	# was cheaper and looked the same.
	assert_float(high - low).is_greater((Flame.HIGH - Flame.LOW) * 0.5)


func test_it_is_never_the_same_two_seconds_running() -> void:
	# Summed at incommensurable rates on purpose: a flicker that repeats on a
	# period is a strobe, and the eye finds a one-second loop immediately.
	var a: Array[float] = []
	var b: Array[float] = []
	for i in 200:
		a.append(Flame.energy(i * 0.01, 0.0))
		b.append(Flame.energy(1.0 + i * 0.01, 0.0))
	var apart := 0.0
	for i in a.size():
		apart = maxf(apart, absf(a[i] - b[i]))
	assert_float(apart).override_failure_message("the flicker repeats every second").is_greater(0.01)


func test_two_torches_in_a_room_do_not_pulse_together() -> void:
	# Twenty lights breathing in time is the tell. Every torch gets its own
	# phase, so the room shimmers rather than throbbing.
	var together := 0
	for i in 400:
		var t := i * 0.02
		if absf(Flame.energy(t, 0.0) - Flame.energy(t, Flame.phase_for(Vector3(9.0, 2.0, -12.0)))) < 0.002:
			together += 1
	assert_int(together).override_failure_message("two torches moved as one").is_less(40)


func test_the_phase_is_the_torch_position_and_is_stable() -> void:
	# Derived from where the torch is, not drawn from a stream: the same room
	# flickers the same way every time you walk back into it, and nothing has
	# to be stored per light.
	var at := Vector3(3.0, 1.98, -6.0)
	assert_float(Flame.phase_for(at)).is_equal(Flame.phase_for(at))
	assert_float(Flame.phase_for(at)).is_not_equal(Flame.phase_for(at + Vector3(3.0, 0.0, 0.0)))


func test_neighbouring_torches_get_phases_far_apart() -> void:
	# Adjacent brackets are the pair the eye compares. A hash that maps
	# neighbours to neighbouring phases would leave exactly those two in sync.
	var apart: Array[float] = []
	for i in 12:
		var a := Flame.phase_for(Vector3(i * Kit.CELL, 2.0, 0.0))
		var b := Flame.phase_for(Vector3((i + 1) * Kit.CELL, 2.0, 0.0))
		apart.append(absf(a - b))
	for gap in apart:
		assert_float(gap).override_failure_message("neighbours share a phase").is_greater(0.05)


func test_the_hero_torch_breathes_at_its_own_rate() -> void:
	# It is a hand's length from your eyes. On the wall rate it would read as
	# the whole room strobing rather than as the thing you are carrying.
	assert_float(Flame.HERO_RATE).is_not_equal(1.0)
	var wall := Flame.energy(0.7, 0.0)
	var hand := Flame.energy(0.7 * Flame.HERO_RATE, Flame.HERO_PHASE)
	assert_float(absf(wall - hand)).is_greater(0.001)


func test_a_light_is_driven_from_its_own_rest_energy() -> void:
	# The flicker multiplies whatever the light was authored at, so tuning a
	# torch's brightness never means re-tuning the flicker.
	var light := OmniLight3D.new()
	light.light_energy = 3.6
	Flame.drive(light, 3.6, 1.234)
	assert_float(light.light_energy).is_between(3.6 * Flame.LOW, 3.6 * Flame.HIGH)
	light.free()


func test_driving_a_freed_light_is_survivable() -> void:
	# Torches are freed with the floor while the frame that drives them is
	# still in flight, on every single descent.
	Flame.drive(null, 3.6, 0.5)
	assert_bool(true).is_true()
