class_name BoneMesh
extends RefCounted
## The parts a crypt creature is made of.
##
## The enemies were five silhouettes built from whole primitives -- a capsule
## torso, a sphere head, four cylinder legs. Good enough to tell a rat from a
## boss across a room, which is what `EnemyShape` was written for, and not good
## enough to look at. A capsule with a ball on top is a mannequin; the wall two
## metres behind it is a photograph of sandstone.
##
## The fix is not an artist. It is that **this game's creatures are made of
## parts by nature.** A skeleton is a skull, a jaw, a cage of ribs and four
## long bones; a construct is plates bolted together; a fungal thing is a stalk
## under a cap. Assembling one out of pieces is not a workaround for having no
## model -- it is what the thing is, and it is why the pieces can then move
## independently, which is the half that actually reads as alive.
##
## Every builder returns a `Node3D` with its parts under it, positioned in
## local metres with the part's own origin at its joint, so a rig can rotate it
## and the geometry swings the right way. Nothing here knows what a creature is.

## Two points of light in the dark are the cheapest possible "it is looking at
## you", and the only part of a creature the player can see from outside the
## torchlight. Bright enough to find, small enough not to light the room -- and
## smaller than the socket it sits in, or it reads as a googly eye rather than
## as something burning inside the skull.
const EYE_ENERGY := 2.6
const EYE_RADIUS := 0.045


