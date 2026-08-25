class_name Prop
extends Control
## Drawn decor: candles, chains, bones, banners, a ritual circle, rubble,
## cobwebs and skulls. No art, one `_draw` each.
##
## These exist because the review that produced the visual overhaul found the
## same fault on half the screens: a small island of content floating in a
## large empty field. The Séance was a black box with two numbers in the
## corner; the Hero screen was a stock pictogram over a text list. Empty
## space is not composition, and a game that leaves 60% of the frame blank
## reads as unfinished no matter how good the palette is.
##
## Every prop is a Control so it can be positioned by a container, animated
## on its own phase, and asserted on by a test. Scatter is deterministic from
## a seed -- no engine randomness -- so the same frame screenshots the same
## twice, which is the whole basis of the look-at-it loop.

enum Kind { CANDLE, CHAIN, BONES, BANNER, CIRCLE, RUBBLE, COBWEB, SKULL }

## A flame may gutter but never go out: a light that drops to nothing reads
## as a rendering fault rather than as a draught.
const FLAME_MIN := 0.72

var kind: int = Kind.CANDLE
var tint: Color = Palette.LANTERN
var seed_value: int = 0

var _time: float = 0.0
var _scatter: Array[Vector2] = []
var _scatter_for: Vector2 = Vector2(-1.0, -1.0)


static func of(prop_kind: int, prop_seed: int = 0) -> Prop:
	var p := Prop.new()
	p.kind = prop_kind
	p.seed_value = prop_seed
	p.tint = _default_tint(prop_kind)
	p.custom_minimum_size = _default_size(prop_kind)
	p.size = p.custom_minimum_size
	return p


static func _default_tint(prop_kind: int) -> Color:
	match prop_kind:
		Kind.CANDLE:
			return Palette.LANTERN
		Kind.BONES, Kind.SKULL:
			return Palette.BONE_DIM
		Kind.BANNER:
			return Palette.STONE_HIGH
		Kind.CIRCLE:
			return Palette.GHOST
		Kind.COBWEB:
			return Palette.BONE_FAINT
	return Palette.STONE_EDGE


