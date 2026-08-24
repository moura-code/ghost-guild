class_name Atmosphere
extends Control
## Everything behind the game: lit stone, drifting motes, and a depth tint
## that darkens as the hero descends. Sits under every screen, costs no art,
## and is the difference between "flat black panel" and "a place".
##
## The shader does the ground; CPUParticles2D do the motes. Both are cheap
## enough to leave running on the Ladder while the player is away.

const SHADER_PATH := "res://game/theme/stone.gdshader"
const MOTE_COUNT := 34
const MOTE_LIFETIME := 14.0

var depth: float = 0.0:
	set(value):
		depth = clampf(value, 0.0, 1.0)
		_apply_depth()

var _ground: ColorRect
var _motes: CPUParticles2D
var _material: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	_ground = ColorRect.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = load(SHADER_PATH)
	if shader != null:
		_material = ShaderMaterial.new()
		_material.shader = shader
		_ground.material = _material
	else:
		# A missing shader must not take the game down with it.
		_ground.color = Palette.STONE
	add_child(_ground)

	_motes = _make_motes()
	add_child(_motes)
	_apply_depth()


## Slow dust rising through the light. Deliberately few and faint: this is
## atmosphere, not a snow effect.
func _make_motes() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = MOTE_COUNT
	p.lifetime = MOTE_LIFETIME
	p.preprocess = MOTE_LIFETIME
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.0, -1.0)
	p.spread = 22.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 13.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Palette.GHOST_DIM
	return p


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_motes()


func _fit_motes() -> void:
	if _motes == null or size.x <= 0.0:
		return
	_motes.emission_rect_extents = size * 0.5
	_motes.position = size * 0.5


## 0 on the surface, 1 at the bottom of the biome. Tints the ground darker
## and warmer as the hero goes down, so depth is felt, not just numbered.
func set_floor(floor: int, last_floor: int) -> void:
	depth = 0.0 if last_floor <= 1 else float(floor - 1) / float(last_floor - 1)


func set_accent(colour: Color) -> void:
	if _material != null:
		_material.set_shader_parameter("accent", colour)


## A one-shot swell of the underlight — used when something lands: a ghost
## placed, a floor cleared, a hero lost.
func pulse(strength: float = 1.0) -> void:
	if _material == null:
		return
	var tween := create_tween()
	tween.tween_method(_set_glow, clampf(strength, 0.0, 1.0), 0.0, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_glow(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("glow_pulse", value)


func _apply_depth() -> void:
	if _material != null:
		_material.set_shader_parameter("depth", depth)
	if _motes != null:
		# Deeper floors are stiller: fewer motes, slower.
		_motes.amount = maxi(8, int(round(float(MOTE_COUNT) * (1.0 - depth * 0.55))))
