class_name CreatureRig
extends RefCounted
## A creature assembled out of `BoneMesh` parts, hung off joints that
## `CreaturePose` can move.
##
## The old bodies were a bag of `MeshInstance3D` children at fixed offsets, and
## the only thing that ever moved was the bag: one tween on the holder's
## position for the idle, another for the flinch, and a rotation on the whole
## `StaticBody3D` for the death. A creature that only ever translates as a rigid
## block is a prop being nudged, and no amount of texture fixes that.
##
## So the parts hang off named joints instead. The head is a child of the chest,
## the jaw a child of the skull, and every frame each joint is set to
## `rest * offset` from a pose table. Nothing is skinned and there is no
## `AnimationPlayer`: these creatures are piles of bone and plate, so rigid
## parts on a hierarchy is not a shortcut around skinning, it is the correct
## model of the thing.
##
## One joint name may hold several nodes -- a beast has four legs and two
## joints -- so `joints` maps a name to an array.

## Where the light in an eye socket comes from, by what the thing is made of.
## Cold for the dead, hot for anything the Kiln built. Read off the enemy's
## tags for the same reason the body tint is: a creature is coloured by what it
## is, not by a per-enemy art field nobody would keep in step.
const EYE_BY_TAG := [
	["fire", Color(1.0, 0.62, 0.24)],
	["construct", Color(1.0, 0.78, 0.36)],
	["fungal", Color(0.62, 0.95, 0.55)],
	["undead", Color(0.55, 0.92, 0.98)],
	["flesh", Color(0.98, 0.72, 0.62)],
]
const DEFAULT_EYE := Color(0.72, 0.86, 0.95)

var kind: int = EnemyShape.Kind.HUMANOID
var joints: Dictionary = {}
var rests: Dictionary = {}
## Every eye and ember material, so a death can put the lights out, paired
## with the energy and alpha it was authored at -- a halo is a tenth of an
## alpha by design and must not be relit to one.
var lights: Array[StandardMaterial3D] = []
var _lit_rest: Array[Vector2] = []


static func eye_colour(tags: Array) -> Color:
	for entry in EYE_BY_TAG:
		if tags.has(String(entry[0])):
			return entry[1]
	return DEFAULT_EYE


## Builds a creature `height` metres tall under `holder`.
static func build(holder: Node3D, creature_kind: int, height: float,
		material: StandardMaterial3D, eye: Color) -> CreatureRig:
	var rig := CreatureRig.new()
	rig.kind = creature_kind
	var root := rig._joint(holder, CreaturePose.ROOT, Vector3.ZERO)
	match creature_kind:
		EnemyShape.Kind.BEAST:
			rig._beast(root, height, material, eye)
		EnemyShape.Kind.WISP:
			rig._wisp(root, height, material, eye)
		EnemyShape.Kind.STACK:
			rig._stack(root, height, material, eye)
		EnemyShape.Kind.HULK:
			rig._hulk(root, height, material, eye)
		_:
			rig._humanoid(root, height, material, eye)
	rig.lights = BoneMesh.lights_in(root)
	for m in rig.lights:
		rig._lit_rest.append(Vector2(m.emission_energy_multiplier, m.albedo_color.a))
	return rig


## Sets every joint the pose names. Joints the pose does not name are left at
## rest, which is how one pose table serves five different skeletons.
func apply(pose: Dictionary) -> void:
	for name in joints:
		var offset: Transform3D = pose.get(name, Transform3D.IDENTITY)
		var nodes: Array = joints[name]
		var rest: Array = rests[name]
		# Rests are per node, not per name: a beast's four legs share two joint
		# names and stand in four different places, and driving them all from
		# the first one's rest piles the whole animal into one leg.
		for i in nodes.size():
			(nodes[i] as Node3D).transform = (rest[i] as Transform3D) * offset


## How bright the eyes burn, 0..1 of their authored energy. A corpse's lights
## go out; that is most of what makes a kill land.
func set_light(level: float) -> void:
	var t := clampf(level, 0.0, 1.0)
	for i in lights.size():
		var rest: Vector2 = _lit_rest[i]
		lights[i].emission_energy_multiplier = rest.x * t
		lights[i].albedo_color.a = rest.y * t


func joint_node(name: String) -> Node3D:
	var found: Array = joints.get(name, [])
	return found[0] if not found.is_empty() else null


func has_joint(name: String) -> bool:
	return joints.has(name)


# ----------------------------------------------------------------- archetypes

