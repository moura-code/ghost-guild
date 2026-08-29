class_name TitleMenu
extends PanelContainer
## The first thing the game shows. Continue, new guild, options, quit.
##
## The game used to drop you straight into whatever the save file said, with
## no title, no way to start over, and no moment before it began. A roguelite
## whose whole subject is a lineage of dead heroes should say its name before
## it hands you one.

signal continued()
signal started_new()
signal options_requested()
signal quit_requested()

const CONTINUE := "continue"
const NEW := "new"
const OPTIONS := "options"
const QUIT := "quit"

var buttons: Dictionary = {}

var _column: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(230.0, 0.0)
	add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED))

	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, 18)
	add_child(margins)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	margins.add_child(_column)


## `has_save` decides whether Continue is offered. Offering it on a fresh
## install and having it do the same thing as New is how a menu teaches the
## player that its buttons are decorative.
func build(content: Content, has_save: bool) -> void:
	for child in _column.get_children():
		child.queue_free()
	buttons.clear()

	var title := UiTheme.title(content.text("ui.menu.title"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_column.add_child(HSeparator.new())

	if has_save:
		_add(content, CONTINUE, "ui.menu.continue", continued)
	_add(content, NEW, "ui.menu.new", started_new)
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
