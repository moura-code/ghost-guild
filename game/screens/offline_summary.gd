class_name OfflineSummary
extends Control
## "While you were away" (spec §5.8). Shown once on load when the ghosts
## earned something worth reporting. A capped return always shows, because
## the cap is the reason to buy Night Watch and hiding it reads as a bug.
##
## A modal over the whole window, not a band in the layout. It used to be a
## sibling of the screens, so showing it squeezed everything above it into
## the remaining space -- on the fight that pushed the hand up over the
## enemies -- and it read as a docked panel rather than as something to
## dismiss.

signal dismissed()

const MIN_SECONDS := 60
const MIN_SOUL := 1.0

var _title: Label
var _away: Label
var _earned: Label
var _capped: Label
var _button: Button


func _init() -> void:
	_build()


## Worth interrupting the player for? A blink is not; a capped night is,
## even if the ladder was empty and earned nothing.
static func should_show(offline: Dictionary) -> bool:
	if bool(offline.get("capped", false)):
		return true
	var counted := int(offline.get("counted", 0))
	var soul := float(offline.get("soul", 0.0))
	return counted >= MIN_SECONDS and soul >= MIN_SOUL


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Centred card, sized to itself rather than to the window.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460.0, 0.0)
	card.add_theme_stylebox_override("panel",
		UiTheme.panel_box(Palette.STONE, Palette.STONE_EDGE))
	centre.add_child(card)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_right", 26)
	pad.add_theme_constant_override("margin_top", 22)
	pad.add_theme_constant_override("margin_bottom", 22)
	card.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pad.add_child(box)

	_title = ScreenLayout.centre(UiTheme.title(""))
	box.add_child(_title)
	_away = ScreenLayout.centre(UiTheme.small(""))
	box.add_child(_away)
	var earned_row := HBoxContainer.new()
	earned_row.alignment = BoxContainer.ALIGNMENT_CENTER
	earned_row.add_theme_constant_override("separation", 8)
	earned_row.add_child(Icons.make_rect(Icons.ui("soul"), 26.0, Palette.SOUL))
	_earned = UiTheme.number("0")
	earned_row.add_child(_earned)
	box.add_child(earned_row)
	_capped = ScreenLayout.centre(UiTheme.small("", Palette.PREPARED))
	_capped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_capped)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(200.0, 42.0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.SOUL))
	_button.pressed.connect(func() -> void: dismissed.emit())
	box.add_child(_button)


## The room behind, darkened. Without a scrim the card floats over a fully
## lit screen and does not read as modal.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.72))


func bind(content: Content, offline: Dictionary) -> void:
	var counted := int(offline.get("counted", 0))
	var capped := bool(offline.get("capped", false))
	_title.text = content.text("ui.offline.title")
	# The time that actually paid, not the time away -- otherwise a capped
	# return claims credit for hours it did not earn.
	_away.text = content.text("ui.offline.away").replace("{duration}", Num.duration(counted))
	_earned.text = Num.short(float(offline.get("soul", 0.0)))
	_capped.text = content.text("ui.offline.capped")
	_capped.visible = capped
	_button.text = content.text("ui.offline.dismiss")
