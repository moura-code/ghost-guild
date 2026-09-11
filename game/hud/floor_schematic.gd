class_name FloorSchematic
extends Control
## Shared read-only geometry and symbols for the full map and live minimap.

signal selected(cell: Vector2i)
var layout: FloorLayout
var run: RunState
var player_at := Vector3.ZERO
var player_yaw := 0.0
var marker := Vector2i(-1, -1)
var compact := false
var interactive := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func bind(current_layout: FloorLayout, current_run: RunState, at: Vector3, yaw: float, destination: Vector2i) -> void:
	layout = current_layout
	run = current_run
	player_at = at
	player_yaw = yaw
	marker = destination
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func area() -> Rect2:
	return Rect2(Vector2(5, 20), size - Vector2(10, 25)) if compact else Rect2(Vector2.ZERO, size)


func cell_size() -> float:
	if layout == null:
		return 0.0
	return maxf(0, minf(area().size.x / maxf(1, layout.width), area().size.y / maxf(1, layout.height)))


func origin() -> Vector2:
	if layout == null:
		return Vector2.ZERO
	return area().position + (area().size - Vector2(layout.width, layout.height) * cell_size()) * 0.5


func map_point(world: Vector3) -> Vector2:
	return origin() + (Vector2(world.x / Kit.CELL, world.z / Kit.CELL) + Vector2.ONE * 0.5) * cell_size()


func _gui_input(event: InputEvent) -> void:
	if interactive and layout != null and cell_size() > 0 and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(Vector2i(((event.position - origin()) / cell_size()).floor()))
		accept_event()


func _draw() -> void:
	if layout == null or run == null or cell_size() <= 0:
		return
	if compact:
		draw_style_box(UiTheme.panel_box(Color(0.025, 0.03, 0.04, 0.9)), Rect2(Vector2.ZERO, size))
		draw_string(UiTheme.body_font(), Vector2(6, 13), run.content.text("ui.map.title").replace("{floor}", str(run.floor)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, UiTheme.FONT_BODY, Palette.BONE)
		draw_string(UiTheme.body_font(), Vector2(size.x - 17, 13), "N↑", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_BODY, Palette.BONE_DIM)
	var step := cell_size()
	var zero := origin()
	for y in layout.height:
		for x in layout.width:
			var kind := layout.cell(x, y)
			if kind != FloorLayout.Cell.VOID:
				draw_rect(Rect2(zero + Vector2(x, y) * step, Vector2.ONE * step), Palette.STONE_EDGE if kind == FloorLayout.Cell.WALL else Palette.STONE_RAISED)
	for i in run.nodes.size():
		var cell := layout.room_center(layout.room_of_node(i))
		var kind := String(run.nodes[i]["kind"])
		var at := zero + (Vector2(cell) + Vector2.ONE * 0.5) * step
		var done := run.is_resolved(i)
		var colour := Palette.BONE_DIM if done and not run.can_enter(i) else RoomPresentation.accent(kind)
		var texture := RoomPresentation.icon(kind)
		var extent := 10.0 if compact else 14.0
		if texture != null:
			draw_texture_rect(texture, Rect2(at - Vector2(extent * 0.5, extent), Vector2.ONE * extent), false, colour)
		_symbol(cell, ("✓" if done else ("·" if run.is_visited(i) else "○")) if compact else str(i + 1) + ("✓" if done else "○"), colour)
	_symbol(layout.room_center(layout.entry_room), "E", Palette.SOUL)
	_symbol(layout.room_center(layout.stairs_room), "S" + ("✓" if run.exit_ready() else "×"), Palette.PREPARED)
	if marker.x >= 0:
		draw_circle(zero + (Vector2(marker) + Vector2.ONE * 0.5) * step, 5, Palette.LANTERN, false, 1.5)
	var player := map_point(player_at)
	var forward := Vector2(-sin(player_yaw), -cos(player_yaw))
	draw_circle(player, 2 if compact else 3, Palette.SOUL)
	draw_line(player, player + forward * (7 if compact else 10), Palette.SOUL, 2)


func _symbol(cell: Vector2i, label: String, colour: Color) -> void:
	var at := origin() + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size()
	draw_string(UiTheme.body_font(), at + Vector2(-4, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_BODY, colour)
