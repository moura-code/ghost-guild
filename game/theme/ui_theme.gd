class_name UiTheme
extends RefCounted
## The game's Theme, built in code rather than authored as a .tres so it
## reviews as a diff. Icon-and-typography aesthetic (spec §9): Godot's
## default font stands in until real faces are licensed.

const FONT_SMALL := 12
const FONT_BODY := 15
const FONT_NUMBER := 20
const FONT_TITLE := 26


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	t.set_color("font_color", "Label", Palette.BONE)
	t.set_font_size("font_size", "Label", FONT_BODY)

	t.set_stylebox("panel", "PanelContainer", panel_box(Palette.STONE_RAISED))
	t.set_stylebox("panel", "Panel", panel_box(Palette.STONE))

	t.set_stylebox("normal", "Button", panel_box(Palette.STONE_RAISED))
	t.set_stylebox("hover", "Button", panel_box(Palette.STONE_EDGE))
	t.set_stylebox("pressed", "Button", panel_box(Palette.STONE))
	t.set_stylebox("disabled", "Button", panel_box(Palette.STONE, Palette.STONE))
	t.set_color("font_color", "Button", Palette.BONE)
	t.set_color("font_hover_color", "Button", Palette.SOUL)
	t.set_color("font_disabled_color", "Button", Palette.BONE_FAINT)
	t.set_font_size("font_size", "Button", FONT_BODY)

	t.set_color("font_color", "TabBar", Palette.BONE_DIM)
	t.set_color("font_selected_color", "TabBar", Palette.BONE)
	return t


static func panel_box(bg: Color, border: Color = Palette.STONE_EDGE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8)
	return sb


## A flat block of colour with no border -- fills, bands and bars.
static func fill_box(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(2)
	return sb


static func title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_TITLE)
	l.add_theme_color_override("font_color", Palette.BONE)
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
