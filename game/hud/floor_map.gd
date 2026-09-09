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
var canvas: Control
var _title: Label
var _legend: Label
var _rooms: HFlowContainer

class Schematic extends Control:
	var map: FloorMap
	func _draw() -> void:
		map.draw_map()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			map.select_at(event.position)
			accept_event()


func _init() -> void:
	add_theme_constant_override("separation", 7)
	_title = ScreenLayout.centre(UiTheme.title(""))
	add_child(_title)
	var schematic := Schematic.new()
	schematic.map = self
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
	canvas.queue_redraw()


func resolved(index: int) -> bool:
	# RunState.is_resolved normalizes flags in place; inspection must not.
	return run.is_resolved(index)


func cell_size() -> float:
	return minf(canvas.size.x / maxf(1, layout.width), canvas.size.y / maxf(1, layout.height))


func origin() -> Vector2:
	return (canvas.size - Vector2(layout.width, layout.height) * cell_size()) * 0.5


func map_point(world: Vector3) -> Vector2:
	return origin() + (Vector2(world.x / Kit.CELL, world.z / Kit.CELL) + Vector2.ONE * 0.5) * cell_size()


func select_at(at: Vector2) -> void:
	if layout != null and cell_size() > 0.0:
		select_cell(Vector2i(((at - origin()) / cell_size()).floor()))


func select_cell(cell: Vector2i) -> void:
	if layout == null or not layout.is_walkable(cell.x, cell.y):
		return
	marker = cell
	marked.emit(cell)
	canvas.queue_redraw()


func draw_map() -> void:
	if layout == null:
		return
	var step := cell_size()
	var zero := origin()
	for y in layout.height:
		for x in layout.width:
			var kind := layout.cell(x, y)
			if kind == FloorLayout.Cell.VOID:
				continue
			canvas.draw_rect(Rect2(zero + Vector2(x, y) * step, Vector2.ONE * step),
				Palette.STONE_EDGE if kind == FloorLayout.Cell.WALL else Palette.STONE_RAISED)
	for i in run.nodes.size():
		var cell := layout.room_center(layout.room_of_node(i))
		var kind := String(run.nodes[i]["kind"])
		var at := zero + (Vector2(cell) + Vector2.ONE * 0.5) * step
		var texture := RoomPresentation.icon(kind)
		if texture != null:
			canvas.draw_texture_rect(texture, Rect2(at - Vector2(7, 12), Vector2(14, 14)), false, RoomPresentation.accent(kind))
		_symbol(cell, str(i + 1) + ("✓" if resolved(i) else "○"), Palette.BONE_DIM if resolved(i) else RoomPresentation.accent(kind))
	_symbol(layout.room_center(layout.entry_room), "E", Palette.SOUL)
	_symbol(layout.room_center(layout.stairs_room), "S" + ("✓" if run.exit_ready() else "×"), Palette.PREPARED)
	if marker.x >= 0:
		var target := zero + (Vector2(marker) + Vector2.ONE * 0.5) * step
		canvas.draw_circle(target, 5, Palette.LANTERN, false, 1.5)
	var player := map_point(player_at)
	var forward := Vector2(-sin(player_yaw), -cos(player_yaw))
	canvas.draw_circle(player, 3, Palette.SOUL)
	canvas.draw_line(player, player + forward * 10, Palette.SOUL, 2)


func _symbol(cell: Vector2i, label: String, colour: Color) -> void:
	var at := origin() + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size()
	canvas.draw_string(UiTheme.body_font(), at + Vector2(-4, 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_BODY, colour)
