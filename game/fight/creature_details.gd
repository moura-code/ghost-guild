class_name CreatureDetails
extends RefCounted
## Equipment and growths attach to the existing joints, so they follow the
## same breathing, recoil and collapse as the body wearing them.


static func dress(joints: Dictionary, h: float, id: String, skin: StandardMaterial3D, kind: int) -> void:
	if id.is_empty():
		return
	var iron := _finish(skin, Color("8995a0"), 0.38, 0.68)
	var brass := _finish(skin, Color("b49765"), 0.46, 0.61)
	var cloth := _finish(skin, Color("3e4a4b"), 0.0, 0.98)
	var leather := _finish(skin, Color("564134"), 0.0, 0.89)
	match id:
		"bone_rat":
			_rat(joints, h, skin)
		"shambler":
			_tabard(joints, h, cloth, false)
		"bone_archer":
			_archer(joints, h, leather, brass)
		"hollow_knight", "ossuary_warden", "kiln_warden":
			_armor(joints, h, iron, brass, kind == EnemyShape.Kind.HULK)
			_sword(joints, h, iron, brass)
			_tabard(joints, h, _finish(skin, Color("4d3440"), 0.0, 0.98), false)
			if id == "ossuary_warden":
				_shield(joints, h, iron, brass)
		"plague_bearer":
			_tabard(joints, h, cloth, true)
			_vials(joints, h, brass)
		"mother_of_bones":
			_tabard(joints, h, _finish(skin, Color("302e3e"), 0.0, 1.0), true)
			_crown(joints, h, skin, brass)
		"spore_hound", "bloom_wretch", "mycelial_husk", "cap_thrower", "thorn_polyp", \
			"flesh_weaver", "deep_lurker", "sporemother", "the_bloom":
			_fungus(joints, h, id, skin, kind == EnemyShape.Kind.BEAST and id != "flesh_weaver")
		"cinder_hound", "slag_crawler", "furnace_drone", "clay_sentinel", \
			"molten_husk", "the_bellows":
			_furnace(joints, h, iron, brass, kind)
		"glass_shrike":
			_crystals(joints, h, _finish(skin, Color("a0bac3"), 0.5, 0.16))


static func _joint(joints: Dictionary, label: String) -> Node3D:
	var nodes: Array = joints.get(label, [])
	return nodes[0] if not nodes.is_empty() else null


static func _finish(base: StandardMaterial3D, colour: Color, metal: float, rough: float) -> StandardMaterial3D:
	var mat := base.duplicate() as StandardMaterial3D
	mat.albedo_color = colour
	mat.albedo_texture = null
	mat.metallic = metal
	mat.roughness = rough
	mat.roughness_texture = null
	mat.normal_scale = 0.18
	mat.rim = 0.28
	return mat


static func _group(parent: Node3D, label: String, h: float) -> Node3D:
	var group := Node3D.new()
	group.name = label
	group.scale = Vector3.ONE * h
	parent.add_child(group)
	return group


static func _plate(parent: Node3D, label: String, at: Vector3, extent: Vector3,
		mat: StandardMaterial3D) -> Node3D:
	var part := BoneMesh.plate(extent, mat)
	part.name = label
	part.position = at
	parent.add_child(part)
	return part


