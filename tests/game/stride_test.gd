extends GdUnitTestSuite
## Walking, as maths.
##
## The suite cannot watch a camera, so the parts of "you feel like a person
## walking" that can be asserted are pulled out of the frame loop: how far a
## step is, how many of them two metres buys, and where the head is at the
## moment a foot lands. Whether it *feels* right is a question only running
## the game answers -- but "the head is highest when a foot lands" is a bug
## that a test can catch and a person playing probably cannot name.


func test_a_walking_step_is_about_a_stride_long() -> void:
	# Sanity, in metres. A step much shorter than this is a mouse; much
	# longer and you are gliding between footfalls.
	var walk := Stride.stride_length(Player.SPEED)
	assert_float(walk).is_between(0.9, 1.6)


func test_sprinting_lengthens_the_stride_rather_than_only_the_cadence() -> void:
	# Running is longer steps. If sprint only raised the rate, the feet would
	# machine-gun -- which is what a doubled walk cycle sounds like.
	assert_float(Stride.stride_length(Player.SPRINT)) \
		.is_greater(Stride.stride_length(Player.SPEED))


func test_cadence_rises_with_speed_but_by_less_than_the_speed_does() -> void:
	var walk_rate := Player.SPEED / Stride.stride_length(Player.SPEED)
	var sprint_rate := Player.SPRINT / Stride.stride_length(Player.SPRINT)
	assert_float(sprint_rate).is_greater(walk_rate)
	# Speed nearly doubles; the feet must not.
	assert_float(sprint_rate / walk_rate).is_less(Player.SPRINT / Player.SPEED)


func test_standing_still_never_takes_a_step() -> void:
	assert_float(Stride.advance(0.0, 0.0, Player.SPEED)).is_equal(0.0)
	assert_int(Stride.footfalls(0.0, Stride.advance(0.0, 0.0, Player.SPEED))).is_equal(0)


func test_walking_one_stride_length_is_exactly_one_footfall() -> void:
	var phase := Stride.advance(0.0, Stride.stride_length(Player.SPEED), Player.SPEED)
	assert_float(phase).is_equal_approx(1.0, 0.0001)
	assert_int(Stride.footfalls(0.0, phase)).is_equal(1)


func test_footfalls_count_the_boundaries_crossed_not_the_distance() -> void:
	# The phase is carried across frames, so what matters is how many whole
	# steps the interval contains -- never how far into a step it started.
	assert_int(Stride.footfalls(0.9, 1.1)).is_equal(1)
	assert_int(Stride.footfalls(1.1, 1.9)).is_equal(0)
	assert_int(Stride.footfalls(0.5, 3.5)).is_equal(3)
	assert_int(Stride.footfalls(2.0, 2.0)).is_equal(0)


func test_the_head_is_at_its_lowest_exactly_when_a_foot_lands() -> void:
	# Weight transfers onto the front foot as it lands. A bob that peaks on
	# the footfall reads as bouncing rather than walking, and it is the single
	# most common way a first-person bob is wrong.
	var down := Stride.bob_offset(0.0, 1.0).y
	assert_float(down).is_less(0.0)
	for t in [0.25, 0.5, 0.75]:
		assert_float(Stride.bob_offset(t, 1.0).y) \
			.override_failure_message("head lower off the footfall at %f" % t) \
			.is_greater(down - 0.0001)
	assert_float(Stride.bob_offset(1.0, 1.0).y).is_equal_approx(down, 0.0001)


func test_the_head_sways_to_one_side_then_the_other_over_two_steps() -> void:
	# Left foot, right foot. A sway with the same period as the dip means both
	# feet are on the same side of your body.
	var first := Stride.bob_offset(0.5, 1.0).x
	var second := Stride.bob_offset(1.5, 1.0).x
	assert_float(absf(first)).is_greater(0.0)
	assert_float(first * second).override_failure_message("both steps swayed the same way").is_less(0.0)
	assert_float(Stride.bob_offset(0.0, 1.0).x).is_equal_approx(0.0, 0.0001)
	assert_float(Stride.bob_offset(2.0, 1.0).x).is_equal_approx(0.0, 0.0001)


func test_a_still_camera_when_you_are_standing_still() -> void:
	# Amount is the eased speed, not the raw one, so this is also what makes
	# stopping settle rather than freeze the head mid-dip.
	assert_vector(Stride.bob_offset(0.37, 0.0)).is_equal(Vector3.ZERO)


func test_the_bob_never_leaves_the_stated_envelope() -> void:
	# The head moving more than a few centimetres is nausea, not immersion.
	for i in 200:
		var offset := Stride.bob_offset(i * 0.037, 1.0)
		assert_float(absf(offset.y)).is_less_equal(Stride.BOB_DOWN + 0.0001)
		assert_float(absf(offset.x)).is_less_equal(Stride.BOB_SIDE + 0.0001)


func test_the_amount_eases_toward_moving_and_back_to_still() -> void:
	# Reached, both ways, and never overshot -- an amount above 1 would push
	# the head outside the envelope the test above just fixed.
	var up := Stride.ease_amount(0.0, 1.0, 0.016)
	assert_float(up).is_between(0.0, 1.0)
	assert_float(up).is_greater(0.0)
	var settled := 1.0
	for i in 200:
		settled = Stride.ease_amount(settled, 0.0, 0.016)
	assert_float(settled).is_equal_approx(0.0, 0.02)
	var risen := 0.0
	for i in 200:
		risen = Stride.ease_amount(risen, 1.0, 0.016)
	assert_float(risen).is_equal_approx(1.0, 0.02)


func test_the_phase_does_not_grow_without_bound_over_a_long_walk() -> void:
	# A float phase that only ever increases loses its fractional precision
	# after a few kilometres, and the bob would visibly coarsen late in a run.
	var phase := 0.0
	for i in 5000:
		phase = Stride.advance(phase, 0.25, Player.SPEED)
	assert_float(phase).is_less(Stride.PHASE_WRAP + 1.0)
