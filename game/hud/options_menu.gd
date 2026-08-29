class_name OptionsMenu
extends PanelContainer
## Mouse sensitivity, invert, field of view, volume, fullscreen.
##
## Every control applies live and writes through on release, so what you are
## looking at while you drag the slider is what you get -- a sensitivity you
## can only judge after closing the menu is a sensitivity you will get wrong
## three times before you get it right.

signal closed()
signal changed(settings: Settings)

var settings: Settings
var sliders: Dictionary = {}
var checks: Dictionary = {}

var _column: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(280.0, 0.0)
	add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED))

	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_%s" % side, 16)
	add_child(margins)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 5)
	margins.add_child(_column)


func build(content: Content, s: Settings) -> void:
	settings = s
	for child in _column.get_children():
		child.queue_free()
	sliders.clear()
	checks.clear()

	var title := UiTheme.title(content.text("ui.menu.options"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_column.add_child(HSeparator.new())

	_slider(content, "sensitivity", "ui.options.sensitivity",
		Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX, 0.05, s.sensitivity)
	_check(content, "invert_y", "ui.options.invert_y", s.invert_y)
	_slider(content, "fov", "ui.options.fov", Settings.FOV_MIN, Settings.FOV_MAX, 1.0, s.fov)
	_slider(content, "master_volume", "ui.options.volume", 0.0, 1.0, 0.05, s.master_volume)
	_check(content, "fullscreen", "ui.options.fullscreen", s.fullscreen)

	_column.add_child(HSeparator.new())
	var back := Button.new()
	back.text = content.text("ui.menu.back")
	back.custom_minimum_size = Vector2(0.0, 22.0)
	back.pressed.connect(func() -> void: closed.emit())
	_column.add_child(back)


## Reads every control back into the Settings object and announces it. One
## path, so "what the menu shows" and "what the game does" cannot diverge.
func commit() -> void:
	if settings == null:
		return
	settings.sensitivity = float((sliders["sensitivity"] as HSlider).value)
	settings.fov = float((sliders["fov"] as HSlider).value)
	settings.master_volume = float((sliders["master_volume"] as HSlider).value)
	settings.invert_y = (checks["invert_y"] as CheckBox).button_pressed
	settings.fullscreen = (checks["fullscreen"] as CheckBox).button_pressed
	changed.emit(settings)


func _slider(content: Content, id: String, key: String, low: float, high: float, step: float, value: float) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.add_child(UiTheme.small(content.text(key), Palette.BONE))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(0.0, 14.0)
	slider.value_changed.connect(func(_v: float) -> void: commit())
	row.add_child(slider)
	_column.add_child(row)
	sliders[id] = slider


func _check(content: Content, id: String, key: String, value: bool) -> void:
	var box := CheckBox.new()
	box.text = content.text(key)
	box.button_pressed = value
	box.toggled.connect(func(_on: bool) -> void: commit())
	_column.add_child(box)
	checks[id] = box
