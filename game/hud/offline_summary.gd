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
## Long enough to watch. This is the one number in the game the player came
## back specifically to see, so it gets more than the usual count.
const COUNT_SECONDS := 1.1

var _title: Label
var _away: Label
var _earned: Label
var _capped: Label
var _returned_head: Control
var _returned: VBoxContainer
var _button: Button
var _earned_ticker: Ticker
var _motes: CPUParticles2D


func _init() -> void:
	_build()


## Worth interrupting the player for? A blink is not; a capped night is,
## even if the ladder was empty and earned nothing.
static func should_show(offline: Dictionary) -> bool:
	if bool(offline.get("capped", false)):
		return true
	# A ghost arrived. That is news at any Soul figure, and it is the whole
	# reason the player left an expedition running before they closed the game.
	if not (offline.get("returned", []) as Array).is_empty():
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
	card.custom_minimum_size = Vector2(230.0, 0.0)
	card.add_theme_stylebox_override("panel",
		UiTheme.panel_box(Palette.STONE, Palette.STONE_EDGE))
	centre.add_child(card)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	card.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	pad.add_child(box)

	_title = ScreenLayout.centre(UiTheme.title(""))
	box.add_child(_title)
	_away = ScreenLayout.centre(UiTheme.small(""))
	box.add_child(_away)
	var earned_row := HBoxContainer.new()
	earned_row.alignment = BoxContainer.ALIGNMENT_CENTER
	earned_row.add_theme_constant_override("separation", 8)
	earned_row.add_child(Icons.make_rect(Icons.ui("soul"), 13.0, Palette.SOUL))
	_earned = UiTheme.number("0")
	earned_row.add_child(_earned)
	box.add_child(earned_row)
	_capped = ScreenLayout.centre(UiTheme.small("", Palette.PREPARED))
	_capped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_capped)

	# What the guild did while nobody was watching. The Soul figure above is
	# the reward for having ghosts; this is the reward for having sent
	# somebody, and it is the only report the player ever gets of it.
	_returned_head = ScreenLayout.section("", Palette.GHOST)
	box.add_child(_returned_head)
	_returned = VBoxContainer.new()
	_returned.add_theme_constant_override("separation", 2)
	box.add_child(_returned)

	# Two candles burning on the card. Coming back to the game is supposed
	# to feel like finding the guild still lit.
	var flames := HBoxContainer.new()
	flames.alignment = BoxContainer.ALIGNMENT_CENTER
	flames.add_theme_constant_override("separation", 150)
	flames.add_child(Prop.of(Prop.Kind.CANDLE, 2))
	flames.add_child(Prop.of(Prop.Kind.CANDLE, 9))
	box.add_child(flames)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(96.0, 20.0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.add_theme_stylebox_override("normal", UiTheme.primary_box(Palette.SOUL))
	_button.pressed.connect(func() -> void: dismissed.emit())
	box.add_child(_button)

	# Soul rising through the scrim behind the card. This screen is the
	# entire payoff of an idle game -- the reason to come back tomorrow --
	# and it was a dialog with an OK button.
	_motes = CPUParticles2D.new()
	_motes.amount = 46
	_motes.lifetime = 4.5
	_motes.preprocess = 4.5
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.direction = Vector2(0.0, -1.0)
	_motes.spread = 14.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 26.0
	_motes.initial_velocity_max = 62.0
	_motes.scale_amount_min = 1.0
	_motes.scale_amount_max = 2.6
	_motes.color = Palette.SOUL
	# Behind the card, in front of the scrim.
	add_child(_motes)
	move_child(_motes, 0)

	_earned_ticker = Ticker.new(_earned, Num.short, COUNT_SECONDS)


## The room behind, darkened. Without a scrim the card floats over a fully
## lit screen and does not read as modal.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.72))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _motes != null:
		_motes.emission_rect_extents = Vector2(size.x * 0.5, 8.0)
		_motes.position = Vector2(size.x * 0.5, size.y)


func bind(content: Content, offline: Dictionary) -> void:
	var counted := int(offline.get("counted", 0))
	var capped := bool(offline.get("capped", false))
	_title.text = content.text("ui.offline.title")
	# The time that actually paid, not the time away -- otherwise a capped
	# return claims credit for hours it did not earn.
	_away.text = content.text("ui.offline.away").replace("{duration}", Num.duration(counted))
	# From zero, every time: the count IS the reward.
	_earned_ticker.set_now(0.0)
	_earned_ticker.to(float(offline.get("soul", 0.0)))
	_capped.text = content.text("ui.offline.capped")
	_capped.visible = capped
	_bind_returned(content, offline.get("returned", []) as Array)
	_button.text = content.text("ui.offline.dismiss")


## One line per ghost the guild placed while the game was closed, each with
## the silhouette that is now standing in the tower.
func _bind_returned(content: Content, ghosts: Array) -> void:
	for old in _returned.get_children():
		_returned.remove_child(old)
		old.queue_free()
	ScreenLayout.section_text(_returned_head, content.text("ui.offline.expeditions"))
	_returned_head.visible = not ghosts.is_empty()
	_returned.visible = not ghosts.is_empty()
	for entry in ghosts:
		var ghost := entry as Ghost
		if ghost == null:
			continue
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		var mark := GhostMark.new()
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.bind(ghost)
		row.add_child(mark)
		row.add_child(UiTheme.body(content.text("ui.expedition.returned")
			.replace("{name}", ghost.name).replace("{floor}", str(ghost.floor)),
			Palette.GHOST))
		_returned.add_child(row)