static func _default_size(prop_kind: int) -> Vector2:
	match prop_kind:
		Kind.CANDLE:
			return Vector2(18.0, 52.0)
		Kind.CHAIN:
			return Vector2(10.0, 110.0)
		Kind.BONES:
			return Vector2(96.0, 34.0)
		Kind.BANNER:
			return Vector2(64.0, 150.0)
		Kind.CIRCLE:
			return Vector2(260.0, 260.0)
		Kind.RUBBLE:
			return Vector2(140.0, 26.0)
		Kind.COBWEB:
			return Vector2(70.0, 70.0)
	return Vector2(26.0, 30.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Decor never stretches. A VBox or HBox fills its children by default,
	# which turned an 18px candle into a 140px one and its halo into a grey
	# disc the size of the screen -- props have proportions and a container
	# is not entitled to them.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _process(delta: float) -> void:
	# Only the things that move ask for a frame.
	if kind == Kind.CANDLE or kind == Kind.CIRCLE:
		advance(delta)


func advance(delta: float) -> void:
	_time += delta
	queue_redraw()


## How brightly the flame is burning, 0 to 1. Deterministic, and driven by
## the same three-incommensurate-sines trick as the room's lantern so the
## candles and the walls breathe together instead of fighting.
func flame() -> float:
	var t := _time + float(seed_value) * 1.37
	var wave := sin(t * 3.1) * 0.5 + sin(t * 7.3 + 0.9) * 0.3 + sin(t * 13.1 + 2.2) * 0.2
	return clampf(1.0 - (1.0 - FLAME_MIN) * 0.5 * (1.0 - wave), FLAME_MIN, 1.0)


## Where the pieces of a scattered prop sit, in local coordinates. Cached
## per size, recomputed when the prop is resized.
func scatter() -> Array[Vector2]:
	if size.x <= 0.0 or size.y <= 0.0:
		return []
	if _scatter_for == size and not _scatter.is_empty():
		return _scatter
	var count := 7 if kind == Kind.BONES else 11
	var points: Array[Vector2] = []
	for i in count:
		# Deterministic and evenly spread: the index walks across the box and
		# the hash only jitters it, so a scatter never clumps into one corner
		# the way pure noise does.
		var along := (float(i) + 0.5) / float(count)
		var jitter_x := (_hash(i * 2 + 1) - 0.5) * 0.6 / float(count)
		var jitter_y := _hash(i * 2 + 2)
		var at := Vector2(clampf(along + jitter_x, 0.0, 1.0) * size.x, jitter_y * size.y)
		points.append(Vector2(clampf(at.x, 0.0, size.x), clampf(at.y, 0.0, size.y)))
	_scatter = points
	_scatter_for = size
	return _scatter


## No engine randomness: props must lay out identically every run so the
## contact sheet is comparable frame to frame.
func _hash(n: int) -> float:
	var h := float(sin(float(n) * 127.1 + float(seed_value) * 311.7) * 43758.5453)
	return h - floorf(h)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	match kind:
		Kind.CANDLE:
			_draw_candle()
		Kind.CHAIN:
			_draw_chain()
		Kind.BONES:
			_draw_bones()
		Kind.BANNER:
			_draw_banner()
		Kind.CIRCLE:
			_draw_circle_rite()
		Kind.RUBBLE:
			_draw_rubble()
		Kind.COBWEB:
			_draw_cobweb()
		Kind.SKULL:
			_draw_skull()


## A stub of wax, a wick, a flame, and the pool of light it throws. The
## light is the point: a candle that does not light anything is a drawing of
## a candle.
func _draw_candle() -> void:
	var lit := flame()
	var body := Rect2(Vector2(size.x * 0.28, size.y * 0.42),
		Vector2(size.x * 0.44, size.y * 0.58))
	draw_rect(body, Palette.BONE_DIM)
	draw_rect(Rect2(body.position, Vector2(body.size.x * 0.32, body.size.y)),
		Color(Palette.BONE.r, Palette.BONE.g, Palette.BONE.b, 0.35))
	# Molten lip.
	draw_rect(Rect2(body.position - Vector2(1.0, 2.0), Vector2(body.size.x + 2.0, 3.0)),
		Palette.BONE)

	var tip := Vector2(size.x * 0.5, size.y * 0.42)
	draw_line(tip, tip - Vector2(0.0, size.y * 0.06), Palette.ABYSS, 1.5)
	# The flame, as three stacked ellipses of falling opacity.
	for i in 3:
		var f := float(i)
		var radius := (size.x * 0.20 - f * size.x * 0.05) * lit
		var at := tip - Vector2(0.0, size.y * 0.10 + f * size.y * 0.035)
		draw_circle(at, maxf(0.6, radius),
			Color(tint.r, tint.g, tint.b, (0.95 - f * 0.22) * lit))
	# The halo it casts. Layered rather than one circle: draw_circle has a
	# hard edge, and a single flat disc at low alpha reads as a grey plate
	# sitting behind the candle instead of as light in the air.
	var halo_at := tip - Vector2(0.0, size.y * 0.12)
	var halo := size.y * 0.62 * lit
	for i in 5:
		var f := float(i) / 4.0
		draw_circle(halo_at, halo * (0.35 + f * 0.65),
			Color(tint.r, tint.g, tint.b, 0.030 * (1.0 - f) * lit))


func _draw_chain() -> void:
	var links := int(size.y / 11.0)
	for i in links:
		var y := float(i) * 11.0
		var wide := i % 2 == 0
		var w := size.x * (0.9 if wide else 0.45)
		var link := Rect2(Vector2((size.x - w) * 0.5, y), Vector2(w, 9.0))
		draw_rect(link, tint, false, 1.6)
		# A lit top edge, which is what turns an outline into a solid.
		draw_line(link.position, link.position + Vector2(link.size.x, 0.0),
			Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g, Palette.EDGE_LIGHT.b, 0.5), 1.0)


func _draw_bones() -> void:
	for at in scatter():
		var length := size.x * 0.13
		var angle := _hash(int(at.x) + 5) * PI
		var arm := Vector2(cos(angle), sin(angle)) * length * 0.5
		draw_line(at - arm, at + arm, tint, 2.4)
		# Knuckles at both ends -- what makes a line read as a bone.
		draw_circle(at - arm, 2.0, tint)
		draw_circle(at + arm, 2.0, tint)


func _draw_banner() -> void:
	var cloth := Rect2(Vector2.ZERO, size)
	draw_rect(cloth, tint)
	# A lit left edge and a shadowed right one: cloth hanging in side light.
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * 0.18, size.y)),
		Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g, Palette.EDGE_LIGHT.b, 0.16))
	draw_rect(Rect2(Vector2(size.x * 0.72, 0.0), Vector2(size.x * 0.28, size.y)),
		Color(0.0, 0.0, 0.0, 0.28))
	# The swallowtail hem.
	var hem := size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, hem), Vector2(size.x * 0.5, hem - size.y * 0.12),
		Vector2(size.x, hem), Vector2(size.x, hem + 1.0), Vector2(0.0, hem + 1.0)]),
		Palette.STONE)


