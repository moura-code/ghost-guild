class_name Transition
extends ColorRect
## A wipe between screens, so the game never hard-cuts. Goes opaque, tells
## the caller to swap at the midpoint, then clears.
##
## A ColorRect over everything is deliberately the dumbest thing that works:
## it survives being inside a container, needs no viewport texture, and
## costs one quad. The swap happens while the screen is covered, so no
## amount of relayout jank is ever visible.

signal midpoint()

const DEFAULT_SECONDS := 0.26

var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Palette.STONE
	modulate.a = 0.0
	visible = false


## Covers the screen, emits `midpoint` for the caller to swap behind it,
## then uncovers. Calling it again mid-wipe restarts cleanly rather than
## leaving the screen stuck under a half-faded sheet.
func play(seconds: float = DEFAULT_SECONDS) -> void:
	if not is_inside_tree():
		midpoint.emit()
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, seconds * 0.5).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: midpoint.emit())
	_tween.tween_property(self, "modulate:a", 0.0, seconds * 0.5).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: visible = false)


## True while the screen is covered or covering.
func is_playing() -> bool:
	return _tween != null and _tween.is_valid()
