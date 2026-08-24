class_name UpgradeRow
extends PanelContainer
## One meta upgrade in the Guild (spec §5.9): what it does, how many levels
## are bought, and what the next one costs. A widget -- it renders the state
## it is given and reports the click through a signal.

signal buy_pressed(id: String)

var upgrade_id: String = ""

var _name: Label
var _text: Label
var _pips: Label
var _button: Button


func _init() -> void:
	_build()


func _build() -> void:
	# A compact box: ten of these plus two headings have to fit one screen,
	# and the shared panel margin made them tall enough to clip the last.
	add_theme_stylebox_override("panel", UiTheme.row_box(Palette.STONE_RAISED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UiTheme.body("")
	_text = UiTheme.small("")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_name)
	left.add_child(_text)
	row.add_child(left)

	_pips = UiTheme.small("", Palette.BONE_DIM)
	_pips.custom_minimum_size = Vector2(34.0, 0.0)
	_pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_pips)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(88.0, 32.0)
	_button.pressed.connect(func() -> void: buy_pressed.emit(upgrade_id))
	row.add_child(_button)


## cost < 0 means the upgrade is maxed or unknown -- Upgrades.cost's contract.
func bind(content: Content, def: UpgradeDef, level: int, cost: float, affordable: bool) -> void:
	upgrade_id = def.id
	_name.text = content.text(def.name_key)
	_text.text = content.text(def.text_key)
	_pips.text = "%d/%d" % [level, def.max_level]
	if cost < 0.0:
		_button.text = content.text("ui.maxed")
		_button.disabled = true
		return
	_button.text = Num.short(cost)
	_button.disabled = not affordable
