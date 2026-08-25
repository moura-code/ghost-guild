class_name UpgradePlaque
extends PanelContainer
## One meta upgrade in the Guild (spec §5.9): what it does, how many levels
## are bought, and what the next one costs. A widget -- it renders the state
## it is given and reports the click through a signal.
##
## It was a full-width row, and ten full-width rows stacked in a scrolling
## column is a settings menu no matter what the rows are made of. Carving
## them did not help, because the problem was never the row, it was the list.
##
## It is a tablet mounted on the wall now, and the Guild is a wall of them --
## all ten visible at once, nothing to scroll. A player should be able to see
## everything the guild can do for them in one look, which is also what makes
## the screen read as a place rather than as a page of settings.

signal buy_pressed(id: String)

## Sized so a group fits one row and both groups fit one screen with nothing
## to scroll -- that is the whole point of the wall, and a tablet ten pixels
## too wide puts half the guild below the fold again.
## Height is what the tallest tablet actually measures, not a wish: names
## like "Lantern Discipline" wrap to two lines at this width, and declaring
## a size the content overruns is how the second group ended up below the
## fold twice.
const PLAQUE_SIZE := Vector2(85.0, 90.0)
const COLUMNS := 6

var upgrade_id: String = ""

var _name: Label
var _button: Button
var _icon: PanelContainer
var _pips: Control
var _level: int = 0
var _max_level: int = 1


func _init() -> void:
	_build()


func _build() -> void:
	custom_minimum_size = PLAQUE_SIZE
	add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	# The glyph is the biggest thing on the tablet: at a wall of ten, the
	# player finds the one they want by its shape, not by reading ten names.
	_icon = Icons.make_plate(null, 14.0, Palette.BONE, Palette.PLATE_NEUTRAL,
		Palette.STONE_EDGE)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_icon)

	_name = UiTheme.body("")
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_name)

	# The description is on the tablet's tooltip rather than on its face.
	#
	# Three lines of body text under every name made each tablet a different
	# height, which stopped the row being a row, and two groups of them did
	# not fit the window. A wall of offerings should answer "what is it and
	# what does it cost" at a glance and keep the fine print for the one the
	# player is actually reaching for -- which is what hovering means.
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Levels as pips: a filled row of them says "nearly maxed" at a glance,
	# where "2/3" has to be read.
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(0.0, 7.0)
	_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pips.draw.connect(_draw_pips)
	column.add_child(_pips)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(0.0, 14.0)
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.pressed.connect(func() -> void: buy_pressed.emit(upgrade_id))
	column.add_child(_button)


## cost < 0 means the upgrade is maxed or unknown -- Upgrades.cost's contract.
## Filled for levels bought, hollow for levels still available.
func _draw_pips() -> void:
	var r := 4.0
	var gap := 11.0
	var y := _pips.size.y * 0.5
	var span := float(maxi(0, _max_level - 1)) * gap
	var start := (_pips.size.x - span) * 0.5
	for i in _max_level:
		var at := Vector2(start + float(i) * gap, y)
		if i < _level:
			_pips.draw_circle(at, r, Palette.PREPARED)
		else:
			_pips.draw_arc(at, r, 0.0, TAU, 14, Palette.BONE_FAINT, 1.2)


func bind(content: Content, def: UpgradeDef, level: int, cost: float, affordable: bool) -> void:
	upgrade_id = def.id
	_name.text = content.text(def.name_key)
	tooltip_text = "%s
%s" % [content.text(def.name_key), content.text(def.text_key)]
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
