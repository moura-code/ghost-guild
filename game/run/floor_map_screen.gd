class_name FloorMapScreen
extends VBoxContainer
## The floor's short path (spec §3.1): three nodes drawn from the biome's
## pattern table, then the exit. Typographic rather than iconographic --
## each node says what it is, and the one you are standing on is the only
## one you can walk into.
##
## A screen, not a widget: it holds the GameRoot so Enter can apply the
## action, but it takes the run explicitly so tests can bind any state.

const MARK_WIDTH := 96.0
const MARK_HEIGHT := 44.0

var game: GameRoot
var run: RunState
var current_index: int = 0

var _path: HBoxContainer
var _enter: Button
var _marks: Array[Label] = []
var _boxes: Array[PanelContainer] = []


func _init() -> void:
	add_theme_constant_override("separation", 14)


func bind(g: GameRoot, p_run: RunState) -> void:
	game = g
	run = p_run
	if _path == null:
		_build()
	refresh()


func _build() -> void:
	_path = HBoxContainer.new()
	_path.add_theme_constant_override("separation", 8)
	add_child(_path)

	_enter = Button.new()
	_enter.pressed.connect(_on_enter)
	add_child(_enter)


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
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(MARK_WIDTH, MARK_HEIGHT)
		var label := UiTheme.body("")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(label)
		_path.add_child(box)
		_marks.append(label)
		_boxes.append(box)
	while _marks.size() > wanted:
		var stale: PanelContainer = _boxes.pop_back()
		_marks.pop_back()
		_path.remove_child(stale)
		stale.queue_free()

	for i in run.nodes.size():
		_marks[i].text = game.text("ui.node.%s" % String(run.nodes[i]["kind"]))
		_paint(i)
	var last := run.nodes.size()
	_marks[last].text = game.text("ui.node.exit")
	_paint(last)


## "done" behind you, "current" where you stand, "ahead" not yet walked.
func state_of(index: int) -> String:
	if index < current_index:
		return "done"
	if index == current_index:
		return "current"
	return "ahead"


func _paint(index: int) -> void:
	var state := state_of(index)
	var label := _marks[index]
	var box := _boxes[index]
	match state:
		"done":
			label.add_theme_color_override("font_color", Palette.BONE_FAINT)
			box.add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE))
		"current":
			label.add_theme_color_override("font_color", Palette.BONE)
			box.add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED, Palette.SOUL))
		_:
			label.add_theme_color_override("font_color", Palette.BONE_DIM)
			box.add_theme_stylebox_override("panel", UiTheme.panel_box(Palette.STONE_RAISED))


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
