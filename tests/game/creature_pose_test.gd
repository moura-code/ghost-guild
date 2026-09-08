extends GdUnitTestSuite
## The one animation system in the game a headless suite can actually see.
##
## Motion used to be tweens on node properties, which a `--headless` run reads
## back as the number it just wrote -- so nothing about how a creature moved was
## ever checked, and the bugs that produced (a corpse that breathes, a room of
## rats moving as one animal) are exactly the ones a still frame cannot show
## either. `CreaturePose` is pure maths, so all of it is checkable here.

const KINDS := [EnemyShape.Kind.HUMANOID, EnemyShape.Kind.BEAST, EnemyShape.Kind.WISP,
	EnemyShape.Kind.STACK, EnemyShape.Kind.HULK]


func _root(pose: Dictionary) -> Transform3D:
	return pose.get(CreaturePose.ROOT, Transform3D.IDENTITY)


# ----------------------------------------------------------------- the idle

func test_every_archetype_moves_when_it_is_doing_nothing() -> void:
	# A creature standing perfectly still is a prop, and the whole point of
	# putting it in the room with you is that it is not one.
	for kind in KINDS:
		var still := CreaturePose.pose(kind, 0.0, 0.0)
		var later := CreaturePose.pose(kind, CreaturePose.idle_seconds(kind) * 0.25, 0.0)
		var moved := false
		for joint in later:
			if not still.has(joint) or still[joint] != later[joint]:
				moved = true
		assert_bool(moved).override_failure_message(
			"archetype %d is a statue" % kind).is_true()


func test_the_idle_never_wanders_off() -> void:
	# Each archetype is a sum of oscillators at unrelated rates, deliberately:
	# one frequency reads as a metronome. So the property is not that it
	# repeats -- it does not -- but that it never accumulates. A creature that
	# drifts a millimetre a second walks out of its own room by floor three.
	for kind in KINDS:
		var furthest := 0.0
		for step in 400:
			var at := CreaturePose.idle(kind, float(step) * 0.05, 0.4)
			furthest = maxf(furthest, _root(at).origin.length())
		assert_float(furthest).override_failure_message(
			"archetype %d strays %.2f m from where it stands" % [kind, furthest]) \
			.is_less(0.35)


func test_a_dying_thing_stops_breathing() -> void:
	# The idle has to go out with the lights, or the corpse on the floor is
	# still visibly inhaling.
	var kind := EnemyShape.Kind.HUMANOID
	var a := CreaturePose.pose(kind, 0.4, 0.0, 0.0, 1.0)
	var b := CreaturePose.pose(kind, 1.1, 0.0, 0.0, 1.0)
	for joint in a:
		var same := (a[joint] as Transform3D).is_equal_approx(b[joint])
		assert_bool(same).override_failure_message(
			"a finished corpse still moves at joint %s" % joint).is_true()


func test_the_same_creature_always_moves_the_same_way() -> void:
	# A fight replays from its seed and the room has to replay with it.
	var a := CreaturePose.pose(EnemyShape.Kind.HULK, 2.5, 1.1, 0.3, 0.0)
	var b := CreaturePose.pose(EnemyShape.Kind.HULK, 2.5, 1.1, 0.3, 0.0)
	for joint in a:
		assert_bool((a[joint] as Transform3D).is_equal_approx(b[joint])).is_true()


func test_two_of_the_same_kind_get_different_phases() -> void:
	var first := CreaturePose.phase_for(0)
	var second := CreaturePose.phase_for(1)
	assert_float(second).is_not_equal(first)
	assert_float(CreaturePose.pose(EnemyShape.Kind.BEAST, 0.3, first)[CreaturePose.ROOT].origin.y) \
		.is_not_equal(
			CreaturePose.pose(EnemyShape.Kind.BEAST, 0.3, second)[CreaturePose.ROOT].origin.y)


func test_a_phase_is_an_angle_not_a_growing_number() -> void:
	# Indices keep climbing across a long fight; the phase must not.
	for index in [0, 1, 7, 40, 999]:
		var phase := CreaturePose.phase_for(index)
		assert_float(phase).is_greater_equal(0.0)
		assert_float(phase).is_less(TAU)


func test_a_boss_idles_slower_than_a_rat() -> void:
	# A boss that fidgets at a rat's rate reads as weightless.
	assert_float(CreaturePose.idle_seconds(EnemyShape.Kind.HULK)).is_greater(
		CreaturePose.idle_seconds(EnemyShape.Kind.BEAST))


# ---------------------------------------------------------------- the flinch

func test_a_flinch_takes_the_head_back_further_than_the_chest() -> void:
	# The lag is the whole reason a jointed creature reads better than a
	# sliding one: the parts arrive at the blow at different times.
	var hit := CreaturePose.flinch(EnemyShape.Kind.HUMANOID, 1.0)
	var head := (hit[CreaturePose.HEAD] as Transform3D).basis.get_euler().x
	var chest := (hit[CreaturePose.CHEST] as Transform3D).basis.get_euler().x
	assert_float(head).is_less(chest)
	assert_float(head).override_failure_message("it flinched forwards").is_less(0.0)


