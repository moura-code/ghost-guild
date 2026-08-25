class_name Ticker
extends RefCounted
## A number that counts to its new value instead of snapping to it.
##
## The Ladder grew this by hand for its Soul counter, and it is the single
## cheapest piece of game feel in the project: a value that jumps reads as a
## field being overwritten, a value that climbs reads as something you
## earned. Everything that shows a number the player caused to change --
## Soul, Coin, HP, yield, the offline total -- should own one of these.
##
## `Num` stays a pure static formatter and knows nothing about this; a Ticker
## takes whichever of its functions suits the number it is counting.
##
## The tween is created from the SceneTree rather than from the label, on
## purpose: screens are rebuilt and rebound constantly, and a counter must
## finish its bookkeeping cleanly when the label it was painting is freed
## out from under it rather than leaving a half-counted value behind.

## Long enough to read as a count, short enough not to make the player wait.
const SECONDS := 0.45
## For the 10 Hz trickle, where a full count would never finish before the
## next tick replaced it.
const QUICK := 0.12

var value: float = 0.0
var seconds: float = SECONDS

var _label: Label
var _format: Callable
var _target: float = 0.0
var _tween: Tween


func _init(label: Label, formatter: Callable = Callable(), duration: float = SECONDS) -> void:
	_label = label
	_format = formatter if formatter.is_valid() else Callable(Num, "short")
	seconds = duration


## Lands on a value without animating it. This is what a screen opening
## should do: the count is for a change the player caused, not for a screen
## appearing, and animating every number up from zero on every bind makes
## the whole game feel like it is booting.
func set_now(v: float) -> void:
	_kill()
	value = v
	_target = v
	_paint()


## Counts to `v`. A second call mid-flight retargets from wherever the count
## has got to rather than stacking a second tween on top of the first.
func to(v: float) -> void:
	if absf(v - value) < 0.005:
		set_now(v)
		return
	_kill()
	_target = v
	var tree := _tree()
	if tree == null:
		# Nothing to drive a tween: land on the value rather than silently
		# never arriving.
		set_now(v)
		return
	_tween = tree.create_tween()
	_tween.tween_method(_step, value, v, seconds) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func is_counting() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## The value the ticker is heading for, which is not what it is showing.
func target() -> float:
	return _target


func _step(v: float) -> void:
	value = v
	_paint()


func _paint() -> void:
	if is_instance_valid(_label):
		_label.text = String(_format.call(value))


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _tree() -> SceneTree:
	if not is_instance_valid(_label) or not _label.is_inside_tree():
		return null
	return _label.get_tree()
