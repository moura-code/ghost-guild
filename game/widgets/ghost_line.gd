class_name GhostLine
extends PanelContainer
## One ghost in the Séance list (spec §5.5): who it was, where it stands,
## how hard it works, and the things that can be done to it. A widget -- it
## renders the state it is given and reports clicks through signals.

signal echo_pressed(ghost_id: int, floor: int)
signal call_pressed(ghost_id: int, floor: int)
signal tend_pressed(ghost_id: int)
signal upgrade_pressed(ghost_id: int)
signal relic_pressed(ghost_id: int)

var ghost_id: int = 0

var _mark: GhostMark
var _name: Label
var _detail: Label
var _doctrine: Label
var _floor: SpinBox
var _floor_seeded: bool = false
var _echo: Button
var _call: Button
var _tend: Button
## The two tends that make a ghost permanently worth more (spec §5.5).
var _upgrade: Button
var _relic: Button
var _echo_cost: float = 0.0
var _call_cost: float = 0.0
var _tend_cost: float = 0.0
var _upgrade_cost: float = 0.0
var _relic_cost: float = 0.0


func _init() -> void:
	_build()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	# Large enough to read as somebody. This screen is a list of the people
	# who died for you; a 14px glyph made it a spreadsheet of them.
	_mark = GhostMark.new()
	_mark.custom_minimum_size = GhostMark.BASE_SIZE * 1.25
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mark)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UiTheme.body("")
	_detail = UiTheme.small("", Palette.BONE_DIM)
	text_box.add_child(_name)
	text_box.add_child(_detail)

	# What this one was told to do. The picker's whole promise is that the
	# choice matters, and a choice the player can never see again is one they
	# will not make carefully a second time.
	_doctrine = UiTheme.small("", Palette.GHOST)
	_doctrine.visible = false
	text_box.add_child(_doctrine)
	row.add_child(text_box)

	_floor = SpinBox.new()
	_floor.min_value = 1.0
	_floor.max_value = 1.0
	_floor.step = 1.0
	_floor.custom_minimum_size = Vector2(62.0, 0.0)
	row.add_child(_floor)

	_tend = Button.new()
	_tend.pressed.connect(func() -> void: tend_pressed.emit(ghost_id))
	row.add_child(_tend)

	_upgrade = Button.new()
	_upgrade.pressed.connect(func() -> void: upgrade_pressed.emit(ghost_id))
	row.add_child(_upgrade)

	_relic = Button.new()
	_relic.pressed.connect(func() -> void: relic_pressed.emit(ghost_id))
	row.add_child(_relic)

	_echo = Button.new()
	_echo.pressed.connect(func() -> void: echo_pressed.emit(ghost_id, int(_floor.value)))
	row.add_child(_echo)

	_call = Button.new()
	_call.pressed.connect(func() -> void: call_pressed.emit(ghost_id, int(_floor.value)))
	row.add_child(_call)


## The rules this ghost fights by, as one line, or "" if it has none. Static
## so the epitaph screen and anything else that shows a ghost can say the same
## sentence the same way.
static func doctrine_text(content: Content, ghost: Ghost) -> String:
	var names: Array[String] = []
	for id in ghost.rules:
		if not content.rules.has(id):
			continue
		var rule: RuleDef = content.rules[id]
		names.append(content.text(rule.name_key))
	if names.is_empty():
		return ""
	return content.text("ui.ghost.doctrine").replace("{rules}", ", ".join(names))


## ctx = {waypoint: int, echo_cost: float, call_cost: float,
##        tend_cost: float, soul: float}
func bind(content: Content, ghost: Ghost, ctx: Dictionary) -> void:
	ghost_id = ghost.id
	_mark.bind(ghost)
	_name.text = ghost.name

	var bits := PackedStringArray()
	bits.append("%s %d" % [content.text("ui.floor_short"), ghost.floor])
	bits.append("%s %s" % [Num.short(ghost.strength), content.text("ui.strength")])
	if ghost.kind == "echo":
		bits.append(content.text("ui.echo"))
	if ghost.restless:
		bits.append(content.text("ui.restless"))
	_detail.text = " · ".join(bits)
	_doctrine.text = doctrine_text(content, ghost)
	# Hidden rather than blank when there is nothing to say: an empty line
	# under every ghost turns a list of people into a list of gaps.
	_doctrine.visible = _doctrine.text != ""

	var waypoint := maxi(1, int(ctx["waypoint"]))
	var soul := float(ctx["soul"])
	# Keep the player's chosen floor when it is still legal.
	_floor.max_value = float(waypoint)
	if not _floor_seeded or _floor.value < 1.0 or _floor.value > float(waypoint):
		_floor.value = float(ghost.floor)
		_floor_seeded = true

	var is_true := ghost.is_true()
	_echo.visible = is_true
	_call.visible = not is_true
	_tend.visible = is_true and ghost.restless
	_floor.visible = true

	if is_true:
		_echo_cost = float(ctx["echo_cost"])
		# The verb, not just the price. A button whose entire label is `50`
		# tells a new player nothing about what pressing it does.
		_echo.text = "%s %s" % [content.text("ui.echo"), Num.short(_echo_cost)]
	else:
		_call_cost = float(ctx["call_cost"])
		_call.text = "%s %s" % [content.text("ui.call"), Num.short(_call_cost)]

	if _tend.visible:
		_tend_cost = float(ctx["tend_cost"])
		_tend.text = "%s %s" % [content.text("ui.tend"),
			content.text("ui.free") if _tend_cost <= 0.0 else Num.short(_tend_cost)]

	# Hidden rather than disabled when there is nothing left to sharpen or
	# nothing in the compendium it does not already carry: a permanently dead
	# button on every row teaches the player the row is mostly dead.
	_upgrade.visible = is_true and bool(ctx.get("can_upgrade", false))
	if _upgrade.visible:
		_upgrade_cost = float(ctx["upgrade_cost"])
		_upgrade.text = "%s %s" % [content.text("ui.tend.sharpen"), Num.short(_upgrade_cost)]
	_relic.visible = is_true and bool(ctx.get("can_relic", false))
	if _relic.visible:
		_relic_cost = float(ctx["relic_cost"])
		_relic.text = "%s %s" % [content.text("ui.tend.relic"), Num.short(_relic_cost)]

	set_affordability(soul)


## The 10 Hz path: affordability only, never a rebind.
func set_affordability(soul: float) -> void:
	if _echo.visible:
		_echo.disabled = soul < _echo_cost
	if _call.visible:
		_call.disabled = soul < _call_cost
	if _tend.visible:
		_tend.disabled = _tend_cost > 0.0 and soul < _tend_cost