## The Séance's ritual circle: two rings and a ring of marks, breathing.
func _draw_circle_rite() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	var breath := 0.55 + 0.45 * (sin(_time * 1.1) * 0.5 + 0.5)
	draw_arc(centre, radius, 0.0, TAU, 96,
		Color(tint.r, tint.g, tint.b, 0.20 * breath), 1.5)
	draw_arc(centre, radius * 0.86, 0.0, TAU, 96,
		Color(tint.r, tint.g, tint.b, 0.11 * breath), 1.0)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(centre + dir * radius * 0.88, centre + dir * radius * 0.98,
			Color(tint.r, tint.g, tint.b, 0.28 * breath), 1.5)


## Broken stone on the floor. Irregular quads, not rectangles: axis-aligned
## boxes in a mid grey read as UI artifacts floating over the screen rather
## than as debris lying on it, which is exactly how the first version looked.
## Dark, with one lit top edge each -- the light is above, so only the top
## face of a chip catches it.
func _draw_rubble() -> void:
	for at in scatter():
		var w := size.x * 0.030 + _hash(int(at.x) + 11) * size.x * 0.030
		var h := w * (0.34 + _hash(int(at.x) + 13) * 0.30)
		var lean := (_hash(int(at.x) + 17) - 0.5) * w * 0.45
		var top_left := at + Vector2(-w * 0.5 + lean, -h * 0.5)
		var top_right := at + Vector2(w * 0.5 + lean * 0.4, -h * 0.5 - h * 0.15)
		draw_colored_polygon(PackedVector2Array([
			top_left, top_right,
			at + Vector2(w * 0.5, h * 0.5),
			at + Vector2(-w * 0.5, h * 0.5)]),
			Color(Palette.STONE_RAISED.r, Palette.STONE_RAISED.g, Palette.STONE_RAISED.b, 0.9))
		draw_line(top_left, top_right,
			Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g, Palette.EDGE_LIGHT.b, 0.22), 1.0)


func _draw_cobweb() -> void:
	var strands := 5
	for i in strands + 1:
		var angle := (PI * 0.5) * float(i) / float(strands)
		draw_line(Vector2.ZERO,
			Vector2(cos(angle), sin(angle)) * size.length(),
			Color(tint.r, tint.g, tint.b, 0.22), 1.0)
	for ring in range(1, 4):
		var r := minf(size.x, size.y) * float(ring) / 3.5
		draw_arc(Vector2.ZERO, r, 0.0, PI * 0.5, 20,
			Color(tint.r, tint.g, tint.b, 0.16), 1.0)


## Drawn inside a square derived from the shorter side, so a skull handed a
## wide box stays a skull rather than becoming a letterbox with two holes in
## it. Everything below is relative to `box`, never to `size`.
func _draw_skull() -> void:
	var side := minf(size.x, size.y)
	var box := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var cranium := Rect2(box.position + Vector2(side * 0.14, side * 0.06),
		Vector2(side * 0.72, side * 0.60))
	draw_rect(cranium, tint)
	# A domed top: three narrowing bands, which reads as a curve at this size
	# without needing a polygon.
	for i in 3:
		var f := float(i) + 1.0
		draw_rect(Rect2(cranium.position + Vector2(side * 0.03 * f, -side * 0.02 * f),
			Vector2(cranium.size.x - side * 0.06 * f, side * 0.03)), tint)
	# Jaw, narrower than the cranium.
	draw_rect(Rect2(box.position + Vector2(side * 0.30, side * 0.64),
		Vector2(side * 0.40, side * 0.18)), tint)
	# Teeth: a dark line across the jaw. Without it the jaw is a second box.
	draw_rect(Rect2(box.position + Vector2(side * 0.30, side * 0.64),
		Vector2(side * 0.40, side * 0.02)), Palette.ABYSS)
	# Sockets. Black, not dark: they are holes.
	var socket := Vector2(side * 0.20, side * 0.19)
	draw_rect(Rect2(box.position + Vector2(side * 0.21, side * 0.22), socket), Palette.ABYSS)
	draw_rect(Rect2(box.position + Vector2(side * 0.59, side * 0.22), socket), Palette.ABYSS)
	# Nasal cavity.
	draw_rect(Rect2(box.position + Vector2(side * 0.45, side * 0.46),
		Vector2(side * 0.10, side * 0.12)), Palette.ABYSS)
