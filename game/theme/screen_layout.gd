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
