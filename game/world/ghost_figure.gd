class_name GhostFigure
extends Node3D
## A dead hero, standing where it died, still working.
##
## This is the pivot's first pillar made literal (spec §2.1): a ghost stops
## being a row in a ladder and becomes a figure in the corridor you walk past
## on your way deeper. It is the single highest-value image the pivot buys,
## which is why it exists before the model that will eventually fill it.
##
## Like EnemyBody, the mesh is a stand-in isolated behind one function. Unlike
## EnemyBody it is not solid: you walk through your dead. Bumping into them
## would make them furniture.

const HEIGHT := 1.72
const BOB := 0.06
const BOB_SECONDS := 3.4
const GLOW := Color(0.55, 0.78, 0.95)

var ghost_id: int = 0
var ghost_floor: int = 1

var _material: StandardMaterial3D
var _bob: Tween


static func create(ghost: Ghost, at: Vector3) -> GhostFigure:
	var f := GhostFigure.new()
	f.name = "Ghost%d" % ghost.id
	f.ghost_id = ghost.id
	f.ghost_floor = ghost.floor
	f.position = at
	f._build()
	return f


func _build() -> void:
	_material = StandardMaterial3D.new()
	# Lit from inside and see-through: a ghost has to read as present without
	# reading as solid, and the torch must pass through it rather than land on
	# it like it lands on stone.
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(GLOW.r, GLOW.g, GLOW.b, 0.34)
	_material.emission_enabled = true
	_material.emission = GLOW
	# 0.9 blew out to pure white once the grade got real headroom -- a ghost
	# should be the brightest thing in a dark corridor, not a light bulb.
	_material.emission_energy_multiplier = 0.35
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := CapsuleMesh.new()
	body.radius = HEIGHT * 0.17
	body.height = HEIGHT * 0.74
	var torso := MeshInstance3D.new()
	torso.name = "Mesh"
	torso.mesh = body
	torso.material_override = _material
	torso.position = Vector3(0.0, HEIGHT * 0.37, 0.0)
	# A ghost casts no shadow. It is the cheapest possible way to say "this is
	# not a thing that is here".
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(torso)

	var skull := SphereMesh.new()
	skull.radius = HEIGHT * 0.12
	skull.height = HEIGHT * 0.24
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = skull
	head.material_override = _material
	head.position = Vector3(0.0, HEIGHT * 0.84, 0.0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(head)

	var lamp := OmniLight3D.new()
	lamp.name = "Glow"
	lamp.light_color = GLOW
	lamp.light_energy = 0.55
	lamp.omni_range = 3.0
	lamp.position = Vector3(0.0, HEIGHT * 0.6, 0.0)
	add_child(lamp)


func material() -> StandardMaterial3D:
	return _material


func head_point() -> Vector3:
	return global_position + Vector3(0.0, HEIGHT + 0.2, 0.0)


## Drifts. A ghost standing perfectly still is a statue, and the difference
## between the two is about four lines of tween.
func _ready() -> void:
	var rest := position.y
	_bob = create_tween().set_loops()
	_bob.tween_property(self, "position:y", rest + BOB, BOB_SECONDS * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(self, "position:y", rest, BOB_SECONDS * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Rises out of the floor where the hero fell. The death beat (spec §9 stage 6)
## is this, then the epitaph over it.
func rise(from_below: float = 1.4, seconds: float = 1.1) -> void:
	var rest := position.y
	position.y = rest - from_below
	_material.albedo_color.a = 0.0
	var up := create_tween()
	up.set_parallel(true)
	up.tween_property(self, "position:y", rest, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	up.tween_property(_material, "albedo_color:a", 0.34, seconds * 0.8)
