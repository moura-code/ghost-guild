class_name PauseMenu
extends PanelContainer
## The menu Escape opens when nothing else is open: resume, options, quit.
##
## There was no way out of this game except Alt+F4, and no way to change a
## setting at all. That is not a build you can hand to anybody.

signal resumed()
signal options_requested()
signal quit_requested()

## Ids so a test can name a button without matching on its label, which is a
## translated string and will change.
const RESUME := "resume"
const OPTIONS := "options"
const QUIT := "quit"

var buttons: Dictionary = {}
var _in_run: bool = false

var _column: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(210.0, 0.0)
	add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED))

	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, 16)
	add_child(margins)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	margins.add_child(_column)


## `in_run` is taken and currently unused, and that is deliberate. Abandoning a
## run mid-floor is NOT something core/ supports: the only way out of a run is
## the exit decision (push / retreat / watch) at phase "exit". Adding an
## "abandon" action is an economy question -- does the hero die, is the Soul
## banked, does it count as a death for the ladder -- and an economy question
## is a design decision, not something a pause menu invents on its own.
##
## Quitting saves mid-run and resumes where you left off, so nothing is
## trapped. The parameter stays so the menu can grow the item the day that
## decision is made.
func build(content: Content, in_run: bool) -> void:
	_in_run = in_run
	for child in _column.get_children():
		child.queue_free()
	buttons.clear()

	var title := UiTheme.title(content.text("ui.menu.paused"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_column.add_child(HSeparator.new())

	_add(content, RESUME, "ui.menu.resume", resumed)
	_add(content, OPTIONS, "ui.menu.options", options_requested)
	_add(content, QUIT, "ui.menu.quit", quit_requested)


func press(id: String) -> void:
	var button: Button = buttons.get(id, null)
	if button != null:
		button.emit_signal("pressed")


func _add(content: Content, id: String, key: String, out: Signal) -> void:
	var button := Button.new()
	button.text = content.text(key)
	button.custom_minimum_size = Vector2(0.0, 22.0)
	button.pressed.connect(func() -> void: out.emit())
	_column.add_child(button)
	buttons[id] = button
