class_name Atmosphere
extends Control
## Everything behind the game: lit stone, drifting motes, and a depth tint
## that darkens as the hero descends. Sits under every screen, costs no art,
## and is the difference between "flat black panel" and "a place".
##
## The shader does the ground; CPUParticles2D do the motes. Both are cheap
## enough to leave running on the Ladder while the player is away.

const SHADER_PATH := "res://game/theme/crypt.gdshader"
const MOTE_COUNT := 34
const MOTE_LIFETIME := 14.0
## The lantern is a flame. Never below MIN -- a light that drops to nothing
## reads as a rendering fault rather than as a draught -- and never far above
## 1, because this multiplies every warm highlight in the room.
const FLICKER_MIN := 0.86
const FLICKER_MAX := 1.06

var depth: float = 0.0:
	set(value):
		depth = clampf(value, 0.0, 1.0)
		_apply_depth()

var _ground: ColorRect
var _motes: CPUParticles2D
var _material: ShaderMaterial
## Where this screen's content lives, in local pixels. Kept in pixels rather
## than normalised because screens declare it during _build(), before any
## container has sized them -- normalising once would focus every screen on
## the wrong place at the size it actually renders at.
var _focus: Rect2 = Rect2()
var _has_focus: bool = false
var _focus_strength: float = 0.0
var _flicker_time: float = 0.0


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
		# The light model lives in Palette; the shader's own defaults are only
		# a fallback so it is legible standalone. Pushing them here keeps one
		# source of truth for "what colour is stone".
		_material.set_shader_parameter("stone", Palette.STONE)
		_material.set_shader_parameter("deep", Palette.ABYSS)
		_material.set_shader_parameter("lantern", Palette.LANTERN)
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


## Declares where this screen's content lives. The ground falls away outside
## it, which is what gives a screen a subject -- the review that produced this
## overhaul found twelve screens where the background was as loud as the
## content and nothing said "look here".
##
## `strength` is how far outside the rect falls, 0 to 1. The default is short
## of 1 on purpose: the frame should recede, not vanish, or the arches and
## masonry that make the room a place go with it.
func focus_on(rect: Rect2, strength: float = 0.82) -> void:
	_focus = rect
	_has_focus = rect.size.x > 0.0 and rect.size.y > 0.0
	_focus_strength = clampf(strength, 0.0, 1.0)
	_apply_focus()


func clear_focus() -> void:
	_has_focus = false
	_focus_strength = 0.0
	_apply_focus()


## Re-normalises the stored pixel rect against the current size. Called again
## on every resize, so a focus declared before layout lands correctly once the
## container gets round to sizing the screen.
func _apply_focus() -> void:
	if _material == null:
		return
	if not _has_focus or size.x <= 0.0 or size.y <= 0.0:
		_material.set_shader_parameter("focus_strength", 0.0)
		return
	var centre := (_focus.position + _focus.size * 0.5) / size
	# The lit core has to clear the content, so it is sized off the longer
	# side of the rect with a margin -- a focus that crops the thing it is
	# pointing at is worse than no focus at all.
	var radius := maxf(_focus.size.x / size.x, _focus.size.y / size.y) * 0.5 * 1.15
	_material.set_shader_parameter("focus_centre", centre)
	_material.set_shader_parameter("focus_radius", radius)
	_material.set_shader_parameter("focus_strength", _focus_strength)


## Driven here rather than from TIME inside the shader so the range is a rule
## the tests can hold, and so it stays deterministic: no engine randomness,
## just three incommensurate sines, which never repeat on a period a player
## would notice and give the same frame the same value every time.
func _process(delta: float) -> void:
	_advance_flicker(delta)


func _advance_flicker(delta: float) -> void:
	_flicker_time += delta
	var t := _flicker_time
	var wave := sin(t * 2.7) * 0.5 + sin(t * 6.1 + 1.3) * 0.32 + sin(t * 11.9 + 2.7) * 0.18
	var mid := (FLICKER_MIN + FLICKER_MAX) * 0.5
	var half := (FLICKER_MAX - FLICKER_MIN) * 0.5
	var value := clampf(mid + wave * half, FLICKER_MIN, FLICKER_MAX)
	if _material != null:
		_material.set_shader_parameter("flicker", value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_motes()
		_apply_focus()


func _fit_motes() -> void:
	if _motes == null or size.x <= 0.0:
		return
	_apply_depth()
	_motes.emission_rect_extents = size * 0.5
	_motes.position = size * 0.5


## 0 on the surface, 1 at the bottom of the biome. Tints the ground darker
## and warmer as the hero goes down, so depth is felt, not just numbered.
func set_floor(floor: int, last_floor: int) -> void:
	depth = 0.0 if last_floor <= 1 else float(floor - 1) / float(last_floor - 1)


## Sets the biome's colour on the crypt. There is no backdrop image any
## more: an AI-generated still at low alpha read as a rendering glitch on
## the warmed palette, and the shader draws the room itself now.
func set_biome(biome_id: String) -> void:
	set_accent(Palette.biome_accent(biome_id))
	_apply_depth()


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
		_material.set_shader_parameter("aspect", (size.x / size.y) if size.y > 0.0 else 1.777)
	if _motes != null:
		# Deeper floors are stiller: fewer motes, slower.
		_motes.amount = maxi(8, int(round(float(MOTE_COUNT) * (1.0 - depth * 0.55))))

