class_name GhostMark
extends Control
## One ghost silhouette standing in the tower (spec §9): translucent cyan,
## drawn rather than an asset, with a slow float so the ladder is never quite
## still. Colour says what kind of ghost it is. A widget: it takes a Ghost
## through bind() and never touches Game.

const BASE_SIZE := Vector2(24.0, 32.0)
const WAVE_BUMPS := 3
const FLOAT_PIXELS := 1.6
const FLOAT_SECONDS := 3.2

var kind: String = "true"
var prepared: bool = false
var restless: bool = false
var floating: bool = true

var _phase: float = 0.0
var _bob: float = 0.0


func _init() -> void:
	custom_minimum_size = BASE_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS


func bind(ghost: Ghost) -> void:
	kind = ghost.kind
	prepared = ghost.prepared
	restless = ghost.restless
	# Deterministic per ghost so a floor's ghosts do not bob in lockstep.
	_phase = float(ghost.id) * 0.9
	queue_redraw()


## Restless reads before prepared: a ghost that needs tending is the thing
## the player has to notice.
func body_color() -> Color:
	if restless:
		return Palette.RESTLESS
	if prepared:
		return Palette.PREPARED
	if kind == "echo":
		return Palette.ECHO
	return Palette.GHOST


func _process(delta: float) -> void:
	if not floating:
		return
	_phase += delta
	var next := sin(_phase * TAU / FLOAT_SECONDS) * FLOAT_PIXELS
	if not is_equal_approx(next, _bob):
		_bob = next
		queue_redraw()


func _draw() -> void:
	# The shadow it stands in, drawn first so the body sits on top of it.
	if size.x > 0.0 and size.y > 0.0:
		draw_circle(Vector2(size.x * 0.5, size.y - 2.0), size.x * 0.42,
			Color(0.0, 0.0, 0.0, 0.35))
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var top := _bob
	var dome_r := w * 0.5
	var wave_h := h * 0.14
	var points := PackedVector2Array()

	# Dome: left edge, over the top, to the right edge.
	var steps := 10
	for i in range(steps + 1):
		var a := PI + PI * float(i) / float(steps)
		points.append(Vector2(dome_r + cos(a) * dome_r, top + dome_r + sin(a) * dome_r))

	# Right side down to the hem.
	var hem := top + h - wave_h
	points.append(Vector2(w, hem))

	# Wavy hem, right to left.
	var wave_steps := 18
	for j in range(wave_steps + 1):
		var t := 1.0 - float(j) / float(wave_steps)
		var y := hem + wave_h * 0.5 + wave_h * 0.5 * sin(t * TAU * float(WAVE_BUMPS) - PI * 0.5)
		points.append(Vector2(w * t, y))

	points.append(Vector2(0.0, top + dome_r))
	draw_colored_polygon(points, body_color())

	# Two hollow eyes, punched in the stone behind.
	var eye_y := top + dome_r * 1.0
	var eye_r := maxf(1.0, w * 0.09)
	draw_circle(Vector2(w * 0.34, eye_y), eye_r, Palette.STONE)
	draw_circle(Vector2(w * 0.66, eye_y), eye_r, Palette.STONE)
