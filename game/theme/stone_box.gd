class_name StoneBox
extends StyleBox
## Carved stone furniture: the frame every panel, row and button in the game
## sits in.
##
## Everything used to be a `StyleBoxFlat` -- a rounded rectangle with a
## hairline border and a flat fill. That is what a UI toolkit looks like, and
## it is why the game read as a settings menu with good art in it rather than
## as a game. A rounded corner is the single most recognisable app signal
## there is; carved stone has corners, and it has a thickness you can see.
##
## What this draws, from the outside in:
##
##   a lit top and left edge, because the lanterns are above and the room's
##   light falls from there; a shadowed bottom and right edge, so the slab
##   has a thickness; a chiselled groove inside that, which is the cut a
##   mason's tool leaves; the face itself; and four corner pegs, which are
##   the detail that stops a rectangle reading as a rectangle.
##
## `pressed` inverts the bevel. That is what makes a button read as having
## been pushed into the wall rather than merely recoloured -- the light moves
## to the bottom edge, which is what happens to a real thing you press.

## Thick enough to read as a carved edge rather than as a border. Below about
## 3px this is indistinguishable from the hairline it replaced.
## Two pixels at 640x360, which is four on screen. A carved edge needs to be
## a visible number of pixels and nothing more -- at this resolution a 4px
## bevel eats a quarter of a card.
const DEFAULT_BEVEL := 2.0
const PEG := 2.0

@export var fill: Color = Palette.STONE_RAISED
@export var lit: Color = Palette.EDGE_LIGHT
@export var shade: Color = Palette.ABYSS
@export var groove: Color = Palette.ABYSS
@export var bevel: float = DEFAULT_BEVEL
## Inverts the bevel: light below, shadow above.
@export var pressed: bool = false
## Corner pegs. Off for rows in a long list, where sixty of them is noise.
@export var pegs: bool = true
## An accent hairline just inside the groove -- used to mark a selected or
## affordable thing without changing its shape.
@export var accent: Color = Color(0, 0, 0, 0)


static func make(p_fill: Color, p_bevel: float = DEFAULT_BEVEL,
		p_pegs: bool = true) -> StoneBox:
	var box := StoneBox.new()
	box.fill = p_fill
	box.bevel = p_bevel
	box.pegs = p_pegs
	box.set_content_margin_all(maxf(6.0, p_bevel * 2.0))
	return box


## Content must not be drawn over the bevel: text sitting on the carved edge
## reads as falling off the plaque.
func _get_minimum_size() -> Vector2:
	var m := bevel * 2.0
	return Vector2(m, m)


func _draw(to: RID, rect: Rect2) -> void:
	# Godot hands a StyleBox whatever rect the container computed, which
	# mid-layout can be degenerate. A bevel wider than the box would draw its
	# own edges past each other.
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var b := minf(bevel, minf(rect.size.x, rect.size.y) * 0.5)
	if b <= 0.0:
		_rect(to, rect, fill)
		return

	# A chamfer, not an outline.
	#
	# The first version filled the whole bevel band with the lit colour at
	# full strength, which put a bright gold stripe along the top and left of
	# every element on the screen -- gold-bordered boxes, not carved stone.
	# A real chamfer is a gradient: one bright line right at the edge where
	# the light catches, then a face tilted a little toward the light, then
	# the flat of the slab. Same for the shadowed side, inverted.
	var up := shade if pressed else lit
	var down := lit if pressed else shade
	var top_face := fill.lerp(up, 0.24)
	var top_line := fill.lerp(up, 0.62)
	var bottom_face := fill.lerp(down, 0.45)
	var bottom_line := fill.lerp(down, 0.85)

	_rect(to, Rect2(rect.position, Vector2(rect.size.x, b)), top_face)
	_rect(to, Rect2(rect.position, Vector2(rect.size.x, 1.0)), top_line)
	_rect(to, Rect2(rect.position + Vector2(0.0, rect.size.y - b),
		Vector2(rect.size.x, b)), bottom_face)
	_rect(to, Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0),
		Vector2(rect.size.x, 1.0)), bottom_line)
	# The vertical faces catch less: light from above grazes them.
	_rect(to, Rect2(rect.position + Vector2(0.0, b), Vector2(b, rect.size.y - b * 2.0)),
		fill.lerp(up, 0.16))
	_rect(to, Rect2(rect.position + Vector2(rect.size.x - b, b),
		Vector2(b, rect.size.y - b * 2.0)), fill.lerp(down, 0.28))

	# The face.
	var face := Rect2(rect.position + Vector2(b, b), rect.size - Vector2(b, b) * 2.0)
	if face.size.x <= 0.0 or face.size.y <= 0.0:
		return
	_rect(to, face, fill)

	# The chiselled groove where the face meets the chamfer -- the cut a
	# mason's tool leaves. One dark line, not a border.
	_outline(to, face, Color(groove.r, groove.g, groove.b, 0.40), 1.0)
	if accent.a > 0.0:
		_outline(to, face.grow(-2.0), accent, 1.0)

	# Pegs. Small, in the corners of the face, lit on top like everything
	# else -- these are the detail that stops the eye reading "rectangle".
	if pegs and face.size.x > 45.0 and face.size.y > 23.0:
		var inset := PEG * 1.5
		var corners: Array[Vector2] = [Vector2(inset, inset),
			Vector2(face.size.x - inset - PEG, inset),
			Vector2(inset, face.size.y - inset - PEG),
			Vector2(face.size.x - inset - PEG, face.size.y - inset - PEG)]
		for corner in corners:
			var at := face.position + corner
			# A sunk rivet: a dark square with one lit top edge. At three
			# pixels this read as a stray dash in the corner, so it is
			# bigger and only drawn where there is room for it.
			_rect(to, Rect2(at, Vector2(PEG, PEG)), fill.lerp(shade, 0.75))
			_rect(to, Rect2(at, Vector2(PEG, 1.0)), fill.lerp(lit, 0.45))


func _rect(to: RID, at: Rect2, colour: Color) -> void:
	if at.size.x > 0.0 and at.size.y > 0.0:
		RenderingServer.canvas_item_add_rect(to, at, colour)


func _outline(to: RID, at: Rect2, colour: Color, width: float) -> void:
	_rect(to, Rect2(at.position, Vector2(at.size.x, width)), colour)
	_rect(to, Rect2(at.position + Vector2(0.0, at.size.y - width),
		Vector2(at.size.x, width)), colour)
	_rect(to, Rect2(at.position, Vector2(width, at.size.y)), colour)
	_rect(to, Rect2(at.position + Vector2(at.size.x - width, 0.0),
		Vector2(width, at.size.y)), colour)
