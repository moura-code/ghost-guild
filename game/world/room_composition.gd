class_name RoomComposition
extends Node3D
## Authored silhouettes on reserved wall sockets. All floor-centre lanes and
## the middle combat volume stay clear. No gameplay RNG or shadow lights.

var _animated: Array[Node3D] = []
var _time: float = 0.0


static func sockets(layout: FloorLayout, room_index: int) -> Array:
	var room := layout.room_rect(room_index)
	var out: Array = []
	var doors := RoomSigns.doors(layout, room_index)
	for y in range(int(room["y"]), int(room["y"]) + int(room["h"])):
		for x in range(int(room["x"]), int(room["x"]) + int(room["w"])):
			var cell := Vector2i(x, y)
			# Merchant access, including its standing space, is always reserved.
			if cell.distance_to(RoomSigns.service_cell(layout, room_index)) < 1.5:
				continue
			var beside_door := false
			for door in doors:
				if cell.distance_to(door["cell"]) < 2.1:
					beside_door = true
			if beside_door:
				continue
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if layout.cell(x + direction.x, y + direction.y) == FloorLayout.Cell.WALL:
					out.append({"cell": cell, "back": direction,
						"at": Kit.cell_to_world(cell) + Vector3(direction.x, 0, direction.y) * 1.12})
					break
	return out


static func build(parent: Node3D, layout: FloorLayout, content: Content) -> RoomComposition:
	var root := RoomComposition.new()
	root.name = "RoomCompositions"
	parent.add_child(root)
	for i in layout.rooms.size():
		var id := String(layout.presets[i]) if i < layout.presets.size() else "neutral"
		var recipe: Dictionary = content.room_presets.get(id, {})
		root._room(layout, i, recipe)
	return root


