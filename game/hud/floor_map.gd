class_name FloorMap
extends VBoxContainer
## The current generated floor, read directly. Markers are presentation state.

signal marked(cell: Vector2i)
signal closed()
var layout: FloorLayout
var run: RunState
var player_at := Vector3.ZERO
var player_yaw: float = 0.0
var marker := Vector2i(-1, -1)
var canvas: FloorSchematic
var _title: Label
var _legend: Label
var _rooms: HFlowContainer

func _init() -> void:
	add_theme_constant_override("separation", 7)
	_title = ScreenLayout.centre(UiTheme.title(""))
	add_child(_title)
	var schematic := FloorSchematic.new()
	schematic.interactive = true
	schematic.selected.connect(select_cell)
	schematic.custom_minimum_size = Vector2(0, 190)
	schematic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas = schematic
	add_child(canvas)
	_legend = ScreenLayout.centre(UiTheme.body(""))
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_legend)
	_rooms = HFlowContainer.new()
	_rooms.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(_rooms)


func bind(current_layout: FloorLayout, current_run: RunState, at: Vector3, yaw: float) -> void:
	if layout != current_layout:
		marker = Vector2i(-1, -1)
	layout = current_layout
	run = current_run
	player_at = at
	player_yaw = yaw
	_title.text = run.content.text("ui.map.title").replace("{floor}", str(run.floor))
	_legend.text = run.content.text("room.legend") + "\n" + RoomPresentation.stairs_text(run)
	for child in _rooms.get_children():
		child.free()
	for i in run.nodes.size():
		var button := Button.new()
		button.text = "%d · %s · %s" % [i + 1, RoomPresentation.label(run.content, String(run.nodes[i]["kind"])), run.content.text("room.state." + RoomPresentation.availability(run, i))]
		button.icon = RoomPresentation.icon(String(run.nodes[i]["kind"]))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 14)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = RoomPresentation.describe(run, i)
		button.focus_entered.connect(func() -> void: _legend.text = RoomPresentation.describe(run, i))
		button.mouse_entered.connect(func() -> void: _legend.text = RoomPresentation.describe(run, i))
		button.pressed.connect(func() -> void: select_cell(layout.room_center(layout.room_of_node(i))))
		_rooms.add_child(button)
	canvas.bind(layout, run, player_at, player_yaw, marker)


func resolved(index: int) -> bool:
	return run.is_resolved(index)


func cell_size() -> float:
	return canvas.cell_size()


func origin() -> Vector2:
	return canvas.origin()


func map_point(world: Vector3) -> Vector2:
	return canvas.map_point(world)


func select_at(at: Vector2) -> void:
	if layout != null and cell_size() > 0.0:
		select_cell(Vector2i(((at - origin()) / cell_size()).floor()))


func select_cell(cell: Vector2i) -> void:
	if layout == null or not layout.is_walkable(cell.x, cell.y):
		return
	marker = cell
	marked.emit(cell)
	canvas.bind(layout, run, player_at, player_yaw, marker)
