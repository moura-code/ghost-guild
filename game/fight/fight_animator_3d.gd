class_name FightAnimator3D
extends Control
## Turns the combat engine's event stream into feel, in a room you are
## standing in. Replaces `game/run/fight_animator.gd`.
##
## The engine already returns the events an action produced --
## `apply(state, action) -> events` -- so this never diffs state to work out
## what happened. Every number that appears here is something the engine
## actually said, and that contract did not change with the pivot.
##
## What changed is the hands, not the pacing. One beat per blow, hit-stop on a
## heavy hit, numbers staggered so a multi-hit does not stack on one pixel:
## that is what made a fight feel like a fight and it is presentation-neutral,
## so it is carried over exactly. New: a blow moves the body that took it, and
## anchors are re-asked every beat, because a body that just recoiled has
## moved and an anchor read once up front puts the second number of a turn
## where the first one was.

signal shake_requested(strength: float)
## Fired as each hit actually lands, so the thing that was hit reacts at the
## moment its number appears rather than all at once up front.
signal hit_landed(event: Dictionary)
signal finished()

const SHAKE_PER_DAMAGE := 0.7
const SHAKE_MAX := 14.0
const BIG_HIT := 10
## How long the sequence holds after a heavy blow or a kill.
const HIT_STOP := 0.09
const STAGGER := 14.0
## Seconds between one hit and the next.
const BEAT := 0.14

var content: Content
var sfx: Sfx
## `() -> Dictionary` keyed "hero" and by enemy index, in SCREEN space. Asked
## again on every beat.
var anchors_supplier: Callable = func() -> Dictionary: return {}
## `(int) -> Node3D` -- the body for an enemy index, or null. Anything with
## `recoil(int)` and `die()` will do, which is what lets this be tested
## without staging a fight.
var body_supplier: Callable = func(_i: int) -> Node3D: return null
## The numbers spawned by the most recent play() call. Tests read this.
var last_spawned: Array[FloatNumber] = []

var _queue: Array = []
var _anchors: Dictionary = {}
var _cursor: int = 0
var _beat: Tween
var _beat_counts: Dictionary = {}
var _hold: float = 0.0


## Damage to the hero shakes; damage to an enemy does not. The screen only
## lurches when the player is the one being hit.
static func shake_for(events: Array) -> float:
	var shake := 0.0
	for event in events:
		if String(event.get("type", "")) != "damage":
			continue
		if String(event.get("target", "")) != "hero":
			continue
		shake = maxf(shake, minf(SHAKE_MAX, float(int(event.get("amount", 0))) * SHAKE_PER_DAMAGE))
	return shake


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func bind(c: Content, s: Sfx) -> void:
	content = c
	sfx = s


func is_playing() -> bool:
	return _cursor < _queue.size()


func play(events: Array) -> void:
	last_spawned.clear()
	_queue = events.duplicate()
	_cursor = 0
	_beat_counts.clear()
	if _beat != null and _beat.is_valid():
		_beat.kill()
	if _queue.is_empty():
		finished.emit()
		return
	_step()


## One beat: everything that should land together lands, then the next beat is
## scheduled. Events with no visible effect are consumed without spending a
## beat, so a turn does not stall on bookkeeping.
func _step() -> void:
	_anchors = anchors_supplier.call()
	while _cursor < _queue.size():
		var event: Dictionary = _queue[_cursor]
		_cursor += 1
		if _render(event, _stagger_for(event)):
			break
	if _cursor < _queue.size() and is_inside_tree():
		_beat = create_tween()
		# Hit-stop: a heavy blow holds the sequence a moment longer before the
		# next one lands, which is what gives it weight. Scoped to this
		# animator's own pacing rather than Engine.time_scale, because the
		# simulation must not know the presentation exists.
		_beat.tween_interval(BEAT + (_hold if _hold > 0.0 else 0.0))
		_beat.tween_callback(_step)
	elif _cursor >= _queue.size():
		finished.emit()
	_hold = 0.0


