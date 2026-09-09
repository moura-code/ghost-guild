class_name TeachingMoment
extends PanelContainer
## A dismissible reminder, independent of campaign unlocks and input ownership.

signal dismissed(id: String)
signal details_requested()
var lesson: String = ""
var _text: Label
var _dismiss: Button


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
	var details := Button.new()
	details.text = "F1 · ?"
	details.pressed.connect(func() -> void: details_requested.emit())
	column.add_child(details)
	hide()


func present(content: Content, id: String) -> void:
	lesson = id
	_text.text = content.text("help.lesson." + id + ".short")
	_dismiss.text = "F2 · " + content.text("help.dismiss")
	show()
