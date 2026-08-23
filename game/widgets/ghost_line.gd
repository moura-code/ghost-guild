class_name GhostLine
extends PanelContainer
## One ghost in the Séance list (spec §5.5): who it was, where it stands,
## how hard it works, and the things that can be done to it. A widget -- it
## renders the state it is given and reports clicks through signals.

signal echo_pressed(ghost_id: int, floor: int)
signal call_pressed(ghost_id: int, floor: int)
signal tend_pressed(ghost_id: int)

var ghost_id: int = 0

var _mark: GhostMark
var _name: Label
var _detail: Label
var _floor: SpinBox
var _echo: Button
var _call: Button
var _tend: Button


func _init() -> void:
	_build()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_mark = GhostMark.new()
	_mark.floating = false
	row.add_child(_mark)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = UiTheme.body("")
	_detail = UiTheme.small("")
	text_box.add_child(_name)
	text_box.add_child(_detail)
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

	_echo = Button.new()
	_echo.pressed.connect(func() -> void: echo_pressed.emit(ghost_id, int(_floor.value)))
	row.add_child(_echo)

	_call = Button.new()
	_call.pressed.connect(func() -> void: call_pressed.emit(ghost_id, int(_floor.value)))
	row.add_child(_call)


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

	var waypoint := maxi(1, int(ctx["waypoint"]))
	var soul := float(ctx["soul"])
	# Keep the player's chosen floor when it is still legal.
	_floor.max_value = float(waypoint)
	if _floor.value < 1.0 or _floor.value > float(waypoint):
		_floor.value = float(ghost.floor)

	var is_true := ghost.kind == "true"
	_echo.visible = is_true
	_call.visible = not is_true
	_tend.visible = is_true and ghost.restless
	_floor.visible = true

	if is_true:
		var echo_cost := float(ctx["echo_cost"])
		_echo.text = Num.short(echo_cost)
		_echo.disabled = soul < echo_cost
	else:
		var call_cost := float(ctx["call_cost"])
		_call.text = Num.short(call_cost)
		_call.disabled = soul < call_cost

	if _tend.visible:
		var tend_cost := float(ctx["tend_cost"])
		_tend.text = content.text("ui.free") if tend_cost <= 0.0 else Num.short(tend_cost)
		_tend.disabled = tend_cost > 0.0 and soul < tend_cost
