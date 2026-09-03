extends GdUnitTestSuite
## The creature the parts add up to.
##
## Geometry lives in the scene tree, which a headless run does not render, but
## it does keep the transforms -- so what is checkable here is the *skeleton*:
## that every archetype has the joints its pose will try to drive, that the
## joints are where a body's joints go, and that applying a pose actually moves
## them. The bug this exists to catch is silent by nature: a joint the rig
## never built is a joint the pose writes into nothing.


func _rig(kind: int, height: float = 1.8) -> Array:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var rig := CreatureRig.build(holder, kind, height, StandardMaterial3D.new(),
		Color(0.5, 0.9, 1.0))
	return [rig, holder]


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child as MeshInstance3D)
		found.append_array(_meshes(child))
	return found


# ------------------------------------------------------------ what got built

func test_every_archetype_has_the_joints_its_own_pose_drives() -> void:
	# The silent one. A pose writing into a joint that was never built does
	# nothing at all and looks exactly like an animation nobody wrote.
	for kind in [EnemyShape.Kind.HUMANOID, EnemyShape.Kind.BEAST, EnemyShape.Kind.WISP,
			EnemyShape.Kind.STACK, EnemyShape.Kind.HULK]:
		var built: CreatureRig = _rig(kind)[0]
		var driven := CreaturePose.idle(kind, 0.4, 0.0)
		for joint in driven:
			assert_bool(built.has_joint(String(joint))).override_failure_message(
				"archetype %d idles a joint called %s that it never built" % [kind, joint]) \
				.is_true()


func test_a_creature_is_made_of_more_than_a_handful_of_pieces() -> void:
	# Five whole primitives is a mannequin. The point of building out of parts
	# is that you can see through a ribcage.
	for kind in [EnemyShape.Kind.HUMANOID, EnemyShape.Kind.BEAST, EnemyShape.Kind.HULK]:
		var pair := _rig(kind)
		assert_int(_meshes(pair[1]).size()).override_failure_message(
			"archetype %d is %d pieces" % [kind, _meshes(pair[1]).size()]).is_greater(14)


func test_it_stands_on_the_floor_and_fits_under_its_own_height() -> void:
	# The collider and the head anchor are both derived from the height, so
	# geometry that hangs below zero or pokes out the top is a body that does
	# not match the thing you can click on.
	for kind in [EnemyShape.Kind.HUMANOID, EnemyShape.Kind.BEAST, EnemyShape.Kind.STACK,
			EnemyShape.Kind.HULK]:
		var pair := _rig(kind, 2.0)
		for inst in _meshes(pair[1]):
			var y: float = (inst as Node3D).global_position.y
			assert_float(y).override_failure_message(
				"archetype %d has a %s underground" % [kind, inst.name]).is_greater(-0.35)
			assert_float(y).override_failure_message(
				"archetype %d has a %s above its own head" % [kind, inst.name]).is_less(2.4)


func test_a_beast_stands_on_four_legs_under_two_joint_names() -> void:
	var rig: CreatureRig = _rig(EnemyShape.Kind.BEAST)[0]
	var left: Array = rig.joints[CreaturePose.LEG_L]
	var right: Array = rig.joints[CreaturePose.LEG_R]
	assert_int(left.size() + right.size()).is_equal(4)
	# And they stand in four different places, which is the bug that a single
	# rest transform per joint name would quietly produce.
	var places: Dictionary = {}
	for leg in left + right:
		places[(leg as Node3D).position] = true
	assert_int(places.size()).override_failure_message(
		"the four legs are stacked in one spot").is_equal(4)


func test_only_a_wisp_burns_without_a_skull() -> void:
	var wisp: CreatureRig = _rig(EnemyShape.Kind.WISP)[0]
	assert_bool(wisp.has_joint(CreaturePose.HEAD)).is_true()
	assert_bool(wisp.has_joint(CreaturePose.LEG_L)).override_failure_message(
		"the thing that floats grew legs").is_false()


func test_a_hulk_is_a_different_shape_and_not_just_a_bigger_one() -> void:
	# A boss with the same silhouette at a larger size reads as "same enemy,
	# more hp", which is the one thing a boss must not read as.
	var hulk: Array = _rig(EnemyShape.Kind.HULK, 1.8)
	var walker: Array = _rig(EnemyShape.Kind.HUMANOID, 1.8)
	assert_int(_meshes(hulk[1]).size()).is_not_equal(_meshes(walker[1]).size())


