class_name Crosshair
extends Control
## A dot in the middle of the screen that opens into a ring when something you
## can act on is under it.
##
## A first-person game where you click enemies to choose a target, and there
## was nothing telling you where the click would land. The dot is also the
## cheapest way to say "you are a body looking at a place" rather than "you
## are a camera".

const DOT := 1.6
const RING := 7.0
const OPEN_SECONDS := 0.09

## 0 = resting dot, 1 = fully open ring.
var openness: float = 0.0:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		queue_redraw()

var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Called every frame by whoever knows what is under the reticle. Tweened
## rather than snapped: a crosshair that pops between two states reads as a
## flicker, and this one is 2 px across.
func set_target(on: bool) -> void:
	var to := 1.0 if on else 0.0
	if is_equal_approx(openness, to):
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		openness = to
		return
	_tween = create_tween()
	_tween.tween_property(self, "openness", to, OPEN_SECONDS)


func _draw() -> void:
	var centre := size * 0.5
	var radius := lerpf(DOT, RING, openness)
	var alpha := lerpf(0.45, 0.95, openness)
	var tint := Palette.BONE
	tint.a = alpha
	if openness < 0.02:
		draw_circle(centre, DOT, tint)
		return
	draw_arc(centre, radius, 0.0, TAU, 24, tint, 1.3, true)
	var dot := Palette.BONE
	dot.a = alpha * 0.7
	draw_circle(centre, DOT * 0.8, dot)