static func _surface(parent: Node3D, label: String, profile: Array[Vector2],
		mat: StandardMaterial3D, pleat: float = 0.0, ragged: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = BoneMesh.loft(profile, 32, pleat, ragged)
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh


static func _armor(joints: Dictionary, h: float, iron: StandardMaterial3D, brass: StandardMaterial3D, large: bool) -> void:
	var chest := _group(_joint(joints, CreaturePose.CHEST), "Armor", h)
	var cuirass := _surface(chest, "Cuirass", [Vector2(0.12, -0.28), Vector2(0.15, -0.22),
		Vector2(0.19, -0.06), Vector2(0.15, 0.025)], iron)
	cuirass.scale.z = 0.70
	BoneMesh.link(chest, "BreastRidge", Vector3(0, -0.25, -0.093), Vector3(0, 0.015, -0.14), 0.013, brass)
	for side: float in [-1.0, 1.0]:
		var shoulder := _plate(chest, "Pauldron", Vector3(side * 0.20, -0.015, 0), Vector3(0.16, 0.11, 0.22), iron)
		shoulder.rotation.z = side * -0.24
		for y in [-0.07, -0.15, -0.22]:
			BoneMesh.ellipsoid(chest, "Rivet", Vector3(side * 0.115, y, -0.115), Vector3.ONE * 0.018, brass)
	var head := _group(_joint(joints, CreaturePose.HEAD), "Helm", h * (1.35 if large else 1.0))
	_surface(head, "Crown", [Vector2(0.118, -0.06), Vector2(0.127, 0.055),
		Vector2(0.087, 0.13), Vector2(0.005, 0.16)], iron).scale.z = 1.05
	_plate(head, "Visor", Vector3(0, -0.015, -0.123), Vector3(0.185, 0.13, 0.032), iron)
	_plate(head, "BrowBand", Vector3(0, 0.063, -0.123), Vector3(0.225, 0.023, 0.035), brass)
	var shadow := StandardMaterial3D.new()
	shadow.albedo_color = Color("0b1015")
	_plate(head, "EyeSlit", Vector3(0, 0.025, -0.142), Vector3(0.145, 0.021, 0.008), shadow)
	for side: float in [-1.0, 1.0]:
		BoneMesh.ellipsoid(head, "EyeVisor%d" % int(side), Vector3(side * 0.038, 0.025, -0.149),
			Vector3(0.024, 0.009, 0.008), BoneMesh.eye_material(Color("a7e5e8")))
	for joint in [CreaturePose.LEG_L, CreaturePose.LEG_R]:
		var leg := _group(_joint(joints, joint), "Greave", h)
		_plate(leg, "ShinPlate", Vector3(0, -0.28, -0.035), Vector3(0.09, 0.20, 0.065), iron)


static func _sword(joints: Dictionary, h: float, iron: StandardMaterial3D, brass: StandardMaterial3D) -> void:
	var sword := _group(_joint(joints, CreaturePose.ARM_R), "Sword", h)
	sword.position = Vector3(0, -h * 0.37, -h * 0.055)
	BoneMesh.link(sword, "Grip", Vector3(0, 0.04, 0), Vector3(0, -0.07, 0), 0.019, brass)
	BoneMesh.link(sword, "Guard", Vector3(-0.085, -0.055, 0), Vector3(0.085, -0.055, 0), 0.015, brass, 1.0)
	_surface(sword, "Blade", [Vector2(0.001, -0.34), Vector2(0.036, -0.09), Vector2(0.027, -0.07)], iron).scale.z = 0.24


static func _shield(joints: Dictionary, h: float, iron: StandardMaterial3D, brass: StandardMaterial3D) -> void:
	var shield := _group(_joint(joints, CreaturePose.ARM_L), "Shield", h)
	shield.position = Vector3(-h * 0.03, -h * 0.29, -h * 0.12)
	_surface(shield, "Kite", [Vector2(0.005, -0.24), Vector2(0.19, -0.025),
		Vector2(0.18, 0.18), Vector2(0.005, 0.22)], iron).scale.z = 0.20
	BoneMesh.link(shield, "Spine", Vector3(0, -0.22, -0.043), Vector3(0, 0.19, -0.043), 0.013, brass)
	BoneMesh.ellipsoid(shield, "Boss", Vector3(0, 0, -0.045), Vector3(0.10, 0.10, 0.07), brass)


static func _tabard(joints: Dictionary, h: float, cloth: StandardMaterial3D, hood: bool) -> void:
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var chest := _group(_joint(joints, CreaturePose.CHEST), "BurialCloth", h)
	_surface(chest, "Skirt", [Vector2(0.22, -0.56), Vector2(0.17, -0.38),
		Vector2(0.12, -0.27)], cloth, 0.08, 0.05).scale.z = 0.68
	if hood:
		_surface(chest, "Mantle", [Vector2(0.21, -0.30), Vector2(0.18, -0.06),
			Vector2(0.25, 0.03), Vector2(0.10, 0.09)], cloth, 0.06, 0.02).scale.z = 0.72
		var head := _group(_joint(joints, CreaturePose.HEAD), "Cowl", h)
		_surface(head, "Hood", [Vector2(0.125, -0.10), Vector2(0.14, 0.07),
			Vector2(0.06, 0.16), Vector2(0.005, 0.20)], cloth).position.z = 0.035
	else:
		_plate(chest, "Strap", Vector3(-0.10, -0.14, -0.13), Vector3(0.047, 0.31, 0.018), cloth).rotation.z = -0.35


static func _archer(joints: Dictionary, h: float, wood: StandardMaterial3D, brass: StandardMaterial3D) -> void:
	_tabard(joints, h, wood, false)
	var bow := _group(_joint(joints, CreaturePose.ARM_L), "Bow", h)
	bow.position = Vector3(0, -h * 0.32, -h * 0.08)
	var points: Array[Vector3] = [Vector3(0, -0.34, -0.01), Vector3(-0.10, -0.23, -0.045),
		Vector3(-0.14, -0.08, -0.07), Vector3(-0.14, 0.08, -0.07),
		Vector3(-0.10, 0.23, -0.045), Vector3(0, 0.34, -0.01)]
	for i in points.size() - 1:
		BoneMesh.link(bow, "Limb%d" % i, points[i], points[i + 1], 0.018, wood, 0.88)
	BoneMesh.link(bow, "String", points[0], points[-1], 0.003, brass, 1.0)
	var quiver := _group(_joint(joints, CreaturePose.CHEST), "Quiver", h)
	quiver.position = Vector3(h * 0.13, -h * 0.07, h * 0.15)
	quiver.rotation.z = -0.30
	BoneMesh.link(quiver, "Leather", Vector3(0, -0.24, 0), Vector3(0, 0.06, 0), 0.06, wood, 1.0)
	for i in 4:
		var at := Vector3((float(i % 2) - 0.5) * 0.045, 0, (float(i / 2) - 0.5) * 0.045)
		BoneMesh.link(quiver, "Arrow", at, at + Vector3(0, 0.23, 0), 0.006, wood, 1.0)
		_plate(quiver, "Fletching", at + Vector3(0, 0.20, 0), Vector3(0.026, 0.052, 0.008), brass)


static func _rat(joints: Dictionary, h: float, skin: StandardMaterial3D) -> void:
	var head := _group(_joint(joints, CreaturePose.HEAD), "RatFeatures", h)
	for side: float in [-1.0, 1.0]:
		BoneMesh.ellipsoid(head, "Ear", Vector3(side * 0.094, 0.08, 0.013), Vector3(0.095, 0.13, 0.025), skin)
		BoneMesh.link(head, "Incisor", Vector3(side * 0.018, -0.045, -0.155),
			Vector3(side * 0.018, -0.10, -0.17), 0.010, skin)
	BoneMesh.ellipsoid(head, "Snout", Vector3(0, -0.017, -0.11), Vector3(0.12, 0.085, 0.15), skin)


static func _vials(joints: Dictionary, h: float, brass: StandardMaterial3D) -> void:
	var root := _group(_joint(joints, CreaturePose.CHEST), "PlagueVials", h)
	var glass := _finish(brass, Color("82996a"), 0.1, 0.24)
	glass.emission = Color("719249")
	glass.emission_energy_multiplier = 0.25
	for i in 3:
		var at := Vector3((float(i) - 1) * 0.095, -0.25, -0.15)
		BoneMesh.ellipsoid(root, "Vial", at, Vector3(0.055, 0.105, 0.055), glass)
		BoneMesh.link(root, "Stopper", at + Vector3(0, 0.045, 0), at + Vector3(0, 0.07, 0), 0.020, brass)


static func _crown(joints: Dictionary, h: float, bone: StandardMaterial3D, brass: StandardMaterial3D) -> void:
	var crown := _group(_joint(joints, CreaturePose.HEAD), "BoneCrown", h)
	_surface(crown, "Band", [Vector2(0.137, 0.065), Vector2(0.145, 0.105)], brass)
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var at := Vector3(cos(angle) * 0.14, 0.09, sin(angle) * 0.14)
		BoneMesh.link(crown, "Tine", at, at + Vector3(cos(angle) * 0.07, 0.08 + float(i % 3) * 0.025, sin(angle) * 0.07), 0.021, bone, 0.02)


static func _fungus(joints: Dictionary, h: float, id: String, skin: StandardMaterial3D, low_body: bool) -> void:
	var cap_mat := _finish(skin, Color("806e9b"), 0.0, 0.86)
	var gill_mat := _finish(skin, Color("c6b790"), 0.0, 0.94)
	var head := _group(_joint(joints, CreaturePose.HEAD), "FungalCrown", h)
	var radius := 0.29 if id in ["cap_thrower", "sporemother", "the_bloom"] else 0.19
	var cap_height := 0.085 if id in ["deep_lurker", "sporemother", "the_bloom"] else 0.13
	var cap := BoneMesh.cap(radius, cap_mat)
	cap.position = Vector3(0, cap_height, 0.015)
	head.add_child(cap)
	(cap.get_node("Gills") as MeshInstance3D).material_override = gill_mat
	for i in 7:
		var a := float(i) * 2.399963
		var r := radius * (0.40 if i % 2 == 0 else 0.72)
		BoneMesh.ellipsoid(head, "SporeSpot", Vector3(cos(a) * r, cap_height + radius * 0.35, sin(a) * r),
			Vector3(0.046, 0.014, 0.034), gill_mat)
	var anchor := _joint(joints, CreaturePose.CHEST)
	if anchor == null:
		anchor = _joint(joints, CreaturePose.HEAD)
	var growth := _group(anchor, "FungalGrowth", h)
	if low_body:
		growth.rotation.x = PI * 0.5
	for i in 4:
		var at := Vector3((-1.0 if i % 2 == 0 else 1.0) * 0.19, -float(i / 2) * 0.12, 0.025)
		BoneMesh.link(growth, "Stalk", at, at + Vector3(0.025, 0.10, 0), 0.015, gill_mat)
		var bud := BoneMesh.cap(0.07 + float(i % 2) * 0.022, cap_mat)
		bud.position = at + Vector3(0.025, 0.11, 0)
		bud.rotation.z = -0.22 if i % 2 == 0 else 0.22
		growth.add_child(bud)


static func _furnace(joints: Dictionary, h: float, iron: StandardMaterial3D, brass: StandardMaterial3D, kind: int) -> void:
	var chest := _group(_joint(joints, CreaturePose.CHEST), "Furnace", h)
	if kind == EnemyShape.Kind.BEAST:
		chest.rotation.x = PI * 0.5
	elif kind == EnemyShape.Kind.STACK:
		chest.position.y = h * 0.22
	_plate(chest, "Housing", Vector3(0, -0.13, 0), Vector3(0.35, 0.32, 0.25), iron)
	var core := BoneMesh.ember(0.062, Color("ff8b3d"))
	core.position = Vector3(0, -0.13, -0.14)
	chest.add_child(core)
	for i in 5:
		var x := (float(i) - 2) * 0.039
		BoneMesh.link(chest, "Grille", Vector3(x, -0.23, -0.17), Vector3(x, -0.03, -0.17), 0.010, brass, 1.0)
	for side: float in [-1.0, 1.0]:
		BoneMesh.link(chest, "Flue", Vector3(side * 0.15, 0, 0.07), Vector3(side * 0.19, 0.20, 0.07), 0.039, iron, 1.0)


static func _crystals(joints: Dictionary, h: float, glass: StandardMaterial3D) -> void:
	var head := _group(_joint(joints, CreaturePose.HEAD), "GlassFan", h)
	for i in 9:
		var turn := float(i) * TAU / 9.0
		var spike := BoneMesh.horn(0.26 + float(i % 3) * 0.06, 0.049, glass)
		spike.position = Vector3(cos(turn) * 0.08, 0, sin(turn) * 0.08)
		spike.rotation = Vector3(sin(turn) * 0.85, 0, -cos(turn) * 0.85)
		head.add_child(spike)
