class_name TurnBanner
extends Label
## Announces whose turn it is, sweeping across and fading. Turns are the
## unit a card game is played in, and without a beat between them the fight
## reads as one continuous smear of numbers.
##
## Ignores the mouse and sits above the fight, so it can pass straight over
## the cards without blocking a click on them.

const SWEEP_SECONDS := 0.9
const TRAVEL := 90.0

var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", UiTheme.FONT_TITLE)
	var face := UiTheme.title_font()
	if face != null:
		add_theme_font_override("font", face)
	modulate.a = 0.0


## `friendly` colours it: the player's turn is bone, the enemy's is danger.
func announce(text_value: String, friendly: bool) -> void:
	text = text_value
	add_theme_color_override("font_color", Palette.BONE if friendly else Palette.DANGER)
	if not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var centre := position
	position = centre - Vector2(TRAVEL * 0.5, 0.0)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", centre + Vector2(TRAVEL * 0.5, 0.0), SWEEP_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, SWEEP_SECONDS * 0.25)
	_tween.chain().tween_property(self, "modulate:a", 0.0, SWEEP_SECONDS * 0.45)
	_tween.chain().tween_callback(func() -> void: position = centre)


func is_announcing() -> bool:
	return _tween != null and _tween.is_valid()
