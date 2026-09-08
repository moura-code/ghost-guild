class_name CampaignMenu
extends VBoxContainer
## Import writes a new slot; continuing is a separate, explicit selection.

signal selected(path: String)
signal import_requested(path: String)
signal closed()
var message: Label
var picker: FileDialog
var _list: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 8)
	message = UiTheme.body("")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.json, *.bak1, *.bak2 ; Campaign saves"])
	picker.file_selected.connect(func(path: String) -> void: import_requested.emit(path))
	add_child(picker)


func build(content: Content, slots: Array[Dictionary], current: String) -> void:
	for child in _list.get_children():
		child.free()
	_list.add_child(UiTheme.title(content.text("ui.saves.title")))
	var explanation := UiTheme.body(content.text("ui.saves.explain"))
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(explanation)
	for slot in slots:
		var button := Button.new()
		button.text = "%s · %s · %s" % [slot["slot"], slot["name"], str(slot["seed"])]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = slot["reason"] != ""
		if slot.get("recovered", "") != "":
			button.tooltip_text = content.text("ui.saves.recovered")
		if button.disabled:
			button.tooltip_text = content.text("ui.saves." + String(slot["reason"]))
		if slot["path"] == current:
			button.text += " · " + content.text("ui.saves.current")
		button.pressed.connect(func() -> void: selected.emit(String(slot["path"])))
		_list.add_child(button)
	var import_button := Button.new()
	import_button.text = content.text("ui.saves.import")
	import_button.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	_list.add_child(import_button)
	var back := Button.new()
	back.text = content.text("ui.close")
	back.pressed.connect(func() -> void: closed.emit())
	_list.add_child(back)
