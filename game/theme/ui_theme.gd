class_name UiTheme
extends RefCounted
## The game's Theme, built in code rather than authored as a .tres so it
## reviews as a diff. Icon-and-typography aesthetic (spec §9): a display
## serif for titles, a humanist sans for body and numbers -- both under the
## SIL Open Font License, see ATTRIBUTION.md.
##
## A missing font file is survivable: the loaders return null and Godot
## falls back to its own face rather than the game refusing to start.

const BODY_FONT_PATH := "res://assets/fonts/Inter.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/Cinzel.ttf"

static var _body_font: Font = null
static var _title_font: Font = null
static var _fonts_tried: bool = false

## Real scale contrast. Everything used to be within a few points of body
## size, which flattened the hierarchy: a screen title and a caption looked
## like the same thing.
const FONT_SMALL := 12
const FONT_BODY := 15
const FONT_NUMBER := 26
const FONT_TITLE := 38


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

	t.set_stylebox("panel", "PanelContainer", panel_box(Palette.STONE_RAISED))
	t.set_stylebox("panel", "Panel", panel_box(Palette.STONE))

	t.set_stylebox("normal", "Button", panel_box(Palette.STONE_HIGH))
	# Warm, not cyan. Under the light model an interactive thing lights up
	# like the lanterns do; ghost cyan belongs to the dead and to nothing else,
	# and a button borrowing it was the game's brightest colour competing with
	# its subject.
	t.set_stylebox("hover", "Button", lit_box(Palette.STONE_EDGE, Palette.EDGE_LIGHT))
	t.set_stylebox("pressed", "Button", panel_box(Palette.STONE, Palette.STONE_EDGE))
	var off := panel_box(Palette.STONE, Palette.STONE_RAISED)
	off.shadow_size = 0
	t.set_stylebox("disabled", "Button", off)
	t.set_color("font_color", "Button", Palette.BONE)
	t.set_color("font_hover_color", "Button", Palette.LANTERN)
	t.set_color("font_disabled_color", "Button", Palette.BONE_FAINT)
	t.set_font_size("font_size", "Button", FONT_BODY)
	t.set_constant("outline_size", "Label", 0)

	t.set_color("font_color", "TabBar", Palette.BONE_DIM)
	t.set_color("font_selected_color", "TabBar", Palette.BONE)
	return t


## A raised surface. Two things make a rectangle read as an object rather
## than as a hole: a lit top edge, and a border darker than the fill on the
## other three sides. Godot's StyleBoxFlat can do exactly that with an
## asymmetric border, so every panel in the game gets it for free.
static func panel_box(bg: Color, border: Color = Palette.STONE_EDGE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.border_color = border
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0.0, 3.0)
	return sb


## A surface that is being pressed, hovered or selected: brighter fill, an
## accent border, and the shadow pulled in so it reads as closer to the page.
static func lit_box(bg: Color, accent: Color) -> StyleBoxFlat:
	var sb := panel_box(bg, accent)
	sb.border_width_top = 2
	sb.shadow_size = 10
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.20)
	sb.shadow_offset = Vector2.ZERO
	return sb


## A card. Tighter margins than a screen panel, a heavier lit edge, and a
## deeper shadow -- a card should read as a physical object lying on top of
## everything else.
## The card's frame. CardView paints the lit-to-shadow face over it.
static func card_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_top = 3
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(9)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0.0, 5.0)
	return sb


## A list row: the panel look, but with the vertical padding cut so a
## screenful of them fits a screen.
static func row_box(bg: Color) -> StyleBoxFlat:
	var sb := panel_box(bg)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.shadow_size = 3
	return sb


## A bar across the window: flat top, no corner rounding, no shadow. Used
## for the navigation, which should read as part of the frame rather than
## as a panel floating on it.
static func bar_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.STONE
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(4)
	return sb


## The primary action on a screen: Descend, Push deeper, End turn. Lifted,
## saturated and edged in the accent so the eye finds it without reading it.
## Using one button style for the primary action, the bail-out and a plain
## catalogue row is the loudest "unfinished" tell a UI can have.
static func primary_box(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.30, accent.g * 0.26, accent.b * 0.34, 1.0)
	sb.border_color = accent
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	sb.shadow_size = 8
	return sb


## A catalogue row -- a shop item, an upgrade. No fill, no border, just a
## rule underneath. A list of forty identical buttons reads as a settings
## menu; a list of rows reads as a catalogue.
static func list_row_box(hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.STONE_RAISED if hovered else Color(0, 0, 0, 0)
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
	sb.set_corner_radius_all(2)
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
