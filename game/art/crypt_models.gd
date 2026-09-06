class_name CryptModels
extends RefCounted
## Original low-poly models. All geometry is editable and uses shared,
## untextured materials; no external models or runtime downloads are needed.

static var _materials: Dictionary = {}


static func material(hex: String, glow: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [hex, glow, metal]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.82
	mat.metallic = metal
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(hex)
		mat.emission_energy_multiplier = glow
	_materials[key] = mat
	return mat


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = shape
	part.material_override = mat
	part.position = at
	parent.add_child(part)
	return part


static func box(parent: Node3D, at: Vector3, extent: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = extent
	return mesh(parent, shape, at, mat)


static func orb(parent: Node3D, at: Vector3, extent: Vector3, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 12
	shape.rings = 6
	var part := mesh(parent, shape, at, mat)
	part.scale = extent
	return part


static func cylinder(parent: Node3D, at: Vector3, bottom: float, top: float,
		height: float, mat: Material, sides: int = 10) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = sides
	return mesh(parent, shape, at, mat)


static func bone(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var part := cylinder(parent, (a + b) * 0.5, radius, radius * 0.8, a.distance_to(b), mat, 6)
	var direction := (b - a).normalized()
	part.quaternion = Quaternion(Vector3.UP, direction)
	return part


static func ring(parent: Node3D, at: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 32
	shape.ring_segments = 6
	return mesh(parent, shape, at, mat)


## A triangulated, scalloped robe with a bent tail and alternating pleats.
static func robe(parent: Node3D, mat: Material, width: float = 1.0) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.34, 0.47, 0.38, 0.24, 0.07]
	var heights := [0.24, 0.62, 1.12, 1.58, 1.88]
	var sides := 16
	for level in range(4):
		for side in sides:
			var points: Array[Vector3] = []
			for corner in [[level, side], [level, side + 1], [level + 1, side + 1], [level + 1, side]]:
				var row := int(corner[0])
				var column := int(corner[1]) % sides
				var angle := TAU * float(column) / float(sides)
				var pleat := 1.0 if column % 2 == 0 else 0.86
				var radius := float(radii[row]) * width * pleat
				var hem := 0.14 * float(column % 2) if row == 0 else 0.0
				points.append(Vector3(cos(angle) * radius, float(heights[row]) + hem,
					sin(angle) * radius * 0.80 - 0.07 * float(row)))
			for index in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	mesh(parent, surface.commit(), Vector3.ZERO, mat)


static func ghost(kind: String = "true") -> Node3D:
	var root := Node3D.new()
	root.name = "Spirit"
	var shade := "559eaa"
	var light := "b2ffff"
	if kind == "echo":
		shade = "697baf"
		light = "c5d4ff"
	elif kind == "prepared":
		shade = "b29a5c"
		light = "ffe6a5"
	elif kind == "restless":
		shade = "9c5868"
		light = "ffc5ad"
	robe(root, material(shade, 0.22))
	orb(root, Vector3(0, 1.38, 0.23), Vector3(0.52, 0.60, 0.23), material("101f2a"))
	for side in [-1.0, 1.0]:
		orb(root, Vector3(side * 0.11, 1.42, 0.345), Vector3(0.064, 0.16, 0.04), material(light, 2.0))
		var sleeve := cylinder(root, Vector3(side * 0.45, 0.87, 0.03), 0.08, 0.17, 0.52, material(shade, 0.18))
		sleeve.rotation.z = side * -0.60
		orb(root, Vector3(side * 0.57, 0.62, 0.10), Vector3(0.13, 0.17, 0.13), material(light, 0.5))
	orb(root, Vector3(0, 1.03, 0.30), Vector3(0.12, 0.12, 0.07), material("d6bb76", 0.2, 0.6))
	return root


static func skull(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> Node3D:
	var head := Node3D.new()
	parent.add_child(head)
	head.position = at
	head.scale = Vector3.ONE * scale_factor
	var ivory := material("d5c6a4")
	orb(head, Vector3.ZERO, Vector3(0.49, 0.53, 0.40), ivory)
	box(head, Vector3(0, -0.19, 0.06), Vector3(0.30, 0.14, 0.29), ivory)
	for side in [-1.0, 1.0]:
		orb(head, Vector3(side * 0.115, 0.015, 0.178), Vector3(0.14, 0.16, 0.072), material("23232a"))
		orb(head, Vector3(side * 0.115, 0.015, 0.213), Vector3(0.043, 0.05, 0.023), material("ffb76e", 1.3))
	box(head, Vector3(0, -0.075, 0.205), Vector3(0.052, 0.09, 0.025), material("3b3434"))
	for i in 4:
		box(head, Vector3(-0.105 + float(i) * 0.07, -0.15, 0.217), Vector3(0.045, 0.075, 0.028), material("eee0ba"))
	return head


static func lantern(parent: Node3D, at: Vector3) -> void:
	var iron := material("544939", 0.0, 0.65)
	cylinder(parent, at, 0.16, 0.16, 0.08, iron)
	cylinder(parent, at + Vector3(0, 0.38, 0), 0.20, 0.08, 0.12, iron)
	orb(parent, at + Vector3(0, 0.20, 0), Vector3(0.18, 0.30, 0.18), material("ffcc7e", 1.8))
	for i in 4:
		var angle := TAU * float(i) / 4.0
		bone(parent, at + Vector3(cos(angle) * 0.13, 0.03, sin(angle) * 0.13),
			at + Vector3(cos(angle) * 0.13, 0.36, sin(angle) * 0.13), 0.019, iron)
	var handle := ring(parent, at + Vector3(0, 0.53, 0), 0.105, 0.017, iron)
	handle.rotation.x = PI * 0.5


static func actor(id: String) -> Node3D:
	if id in ["ghost", "grave_wisp", "echo", "prepared", "restless"]:
		return ghost(id if id != "ghost" and id != "grave_wisp" else "true")
	var root := Node3D.new()
	root.name = id.to_pascal_case()
	var ivory := material("cbbd9e")
	var iron := material("515867", 0.0, 0.65)
	var cloth := material("544450")
	match id:
		"bone_rat":
			orb(root, Vector3(0, 0.44, -0.05), Vector3(0.60, 0.55, 1.1), material("6d665e"))
			var head := skull(root, Vector3(0, 0.51, 0.54), 0.85)
			head.scale.z *= 1.45
			for side in [-1.0, 1.0]:
				orb(root, Vector3(side * 0.23, 0.78, 0.32), Vector3(0.21, 0.28, 0.12), ivory)
				for z in [-0.4, 0.32]:
					bone(root, Vector3(side * 0.20, 0.4, z), Vector3(side * 0.4, 0.1, z + 0.1), 0.055, ivory)
					bone(root, Vector3(side * 0.4, 0.1, z + 0.1), Vector3(side * 0.4, 0.06, z + 0.3), 0.055, ivory)
			for i in 5:
				var rib := ring(root, Vector3(0, 0.48, -0.36 + float(i) * 0.15), 0.30, 0.025, ivory)
				rib.rotation.x = PI * 0.5
			bone(root, Vector3(0, 0.32, -0.52), Vector3(0.4, 0.15, -1.1), 0.038, ivory)
			bone(root, Vector3(0.4, 0.15, -1.1), Vector3(0.8, 0.22, -1.32), 0.025, ivory)
		"crypt_spider":
			orb(root, Vector3(0, 0.48, -0.32), Vector3(0.85, 0.65, 0.95), material("423647"))
			orb(root, Vector3(0, 0.42, 0.31), Vector3(0.53, 0.42, 0.50), material("786754"))
			for side in [-1.0, 1.0]:
				for i in 4:
					var z := -0.50 + float(i) * 0.25
					var knee := Vector3(side * (1.0 + sin(float(i)) * 0.18), 0.64, z * 1.8)
					bone(root, Vector3(side * 0.20, 0.40, z), knee, 0.055, ivory)
					bone(root, knee, Vector3(knee.x * 1.17, 0.04, knee.z + 0.2), 0.035, ivory)
				for i in 3:
					orb(root, Vector3(side * (0.08 + float(i) * 0.065), 0.44, 0.54 - float(i) * 0.02), Vector3.ONE * 0.065, material("ff8164", 1.2))
		"skull_stack":
			for i in 4:
				var head := skull(root, Vector3(sin(float(i) * 2.0) * 0.12, 0.35 + float(i) * 0.42, 0), 1.0)
				head.rotation.z = sin(float(i) * 3.0) * 0.2
			cylinder(root, Vector3(0, 0.10, 0), 0.58, 0.48, 0.20, material("565052"))
		"sexton", "plague_bearer", "mother_of_bones":
			var tint := "484957" if id == "sexton" else "635b43"
			if id == "mother_of_bones":
				tint = "605061"
			robe(root, material(tint), 1.15)
			var head := skull(root, Vector3(0, 1.46, 0.22), 0.78)
			if id == "sexton":
				orb(head, Vector3(0, 0, 0.13), Vector3(0.39, 0.36, 0.18), material("252530"))
				box(head, Vector3(0, 0.07, 0.23), Vector3(0.28, 0.045, 0.03), material("b4a081"))
			for side in [-1.0, 1.0]:
				bone(root, Vector3(side * 0.29, 1.2, 0), Vector3(side * 0.55, 0.80, 0.17), 0.12, material(tint))
				orb(root, Vector3(side * 0.57, 0.77, 0.18), Vector3.ONE * 0.16, ivory)
			if id == "sexton":
				bone(root, Vector3(0.63, 0.12, 0.2), Vector3(0.63, 1.77, 0.2), 0.032, material("897457"))
				box(root, Vector3(0.63, 0.20, 0.2), Vector3(0.24, 0.35, 0.07), iron)
				lantern(root, Vector3(-0.60, 0.22, 0.2))
			elif id == "plague_bearer":
				orb(root, Vector3(0, 0.84, 0.37), Vector3(0.45, 0.55, 0.24), material("a6aa66", 0.18))
				lantern(root, Vector3(0.55, 0.19, 0.20))
			else:
				for i in 7:
					var a := PI * float(i) / 6.0
					bone(root, Vector3(cos(a) * 0.26, 1.63 + sin(a) * 0.21, 0),
						Vector3(cos(a) * 0.6, 1.76 + sin(a) * 0.62, 0), 0.04, ivory)
				for side in [-1.0, 1.0]:
					skull(root, Vector3(side * 0.49, 1.07, 0), 0.58)
		_:
			# Skeletons share anatomy, with a distinct stance and equipment.
			var armored := id in ["hollow_knight", "ossuary_warden"]
			for side in [-1.0, 1.0]:
				var knee := Vector3(side * 0.20, 0.45, 0.11)
				bone(root, Vector3(side * 0.16, 0.91, 0), knee, 0.065, ivory)
				bone(root, knee, Vector3(side * 0.25, 0.10, 0.04), 0.055, ivory)
				box(root, Vector3(side * 0.25, 0.065, 0.14), Vector3(0.17, 0.12, 0.33), iron if armored else ivory)
				var elbow := Vector3(side * 0.48, 0.97, 0.02)
				bone(root, Vector3(side * 0.24, 1.30, 0), elbow, 0.07, ivory)
				bone(root, elbow, Vector3(side * 0.60, 0.67, 0.2), 0.052, ivory)
				orb(root, Vector3(side * 0.60, 0.64, 0.2), Vector3(0.14, 0.20, 0.11), ivory)
			bone(root, Vector3(0, 0.8, 0), Vector3(0, 1.5, 0), 0.07, ivory)
			for i in 4:
				var rib := ring(root, Vector3(0, 1.06 + float(i) * 0.095, 0), 0.21 + float(i) * 0.019, 0.027, ivory)
				rib.scale.z = 0.62
			skull(root, Vector3(0, 1.69, 0.02))
			if armored:
				orb(root, Vector3(0, 1.2, 0), Vector3(0.66, 0.56, 0.36), iron)
				box(root, Vector3(0, 1.73, 0), Vector3(0.52, 0.25, 0.41), iron)
				for side in [-1.0, 1.0]:
					orb(root, Vector3(side * 0.36, 1.35, 0), Vector3(0.35, 0.24, 0.37), iron)
				bone(root, Vector3(0.63, 0.14, 0.2), Vector3(0.63, 1.57, 0.2), 0.032, material("acaba1", 0.0, 0.8))
				box(root, Vector3(0.63, 0.8, 0.2), Vector3(0.36, 0.06, 0.1), material("b09659", 0, 0.6))
				if id == "ossuary_warden":
					box(root, Vector3(-0.62, 0.8, 0.30), Vector3(0.65, 0.9, 0.13), iron)
					skull(root, Vector3(-0.62, 0.94, 0.41), 0.60)
			elif id == "bone_archer":
				for i in 8:
					var a := -1.1 + float(i) * 0.275
					var b := a + 0.275
					bone(root, Vector3(-0.55 - cos(a) * 0.38, 0.90 + sin(a) * 0.65, 0.2),
						Vector3(-0.55 - cos(b) * 0.38, 0.90 + sin(b) * 0.65, 0.2), 0.032, material("958066"))
				bone(root, Vector3(-0.72, 0.32, 0.2), Vector3(-0.72, 1.48, 0.2), 0.008, ivory)
			else:
				box(root, Vector3(0.05, 0.86, 0), Vector3(0.46, 0.28, 0.26), cloth)
				root.rotation.z = -0.08
	return root


static func candle(parent: Node3D, at: Vector3, height: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	cylinder(root, Vector3(0, height * 0.5, 0), 0.065, 0.058, height, material("cabc98"), 8)
	orb(root, Vector3(0, height + 0.10, 0), Vector3(0.08, 0.21, 0.08), material("ffbf6c", 2.2))
	return root


## An open-front, isometric crypt: tiled plinth, broken walls, vaulted
## doorway, sarcophagus, votives and a ritual circle around the residents.
static func chamber() -> Node3D:
	var root := Node3D.new()
	root.name = "Catacomb"
	var rock := material("3d414c")
	var edge := material("64616a")
	var gold := material("9f8860", 0, 0.45)
	box(root, Vector3(0, -0.32, 0), Vector3(6.7, 0.56, 4.8), material("252b39"))
	box(root, Vector3(0, -0.06, 0), Vector3(6.85, 0.14, 4.95), edge)
	for x in range(9):
		for z in range(6):
			var shade: String = ["454652", "51505a", "3c424f", "55535b"][(x * 7 + z * 3) % 4]
			box(root, Vector3(-2.97 + float(x) * 0.74, 0.025, -1.96 + float(z) * 0.77),
				Vector3(0.71, 0.12, 0.74), material(shade))
	# Back wall leaves the center open for the arched doorway.
	for side in [-1.0, 1.0]:
		for row in 6:
			for col in 2:
				box(root, Vector3(side * (1.88 + float(col) * 0.77), 0.24 + float(row) * 0.40, -2.15),
					Vector3(0.74, 0.37, 0.44), material("4c4a53" if (row + col) % 3 == 0 else "383e4b"))
		box(root, Vector3(side * 1.25, 0.88, -2.08), Vector3(0.34, 1.76, 0.66), edge)
		box(root, Vector3(side * 1.25, 0.13, -2.04), Vector3(0.53, 0.22, 0.83), rock)
		box(root, Vector3(side * 1.25, 1.65, -2.04), Vector3(0.52, 0.19, 0.81), gold)
		for z in range(4):
			var count := 4 - z if side < 0 else 2
			for row in count:
				box(root, Vector3(side * 3.15, 0.24 + float(row) * 0.40, -1.65 + float(z) * 0.73),
					Vector3(0.40, 0.37, 0.70), rock)
		cylinder(root, Vector3(side * 2.83, 0.55, 1.65), 0.24, 0.20, 1.0, rock, 8)
		cylinder(root, Vector3(side * 2.83, 1.07, 1.65), 0.30, 0.30, 0.13, gold, 8)
		for i in 3:
			candle(root, Vector3(side * 2.83 + float(i - 1) * 0.12, 1.14, 1.65), 0.25 + float(i % 2) * 0.16)
	for i in 11:
		var a := PI * float(i) / 10.0
		var stone := box(root, Vector3(cos(a) * 1.26, 1.68 + sin(a) * 1.26, -2.08), Vector3(0.39, 0.36, 0.66), edge)
		stone.rotation.z = a - PI * 0.5
	box(root, Vector3(0, 1.20, -2.49), Vector3(2.18, 2.55, 0.13), material("101722"))
	for i in 5:
		box(root, Vector3(0, 0.1 + float(i) * 0.095, -1.7 - float(i) * 0.14), Vector3(2.0, 0.14, 0.40), rock)
	# Carved sarcophagus in the rear left corner.
	box(root, Vector3(-2.05, 0.35, -0.95), Vector3(0.82, 0.58, 1.63), material("62616a"))
	box(root, Vector3(-2.05, 0.66, -0.95), Vector3(0.96, 0.13, 1.76), edge)
	box(root, Vector3(-2.05, 0.74, -0.95), Vector3(0.10, 0.06, 0.83), gold)
	box(root, Vector3(-2.05, 0.74, -1.1), Vector3(0.41, 0.06, 0.09), gold)
	ring(root, Vector3(0.4, 0.095, 0.22), 1.31, 0.017, material("86c5c9", 0.5))
	ring(root, Vector3(0.4, 0.095, 0.22), 1.13, 0.012, gold)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var rune := box(root, Vector3(0.4 + cos(a) * 1.22, 0.10, 0.22 + sin(a) * 1.22), Vector3(0.10, 0.015, 0.035), gold)
		rune.rotation.y = -a
	for i in 9:
		candle(root, Vector3(1.78 + float(i % 3) * 0.25, 0.10, -1.30 + float(i / 3) * 0.25), 0.18 + float((i * 7) % 4) * 0.11)
	skull(root, Vector3(2.50, 0.29, -0.6), 0.55)
	for i in 8:
		var debris := box(root, Vector3(-2.4 + float(i) * 0.65, 0.15, 1.7 + sin(float(i) * 6.0) * 0.14), Vector3(0.22, 0.16, 0.20), rock)
		debris.rotation.y = float(i) * 1.8
	return root
