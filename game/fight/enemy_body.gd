class_name EnemyBody
extends StaticBody3D
## The enemy, standing in the room you walked into.
##
## The mesh is no longer a stand-in. It was one for four stages -- a capsule
## with a ball on top, then five silhouettes of stacked primitives -- on the
## theory that a rigged creature was the one thing the no-artist pipeline could
## not produce. That turned out to be the wrong shape of problem. Every free
## rigged monster pack worth having is chibi, and dropping a big-headed cartoon
## skeleton into a room built from photoscanned sandstone would have cost more
## than the placeholder did.
##
## What the game actually needed was already true of its own fiction: these
## creatures are **made of parts**. `BoneMesh` builds the parts, `CreatureRig`
## hangs them off joints, and `CreaturePose` moves the joints. Nothing is
## skinned, and nothing here is waiting for an artist any more.
##
## This node owns the clock. The pose is a pure function of (archetype, time,
## phase, hurt, dead) and this is the thing that advances those four numbers.

## Layer 4 in the project's layer names. Bodies you can put a crosshair on.
const LAYER_ENEMY := 8
const MIN_HEIGHT := 0.9
const MAX_HEIGHT := 2.9
## The hp a "full-size" humanoid has. Anything bigger keeps growing, slowly.
const REFERENCE_HP := 34.0
const HIGHLIGHT_ENERGY := 1.4
## The damage that produces a full-strength flinch. Anything above it is the
## same flinch: a body cannot recoil harder than all the way.
const FULL_FLINCH_DAMAGE := 20.0

var index: int = -1
var dying: bool = false
## The silhouette archetype this creature got. See EnemyShape.
var shape: int = EnemyShape.Kind.HUMANOID

var _body: Node3D
var _rig: CreatureRig
var _material: StandardMaterial3D
var _height: float = 1.8
## Its own place in the idle cycle, so a room of three bone rats does not
## breathe as one animal.
var _phase: float = 0.0
var _clock: float = 0.0
## 1.0 at the moment of a blow, decaying to 0.
var _hurt: float = 0.0
## 0 until it dies, then 0 -> 1 as it goes down.
var _fallen: float = 0.0
var _detail_meshes: Array[MeshInstance3D] = []


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
	b._phase = CreaturePose.phase_for(enemy_index)
	b.collision_layer = LAYER_ENEMY
	b.collision_mask = 0

	# Everything visible hangs off _body so the hover offset and the rig's own
	# motion move the creature without moving the collider or the head anchor.
	b._body = Node3D.new()
	b._body.name = "Body"
	b.add_child(b._body)
	b._build_creature(def)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	if b.shape == EnemyShape.Kind.BEAST:
		var box := BoxShape3D.new()
		box.size = Vector3(b._height * 1.35, b._height * 0.70, b._height * 1.3)
		shape.shape = box
		shape.position.y = b._height * 0.35
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = b._height * 0.22
		capsule.height = b._height * (0.8 if b.shape == EnemyShape.Kind.WISP else 1.0)
		shape.shape = capsule
		shape.position.y = EnemyShape.hover(b.shape) + capsule.height * 0.5
	b.add_child(shape)
	return b


func _build_creature(def: EnemyDef) -> void:
	# What it is made of, read off its own tags. See EnemySkin -- this used to
	# be a flat untextured colour, which is a mannequin however good the
	# silhouette is, on a creature standing against a wall that has a normal
	# map and ambient occlusion.
	_material = EnemySkin.material_for(def)
	shape = EnemyShape.kind_for(def)
	_body.position.y = EnemyShape.hover(shape)
	_rig = CreatureRig.build(_body, shape, _height, _material,
		CreatureRig.eye_colour(def.tags), def.id)
	for node in _body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.material_override != _material:
			_detail_meshes.append(mesh)
	# The tag is a name the def already has; nothing here invents copy.
	_body.set_meta("enemy_id", def.id)
	# Stand it in its rest pose immediately: a body that only takes a shape on
	# the first _process frame pops on the frame it is spawned.
	_rig.apply(CreaturePose.pose(shape, 0.0, _phase))


## Breathing, swaying, drifting, flinching, falling -- all of it one pose
## evaluated per frame. A creature standing perfectly still is a prop, and the
## whole point of putting it in the room with you is that it is not one.
func _process(delta: float) -> void:
	if _rig == null:
		return
	_clock += delta
	if dying:
		var was := _fallen
		_fallen = minf(1.0, _fallen + delta / CreaturePose.DEATH_SECONDS)
		if _fallen != was:
			# The lights go out as it goes down. A corpse with burning eyes is
			# a thing that is still looking at you.
			_rig.set_light(1.0 - _fallen)
	elif _hurt > 0.0:
		_hurt = maxf(0.0, _hurt - delta / CreaturePose.HIT_SECONDS)
	_rig.apply(CreaturePose.pose(shape, _clock, _phase, _hurt, _fallen))


## Where a damage number should appear: just above the head, in world space.
func head_point() -> Vector3:
	var top := _height * (0.70 if shape == EnemyShape.Kind.BEAST else 1.0)
	if shape == EnemyShape.Kind.WISP:
		top = EnemyShape.hover(shape) + _height * 0.82
	return global_position + Vector3(0.0, top + 0.22, 0.0)


func mesh_material() -> StandardMaterial3D:
	return _material


## Where the creature rests relative to where it stands. Only a wisp is off
## the floor. Tests read this rather than a mesh's global transform, which a
## headless run does not flush.
func body_offset() -> Vector3:
	return _body.position


## How far the pose currently has the creature from its rest position. The
## animated half of the same question, and the one a test uses to prove the
## thing is moving at all.
func pose_offset() -> Vector3:
	var root := _rig.joint_node(CreaturePose.ROOT) if _rig != null else null
	return root.position if root != null else Vector3.ZERO


## How far through its flinch it is, 1.0 at the blow. Exposed because it is the
## state the animation is made of, and a test that can only look at a rendered
## transform cannot see it.
func hurt_level() -> float:
	return _hurt


## How far through falling over it is, 0 until it dies.
func fallen_level() -> float:
	return _fallen


func recoil(amount: int) -> void:
	if dying:
		return
	# The whole flinch is one number now. It used to be two tweens racing each
	# other for the same node position -- the idle loop and the recoil -- and
	# the idle had to be killed and restarted around every blow.
	_hurt = clampf(float(amount) / FULL_FLINCH_DAMAGE, 0.25, 1.0)


## Falls apart rather than vanishes. A body that pops out of existence takes
## the weight of the kill with it.
func die() -> void:
	if dying:
		return
	dying = true
	collision_layer = 0
	set_highlight(false)
	# The pose takes it down; this only takes it away, and later, so the fall
	# is watched rather than faded through.
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(_material, "albedo_color:a", 0.0, 0.55) \
		.set_delay(CreaturePose.DEATH_SECONDS * 0.55)
	fade.tween_method(_fade_details, 0.0, 1.0, 0.55) \
		.set_delay(CreaturePose.DEATH_SECONDS * 0.55)


func _fade_details(value: float) -> void:
	for mesh in _detail_meshes:
		mesh.transparency = value


func set_highlight(on: bool) -> void:
	if _material == null:
		return
	_material.emission_energy_multiplier = HIGHLIGHT_ENERGY if on else EnemySkin.REST_EMISSION
