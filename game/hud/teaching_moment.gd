class_name TeachingMoment
extends PanelContainer
## A dismissible reminder, independent of campaign unlocks and input ownership.

signal dismissed(id: String)
signal details_requested()
var lesson: String = ""
var _text: Label
var _dismiss: Button
var _details: Button


func _init() -> void:
	custom_minimum_size.x = 180
	size.x = 180
	add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.VOID))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	add_child(column)
	_text = UiTheme.body("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_text)
	_dismiss = Button.new()
	_dismiss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dismiss.pressed.connect(func() -> void: dismissed.emit(lesson))
	column.add_child(_dismiss)
	_details = Button.new()
	_details.text = "F1 · ?"
	_details.pressed.connect(func() -> void: details_requested.emit())
	column.add_child(_details)
	hide()


func present(content: Content, id: String, compact: bool = false) -> void:
	lesson = id
	custom_minimum_size.x = 72 if compact else 180
	size.x = custom_minimum_size.x
	_text.text = content.text("help.lesson.combat.compact" if compact else "help.lesson." + id + ".short")
	_dismiss.text = "F2 · ×" if compact else "F2 · " + content.text("help.dismiss")
	_dismiss.tooltip_text = content.text("help.dismiss")
	show()
