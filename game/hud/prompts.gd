class_name Prompts
extends Control
## The two lines of text the world needs: which floor you just arrived on, and
## what the thing you are looking at would do if you pressed E.
##
## Both are 2D over the 3D room rather than in it. A label floating in the
## world at the mouth of a corridor is a label you read at an angle, in fog,
## at whatever size the perspective gives it.

const BANNER_SECONDS := 1.9
const BANNER_FADE := 0.5

var banner: Label
var prompt: Label

var _banner_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	banner = Label.new()
	banner.name = "Banner"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.anchor_right = 1.0
	banner.offset_top = 48.0
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.anchor_right = 1.0
	prompt.offset_top = -96.0
	prompt.offset_bottom = -80.0
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)


## Rises, holds, fades. Announced on arrival rather than pinned to a corner:
## which floor you are on matters for a moment and then stops mattering.
func announce(text_value: String) -> void:
	banner.text = text_value
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner.modulate.a = 1.0
	if not is_inside_tree():
		return
	_banner_tween = create_tween()
	_banner_tween.tween_interval(BANNER_SECONDS)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, BANNER_FADE)


func show_prompt(text_value: String) -> void:
	prompt.text = text_value


func clear_prompt() -> void:
	prompt.text = ""


func has_prompt() -> bool:
	return prompt.text != ""


func is_announcing() -> bool:
	return banner.modulate.a > 0.0