func _room(layout: FloorLayout, index: int, recipe: Dictionary) -> void:
	var composition := String(recipe.get("composition", "aisle"))
	var spots := sockets(layout, index)
	var stone := material(Color(0.35, 0.39, 0.44))
	var bone := material(Color(0.70, 0.66, 0.53))
	var iron := material(Color(0.13, 0.16, 0.18), 0.65)
	var wood := material(Color(0.28, 0.16, 0.09))
	var green := material(Color(0.24, 0.52, 0.38), 0.0, 0.12)
	var ember := material(Color(0.69, 0.20, 0.045), 0.15, 0.35)
	var spectral := material(Color(0.20, 0.40, 0.64), 0.0, 0.12)
	for i in mini(spots.size(), 8):
		var spot: Dictionary = spots[i]
		var at: Vector3 = spot["at"]
		var back: Vector2i = spot["back"]
		var socket := Node3D.new()
		socket.name = composition + "Socket%d" % i
		socket.position = at
		socket.rotation.y = atan2(float(back.x), float(back.y))
		add_child(socket)
		match composition:
			"aisle":
				box(socket, "Sarcophagus", Vector3(1.5, 0.65, 0.6), Vector3(0, 0.325, 0), stone, true)
				box(socket, "Lid", Vector3(1.65, 0.10, 0.68), Vector3(0, 0.71, 0), bone)
				box(socket, "Inscription", Vector3(0.12, 0.015, 0.4), Vector3(0, 0.775, 0), iron)
			"vault":
				box(socket, "BrokenPier", Vector3(0.60, 1.0 + (i % 3) * 0.4, 0.55), Vector3(0, 0.5 + (i % 3) * 0.2, 0), stone, true)
				var slab := box(socket, "FallenCapital", Vector3(1.4, 0.35, 0.6), Vector3(0, 0.18, -0.05), stone)
				slab.rotation.z = 0.15 if i % 2 == 0 else -0.18
			"ossuary":
				box(socket, "BoneShelf", Vector3(1.45, 1.8, 0.25), Vector3(0, 0.9, 0.12), stone, true)
				for level in 3:
					box(socket, "Shelf", Vector3(1.5, 0.08, 0.55), Vector3(0, 0.4 + level * 0.5, -0.1), iron)
					for column in 4:
						sphere(socket, "Skull", Vector3(0.23, 0.27, 0.24), Vector3(-0.53 + column * 0.35, 0.56 + level * 0.5, -0.13), bone)
			"ritual":
				box(socket, "Obelisk", Vector3(0.42, 2.45, 0.4), Vector3(0, 1.22, 0), iron, true)
				box(socket, "Rune", Vector3(0.10, 1.4, 0.025), Vector3(0, 1.45, -0.215), spectral)
				_activity(socket, Vector3(0, 1.9, -0.42), spectral, int(recipe.get("ambient_budget", 0)))
			"workroom", "foundry":
				box(socket, "Bench", Vector3(1.65, 0.85, 0.55), Vector3(0, 0.425, 0), wood if composition == "workroom" else iron, true)
				box(socket, "Tools", Vector3(0.75, 0.12, 0.30), Vector3(0, 0.92, 0), iron)
				box(socket, "ToolRack", Vector3(1.4, 0.65, 0.12), Vector3(0, 1.65, 0.15), wood)
			"merchant":
				box(socket, "StockShelf", Vector3(1.5, 1.9, 0.30), Vector3(0, 0.95, 0), wood, true)
				for level in 3:
					box(socket, "Stock", Vector3(0.8, 0.25, 0.35), Vector3(0, 0.35 + level * 0.52, -0.12), bone)
				var cloth := box(socket, "Awning", Vector3(1.65, 0.05, 0.75), Vector3(0, 2.5, -0.15), material(Color(0.32, 0.16, 0.21)))
				_animated.append(cloth)
			"garden":
				for growth in 3:
					var h := 0.45 + growth * 0.4
					box(socket, "Stem", Vector3(0.13, h, 0.13), Vector3((growth - 1) * 0.42, h * 0.5, 0), bone)
					sphere(socket, "Cap", Vector3(0.62, 0.25, 0.6), Vector3((growth - 1) * 0.42, h, 0), green)
				_activity(socket, Vector3(0, 1.8, -0.25), green, int(recipe.get("ambient_budget", 0)))
			"roots":
				for root_index in 3:
					var root := box(socket, "Root", Vector3(0.24, 2.8, 0.22), Vector3((root_index - 1) * 0.4, 1.4, 0), wood)
					root.rotation.z = (root_index - 1) * 0.12
				_activity(socket, Vector3(0, 2.1, -0.24), green, int(recipe.get("ambient_budget", 0)))
			"cistern":
				box(socket, "Basin", Vector3(1.5, 0.5, 0.6), Vector3(0, 0.25, 0), stone, true)
				box(socket, "Water", Vector3(1.3, 0.02, 0.48), Vector3(0, 0.51, -0.04), spectral)
				_activity(socket, Vector3(0, 1.4, -0.15), spectral, int(recipe.get("ambient_budget", 0)))
			"furnace":
				box(socket, "Furnace", Vector3(1.45, 2.5, 0.6), Vector3(0, 1.25, 0), stone, true)
				box(socket, "Firebox", Vector3(0.8, 1.2, 0.02), Vector3(0, 0.95, -0.31), ember)
				for bar in 5:
					box(socket, "Grille", Vector3(0.055, 1.3, 0.05), Vector3((bar - 2) * 0.17, 0.95, -0.34), iron)
			"gantry":
				box(socket, "SteelPier", Vector3(0.45, 2.95, 0.4), Vector3(0, 1.47, 0), iron, true)
				for link in 8:
					sphere(socket, "Chain", Vector3(0.12, 0.22, 0.10), Vector3(0.5, 1.1 + link * 0.23, 0), iron)
	# A crown at the ceiling gives each room a readable architectural rhythm.
	var room := layout.room_rect(index)
	var center := Kit.cell_to_world(layout.room_center(index))
	if composition in ["aisle", "ritual", "gantry", "roots"]:
		box(self, "CeilingRib", Vector3(float(room["w"]) * Kit.CELL - 0.4, 0.18, 0.28), center + Vector3(0, Kit.WALL_H - 0.10, 0), iron if composition == "gantry" else stone)


func _activity(parent: Node3D, at: Vector3, mat: StandardMaterial3D, budget: int) -> void:
	if _animated.size() >= budget * 5:
		return
	var mote := sphere(parent, "AmbientMote", Vector3.ONE * 0.07, at, mat)
	mote.set_meta("rest_y", at.y)
	_animated.append(mote)


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for i in _animated.size():
		var ornament := _animated[i]
		if Settings.motion_reduced or camera.global_position.distance_squared_to(ornament.global_position) > 400:
			continue
		if ornament.has_meta("rest_y"):
			ornament.position.y = float(ornament.get_meta("rest_y")) + sin(_time * 0.8 + i * 1.7) * 0.09
		else:
			ornament.rotation.z = sin(_time * 0.6 + i) * 0.025


static func material(colour: Color, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mat.metallic = metallic
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = emission
	return mat


static func box(parent: Node3D, label: String, dimensions: Vector3, at: Vector3, mat: StandardMaterial3D, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var model := MeshInstance3D.new()
	model.name = label
	model.mesh = mesh
	model.material_override = mat
	model.position = at
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = DungeonBuilder.LAYER_WORLD
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = dimensions
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		model.add_child(body)
	return model


static func sphere(parent: Node3D, label: String, dimensions: Vector3, at: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.radius = 0.5
	mesh.height = 1.0
	var model := MeshInstance3D.new()
	model.name = label
	model.mesh = mesh
	model.material_override = mat
	model.position = at
	model.scale = dimensions
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
	return model
