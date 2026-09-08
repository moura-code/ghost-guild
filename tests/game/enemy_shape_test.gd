extends GdUnitTestSuite
## Every enemy used to be the same capsule with a ball on top, so a rat, a
## spider, a floating wisp and a stack of skulls were four identical objects at
## four sizes. Telling what you are fighting is a rule of the genre, not a
## polish item.


func _def(id: String) -> EnemyDef:
	return TestFixtures.content().enemies[id]


func test_the_whole_roster_has_a_silhouette() -> void:
	for id in TestFixtures.content().enemies:
		assert_bool(EnemyShape.SHAPES.has(String(id))).override_failure_message(
			"no shape for %s" % id).is_true()


func test_the_four_that_need_no_humanoid_rig_are_not_humanoids() -> void:
	# grave_wisp, skull_stack, crypt_spider and bone_rat are the four the art
	# brief singles out as needing no humanoid rig. Their silhouettes should
	# say so before any model arrives.
	for id in ["grave_wisp", "skull_stack", "crypt_spider", "bone_rat"]:
		assert_int(EnemyShape.kind_for(_def(id))).override_failure_message(
			"%s is shaped like a person" % id).is_not_equal(EnemyShape.Kind.HUMANOID)


func test_a_boss_is_a_different_shape_and_not_just_a_bigger_one() -> void:
	assert_int(EnemyShape.kind_for(_def("mother_of_bones"))).is_equal(EnemyShape.Kind.HULK)
	assert_int(EnemyShape.kind_for(_def("shambler"))).is_not_equal(EnemyShape.Kind.HULK)


func test_an_enemy_added_without_a_shape_still_gets_a_body() -> void:
	var made := EnemyDef.new()
	made.id = "not_in_the_table"
	made.hp = 20
	assert_int(EnemyShape.kind_for(made)).is_equal(EnemyShape.Kind.HUMANOID)
	made.hp = 80
	assert_int(EnemyShape.kind_for(made)).is_equal(EnemyShape.Kind.HULK)
	made.hp = 9
	assert_int(EnemyShape.kind_for(made)).is_equal(EnemyShape.Kind.BEAST)


func test_only_the_wisp_leaves_the_ground() -> void:
	assert_float(EnemyShape.hover(EnemyShape.Kind.WISP)).is_greater(0.0)
	for kind in [EnemyShape.Kind.HUMANOID, EnemyShape.Kind.BEAST, EnemyShape.Kind.STACK, EnemyShape.Kind.HULK]:
		assert_float(EnemyShape.hover(kind)).is_equal(0.0)


func test_heavy_things_idle_slower_than_light_ones() -> void:
	# A boss that fidgets at the same rate as a rat reads as weightless.
	assert_float(CreaturePose.idle_seconds(EnemyShape.Kind.HULK)).is_greater(
		CreaturePose.idle_seconds(EnemyShape.Kind.BEAST))


func test_each_archetype_builds_a_different_number_of_parts() -> void:
	var counts: Dictionary = {}
	for kind in [EnemyShape.Kind.HUMANOID, EnemyShape.Kind.BEAST, EnemyShape.Kind.WISP,
			EnemyShape.Kind.STACK, EnemyShape.Kind.HULK]:
		var holder: Node3D = auto_free(Node3D.new())
		add_child(holder)
		CreatureRig.build(holder, kind, 1.8, StandardMaterial3D.new(), Color.WHITE)
		var parts := _meshes_under(holder).size()
		assert_int(parts).override_failure_message(
			"archetype %d built nothing" % kind).is_greater(0)
		counts[kind] = parts
	# Not all the same shape by accident.
	var distinct: Dictionary = {}
	for kind in counts:
		distinct[counts[kind]] = true
	assert_int(distinct.size()).is_greater(2)


func test_every_bone_shares_the_one_material() -> void:
	# The roster has to grade as one thing, whatever shape each creature is.
	# Eyes, sockets and embers are the exceptions and say so in their names:
	# a light that dimmed with the body would not be a light.
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var material := StandardMaterial3D.new()
	CreatureRig.build(holder, EnemyShape.Kind.HULK, 2.4, material, Color.WHITE)
	var bones := 0
	for inst in _meshes_under(holder):
		var part := String(inst.name)
		var lit := part.begins_with("Eye") or part.begins_with("Socket")
		if lit or part == "Core" or part == "Halo":
			continue
		bones += 1
		assert_object(inst.material_override).override_failure_message(
			"%s is not made of the same stuff as the rest of it" % part).is_same(material)
	assert_int(bones).is_greater(8)


## Parts hang off joints now, so they are grandchildren rather than children.
func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child as MeshInstance3D)
		found.append_array(_meshes_under(child))
	return found


func test_a_wisp_body_floats_and_a_shambler_does_not() -> void:
	var wisp: EnemyBody = auto_free(EnemyBody.create(_def("grave_wisp"), 0))
	add_child(wisp)
	var walker: EnemyBody = auto_free(EnemyBody.create(_def("shambler"), 1))
	add_child(walker)
	assert_int(wisp.shape).is_equal(EnemyShape.Kind.WISP)
	assert_float(wisp.body_offset().y).is_greater(0.0)
	assert_float(walker.body_offset().y).is_equal(0.0)


func test_a_body_is_never_standing_perfectly_still() -> void:
	# The reason to put a creature in the room with you rather than on a card.
	var b: EnemyBody = auto_free(EnemyBody.create(_def("shambler"), 0))
	add_child(b)
	await await_millis(120)
	var first := b.pose_offset()
	await await_millis(400)
	assert_vector(b.pose_offset()).override_failure_message(
		"it has not moved in half a second").is_not_equal(first)


func test_two_of_the_same_creature_do_not_breathe_in_lockstep() -> void:
	# A room of three bone rats moving as one animal is worse than a room of
	# three still ones: it reads as a copy-paste rather than as three things.
	var a: EnemyBody = auto_free(EnemyBody.create(_def("bone_rat"), 0))
	add_child(a)
	var b: EnemyBody = auto_free(EnemyBody.create(_def("bone_rat"), 1))
	add_child(b)
	await await_millis(200)
	assert_vector(a.pose_offset()).is_not_equal(b.pose_offset())