# ------------------------------------------------------------- what it does

func test_applying_a_pose_actually_moves_the_joints() -> void:
	var rig: CreatureRig = _rig(EnemyShape.Kind.HUMANOID)[0]
	var head := rig.joint_node(CreaturePose.HEAD)
	var rest := head.transform
	rig.apply(CreaturePose.collapse(EnemyShape.Kind.HUMANOID, 1.0))
	assert_bool(head.transform.is_equal_approx(rest)).override_failure_message(
		"the head did not move when the body fell over").is_false()


func test_a_pose_is_an_offset_from_rest_not_a_replacement_for_it() -> void:
	# The arms are rotated at rest so they hang away from the ribs. A pose that
	# overwrote the joint instead of composing with it would snap them flat.
	var rig: CreatureRig = _rig(EnemyShape.Kind.HUMANOID)[0]
	var arm := rig.joint_node(CreaturePose.ARM_L)
	var rest := arm.rotation.z
	assert_float(rest).override_failure_message(
		"the arm hangs flat against the ribs at rest").is_not_equal(0.0)
	rig.apply(CreaturePose.idle(EnemyShape.Kind.HUMANOID, 0.0, 0.0))
	# Composed, so it is neither the rest angle nor the pose's own angle.
	assert_float(arm.rotation.z).is_not_equal(rest)
	assert_float(arm.rotation.z).override_failure_message(
		"the pose replaced the rest instead of composing with it").is_not_equal(0.10)
	assert_float(absf(arm.rotation.z - rest)).is_less(0.3)


func test_an_empty_pose_puts_everything_back_where_it_started() -> void:
	var rig: CreatureRig = _rig(EnemyShape.Kind.BEAST)[0]
	var before: Array = []
	for leg in rig.joints[CreaturePose.LEG_L]:
		before.append((leg as Node3D).transform)
	rig.apply(CreaturePose.collapse(EnemyShape.Kind.BEAST, 1.0))
	rig.apply({})
	for i in before.size():
		assert_bool((rig.joints[CreaturePose.LEG_L][i] as Node3D).transform \
			.is_equal_approx(before[i])).is_true()


# ------------------------------------------------------------------ the eyes

func test_a_creature_has_something_burning_in_its_head() -> void:
	# Two points of light are the only part of a creature the player can see
	# from outside the torchlight.
	for kind in [EnemyShape.Kind.HUMANOID, EnemyShape.Kind.BEAST, EnemyShape.Kind.WISP,
			EnemyShape.Kind.STACK, EnemyShape.Kind.HULK]:
		var rig: CreatureRig = _rig(kind)[0]
		assert_int(rig.lights.size()).override_failure_message(
			"archetype %d has nothing lit on it" % kind).is_greater(0)


func test_the_lights_go_out_and_come_back_to_what_they_were() -> void:
	var rig: CreatureRig = _rig(EnemyShape.Kind.HUMANOID)[0]
	var lit: Array[float] = []
	for m in rig.lights:
		lit.append(m.emission_energy_multiplier)
	rig.set_light(0.0)
	for m in rig.lights:
		assert_float(m.emission_energy_multiplier).is_equal(0.0)
	rig.set_light(1.0)
	for i in rig.lights.size():
		assert_float(rig.lights[i].emission_energy_multiplier).override_failure_message(
			"relighting a corpse made it brighter than it ever was") \
			.is_equal_approx(lit[i], 0.0001)


func test_what_a_thing_is_made_of_decides_what_colour_it_burns() -> void:
	# Cold for the dead, hot for anything the Kiln built.
	var undead := CreatureRig.eye_colour(["undead"])
	var fire := CreatureRig.eye_colour(["construct", "fire"])
	assert_float(fire.r).is_greater(fire.b)
	assert_float(undead.b).is_greater(undead.r)
	assert_bool(CreatureRig.eye_colour(["nothing_authored"]) == CreatureRig.DEFAULT_EYE) \
		.override_failure_message("an untagged creature burns some other colour").is_true()
