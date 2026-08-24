class_name ScreenLayout
extends RefCounted
## Shared composition for the panel screens.
##
## Every one of them was a VBoxContainer that sized to its content and sat
## in the top-left corner, leaving most of the window empty and stretching
## its rows the full 1280px. A column with a maximum width, centred
## horizontally, fixes all of them the same way — and keeps them looking
## like one game rather than six separate dialogs.

## Wide enough for a two-column row, narrow enough that a line of text is
## still comfortable to read.
const COLUMN_WIDTH := 720.0
const WIDE_COLUMN := 900.0


## Wraps `content` in a centred column of at most `width` and returns the
## wrapper, which is what gets added to the screen.
static func centred(content: Control, width: float = COLUMN_WIDTH) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(width, content.custom_minimum_size.y)
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(content)
	return row


## A label that centres itself, for the headings and captions these screens
## are full of.
static func centre(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A heading with an accent bar and a rule running out from it.
##
## A bare centred label left every panel screen reading as an unstyled list.
## A header treatment is what tells the eye a block was composed to be the
## size it is, rather than having simply run out of content.
static func section(text: String, accent: Color = Palette.SOUL) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(3.0, 17.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("panel", UiTheme.fill_box(accent))
	row.add_child(bar)
	row.add_child(UiTheme.body(text, Palette.BONE))
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.add_theme_stylebox_override("panel",
		UiTheme.fill_box(Color(accent.r, accent.g, accent.b, 0.20)))
	row.add_child(rule)
	return row


## Wraps content in a bounded, translucent slab.
##
## The panel screens were bare lists sitting straight on the crypt wall,
## which reads as a settings menu pasted over wallpaper. Giving the content
## a lid and a border makes it part of the room instead.
static func plate(content: Control, width: float = WIDE_COLUMN) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UiTheme.panel_box(Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.55),
			Palette.STONE_EDGE))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	panel.add_child(margin)
	return centred(panel, width)