## Upright, and a person's proportions only in outline: a cage of ribs on legs
## with a skull over it. The one the player fights most.
func _humanoid(root: Node3D, h: float, mat: StandardMaterial3D, eye: Color) -> void:
	var pelvis := BoneMesh.plate(Vector3(h * 0.22, h * 0.09, h * 0.14), mat)
	pelvis.position = Vector3(0.0, h * 0.43, 0.0)
	root.add_child(pelvis)

	var chest := _joint(root, CreaturePose.CHEST, Vector3(0.0, h * 0.78, 0.0))
	var cage := BoneMesh.rib_cage(h * 0.34, h * 0.34, mat)
	chest.add_child(cage)

	var head := _joint(chest, CreaturePose.HEAD, Vector3(0.0, h * 0.09, 0.0))
	var skull := BoneMesh.skull(h * 0.2, mat, eye)
	head.add_child(skull)
	_adopt_jaw(skull)

	for side in [-1.0, 1.0]:
		var arm := _joint(chest, CreaturePose.ARM_L if side < 0.0 else CreaturePose.ARM_R,
			Vector3(side * h * 0.19, -h * 0.02, 0.0), Vector3(0.0, 0.0, side * -0.12))
		arm.add_child(BoneMesh.long_bone(h * 0.42, h * 0.032, mat))
	for side in [-1.0, 1.0]:
		var leg := _joint(root, CreaturePose.LEG_L if side < 0.0 else CreaturePose.LEG_R,
			Vector3(side * h * 0.09, h * 0.42, 0.0))
		leg.add_child(BoneMesh.long_bone(h * 0.42, h * 0.045, mat))


## Low and long on four legs, head out front. Reads as "something down there"
## from across a room, which is the whole job of a silhouette in the dark.
func _beast(root: Node3D, h: float, mat: StandardMaterial3D, eye: Color) -> void:
	# The cage is built hanging down its own -Y, so the joint lies it along +Z
	# and the ribs become a barrel seen from the side.
	var chest := _joint(root, CreaturePose.CHEST, Vector3(0.0, h * 0.52, -h * 0.2),
		Vector3(-PI * 0.5, 0.0, 0.0))
	chest.add_child(BoneMesh.rib_cage(h * 0.62, h * 0.3, mat, 4))

	var head := _joint(root, CreaturePose.HEAD, Vector3(0.0, h * 0.5, -h * 0.32))
	var skull := BoneMesh.skull(h * 0.2, mat, eye)
	head.add_child(skull)
	_adopt_jaw(skull)

	var tail := _joint(root, CreaturePose.TAIL, Vector3(0.0, h * 0.5, h * 0.4),
		Vector3(-1.9, 0.0, 0.0))
	tail.add_child(BoneMesh.long_bone(h * 0.34, h * 0.022, mat))

	# Four legs on two joint names: the front pair leads and the back pair
	# trails, and the pose only has to know about two of them.
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var front := i < 2
		var name := CreaturePose.LEG_L if side < 0.0 else CreaturePose.LEG_R
		var leg := _joint(root, name,
			Vector3(side * h * 0.19, h * 0.44, (-h * 0.26) if front else (h * 0.24)),
			Vector3((-0.2 if front else 0.2), 0.0, side * 0.1))
		leg.add_child(BoneMesh.long_bone(h * 0.44, h * 0.03, mat))


## No legs and no ground contact: a core burning inside a hanging rag of
## itself. The one enemy whose silhouette says "this is not a body".
func _wisp(root: Node3D, h: float, mat: StandardMaterial3D, eye: Color) -> void:
	var head := _joint(root, CreaturePose.HEAD, Vector3(0.0, h * 0.58, 0.0))
	head.add_child(BoneMesh.ember(h * 0.11, eye))

	# Tatters, hanging and swinging off the core. Three, at unequal lengths:
	# two would read as legs and four as a jellyfish.
	var lengths := [0.46, 0.3, 0.38]
	for i in 3:
		var turn := TAU * float(i) / 3.0 + 0.4
		var rag := BoneMesh.horn(h * float(lengths[i]), h * 0.05, mat)
		rag.position = Vector3(cos(turn) * h * 0.07, -h * 0.05, sin(turn) * h * 0.07)
		rag.rotation = Vector3(PI, 0.0, cos(turn) * 0.2)
		head.add_child(rag)


