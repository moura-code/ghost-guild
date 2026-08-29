class_name EnemyBody
extends StaticBody3D
## The enemy, standing in the room you walked into.
##
## THE MESH IS A STAND-IN. There is still no rigged enemy model -- it is the
## one part of the no-artist pipeline stage 0 did not prove -- and the pivot is
## not going to wait for it. Everything around this node is model-agnostic:
## the staging, the targeting, the animator and the HUD all talk to `recoil`,
## `die`, `head_point` and `index`. Dropping in a real creature replaces
## `_build_mesh` and re-points `recoil`/`die` at an AnimationPlayer, and
## nothing else in the game changes.
##
## So the proportions are not an art decision. They are read off the enemy's
## hp so that a bone_rat and the mother_of_bones are visibly different
## creatures at a glance, which is the one thing the fight genuinely needs
## from the model before the model exists.

## Layer 4 in the project's layer names. Bodies you can put a crosshair on.
const LAYER_ENEMY := 8
const MIN_HEIGHT := 0.9
const MAX_HEIGHT := 2.9
## The hp a "full-size" humanoid has. Anything bigger keeps growing, slowly.
const REFERENCE_HP := 34.0
const RECOIL_DEPTH := 0.28
const RECOIL_SECONDS := 0.22
const HIGHLIGHT_ENERGY := 1.4

var index: int = -1
var dying: bool = false

var _body: Node3D
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _height: float = 1.8
var _recoil: Tween


## Height in metres. Bound to hp rather than to a per-enemy art field, because
## hp is the number the game already balances and the one a player already
## reads as "how big a problem is this".
static func stand_in_height(def: EnemyDef) -> float:
	var t := sqrt(maxf(1.0, float(def.hp)) / REFERENCE_HP)
	return clampf(1.8 * t, MIN_HEIGHT, MAX_HEIGHT)


static func create(def: EnemyDef, enemy_index: int) -> EnemyBody:
	var b := EnemyBody.new()
	b.name = "Enemy%d" % enemy_index
	b.index = enemy_index
	b._height = stand_in_height(def)
	b.collision_layer = LAYER_ENEMY
	b.collision_mask = 0

	# Everything visible hangs off _body so recoil and the death fall move the
	# creature without moving the collider's origin or the head anchor's frame.
	b._body = Node3D.new()
	b._body.name = "Body"
	b.add_child(b._body)
	b._build_mesh(def)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = b._height * 0.22
	capsule.height = b._height
	shape.shape = capsule
	shape.position = Vector3(0.0, b._height * 0.5, 0.0)
	b.add_child(shape)
	return b


func _build_mesh(def: EnemyDef) -> void:
	_material = StandardMaterial3D.new()
	# Bone against wet stone. Cold, slightly emissive so a creature at the edge
	# of the torchlight is a shape rather than nothing at all -- the dark is
	# meant to be threatening, not empty.
	# Old bone, not white plastic. The first version was 0.62 grey with a cool
	# emission on top, and under the new fill light it read as a shop mannequin
	# -- brighter than the stone around it, which nothing in a crypt should be.
	_material.albedo_color = Color(0.42, 0.39, 0.33)
	_material.roughness = 0.94
	_material.emission_enabled = true
	_material.emission = Color(0.36, 0.40, 0.46)
	_material.emission_energy_multiplier = 0.05

	var capsule := CapsuleMesh.new()
	capsule.radius = _height * 0.20
	capsule.height = _height * 0.78
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = capsule
	_mesh.material_override = _material
	_mesh.position = Vector3(0.0, _height * 0.39, 0.0)
	_body.add_child(_mesh)

	var skull := SphereMesh.new()
	skull.radius = _height * 0.13
	skull.height = _height * 0.26
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = skull
	head.material_override = _material
	head.position = Vector3(0.0, _height * 0.86, 0.0)
	_body.add_child(head)
	# The tag is a name the def already has; nothing here invents copy.
	_body.set_meta("enemy_id", def.id)


## Where a damage number should appear: just above the head, in world space.
func head_point() -> Vector3:
	return global_position + Vector3(0.0, _height + 0.25, 0.0)


func mesh_material() -> StandardMaterial3D:
	return _material


## The visible offset of the creature from where it stands. Tests read this
## rather than the mesh's global transform, which a headless run does not
## flush.
func body_offset() -> Vector3:
	return _body.position


func recoil(amount: int) -> void:
	if dying:
		return
	if _recoil != null and _recoil.is_valid():
		_recoil.kill()
	var back := clampf(float(amount) / 20.0, 0.25, 1.0) * RECOIL_DEPTH
	_body.position = Vector3(0.0, 0.0, back)
	_recoil = create_tween()
	_recoil.tween_property(_body, "position", Vector3.ZERO, RECOIL_SECONDS) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Falls rather than vanishes. A body that pops out of existence takes the
## weight of the kill with it.
func die() -> void:
	if dying:
		return
	dying = true
	collision_layer = 0
	set_highlight(false)
	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(self, "rotation:x", -PI * 0.42, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_material, "albedo_color:a", 0.0, 0.7).set_delay(0.25)


func set_highlight(on: bool) -> void:
	if _material == null:
		return
	_material.emission_energy_multiplier = HIGHLIGHT_ENERGY if on else 0.05
