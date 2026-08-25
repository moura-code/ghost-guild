class_name UiTheme
extends RefCounted
## The game's Theme, built in code rather than authored as a .tres so it
## reviews as a diff. Icon-and-typography aesthetic (spec §9): a display
## serif for titles, a humanist sans for body and numbers -- both under the
## SIL Open Font License, see ATTRIBUTION.md.
##
## A missing font file is survivable: the loaders return null and Godot
## falls back to its own face rather than the game refusing to start.

## Pixel fonts, imported with antialiasing and subpixel positioning off. A
## vector face rendered into a 640x360 viewport is the one thing that breaks
## the illusion hardest -- smooth glyphs sitting on hard pixels read as a
## screenshot of pixel art rather than as pixel art.
##
## Pixelify carries the body: measured against the game's longest card text
## it is as narrow as Inter was, which is what makes a 79px card still able
## to hold its rules. Silkscreen is wide and blocky and is the title voice.
const BODY_FONT_PATH := "res://assets/fonts/PixelifySans.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/Silkscreen.ttf"

static var _body_font: Font = null
static var _title_font: Font = null
static var _fonts_tried: bool = false

## Sizes are in 640x360 pixels, so they are half what they were and they land
## on whole numbers on purpose: a pixel font asked for a fractional size gets
## rounded somewhere and the glyphs stop lining up with the grid.
const FONT_SMALL := 6
const FONT_BODY := 8
const FONT_NUMBER := 16
const FONT_TITLE := 16


## Inter for everything a player reads as information.
static func body_font() -> Font:
	_load_fonts()
	return _body_font


## Cinzel for titles, epitaphs and the name of the dead.
static func title_font() -> Font:
	_load_fonts()
	return _title_font


static func _load_fonts() -> void:
	if _fonts_tried:
		return
	_fonts_tried = true
	if ResourceLoader.exists(BODY_FONT_PATH):
		_body_font = load(BODY_FONT_PATH) as Font
	if ResourceLoader.exists(TITLE_FONT_PATH):
		_title_font = load(TITLE_FONT_PATH) as Font


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	var body := body_font()
	if body != null:
		t.default_font = body
		t.set_font("font", "Label", body)
		t.set_font("font", "Button", body)
		t.set_font("font", "LineEdit", body)

	t.set_color("font_color", "Label", Palette.BONE)
	t.set_font_size("font_size", "Label", FONT_BODY)

	# Carved stone, not rounded rectangles. Everything the player touches is a
	# slab cut into the wall: a lit top edge because the lanterns are above, a
	# thickness you can see, a chiselled groove and four pegs.
	t.set_stylebox("panel", "PanelContainer", StoneBox.make(Palette.STONE_RAISED))
	t.set_stylebox("panel", "Panel", StoneBox.make(Palette.STONE, 3.0, false))

	var rest := StoneBox.make(Palette.STONE_HIGH, 5.0)
	rest.lit = Palette.STONE_EDGE
	t.set_stylebox("normal", "Button", rest)
	# Hover lights the slab warm, the way a lantern would. Ghost cyan belongs
	# to the dead and to nothing else, and a button borrowing it was the
	# game's brightest colour competing with its own subject.
	var hover := StoneBox.make(Palette.STONE_EDGE, 5.0)
	hover.accent = Color(Palette.EDGE_LIGHT.r, Palette.EDGE_LIGHT.g, Palette.EDGE_LIGHT.b, 0.65)
	t.set_stylebox("hover", "Button", hover)
	# Pushed into the wall: the bevel inverts, so the light is underneath.
	var down := StoneBox.make(Palette.STONE, 5.0)
	down.pressed = true
	t.set_stylebox("pressed", "Button", down)
	var off := StoneBox.make(Palette.STONE, 3.0, false)
	off.lit = Palette.STONE_EDGE
	t.set_stylebox("disabled", "Button", off)
	t.set_color("font_color", "Button", Palette.BONE)
	t.set_color("font_hover_color", "Button", Palette.LANTERN)
	t.set_color("font_disabled_color", "Button", Palette.BONE_FAINT)
	t.set_font_size("font_size", "Button", FONT_BODY)
	t.set_constant("outline_size", "Label", 0)

	# Scrollbars. A stock scrollbar is the loudest remaining "this is an app"
	# signal on any screen long enough to need one: a carved groove with a
	# stone grip in it reads as part of the wall.
	var trough := StoneBox.make(Palette.ABYSS, 2.0, false)
	trough.pressed = true
	trough.lit = Palette.STONE_HIGH
	trough.set_content_margin_all(0)
	var grip := StoneBox.make(Palette.STONE_HIGH, 3.0, false)
	grip.lit = Palette.STONE_EDGE
	grip.set_content_margin_all(0)
	var grip_lit := StoneBox.make(Palette.STONE_EDGE, 3.0, false)
	grip_lit.lit = Palette.EDGE_LIGHT
	grip_lit.set_content_margin_all(0)
	for axis in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", axis, trough)
		t.set_stylebox("grabber", axis, grip)
		t.set_stylebox("grabber_highlight", axis, grip_lit)
		t.set_stylebox("grabber_pressed", axis, grip_lit)

	t.set_color("font_color", "TabBar", Palette.BONE_DIM)
	t.set_color("font_selected_color", "TabBar", Palette.BONE)
	return t