## Skulls piled on skulls, held up by nothing you can see. Lumpy where
## everything else is smooth, and the only creature with no single head.
func _stack(root: Node3D, h: float, mat: StandardMaterial3D, eye: Color) -> void:
	var chest := _joint(root, CreaturePose.CHEST, Vector3(0.0, h * 0.12, 0.0))
	var spine := BoneMesh.plate(Vector3(h * 0.1, h * 0.5, h * 0.1), mat)
	spine.position = Vector3(0.0, h * 0.25, 0.0)
	chest.add_child(spine)

	# The lower half of the pile leans with the spine; the upper half is its
	# own joint, so the top of the stack lags behind the bottom and the whole
	# thing reads as balanced rather than glued.
	var head := _joint(chest, CreaturePose.HEAD, Vector3(0.0, h * 0.44, 0.0))
	var placed := [
		[chest, 0.06, 0.24, -1.0],
		[chest, 0.3, 0.2, 1.0],
		[head, 0.02, 0.18, 1.0],
		[head, 0.2, 0.14, -1.0],
	]
	for i in placed.size():
		var row: Array = placed[i]
		var skull := BoneMesh.skull(h * float(row[2]), mat, eye)
		skull.position = Vector3(float(row[3]) * h * 0.05, h * float(row[1]), 0.0)
		skull.rotation = Vector3(0.1, float(row[3]) * (0.5 + float(i) * 0.3), float(row[3]) * 0.2)
		(row[0] as Node3D).add_child(skull)


## Wide, hunched and horned. A boss has to be a different shape and not just a
## bigger one, or the player reads "same enemy, more hp".
func _hulk(root: Node3D, h: float, mat: StandardMaterial3D, eye: Color) -> void:
	var pelvis := BoneMesh.plate(Vector3(h * 0.28, h * 0.11, h * 0.18), mat)
	pelvis.position = Vector3(0.0, h * 0.42, 0.0)
	root.add_child(pelvis)

	var chest := _joint(root, CreaturePose.CHEST, Vector3(0.0, h * 0.8, 0.0),
		Vector3(0.14, 0.0, 0.0))
	# Narrower than it was. A cage as wide as the creature is tall reads as a
	# barrel on legs rather than as a chest, and the shoulders stop meaning
	# anything because there is nothing narrower for them to sit above.
	chest.add_child(BoneMesh.rib_cage(h * 0.36, h * 0.4, mat, 6))
	for side in [-1.0, 1.0]:
		var pauldron := BoneMesh.plate(Vector3(h * 0.16, h * 0.1, h * 0.18), mat)
		pauldron.position = Vector3(side * h * 0.25, -h * 0.01, 0.0)
		pauldron.rotation = Vector3(0.0, 0.0, side * -0.34)
		chest.add_child(pauldron)

	var head := _joint(chest, CreaturePose.HEAD, Vector3(0.0, h * 0.05, -h * 0.06))
	var skull := BoneMesh.skull(h * 0.26, mat, eye)
	head.add_child(skull)
	_adopt_jaw(skull)
	for side in [-1.0, 1.0]:
		var horn := BoneMesh.horn(h * 0.3, h * 0.045, mat)
		horn.position = Vector3(side * h * 0.11, h * 0.09, -h * 0.02)
		horn.rotation = Vector3(-0.4, 0.0, side * 0.7)
		head.add_child(horn)

	for side in [-1.0, 1.0]:
		var arm := _joint(chest, CreaturePose.ARM_L if side < 0.0 else CreaturePose.ARM_R,
			Vector3(side * h * 0.28, -h * 0.05, 0.0), Vector3(0.0, 0.0, side * -0.2))
		arm.add_child(BoneMesh.long_bone(h * 0.52, h * 0.055, mat))
	for side in [-1.0, 1.0]:
		var leg := _joint(root, CreaturePose.LEG_L if side < 0.0 else CreaturePose.LEG_R,
			Vector3(side * h * 0.13, h * 0.42, 0.0))
		leg.add_child(BoneMesh.long_bone(h * 0.42, h * 0.07, mat))


# --------------------------------------------------------------------- wiring

## Registers a joint. Several nodes may answer to one name -- four legs, two
## joints -- and `apply` drives all of them together.
func _joint(parent: Node3D, name: String, at: Vector3,
		turn: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = "%s%d" % [name, int(joints.get(name, []).size())]
	node.position = at
	node.rotation = turn
	parent.add_child(node)
	if not joints.has(name):
		joints[name] = []
		rests[name] = []
	joints[name].append(node)
	(rests[name] as Array).append(node.transform)
	return node


## Promotes the jaw a skull built into a joint the pose can drive, so the mouth
## hangs open when the thing dies instead of staying politely shut.
func _adopt_jaw(skull: Node3D) -> void:
	var jaw := skull.get_node_or_null("Jaw")
	if jaw == null:
		return
	if not joints.has(CreaturePose.JAW):
		joints[CreaturePose.JAW] = []
		rests[CreaturePose.JAW] = []
	joints[CreaturePose.JAW].append(jaw)
	(rests[CreaturePose.JAW] as Array).append((jaw as Node3D).transform)
