class_name HelpPanel
extends VBoxContainer

signal closed()


static func binding(action: String) -> String:
	var labels := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			labels.append(OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode))
		elif event is InputEventMouseButton:
			labels.append(event.as_text())
	return " / ".join(labels)


func build(content: Content, guild: bool, exploring: bool) -> void:
	for child in get_children():
		child.free()
	add_theme_constant_override("separation", 8)
	add_child(ScreenLayout.centre(UiTheme.title(content.text("ui.help.title"))))
	var actions := ["move_forward", "sprint", "ui_cancel", "help"]
	if guild:
		actions.append_array(["guild_menu", "interact"])
	if exploring:
		actions.append("inspect_hero")
		if not guild:
			actions.append_array(["floor_map", "interact"])
	for action in actions:
		var row := UiTheme.body(binding(action) + " — " + content.text("ui.help." + action))
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(row)
	var keyboard := UiTheme.body(content.text("ui.help.keyboard"))
	keyboard.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(keyboard)
	add_child(ScreenLayout.centre(UiTheme.title(content.text("help.glossary"))))
	for stat_id in ["might", "wit", "vigor", "focus"]:
		var explanation := UiTheme.body(MechanicsText.stat(content, stat_id, 0))
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(explanation)
	for lesson in ["combat", "upgrade", "rooms", "ghost"]:
		var text := UiTheme.body(content.text("help.lesson." + lesson))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(text)
	for keyword in ["exhaust", "retain"]:
		var text := UiTheme.body(content.text("help.keyword." + keyword))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(text)
	for status_id in ContentValidator.STATUSES:
		var text := UiTheme.body(MechanicsText.status(content, status_id))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(text)
	var close := Button.new()
	close.text = content.text("ui.close")
	close.pressed.connect(func() -> void: closed.emit())
	add_child(close)
