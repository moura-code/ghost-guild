class_name NavBar
extends PanelContainer
## The main navigation (spec §9). Four plain buttons crammed into the corner
## read as a browser toolbar, not as a game menu, so this is a bar across the
## top of the window: an icon over a label for each destination, the active
## one lit and underlined in the biome accent, and a marker that slides
## between them rather than jumping.

signal tab_pressed(id: String)

const HEIGHT := 56.0
const ITEM_WIDTH := 108.0
const MARKER_HEIGHT := 2.0
const SLIDE_SECONDS := 0.22

var current: String = ""
var accent: Color = Palette.BONE

var _row: HBoxContainer
var _items: Dictionary = {}
var _marker_x: float = 0.0
var _marker_w: float = 0.0
var _marker_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	add_theme_stylebox_override("panel", UiTheme.bar_box())
	_build()


func _build() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 4)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)


## `tabs` is an ordered array of {id, label, icon}.
func build_tabs(tabs: Array) -> void:
	for tab in tabs:
		var id := String(tab["id"])
		var item := _make_item(id, String(tab["label"]), String(tab["icon"]))
		_row.add_child(item)
		_items[id] = item


func _make_item(id: String, label: String, icon: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(ITEM_WIDTH, HEIGHT - 10.0)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: tab_pressed.emit(id))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var glyph := Icons.make_rect(Icons.ui(icon), 22.0, Palette.BONE_DIM)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(glyph)

	var text := UiTheme.small(label, Palette.BONE_DIM)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(text)

	button.add_child(column)
	return button


## Lights the active destination and slides the marker to it. The slide is
## the point: a marker that jumps reads as a page reload.
func select(id: String) -> void:
	if not _items.has(id):
		return
	current = id
	for other in _items:
		var button: Button = _items[other]
		var column := button.get_child(0)
		var lit: bool = other == id
		(column.get_child(0) as TextureRect).modulate = accent if lit else Palette.BONE_DIM
		(column.get_child(1) as Label).add_theme_color_override(
			"font_color", Palette.BONE if lit else Palette.BONE_DIM)
	# Deferred: at the moment select() runs, the container has not laid the
	# buttons out yet, so every position reads 0 and the marker parks itself
	# at the far left of the bar.
	_slide_marker.call_deferred(_items[id] as Button)


func _slide_marker(to: Button) -> void:
	if not is_instance_valid(to):
		return
	var target_x := to.position.x
	var target_w := to.size.x
	if target_w <= 0.0:
		return
	if _marker_w <= 0.0 or not is_inside_tree():
		_marker_x = target_x
		_marker_w = target_w
		queue_redraw()
		return
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = create_tween()
	_marker_tween.set_parallel(true)
	_marker_tween.tween_method(_set_marker_x, _marker_x, target_x, SLIDE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_marker_tween.tween_method(_set_marker_w, _marker_w, target_w, SLIDE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_marker_x(value: float) -> void:
	_marker_x = value
	queue_redraw()


func _set_marker_w(value: float) -> void:
	_marker_w = value
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and current != "" and _items.has(current):
		_marker_x = (_items[current] as Button).position.x
		_marker_w = (_items[current] as Button).size.x
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0:
		return
	# A hairline under the whole bar, so it reads as a shelf the screen
	# hangs from rather than as a floating strip.
	draw_rect(Rect2(Vector2(0.0, size.y - 1.0), Vector2(size.x, 1.0)),
		Color(Palette.STONE_EDGE.r, Palette.STONE_EDGE.g, Palette.STONE_EDGE.b, 0.7))
	if _marker_w <= 0.0:
		return
	var x := _row.position.x + _marker_x
	draw_rect(Rect2(Vector2(x, size.y - MARKER_HEIGHT), Vector2(_marker_w, MARKER_HEIGHT)), accent)
	# A soft bloom above the marker, so the active tab glows a little.
	for i in 6:
		var t := float(i) / 5.0
		draw_rect(Rect2(Vector2(x, size.y - MARKER_HEIGHT - t * 14.0), Vector2(_marker_w, 2.0)),
			Color(accent.r, accent.g, accent.b, 0.06 * (1.0 - t)))