## A raised surface, carved into the wall.
##
## This was a StyleBoxFlat with a 4px corner radius and a hairline border --
## which is to say, it was the look of a settings menu. Everything the player
## reads sits on one of these, so it is the single highest-leverage shape in
## the game: making it carved changes every screen at once.
static func panel_box(bg: Color, border: Color = Palette.STONE_EDGE) -> StoneBox:
	var box := StoneBox.make(bg, 4.0)
	# Structure is stone; only the things you touch catch the lantern. Lighting
	# every panel's chamfer with EDGE_LIGHT put a gold line along the top of
	# every element on screen, which read as gold-bordered boxes rather than as
	# carved rock and left nothing for a button to stand out against.
	box.lit = Palette.STONE_EDGE
	box.shade = Color(Palette.ABYSS.r, Palette.ABYSS.g, Palette.ABYSS.b, 0.9)
	box.groove = border
	box.set_content_margin_all(11)
	return box


## A surface being hovered, pressed or selected. Same carving, plus a warm
## hairline just inside the groove -- the light catching an edge, rather than
## a different-coloured border, which is what a form control does.
static func lit_box(bg: Color, accent: Color) -> StoneBox:
	var box := panel_box(bg, accent)
	box.accent = Color(accent.r, accent.g, accent.b, 0.75)
	return box


## A card: a thin stone tablet. Tighter margins than a screen panel and no
## pegs -- at 158px wide four rivets crowd the art slot -- but the same
## carved bevel, so a card in the hand and a plaque on the wall read as the
## same material.
static func card_box(bg: Color, border: Color) -> StoneBox:
	var box := StoneBox.make(bg, 2.0, false)
	box.lit = Palette.STONE_EDGE
	box.groove = border
	box.set_content_margin_all(4)
	return box


## A list row: the panel look, but with the vertical padding cut so a
## screenful of them fits a screen.
static func row_box(bg: Color) -> StoneBox:
	var box := StoneBox.make(bg, 3.0, false)
	box.lit = Palette.STONE_EDGE
	box.set_content_margin_all(9)
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


## A bar across the window: flat top, no corner rounding, no shadow. Used
## for the navigation, which should read as part of the frame rather than
## as a panel floating on it.
static func bar_box() -> StoneBox:
	var box := StoneBox.make(Palette.STONE, 3.0, false)
	box.lit = Palette.STONE_EDGE
	box.set_content_margin_all(4)
	return box


## The primary action on a screen: Descend, Push deeper, End turn. Lifted,
## saturated and edged in the accent so the eye finds it without reading it.
## Using one button style for the primary action, the bail-out and a plain
## catalogue row is the loudest "unfinished" tell a UI can have.
static func primary_box(accent: Color) -> StoneBox:
	var box := StoneBox.make(
		Color(accent.r * 0.30, accent.g * 0.26, accent.b * 0.34, 1.0), 5.0)
	# The accent lights the carved edge itself rather than outlining the
	# shape: this is the slab the lantern is pointed at.
	box.lit = Color(accent.r, accent.g, accent.b, 0.85)
	box.accent = Color(accent.r, accent.g, accent.b, 0.55)
	box.groove = Palette.ABYSS
	box.set_content_margin_all(11)
	return box


