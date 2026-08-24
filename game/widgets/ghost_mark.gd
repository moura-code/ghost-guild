class_name GhostMark
extends Control
## One ghost silhouette standing in the tower (spec §9): translucent cyan,
## drawn rather than an asset, with a slow float so the ladder is never quite
## still. Colour says what kind of ghost it is. A widget: it takes a Ghost
## through bind() and never touches Game.

const BASE_SIZE := Vector2(24.0, 32.0)
const WAVE_BUMPS := 3
const FLOAT_PIXELS := 3.4
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
##
## Restless used to be its own salmon orange, which on the epitaph -- a
## near-black screen about someone dying -- made the game's mascot the one
## saturated warm object in the frame, and it read as an arcade sprite. It
## warns in the colour the rest of the game warns in.
func body_color() -> Color:
	if restless:
		return Palette.DANGER
	if prepared:
		return Palette.PREPARED
	if kind == "echo":
		return Palette.ECHO
	return Palette.GHOST


func _process(delta: float) -> void:
	if not floating:
		return
	_phase += delta
	# The restless shudder rather than drift: on an idle screen the ghost
	# that wants tending should catch the eye through movement, not only
	# through being a different colour.
	var period := FLOAT_SECONDS * (0.28 if restless else 1.0)
	var swing := FLOAT_PIXELS * (1.5 if restless else 1.0)
	var next := sin(_phase * TAU / period) * swing
	if not is_equal_approx(next, _bob):
		_bob = next
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	# The shadow it stands in, drawn first so the body sits on top of it.
	draw_circle(Vector2(w * 0.5, h - 2.0), w * 0.42, Color(0.0, 0.0, 0.0, 0.35))

	var body := body_color()
	var top := _bob
	# Narrower than the box it is laid out in: a dome as wide as it is tall
	# reads as an arcade sprite, and this is meant to be a person.
	var inset := w * 0.07
	var left := inset
	var right := w - inset
	var span := right - left
	var dome_r := span * 0.5
	var wave_h := h * 0.15
	var points := PackedVector2Array()

	# Dome: left edge, over the top, to the right edge.
	var steps := 12
	for i in range(steps + 1):
		var a := PI + PI * float(i) / float(steps)
		points.append(Vector2(left + dome_r + cos(a) * dome_r, top + dome_r + sin(a) * dome_r))

	# Right side down to the hem.
	var hem := top + h - wave_h
	points.append(Vector2(right, hem))

	# Wavy hem, right to left.
	var wave_steps := 18
	for j in range(wave_steps + 1):
		var t := 1.0 - float(j) / float(wave_steps)
		var y := hem + wave_h * 0.5 + wave_h * 0.5 * sin(t * TAU * float(WAVE_BUMPS) - PI * 0.5)
		points.append(Vector2(left + span * t, y))

	points.append(Vector2(left, top + dome_r))

	# The light it gives off, so it sits in the room rather than on it.
	for i in 4:
		var g := 1.0 - float(i) / 4.0
		draw_circle(Vector2(w * 0.5, top + h * 0.42), dome_r * (1.0 + g * 1.1),
			Color(body.r, body.g, body.b, 0.05 * (1.0 - g)))

	# Solid at the crown, dissolving at the hem. draw_polygon takes a colour
	# per vertex, which is the only gradient available without a texture --
	# and a ghost that is a flat opaque slab is just a shape.
	var colours := PackedColorArray()
	for pt in points:
		var t := clampf((pt.y - top) / maxf(1.0, h), 0.0, 1.0)
		colours.append(Color(minf(body.r * (1.0 + (1.0 - t) * 0.25), 1.0),
			minf(body.g * (1.0 + (1.0 - t) * 0.25), 1.0),
			minf(body.b * (1.0 + (1.0 - t) * 0.25), 1.0),
			body.a * (0.98 - t * 0.62)))
	draw_polygon(points, colours)

	# Two hollow eyes. Dark, not filled with the wall colour: painted-on dots
	# follow whatever is behind the ghost and stop reading as sockets.
	var eye_y := top + dome_r * 1.05
	var eye_r := maxf(1.0, span * 0.10)
	draw_circle(Vector2(left + span * 0.33, eye_y), eye_r, Color(0.02, 0.02, 0.05, 0.85))
	draw_circle(Vector2(left + span * 0.67, eye_y), eye_r, Color(0.02, 0.02, 0.05, 0.85))
	# A catchlight, so the eyes are looking rather than empty.
	var spark := maxf(0.5, eye_r * 0.34)
	draw_circle(Vector2(left + span * 0.33 + eye_r * 0.3, eye_y - eye_r * 0.3), spark,
		Color(body.r, body.g, body.b, 0.7))
	draw_circle(Vector2(left + span * 0.67 + eye_r * 0.3, eye_y - eye_r * 0.3), spark,
		Color(body.r, body.g, body.b, 0.7))
