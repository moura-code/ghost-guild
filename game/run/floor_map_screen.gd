class_name FloorMapScreen
extends VBoxContainer
## The floor's short path (spec §3.1): three nodes drawn from the biome's
## pattern table, then the exit -- drawn as a corridor of doorways, with the
## floor under them and the way you have already walked lit behind you.
##
## It used to be four 96x44 chips in the top-left corner over a full-width
## button, with most of the window left empty. This is the screen between
## every node in the game and it read as a toolbar.
##
## A screen, not a widget: it holds the GameRoot so Enter can apply the
## action, but it takes the run explicitly so tests can bind any state.

const GAP := 26.0
## Room for the doors, the floor they stand on and the path across it.
const CORRIDOR_HEIGHT := 150.0
const DOOR_TOP := 30.0

var game: GameRoot
var run: RunState
var current_index: int = 0

var _path: Control
var _enter: Button
var _marks: Array[Label] = []
var _boxes: Array[DoorwayView] = []
var _icons: Array[TextureRect] = []


func _init() -> void:
	add_theme_constant_override("separation", 22)
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func bind(g: GameRoot, p_run: RunState) -> void:
	game = g
	run = p_run
	if _path == null:
		_build()
	refresh()


func _build() -> void:
	_path = Control.new()
	_path.custom_minimum_size = Vector2(0.0, CORRIDOR_HEIGHT)
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path.draw.connect(_draw_corridor)
	_path.resized.connect(_layout_doors)
	add_child(_path)

	_enter = Button.new()
	_enter.custom_minimum_size = Vector2(140.0, 22.0)
	_enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enter.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.SOUL))
	_enter.pressed.connect(_on_enter)
	add_child(_enter)


## Where the doors' feet sit inside the corridor: the very bottom of the
## door, so the floor starts under them rather than cutting across them.
func _door_foot() -> float:
	return DOOR_TOP + DoorwayView.SIZE.y


## The doors sit in a row along the corridor, centred in whatever width the
## window gives them.
func _layout_doors() -> void:
	if _path == null or _boxes.is_empty():
		return
	var n := _boxes.size()
	var span := float(n) * DoorwayView.SIZE.x + float(n - 1) * GAP
	var left := (_path.size.x - span) * 0.5
	var top := DOOR_TOP
	for i in n:
		_boxes[i].position = Vector2(left + float(i) * (DoorwayView.SIZE.x + GAP), top)
	_path.queue_redraw()


## The floor, and the way across it. What you have already walked is lit;
## what is ahead is only faintly marked, because you have not been there.
func _draw_corridor() -> void:
	if _boxes.is_empty() or _path.size.x <= 0.0:
		return
	var foot := _door_foot()
	var w := _path.size.x

	# The floor: a slab running away from the doors, dimming with distance.
	var floor_top := foot - 2.0
	var depth := maxf(1.0, CORRIDOR_HEIGHT - floor_top)
	for i in 10:
		var t := float(i) / 9.0
		var y := floor_top + t * depth
		var inset := (1.0 - t) * w * 0.06
		_path.draw_rect(Rect2(Vector2(inset, y), Vector2(w - inset * 2.0, depth / 10.0 + 1.0)),
			Color(Palette.STONE_RAISED.r, Palette.STONE_RAISED.g, Palette.STONE_RAISED.b,
				0.42 * (1.0 - t * 0.75)))
	_path.draw_rect(Rect2(Vector2(0.0, floor_top), Vector2(w, 1.0)),
		Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g, Palette.EDGE_LIGHT.b, 0.30))

	# The path itself: pips between each pair of doors, lit behind you.
	for i in _boxes.size() - 1:
		var a := _boxes[i].position.x + DoorwayView.SIZE.x
		var b := _boxes[i + 1].position.x
		var walked := i < current_index
		var colour := Palette.SOUL if walked else Palette.STONE_EDGE
		for step in 3:
			var t := (float(step) + 0.5) / 3.0
			_path.draw_circle(Vector2(lerpf(a, b, t), foot + 22.0), 2.5 if walked else 2.0,
				Color(colour.r, colour.g, colour.b, 0.75 if walked else 0.35))


func refresh() -> void:
	if run == null:
		return
	current_index = run.node_index
	_rebuild_path()
	_refresh_enter()


## One marker per node plus a final one for the floor exit, so the player
## can see the shape of the whole floor before committing to it.
func _rebuild_path() -> void:
	var wanted := run.nodes.size() + 1
	while _marks.size() < wanted:
		var door := DoorwayView.new()
		_path.add_child(door)
		_marks.append(door._label)
		_boxes.append(door)
		_icons.append(door._icon)
	while _marks.size() > wanted:
		var stale: DoorwayView = _boxes.pop_back()
		_marks.pop_back()
		_icons.pop_back()
		_path.remove_child(stale)
		stale.queue_free()

	for i in run.nodes.size():
		var kind := String(run.nodes[i]["kind"])
		_boxes[i].bind(game.text("ui.node.%s" % kind), Icons.get_icon("node", kind),
			state_of(i), accent_for(kind))
	var last := run.nodes.size()
	_boxes[last].bind(game.text("ui.node.exit"), Icons.get_icon("node", "exit"),
		state_of(last), Palette.PREPARED)
	_layout_doors()


## What colour the light behind a door is. A fight and a shop should not
## glow the same: the colour is the first thing read at a glance.
static func accent_for(kind: String) -> Color:
	match kind:
		"fight": return Palette.DANGER
		"elite": return Palette.PREPARED
		"shop": return Palette.PREPARED
		"rest": return Palette.GOOD
		"event": return Palette.ECHO
		_: return Palette.SOUL


## "done" behind you, "current" where you stand, "ahead" not yet walked.
func state_of(index: int) -> String:
	if index < current_index:
		return "done"
	if index == current_index:
		return "current"
	return "ahead"


func _refresh_enter() -> void:
	var node := run.current_node()
	var kind := String(node.get("kind", ""))
	if kind == "":
		_enter.text = game.text("ui.node.enter")
		_enter.disabled = true
		return
	_enter.text = "%s: %s" % [game.text("ui.node.enter"), game.text("ui.node.%s" % kind)]
	_enter.disabled = run.phase != "node"


func _on_enter() -> void:
	if run == null or run.phase != "node":
		return
	game.run_action({"kind": "enter"})
