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
## What the floor still wants from you. Sits under the compass, because a
## compass with marks on it and no words is an instrument nobody reads.
var objective: Label

var _banner_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	banner = Label.new()
	banner.name = "Banner"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Anchored across the full width, not to a centre point: with
	# PRESET_CENTER_TOP the label's own left edge is what gets centred, so a
	# centre-aligned string inside it lands right of the middle.
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 54.0
	banner.offset_bottom = 72.0
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	prompt = Label.new()
	prompt.name = "Prompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -118.0
	prompt.offset_bottom = -100.0
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)

	objective = Label.new()
	objective.name = "Objective"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	objective.offset_top = Compass.TOP + Compass.HEIGHT + 1.0
	objective.offset_bottom = Compass.TOP + Compass.HEIGHT + 17.0
	objective.modulate = Palette.BONE_DIM
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objective)


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


## Takes the banner down immediately. A floor announcement that is still
## fading when a panel opens ends up printed across it.
func hush() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner.modulate.a = 0.0


func show_objective(text_value: String) -> void:
	objective.text = text_value


func clear_objective() -> void:
	objective.text = ""


func has_objective() -> bool:
	return objective.text != ""
