class_name EnemyShape
extends RefCounted
## The silhouette a stand-in creature gets, and how it idles.
##
## STILL A STAND-IN. There is no rigged enemy model -- the one part of the
## no-artist pipeline stage 0 never proved -- and this does not pretend to be
## one. What it fixes is narrower and worth fixing on its own: every enemy in
## the game was the same capsule with a ball on top, so a rat, a spider, a
## floating wisp and a stack of skulls were four identical objects at four
## sizes. You could not tell what you were fighting, and telling what you are
## fighting is a rule of the genre, not a polish item.
##
## Silhouette is the cheapest possible way to carry that. Five archetypes,
## built from primitives, distinguishable in one glance at the edge of the
## torchlight. A real model replaces `build()` and nothing else.

enum Kind { HUMANOID, BEAST, WISP, STACK, HULK }

## Which archetype each enemy in the roster gets. An explicit table rather
## than inference from tags: `undead` covers a rat, a wisp and the boss, so
## tags cannot tell them apart, and guessing from hp would put the spider and
## the archer in the same bucket.
const SHAPES := {
	"bone_rat": Kind.BEAST,
	"crypt_spider": Kind.BEAST,
	"grave_wisp": Kind.WISP,
	"skull_stack": Kind.STACK,
	"shambler": Kind.HUMANOID,
	"bone_archer": Kind.HUMANOID,
	"hollow_knight": Kind.HUMANOID,
	"plague_bearer": Kind.HUMANOID,
	"ossuary_warden": Kind.HULK,
	"mother_of_bones": Kind.HULK,
}


static func kind_for(def: EnemyDef) -> int:
	if SHAPES.has(def.id):
		return SHAPES[def.id]
	# An enemy added to the data without a shape still gets a body. Big things
	# are hulks, small things are beasts, everything else stands up.
	if def.hp >= 55:
		return Kind.HULK
	if def.hp <= 14:
		return Kind.BEAST
	return Kind.HUMANOID


## How far off the ground the thing floats. Only a wisp does.
static func hover(kind: int) -> float:
	return 0.85 if kind == Kind.WISP else 0.0


## Seconds for one idle cycle. Slower for heavy things: a boss that fidgets at
## the same rate as a rat reads as weightless.
static func idle_seconds(kind: int) -> float:
	match kind:
		Kind.WISP:
			return 2.6
		Kind.BEAST:
			return 1.1
		Kind.HULK:
			return 3.4
		Kind.STACK:
			return 2.2
		_:
			return 1.9


## How far the idle moves it, in metres.
static func idle_travel(kind: int) -> float:
	match kind:
		Kind.WISP:
			return 0.22
		Kind.BEAST:
			return 0.05
		Kind.HULK:
			return 0.09
		_:
			return 0.06


## Builds the silhouette under `holder`, sized to `height` metres, using
## `material` throughout so the whole roster grades as one thing.
static func build(holder: Node3D, kind: int, height: float, material: StandardMaterial3D) -> void:
	match kind:
		Kind.BEAST:
			_beast(holder, height, material)
		Kind.WISP:
			_wisp(holder, height, material)
		Kind.STACK:
			_stack(holder, height, material)
		Kind.HULK:
			_hulk(holder, height, material)
		_:
			_humanoid(holder, height, material)


## Low and long, on four legs. Reads as "something down there" from across a
## room, which is the whole job.
static func _beast(holder: Node3D, height: float, material: StandardMaterial3D) -> void:
	var body := CapsuleMesh.new()
	body.radius = height * 0.26
	body.height = height * 1.15
	var spine := _mesh(holder, "Body", body, material, Vector3(0.0, height * 0.42, 0.0))
	# Lying along the ground rather than standing on end.
	spine.rotation = Vector3(PI * 0.5, 0.0, 0.0)

	var skull := SphereMesh.new()
	skull.radius = height * 0.19
	skull.height = height * 0.34
	_mesh(holder, "Head", skull, material, Vector3(0.0, height * 0.46, -height * 0.55))

	var leg := CylinderMesh.new()
	leg.top_radius = height * 0.05
	leg.bottom_radius = height * 0.03
	leg.height = height * 0.42
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var along := -0.28 if i < 2 else 0.28
		_mesh(holder, "Leg%d" % i, leg, material,
			Vector3(side * height * 0.24, height * 0.21, along * height))


