class_name DoorwayView
extends Control
## One node on the floor, drawn as a doorway in the corridor wall.
##
## The floor map used to be four 96x44 chips crowded into the top-left
## corner above a full-width button, with five hundred pixels of empty wall
## under them. Nothing about it said "choose where to go next" -- it read as
## a toolbar. A door you can see into says it without a word of text.
##
## The arch is drawn rather than styled because a StyleBox cannot be an
## arch, and the arch is the whole idea.

const SIZE := Vector2(150.0, 208.0)
const FRAME := 11.0

## "done" behind you, "current" where you stand, "ahead" not yet walked.
var state: String = "ahead"
var accent: Color = Palette.SOUL

var _icon: TextureRect
var _label: Label
var _time: float = 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_icon = Icons.make_rect(null, 52.0, Palette.BONE)
	_icon.position = Vector2(SIZE.x * 0.5 - 26.0, SIZE.y * 0.40 - 26.0)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_label = UiTheme.small("")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(SIZE.x, 18.0)
	_label.position = Vector2(0.0, SIZE.y - 22.0)
	add_child(_label)


func bind(text: String, texture: Texture2D, p_state: String, p_accent: Color) -> void:
	_label.text = text
	_icon.texture = texture
	state = p_state
	accent = p_accent
	match state:
		"done":
			_icon.modulate = Palette.BONE_FAINT
			_label.add_theme_color_override("font_color", Palette.BONE_FAINT)
		"current":
			_icon.modulate = Palette.BONE
			_label.add_theme_color_override("font_color", Palette.BONE)
		_:
			_icon.modulate = Palette.BONE_DIM
			_label.add_theme_color_override("font_color", Palette.BONE_DIM)
	queue_redraw()


## The door you are standing at breathes; the rest are still.
func _process(delta: float) -> void:
	if state != "current":
		return
	_time += delta
	queue_redraw()


## The outline of an arch: two jambs and a semicircular crown.
static func arch_points(rect: Rect2, steps: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := rect.size.x * 0.5
	var cx := rect.position.x + r
	var spring := rect.position.y + r
	pts.append(Vector2(rect.position.x, rect.end.y))
	pts.append(Vector2(rect.position.x, spring))
	for i in range(steps + 1):
		var a := PI - float(i) / float(steps) * PI
		pts.append(Vector2(cx + cos(a) * r, spring - sin(a) * r))
	pts.append(Vector2(rect.end.x, rect.end.y))
	return pts


func _draw() -> void:
	var outer := Rect2(Vector2(4.0, 2.0), Vector2(SIZE.x - 8.0, SIZE.y - 34.0))
	var inner := Rect2(outer.position + Vector2(FRAME, FRAME),
		outer.size - Vector2(FRAME * 2.0, FRAME))

	# The stone the door is cut into.
	draw_colored_polygon(arch_points(outer), Palette.STONE_HIGH)
	# ...lit along its own crown, so the frame has a thickness.
	draw_polyline(arch_points(outer), Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g,
		Palette.EDGE_LIGHT.b, 0.55), 2.0, true)

	# The opening. What is behind it is the whole state of the node: a walked
	# door is shut and dark, the one ahead of you is unlit, and the one you
	# are standing at has light coming out of it.
	var opening := arch_points(inner)
	# Not black. A dark opening is depth; a black one is a hole cut in the
	# screen, and the game has spent five rounds getting rid of those.
	# Only the door you stand at is allowed to wear its colour. The others
	# get a trace of it over stone: four saturated openings side by side is
	# four colours competing for a glance that has one thing to find.
	var strength := 0.30 if state == "current" else 0.07
	var beyond := Palette.VOID.lerp(accent, strength)
	draw_colored_polygon(opening, Color(beyond.r, beyond.g, beyond.b, 0.95))
	# A little of whatever is further in, pooling at the back of the opening.
	for i in 5:
		var t := float(i) / 4.0
		var deep := Rect2(inner.position + Vector2(inner.size.x * 0.30 * t, inner.size.x * 0.34 * t),
			inner.size - Vector2(inner.size.x * 0.60 * t, inner.size.x * 0.34 * t))
		if deep.size.x > 3.0:
			draw_colored_polygon(arch_points(deep),
				Color(accent.r, accent.g, accent.b, 0.030 if state == "current" else 0.014))
	if state == "current":
		var breath := 0.80 + 0.20 * sin(_time * 2.0)
		# Light spilling out, brightest at the threshold.
		for i in 7:
			var t := float(i) / 6.0
			var lit := Rect2(inner.position + Vector2(inner.size.x * 0.5 * t, inner.size.x * 0.5 * t),
				inner.size - Vector2(inner.size.x * t, inner.size.x * 0.5 * t))
			if lit.size.x <= 2.0:
				continue
			draw_colored_polygon(arch_points(lit),
				Color(accent.r, accent.g, accent.b, 0.06 * breath))
		draw_polyline(opening, Color(accent.r, accent.g, accent.b, 0.9 * breath), 2.0, true)
		# The pool it throws onto the corridor floor.
		for i in 6:
			var t := float(i) / 5.0
			draw_rect(Rect2(Vector2(inner.position.x - 6.0 * t, outer.end.y + t * 5.0),
				Vector2(inner.size.x + 12.0 * t, 5.0)),
				Color(accent.r, accent.g, accent.b, 0.07 * (1.0 - t) * breath))
	elif state == "done":
		# Boarded up behind you: horizontal bars across the opening.
		for i in 4:
			var y := inner.position.y + inner.size.y * (0.30 + float(i) * 0.19)
			draw_rect(Rect2(Vector2(inner.position.x + 2.0, y), Vector2(inner.size.x - 4.0, 3.0)),
				Color(Palette.STONE_EDGE.r, Palette.STONE_EDGE.g, Palette.STONE_EDGE.b, 0.5))
		draw_polyline(opening, Color(Palette.STONE_EDGE.r, Palette.STONE_EDGE.g,
			Palette.STONE_EDGE.b, 0.4), 1.0, true)
	else:
		draw_polyline(opening, Color(Palette.STONE_EDGE.r, Palette.STONE_EDGE.g,
			Palette.STONE_EDGE.b, 0.6), 1.5, true)
