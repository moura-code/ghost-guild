class_name FloatNumber
extends Label
## A number that rises and fades. The workhorse of the fight's feel: damage
## dealt, block gained, healing, status stacks. Spawned by FightAnimator from
## the engine's event stream, frees itself when the tween finishes.
##
## Tested for state, not for pixels: that it carries the right text and
## colour, and that it removes itself. Tween interpolation is Godot's job.

const RISE_PIXELS := 34.0
const LIFETIME := 0.75

var _tween: Tween


static func make(text: String, colour: Color, big: bool = false) -> FloatNumber:
	var n := FloatNumber.new()
	n.text = text
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_theme_color_override("font_color", colour)
	n.add_theme_font_size_override("font_size", UiTheme.FONT_TITLE if big else UiTheme.FONT_NUMBER)
	return n


## Starts the rise-and-fade. Called after the node is in the tree, because a
## Tween needs a tree to run in.
func launch(from: Vector2) -> void:
	position = from
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", from + Vector2(0.0, -RISE_PIXELS), LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(queue_free)
