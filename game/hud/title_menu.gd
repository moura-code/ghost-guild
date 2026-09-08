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
signal campaigns_requested()
signal quit_requested()

const CONTINUE := "continue"
const NEW := "new"
const OPTIONS := "options"
const QUIT := "quit"

var buttons: Dictionary = {}

var _column: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	# `Crawl._host` stretches a hosted panel to the full frame unless it
	# says it has already placed itself. This is a card, not a screen.
	set_meta("keeps_own_rect", true)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(290.0, 0.0)
	add_theme_stylebox_override("panel", UiTheme.panel_box(Color(0.035, 0.047, 0.07, 0.94)))

	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, 20)
	add_child(margins)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 7)
	margins.add_child(_column)


## `has_save` decides whether Continue is offered. Offering it on a fresh
## install and having it do the same thing as New is how a menu teaches the
## player that its buttons are decorative.
func build(content: Content, has_save: bool) -> void:
	for child in _column.get_children():
		child.free()
	buttons.clear()

	var emblem := Icons.make_rect(Icons.ui("ghost"), 32.0, Palette.SOUL)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(emblem)
	_column.add_child(ScreenLayout.centre(UiTheme.small(content.text("ui.menu.kicker"), Palette.EDGE_LIGHT)))
	var title := UiTheme.title(content.text("ui.menu.title"))
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var premise := ScreenLayout.centre(UiTheme.body(content.text("ui.menu.premise"), Palette.BONE_DIM))
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(premise)
	var space := Control.new()
	space.custom_minimum_size.y = 5
	_column.add_child(space)

	if has_save:
		_add(content, CONTINUE, "ui.menu.continue", continued)
	_add(content, NEW, "ui.menu.new", started_new)
	_add(content, OPTIONS, "ui.menu.options", options_requested)
	_add(content, "campaigns", "ui.saves.title", campaigns_requested)
	_add(content, QUIT, "ui.menu.quit", quit_requested)
	var primary: Button = buttons[CONTINUE if has_save else NEW]
	primary.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.EDGE_LIGHT))


func press(id: String) -> void:
	var button: Button = buttons.get(id, null)
	if button != null:
		button.emit_signal("pressed")


func _add(content: Content, id: String, key: String, out: Signal) -> void:
	var button := Button.new()
	button.text = content.text(key)
	button.custom_minimum_size = Vector2(0.0, 26.0)
	button.pressed.connect(func() -> void: out.emit())
	_column.add_child(button)
	buttons[id] = button