## Numbers from the same beat stagger vertically so a multi-hit attack does
## not stack every number on one pixel.
func _stagger_for(event: Dictionary) -> int:
	# `target` is a String on damage events but an int on card_played, so it
	# cannot be typed -- str() takes either.
	var target: Variant = event.get("target", "")
	var key := "%s%d" % [str(target), int(event.get("index", -1))]
	var n := int(_beat_counts.get(key, 0))
	_beat_counts[key] = n + 1
	return n


## Returns true when the event was worth a beat.
func _render(event: Dictionary, stagger: int) -> bool:
	var type := String(event.get("type", ""))
	match type:
		"damage":
			var amount := int(event.get("amount", 0))
			if amount <= 0:
				# A fully absorbed hit is still an event the player should
				# feel -- it is the block doing its job.
				_spawn(content.text("ui.fight.blocked"), Palette.SOUL, _anchor(event), stagger)
				_sound("block")
				hit_landed.emit(event)
				return true
			var at: Variant = _anchor(event)
			_spawn(str(amount), Palette.DANGER, at, stagger, amount >= BIG_HIT)
			if at != null:
				_spark(at as Vector2, Palette.DANGER, amount >= BIG_HIT)
			if amount >= BIG_HIT:
				_hold = HIT_STOP
			if String(event.get("target", "")) == "hero":
				shake_requested.emit(minf(SHAKE_MAX, float(amount) * SHAKE_PER_DAMAGE))
				_sound("hero_hurt")
			else:
				var body := _body_of(event)
				if body != null and body.has_method("recoil"):
					body.call("recoil", amount)
				if sfx != null:
					sfx.hit(amount)
			hit_landed.emit(event)
			return true
		"block_gained":
			var block := int(event.get("amount", 0))
			if block <= 0:
				return false
			_spawn("+%d" % block, Palette.SOUL, _anchor(event), stagger)
			_sound("block")
			return true
		"heal":
			var healed := int(event.get("amount", 0))
			if healed <= 0:
				return false
			_spawn("+%d" % healed, Palette.GOOD, _anchor(event), stagger)
			return true
		"status_applied":
			var stacks := int(event.get("stacks", 0))
			if stacks <= 0:
				return false
			_spawn(content.text("status.%s.name" % String(event.get("status", ""))),
				Palette.PREPARED, _anchor(event), stagger)
			return true
		"enemy_died":
			var died_at: Variant = _anchor(event)
			_spawn(content.text("ui.fight.slain"), Palette.BONE_DIM, died_at, stagger, true)
			if died_at != null:
				# A death throws more, and throws it in bone.
				_spark(died_at as Vector2, Palette.BONE, true)
			var body := _body_of(event)
			if body != null and body.has_method("die"):
				body.call("die")
			_hold = HIT_STOP * 1.6
			_sound("enemy_die")
			hit_landed.emit(event)
			return true
	return false


func _body_of(event: Dictionary) -> Node3D:
	if not event.has("index"):
		return null
	return body_supplier.call(int(event["index"])) as Node3D


func _sound(id: String) -> void:
	if sfx != null:
		sfx.play(id)


func _anchor(event: Dictionary) -> Variant:
	if String(event.get("target", "")) == "hero":
		return _anchors.get("hero")
	if event.has("index"):
		return _anchors.get(int(event["index"]))
	return _anchors.get("hero")


## A burst of sparks where the blow landed. Text alone tells the player what
## happened; this makes it feel like it happened. One-shot, cheap, and frees
## itself -- no art, just points.
func _spark(at: Vector2, colour: Color, big: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12 if big else 7
	p.lifetime = 0.22 if big else 0.16
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.gravity = Vector2(0.0, 220.0)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0 if big else 105.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6 if big else 1.8
	p.color = colour
	add_child(p)
	# CPUParticles2D does not tidy up after a one-shot burst.
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)


func _spawn(text_value: String, colour: Color, at: Variant, stagger: int, big: bool = false) -> void:
	if at == null:
		return
	var number := FloatNumber.make(text_value, colour, big)
	add_child(number)
	last_spawned.append(number)
	number.launch((at as Vector2) + Vector2(0.0, -STAGGER * float(stagger)))