## A catalogue row -- a shop item, an upgrade. No fill, no border, just a
## rule underneath. A list of forty identical buttons reads as a settings
## menu; a list of rows reads as a catalogue.
static func list_row_box(hovered: bool = false) -> StyleBox:
	if hovered:
		var box := StoneBox.make(Palette.STONE_RAISED, 3.0, false)
		box.set_content_margin_all(9)
		box.content_margin_left = 14
		return box
	# At rest a catalogue row is a rule, not a slab. Forty carved plaques
	# stacked in a list is noise; the carving is what marks the one under
	# the cursor.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(Palette.STONE_EDGE.r, Palette.STONE_EDGE.g, Palette.STONE_EDGE.b, 0.45)
	sb.border_width_bottom = 1
	sb.set_content_margin_all(9)
	sb.content_margin_left = 14
	return sb


## A small round chip: cost bubbles, counters, pips.
static func pip_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(15)
	sb.set_content_margin_all(2)
	return sb


## A flat block of colour with no border -- fills, bands and bars.
static func fill_box(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	return sb


## Draws a health bar into `on`, at `rect`, `frac` full in `colour`, with
## `shield` worth of block stacked after it.
##
## The fill used to be the colour at 34% brightness on a near-black trough,
## which meant a hero at 70/70 had a bar that read as empty -- the player is
## told they are about to die when they are untouched. It is lit at the top
## and falls away below, like every other solid in the game.
static func draw_health(on: CanvasItem, rect: Rect2, frac: float, colour: Color,
		shield: float = 0.0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	on.draw_rect(rect, Palette.VOID)
	var w := rect.size.x * clampf(frac, 0.0, 1.0)
	var h := rect.size.y
	if w > 0.0:
		var bands := 6
		for i in bands:
			var t := float(i) / float(bands - 1)
			var lit := 1.05 - t * 0.60
			on.draw_rect(Rect2(rect.position + Vector2(0.0, h * t / float(bands) * float(bands)),
				Vector2(w, h / float(bands) + 0.6)),
				Color(minf(colour.r * lit, 1.0), minf(colour.g * lit, 1.0),
					minf(colour.b * lit, 1.0), 1.0))
		# The lit lip along the top, and a shadow where the fill ends.
		on.draw_rect(Rect2(rect.position, Vector2(w, 1.0)),
			Color(1.0, 1.0, 1.0, 0.45))
		if frac < 0.999:
			on.draw_rect(Rect2(rect.position + Vector2(w - 1.0, 0.0), Vector2(1.0, h)),
				Color(0.0, 0.0, 0.0, 0.55))
	if shield > 0.0:
		var sw := rect.size.x * clampf(shield, 0.0, 1.0 - clampf(frac, 0.0, 1.0))
		on.draw_rect(Rect2(rect.position + Vector2(w, 0.0), Vector2(sw, h)),
			Color(Palette.SOUL.r * 0.75, Palette.SOUL.g * 0.75, Palette.SOUL.b * 0.75, 1.0))
		on.draw_rect(Rect2(rect.position + Vector2(w, 0.0), Vector2(sw, 1.0)), Palette.SOUL)
	on.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), Color(0.0, 0.0, 0.0, 0.7))


static func title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_TITLE)
	l.add_theme_color_override("font_color", Palette.BONE)
	var face := title_font()
	if face != null:
		l.add_theme_font_override("font", face)
	return l


static func body(text: String, colour: Color = Palette.BONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_BODY)
	l.add_theme_color_override("font_color", colour)
	return l


static func small(text: String, colour: Color = Palette.BONE_DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_SMALL)
	l.add_theme_color_override("font_color", colour)
	return l


static func number(text: String, colour: Color = Palette.SOUL) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_NUMBER)
	l.add_theme_color_override("font_color", colour)
	return l
