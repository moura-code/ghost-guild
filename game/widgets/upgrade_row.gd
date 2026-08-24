class_name UpgradeRow
extends PanelContainer
## One meta upgrade in the Guild (spec §5.9): what it does, how many levels
## are bought, and what the next one costs. A widget -- it renders the state
## it is given and reports the click through a signal.

signal buy_pressed(id: String)

var upgrade_id: String = ""

var _name: Label
var _text: Label
var _button: Button
var _icon: PanelContainer
var _pips: Control
var _level: int = 0
var _max_level: int = 1


func _init() -> void:
	_build()


func _build() -> void:
	# A compact box: ten of these plus two headings have to fit one screen,
	# and the shared panel margin made them tall enough to clip the last.
	add_theme_stylebox_override("panel", UiTheme.row_box(Palette.STONE_RAISED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	# Its own glyph, plated by group -- a column of identical text rows is
	# what made this screen read as a settings menu rather than a guild.
	_icon = Icons.make_plate(null, 30.0, Palette.BONE, Palette.PLATE_NEUTRAL,
		Palette.STONE_EDGE)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UiTheme.body("")
	_text = UiTheme.small("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_name)
	left.add_child(_text)
	row.add_child(left)

	# Levels as pips: a filled row of them says "nearly maxed" at a glance,
	# where "2/3" has to be read.
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(52.0, 12.0)
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pips.draw.connect(_draw_pips)
	row.add_child(_pips)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(88.0, 32.0)
	_button.pressed.connect(func() -> void: buy_pressed.emit(upgrade_id))
	row.add_child(_button)


## cost < 0 means the upgrade is maxed or unknown -- Upgrades.cost's contract.
## Filled for levels bought, hollow for levels still available.
func _draw_pips() -> void:
	var r := 4.0
	var gap := 11.0
	var y := _pips.size.y * 0.5
	for i in _max_level:
		var at := Vector2(r + float(i) * gap, y)
		if i < _level:
			_pips.draw_circle(at, r, Palette.PREPARED)
		else:
			_pips.draw_arc(at, r, 0.0, TAU, 14, Palette.BONE_FAINT, 1.2)


func bind(content: Content, def: UpgradeDef, level: int, cost: float, affordable: bool) -> void:
	upgrade_id = def.id
	_name.text = content.text(def.name_key)
	_text.text = content.text(def.text_key)
	_level = level
	_max_level = maxi(1, def.max_level)
	(_icon.get_child(0) as TextureRect).texture = Icons.get_icon("upgrade", def.id)
	_pips.queue_redraw()
	if cost < 0.0:
		_button.text = content.text("ui.maxed")
		_button.disabled = true
		_button.add_theme_stylebox_override("normal",
			UiTheme.panel_box(Palette.VOID, Palette.PREPARED))
		_button.add_theme_color_override("font_color", Palette.PREPARED)
		return
	_button.text = Num.short(cost)
	_button.disabled = not affordable
	# Affordable reads as an offer; unaffordable recedes. One flat style for
	# both made the whole screen look like a settings menu.
	if affordable:
		_button.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.SOUL))
		_button.add_theme_color_override("font_color", Palette.BONE)
	else:
		_button.add_theme_stylebox_override("normal",
			UiTheme.panel_box(Palette.VOID, Palette.STONE_RAISED))
		_button.add_theme_color_override("font_color", Palette.BONE_FAINT)
