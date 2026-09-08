class_name GhostFigure
extends Node3D
## A fallen hero in a pleated burial shroud, with a hollow hood and eyes lit
## from within. The body floats independently of the rise animation so the
## two motions never compete for the same transform.

const HEIGHT := 1.72
const BOB := 0.06
const BOB_SECONDS := 3.4
const GLOW := Color(0.55, 0.78, 0.95)

var ghost_id: int = 0
var ghost_floor: int = 1
var state: String = "true"
var _material: StandardMaterial3D
var _details: Array[StandardMaterial3D] = []
var _alphas: Array[float] = []
var _meshes: Array[MeshInstance3D] = []
var _rests: Array[Vector3] = []
var _lamp: OmniLight3D
var _clock: float = 0.0
var _rise: Tween
static var _shroud: ArrayMesh
static var _hood: ArrayMesh


static func create(ghost: Ghost, at: Vector3) -> GhostFigure:
	var f := GhostFigure.new()
	f.name = "Ghost%d" % ghost.id
	f.ghost_id = ghost.id
	f.ghost_floor = ghost.floor
	f.position = at
	f.state = "restless" if ghost.restless else ("prepared" if ghost.prepared else ghost.kind)
	f._build()
	return f


static func colour_for(kind: String) -> Color:
	match kind:
		"prepared": return Color("dfc890")
		"restless": return Color("dba1ab")
		"echo": return Color("9eaee2")
		_: return GLOW


func _build() -> void:
	var tint := colour_for(state)
	_material = _spirit_material(tint, 0.38, 0.18)
	_material.roughness = 0.85
	_material.rim_enabled = true
	_material.rim = 0.25
	_material.rim_tint = 0.3
	if _shroud == null:
		_shroud = BoneMesh.loft([Vector2(0.28, 0.17), Vector2(0.34, 0.38),
			Vector2(0.28, 0.66), Vector2(0.23, 0.93), Vector2(0.32, 1.14),
			Vector2(0.22, 1.28), Vector2(0.13, 1.38)], 40, 0.11, 0.12)
		_hood = BoneMesh.loft([Vector2(0.22, 1.12), Vector2(0.255, 1.30),
			Vector2(0.235, 1.49), Vector2(0.145, 1.66), Vector2(0.005, HEIGHT)], 32, 0.025)
	_add_mesh("Mesh", _shroud, _material).scale.z = 0.72
	_add_mesh("Head", _hood, _material).scale.z = 0.86

	var shadow := _spirit_material(Color("102131"), 0.94, 0.02)
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.render_priority = 1
	_track(BoneMesh.ellipsoid(self, "HoodHollow", Vector3(0, 1.39, -0.194),
		Vector3(0.33, 0.40, 0.07), shadow))
	var eyes := _spirit_material(tint.lightened(0.45), 0.95, 0.70)
	eyes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eyes.render_priority = 2
	for side in [-1.0, 1.0]:
		_track(BoneMesh.ellipsoid(self, "Eye", Vector3(side * 0.067, 1.40, -0.235),
			Vector3(0.035, 0.063, 0.023), eyes))
		var sleeve := _add_mesh("Sleeve", BoneMesh.loft([Vector2(0.04, -0.34),
			Vector2(0.115, -0.15), Vector2(0.14, 0.08)], 20, 0.06, 0.055), _material)
		sleeve.position = Vector3(side * 0.285, 1.00, -0.02)
		sleeve.rotation.z = side * 0.30
		_rests[_rests.size() - 1] = sleeve.position
		_track(BoneMesh.ellipsoid(self, "Hand", Vector3(side * 0.39, 0.65, -0.02),
			Vector3(0.08, 0.14, 0.07), _material))
	var clasp := _spirit_material(tint.lightened(0.15), 0.70, 0.25)
	_track(BoneMesh.ellipsoid(self, "Clasp", Vector3(0, 1.06, -0.217), Vector3(0.075, 0.115, 0.025), clasp))
	_lamp = OmniLight3D.new()
	_lamp.name = "Glow"
	_lamp.light_color = tint
	_lamp.light_energy = 0.48
	_lamp.omni_range = 2.8
	_lamp.position = Vector3(0, HEIGHT * 0.6, 0)
	add_child(_lamp)


func _spirit_material(tint: Color, alpha: float, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(tint, alpha)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = emission
	mat.disable_receive_shadows = true
	_details.append(mat)
	_alphas.append(alpha)
	return mat


func _add_mesh(label: String, shape: Mesh, mat: StandardMaterial3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = shape
	part.material_override = mat
	add_child(part)
	_track(part)
	return part


func _track(part: MeshInstance3D) -> void:
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_meshes.append(part)
	_rests.append(part.position)


func material() -> StandardMaterial3D:
	return _material


func head_point() -> Vector3:
	return global_position + Vector3(0, HEIGHT + 0.2, 0)


func _process(delta: float) -> void:
	if Settings.motion_reduced:
		return
	_clock += delta
	var phase := _clock * TAU / BOB_SECONDS + CreaturePose.phase_for(ghost_id)
	var drift := sin(phase) * BOB
	for i in _meshes.size():
		_meshes[i].position = _rests[i] + Vector3(sin(phase * 0.47) * 0.018, drift, 0)


func _set_opacity(value: float) -> void:
	for i in _details.size():
		_details[i].albedo_color.a = _alphas[i] * value
	_lamp.light_energy = 0.48 * value


func rise(from_below: float = 1.4, seconds: float = 1.1) -> void:
	if Settings.motion_reduced:
		from_below = 0.0
		seconds = 0.15
	if _rise != null and _rise.is_valid():
		_rise.kill()
	var rest := position.y
	position.y = rest - from_below
	_set_opacity(0.0)
	_rise = create_tween().set_parallel(true)
	_rise.tween_property(self, "position:y", rest, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rise.tween_method(_set_opacity, 0.0, 1.0, seconds * 0.8)
