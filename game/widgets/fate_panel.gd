class_name FatePanel
extends PanelContainer
## What the fight is actually for.
##
## Ghost Guild's premise is that dying is a decision -- where you fall is
## where your ghost farms, forever. But during a fight, which is where the
## player spends most of their time, none of that was on screen: it was a
## card game with the game's whole identity hidden behind a menu.
##
## So this sits beside the hero and shows the thing at stake right now: the
## ghost you would leave if this floor killed you, and what that floor would
## pay. It updates as the fight goes, because the answer changes with the
## deck you are drawing and the health you have left.

const PANEL_SIZE := Vector2(98.0, 58.0)

var floor_number: int = 1
var yield_here: float = 0.0

var _mark: GhostMark
var _caption: Label
var _floor: Label
var _rate: Label
var _pulse: float = 0.0


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.VOID, Palette.STONE_EDGE))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	_caption = UiTheme.small("", Palette.BONE_FAINT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_caption)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# The ghost you would become, standing where it would stand.
	_mark = GhostMark.new()
	_mark.restless = true
	_mark.custom_minimum_size = GhostMark.BASE_SIZE
	row.add_child(_mark)
	_floor = UiTheme.body("", Palette.GHOST)
	_floor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_floor)
	box.add_child(row)

	_rate = UiTheme.number("", Palette.SOUL)
	_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_rate)

	var foot := UiTheme.small("", Palette.BONE_FAINT)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(foot)
	_foot = foot


var _foot: Label


## `rate` is what a ghost left on this floor would earn per hour. Passed in
## rather than computed here: it costs a simulation, and a widget should not
## be running one.
func bind(content: Content, floor: int, rate: float) -> void:
	floor_number = floor
	yield_here = rate
	_caption.text = content.text("ui.fight.becoming")
	_floor.text = content.text("ui.run.floor").replace("{floor}", str(floor))
	_rate.text = Num.rate(rate)
	_foot.text = content.text("ui.fight.yield_here")


## A soft swell whenever the number changes, so the player notices that
## what their death is worth just moved.
func acknowledge() -> void:
	if not is_inside_tree():
		return
	_pulse = 1.0
	var tween := create_tween()
	tween.tween_method(_set_pulse, 1.0, 0.0, 0.9).set_trans(Tween.TRANS_QUAD)


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _draw() -> void:
	if _pulse <= 0.0 or size.x <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size),
		Color(Palette.GHOST.r, Palette.GHOST.g, Palette.GHOST.b, 0.10 * _pulse))