func test_a_bigger_number_is_a_bigger_flinch() -> void:
	var small := CreaturePose.flinch(EnemyShape.Kind.HUMANOID, 0.2)
	var big := CreaturePose.flinch(EnemyShape.Kind.HUMANOID, 1.0)
	assert_float(absf((big[CreaturePose.HEAD] as Transform3D).basis.get_euler().x)) \
		.is_greater(absf((small[CreaturePose.HEAD] as Transform3D).basis.get_euler().x))


func test_a_hulk_gives_less_than_a_wisp() -> void:
	# Weight is mostly how little a thing moves when you hit it.
	var hulk := absf((CreaturePose.flinch(EnemyShape.Kind.HULK, 1.0)[CreaturePose.HEAD]
		as Transform3D).basis.get_euler().x)
	var wisp := absf((CreaturePose.flinch(EnemyShape.Kind.WISP, 1.0)[CreaturePose.HEAD]
		as Transform3D).basis.get_euler().x)
	assert_float(hulk).is_less(wisp)


func test_a_settled_flinch_is_no_flinch_at_all() -> void:
	# Zero hurt has to be exactly the idle, or every creature in the game sits
	# permanently a few degrees back from where it was authored.
	var kind := EnemyShape.Kind.HUMANOID
	var idle := CreaturePose.idle(kind, 1.3, 0.2)
	var settled := CreaturePose.pose(kind, 1.3, 0.2, 0.0, 0.0)
	assert_int(settled.size()).is_equal(idle.size())
	for joint in idle:
		assert_bool((idle[joint] as Transform3D).is_equal_approx(settled[joint])) \
			.override_failure_message("joint %s never settles" % joint).is_true()


# --------------------------------------------------------------- the falling

func test_a_body_only_ever_goes_down() -> void:
	# A corpse that bobs back up on the way down is the single most obvious way
	# for a procedural death to look wrong.
	for kind in KINDS:
		var last := 1.0
		for step in 21:
			var t := float(step) / 20.0
			var y := _root(CreaturePose.collapse(kind, t)).origin.y
			assert_float(y).override_failure_message(
				"archetype %d rose again at t=%.2f" % [kind, t]).is_less_equal(last + 0.0001)
			last = y


func test_nothing_has_fallen_at_the_moment_of_death() -> void:
	for kind in KINDS:
		assert_vector(_root(CreaturePose.collapse(kind, 0.0)).origin).is_equal(Vector3.ZERO)


func test_a_finished_death_is_on_the_floor_and_face_down() -> void:
	var down := CreaturePose.collapse(EnemyShape.Kind.HUMANOID, 1.0)
	assert_float(_root(down).origin.y).is_less(-0.2)
	assert_float(_root(down).basis.get_euler().x).override_failure_message(
		"it fell over backwards up into the ceiling").is_less(-1.0)


func test_the_jaw_falls_open() -> void:
	# Small, and the difference between a corpse and a mannequin lying down.
	var shut := (CreaturePose.collapse(EnemyShape.Kind.HUMANOID, 0.0)[CreaturePose.JAW]
		as Transform3D).basis.get_euler().x
	var slack := (CreaturePose.collapse(EnemyShape.Kind.HUMANOID, 1.0)[CreaturePose.JAW]
		as Transform3D).basis.get_euler().x
	assert_float(slack).is_greater(shut)


func test_a_wisp_guttes_out_where_it_floats_rather_than_falling() -> void:
	var wisp := absf(_root(CreaturePose.collapse(EnemyShape.Kind.WISP, 1.0)).origin.y)
	var hulk := absf(_root(CreaturePose.collapse(EnemyShape.Kind.HULK, 1.0)).origin.y)
	assert_float(wisp).is_less(hulk)


# ------------------------------------------------------------- the composite

func test_a_flinch_is_on_top_of_the_breathing_rather_than_instead_of_it() -> void:
	var kind := EnemyShape.Kind.HUMANOID
	var calm := CreaturePose.pose(kind, 0.7, 0.3, 0.0, 0.0)
	var hurt := CreaturePose.pose(kind, 0.7, 0.3, 1.0, 0.0)
	# Same instant, so the idle term is identical and the difference is exactly
	# the flinch -- which is what "composes" has to mean.
	assert_float(_root(hurt).origin.z - _root(calm).origin.z).is_greater(0.1)
	assert_float(_root(hurt).origin.y).is_equal_approx(_root(calm).origin.y, 0.0001)


func test_dying_overrides_whatever_it_was_doing() -> void:
	var kind := EnemyShape.Kind.HUMANOID
	var alive := CreaturePose.pose(kind, 0.7, 0.3, 0.0, 0.0)
	var dead := CreaturePose.pose(kind, 0.7, 0.3, 0.0, 1.0)
	assert_float(_root(dead).origin.y).is_less(_root(alive).origin.y - 0.2)
