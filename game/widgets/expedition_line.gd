class_name ExpeditionLine
extends PanelContainer
## One expedition slot in the Guild (spec §3.5): who is in the field, how deep
## they went and how long until they take the watch -- or, when the slot is
## empty, the button that sends somebody.
##
## A widget: it renders the state it is given and reports the click through a
## signal. It is re-bound with the current time rather than reading a clock of
## its own, which is what keeps every panel in the game on the same second and
## makes the countdown testable without waiting for it.
##
## One line, and the same line in both states. The first version stacked the
## name over the countdown and gave the empty slot a full-width button, which
## made the two states different heights and the band twice as tall as the
## thing it was reporting on.

signal send_pressed()

## Pinned rather than left to the content, because the Send button is a
## couple of pixels taller than a line of text and the band would twitch every
## time a slot filled. At least as tall as the button, or the pin does
## nothing -- which is what `test_both_states_are_the_same_row` is guarding.
const HEIGHT := 23.0
const MARK_SIZE := Vector2(9.0, 12.0)
const BAR_SIZE := Vector2(56.0, 3.0)
const TIME_WIDTH := 46.0

var _mark: GhostMark
var _name: Label
var _detail: Label
var _send: Button
var _bar: Control
var _progress: float = 0.0


func _init() -> void:
	_build()


func _build() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	add_theme_stylebox_override("panel", UiTheme.list_row_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	# Faded rather than hidden on an empty slot: an invisible child is
	# dropped from the row entirely, and then the two states do not line up.
	_mark = GhostMark.new()
	_mark.custom_minimum_size = MARK_SIZE
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_mark)

	_name = UiTheme.body("")
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_name)

	# The wait, drawn. The countdown answers "how long"; the bar is the part
	# you can see move without reading it, and this is a screen the player
	# leaves open while they decide what to buy.
	_bar = Control.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(_draw_bar)
	row.add_child(_bar)

	_detail = UiTheme.small("", Palette.BONE_DIM)
	_detail.custom_minimum_size = Vector2(TIME_WIDTH, 0.0)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_detail)

	# A price-chip of a button, not a call to action: the section heading
	# already said what this band is, and a full-width primary button here
	# was the loudest thing on a screen full of things to buy.
	var box := UiTheme.primary_box(Palette.GHOST)
	box.set_content_margin_all(2)
	_send = Button.new()
	_send.add_theme_stylebox_override("normal", box)
	_send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_send.pressed.connect(func() -> void: send_pressed.emit())
	row.add_child(_send)


## A visible empty track, not a groove: at zero progress a bar drawn in the
## panel's own shadow colour is indistinguishable from a scratch on the stone,
## and zero is the state it starts every expedition in.
func _draw_bar() -> void:
	_bar.draw_rect(Rect2(Vector2.ZERO, _bar.size), Palette.STONE_HIGH)
	_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(_bar.size.x * _progress, _bar.size.y)),
		Palette.GHOST)


## `e == null` is an open slot. One entry point for both states, because a
## slot that fills and empties as the clock runs should not be two widgets
## that have to agree with each other about how a row looks.
func bind(content: Content, e: Expedition, now: int) -> void:
	var open := e == null
	_mark.modulate.a = 0.0 if open else 1.0
	_bar.visible = not open
	_detail.visible = not open
	_send.visible = open
	# An open slot recedes: the one in the field is what the player came to
	# look at, and two rows of equal weight make neither of them the subject.
	_name.add_theme_color_override("font_color", Palette.BONE_DIM if open else Palette.BONE)
	if open:
		_progress = 0.0
		_name.text = content.text("ui.expedition.none")
		_send.text = content.text("ui.expedition.send")
		tooltip_text = ""
		return
	_progress = e.progress(now)
	_mark.bind(e.ghost)
	_name.text = content.text("ui.expedition.away") \
		.replace("{name}", e.ghost.name).replace("{floor}", str(e.ghost.floor))
	_detail.text = Num.countdown(e.remaining(now))
	# The countdown reads as a number next to a bar, which is unambiguous but
	# says nothing about what happens at zero. The sentence lives on the
	# tooltip, the way the fine print on an upgrade tablet does.
	tooltip_text = content.text("ui.expedition.returns").replace("{time}", _detail.text)
	_bar.queue_redraw()