## No legs, no ground contact: a head and a trailing tail of light. The one
## enemy whose silhouette says "this is not a body".
static func _wisp(holder: Node3D, height: float, material: StandardMaterial3D) -> void:
	var core := SphereMesh.new()
	core.radius = height * 0.26
	core.height = height * 0.52
	_mesh(holder, "Core", core, material, Vector3(0.0, height * 0.55, 0.0))
	var tail := CylinderMesh.new()
	tail.top_radius = height * 0.16
	tail.bottom_radius = 0.01
	tail.height = height * 0.55
	_mesh(holder, "Tail", tail, material, Vector3(0.0, height * 0.2, 0.0))


## Skulls piled on skulls. Distinct because it is lumpy where everything else
## is smooth.
static func _stack(holder: Node3D, height: float, material: StandardMaterial3D) -> void:
	var count := 4
	for i in count:
		var t := float(i) / float(count - 1)
		var skull := SphereMesh.new()
		var r := lerpf(height * 0.24, height * 0.14, t)
		skull.radius = r
		skull.height = r * 2.0
		var lean := (0.06 if i % 2 == 0 else -0.06) * height
		_mesh(holder, "Skull%d" % i, skull, material,
			Vector3(lean, r + height * 0.72 * t, lean * 0.5))


## Upright, with shoulders and arms. The default, and the one the eventual
## rigged model will replace first.
static func _humanoid(holder: Node3D, height: float, material: StandardMaterial3D) -> void:
	var torso := CapsuleMesh.new()
	torso.radius = height * 0.17
	torso.height = height * 0.62
	_mesh(holder, "Body", torso, material, Vector3(0.0, height * 0.46, 0.0))

	var skull := SphereMesh.new()
	skull.radius = height * 0.115
	skull.height = height * 0.23
	_mesh(holder, "Head", skull, material, Vector3(0.0, height * 0.88, 0.0))

	var arm := CapsuleMesh.new()
	arm.radius = height * 0.045
	arm.height = height * 0.44
	for side in [-1.0, 1.0]:
		_mesh(holder, "Arm%d" % int(side), arm, material,
			Vector3(side * height * 0.21, height * 0.5, 0.0))

	var leg := CapsuleMesh.new()
	leg.radius = height * 0.06
	leg.height = height * 0.42
	for side in [-1.0, 1.0]:
		_mesh(holder, "Leg%d" % int(side), leg, material,
			Vector3(side * height * 0.09, height * 0.2, 0.0))


## Wide, hunched, horned. A boss has to be a different shape and not just a
## bigger one, or the player reads "same enemy, more hp".
static func _hulk(holder: Node3D, height: float, material: StandardMaterial3D) -> void:
	var torso := CapsuleMesh.new()
	torso.radius = height * 0.27
	torso.height = height * 0.66
	var body := _mesh(holder, "Body", torso, material, Vector3(0.0, height * 0.5, 0.0))
	body.rotation = Vector3(0.16, 0.0, 0.0)

	var skull := SphereMesh.new()
	skull.radius = height * 0.14
	skull.height = height * 0.26
	_mesh(holder, "Head", skull, material, Vector3(0.0, height * 0.82, -height * 0.1))

	var horn := CylinderMesh.new()
	horn.top_radius = 0.005
	horn.bottom_radius = height * 0.035
	horn.height = height * 0.26
	for side in [-1.0, 1.0]:
		var h := _mesh(holder, "Horn%d" % int(side), horn, material,
			Vector3(side * height * 0.11, height * 0.94, -height * 0.09))
		h.rotation = Vector3(0.0, 0.0, side * 0.45)

	var arm := CapsuleMesh.new()
	arm.radius = height * 0.08
	arm.height = height * 0.55
	for side in [-1.0, 1.0]:
		var a := _mesh(holder, "Arm%d" % int(side), arm, material,
			Vector3(side * height * 0.31, height * 0.46, 0.0))
		a.rotation = Vector3(0.0, 0.0, side * -0.22)

	var leg := CapsuleMesh.new()
	leg.radius = height * 0.1
	leg.height = height * 0.36
	for side in [-1.0, 1.0]:
		_mesh(holder, "Leg%d" % int(side), leg, material,
			Vector3(side * height * 0.14, height * 0.18, 0.0))


static func _mesh(holder: Node3D, part: String, mesh: Mesh, material: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = part
	inst.mesh = mesh
	inst.material_override = material
	inst.position = at
	holder.add_child(inst)
	return inst