## A skull: cranium, brow, a muzzle that juts, a jaw hung under it, and two
## sockets with something burning in them.
##
## `size` is the cranium's diameter. The jaw is a separate child called "Jaw"
## because a rig chatters it, and the eyes are separate materials because they
## have to go out when the body fades rather than glowing on a corpse.
static func skull(size: float, material: StandardMaterial3D, eye_colour: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Skull"

	ellipsoid(root, "Cranium", Vector3(0, size * 0.06, size * 0.03),
		Vector3(size * 0.88, size * 0.94, size * 1.04), material)
	var muzzle := BoxMesh.new()
	muzzle.size = Vector3(size * 0.38, size * 0.16, size * 0.30)
	_part(root, "Muzzle", muzzle, material, Vector3(0, -size * 0.19, -size * 0.40))
	var dark := _socket_material()
	ellipsoid(root, "SocketNose", Vector3(0, -size * 0.11, -size * 0.55),
		Vector3(size * 0.12, size * 0.20, size * 0.07), dark)

	var jaw_node := Node3D.new()
	jaw_node.name = "Jaw"
	jaw_node.position = Vector3(0, -size * 0.18, -size * 0.12)
	root.add_child(jaw_node)
	var jaw := BoxMesh.new()
	jaw.size = Vector3(size * 0.46, size * 0.11, size * 0.42)
	_part(jaw_node, "Bone", jaw, material, Vector3(0, -size * 0.18, -size * 0.24))
	for side: float in [-1.0, 1.0]:
		link(jaw_node, "Hinge", Vector3(side * size * 0.24, 0, 0),
			Vector3(side * size * 0.20, -size * 0.18, -size * 0.40), size * 0.045, material)
		ellipsoid(root, "Socket%d" % int(side), Vector3(side * size * 0.205, size * 0.015, -size * 0.465),
			Vector3(size * 0.29, size * 0.265, size * 0.14), dark)
		link(root, "Brow", Vector3(side * size * 0.065, size * 0.11, -size * 0.49),
			Vector3(side * size * 0.34, size * 0.16, -size * 0.39), size * 0.05, material)
		ellipsoid(root, "Cheek", Vector3(side * size * 0.31, -size * 0.12, -size * 0.37),
			Vector3(size * 0.19, size * 0.16, size * 0.28), material)
		ellipsoid(root, "Eye%d" % int(side), Vector3(side * size * 0.205, size * 0.015, -size * 0.54),
			Vector3.ONE * size * EYE_RADIUS * 2.0, eye_material(eye_colour))
	for i in 6:
		var tooth := BoxMesh.new()
		tooth.size = Vector3(size * 0.045, size * (0.072 if i % 2 == 0 else 0.06), size * 0.06)
		_part(root, "Tooth%d" % i, tooth, material,
			Vector3((float(i) - 2.5) * size * 0.057, -size * 0.28, -size * 0.53))

	return root


## A cage of ribs on a spine. Rings rather than a barrel: you can see through
## a ribcage, and being able to see the wall through a thing is most of what
## says it is dead.
static func rib_cage(length: float, width: float, material: StandardMaterial3D,
		ribs: int = 5) -> Node3D:
	var root := Node3D.new()
	root.name = "Cage"
	for i in ribs:
		var t := float(i) / float(maxi(1, ribs - 1))
		# Widest at the chest and tapering to the waist, which is the shape
		# that reads as a torso from the side as well as the front.
		var r := width * lerpf(0.52, 0.30, t * t)
		var ring := TorusMesh.new()
		ring.inner_radius = maxf(0.001, r - width * 0.055)
		ring.outer_radius = r
		ring.rings = 32
		ring.ring_segments = 10
		var rib := _part(root, "Rib%d" % i, ring, material,
			Vector3(0.0, -length * t, 0.0))
		rib.rotation = Vector3(0.08 + t * 0.10, 0.0, 0.0)
		rib.scale = Vector3(1.0, 1.0, 0.72)

	var spine_link := BoxMesh.new()
	spine_link.size = Vector3(width * 0.14, length * 1.06, width * 0.14)
	_part(root, "Spine", spine_link, material, Vector3(0.0, -length * 0.5, width * 0.2))
	return root


## A long bone: a shaft with a knuckle at each end. Its origin is the top
## knuckle, so a rig hangs it off a joint and rotates it about the socket.
static func long_bone(length: float, radius: float, material: StandardMaterial3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Limb"
	var shaft := CylinderMesh.new()
	shaft.top_radius = radius * 0.72
	shaft.bottom_radius = radius * 0.62
	shaft.height = length
	shaft.radial_segments = 12
	_part(root, "Shaft", shaft, material, Vector3(0.0, -length * 0.5, 0.0))
	for end in [0.0, -length]:
		var knuckle := SphereMesh.new()
		knuckle.radius = radius
		knuckle.height = radius * 1.7
		knuckle.radial_segments = 16
		knuckle.rings = 8
		_part(root, "End%d" % int(end * 100.0), knuckle, material, Vector3(0.0, end, 0.0))
	return root


## A horn or a spine: tapered, and pointing up its own local Y.
static func horn(length: float, radius: float, material: StandardMaterial3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Horn"
	var cone := CylinderMesh.new()
	cone.top_radius = radius * 0.06
	cone.bottom_radius = radius
	cone.height = length
	_part(root, "Point", cone, material, Vector3(0.0, length * 0.5, 0.0))
	return root


## A mushroom cap. Flattened hemisphere plus the gills under it, because a
## dome alone is a helmet.
static func cap(radius: float, material: StandardMaterial3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Cap"
	var dome := SphereMesh.new()
	dome.radius = radius
	dome.height = radius * 1.5
	var top := _part(root, "Dome", dome, material, Vector3.ZERO)
	top.scale = Vector3(1.0, 0.62, 1.0)

	var gills := CylinderMesh.new()
	gills.top_radius = radius * 0.92
	gills.bottom_radius = radius * 0.55
	gills.height = radius * 0.22
	_part(root, "Gills", gills, material, Vector3(0.0, -radius * 0.2, 0.0))
	return root


## A slab of a construct: bevelled by being three boxes rather than one, so
## its edges catch the lantern instead of going flat.
static func plate(size: Vector3, material: StandardMaterial3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Plate"
	var face := BoxMesh.new()
	face.size = size
	_part(root, "Face", face, material, Vector3.ZERO)
	var lip := BoxMesh.new()
	lip.size = Vector3(size.x * 1.08, size.y * 0.16, size.z * 1.08)
	_part(root, "Top", lip, material, Vector3(0.0, size.y * 0.46, 0.0))
	_part(root, "Bottom", lip, material, Vector3(0.0, -size.y * 0.46, 0.0))
	return root


## A burning core: the thing a wisp actually is. Two shells, the outer one
## unshaded and transparent, so it reads as light rather than as a lamp.
static func ember(radius: float, colour: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Ember"
	var core := SphereMesh.new()
	core.radius = radius
	core.height = radius * 2.0
	_part(root, "Core", core, null, Vector3.ZERO).material_override = eye_material(colour)

	var halo := SphereMesh.new()
	halo.radius = radius * 2.1
	halo.height = radius * 4.2
	var glow := _part(root, "Halo", halo, null, Vector3.ZERO)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.albedo_color = Color(colour.r, colour.g, colour.b, 0.10)
	m.disable_receive_shadows = true
	glow.material_override = m
	return root


## The material an eye or an ember burns with. Unshaded: a light source that
## dims when the room does is not a light source.
static func eye_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = EYE_ENERGY
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = true
	return m


## Every eye and ember material under `root`, so a death can put them out.
## Collected by walking the tree rather than returned from each builder,
## because a rig assembles parts from several builders and would otherwise
## have to thread a list through all of them.
static func lights_in(root: Node) -> Array[StandardMaterial3D]:
	var found: Array[StandardMaterial3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			var inst := child as MeshInstance3D
			var name := String(inst.name)
			if (name.begins_with("Eye") or name == "Core" or name == "Halo") \
					and inst.material_override is StandardMaterial3D:
				found.append(inst.material_override as StandardMaterial3D)
		found.append_array(lights_in(child))
	return found


static func _socket_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.03)
	m.roughness = 1.0
	m.metallic = 0.0
	return m


## A continuous surface of revolution, with optional fabric pleats and a
## ragged hem. Shared by robes, armor and fungal stalks. UVs and outward
## normals are authored alongside the vertices so small folds catch light.
static func loft(profile: Array[Vector2], segments: int = 32, pleat: float = 0.0,
		ragged: float = 0.0) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size() - 1):
		for side in segments:
			for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0),
					Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var level: int = row + corner.x
				var angle := TAU * float(side + corner.y) / float(segments)
				var section := profile[level]
				var radius := section.x * (1.0 + cos(angle * 8.0) * pleat)
				var height := section.y + (sin(angle * 5.0) * ragged if level == 0 else 0.0)
				var slope := profile[mini(level + 1, profile.size() - 1)] - profile[maxi(0, level - 1)]
				surface.set_normal(Vector3(cos(angle) * slope.y, -slope.x, sin(angle) * slope.y).normalized())
				surface.set_uv(Vector2(float(side + corner.y) / float(segments), float(level) / float(profile.size() - 1)))
				surface.add_vertex(Vector3(cos(angle) * radius, height, sin(angle) * radius))
	return surface.commit()


## A tapered connection, useful for fingers, bow limbs and articulated legs.
static func link(parent: Node3D, name: String, from: Vector3, to: Vector3,
		radius: float, material: StandardMaterial3D, taper: float = 0.72) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.height = from.distance_to(to)
	shape.bottom_radius = radius
	shape.top_radius = radius * taper
	shape.radial_segments = 10
	var part := _part(parent, name, shape, material, (from + to) * 0.5)
	part.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return part


static func ellipsoid(parent: Node3D, name: String, at: Vector3, extent: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 20
	shape.rings = 12
	var part := _part(parent, name, shape, material, at)
	part.scale = extent
	return part


static func _part(holder: Node3D, part: String, mesh: Mesh,
		material: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = part
	inst.mesh = mesh
	if material != null:
		inst.material_override = material
	inst.position = at
	holder.add_child(inst)
	return inst
